// Wikipedia grounding scrape (modern-saint-histories plan Task 2).
//
// For every seed record whose `sources` list carries a
// `https://en.wikipedia.org/wiki/...` URL, fetches the article's plain text
// via the MediaWiki API (`action=query&prop=extracts&explaintext=1`), and
// saves the clean text as:
//   data/grounding_wikipedia/<slug>.txt   article plain text
//   data/grounding_wikipedia/manifest.json  one row per grounded slug with
//                                         sha256, char count, fetchedAt,
//                                         and the article title
// Manifest rows use the CE manifest's entry shape (slug/url/file/chars/
// sha256/fetchedAt) plus `title`, so the build merge treats both classes
// uniformly.
//
// Disambiguation guard (Review Focus): the first line of the extract must
// contain the seed's name or the URL-derived article title (accent-folded);
// otherwise the slug is recorded as a failure, NOTHING is written for it,
// and the run exits 1 at the end. This keeps a same-named wrong person from
// ever entering the grounding corpus.
//
// Polite scraping: >= 1.1 s between requests, two attempts per URL, resumable
// — an existing non-empty `<slug>.txt` is never re-fetched.
//
// Dev-only: tools/ is never imported by runtime code.
//
// Usage (from the package root):
//   dart run tools/wikipedia_grounding.dart [--slug <slug> ...] [--batch
//   <data/wikipedia_batch.json>] [--refresh]
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;
import 'package:http/http.dart' as http;

import 'package:saint_data/src/utils/history_source.dart';

const String _kApiBase = 'https://en.wikipedia.org/w/api.php';

/// One seed record to scrape: the slug, the display name (for the
/// disambiguation guard), and the seed's source URLs.
class SaintSeedRow {
  const SaintSeedRow({
    required this.slug,
    required this.name,
    required this.sources,
  });
  final String slug;
  final String name;
  final List<String> sources;
}

/// Per-slug scrape failures (disambiguation guard or HTTP/extract errors).
class ScrapeFailure {
  const ScrapeFailure({required this.slug, required this.reason});
  final String slug;
  final String reason;
}

/// The result of one scraper run.
class ScrapeOutcome {
  const ScrapeOutcome({required this.written, required this.failures});
  final List<String> written;
  final List<ScrapeFailure> failures;
}

/// The accent-folded, de-prefixed comparable form of a saint display name
/// ("St. Thérèse of Lisieux" -> "therese of lisieux").
String comparableName(String name) {
  return foldAccentsLite(
    name.toLowerCase(),
  ).replaceAll(RegExp(r'^st\.?\s+'), '').replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// Accent folding without pulling the whole Task 1 normalizer in.
String foldAccentsLite(String input) {
  const Map<String, String> table = <String, String>{
    'á': 'a',
    'à': 'a',
    'â': 'a',
    'ä': 'a',
    'ã': 'a',
    'ā': 'a',
    'å': 'a',
    'æ': 'ae',
    'ç': 'c',
    'é': 'e',
    'è': 'e',
    'ê': 'e',
    'ë': 'e',
    'ē': 'e',
    'í': 'i',
    'ì': 'i',
    'î': 'i',
    'ï': 'i',
    'ī': 'i',
    'ñ': 'n',
    'ó': 'o',
    'ò': 'o',
    'ô': 'o',
    'ö': 'o',
    'õ': 'o',
    'ø': 'o',
    'ō': 'o',
    'œ': 'oe',
    'ß': 'ss',
    'ú': 'u',
    'ù': 'u',
    'û': 'u',
    'ü': 'u',
    'ū': 'u',
    'ý': 'y',
    'ÿ': 'y',
    'ž': 'z',
    'š': 's',
    'ć': 'c',
    'č': 'c',
    'ł': 'l',
    'ź': 'z',
    'ż': 'z',
    'ń': 'n',
    'ę': 'e',
    'ą': 'a',
  };
  return input.split('').map((String c) => table[c] ?? c).join();
}

/// The article title from a wikipedia URL ("Pope_John_Paul_II" ->
/// "Pope John Paul II"). `Uri.parse` already percent-decodes path segments.
String titleFromUrl(String url) {
  final Uri uri = Uri.parse(url);
  return uri.pathSegments.last.replaceAll('_', ' ');
}

/// Extracts the plain text of the FIRST response page; throws a `StateError`
/// when the extract is empty (a disambiguation page yields no extract).
String extractPlainText(String responseBody) {
  final Object? decoded = jsonDecode(responseBody);
  final Map<String, dynamic> envelope = decoded is Map<String, dynamic>
      ? decoded
      : <String, dynamic>{};
  final Map<String, dynamic> query =
      (envelope['query'] as Map<String, dynamic>?) ?? <String, dynamic>{};
  final List<dynamic> pages =
      (query['pages'] as List<dynamic>?) ?? const <dynamic>[];
  if (pages.isEmpty) {
    throw StateError('extracts response has no page');
  }
  final Map<String, dynamic> page = pages.first as Map<String, dynamic>;
  final String extract = (page['extract'] ?? '').toString();
  if (extract.trim().isEmpty) {
    throw StateError(
      'extract is empty for "${page['title']}" — likely a disambiguation page',
    );
  }
  return dedupeSectionHeaders(extract.trim());
}

/// Drops exact duplicate standalone section-header lines (MediaWiki
/// `explaintext` repeats the page title as the first section header).
String dedupeSectionHeaders(String text) {
  final Set<String> seenStandalone = <String>{};
  final List<String> kept = <String>[];
  for (final String line in text.split('\n\n')) {
    final String block = line.trim();
    if (block.isEmpty) {
      kept.add('');
      continue;
    }
    // A standalone block of <= 80 chars with no terminal punctuation is a
    // section header.
    final bool isHeader =
        block.length <= 80 && !RegExp(r'[.!?][")\]]?$').hasMatch(block);
    if (isHeader) {
      if (!seenStandalone.add(comparableName(block))) {
        continue;
      }
    }
    kept.add(line);
  }
  return kept.join('\n\n');
}

/// The disambiguation guard: the article's OPENING TEXT (first ~400 chars)
/// must contain every distinctive token of the seed name or of the article
/// title (accent-folded, honorifics ignored). Token-set matching tolerates
/// openings like "Maria Teresa Goretti" (seed "St. Maria Goretti") or
/// "Raymond Kolbe … canonized as Saint Maximilian Kolbe", while a page
/// about a different person shares no name tokens.
bool headlineMatches(String text, String seedName, String articleTitle) {
  final String opening = comparableName(
    text.length <= 400 ? text : text.substring(0, 400),
  );
  final Set<String> openingTokens = distinctiveTokens(opening);
  for (final String candidate in <String>[seedName, articleTitle]) {
    final Set<String> tokens = distinctiveTokens(comparableName(candidate));
    if (tokens.isNotEmpty && openingTokens.containsAll(tokens)) {
      return true;
    }
  }
  return false;
}

/// Name tokens long enough and distinctive enough to identify a person
/// (honorifics and glue words dropped).
Set<String> distinctiveTokens(String comparableNameInput) {
  const Set<String> stopwords = <String>{
    'st',
    'saint',
    'the',
    'of',
    'ii',
    'iii',
  };
  return comparableNameInput
      .split(RegExp(r'[^a-z0-9]+'))
      .where((String t) => t.length >= 4 && !stopwords.contains(t))
      .toSet();
}

/// The wikipedia article URL in the seed's `sources` list, if any.
String? wikipediaUrlFor(SaintSeedRow seed) {
  for (final String source in seed.sources) {
    if (source.startsWith('https://en.wikipedia.org/wiki/')) {
      return source;
    }
  }
  return null;
}

/// The API request URL for one article title.
String apiUrlFor(String title) =>
    '$_kApiBase?action=query&prop=extracts&explaintext=1&format=json'
    '&formatversion=2&redirects=1&titles=${Uri.encodeComponent(title)}';

/// Runs the scrape; network calls go through the injected [clientFactory]
/// (real `http.Client` in production, MockClient in tests).
Future<ScrapeOutcome> runScrape({
  required String packageRootForTest,
  required List<SaintSeedRow> seeds,
  required http.Client Function() clientFactory,
  required void Function(String message) log,
  List<String> onlySlugs = const <String>[],
  Map<String, String> titleOverrides = const <String, String>{},
}) async {
  final String outDir = '${packageRootForTest}/${groundingDirFor('wikipedia')}';
  Directory(outDir).createSync(recursive: true);
  final File manifestFile = File('$outDir/manifest.json');
  final Map<String, dynamic> manifest = manifestFile.existsSync()
      ? jsonDecode(manifestFile.readAsStringSync()) as Map<String, dynamic>
      : <String, dynamic>{'generatedAt': null, 'articles': <dynamic>[]};
  final List<dynamic> articles =
      (manifest['articles'] as List<dynamic>?) ?? <dynamic>[];

  final List<ScrapeFailure> failures = <ScrapeFailure>[];
  final List<String> written = <String>[];
  final http.Client client = clientFactory();
  // The production body extraction (used via fetchText's default).
  String Function(String) extract = extractPlainText;

  // Pre-request pacing for EVERY scraped slug after the first — success,
  // failure, and resume all take the polite path (final-review #13). The
  // pace fires only where a request could actually be made: slugs filtered
  // out or fully resumed cost less than a request and skip the wait.
  bool paced = false;

  for (final SaintSeedRow seed in seeds) {
    if (onlySlugs.isNotEmpty && !onlySlugs.contains(seed.slug)) {
      continue;
    }
    final String? url = titleOverrides.containsKey(seed.slug)
        ? 'https://en.wikipedia.org/wiki/'
              '${Uri.encodeComponent(titleOverrides[seed.slug]!.replaceAll(' ', '_'))}'
        : wikipediaUrlFor(seed);
    if (url == null) {
      failures.add(
        ScrapeFailure(
          slug: seed.slug,
          reason: 'no wikipedia URL in the seed sources list',
        ),
      );
      continue;
    }
    // Guard, extract, and write for one slug.
    final Map<String, dynamic> prior = <String, dynamic>{
      for (final Object? row in articles)
        if (row is Map<String, dynamic>) row['slug'] as String: row,
    };
    final File groundingFile = File('$outDir/${seed.slug}.txt');
    final bool hasFile =
        groundingFile.existsSync() && groundingFile.lengthSync() > 0;
    if (hasFile && prior[seed.slug] != null) {
      continue; // resume: grounded + manifest row present
    }
    final String title = titleOverrides.containsKey(seed.slug)
        ? titleOverrides[seed.slug]!
        : titleFromUrl(url);
    if (hasFile) {
      // The file survived a previous run but its manifest row is missing
      // (a crash between write and manifest) — rebuild the row locally,
      // no HTTP call.
      final String saved = groundingFile.readAsStringSync();
      articles
        ..removeWhere(
          (Object? row) =>
              row is Map<String, dynamic> && row['slug'] == seed.slug,
        )
        ..add(<String, dynamic>{
          'slug': seed.slug,
          'url': url,
          'file': '${seed.slug}.txt',
          'chars': saved.trim().length,
          'sha256': crypto.sha256.convert(utf8.encode(saved.trim())).toString(),
          'fetchedAt': DateTime.now().toUtc().toIso8601String(),
          'title': title,
        });
      written.add(seed.slug);
      log('[${seed.slug}] manifest row rebuilt from the existing file');
      continue;
    }
    String body;
    // Politeness pacing: >=1.1 s between actual HTTP requests, including
    // after a resume-skip or a logged failure.
    if (paced) {
      await Future<void>.delayed(const Duration(milliseconds: 1100));
    }
    paced = true;
    // Two attempts per URL; a 429/5xx honors Retry-After (default 10 s)
    // before the single retry (Global Constraints politeness).
    http.Response? response;
    Object? transportError;
    int status = 0;
    for (int attempt = 1; attempt <= 2; attempt++) {
      transportError = null;
      status = 0;
      try {
        response = await client
            .get(
              Uri.parse(apiUrlFor(title)),
              headers: <String, String>{
                'user-agent': 'sancta-via-grounding/1.0',
              },
            )
            .timeout(const Duration(seconds: 120));
      } catch (e) {
        transportError = e;
        if (attempt == 2) {
          break;
        }
        await Future<void>.delayed(const Duration(seconds: 10));
        continue;
      }
      status = response.statusCode;
      if (status == 429 || status >= 500) {
        if (attempt == 2) {
          break;
        }
        final int retryAfter =
            int.tryParse(response.headers['retry-after'] ?? '') ?? 10;
        log('[${seed.slug}] HTTP $status; retrying in ${retryAfter}s');
        await Future<void>.delayed(Duration(seconds: retryAfter));
        continue;
      }
      break;
    }
    if (transportError != null) {
      failures.add(
        ScrapeFailure(slug: seed.slug, reason: 'HTTP error: $transportError'),
      );
      continue;
    }
    if (status != 200) {
      failures.add(
        ScrapeFailure(slug: seed.slug, reason: 'HTTP $status for "$title"'),
      );
      continue;
    }
    body = response!.body;
    String text;
    try {
      text = extract(body);
    } catch (e) {
      failures.add(ScrapeFailure(slug: seed.slug, reason: 'extract error: $e'));
      continue;
    }
    if (text.length < 2000) {
      failures.add(
        ScrapeFailure(
          slug: seed.slug,
          reason:
              'extract too short (${text.length} chars < 2000) for "$title" — '
              'modern-saint honesty: record the failure, never force it',
        ),
      );
      continue;
    }
    if (!headlineMatches(text, seed.name, title)) {
      failures.add(
        ScrapeFailure(
          slug: seed.slug,
          reason:
              'disambiguation guard: opening does not name '
              '"${seed.name}" (title "$title")',
        ),
      );
      continue;
    }
    final DateTime now = DateTime.now().toUtc();
    const String newline = '\n';
    groundingFile.writeAsStringSync('$text$newline');
    final Map<String, dynamic> row = <String, dynamic>{
      'slug': seed.slug,
      'url': url,
      'file': '${seed.slug}.txt',
      'chars': text.length + newline.length,
      'sha256': crypto.sha256.convert(utf8.encode('$text$newline')).toString(),
      'fetchedAt': now.toIso8601String(),
      'title': title,
    };
    articles
      ..removeWhere(
        (Object? row) =>
            row is Map<String, dynamic> && row['slug'] == seed.slug,
      )
      ..add(row);
    written.add(seed.slug);
    log('[${seed.slug}] grounded ($title, ${row['chars']} chars)');
  }

  manifest['articles'] = articles;
  manifest['generatedAt'] = DateTime.now().toUtc().toIso8601String();
  if (articles.isNotEmpty || written.isNotEmpty) {
    manifestFile.writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert(manifest)}\n',
    );
  }
  client.close();
  return ScrapeOutcome(written: written, failures: failures);
}

/// Loads the seed rows from `data/saints_source.json` (package root at cwd).
List<SaintSeedRow> loadSeedRows(String saintsSourcePath) {
  final Object? decoded = jsonDecode(File(saintsSourcePath).readAsStringSync());
  final List<dynamic> saints =
      ((decoded as Map<String, dynamic>)['saints'] as List<dynamic>? ??
      const <dynamic>[]);
  return <SaintSeedRow>[
    for (final Object? row in saints)
      if (row is Map<String, dynamic>)
        SaintSeedRow(
          slug: (row['slug'] ?? '').toString(),
          name: (row['name'] ?? '').toString(),
          sources: <String>[
            for (final Object? s
                in (row['sources'] as List<dynamic>? ?? const <dynamic>[]))
              s.toString(),
          ],
        ),
  ];
}

Future<void> main(List<String> args) async {
  final List<String> slugs = <String>[];
  String? batchPath;
  for (int i = 0; i < args.length; i++) {
    switch (args[i]) {
      case '--slug':
        {
          if (i + 1 >= args.length) {
            stderr.writeln('wikipedia_grounding: --slug needs a value');
            exitCode = 1;
            return;
          }
          slugs.add(args[++i]);
        }
      case '--batch':
        {
          if (i + 1 >= args.length) {
            stderr.writeln('wikipedia_grounding: --batch needs a path');
            exitCode = 1;
            return;
          }
          batchPath = args[++i];
        }
      case '--refresh':
        stderr.writeln(
          'wikipedia_grounding: --refresh is not supported; delete the '
          'slug’s .txt file instead',
        );
        exitCode = 1;
        return;
      default:
        stderr.writeln('wikipedia_grounding: unknown argument "${args[i]}"');
        exitCode = 1;
        return;
    }
  }

  final Map<String, String> titleOverrides = <String, String>{};
  if (batchPath != null) {
    final Object? decoded = jsonDecode(File(batchPath).readAsStringSync());
    (decoded as Map<String, dynamic>).forEach(
      (String slug, Object? title) => titleOverrides[slug] = title.toString(),
    );
  }

  final List<SaintSeedRow> seeds = loadSeedRows('data/saints_source.json');
  print(
    'seeds: ${seeds.length} (slugs filter: '
    '${slugs.isEmpty ? "<none>" : slugs.join(", ")})',
  );
  final ScrapeOutcome outcome = await runScrape(
    packageRootForTest: '.',
    seeds: seeds,
    clientFactory: http.Client.new,
    log: print,
    onlySlugs: titleOverrides.isNotEmpty ? titleOverrides.keys.toList() : slugs,
    titleOverrides: titleOverrides,
  );
  print(
    'written: ${outcome.written.length}, failures: '
    '${outcome.failures.length}',
  );
  for (final ScrapeFailure failure in outcome.failures) {
    stderr.writeln('  ${failure.slug}: ${failure.reason}');
  }
  if (outcome.failures.isNotEmpty) {
    exitCode = 1;
  }
}
