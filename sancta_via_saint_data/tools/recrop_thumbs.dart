// Face-centered thumb re-crop (heads-in-frame fix).
//
// The one-time thumb fetch (tools/fetch_saint_images.dart) center-cropped
// every image vertically, which decapitated tall portraits whose faces sit
// below the geometric middle (e.g. St Hugh of Lincoln, face at ~72% of the
// painting). This tool re-processes every bundled thumb:
//
//   1. downloads the ORIGINAL image referenced by the seed's `image.url`
//      (512px Wikimedia thumb when a `/thumb/...` URL shape is available);
//   2. face-detects it with the macOS Vision framework through the
//      `tool/facedetect` binary (compiled on first use from
//      `tool/facedetect.swift`);
//   3. crops a square anchored on the face (fallback: top-biased square)
//      and re-encodes `assets/thumbs/<slug>.jpg` at 256x256.
//
// Resumable via the ledger `data/thumb_recrop.json` ({slug: {faced: bool}}):
// a slug present there is skipped unless `--force`. Failures are recorded
// per slug in `data/recrop_failures.json`; the run exits 1 when any failed.
//
// Network politeness (mirrors fetch_saint_images): >=250 ms between
// requests, 429/5xx back-off ladder (2s, 4s, 8s, up to 4 attempts), and the
// descriptive Wikimedia User-Agent.
//
// Dev-only: tools/ is never imported by runtime code.
//
// Usage (from the package root):
//   dart run tools/recrop_thumbs.dart               # full resumable run
//   dart run tools/recrop_thumbs.dart --slug <slug> # single smoke run
//   dart run tools/recrop_thumbs.dart --force       # redo existing
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;

import 'package:saint_data/src/utils/face_crop.dart';
import 'fetch_saint_images.dart' show wikimediaThumbUrl;

const String _userAgent = 'SanctaViaSaintDataBuild/1.0 (+https://sancta-via.net)';
const String _facedetectSource = 'tool/facedetect.swift';
const String _facedetectBinary = '.dart_tool/facedetect_bin';

/// Resolves the facedetect binary, compiling it once if needed.
Future<String> _facedetectBinaryPath() async {
  final File binary = File(_facedetectBinary);
  if (binary.existsSync() && binary.lengthSync() > 1000) {
    return binary.path;
  }
  final ProcessResult compiled = await Process.run(
    'swiftc',
    <String>['-O', _facedetectSource, '-o', binary.path],
  );
  if (compiled.exitCode != 0) {
    stderr.write(compiled.stderr);
    throw StateError('facedetect compile failed');
  }
  return binary.path;
}

/// Normalized face rects from the facedetect binary.
Future<List<FaceRect>> detectFaces(String binaryPath, String imagePath) async {
  final ProcessResult result = await Process.run(
    binaryPath,
    <String>[imagePath],
  );
  if (result.exitCode != 0) {
    throw StateError('facedetect exited ${result.exitCode}: ${result.stderr}');
  }
  final Object? decoded = jsonDecode(result.stdout as String);
  final List<dynamic> rows = decoded is List<dynamic> ? decoded : <dynamic>[];
  return <FaceRect>[
    for (final Object? row in rows)
      if (row is Map<String, dynamic>)
        FaceRect(
          x: (row['x'] as num).toDouble(),
          y: (row['y'] as num).toDouble(),
          w: (row['w'] as num).toDouble(),
          h: (row['h'] as num).toDouble(),
        ),
  ];
}

/// Runs the pacing/budgets and returns the downloaded bytes, or throws.
Future<Uint8List> _download(
  http.Client client,
  String url,
) async {
  final List<int> ladder = <int>[2, 4, 8];
  Object? lastError;
  for (int attempt = 0; attempt <= ladder.length; attempt++) {
    try {
      final http.Response response = await client
          .get(
            Uri.parse(url),
            headers: <String, String>{'user-agent': _userAgent},
          )
          .timeout(const Duration(seconds: 60));
      if (response.statusCode == 200) {
        return response.bodyBytes;
      }
      if (response.statusCode == 429 || response.statusCode >= 500) {
        if (attempt == ladder.length) {
          continue; // falls through to the throw below
        }
        final int wait =
            int.tryParse(response.headers['retry-after'] ?? '') ??
                ladder[attempt];
        await Future<void>.delayed(Duration(seconds: wait));
        continue;
      }
      throw HttpException('HTTP ${response.statusCode} for $url');
    } on Object catch (error) {
      lastError = error;
      if (error is HttpException) {
        rethrow;
      }
      if (attempt < ladder.length) {
        await Future<void>.delayed(Duration(seconds: ladder[attempt]));
      }
    }
  }
  throw HttpException('exhausted retry ladder for $url: $lastError');
}

/// Decodes + crops per [rect] + writes the JPEG.
void _writeCroppedThumb(
  Uint8List bytes,
  CropRect rect,
  File thumbFile,
) {
  final img.Image? decoded = img.decodeImage(bytes, frame: 0);
  if (decoded == null) {
    throw StateError('image decode failed');
  }
  final int clampedX = rect.x.clamp(0, math.max(0, decoded.width - 1));
  final int clampedY = rect.y.clamp(0, math.max(0, decoded.height - 1));
  final int clampedSize = rect.size.clamp(
    1,
    math.min(decoded.width - clampedX, decoded.height - clampedY),
  );
  final img.Image cropped = img.copyCrop(
    decoded,
    x: clampedX,
    y: clampedY,
    width: clampedSize,
    height: clampedSize,
  );
  final img.Image thumb = img.copyResize(
    cropped,
    width: 256,
    height: 256,
    interpolation: img.Interpolation.average,
  );
  final File partFile = File('${thumbFile.path}.part');
  partFile.writeAsBytesSync(img.encodeJpg(thumb, quality: 85), flush: true);
  partFile.renameSync(thumbFile.path);
}

Future<void> main(List<String> args) async {
  final List<String> onlySlugs = <String>[];
  bool force = false;
  for (final String arg in args) {
    if (arg == '--force') {
      force = true;
    } else if (arg == '--slug') {
      stderr.writeln('recrop_thumbs: --slug needs a value');
      exitCode = 1;
      return;
    } else if (arg.startsWith('--slug=')) {
      onlySlugs.add(arg.substring(7));
    } else {
      stderr.writeln('recrop_thumbs: unknown argument "$arg"');
      exitCode = 1;
      return;
    }
  }

  final http.Client client = http.Client();
  final String binaryPath = await _facedetectBinaryPath();
  final Map<String, dynamic> payload = jsonDecode(
    File('data/saints_source.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  final File ledgerFile = File('data/thumb_recrop.json');
  final Map<String, dynamic> ledger = ledgerFile.existsSync()
      ? (jsonDecode(ledgerFile.readAsStringSync()) as Map<String, dynamic>)
      : <String, dynamic>{};
  final File failuresFile = File('data/recrop_failures.json');
  final Map<String, String> failures = <String, String>{};

  final List<dynamic> saints = payload['saints'] as List<dynamic>;
  int processed = 0;
  await Future<void>.delayed(const Duration(milliseconds: 1));
  bool paced = false;

  for (final Object? row in saints) {
    if (row is! Map<String, dynamic>) {
      continue;
    }
    final String slug = (row['slug'] ?? '').toString();
    final Map<String, dynamic>? image =
        row['image'] is Map<String, dynamic>
            ? row['image'] as Map<String, dynamic>
            : null;
    if (image == null || (image['url'] ?? '').toString().isEmpty) {
      continue;
    }
    if (onlySlugs.isNotEmpty && !onlySlugs.contains(slug)) {
      continue;
    }
    if (!force && ledger.containsKey(slug)) {
      continue;
    }
    if (paced) {
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
    paced = true;

    try {
      final String originalUrl = (image['url'] ?? '').toString();
      final String sourceUrl = wikimediaThumbUrl(originalUrl, width: 512);
      Uint8List bytes;
      try {
        bytes = await _download(client, sourceUrl);
      } on HttpException {
        // A 400 thumb request usually means the original is smaller than
        // the requested width: fall back to the source itself.
        bytes = await _download(client, originalUrl);
      }
      final img.Image? decoded = img.decodeImage(bytes, frame: 0);
      if (decoded == null) {
        failures[slug] = 'image decode failed';
        continue;
      }
      final File probeFile = File(
        '${Directory.systemTemp.path}/recrop_$slug.img',
      );
      probeFile.writeAsBytesSync(bytes, flush: true);
      final List<FaceRect> faces = await detectFaces(binaryPath, probeFile.path);
      probeFile.deleteSync();
      final CropRect rect = faceCropRect(
        imageWidth: decoded.width,
        imageHeight: decoded.height,
        faces: faces,
      );
      _writeCroppedThumb(bytes, rect, File('assets/thumbs/$slug.jpg'));
      ledger[slug] = <String, dynamic>{
        'faced': faces.isNotEmpty,
        'faces': faces.length,
        'crop': <String, int>{'x': rect.x, 'y': rect.y, 'size': rect.size},
      };
      processed++;
      stdout.writeln('[${slug}] recropped (faces: ${faces.length},'
          ' crop y=${rect.y})');
    } on Object catch (error) {
      failures[slug] = error.toString();
      stderr.writeln('[${slug}] FAILED: $error');
    }
  }

  File('data/thumb_recrop.json').writeAsBytesSync(
    Uint8List.fromList(
      utf8.encode(const JsonEncoder.withIndent('  ').convert(ledger)),
    ),
    flush: true,
  );
  if (failures.isEmpty) {
    if (failuresFile.existsSync()) {
      failuresFile.deleteSync();
    }
  } else {
    failuresFile.writeAsBytesSync(
      Uint8List.fromList(
        utf8.encode(const JsonEncoder.withIndent('  ').convert(failures)),
      ),
      flush: true,
    );
  }
  stdout.writeln('recropped: $processed, failures: ${failures.length}');
  if (failures.isNotEmpty) {
    exitCode = 1;
  }
  client.close();
}
