#!/usr/bin/env dart

/// Fetch tool for upstream Bible source snapshots.
///
/// Reads `tools/build_bibles/manifest.json` (its sibling) and, for each entry
/// in `sources`, downloads the pinned `url` into `assets/sources/<id>.<ext>`
/// (or the fixed snapshot file name mapped in `_snapshotFileNames`), computes
/// the SHA-256 checksum, and compares it against the manifest entry.
///
/// Two source kinds are supported:
/// - Plain sources: `url` points at a single file that is stored as-is.
/// - Joined sources (manifest entry has `joinList`): `url` is a raw-directory
///   base; the committed sibling join list (e.g. `drc_file_list.json`) names
///   the per-book files to fetch from it, they are shape-validated and
///   joined into one `{<bookKey>: {<chapter>: {<verse>: "text"}}}` JSON
///   object where `<bookKey>` is the file name minus `.json` (verbatim per
///   upstream); per-file shape violations abort the join.
/// - Every fetched response must be complete: when `Content-Length` is
///   present the collected bytes must match exactly, empty bodies are
///   rejected, and a stalled body aborts with a read-idle timeout.
/// Behaviour:
/// - First fetch (manifest `sha256` empty): pins `sha256`, `fileSize` and
///   `fetchedAt` into the manifest.
/// - Subsequent runs (snapshot present, `sha256` pinned): verify the local
///   file checksum without re-downloading, so callers never re-download.
/// - Checksum mismatch without `--update`: prints both hashes and exits 1.
/// - `--update`: force re-download of every source, update
///   `sha256`/`fetchedAt`/`fileSize` in the manifest, and print a diff against
///   the previous values for human review.
///
/// `fallbackUrls` are recorded metadata only; only the primary `url` is
/// downloaded. Sources that cannot be downloaded fail the run (exit 1).
///
/// Usage (from `sancta_via_bible_data/`):
/// ```
/// dart tools/build_bibles/bin/fetch_sources.dart
/// dart tools/build_bibles/bin/fetch_sources.dart --update
/// ```

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

const String _manifestRelativePath = 'tools/build_bibles/manifest.json';
const String _assetsRelativeDir = 'assets/sources';

/// Maximum dwell time between two body chunks of a download before the body
/// is treated as stalled and the fetch aborts.
const Duration _readIdleTimeout = Duration(seconds: 90);

/// Fixed snapshot file names under `assets/sources/` read by later pipeline
/// stages. Source ids not listed here are stored as `<id>.<ext>`
/// (`<ext>` resolved from the URL suffix).
const Map<String, String> _snapshotFileNames = <String, String>{
  'engwebc_usfm': 'engwebc_usfm.zip',
  'cpdv_entire': 'EntireBible-CPDV.json',
  'cpdv_books': 'CPDV-books.json',
  'drc': 'drc.json',
};

/// Download failure / manifest shape failure; reported per source id.
class FetchException implements Exception {
  const FetchException(this.message);

  final String message;

  @override
  String toString() => message;
}

Future<void> main(List<String> args) async {
  final bool update = args.length == 1 && args[0] == '--update';
  if (args.isNotEmpty && !update) {
    stderr.writeln(
      'Usage: dart tools/build_bibles/bin/fetch_sources.dart [--update]',
    );
    exitCode = 2;
    return;
  }

  final Directory packageRoot = _packageRoot();
  final File manifestFile = File('${packageRoot.path}/$_manifestRelativePath');
  final Directory manifestDir = manifestFile.parent;
  final Directory assetsDir = Directory(
    '${packageRoot.path}/$_assetsRelativeDir',
  );
  stdout.writeln('Manifest: ${manifestFile.path}');
  if (!manifestFile.existsSync()) {
    stderr.writeln('Manifest file not found.');
    exitCode = 1;
    return;
  }

  final Map<String, dynamic> manifest;
  final Map<String, dynamic> sources;
  try {
    (manifest, sources) = _loadManifest(manifestFile);
  } on FormatException catch (e) {
    stderr.writeln('Invalid manifest: ${e.message}');
    exitCode = 1;
    return;
  }

  final List<String> verified = <String>[];
  final List<String> pinned = <String>[];
  final List<String> refreshed = <String>[];
  final List<String> failures = <String>[];

  for (final MapEntry<String, dynamic> sourceEntry in sources.entries) {
    final String id = sourceEntry.key;
    try {
      final Map<String, dynamic> entry =
          sourceEntry.value as Map<String, dynamic>;
      final _FetchResult result = await _processSource(
        id: id,
        entry: entry,
        assetsDir: assetsDir,
        manifestDir: manifestDir,
        update: update,
      );
      switch (result) {
        case _FetchResult.verified:
          verified.add(id);
        case _FetchResult.pinned:
          pinned.add(id);
        case _FetchResult.updated:
          refreshed.add(id);
        case _FetchResult.failed:
          failures.add(id);
      }
    } on Object catch (e) {
      stderr.writeln('[fail]     $id: $e');
      failures.add(id);
    }
  }

  if (pinned.isNotEmpty || refreshed.isNotEmpty) {
    const JsonEncoder encoder = JsonEncoder.withIndent('  ');
    manifestFile.writeAsStringSync('${encoder.convert(manifest)}\n');
    stdout.writeln('Manifest updated: ${manifestFile.path}');
  }

  stdout.writeln(
    'Summary: verified=${verified.length} pinned=${pinned.length} '
    'updated=${refreshed.length} failed=${failures.length}',
  );
  if (failures.isNotEmpty) {
    stderr.writeln('Failed sources: ${failures.join(', ')}');
    exitCode = 1;
  }
}

/// Per-source outcome for the current run.
enum _FetchResult { verified, pinned, updated, failed }

Future<_FetchResult> _processSource({
  required String id,
  required Map<String, dynamic> entry,
  required Directory manifestDir,
  required Directory assetsDir,
  required bool update,
}) async {
  final String urlString = entry['url'] as String? ?? '';
  if (urlString.isEmpty) {
    throw const FetchException('manifest entry has no "url"');
  }
  final Uri url = Uri.parse(urlString);
  final String ext = url.path.toLowerCase().endsWith('.zip') ? 'zip' : 'json';
  final String fileName = _snapshotFileNames[id] ?? '$id.$ext';
  if (!fileName.toLowerCase().endsWith('.$ext')) {
    throw FetchException(
      'snapshot file "$fileName" does not match URL extension "$ext"',
    );
  }
  final File dest = File('${assetsDir.path}/$fileName');
  final String pinnedSha256 = entry['sha256'] as String? ?? '';
  final String joinListName = entry['joinList'] as String? ?? '';

  // Snapshot content resolver: plain single-file download, or a validated join
  // over the committed join list.
  Future<List<int>> _fetchSnapshotBytes() => joinListName.isEmpty
      ? _download(url)
      : _downloadJoined(
          id: id,
          baseUri: url,
          joinListFile: File('${manifestDir.path}/$joinListName'),
          joinListName: joinListName,
          expectedFileCount: entry['fileCount'] as int?,
        );

  // Idempotent path: the snapshot exists and its checksum is pinned, so only
  // verify (no network access).
  if (!update && dest.existsSync() && pinnedSha256.isNotEmpty) {
    final String actualSha256 = _sha256OfBytes(dest.readAsBytesSync());
    if (actualSha256 == pinnedSha256) {
      stdout.writeln('[ok]       $id -> $fileName (checksum verified)');
      return _FetchResult.verified;
    }
    stderr.writeln('[mismatch] $id ($fileName)');
    stderr.writeln('           manifest sha256: $pinnedSha256');
    stderr.writeln('           on-disk  sha256: $actualSha256');
    stderr.writeln(
      '           Upstream content changed; re-run with --update to re-pin.',
    );
    return _FetchResult.failed;
  }

  // Download path: first fetch, missing file, or forced --update.
  final List<int> bytes = await _fetchSnapshotBytes();
  assetsDir.createSync(recursive: true);
  dest.writeAsBytesSync(bytes);
  final String sha256Hex = _sha256OfBytes(bytes);
  final int fileSize = bytes.length;
  final String fetchedAt = DateTime.now().toUtc().toIso8601String();

  if (update) {
    final Object? oldSha256 = entry['sha256'];
    final Object? oldFileSize = entry['fileSize'];
    final Object? oldFetchedAt = entry['fetchedAt'];
    stdout.writeln('[updated]  $id -> $fileName');
    stdout.writeln('           sha256:    $oldSha256 -> $sha256Hex');
    stdout.writeln('           fileSize:  $oldFileSize -> $fileSize');
    stdout.writeln('           fetchedAt: $oldFetchedAt -> $fetchedAt');
    entry['sha256'] = sha256Hex;
    entry['fileSize'] = fileSize;
    entry['fetchedAt'] = fetchedAt;
    return _FetchResult.updated;
  }

  if (pinnedSha256.isEmpty) {
    stdout.writeln('[pinned]   $id -> $fileName');
    stdout.writeln('           sha256: $sha256Hex ($fileSize bytes)');
    entry['sha256'] = sha256Hex;
    entry['fileSize'] = fileSize;
    entry['fetchedAt'] = fetchedAt;
    return _FetchResult.pinned;
  }

  final _FetchResult result = pinnedSha256 == sha256Hex
      ? _FetchResult.verified
      : _FetchResult.failed;
  if (result == _FetchResult.verified) {
    stdout.writeln(
      '[ok]       $id -> $fileName (re-downloaded, checksum matches)',
    );
  } else {
    stderr.writeln('[mismatch] $id ($fileName) after download');
    stderr.writeln('           manifest sha256: $pinnedSha256');
    stderr.writeln('           fetched  sha256: $sha256Hex');
    stderr.writeln(
      '           Upstream content changed; re-run with --update to re-pin.',
    );
  }
  return result;
}

/// Loads `manifest.json` and validates the expected shape:
/// `{"sources": {"<id>": {...}}}`.
(Map<String, dynamic>, Map<String, dynamic>) _loadManifest(File manifestFile) {
  final Object? decoded = jsonDecode(manifestFile.readAsStringSync());
  if (decoded is! Map<String, dynamic>) {
    throw const FormatException('manifest.json must be a JSON object');
  }
  final Object? sources = decoded['sources'];
  if (sources is! Map<String, dynamic>) {
    throw const FormatException(
      'manifest.json must contain a "sources" object',
    );
  }
  return (decoded, sources);
}

/// Downloads the body of `url` as bytes. `HttpClient` follows redirects by
/// default and `autoUncompress` handles gzip transfer encodings, so callers
/// receive the plain content bytes only once the body is known complete.
Future<List<int>> _download(Uri url) async {
  final HttpClient client = HttpClient()
    ..autoUncompress = true
    ..connectionTimeout = const Duration(seconds: 30)
    ..userAgent = 'sancta-via-fetch-sources';
  try {
    final HttpClientRequest request = await client.getUrl(url);
    final HttpClientResponse response = await request.close();
    if (response.statusCode != HttpStatus.ok) {
      throw FetchException('HTTP ${response.statusCode} for $url');
    }
    return await _collectCompleteBody(response, url);
  } finally {
    client.close(force: true);
  }
}

/// Collects the response body with guards against corrupt snapshots:
///
/// - a read-idle timeout aborts stalled bodies (no infinite hangs);
/// - empty bodies are rejected;
/// - when the response carries `Content-Length` for an uncompressed body, the
///   collected byte count must match exactly (truncation surfaced as a clean
///   stream end is rejected instead of being pinned and later blessed by
///   verify runs). For `Content-Encoding` compressed bodies the header
///   describes the wire size, so only the timeout and emptiness guards apply.
Future<List<int>> _collectCompleteBody(
  HttpClientResponse response,
  Uri url,
) async {
  final int? contentLength = int.tryParse(
    response.headers.value(HttpHeaders.contentLengthHeader) ?? '',
  );
  final String? transferEncoding = response.headers.value(
    HttpHeaders.contentEncodingHeader,
  );
  final bool compressed =
      transferEncoding != null && transferEncoding.toLowerCase() != 'identity';
  final BytesBuilder builder = BytesBuilder(copy: false);
  try {
    await for (final List<int> chunk in response.timeout(_readIdleTimeout)) {
      builder.add(chunk);
    }
  } on TimeoutException {
    throw FetchException(
      'read timed out for $url (no data for ${_readIdleTimeout.inSeconds}s): '
      'stalled body',
    );
  }
  if (builder.length == 0) {
    throw FetchException('empty response body for $url');
  }
  if (contentLength != null && !compressed && builder.length != contentLength) {
    throw FetchException(
      'incomplete download for $url: got ${builder.length} of '
      '$contentLength bytes',
    );
  }
  return builder.takeBytes();
}

String _sha256OfBytes(List<int> bytes) => sha256.convert(bytes).toString();

/// Fetches every file named in the committed join list from the raw-directory
/// base URL and joins them into a single JSON object
/// `{<bookKey>: {<chapter>: {<verse>: "text"}}}` where `<bookKey>` is the
/// file name minus `.json`, verbatim (no renaming). Each fetched file's shape
/// is enforced strictly (`joinShapeViolation`) — a metadata sibling key or any
/// non-conforming value aborts the join. The body of each response is
/// required to be complete (`_collectCompleteBody`); the book count is
/// validated against the join list and the manifest `fileCount`; the psalms
/// book key spelling and its chapter 19 verse count are printed as
/// verification.
Future<List<int>> _downloadJoined({
  required String id,
  required Uri baseUri,
  required File joinListFile,
  required String joinListName,
  required int? expectedFileCount,
}) async {
  final List<String> fileNames = _loadJoinList(joinListFile, joinListName);
  if (!baseUri.toString().endsWith('/')) {
    throw FetchException('join source base URL must end with "/": $baseUri');
  }

  final HttpClient client = HttpClient()
    ..autoUncompress = true
    ..connectionTimeout = const Duration(seconds: 30)
    ..userAgent = 'sancta-via-fetch-sources';
  final Map<String, Map<String, dynamic>> joined =
      <String, Map<String, dynamic>>{};
  try {
    for (final String fileName in fileNames) {
      final String bookKey = fileName.substring(
        0,
        fileName.length - '.json'.length,
      );
      if (bookKey.isEmpty ||
          fileName.contains('/') ||
          !fileName.endsWith('.json')) {
        throw FetchException('invalid join-list entry: "$fileName"');
      }
      if (joined.containsKey(bookKey)) {
        throw FetchException('duplicate book key "$bookKey" in $joinListName');
      }
      final Uri fileUrl = Uri.parse(
        '${baseUri.toString()}${Uri.encodeComponent(fileName)}',
      );
      final HttpClientRequest request = await client.getUrl(fileUrl);
      final HttpClientResponse response = await request.close();
      if (response.statusCode != HttpStatus.ok) {
        throw FetchException('HTTP ${response.statusCode} for $fileUrl');
      }
      String text = utf8.decode(await _collectCompleteBody(response, fileUrl));
      if (text.startsWith('\uFEFF')) {
        text = text.substring(1);
      }
      final Object? bookJson = jsonDecode(text);
      if (bookJson is! Map<String, dynamic>) {
        throw FetchException('$fileName: expected a JSON object of chapters');
      }
      final String? violation = joinShapeViolation(bookJson, fileName);
      if (violation != null) {
        throw FetchException('$fileName: $violation');
      }
      joined[bookKey] = bookJson;
    }
  } finally {
    client.close(force: true);
  }

  final int bookCount = joined.length;
  final int? expected = expectedFileCount;
  if (expected != null && bookCount != expected) {
    throw FetchException('joined $bookCount books, manifest expects $expected');
  }
  stdout.writeln(
    '[join]     $id: joined $bookCount files from $joinListName '
    '(base: $baseUri)',
  );

  final String psalmsKey = joined.keys.firstWhere(
    (String key) => key.toLowerCase().contains('psalm'),
    orElse: () => '',
  );
  if (psalmsKey.isNotEmpty) {
    final Map<String, dynamic> psalms =
        joined[psalmsKey] ?? <String, dynamic>{};
    final Map<String, dynamic> psalm19 = psalms['19'] is Map<String, dynamic>
        ? psalms['19'] as Map<String, dynamic>
        : <String, dynamic>{};
    stdout.writeln(
      '[join]     $id: psalms book key "$psalmsKey"; '
      '$psalmsKey/19 has ${psalm19.length} verses',
    );
  }

  const JsonEncoder encoder = JsonEncoder.withIndent('  ');
  return utf8.encode('${encoder.convert(joined)}\n');
}

/// Returns `null` when [bookJson] matches the strictly-joined per-file shape
/// `{<chapter>: {<verse>: "text"}}`; otherwise a description naming the
/// offending key is returned. Enforced constraints:
/// - every top-level value is an object (a chapter map) — non-object values
///   such as a string metadata sibling key (e.g. `charset`) are contract
///   violations;
/// - every chapter entry is an object, i.e. chapters map to verse maps;
/// - every verse value is a string (the upstream-verbatim text).
String? joinShapeViolation(Map<String, dynamic> bookJson, String fileName) {
  for (final MapEntry<String, dynamic> chapterEntry in bookJson.entries) {
    final Object? verses = chapterEntry.value;
    if (verses is! Map<String, dynamic>) {
      return 'chapter "${chapterEntry.key}" is not an object '
          '(expected {<chapter>: {<verse>: "text"}})';
    }
    for (final MapEntry<String, dynamic> verseEntry in verses.entries) {
      if (verseEntry.value is! String) {
        return 'chapter "${chapterEntry.key}" verse '
            '"${verseEntry.key}" text is not a string';
      }
    }
  }
  return null;
}

/// Loads the committed join list (JSON array of `<BookName>.json` file names).
List<String> _loadJoinList(File joinListFile, String joinListName) {
  if (!joinListFile.existsSync()) {
    throw FetchException('join list not found: ${joinListFile.path}');
  }
  final Object? decoded = jsonDecode(joinListFile.readAsStringSync());
  if (decoded is! List<Object?>) {
    throw FetchException('$joinListName must be a JSON array of file names');
  }
  int i = 0;
  final List<String> fileNames = <String>[];
  for (final Object? element in decoded) {
    final Object? entry = element;
    i += 1;
    if (entry is! String) {
      throw FetchException('$joinListName entry #$i is not a string');
    }
    fileNames.add(entry);
  }
  return fileNames;
}

/// Walks up from this script's location until a `pubspec.yaml` is found (the
/// package root); falls back to the current working directory.
Directory _packageRoot() {
  Directory dir = File.fromUri(Platform.script).parent;
  for (int i = 0; i < 8; i++) {
    if (File('${dir.path}/pubspec.yaml').existsSync()) {
      return dir;
    }
    final Directory parent = dir.parent;
    if (parent.path == dir.path) {
      break;
    }
    dir = parent;
  }
  return Directory.current;
}
