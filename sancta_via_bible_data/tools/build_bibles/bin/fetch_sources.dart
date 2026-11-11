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
/// - Scraped sources (manifest entry has a `scrape` object): `url` is a
///   chapter-directory base (drbo.org `/chapter/`); every book 1..bookCount
///   is enumerated chapter 1..K as `<bb><ccc>.htm` codes (`bb` = 1-based
///   book, `ccc` = 3-digit chapter), pages are parsed into
///   `{<bookKey>: {<chapter>: {<verse>: "text"}}}` (bookKey = drbo.org's
///   verbatim book name) and written to the snapshot once the full book set
///   is complete and validated. Structure/anchor hard gates abort with
///   evidence; the book -> chapter count table is derived from the cpdv
///   chapter counts in `expected_structure.json` (Vulgate basis) and each
///   book's one-past boundary page must NOT exist (missing pages redirect to
///   drbo.org's 404 page). `scrape.chapterCountOverrides` records books where
///   the live verification disagreed with the cpdv count (each value is
///   verified against the real 404 boundary at run time). Raw pages are
///   cached per chapter under `assets/sources/.drc_cache/` (git-ignored), so
///   resumed crawls skip completed chapters and re-runs never re-fetch.
///   Requests honor `scrape.crawlDelayMs` (>= 5000 per drbo.org robots.txt)
///   between request starts over a single connection. `--smoke` fetches only
///   the pinned smoke chapters (Genesis 1, Esther 1, Apocalypse 1) plus their
///   one-past boundary probes, writes the cache, and never emits the
///   snapshot.
/// - Every run that may reach the network takes a cross-process run lock
///   (`assets/sources/.drc_cache/fetch_sources.lock`, inside the git-ignored
///   cache dir): an OS file lock (advisory, exclusive, per-instance) keeps a
///   second instance from ever overlapping a running fetch's request stream,
///   and a recorded PID refuses runs while that PID is alive, taking the
///   lock over (with a log line) once the PID is gone. The lock file is left
///   in place on release for resume consistency; crashed runs are detected
///   by the dead PID on the next run.
/// - Transient transport failures are retried with a bounded per-request
///   budget of 3 attempts (1 try + 2 retries): retryable error classes are
///   `HttpException`/`SocketException`/`TimeoutException` (the connection
///   closed/reset and stalled-body family) plus the wrapped read-idle-timeout
///   error; missing-page (404/redirect) responses, HTTP 5xx failures, bk/ch
///   anchor aborts, and shape violations are never retried. Each retry is
///   logged grep-ably as `[retry] <label> attempt N/3: <error>` and counts as
///   a request for the delay. Spacing: the throttled scraper keeps >= 5s
///   (its robots gap) between attempts, escalating to ~2x the gap before the
///   final attempt; plain/joined requests wait 5s, then 10s. The scraped
///   source opens one short-lived client per attempt (closed with the
///   response), so no connection is reused across the idle gap between
///   requests (the keep-alive close race) — a deliberate choice over
///   connection reuse since the handshake cost is negligible at a 5s cadence.
/// - Every fetched response must be complete: when `Content-Length` is
///   present the collected bytes must match exactly, empty bodies are
///   rejected, and a stalled body aborts with a read-idle timeout.
/// Behaviour:
/// - First fetch (manifest `sha256` empty): pins `sha256`, `fileSize` and
///   `fetchedAt` into the manifest (for scraped sources: when the joined
///   snapshot is written on completion).
/// - Subsequent runs (snapshot present, `sha256` pinned): verify the local
///   file checksum without re-downloading, so callers never re-download.
/// - Checksum mismatch without `--update`: prints both hashes and exits 1.
/// - `--update`: force re-download of every source, update
///   `sha256`/`fetchedAt`/`fileSize` in the manifest, and print a diff against
///   the previous values for human review. A scraped source re-runs its crawl
///   (cache-verified chapters are skipped) unless the snapshot checksum still
///   verifies.
/// - `fallbackUrls` are recorded metadata only; only the primary `url` is
///   downloaded/fetched. Sources that cannot be downloaded fail the run
///   (exit 1); an in-progress scrape also fails the run (exit 1) until its
///   snapshot is complete.
///
/// Usage (from `sancta_via_bible_data/`):
/// ```
/// dart tools/build_bibles/bin/fetch_sources.dart
/// dart tools/build_bibles/bin/fetch_sources.dart --update
/// dart tools/build_bibles/bin/fetch_sources.dart --smoke
/// ```

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

const String _manifestRelativePath = 'tools/build_bibles/manifest.json';
const String _assetsRelativeDir = 'assets/sources';

const String _expectedStructureRelativePath =
    'tools/build_bibles/expected_structure.json';
const String _bookNamesJsonRelativePath = 'tools/build_bibles/book_names.json';
const String _scrapeCacheRelativeDir = 'assets/sources/.drc_cache';
const String _runLockFileName = 'fetch_sources.lock';

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

/// Smoke-test chapter fetch set for scraped sources (`--smoke`): one chapter
/// each for books bk=1 (Genesis), bk=19 (Esther; exercises the chapter-count
/// override) and bk=73 (Apocalypse), plus each book's one-past boundary page
/// (which must NOT exist).
const List<int> _scrapeSmokeBooks = <int>[1, 19, 73];

/// Robots.txt crawl-delay lower bound for the drbo.org scraper.
const int _scrapeCrawlDelayLowerBoundMs = 5000;

Future<void> main(List<String> args) async {
  final bool update = args.contains('--update');
  final bool smoke = args.contains('--smoke');
  final bool badArgs = args.any(
    (String a) => a != '--update' && a != '--smoke',
  );
  if (args.isNotEmpty && (badArgs || args.toSet().length != args.length)) {
    stderr.writeln(
      'Usage: dart tools/build_bibles/bin/fetch_sources.dart [--update] [--smoke]',
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

  // Cross-process run lock: one fetch run at a time, so the per-request
  // crawl delay cannot be doubled by a second instance.
  _FetchRunLock runLock;
  try {
    runLock = _acquireFetchRunLock(
      Directory('${packageRoot.path}/$_scrapeCacheRelativeDir'),
    );
  } on FetchException catch (e) {
    stderr.writeln('[lock]     $e');
    exitCode = 1;
    return;
  }

  try {
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
          smoke: smoke,
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
  } finally {
    runLock.release();
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
  required bool smoke,
}) async {
  final Object? rawScrape = entry['scrape'];
  if (rawScrape is Map<String, dynamic>) {
    return _processScrapeSource(
      id: id,
      entry: entry,
      scrape: rawScrape,
      assetsDir: assetsDir,
      update: update,
      smoke: smoke,
    );
  }
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
  // Plain source: single logical request; retried on transient transport
  // errors (connection closed/reset/timeouts) before the failure is final.
  Future<List<int>> _fetchSnapshotBytes() {
    if (joinListName.isNotEmpty) {
      return _downloadJoined(
        id: id,
        baseUri: url,
        joinListFile: File('${manifestDir.path}/$joinListName'),
        joinListName: joinListName,
        expectedFileCount: entry['fileCount'] as int?,
      );
    }
    return _retryTransient(
      'plain $id',
      () => _download(url),
      firstRetryDelayMs: _fetchRetryDelayMs,
      escalatedRetryDelayMs: _fetchRetryEscalatedDelayMs,
    );
  }

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
  } on TimeoutException catch (e) {
    // Transport-class: the body stalled, so the request is retried like any
    // other transient failure (the descriptive original message is kept).
    throw _TransientFetchException(
      '${e.toString()} for $url (no data for ${_readIdleTimeout.inSeconds}s): '
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
      String text = await _retryTransient(
        'joined $id $fileName',
        () async {
          final HttpClientRequest request = await client.getUrl(fileUrl);
          final HttpClientResponse response = await request.close();
          if (response.statusCode != HttpStatus.ok) {
            throw FetchException('HTTP ${response.statusCode} for $fileUrl');
          }
          return utf8.decode(await _collectCompleteBody(response, fileUrl));
        },
        firstRetryDelayMs: _fetchRetryDelayMs,
        escalatedRetryDelayMs: _fetchRetryEscalatedDelayMs,
      );
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

// ---------------------------------------------------------------------------
// Transient-transport retry (shared by every fetch mode)
// ---------------------------------------------------------------------------

/// Maximum attempts per single logical request (1 try + 2 retries).
const int _maxFetchAttempts = 3;

/// Delay before the first retry of a non-throttled (plain/joined) request.
const int _fetchRetryDelayMs = 5000;

/// Delay before the final retry of a non-throttled request; the throttled
/// scraper escalates by this much on top of its own robots gap instead.
const int _fetchRetryEscalatedDelayMs = 10000;

/// Whether [error] is a transport-class failure worth retrying: the connection
/// was closed/reset mid-request or a timeout hit. Hard gates (HTTP 5xx
/// [FetchException]s, 404 missing pages, bk/ch anchor aborts, shape
/// violations) are never retried.
bool _isTransientTransportError(Object error) {
  return error is HttpException ||
      error is SocketException ||
      error is TimeoutException ||
      error is _TransientFetchException;
}

/// A transport-class failure that is safe to retry (wrapped where the original
/// type would otherwise be lost to a FetchException).
final class _TransientFetchException implements Exception {
  const _TransientFetchException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Runs [action] with bounded retries for transient transport errors: at most
/// [_maxFetchAttempts] attempts per logical request, each failure logged
/// grep-ably (`[retry] … attempt N/M: <error>`), the original error rethrown
/// unchanged once attempts are exhausted.
///
/// Spacing (documented behaviour): [firstRetryDelayMs] before the second
/// attempt and [escalatedRetryDelayMs] before the final one — the throttled
/// scraper passes 0 / `crawlDelayMs` because its own robots gap (>= 5s) is
/// enforced per attempt inside the action, so retries land ~5s apart and the
/// final retry ~2x that; plain/joined requests pass 5000 / 10000.
Future<T> _retryTransient<T>(
  String label,
  Future<T> Function() action, {
  required int firstRetryDelayMs,
  required int escalatedRetryDelayMs,
}) async {
  for (int attempt = 1; ; attempt++) {
    try {
      return await action();
    } on Object catch (e) {
      if (!_isTransientTransportError(e)) {
        rethrow;
      }
      if (attempt >= _maxFetchAttempts) {
        stdout.writeln(
          '[retry]     $label gave up after $_maxFetchAttempts attempts: $e',
        );
        rethrow;
      }
      stdout.writeln(
        '[retry]     $label attempt ${attempt + 1}/$_maxFetchAttempts: $e',
      );
      final int extra = attempt >= _maxFetchAttempts - 1
          ? escalatedRetryDelayMs
          : firstRetryDelayMs;
      if (extra > 0) {
        await Future<void>.delayed(Duration(milliseconds: extra));
      }
    }
  }
}

// ---------------------------------------------------------------------------
// Cross-process run lock (guards the network request stream of any run)
// ---------------------------------------------------------------------------

/// Handle for the acquired per-run lock; [release] must be called in a
/// `finally` so a finished run always yields the lock.
final class _FetchRunLock {
  const _FetchRunLock(this._file);

  final RandomAccessFile _file;

  /// Releases the OS file lock. The lock FILE stays on disk (with the
  /// releasing PID) for resume consistency; the next run takes over once the
  /// recorded PID is gone.
  void release() {
    _file.unlockSync();
    _file.closeSync();
  }
}

/// Acquires the exclusive cross-process run lock before the first network
/// request, throwing [FetchException] (never overlapping the holder) when
/// another fetch run is live.
///
/// Two layers keep two instances apart:
/// - an OS file lock (`RandomAccessFile.lockSync`, advisory/exclusive) is
///   atomic, so simultaneous starts cannot both win, and is released by the
///   OS if a process dies; and
/// - the lock FILE records the owner's PID, so a run whose predecessor is
///   STILL ALIVE refuses (`another fetch is running (PID …)`) even when that
///   predecessor predates the file lock (e.g. an in-flight legacy crawl) or
///   the PID was reused. A dead PID is taken over with a log line.
_FetchRunLock _acquireFetchRunLock(Directory cacheDir) {
  final File lockFile = File('${cacheDir.path}/$_runLockFileName');
  Directory(cacheDir.path).createSync(recursive: true);
  // Append mode: opening never truncates, so the recorded owner stays
  // readable before the lock is held.
  final RandomAccessFile file = lockFile.openSync(mode: FileMode.append);
  try {
    file.lockSync(FileLock.exclusive);
  } on Object {
    file.closeSync();
    throw const FetchException(
      'another fetch is running (the run lock fetch_sources.lock is held); '
      'refusing to overlap its request stream',
    );
  }
  // The OS lock is ours: inspect the recorded owner.
  final (int? recordedPid, String? startedAt) = _readLockOwner(lockFile);
  if (recordedPid != null && recordedPid != pid) {
    if (_pidIsAlive(recordedPid)) {
      file.unlockSync();
      file.closeSync();
      throw FetchException(
        'another fetch is running (PID $recordedPid'
        '${startedAt == null ? '' : ', started $startedAt'}); '
        'refusing to overlap its request stream',
      );
    }
    stdout.writeln(
      '[lock]     stale lock: recorded PID $recordedPid is gone; '
      'taking over the run lock',
    );
  }
  file.truncateSync(0);
  file.setPositionSync(0);
  file.writeStringSync(
    '${jsonEncode(<String, String>{'pid': '$pid', 'startedAt': DateTime.now().toUtc().toIso8601String()})}\n',
  );
  return _FetchRunLock(file);
}

/// Reads the recorded owner from the lock file; `(null, null)` when absent,
/// empty, or unreadable (a corrupt record is treated as no owner).
(int?, String?) _readLockOwner(File lockFile) {
  try {
    // NUL bytes are stripped defensively: a record written by an older build
    // (before the write position was pinned) could carry a zero-filled hole.
    final String text = lockFile
        .readAsStringSync()
        .replaceAll('\u0000', '')
        .trim();
    if (text.isEmpty) {
      return (null, null);
    }
    final Object? decoded = jsonDecode(text);
    if (decoded is Map<String, dynamic>) {
      final Object? pidRaw = decoded['pid'];
      final int? recordedPid = pidRaw is int ? pidRaw : int.tryParse('$pidRaw');
      final Object? startedAt = decoded['startedAt'];
      return (recordedPid, startedAt is String ? startedAt : null);
    }
  } on Object {
    // fall through: unreadable/corrupt record behaves as no owner
  }
  return (null, null);
}

/// Whether [processId] is alive (`kill -0`); a missing/unusable `kill`
/// binary warns and reports dead so a broken checker cannot brick runs.
bool _pidIsAlive(int processId) {
  if (processId <= 0) {
    return false;
  }
  try {
    final ProcessResult result = Process.runSync('kill', <String>[
      '-0',
      '$processId',
    ]);
    return result.exitCode == 0;
  } on Object {
    stdout.writeln(
      '[lock]     cannot check PID $processId liveness (kill unavailable); '
      'treating the lock as stale',
    );
    return false;
  }
}

// ---------------------------------------------------------------------------
// Scraped sources (drbo.org; kind selected by a `scrape` manifest entry)
// ---------------------------------------------------------------------------

/// Throttled HTTP client for scraped sources: requests are sequential with a
/// minimum gap of `crawlDelayMs` between request starts (the upstream
/// robots.txt crawl-delay is honored exactly), and every attempt opens its own
/// short-lived client that is closed as soon as the response body is read —
/// no connection is ever held open across the idle gap between requests, so
/// the server cannot close a reused connection out from under the next
/// request (keep-alive race), and each retry starts on a fresh connection.
final class _ThrottledScraper {
  _ThrottledScraper(this.crawlDelayMs)
    : lastRequestStart = DateTime.fromMillisecondsSinceEpoch(0);

  final int crawlDelayMs;

  /// Start time of the most recent request (used to enforce the gap).
  DateTime lastRequestStart;

  /// Requests issued so far; every retry attempt is its own request for the
  /// delay and this counter.
  int requestCount = 0;

  /// Minimum observed start-to-start gap between two requests (ms), or -1
  /// before the second request; surfaced as a run-time delay proof.
  int minGapMs = -1;

  /// GETs [url] with `followRedirects` disabled and bounded transient-error
  /// retries. Returns the status, any `Location` header, and the fully-read
  /// body for 200 responses only. [label] names the logical request in the
  /// grep-able retry log.
  Future<({int status, String location, List<int>? bytes})> get(
    Uri url, {
    required String label,
  }) {
    return _retryTransient(
      label,
      () => _attemptGet(url),
      firstRetryDelayMs: 0,
      escalatedRetryDelayMs: crawlDelayMs,
    );
  }

  /// One throttled request attempt; each attempt counts for the delay.
  Future<({int status, String location, List<int>? bytes})> _attemptGet(
    Uri url,
  ) async {
    final DateTime now = DateTime.now();
    final int wait =
        crawlDelayMs + 50 - now.difference(lastRequestStart).inMilliseconds;
    if (wait > 0) {
      await Future<void>.delayed(Duration(milliseconds: wait));
    }
    final DateTime start = DateTime.now();
    if (requestCount > 0) {
      final int gap = start.difference(lastRequestStart).inMilliseconds;
      if (minGapMs == -1 || gap < minGapMs) {
        minGapMs = gap;
      }
    }
    lastRequestStart = start;
    requestCount += 1;

    final HttpClient client = HttpClient()
      ..autoUncompress = true
      ..connectionTimeout = const Duration(seconds: 30)
      ..userAgent = 'sancta-via-fetch-sources';
    try {
      final HttpClientRequest request = await client.getUrl(url);
      request.followRedirects = false;
      final HttpClientResponse response = await request.close();
      if (response.statusCode == HttpStatus.ok) {
        final List<int> bytes = await _collectCompleteBody(response, url);
        return (status: response.statusCode, location: '', bytes: bytes);
      }
      if (response.statusCode == HttpStatus.movedPermanently ||
          response.statusCode == HttpStatus.found ||
          response.statusCode == HttpStatus.movedTemporarily ||
          response.statusCode == HttpStatus.notFound) {
        return (
          status: response.statusCode,
          location: response.headers.value(HttpHeaders.locationHeader) ?? '',
          bytes: null,
        );
      }
      throw FetchException('HTTP ${response.statusCode} for $url');
    } finally {
      // Per-request client: never hold a connection open across the idle gap
      // between requests.
      client.close(force: true);
    }
  }
}

/// Result of one scraped chapter page: verse number -> text.
final class _DrboChapter {
  const _DrboChapter(this.bookKey, this.bk, this.ch, this.verses);

  final String bookKey;
  final int bk;
  final int ch;
  final Map<int, String> verses;
}

/// `<a class=vn href="/cgi-bin/d?b=drb&bk=1&ch=1&l=1-#x">…</a>` (tolerant of
/// quoted attributes and `&amp;`-encoded ampersands).
final RegExp _drboVerseAnchorOpen = RegExp(
  r'<a\s+class="?vn"?\s+href="(/cgi-bin/d\?b=drb[?&][^"]*)"[^>]*>',
);

/// Extracts bk/ch/l out of an anchor href.
final RegExp _drboHrefParams = RegExp(
  r'bk=(\d+)&(?:amp;)?ch=(\d+)&(?:amp;)?l=(\d+)',
);

/// drbo.org book links on the homepage: `<a class=b href="chapter/NN001.htm"`
final RegExp _drboBookAnchor = RegExp(
  r'<a\s+class="?b"?\s+href="chapter/(\d{2})001\.htm"[^>]*>(.*?)</a>',
  dotAll: true,
);

/// The asterisk glyph tag drbo.org appends to deuterocanonical book names.
final RegExp _drboAsteriskGlyph = RegExp(
  r'<font\s+class="?ast"?[^>]*>[^<]*</font>',
  caseSensitive: false,
);

/// `<p class=note>…</p>` footnote blocks between verse groups.
final RegExp _drboNoteBlock = RegExp(
  r'<p\s+class="?note"[^>]*>.*?</p>',
  dotAll: true,
);

/// Inline `<script>…</script>` blocks (page footer only).
final RegExp _drboScriptBlock = RegExp(r'<script\b.*?</script>', dotAll: true);

/// Returns `true` when [status]/[location] mean "chapter does not exist"
/// (a redirect onto the site's 404 page, or a straight 404).
bool _drboIsMissingPage(int status, String location) {
  if (status == HttpStatus.notFound) {
    return true;
  }
  return (status >= 300 && status < 400) && location.endsWith('/404.htm');
}

/// Builds a `<bb><ccc>.htm` chapter-page code (book 1-based, chapter decimal).
String _drboCode(int bk, int chapter) {
  if (bk < 1 || bk > 99 || chapter < 1 || chapter > 999) {
    throw FetchException(
      'cannot encode chapter page code for bk=$bk ch=$chapter',
    );
  }
  return '${bk.toString().padLeft(2, '0')}${chapter.toString().padLeft(3, '0')}';
}

/// Loads `book_names.json` and validates that every scrapable source key
/// already maps onto a canonical db book name with a consistent order.
Map<String, (String, int)> _loadBookNamesForScrape(String bookNamesPath) {
  final File file = File(bookNamesPath);
  if (!file.existsSync()) {
    throw FetchException('book_names.json not found at $bookNamesPath');
  }
  final Object? decoded = jsonDecode(file.readAsStringSync());
  if (decoded is! Map<String, dynamic>) {
    throw FetchException('book_names.json must be a JSON object');
  }
  final Map<String, (String, int)> result = <String, (String, int)>{};
  decoded.forEach((String key, Object? value) {
    final String sourceKey = key;
    if (value is! Map<String, dynamic>) {
      throw FetchException(
        'book_names.json["$sourceKey"] entry is not an object',
      );
    }
    final String dbName = value['dbName'] as String? ?? '';
    final Object? orderRaw = value['order'];
    final int? order = orderRaw is int ? orderRaw : int.tryParse('$orderRaw');
    if (dbName.isEmpty || order == null) {
      throw FetchException(
        'book_names.json["$sourceKey"] must be {dbName, order}',
      );
    }
    result[sourceKey] = (dbName, order);
  });
  return result;
}

/// Parses the drbo.org homepage for the per-book verbatim names (bk code ->
/// name, first anchor per book code wins) and hard-fails unless exactly 73
/// sequential book codes are present.
Map<int, String> _parseDrboBookNames(String homepageHtml, String debugLabel) {
  final Map<int, String> names = <int, String>{};
  for (final RegExpMatch match in _drboBookAnchor.allMatches(homepageHtml)) {
    final int bk = int.parse(match.group(1)!);
    final String inner = match.group(2)!;
    final String name = _stripHtmlTags(
      _drboAsteriskGlyph.allMatches(inner).length == 0
          ? inner
          : inner.replaceAll(_drboAsteriskGlyph, ''),
    ).trim();
    if (name.isEmpty) {
      throw FetchException('$debugLabel: empty book name for bk=$bk');
    }
    if (!names.containsKey(bk)) {
      names[bk] = name;
    }
  }
  if (names.length != 73) {
    throw FetchException(
      '$debugLabel: expected 73 distinct book codes on the homepage, found ${names.length}',
    );
  }
  for (int bk = 1; bk <= 73; bk++) {
    if (!names.containsKey(bk)) {
      throw FetchException(
        '$debugLabel: book code $bk missing from the homepage',
      );
    }
  }
  return names;
}

/// Builds the per-drbo-book effective chapter-count table: cpdv chapter
/// counts from `expected_structure.json` (Vulgate basis) keyed through
/// book_names.json's drbo-name dbName mapping, with any
/// `scrape.chapterCountOverrides` applied on top. Also returns the list of
/// override books whose cpdv count was overridden (for run logging).
(Map<int, int>, List<String>) _drboChapterCountTable({
  required Map<String, (String, int)> keyToBook,
  required Map<int, String> drboNames,
  required String expectedStructurePath,
  required Map<String, dynamic> scrape,
}) {
  final File file = File(expectedStructurePath);
  if (!file.existsSync()) {
    throw FetchException(
      'expected_structure.json not found: $expectedStructurePath',
    );
  }
  final Object? decoded = jsonDecode(file.readAsStringSync());
  final Object? translations = decoded is Map<String, dynamic>
      ? decoded['translations']
      : null;
  final Object? cpdv = translations is Map<String, dynamic>
      ? translations['cpdv']
      : null;
  final Object? chapters = cpdv is Map<String, dynamic>
      ? cpdv['chapters']
      : null;
  if (chapters is! Map<String, dynamic>) {
    throw FetchException(
      'expected_structure.json has no translations.cpdv.chapters table',
    );
  }
  final Map<String, int> countsByDbName = <String, int>{};
  chapters.forEach((String dbName, Object? perBook) {
    if (perBook is! Map<String, dynamic>) {
      throw FetchException(
        'expected_structure.json cpdv book "$dbName" is not an object',
      );
    }
    countsByDbName[dbName] = perBook.length;
  });

  final Map<String, int> overrides = <String, int>{};
  final Object? overridesRaw = scrape['chapterCountOverrides'];
  if (overridesRaw is Map<String, dynamic>) {
    overridesRaw.forEach((String bk, Object? count) {
      final int? parsed = count is int ? count : int.tryParse('$count');
      if (parsed == null || parsed < 1) {
        throw FetchException(
          'scrape.chapterCountOverrides["$bk"] is not a positive count',
        );
      }
      overrides[bk] = parsed;
    });
  }

  final Map<int, int> table = <int, int>{};
  final List<String> overridden = <String>[];
  for (final MapEntry<int, String> entry in drboNames.entries) {
    final int bk = entry.key;
    final String name = entry.value;
    final (String, int)? mapping = keyToBook[name];
    if (mapping == null) {
      throw FetchException(
        'book_names.json has no entry for drbo.org book name "$name" (bk=$bk); '
        'commit the updated book-name map before scraping',
      );
    }
    final int? cpdvCount = countsByDbName[mapping.$1];
    if (cpdvCount == null) {
      throw FetchException(
        'expected_structure.json has no cpdv chapter count for "${mapping.$1}" '
        '(drbo.org bk=$bk "$name")',
      );
    }
    final String key = '$bk';
    if (overrides.containsKey(key)) {
      table[bk] = overrides[key]!;
      if (overrides[key]! != cpdvCount) {
        stdout.writeln(
          '[scrape]   bk=$bk "$name": chapter count overridden from the cpdv '
          'table ($cpdvCount -> ${overrides[key]!}); verified against the '
          'live 404 boundary at run time',
        );
        overridden.add(
          'bk=$bk "$name": cpdv=$cpdvCount override=${overrides[key]!}',
        );
      } else {
        stdout.writeln(
          '[scrape]   bk=$bk "$name": chapter count override equals the cpdv '
          'table ($cpdvCount)',
        );
      }
    } else {
      table[bk] = cpdvCount;
    }
  }
  return (table, overridden);
}

/// Strips HTML tags from [html] (after footnote/script removal by the caller).
String _stripHtmlTags(String html) {
  return html
      .replaceAll(_drboScriptBlock, '')
      .replaceAll(_drboNoteBlock, '')
      .replaceAll(RegExp(r'<[^>]*>'), '');
}

/// Decodes the HTML entities drbo.org pages use, then rejects any residual
/// entity escapes so no markup leak can slip into the snapshot.
String _decodeHtmlEntities(String text, String debugLabel) {
  String result = text
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&quot;', '"')
      .replaceAll('&apos;', "'")
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAllMapped(RegExp(r'&#(\d+);'), (Match m) {
        final int code = int.parse(m.group(1)!);
        if (code < 32 || code > 0x10FFFF) {
          throw FetchException(
            '$debugLabel: unexpected character entity &#$code;',
          );
        }
        return String.fromCharCode(code);
      })
      .replaceAllMapped(RegExp(r'&#x([0-9a-fA-F]+);'), (Match m) {
        final int code = int.parse(m.group(1)!, radix: 16);
        if (code < 32 || code > 0x10FFFF) {
          throw FetchException(
            '$debugLabel: unexpected character entity &#x${m.group(1)!};',
          );
        }
        return String.fromCharCode(code);
      });
  result = result.replaceAll('&amp;', '&');
  if (result.contains(RegExp(r'&[a-z]+;|&#\d+;|&#x[0-9a-fA-F]+;'))) {
    throw FetchException(
      '$debugLabel: residual HTML entity escape in text: ${result.length > 80 ? result.substring(0, 80) : result}',
    );
  }
  return result;
}

/// Parses one drbo.org chapter page into its verses with hard gates:
/// - every verse anchor must belong to the requested bk/ch (mismatch aborts);
/// - verse anchors must run 1..N sequentially with the anchor display text
///   agreeing with the anchored verse number (self-describing gate);
/// - footnote `<p class=note>` blocks, scripts and all tags are removed, the
///   last verse slice is cut at the content table's `</table>`, text is
///   entity-decoded/whitespace-collapsed and must be non-empty, and no
///   markup/entity escape may remain.
_DrboChapter _parseDrboChapterPage({
  required String html,
  required int requestedBk,
  required int requestedCh,
  required String bookKey,
  required String debugLabel,
}) {
  String text = html;
  if (text.startsWith('\uFEFF')) {
    text = text.substring(1);
  }
  final List<RegExpMatch> anchors = _drboVerseAnchorOpen
      .allMatches(text)
      .toList();
  if (anchors.isEmpty) {
    throw FetchException('$debugLabel: no verse anchors found');
  }
  final Map<int, String> verses = <int, String>{};
  int expectedVerse = 1;
  for (int i = 0; i < anchors.length; i++) {
    final RegExpMatch anchor = anchors[i];
    final RegExpMatch? params = _drboHrefParams.firstMatch(anchor.group(1)!);
    if (params == null) {
      throw FetchException(
        '$debugLabel: verse anchor ${i + 1} has an unparsable href: ${anchor.group(1)!}',
      );
    }
    final int bk = int.parse(params.group(1)!);
    final int ch = int.parse(params.group(2)!);
    final int verse = int.parse(params.group(3)!);
    if (bk != requestedBk || ch != requestedCh) {
      throw FetchException(
        '$debugLabel: verse anchor for verse $verse carries bk=$bk ch=$ch but '
        'the page was fetched as bk=$requestedBk ch=$requestedCh',
      );
    }
    if (verse != expectedVerse) {
      throw FetchException(
        '$debugLabel: verse anchor numbering is not contiguous: expected $expectedVerse, '
        'found $verse (bk=$bk ch=$ch)',
      );
    }
    final String display = _decodeHtmlEntities(
      _stripHtmlTags(
        text.substring(anchor.end, text.indexOf('</a>', anchor.end)),
      ),
      '$debugLabel verse $verse anchor',
    ).trim();
    if (display != expectedVerse.toString()) {
      throw FetchException(
        '$debugLabel: anchor display text "$display" disagrees with the '
        'anchored verse number $expectedVerse',
      );
    }
    final int textStart = text.indexOf('</a>', anchor.end) + '</a>'.length;
    final int textEnd;
    if (i + 1 < anchors.length) {
      textEnd = anchors[i + 1].start;
    } else {
      final int tableEnd = text.indexOf('</table>', textStart);
      if (tableEnd == -1) {
        throw FetchException(
          '$debugLabel: content table does not close after the last verse anchor',
        );
      }
      textEnd = tableEnd;
    }
    final String verseText = _decodeHtmlEntities(
      _stripHtmlTags(text.substring(textStart, textEnd)),
      '$debugLabel verse $verse',
    ).replaceAll(RegExp(r'\s+'), ' ').trim();
    if (verseText.isEmpty) {
      throw FetchException(
        '$debugLabel: verse $verse text is empty after markup removal',
      );
    }
    if (verseText.contains('\\') ||
        verseText.contains('<') ||
        verseText.contains('>')) {
      throw FetchException(
        '$debugLabel verse $verse: markup leak in text: ${verseText.length > 80 ? verseText.substring(0, 80) : verseText}',
      );
    }
    verses[verse] = verseText;
    expectedVerse += 1;
  }
  return _DrboChapter(bookKey, requestedBk, requestedCh, verses);
}

/// Scraped-source driver: verifies each book's one-past boundary page is
/// missing (404 redirect), scrapes every chapter 1..K into the per-page raw
/// cache, and - once the whole book set is complete and validated - writes
/// the joined snapshot and pins the manifest checksums.
Future<_FetchResult> _processScrapeSource({
  required String id,
  required Map<String, dynamic> entry,
  required Map<String, dynamic> scrape,
  required Directory assetsDir,
  required bool update,
  required bool smoke,
}) async {
  final String base = entry['url'] as String? ?? '';
  final String bookNamesUrl = scrape['bookNamesUrl'] as String? ?? '';
  final String codeFormat = scrape['codeFormat'] as String? ?? '';
  final Object? bookCountRaw = scrape['bookCount'];
  final int? crawlDelayRaw = scrape['crawlDelayMs'] is int
      ? scrape['crawlDelayMs'] as int
      : int.tryParse('${scrape['crawlDelayMs']}');
  if (!base.startsWith('https://') || !base.endsWith('/')) {
    throw FetchException('scrape url must be an HTTPS directory: $base');
  }
  if (!bookNamesUrl.startsWith('https://') ||
      _hostOf(bookNamesUrl) != _hostOf(base)) {
    throw FetchException(
      'scrape bookNamesUrl must live under the scrape base host: $bookNamesUrl vs $base',
    );
  }
  if (codeFormat != 'bbccc') {
    throw FetchException(
      'scrape.codeFormat must be "bbccc" (got "$codeFormat")',
    );
  }
  final int? bookCount = bookCountRaw is int
      ? bookCountRaw
      : int.tryParse('$bookCountRaw');
  if (bookCount != 73) {
    throw FetchException('scrape.bookCount must be 73 (got $bookCount)');
  }
  if (crawlDelayRaw == null || crawlDelayRaw < _scrapeCrawlDelayLowerBoundMs) {
    throw FetchException(
      'scrape.crawlDelayMs must be >= $_scrapeCrawlDelayLowerBoundMs per the '
      'upstream robots.txt crawl-delay (got $crawlDelayRaw)',
    );
  }
  final String chapterBase = base;
  final Uri baseUri = Uri.parse(chapterBase);
  final Uri bookNamesUri = Uri.parse(bookNamesUrl);

  final Directory packageRoot = _packageRoot();
  final Directory cacheDir = Directory(
    '${packageRoot.path}/$_scrapeCacheRelativeDir',
  );
  final File metadata = File('${cacheDir.path}/meta.json');
  final File dest = File(
    '${assetsDir.path}/${_snapshotFileNames[id] ?? '$id.json'}',
  );

  // Idempotent fast path: the final snapshot exists and its checksum is
  // pinned; verify it locally and skip all scraping.
  final String pinnedSha256 = entry['sha256'] as String? ?? '';
  if (!update && !smoke && dest.existsSync() && pinnedSha256.isNotEmpty) {
    final String actual = _sha256OfBytes(dest.readAsBytesSync());
    if (actual == pinnedSha256) {
      stdout.writeln('[ok]       $id -> ${dest.path} (checksum verified)');
      return _FetchResult.verified;
    }
    stderr.writeln(
      '[mismatch] $id (${dest.path}) sha256 mismatch; '
      'rebuilding deterministically from the .drc_cache scrape cache',
    );
  }

  final _ThrottledScraper scraper = _ThrottledScraper(crawlDelayRaw);
  final Map<String, (String, int)> keyToBook = _loadBookNamesForScrape(
    '${packageRoot.path}/$_bookNamesJsonRelativePath',
  );
  // Book names: cached homepage first, otherwise one throttled fetch.
  final File indexCache = File('${cacheDir.path}/index.htm');
  String homepage;
  if (indexCache.existsSync()) {
    homepage = utf8.decode(indexCache.readAsBytesSync());
    stdout.writeln('[scrape]   book-name index: cached (${indexCache.path})');
  } else {
    final r = await scraper.get(bookNamesUri, label: '$id book-name index');
    if (r.status != HttpStatus.ok || r.bytes == null) {
      throw FetchException(
        'HTTP ${r.status} for the book-name index $bookNamesUrl',
      );
    }
    homepage = utf8.decode(r.bytes!);
    cacheDir.createSync(recursive: true);
    indexCache.writeAsBytesSync(r.bytes!);
    stdout.writeln('[scrape]   book-name index: fetched ($bookNamesUrl)');
  }
  final Map<int, String> drboNames = _parseDrboBookNames(
    homepage,
    'book-name index',
  );

  if (smoke) {
    return await _scrapeSmoke(
      id: id,
      scraper: scraper,
      baseUri: baseUri,
      drboNames: drboNames,
      cacheDir: cacheDir,
      metadata: metadata,
      scrape: scrape,
      keyToBook: keyToBook,
    );
  }

  final (
    Map<int, int> counts,
    List<String> overridden,
  ) = _drboChapterCountTable(
    keyToBook: keyToBook,
    drboNames: drboNames,
    expectedStructurePath:
        '${packageRoot.path}/$_expectedStructureRelativePath',
    scrape: scrape,
  );
  final int totalChapters = counts.values.fold(
    0,
    (int sum, int count) => sum + count,
  );

  // Load (or initialize) the boundary-verification cache.
  final Map<String, dynamic> meta = metadata.existsSync()
      ? jsonDecode(metadata.readAsStringSync()) as Map<String, dynamic>
      : <String, dynamic>{'books': <String, dynamic>{}};
  final Object? booksRaw = meta['books'];
  if (booksRaw is! Map<String, dynamic>) {
    // repair or initialize
  }
  final Map<String, dynamic> booksMeta = booksRaw is Map<String, dynamic>
      ? booksRaw
      : <String, dynamic>{};
  meta['books'] = booksMeta;

  // Full crawl: boundary verification first (so a disagreement with the
  // cpdv-derived table aborts before any chapter pages are fetched).
  for (final MapEntry<int, String> bookEntry in drboNames.entries) {
    final int bk = bookEntry.key;
    final String name = bookEntry.value;
    final int expectedCount = counts[bk]!;
    if (!_boundaryVerified(booksMeta, bk, expectedCount)) {
      await _verifyBookBoundary(
        id: id,
        scraper: scraper,
        baseUri: baseUri,
        bk: bk,
        name: name,
        expectedCount: expectedCount,
        cacheDir: cacheDir,
        booksMeta: booksMeta,
        scrape: scrape,
      );
      _saveMeta(metadata, meta);
    }
  }

  // Scrape every chapter of every book.
  final Map<int, Map<int, Map<int, String>>> books =
      <int, Map<int, Map<int, String>>>{};
  int fetched = 0;
  int cached = 0;
  for (final MapEntry<int, String> bookEntry in drboNames.entries) {
    final int bk = bookEntry.key;
    final String name = bookEntry.value;
    final int expectedCount = counts[bk]!;
    final Map<int, Map<int, String>> chapterTexts = <int, Map<int, String>>{};
    for (int chapter = 1; chapter <= expectedCount; chapter++) {
      final String code = _drboCode(bk, chapter);
      final File rawCache = File('${cacheDir.path}/$code.htm');
      final String url = '${baseUri.toString()}$code.htm';
      String page;
      if (rawCache.existsSync()) {
        page = utf8.decode(rawCache.readAsBytesSync());
        cached += 1;
      } else {
        cacheDir.createSync(recursive: true);
        final r = await scraper.get(Uri.parse(url), label: '$id chapter $code');
        if (_drboIsMissingPage(r.status, r.location)) {
          throw FetchException(
            'bk=$bk "$name" chapter $chapter ($url) does not exist although '
            'the expected count is $expectedCount; aborting (boundary '
            'disagreement? adjust scrape.chapterCountOverrides)',
          );
        }
        if (r.status != HttpStatus.ok || r.bytes == null) {
          throw FetchException('HTTP ${r.status} for $url');
        }
        rawCache.writeAsBytesSync(r.bytes!);
        page = utf8.decode(r.bytes!);
        fetched += 1;
      }
      final _DrboChapter parsed = _parseDrboChapterPage(
        html: page,
        requestedBk: bk,
        requestedCh: chapter,
        bookKey: name,
        debugLabel: '$name $chapter ($code.htm)',
      );
      chapterTexts[chapter] = parsed.verses;
    }
    books[bk] = chapterTexts;
    final int bookVerses = chapterTexts.values.fold(
      0,
      (int sum, Map<int, String> verses) => sum + verses.length,
    );
    stdout.writeln(
      '[scrape]   bk=$bk "$name": $expectedCount chapters, '
      '$bookVerses verses (fetched $fetched, cached $cached so far)',
    );
  }

  // Shape-validate the full join before writing: verse keys exactly 1..N
  // (the same gate validate_sources.dart applies to joined JSON snapshots).
  final Map<String, Map<String, dynamic>> joined =
      <String, Map<String, dynamic>>{};
  int chapterTotal = 0;
  int verseTotal = 0;
  for (final MapEntry<int, String> bookEntry in drboNames.entries) {
    final int bk = bookEntry.key;
    final String name = bookEntry.value;
    final Map<int, Map<int, String>> chapterTexts = books[bk]!;
    joined[name] = <String, dynamic>{
      for (final int chapter in chapterTexts.keys)
        '$chapter': <String, String>{
          for (final int verse in chapterTexts[chapter]!.keys)
            '$verse': chapterTexts[chapter]![verse]!,
        },
    };
    chapterTotal += chapterTexts.length;
    verseTotal += chapterTexts.values.fold(
      0,
      (int sum, Map<int, String> verses) => sum + verses.length,
    );
  }
  if (joined.length != bookCount!) {
    throw FetchException(
      'scrape produced ${joined.length} books, manifest expects $bookCount',
    );
  }
  if (chapterTotal != totalChapters) {
    throw FetchException(
      'scrape produced $chapterTotal chapters, expected $totalChapters from the count table',
    );
  }

  cacheDir.createSync(recursive: true);
  const JsonEncoder encoder = JsonEncoder.withIndent('  ');
  final List<int> bytes = utf8.encode('${encoder.convert(joined)}\n');
  dest.writeAsBytesSync(bytes);
  final String sha256Hex = _sha256OfBytes(bytes);
  stdout.writeln(
    '[scrape]   complete: wrote ${dest.path} ($chapterTotal chapters, '
    '$verseTotal verses, ${bytes.length} bytes); '
    'fetched $fetched, cached $cached; min request gap '
    '${scraper.minGapMs}ms over ${scraper.requestCount} requests',
  );
  entry['sha256'] = sha256Hex;
  entry['fileSize'] = bytes.length;
  entry['fetchedAt'] = DateTime.now().toUtc().toIso8601String();
  return _FetchResult.pinned;
}

/// Reads the cached boundary verdict for [bk]; returns whether a previous run
/// already verified the one-past page missing for [expectedCount].
bool _boundaryVerified(
  Map<String, dynamic> booksMeta,
  int bk,
  int expectedCount,
) {
  final Object? raw = booksMeta['$bk'];
  if (raw is! Map<String, dynamic>) {
    return false;
  }
  final Object? count = raw['count'];
  final bool verified = raw['boundaryMissing'] == true;
  return verified && count is int && count == expectedCount;
}

/// Probes chapter expectedCount+1 for [bk]: it must NOT exist (404 redirect)
/// and records the verdict in the scrape cache meta. A live chapter past the
/// expected count triggers the count-disagreement protocol: probe up to a
/// small buffer further to report the verified structure, then fail - no data
/// is emitted on disagreement.
Future<void> _verifyBookBoundary({
  required String id,
  required _ThrottledScraper scraper,
  required Uri baseUri,
  required int bk,
  required String name,
  required int expectedCount,
  required Directory cacheDir,
  required Map<String, dynamic> booksMeta,
  required Map<String, dynamic> scrape,
}) async {
  final int buffer = 5;
  int probe = expectedCount + 1;
  while (true) {
    final String code = _drboCode(bk, probe);
    final String url = '${baseUri.toString()}$code.htm';
    final r = await scraper.get(
      Uri.parse(url),
      label: '$id boundary probe $code',
    );
    if (_drboIsMissingPage(r.status, r.location)) {
      booksMeta['$bk'] = <String, dynamic>{
        'count': expectedCount,
        'boundaryCode': code,
        'boundaryMissing': true,
        'verifiedAt': DateTime.now().toUtc().toIso8601String(),
      };
      return;
    }
    if (r.status != HttpStatus.ok || r.bytes == null) {
      throw FetchException('HTTP ${r.status} probing boundary page $url');
    }
    probe += 1;
    if (probe > expectedCount + buffer) {
      throw FetchException(
        'bk=$bk "$name": chapters exist beyond the expected count '
        '(expected $expectedCount, $code.htm exists). Scrape chapter-count '
        'override required; no data emitted.',
      );
    }
  }
}

/// Writes the scrape-cache metadata atomically enough for single-process use.
void _saveMeta(File metadata, Map<String, dynamic> meta) {
  Directory(metadata.parent.path).createSync(recursive: true);
  const JsonEncoder encoder = JsonEncoder.withIndent('  ');
  metadata.writeAsStringSync('${encoder.convert(meta)}\n');
}

/// `--smoke` run for a scraped source: fetches the book-name index (cached),
/// then exactly one chapter each for the pinned smoke books plus their
/// one-past boundary pages (which must not exist). Never writes the snapshot;
/// prints shape, anchor, timing and gate evidence.
Future<_FetchResult> _scrapeSmoke({
  required String id,
  required _ThrottledScraper scraper,
  required Uri baseUri,
  required Map<int, String> drboNames,
  required Directory cacheDir,
  required File metadata,
  required Map<String, dynamic> scrape,
  required Map<String, (String, int)> keyToBook,
}) async {
  final (
    Map<int, int> counts,
    List<String> overridden,
  ) = _drboChapterCountTable(
    keyToBook: keyToBook,
    drboNames: drboNames,
    expectedStructurePath:
        '${_packageRoot().path}/$_expectedStructureRelativePath',
    scrape: scrape,
  );
  final Map<String, dynamic> meta = metadata.existsSync()
      ? jsonDecode(metadata.readAsStringSync()) as Map<String, dynamic>
      : <String, dynamic>{'books': <String, dynamic>{}};
  final Object? booksRaw = meta['books'];
  final Map<String, dynamic> booksMeta = booksRaw is Map<String, dynamic>
      ? booksRaw
      : <String, dynamic>{};
  meta['books'] = booksMeta;
  for (final int bk in _scrapeSmokeBooks) {
    final String name = drboNames[bk]!;
    // one-past boundary page must NOT exist; cached verdicts are honored so
    // repeat smoke runs never re-fetch
    final int expectedCount = counts[bk]!;
    final String boundaryCode = _drboCode(bk, expectedCount + 1);
    if (_boundaryVerified(booksMeta, bk, expectedCount)) {
      stdout.writeln(
        '[smoke]     bk=$bk "$name": boundary verified in a previous run '
        '(count $expectedCount, boundary page $boundaryCode.htm missing)',
      );
    } else {
      final r = await scraper.get(
        Uri.parse('${baseUri.toString()}$boundaryCode.htm'),
        label: '$id boundary probe $boundaryCode [smoke]',
      );
      if (!_drboIsMissingPage(r.status, r.location)) {
        throw FetchException(
          'smoke: boundary page $boundaryCode.htm for bk=$bk "$name" exists '
          '(chapter count table disagrees with the live site)',
        );
      }
      booksMeta['$bk'] = <String, dynamic>{
        'count': expectedCount,
        'boundaryCode': boundaryCode,
        'boundaryMissing': true,
        'verifiedAt': DateTime.now().toUtc().toIso8601String(),
      };
      _saveMeta(metadata, meta);
      stdout.writeln(
        '[smoke]     bk=$bk "$name": boundary page $boundaryCode.htm missing (verified live)',
      );
    }

    // the chapter page itself
    final String code = _drboCode(bk, 1);
    final File rawCache = File('${cacheDir.path}/$code.htm');
    final String url = '${baseUri.toString()}$code.htm';
    String page;
    if (rawCache.existsSync()) {
      page = utf8.decode(rawCache.readAsBytesSync());
      stdout.writeln('[smoke]     $code.htm: cached');
    } else {
      final rc = await scraper.get(
        Uri.parse(url),
        label: '$id chapter $code [smoke]',
      );
      if (rc.status != HttpStatus.ok || rc.bytes == null) {
        throw FetchException('smoke: HTTP ${rc.status} for $url');
      }
      rawCache.writeAsBytesSync(rc.bytes!);
      page = utf8.decode(rc.bytes!);
      stdout.writeln('[smoke]     $code.htm: fetched ($url)');
    }
    final _DrboChapter parsed = _parseDrboChapterPage(
      html: page,
      requestedBk: bk,
      requestedCh: 1,
      bookKey: name,
      debugLabel: 'smoke-$name-1',
    );
    stdout.writeln(
      '[smoke]     bk=$bk "$name" ch1: ${parsed.verses.length} verses; '
      'book_names maps "$name" -> "${keyToBook[name]!.$1}" order ${keyToBook[name]!.$2}',
    );
    final MapEntry<int, String> first = parsed.verses.entries.first;
    stdout.writeln(
      '[smoke]     sample $name 1:${first.key}: '
      '"${first.value.length > 70 ? first.value.substring(0, 70) : first.value}"',
    );
    stdout.writeln(
      '[smoke]     sample $name 1:1 (full): "${parsed.verses[1]}"',
    );
  }
  final String gapProof = scraper.minGapMs == -1
      ? 'no requests issued (all served from the .drc_cache)'
      : 'min inter-request gap ${scraper.minGapMs}ms '
            '(crawlDelayMs honor proof over ${scraper.requestCount} requests)';
  stdout.writeln('[smoke]     requests: ${scraper.requestCount}; $gapProof');
  return _FetchResult.verified;
}

/// The host of a URL string (for the scraper allowlist check).
String _hostOf(String url) => Uri.parse(url).host;

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
