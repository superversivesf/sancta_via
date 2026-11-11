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
//   - `fetchAndProcessOne` owns the per-URL retry budgets and pacing: every
//     request is spaced at least 250 ms from the last (measure-elapsed-then-
//     top-up, so slow downloads are not double-punished), a throttled
//     response (HTTP 429 / 5xx) backs off honoring `Retry-After` (else the
//     2s → 4s → 8s ladder, i.e. up to 4 attempts per URL), and exhaustion
//     surfaces as `FetchThrottledException` — a DEFERRAL that is printed
//     with a per-slug line and never recorded in the ledger, because the
//     next re-run re-attempts it automatically;
//   - permanent failure classes (other 4xx, unparseable URL, undecodable
//     body, connection/timeout beyond the single retry) get the original
//     retry-once budget and are then recorded as `{slug, url, error}` in
//     `data/image_failures.json`; the ledger starts from the previous
//     file's content (read + append), is deduplicated by slug on rewrite,
//     and drops the entry of any slug whose thumb exists or is freshly
//     written, so it always lists CURRENT failures.
// Requests are strictly serialized: one request in flight, no concurrency.
//
// Wikimedia bot-policy note: every request carries a descriptive
// `User-Agent` (`SanctaViaSaintDataBuild/1.0 (+https://sancta-via.net)`),
// which is required for upload.wikimedia.org access.
//
// Dev-only: tools/ is never imported by runtime code (the test files import
// the pure URL function and the loopback-stub-drivable fetch seam).
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
/// link; timeouts are permanent-class (see `fetchAndProcessOne`).
const Duration _requestTimeout = Duration(seconds: 120);

/// Politeness pacing: minimum spacing between the end of one HTTP request
/// and the start of the next — across retries AND across URLs (the top-up
/// runs after every completed request, including the last of each URL).
/// The controller's first full run drowned in HTTP 429s with zero pacing
/// (85 thumbs in ~1 minute); 250 ms keeps the loop under ~4 requests/s.
const Duration _defaultMinRequestGap = Duration(milliseconds: 250);

/// Backoff ladder for throttle-class responses (HTTP 429 / 5xx): the Nth
/// throttle error of a URL waits rung N (clamped at the last). Combined
/// with the initial request this gives a URL 4 fetch attempts against a
/// throttle burst before the run defers it to the next re-run.
const List<Duration> _throttleWaits = <Duration>[
  Duration(seconds: 2),
  Duration(seconds: 4),
  Duration(seconds: 8),
];

/// Cap on an honored `Retry-After` header: Wikimedia's own backoff hint is
/// obeyed, but one absurd value may not stall the whole background run.
const Duration _maxRetryAfterDelay = Duration(seconds: 60);

/// Pause before the single no-wait-budget retry for connection/timeout
/// errors (no HTTP status, no `Retry-After` to honor): a blip is not
/// re-hit instantly, and a URL failing twice is a ledger-able defect.
const Duration _connectionRetryWait = Duration(milliseconds: 750);

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
///
/// Internal to the tool, but public by name so the test files can drive
/// `fetchAndProcessOne` and `wikimediaThumbUrl` directly.
class ImageTarget {
  const ImageTarget(this.slug, this.url);

  final String slug;
  final String url;
}

/// The wait before the [attempt]-th (1-based) throttle retry of a URL.
///
/// A `Retry-After` header value in whole seconds ([retryAfter]) wins over
/// the ladder and is clamped to `_maxRetryAfterDelay`; anything it cannot
/// parse (null, non-integer, negative) falls back to the ladder, whose
/// [waits] default to 2s → 4s → 8s with the last rung repeated for any
/// further attempt. Pure: pinned by `test/tools/thumb_fetch_pacing_test.dart`.
Duration backoffDelayFor(
  int attempt, {
  String? retryAfter,
  List<Duration>? waits,
}) {
  final List<Duration> ladder = waits ?? _throttleWaits;
  if (retryAfter != null) {
    final int? seconds = int.tryParse(retryAfter.trim());
    if (seconds != null && seconds >= 0) {
      final Duration parsed = Duration(seconds: seconds);
      return parsed > _maxRetryAfterDelay ? _maxRetryAfterDelay : parsed;
    }
  }
  return ladder[(attempt - 1).clamp(0, ladder.length - 1)];
}

/// Spacing owed after a completed HTTP request: tops a fast request up to
/// [minRequestGap] between requests, while a slow download is not
/// double-punished (it already provided the spacing). Pure: pinned by
/// `test/tools/thumb_fetch_pacing_test.dart`.
Duration pacingDelayAfter(
  Duration previousRequestElapsed,
  Duration minRequestGap,
) {
  if (previousRequestElapsed >= minRequestGap) {
    return Duration.zero;
  }
  return minRequestGap - previousRequestElapsed;
}

/// A throttle-class fetch outcome (HTTP 429 / 5xx still throttled after the
/// backoff ladder): a server-load state, NOT a data defect. The caller
/// defers the URL to the next re-run and must NOT write it into the
/// permanent failure ledger.
class FetchThrottledException implements Exception {
  FetchThrottledException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// A permanent-class fetch outcome: HTTP 4xx other than 429, a URL that
/// cannot be parsed, an undecodable image body, or a connection/timeout
/// beyond the single retry. The caller records this in the failure ledger.
class FetchFailedException implements Exception {
  FetchFailedException(this.message);

  final String message;

  @override
  String toString() => message;
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
  final List<ImageTarget> targets = <ImageTarget>[];
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
        targets.add(ImageTarget(slug, url));
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
  int deferredNow = 0;
  int processed = 0;

  final http.Client client = http.Client();
  try {
    for (final ImageTarget target in targets) {
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
            deferredNow,
            skipped,
          );
        }
        continue;
      }
      // fetchAndProcessOne owns ALL retry budgets (throttle ladder with
      // Retry-After, the brief's single no-wait retry for permanent
      // classes) and classifies its failures; the loop only routes them:
      try {
        await fetchAndProcessOne(client, target, thumbFile);
        downloaded++;
        failures.remove(target.slug);
      } on FetchThrottledException catch (error) {
        // Transient server-side throttling: a re-run re-attempts this URL
        // (skip-existing), so it must NOT be recorded as an image failure —
        // the ledger only lists real data defects. Purge any ghost entry a
        // previous run recorded for this slug: a deferral is the opposite
        // of a recorded defect, never both.
        failures.remove(target.slug);
        deferredNow++;
        print('fetch_saint_images DEFERRED ${target.slug}: $error');
      } on FetchFailedException catch (error) {
        failedNow++;
        failures[target.slug] = <String, String>{
          'slug': target.slug,
          'url': target.url,
          'error': _shortError(error),
        };
        _writeFailures(failuresFile, failures);
        print('fetch_saint_images FAILURE ${target.slug}: $error');
      } on Object catch (error) {
        // Poison-pill guard: ANY other escape from the per-image path (the
        // decoders can throw ImageException; partFile.writeAsBytesSync and
        // partFile.renameSync can throw FileSystemException) is converted
        // into a recorded, ledgerable failure — the crawl records it and
        // CONTINUES instead of aborting with a nonzero exit on every re-run
        // at the same image.
        failedNow++;
        failures[target.slug] = <String, String>{
          'slug': target.slug,
          'url': target.url,
          'error': _shortError(error),
        };
        _writeFailures(failuresFile, failures);
        print(
          'fetch_saint_images FAILURE ${target.slug}: '
          '${failures[target.slug]!['error']}',
        );
      }
      processed++;
      if (processed % 100 == 0) {
        _printProgress(
          processed,
          targets.length,
          downloaded,
          failedNow,
          deferredNow,
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
    '  deferred (throttled, retry on next run): $deferredNow '
    '(not recorded in the ledger)',
  );
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
  int deferredNow,
  int skipped,
) {
  print(
    'fetch_saint_images [$processed/$total] '
    'downloaded=$downloaded failed=$failedNow '
    'deferred=$deferredNow skipped=$skipped',
  );
}

/// Fetches [target], center-crops square, resizes to 256×256 and encodes
/// the JPEG atomically at [thumbFile] (`.part` + rename, so an interrupted
/// run never leaves a half-written thumb that skip-exists would honor).
///
/// Retry + pacing policy (all budgets are per URL, inside this function so
/// the run loop stays a thin router):
///   - HTTP 429 / 5xx (throttle class): the [throttleWaits] backoff ladder
///     (default 2s → 4s → 8s), with a `Retry-After` header honored instead
///     of the rung when present; exhausted, throws
///     [FetchThrottledException] — the URL is DEFERRED to the next re-run
///     and must not be recorded as a permanent failure;
///   - every other error — other 4xx, unparseable URL, undecodable body,
///     connection/timeout — gets the brief's single immediate retry (with
///     [_connectionRetryWait] spacing for connection/timeout blips), then
///     throws [FetchFailedException] for the caller to ledger;
///   - every completed request is spaced by [minRequestGap] via
///     `pacingDelayAfter` (top-up model), across retries and URLs — the
///     first request of a URL pays nothing.
/// Public so `test/tools/thumb_fetch_pacing_test.dart` can drive it against
/// a loopback HTTP stub; [throttleWaits] is a test seam, not production
/// configuration (production callers use the default ladder).
Future<void> fetchAndProcessOne(
  http.Client client,
  ImageTarget target,
  File thumbFile, {
  List<Duration>? throttleWaits,
  Duration minRequestGap = _defaultMinRequestGap,
}) async {
  final String url = wikimediaThumbUrl(target.url, width: _requestThumbSize);
  final Uri uri;
  try {
    uri = Uri.parse(url);
  } on FormatException catch (error) {
    throw FetchFailedException('url could not be parsed: $url ($error)');
  }

  final List<Duration> waits = throttleWaits ?? _throttleWaits;
  int throttleRetries = 0;
  bool permanentRetried = false;
  final Stopwatch requestWatch = Stopwatch();
  Duration lastRequestElapsed = Duration.zero;
  bool firstRequest = true;

  while (true) {
    if (!firstRequest) {
      final Duration gap = pacingDelayAfter(lastRequestElapsed, minRequestGap);
      if (gap > Duration.zero) {
        await Future<void>.delayed(gap);
      }
    }
    firstRequest = false;

    requestWatch
      ..reset()
      ..start();
    http.Response response;
    try {
      response = await client
          .get(uri, headers: <String, String>{'User-Agent': _userAgent})
          .timeout(_requestTimeout);
    } on TimeoutException catch (error) {
      requestWatch.stop();
      lastRequestElapsed = requestWatch.elapsed;
      // No status code and no Retry-After to honor — but a consistent
      // timeout is a defect worth seeing in the ledger, so it only gets
      // the brief's single retry (not the throttle ladder).
      if (!permanentRetried) {
        permanentRetried = true;
        await Future<void>.delayed(_connectionRetryWait);
        continue;
      }
      throw FetchFailedException(
        'timed out after ${_requestTimeout.inSeconds}s: $url '
        '(${_shortError(error)})',
      );
    } on Object catch (error) {
      // Connection-level failure (SocketException, http.ClientException, …).
      requestWatch.stop();
      lastRequestElapsed = requestWatch.elapsed;
      if (!permanentRetried) {
        permanentRetried = true;
        await Future<void>.delayed(_connectionRetryWait);
        continue;
      }
      throw FetchFailedException(
        'connection failed for $url: ${_shortError(error)}',
      );
    }
    requestWatch.stop();
    lastRequestElapsed = requestWatch.elapsed;

    if (response.statusCode == 200) {
      try {
        _writeThumb(response, url, thumbFile);
      } on Object catch (error) {
        // Decode/encode failures (the decoders throw ImageException for
        // corrupt payloads) and .part write/rename failures
        // (FileSystemException) surface here as well as undecodable bodies;
        // ALL are permanent classes sharing the brief's single immediate
        // retry, and NONE may escape raw past this function (poison pill).
        if (!permanentRetried) {
          permanentRetried = true;
          continue;
        }
        if (error is FetchFailedException) {
          rethrow;
        }
        throw FetchFailedException(
          'image processing failed for $url: ${_shortError(error)}',
        );
      }
      final Duration gap = pacingDelayAfter(lastRequestElapsed, minRequestGap);
      if (gap > Duration.zero) {
        await Future<void>.delayed(gap);
      }
      return;
    }

    if (response.statusCode == 429 || response.statusCode >= 500) {
      if (throttleRetries >= waits.length) {
        throw FetchThrottledException(
          'still throttled (last HTTP ${response.statusCode}) after '
          '${throttleRetries + 1} attempts: $url',
        );
      }
      throttleRetries++;
      await Future<void>.delayed(
        backoffDelayFor(
          throttleRetries,
          retryAfter: response.headers[HttpHeaders.retryAfterHeader],
          waits: waits,
        ),
      );
      continue;
    }

    // Every other status (400, 403, 404, …) is permanent for this URL.
    if (!permanentRetried) {
      permanentRetried = true;
      continue;
    }
    throw FetchFailedException('HTTP ${response.statusCode} from $url');
  }
}

/// Decodes `response`'s body, center-crops square, resizes to 256×256 and
/// writes the JPEG atomically at [thumbFile]. Decode failure is a
/// permanent data defect: [FetchFailedException].
void _writeThumb(http.Response response, String url, File thumbFile) {
  final img.Image? decoded = img.decodeImage(
    Uint8List.fromList(response.bodyBytes),
    frame: 0,
  );
  if (decoded == null) {
    throw FetchFailedException(
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
