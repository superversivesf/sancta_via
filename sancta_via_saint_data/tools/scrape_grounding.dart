// CE grounding scrape (Task 2 of the saint-histories plan).
//
// Reads the pinned selection in `data/grounding/selection.json` (the
// accepted 1:1 slug<->article pairs), fetches each referenced Catholic
// Encyclopedia article from newadvent.org, strips the CE site boilerplate,
// and saves the clean text as:
//   data/grounding/<ceCode>.txt   clean article text (paragraphs joined
//                                 with blank lines)
//   data/grounding/manifest.json  one row per grounded slug with sha256,
//                                 char count, and fetchedAt
// Every selection match row gains `grounded: true|false`.
//
// Boilerplate stripped (`scrapeGroundingArticle`): the `capitalcity` /
// `mi5` site header, search box, A-Z letter nav, and breadcrumbs (all sit
// before the article `<h1>`), the "help support the mission" download
// promo, ad divs and scripts, the `.pub` "About this page" block with its
// APA/MLA citations and approbation, the copyright/CONTACT-US footer, any
// "See also" tail paragraph, `[^N]` footnote markers, and every leftover
// tag or `../cathen` link artifact. Paragraph text is entity-decoded with
// the Task 1 decoder.
//
// Polite scraping (Global Constraints): >= 2.2 s between requests, two
// attempts per URL (pacing honored before every attempt), robots rules
// honored, resumable — an existing non-empty `<ceCode>.txt` is never
// re-fetched. Failures are recorded per slug and the run exits 1; a
// re-run retries only the missing articles.
//
// Dev-only: tools/ is never imported by runtime code.
//
// Usage (from the package root):
//   dart run tools/scrape_grounding.dart [--refresh]
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;
import 'package:http/http.dart' as http;

// Reuses the Task 1 entity/tag decoder and robots helpers so both tools
// agree on text decoding and scrape politeness.
import 'select_ce_matches.dart'
    show decodeEntities, loadDisallowPrefixes, stripTags;

/// Polite, identifiable UA for all requests to newadvent.org.
const String _userAgent =
    'sancta_via_dev/0.1 (CE grounding scrape; ground-truth build; contact via repo)';

/// Minimum gap between consecutive requests to newadvent.org.
const Duration _minRequestGap = Duration(milliseconds: 2200);

/// Per-request timeout.
const Duration _requestTimeout = Duration(seconds: 30);

/// Sentinel separating HTML paragraphs during extraction; a private-use
/// codepoint that cannot occur in the source pages.
const String _paragraphSentinel = '\uE000';

/// Lowercase markers that drop a whole paragraph when present in it. Body
/// text of 1907-12 encyclopedia articles never contains the site's modern
/// chrome (citation blocks, promo, footer); the marker net also makes the
/// extraction robust when the `.pub` cut markers are missing.
const List<String> _boilerplateMarkers = <String>[
  'help support the mission',
  'instant download',
  'new advent',
  'newadvent.org',
  'apa citation',
  'mla citation',
  'ecclesiastical approbation',
  'contact information',
  'copyright ',
  'advertise',
];

// ---------------------------------------------------------------------------
// Result types
// ---------------------------------------------------------------------------

/// One scraped CE article: the extracted `<h1>` title and the clean
/// paragraph text.
class GroundingArticle {
  /// Article title, e.g. `St. Francis of Assisi`.
  final String title;

  /// Clean body text; paragraphs separated by single blank lines.
  final String text;

  /// Creates an article.
  const GroundingArticle({required this.title, required this.text});
}

/// One successfully grounded slug (manifest row content).
class ScrapeResult {
  final String slug;
  final String ceCode;
  final String url;
  final String file;
  final int chars;
  final String sha256;
  final String fetchedAt;

  /// Creates a result.
  const ScrapeResult({
    required this.slug,
    required this.ceCode,
    required this.url,
    required this.file,
    required this.chars,
    required this.sha256,
    required this.fetchedAt,
  });
}

/// A slug whose article could not be fetched or extracted this run.
class ScrapeFailure {
  final String slug;
  final String ceCode;
  final String url;
  final String reason;

  /// Creates a failure.
  const ScrapeFailure({
    required this.slug,
    required this.ceCode,
    required this.url,
    required this.reason,
  });
}

/// Fatal tool error surfaced with exit code 1.
class ScrapeGroundingException implements Exception {
  final String message;

  /// Creates an exception with [message].
  ScrapeGroundingException(this.message);

  @override
  String toString() => message;
}

// ---------------------------------------------------------------------------
// Extraction (pure; exercised by the fixture tests)
// ---------------------------------------------------------------------------

final RegExp _h1Pattern = RegExp(r'<h1[^>]*>([\s\S]*?)</h1>');
final RegExp _pageTitlePattern = RegExp(r'<title[^>]*>([\s\S]*?)</title>');
final RegExp _pubDivPattern = RegExp(r'<div\s+class=.pub');
final RegExp _footerDivPattern = RegExp(r'<div\s+id=.ogdenville');
final RegExp _springfieldPattern = RegExp(r'<div\s+id=.springfield2');
final RegExp _closedHeadPattern = RegExp(r'</head>');
final RegExp _scriptPattern = RegExp(r'<script\b[\s\S]*?</script>');
final RegExp _stylePattern = RegExp(r'<style\b[\s\S]*?</style>');
final RegExp _footnotePattern = RegExp(r'\[\^?\d+\]');
final RegExp _pageMarkerPrefix = RegExp(
  r'^CATHOLIC ENCYCLOPEDIA:\s*',
  caseSensitive: false,
);
final RegExp _seeAlsoStart = RegExp(r'^see also\b');

/// Collapses whitespace runs to single spaces and trims.
String _collapseWhitespace(String input) {
  return input.replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// Cleans a candidate title: strips tags, decodes entities, collapses
/// whitespace.
String _cleanTitle(String raw) {
  return _collapseWhitespace(decodeEntities(stripTags(raw)));
}

/// Drops boilerplate, "See also" tails, and emptiness; collapses each
/// surviving paragraph to single-spaced text.
List<String> _extractParagraphs(String region) {
  String scrubbed = region
      .replaceAll(_scriptPattern, ' ')
      .replaceAll(_stylePattern, ' ')
      .replaceAll('</p>', _paragraphSentinel)
      .replaceAll(RegExp(r'<br\s*/?>'), ' ');
  scrubbed = decodeEntities(stripTags(scrubbed));
  scrubbed = scrubbed.replaceAll(_footnotePattern, '');

  final List<String> kept = <String>[];
  for (final String raw in scrubbed.split(_paragraphSentinel)) {
    final String paragraph = _collapseWhitespace(raw);
    if (paragraph.isEmpty) {
      continue;
    }
    if (_seeAlsoStart.hasMatch(paragraph.toLowerCase())) {
      continue;
    }
    final String folded = paragraph.toLowerCase();
    if (_boilerplateMarkers.any(folded.contains)) {
      continue;
    }
    kept.add(paragraph);
  }
  return kept;
}

/// Extracts `{text, title}` from a real New Advent CE article page:
/// everything between the article `<h1>` and the `.pub` citation block,
/// with site chrome, promos, ads, citations, and copyright stripped.
GroundingArticle scrapeGroundingArticle(String html) {
  final RegExpMatch? h1 = _h1Pattern.firstMatch(html);
  String title = h1 != null ? _cleanTitle(h1.group(1)!) : '';
  if (title.isEmpty) {
    final RegExpMatch? pageTitle = _pageTitlePattern.firstMatch(html);
    if (pageTitle != null) {
      title = _cleanTitle(
        pageTitle.group(1)!,
      ).replaceFirst(_pageMarkerPrefix, '');
    }
  }

  // The body region starts after the article `<h1>` (which sits inside the
  // `springfield2` content div, after all site chrome). Defensive fallbacks
  // for pages that skip the h1.
  final int start;
  if (h1 != null) {
    start = h1.end;
  } else {
    final RegExpMatch? springfield = _springfieldPattern.firstMatch(html);
    final RegExpMatch? closedHead = _closedHeadPattern.firstMatch(html);
    if (springfield != null) {
      start = springfield.end;
    } else if (closedHead != null) {
      start = closedHead.end;
    } else {
      start = 0;
    }
  }

  // The body region ends before the `pub`(About this page) citation block,
  // falling back to the footer bar div, then the whole rest of the page
  // (the paragraph filter still removes its chrome).
  final RegExpMatch? pub = _pubDivPattern.firstMatch(html);
  final RegExpMatch? footer = _footerDivPattern.firstMatch(html);
  final int end;
  if (pub != null && pub.start >= start) {
    end = pub.start;
  } else if (footer != null && footer.start >= start) {
    end = footer.start;
  } else {
    end = html.length;
  }
  if (start >= end) {
    throw ScrapeGroundingException('could not locate the article body region');
  }

  final List<String> paragraphs = _extractParagraphs(
    html.substring(start, end),
  );
  if (paragraphs.isEmpty) {
    throw ScrapeGroundingException('article body extracted to no text');
  }
  return GroundingArticle(title: title, text: paragraphs.join('\n\n'));
}

// ---------------------------------------------------------------------------
// Fetch + persist helpers
// ---------------------------------------------------------------------------

/// Reads [bytes] as UTF-8, falling back to latin-1 when the page is not
/// valid UTF-8 (the 1907-12 source predates Unicode; New Advent serves
/// UTF-8 with `<meta charset="utf-8">`, but a legacy mirror may not).
String decodeBody(List<int> bytes) {
  try {
    return utf8.decode(bytes);
  } on FormatException {
    return latin1.decode(bytes, allowInvalid: true);
  }
}

/// Sha-256 of the UTF-8 bytes of [text], hex-encoded — the digest of the
/// exact bytes saved to disk.
String sha256OfText(String text) {
  return crypto.sha256.convert(utf8.encode(text)).toString();
}

/// GET with the polite UA and timeout; pacing honored before every
/// attempt. Returns the decoded body on HTTP 200.
Future<String> _fetchBody(Uri url, Stopwatch pacingClock) async {
  String lastError = '';
  for (int attempt = 0; attempt < 2; attempt++) {
    final int remaining =
        _minRequestGap.inMilliseconds - pacingClock.elapsedMilliseconds;
    if (remaining > 0) {
      await Future<void>.delayed(Duration(milliseconds: remaining));
    }
    pacingClock.reset();
    try {
      final http.Response response = await http
          .get(url, headers: <String, String>{'User-Agent': _userAgent})
          .timeout(_requestTimeout);
      if (response.statusCode == 200) {
        return decodeBody(response.bodyBytes);
      }
      lastError = 'HTTP ${response.statusCode}';
    } catch (error) {
      lastError = error.toString();
    }
  }
  throw ScrapeGroundingException('$lastError for ${url.path}');
}

/// The content of an already-grounded article file, or null when [path] is
/// absent or empty (resumability: a grounding file present from a previous
/// run means the article is not re-fetched).
String? existingGroundingText(String path) {
  final File file = File(path);
  if (!file.existsSync()) {
    return null;
  }
  final List<int> bytes = file.readAsBytesSync();
  if (bytes.isEmpty) {
    return null;
  }
  final String text = decodeBody(bytes);
  return text.isEmpty ? null : text;
}

// ---------------------------------------------------------------------------
// Output shapes (pinned by the plan)
// ---------------------------------------------------------------------------

/// manifest.json `articles` rows (pinned shape: exactly these keys).
List<Map<String, dynamic>> toManifestArticles({
  required List<ScrapeResult> articles,
}) {
  return <Map<String, dynamic>>[
    for (final ScrapeResult article in articles)
      <String, dynamic>{
        'slug': article.slug,
        'ceCode': article.ceCode,
        'url': article.url,
        'file': article.file,
        'chars': article.chars,
        'sha256': article.sha256,
        'fetchedAt': article.fetchedAt,
      },
  ];
}

/// manifest.json payload (pinned shape).
Map<String, dynamic> toManifestJson({
  required List<ScrapeResult> articles,
  required String generatedAt,
}) {
  return <String, dynamic>{
    'generatedAt': generatedAt,
    'articles': toManifestArticles(articles: articles),
  };
}

// ---------------------------------------------------------------------------
// Runner
// ---------------------------------------------------------------------------

/// Pretty JSON encoder used for the grounding JSON outputs.
const JsonEncoder _prettyEncoder = JsonEncoder.withIndent('  ');

/// The scrape outcome for one run.
class ScrapeRun {
  /// Successes, one row per grounded slug, in selection order.
  final List<ScrapeResult> results;

  /// Per-slug failures (exit 1 list).
  final List<ScrapeFailure> failures;

  /// Creates an outcome.
  const ScrapeRun({required this.results, required this.failures});
}

/// Runs the grounding scrape end to end:
///   * loads selection.json,
///   * fetches each unique article (2.2 s pacing, 2 attempts), skipping
///     existing `<ceCode>.txt` files,
///   * saves clean text + manifest.json,
///   * stamps `grounded: true|false` on every selection match row,
///   * reports failures per slug (the caller turns those into exit 1).
Future<ScrapeRun> run({bool refresh = false}) async {
  final Directory packageRoot = Directory.current;
  final String groundingDir = '${packageRoot.path}/data/grounding';
  final File selectionFile = File('$groundingDir/selection.json');
  if (!selectionFile.existsSync()) {
    throw ScrapeGroundingException(
      'missing ${selectionFile.path} — run tools/select_ce_matches.dart first',
    );
  }
  final Map<String, dynamic> selection =
      jsonDecode(selectionFile.readAsStringSync()) as Map<String, dynamic>;
  final List<Map<String, dynamic>> matches =
      (selection['matches'] as List<dynamic>).cast<Map<String, dynamic>>();
  stdout.writeln('selected matches: ${matches.length}');

  // Fetches are keyed by ceCode: every slug claiming one article is
  // grounded from a single fetch (the 1:1 discipline currently forbids
  // sharing, but the tool stays honest if that ever relaxes).
  final List<String> codesInOrder = <String>[];
  final Map<String, String> urlByCode = <String, String>{};
  final Map<String, List<String>> slugsByCode = <String, List<String>>{};
  for (final Map<String, dynamic> match in matches) {
    final String code = match['ceCode'] as String;
    if (!urlByCode.containsKey(code)) {
      codesInOrder.add(code);
      urlByCode[code] = match['ceUrl'] as String;
      slugsByCode[code] = <String>[];
    }
    slugsByCode[code]!.add(match['slug'] as String);
  }
  stdout.writeln('unique articles to ground: ${codesInOrder.length}');

  final Stopwatch pacingClock = Stopwatch();
  final Set<String> disallows = await loadDisallowPrefixes(
    ceCacheDir: Directory('$groundingDir/ce_index'),
    pacingClock: pacingClock,
  );
  for (final String prefix in disallows) {
    if (prefix.isNotEmpty && '/cathen/06221a.htm'.startsWith(prefix)) {
      throw ScrapeGroundingException(
        'robots.txt would disallow /cathen/: $prefix',
      );
    }
  }

  final List<ScrapeResult> results = <ScrapeResult>[];
  final List<ScrapeFailure> failures = <ScrapeFailure>[];
  int cachedCount = 0;
  int failedCodes = 0;
  for (final String code in codesInOrder) {
    final String url = urlByCode[code]!;
    final String path = '$groundingDir/$code.txt';
    final List<String> slugs = slugsByCode[code]!;

    final String? cached = refresh ? null : existingGroundingText(path);
    if (cached != null) {
      cachedCount++;
      final String fetchedAt = File(
        path,
      ).lastModifiedSync().toUtc().toIso8601String();
      final String digest = sha256OfText(cached);
      for (final String slug in slugs) {
        results.add(
          ScrapeResult(
            slug: slug,
            ceCode: code,
            url: url,
            file: '$code.txt',
            chars: cached.length,
            sha256: digest,
            fetchedAt: fetchedAt,
          ),
        );
      }
      continue;
    }

    try {
      final String html = await _fetchBody(Uri.parse(url), pacingClock);
      final GroundingArticle article = scrapeGroundingArticle(html);
      File(path).writeAsStringSync(article.text, mode: FileMode.write);
      final String fetchedAt = DateTime.now().toUtc().toIso8601String();
      for (final String slug in slugs) {
        results.add(
          ScrapeResult(
            slug: slug,
            ceCode: code,
            url: url,
            file: '$code.txt',
            chars: article.text.length,
            sha256: sha256OfText(article.text),
            fetchedAt: fetchedAt,
          ),
        );
      }
    } catch (error) {
      failedCodes++;
      for (final String slug in slugs) {
        failures.add(
          ScrapeFailure(slug: slug, ceCode: code, url: url, reason: '$error'),
        );
      }
      stdout.writeln('FAILED: $code (${slugs.join(', ')}): $error');
    }
  }

  // Manifest rows == successes, re-ordered to selection (rank) order.
  final Map<String, ScrapeResult> resultBySlug = <String, ScrapeResult>{};
  for (final ScrapeResult result in results) {
    resultBySlug.putIfAbsent(result.slug, () => result);
  }
  final List<ScrapeResult> rowOrder = <ScrapeResult>[];
  final List<String> groundedSlugs = <String>[];
  for (final Map<String, dynamic> match in matches) {
    final String slug = match['slug'] as String;
    final ScrapeResult? result = resultBySlug[slug];
    if (result != null) {
      rowOrder.add(result);
      groundedSlugs.add(slug);
    }
  }
  File('$groundingDir/manifest.json').writeAsStringSync(
    '${_prettyEncoder.convert(toManifestJson(articles: rowOrder, generatedAt: DateTime.now().toUtc().toIso8601String()))}\n',
  );

  // selection.json match rows gain `grounded: true|false`; every other
  // top-level key (generatedAt, drops, counts, recovered, ...) is
  // preserved.
  final Set<String> groundedSet = groundedSlugs.toSet();
  for (final Map<String, dynamic> match in matches) {
    match['grounded'] = groundedSet.contains(match['slug'] as String);
  }
  selectionFile.writeAsStringSync('${_prettyEncoder.convert(selection)}\n');

  stdout.writeln(
    'grounded: ${rowOrder.length} / ${matches.length} '
    '(${codesInOrder.length} unique articles; '
    'fetched this run: ${codesInOrder.length - cachedCount - failedCodes}, '
    'cached: $cachedCount, failed: $failedCodes)',
  );
  stdout.writeln('wrote: $groundingDir/manifest.json');
  stdout.writeln('wrote: $groundingDir/selection.json (grounded flags)');
  return ScrapeRun(results: rowOrder, failures: failures);
}

Future<void> main(List<String> args) async {
  try {
    final ScrapeRun scrapeRun = await run(refresh: args.contains('--refresh'));
    if (scrapeRun.failures.isNotEmpty) {
      stderr.writeln(
        'scrape_grounding: ${scrapeRun.failures.length} failures:',
      );
      for (final ScrapeFailure failure in scrapeRun.failures) {
        stderr.writeln(
          '  ${failure.slug} (${failure.ceCode}): ${failure.reason}',
        );
      }
      exitCode = 1;
    }
  } on ScrapeGroundingException catch (error) {
    stderr.writeln('scrape_grounding: $error');
    exitCode = 1;
  }
}
