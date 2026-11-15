// Unit tests for `tools/wikipedia_grounding.dart` (modern-saint-histories
// plan Task 2) — fixture-driven, NO network (injected http client).
//
// Pins:
//   * plain-text extraction from a recorded `prop=extracts&explaintext=1`
//     response, with duplicate section headers deduped;
//   * the seed-name/first-line disambiguation guard (Review Focus) — a wrong
//     person's article fails loudly, never silently ingests;
//   * manifest entry shape + sha256 + chars;
//   * the run wrapper records per-slug failures and reports them for the
//     exit-1 semantics.
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../tools/wikipedia_grounding.dart';

const String kJohnPaulUrl =
    'https://en.wikipedia.org/wiki/Pope_John_Paul_II';

const String kJohnPaulExtractJson =
    '{"batchcomplete":true,"query":{"pages":[{"pageid":null,"ns":0,'
    '"title":"Pope John Paul II","extract":"Pope John Paul II (born Karol '
    'Józef Wojtyła) reigned as pope of the Catholic Church from 1978 until '
    'his death in 2005.\\n\\nPope John Paul II\\n\\nHe was canonized in 2014 '
    'by Pope Francis.\\n\\nPope John Paul II\\n\\nHis feast day is 22 '
    'October."}]}}';

SaintSeedRow seedRow() => const SaintSeedRow(
      slug: 'john-paul-ii',
      name: 'St. John Paul II',
      sources: <String>[
        'https://commons.wikimedia.org/wiki/Pope',
        kJohnPaulUrl,
      ],
    );

void main() {
  group('extractPlainText', () {
    test('extracts the plain text from a recorded explaintext response', () {
      final String text = extractPlainText(kJohnPaulExtractJson);
      expect(text, contains('reigned as pope of the Catholic Church'));
    });

    test('dedupes repeated section headers', () {
      final String text = extractPlainText(kJohnPaulExtractJson);
      // The header appears three times in the payload; keep only the first.
      expect('Pope John Paul II'.allMatches(text), hasLength(2));
    });

    test('throws a loud exception on an empty extract (disambiguation page)',
        () {
      const String empty = '{"query":{"pages":[{"title":"X","extract":""}]}}';
      expect(() => extractPlainText(empty), throwsA(isA<StateError>()));
    });
  });

  group('headlineMatches (disambiguation guard, Review Focus)', () {
    test('matches the seed name against the article opening', () {
      expect(
        headlineMatches(
          'Pope John Paul II (born Karol Józef Wojtyła) reigned as pope',
          seedRow().name,
          titleFromUrl(kJohnPaulUrl),
        ),
        isTrue,
      );
    });

    test('matches when the URL title appears verbatim in the opening', () {
      expect(
        headlineMatches(
          'Francis of Assisi founded the Franciscan Order',
          'St. Francis of Assisi',
          titleFromUrl(
            'https://en.wikipedia.org/wiki/Francis_of_Assisi',
          ),
        ),
        isTrue,
      );
    });

    test('rejects a different person (wrong-name guard)', () {
      expect(
        headlineMatches(
          'A village primary school in Powys, Wales',
          'St. Dudwg',
          'St_Govans',
        ),
        isFalse,
      );
    });

    test("tolerates a middle name in the opening ('Maria Teresa Goretti')",
        () {
      expect(
        headlineMatches(
          'Maria Teresa Goretti was an Italian virgin martyrorum of the '
          'Roman Catholic Church, canonized in 1950.',
          'St. Maria Goretti',
          'Maria Goretti',
        ),
        isTrue,
      );
    });

    test("tolerates a canonization-style opening for 'Maximilian Kolbe'", () {
      expect(
        headlineMatches(
          'Raymond Kolbe, venerated as Saint Maximilian Maria Kolbe, was a '
          'Polish Catholic priest who volunteered to die in place of a '
          'stranger at Auschwitz.',
          'St. Maximilian Kolbe',
          'Maximilian Kolbe',
        ),
        isTrue,
      );
    });
  });

  group('titleFromUrl', () {
    test('decodes and spaces out the underscored title', () {
      expect(titleFromUrl(kJohnPaulUrl), 'Pope John Paul II');
      expect(
        titleFromUrl(
          'https://en.wikipedia.org/wiki/Jos%C3%A9mar%C3%ADa_Escriv%C3%A1',
        ),
        'Josémaría Escrivá',
      );
    });
  });

  group('runScrape (injected client)', () {
    late Directory temp;

    setUp(() {
      temp = Directory.systemTemp.createTempSync('wiki-grounding-');
    });

    tearDown(() {
      temp.deleteSync(recursive: true);
    });

    test('writes the text file and a manifest entry with sha256', () async {
      final ScrapeOutcome outcome = await runScrape(
        packageRootForTest: temp.path,
        seeds: <SaintSeedRow>[seedRow()],
        clientFactory: () => MockClient(
          (http.Request request) async => http.Response(
            kJohnPaulExtractJson,
            200,
            headers: {'content-type': 'application/json'},
          ),
        ),
        log: (_) {},
      );

      expect(outcome.failures, isEmpty);
      final File text = File('${temp.path}/data/grounding_wikipedia/'
          'john-paul-ii.txt');
      expect(text.existsSync(), isTrue);
      expect(
        text.readAsStringSync(),
        contains('reigned as pope of the Catholic Church'),
      );

      final Map<String, dynamic> manifest = jsonDecode(
        File(
          '${temp.path}/data/grounding_wikipedia/manifest.json',
        ).readAsStringSync(),
      ) as Map<String, dynamic>;
      final List<dynamic> articles = manifest['articles'] as List<dynamic>;
      expect(articles, hasLength(1));
      final Map<String, dynamic> row = articles.single as Map<String, dynamic>;
      expect(row['slug'], 'john-paul-ii');
      expect(row['url'], kJohnPaulUrl);
      expect(row['file'], 'john-paul-ii.txt');
      expect(row['title'], 'Pope John Paul II');
      expect(row['chars'], greaterThan(50));
      expect(row['sha256'], matches(RegExp(r'^[0-9a-f]{64}$')));
      expect(row['fetchedAt'], isNotNull);
    });

    test('records a failure and refuses to write when the wrong person '
        'comes back', () async {
      const String wrongPerson =
          '{"query":{"pages":[{"title":"St_Govans","extract":"A village '
          'primary school sits below the cliffs of Pembrokeshire, Wales. '
          'The chapel ruin overlooks the sea. Visitors walk the coastal '
          'path each summer."}]}}';
      final ScrapeOutcome outcome = await runScrape(
        packageRootForTest: temp.path,
        seeds: <SaintSeedRow>[seedRow()],
        clientFactory: () => MockClient(
          (http.Request request) async => http.Response(
            wrongPerson,
            200,
            headers: {'content-type': 'application/json'},
          ),
        ),
        log: (_) {},
      );

      expect(outcome.failures, hasLength(1));
      expect(
        outcome.failures.single.slug,
        'john-paul-ii',
      );
      expect(
        File(
          '${temp.path}/data/grounding_wikipedia/john-paul-ii.txt',
        ).existsSync(),
        isFalse,
        reason: 'a disambiguation-guard failure must not write a text file',
      );
      expect(
        File(
          '${temp.path}/data/grounding_wikipedia/manifest.json',
        ).existsSync(),
        isFalse,
        reason: 'a disambiguation-guard failure must not write a manifest row',
      );
    });

    test('retries once on HTTP 429 and succeeds (Retry-After honored)',
        () async {
      int calls = 0;
      final ScrapeOutcome outcome = await runScrape(
        packageRootForTest: temp.path,
        seeds: <SaintSeedRow>[seedRow()],
        clientFactory: () => MockClient(
          (http.Request request) async {
            calls++;
            if (calls == 1) {
              return http.Response('slow down', 429,
                  headers: {'retry-after': '0'});
            }
            return http.Response(
              kJohnPaulExtractJson,
              200,
              headers: {'content-type': 'application/json'},
            );
          },
        ),
        log: (_) {},
      );

      expect(outcome.failures, isEmpty, reason: 'the retry must clear the 429');
      expect(calls, 2, reason: 'exactly one retry after the 429');
      expect(
        File(
          '${temp.path}/data/grounding_wikipedia/john-paul-ii.txt',
        ).existsSync(),
        isTrue,
      );
    });

    test('resume: an existing non-empty file is not refetched', () async {
      final String dir = '${temp.path}/data/grounding_wikipedia';
      File('$dir/john-paul-ii.txt').createSync(recursive: true);
      File('$dir/john-paul-ii.txt').writeAsStringSync('pre-existing');
      int calls = 0;
      await runScrape(
        packageRootForTest: temp.path,
        seeds: <SaintSeedRow>[seedRow()],
        clientFactory: () => MockClient(
          (http.Request request) async {
            calls = calls + 1;
            return http.Response('{"query":{"pages":[]}}', 200);
          },
        ),
        log: (_) {},
      );
      expect(calls, 0, reason: 'existing grounding is never refetched');
    });
  });
}
