// Fetch + process saint image thumbnails (Task 6 of the saint-companion plan).
//
// Iterates the saints that carry an `image` object in
// `data/saints_source.json`, downloads each referenced Wikimedia image
// (thumb-size when the URL has a `/thumb/…/<w>px-<name>` tail, otherwise the
// original), center-crops it square, resizes to 256×256, and encodes a JPEG
// at `assets/thumbs/<slug>.jpg` — the exact path `Saint.thumbAsset` promises
// (`assets/thumbs/<slug>.jpg`, set by `Saint.fromSourceJson` for every record
// with an `image`). Slug filenames are safe: slugs are kebab-case per the
// Task 2 rules.
//
// The run is one-time, network-bound, and resumable:
//   - a thumb that already exists is skipped (unless `--force`), so an
//     interrupted run continues where it stopped;
//   - each URL is retried once on error before its `{slug, url, error}` is
//     recorded in `data/image_failures.json`; the ledger starts from the
//     previous file's content (read + append), is deduplicated by slug on
//     rewrite, and drops the entry of any slug whose thumb exists or is
//     freshly written, so it always lists CURRENT failures.
// Requests are strictly serialized: one request in flight, no concurrency,
// no artificial delay (volume is ~1.4k images).
//
// Wikimedia bot-policy note: every request carries a descriptive
// `User-Agent` (`SanctaViaSaintDataBuild/1.0 (+https://sancta-via.net)`),
// which is required for upload.wikimedia.org access.
//
// Dev-only: tools/ is never imported by runtime code (the test file imports
// the pure URL function only).
//
// Usage (from the package root):
//   dart run tools/fetch_saint_images.dart            # full resumable run
//   dart run tools/fetch_saint_images.dart --limit 20 # smoke run
//   dart run tools/fetch_saint_images.dart --force    # re-download existing
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

/// Required Wikimedia-compliant User-Agent (pinned value).
const String _userAgent =
    'SanctaViaSaintDataBuild/1.0 (+https://sancta-via.net)';

/// Floor for requested thumbnail widths; smaller requests are raised to it.
const int _minThumbWidth = 256;

/// Output square edge / resize target (px).
const int _thumbSize = 256;

/// Width requested from Wikimedia thumbs, in px.
///
/// Wikimedia production now rejects direct `upload.wikimedia.org` thumbnail
/// requests whose width is not one of its standard sizes
/// (20, 40, 60, 120, 250, 330, 500, 960, 1280, 1920, 3840; see
/// <https://www.mediawiki.org/wiki/Common_thumbnail_sizes>), answering
/// non-standard widths with HTTP 400 ("Use thumbnail sizes listed on
/// <https://w.wiki/GHai>"). 256 px is not in that set, so the nearest
/// allowed size at or above it is requested and downscaled locally to the
/// 256×256 output below. The pure `wikimediaThumbUrl` mapping itself keeps
/// its pinned default of 256: the tool passes this width explicitly.
const int _requestThumbSize = 330;

/// JPEG quality for the encoded thumbs.
const int _thumbJpegQuality = 80;

/// Per-request wall-clock cap so one hung connection cannot stall a
/// background run. 120 s comfortably covers the largest original on a slow
/// link; timeouts are treated like any other fetch error (retry, record).
const Duration _requestTimeout = Duration(seconds: 120);

/// Matches the `<w>px-` width token of the LAST path segment: a run of
/// digits followed by `px-`, then only non-slash characters to the end of
/// the URL. No leading-`/` anchor: rendered thumbs of TIFF originals prefix
/// the width token inside one segment (`lossy-page1-220px-Foo.tiff.jpg`).
/// The leftmost match wins, which is the width token in realistic URLs —
/// a name like `220px-6px-art.jpg` rewrites `220`, not the tail `6`.
final RegExp _thumbWidthPattern = RegExp(r'(\d+)px-[^/]*$');

/// Rewrites a Wikimedia image URL so it points at [width]-wide thumb bytes.
///
/// For URLs containing `/thumb/…/<w>px-<name>`, `<w>` is replaced with
/// `max([width], 256)`. Everything else — the path, the tail name, query or
/// fragment parts — is kept byte-for-byte. URLs without that shape are
/// returned unchanged: non-thumb originals are downloaded as-is and
/// downsized locally, and malformed input must never be "fixed" into a
/// different URL.
String wikimediaThumbUrl(String url, {int width = 256}) {
  if (!url.contains('/thumb/')) {
    return url;
  }
  final RegExpMatch? match = _thumbWidthPattern.firstMatch(url);
  if (match == null) {
    return url;
  }
  final String oldWidth = match.group(1)!;
  final int targetWidth = width > _minThumbWidth ? width : _minThumbWidth;
  final int replaceStart = match.start;
  return url.replaceRange(
    replaceStart,
    replaceStart + oldWidth.length,
    '$targetWidth',
  );
}

/// One saint image to download: the slug names the output file.
class _ImageTarget {
  const _ImageTarget(this.slug, this.url);

  final String slug;
  final String url;
}

/// Parse summary from [main]: `--force` re-downloads existing thumbs;
/// `--limit N` caps the number of images the loop EXAMINES — skipped thumbs
/// included — so a from-scratch `--limit 20` run fetches-or-fails exactly
/// the first 20 targets for smoke runs.
class _FetchArgs {
  const _FetchArgs({required this.force, required this.limit});

  final bool force;
  final int? limit;
}

Future<void> main(List<String> args) async {
  final _FetchArgs parsed;
  try {
    parsed = _parseArgs(args);
  } on FormatException catch (error) {
    stderr.writeln(
      'fetch_saint_images: ${error.message}\n'
      'usage: dart run tools/fetch_saint_images.dart [--force] [--limit N]',
    );
    exitCode = 1;
    return;
  }
  try {
    await _run(parsed);
  } on FetchSaintImagesException catch (error) {
    stderr.writeln('fetch_saint_images: $error');
    exitCode = 1;
  }
}

/// An infrastructure failure (unreadable source file / bad JSON) that aborts
/// the run. Per-image download failures are data, not run errors: they are
/// recorded in `data/image_failures.json` and the run continues.
class FetchSaintImagesException implements Exception {
  FetchSaintImagesException(this.message);

  final String message;

  @override
  String toString() => message;
}

_FetchArgs _parseArgs(List<String> args) {
  bool force = false;
  int? limit;
  for (int i = 0; i < args.length; i++) {
    final String arg = args[i];
    if (arg == '--force') {
      force = true;
      continue;
    }
    if (arg == '--limit') {
      limit = _parseLimit(
        i + 1 < args.length ? args[i + 1] : null,
        '--limit requires a positive integer argument',
      );
      i++;
      continue;
    }
    if (arg.startsWith('--limit=')) {
      limit = _parseLimit(
        arg.substring('--limit='.length),
        '--limit requires a positive integer value',
      );
      continue;
    }
    throw FormatException('unknown argument: $arg');
  }
  return _FetchArgs(force: force, limit: limit);
}

int _parseLimit(String? raw, String message) {
  final int? value = raw == null ? null : int.tryParse(raw);
  if (value == null || value <= 0) {
    throw FormatException('$message, got: ${raw ?? '<missing>'}');
  }
  return value;
}

/// An infrastructure failure that aborts the run before/after the image
/// loop (e.g. `data/saints_source.json` unreadable).
Future<void> _run(_FetchArgs parsed) async {
  final int? limit = parsed.limit;

  final String packageRoot = Directory.current.path;
  final File sourceFile = File(
    p.join(packageRoot, 'data', 'saints_source.json'),
  );
  final File failuresFile = File(
    p.join(packageRoot, 'data', 'image_failures.json'),
  );
  final Directory thumbsDir = Directory(
    p.join(packageRoot, 'assets', 'thumbs'),
  );

  // Load the image targets from the committed source snapshot.
  final List<_ImageTarget> targets = <_ImageTarget>[];
  final Map<String, Object?> payload;
  try {
    final Object? decoded = jsonDecode(sourceFile.readAsStringSync());
    payload = decoded! as Map<String, Object?>;
  } on Object catch (error) {
    throw FetchSaintImagesException('cannot read ${sourceFile.path}: $error');
  }
  // Records whose image object carries no usable URL can never download:
  // they become pre-recorded failures instead of targets.
  final List<Object?> recordItems =
      payload['saints'] as List<Object?>? ?? const <Object?>[];
  final Map<String, Map<String, String>> preFailures =
      <String, Map<String, String>>{};
  for (final Object? item in recordItems) {
    final Map<String, Object?> record = item! as Map<String, Object?>;
    final Object? slug = record['slug'];
    if (slug is! String || slug.isEmpty) {
      continue;
    }
    final Object? image = record['image'];
    if (image is Map && image.isNotEmpty) {
      final Object? url = image['url'];
      if (url is String && url.isNotEmpty) {
        targets.add(_ImageTarget(slug, url));
      } else {
        preFailures[slug] = <String, String>{
          'slug': slug,
          'url': url is String ? url : '<missing>',
          'error': 'image url missing or not a string: $url',
        };
      }
    }
  }

  // Failure ledger: start from the previous file's content (read + append).
  // Rewrites are deduplicated by slug and sorted; entries for slugs whose
  // thumb exists or is freshly written are dropped (a failure entry for a
  // thumb that exists would be a lie about the current state).
  final Map<String, Map<String, String>> failures = _readFailures(failuresFile);
  failures.addAll(preFailures);
  if (!thumbsDir.existsSync()) {
    thumbsDir.createSync(recursive: true);
  }

  int downloaded = 0;
  int skipped = 0;
  int failedNow = 0;
  int processed = 0;

  final http.Client client = http.Client();
  try {
    for (final _ImageTarget target in targets) {
      if (limit != null && processed >= limit) {
        break;
      }
      final File thumbFile = File(p.join(thumbsDir.path, '${target.slug}.jpg'));
      if (!parsed.force && thumbFile.existsSync()) {
        skipped++;
        failures.remove(target.slug);
        processed++;
        if (processed % 100 == 0) {
          _printProgress(
            processed,
            targets.length,
            downloaded,
            failedNow,
            skipped,
          );
        }
        continue;
      }
      try {
        await _fetchAndProcessOne(client, target, thumbFile);
        downloaded++;
        failures.remove(target.slug);
      } on Object {
        // One retry per URL; only the retry's error is recorded.
        try {
          await _fetchAndProcessOne(client, target, thumbFile);
          downloaded++;
          failures.remove(target.slug);
        } on Object catch (retryError) {
          failedNow++;
          failures[target.slug] = <String, String>{
            'slug': target.slug,
            'url': target.url,
            'error': _shortError(retryError),
          };
          _writeFailures(failuresFile, failures);
          print(
            'fetch_saint_images FAILURE ${target.slug}: '
            '${failures[target.slug]!['error']}',
          );
        }
      }
      processed++;
      if (processed % 100 == 0) {
        _printProgress(
          processed,
          targets.length,
          downloaded,
          failedNow,
          skipped,
        );
      }
    }
  } finally {
    client.close();
  }

  // Final ledger rewrite: dedupe by slug (map already guarantees it) and
  // keep it sorted so re-runs diff cleanly.
  _writeFailures(failuresFile, failures);

  print(
    'fetch_saint_images summary'
    '${limit == null ? '' : ' (limited to $limit processed)'}',
  );
  print('  images with image object: ${targets.length}');
  print('  downloaded: $downloaded');
  print('  skipped (thumb exists): $skipped');
  print('  failed (recorded): $failedNow');
  print(
    '  failures: ${failuresFile.path} '
    '(${failures.length} entries, deduplicated by slug)',
  );
}

/// Prints the every-100 progress line, including running counts.
void _printProgress(
  int processed,
  int total,
  int downloaded,
  int failedNow,
  int skipped,
) {
  print(
    'fetch_saint_images [$processed/$total] '
    'downloaded=$downloaded failed=$failedNow skipped=$skipped',
  );
}

/// Downloads [target], center-crops square, resizes to 256×256 and encodes
/// the JPEG atomically at [thumbFile] (`.part` + rename, so an interrupted
/// run never leaves a half-written thumb that skip-exists would honor).
Future<void> _fetchAndProcessOne(
  http.Client client,
  _ImageTarget target,
  File thumbFile,
) async {
  final String url = wikimediaThumbUrl(target.url, width: _requestThumbSize);
  final Uri uri = Uri.parse(url);
  final http.Response response = await client
      .get(uri, headers: <String, String>{'User-Agent': _userAgent})
      .timeout(_requestTimeout);
  if (response.statusCode != 200) {
    throw FetchSaintImagesException('HTTP ${response.statusCode} from $url');
  }
  final img.Image? decoded = img.decodeImage(
    Uint8List.fromList(response.bodyBytes),
    frame: 0,
  );
  if (decoded == null) {
    throw FetchSaintImagesException(
      'image decode failed for $url '
      '(${response.bodyBytes.length} bytes)',
    );
  }
  final int square = decoded.width < decoded.height
      ? decoded.width
      : decoded.height;
  final img.Image cropped = img.copyCrop(
    decoded,
    x: (decoded.width - square) ~/ 2,
    y: (decoded.height - square) ~/ 2,
    width: square,
    height: square,
  );
  final img.Image thumb = img.copyResize(
    cropped,
    width: _thumbSize,
    height: _thumbSize,
    interpolation: img.Interpolation.average,
  );
  final Uint8List bytes = img.encodeJpg(thumb, quality: _thumbJpegQuality);
  final File partFile = File('${thumbFile.path}.part');
  partFile.writeAsBytesSync(bytes, flush: true);
  partFile.renameSync(thumbFile.path);
}

/// Reads the previous failures ledger; an unreadable or invalid file starts
/// from an empty ledger with a stderr warning (the ledger is a rebuildable
/// cache of download outcomes, never a reason to abort).
Map<String, Map<String, String>> _readFailures(File failuresFile) {
  if (!failuresFile.existsSync()) {
    return <String, Map<String, String>>{};
  }
  try {
    final Object? decoded = jsonDecode(failuresFile.readAsStringSync());
    final List<Object?> items = decoded! as List<Object?>;
    final Map<String, Map<String, String>> failures =
        <String, Map<String, String>>{};
    for (final Object? item in items) {
      final Map<String, Object?> entry = item! as Map<String, Object?>;
      final Object? slug = entry['slug'];
      if (slug is String && slug.isNotEmpty) {
        failures[slug] = <String, String>{
          'slug': slug,
          'url': '${entry['url']}',
          'error': '${entry['error']}',
        };
      }
    }
    return failures;
  } on Object catch (error) {
    stderr.writeln(
      'fetch_saint_images WARNING unreadable failures ledger '
      '${failuresFile.path} ($error); starting from empty',
    );
    return <String, Map<String, String>>{};
  }
}

/// Rewrites the ledger from [failures] (keyed by slug): sorted entries,
/// always a valid JSON array (empty list when there are no failures).
void _writeFailures(
  File failuresFile,
  Map<String, Map<String, String>> failures,
) {
  final List<Map<String, String>> entries = <Map<String, String>>[
    for (final String slug in failures.keys.toList()..sort()) failures[slug]!,
  ];
  const JsonEncoder encoder = JsonEncoder.withIndent('  ');
  failuresFile.parent.createSync(recursive: true);
  failuresFile.writeAsStringSync('${encoder.convert(entries)}\n', flush: true);
}

/// Truncates an error string so one bad URL cannot balloon the ledger.
String _shortError(Object error) {
  final String text = '$error'.replaceAll('\n', ' ');
  return text.length <= 300 ? text : '${text.substring(0, 300)}…';
}
