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

import 'package:crypto/crypto.dart' as crypto;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../tools/wikipedia_grounding.dart';

const String kJohnPaulUrl = 'https://en.wikipedia.org/wiki/Pope_John_Paul_II';

const String kJohnPaulExtractJson =
    '{"batchcomplete":true,"query":{"pages":[{"pageid":null,"ns":0,'
    '"title":"Pope John Paul II","extract":"Pope John Paul II (born Karol '
    'Józef Wojtyła) reigned as pope of the Catholic Church from 1978 until '
    'his death in 2005.\\n\\nPope John Paul II\\n\\nHe was canonized in 2014 '
    'by Pope Francis.\\n\\nPope John Paul II\\n\\nHis feast day is 22 '
    'October.\\n\\nEarly life\\n\\nHe was born in Wadowice, Poland, in 1920 '
    'and studied for the priesthood in secret during the Nazi occupation of '
    'Poland.\\n\\nPapacy\\n\\nHis pontificate of twenty-six years was one of '
    'the longest in history, marked by vast travels that took him to nearly '
    'every continent, the World Youth Days that gathered millions of young '
    'people in cities from Buenos Aires to Manila, and the encyclicals that '
    'shaped a generation of Catholic teaching on work, on culture, and on '
    'the dignity of every human life; the visits to his own suffering '
    'country after its liberation, the restoration of the diplomatic '
    'relations of the Holy See with many lands, the catechism he gave the '
    'Church, and the daily audiences that carried his voice into every '
    'home where a radio or a television could be found.\\n\\nLegacy\\n\\nHe '
    'was beatified in '
    '2011 and canonized on 27 April 2014 by Pope Francis, alongside Pope '
    'John XXIII, and his liturgical memorial is celebrated on 22 October '
    'throughout the universal church, in every country where his pastoral '
    'visits are remembered, and in every parish that carries his name or '
    'safeguards his relics; the pilgrims who come to the shrine in Krakow '
    'leave with the memory of his patience under persecution, his fidelity '
    'in prayer, and the courage with which he bore the wounds of the '
    'assassination attempt to the end of his life, forgiving the man who '
    'shot him and later visiting him in prison to offer him pardon and '
    "that carries his name, and at the shrine in Krakow that guards his "
    'relics and his teachings for pilgrims from all over the world. The '
    'veneration of the saint grew steadily after his death, and the '
    'documents of his beatification and canonization were read in the '
    'presence of pilgrims from Poland and from every nation; the Church '
    'honored the memory of his life of holiness, his patience under '
    'persecution, and his long service to the See of Peter, whose duties '
    'he carried in spite of illness and advanced age, and whose teaching '
    'he defended in every season of his long and generous life."}]}}';

SaintSeedRow seedRow() => const SaintSeedRow(
  slug: 'john-paul-ii',
  name: 'St. John Paul II',
  sources: <String>['https://commons.wikimedia.org/wiki/Pope', kJohnPaulUrl],
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

    test(
      'throws a loud exception on an empty extract (disambiguation page)',
      () {
        const String empty = '{"query":{"pages":[{"title":"X","extract":""}]}}';
        expect(() => extractPlainText(empty), throwsA(isA<StateError>()));
      },
    );
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
          titleFromUrl('https://en.wikipedia.org/wiki/Francis_of_Assisi'),
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

    test("tolerates a middle name in the opening ('Maria Teresa Goretti')", () {
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

      expect(
        outcome.failures.map((ScrapeFailure f) => f.reason).toList(),
        isEmpty,
        reason: 'grounding must succeed',
      );
      final File text = File(
        '${temp.path}/data/grounding_wikipedia/'
        'john-paul-ii.txt',
      );
      expect(text.existsSync(), isTrue);
      expect(
        text.readAsStringSync(),
        contains('reigned as pope of the Catholic Church'),
      );

      final Map<String, dynamic> manifest =
          jsonDecode(
                File(
                  '${temp.path}/data/grounding_wikipedia/manifest.json',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>;
      final List<dynamic> articles = manifest['articles'] as List<dynamic>;
      expect(articles, hasLength(1));
      final Map<String, dynamic> row = articles.single as Map<String, dynamic>;
      expect(row['slug'], 'john-paul-ii');
      expect(row['url'], kJohnPaulUrl);
      expect(row['file'], 'john-paul-ii.txt');
      expect(row['title'], 'Pope John Paul II');
      expect(row['chars'], greaterThan(50));
      final String body = text.readAsStringSync();
      // The manifest hashes the FILE BYTES as committed (CE-manifest
      // parity: `sha256sum -c` style verification must pass).
      expect(
        row['sha256'],
        crypto.sha256.convert(utf8.encode(body)).toString(),
      );
      expect(row['chars'], body.length);
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
      expect(outcome.failures.single.slug, 'john-paul-ii');
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

    test(
      'retries once on HTTP 429 and succeeds (Retry-After honored)',
      () async {
        int calls = 0;
        final ScrapeOutcome outcome = await runScrape(
          packageRootForTest: temp.path,
          seeds: <SaintSeedRow>[seedRow()],
          clientFactory: () => MockClient((http.Request request) async {
            calls++;
            if (calls == 1) {
              return http.Response(
                'slow down',
                429,
                headers: {'retry-after': '0'},
              );
            }
            return http.Response(
              kJohnPaulExtractJson,
              200,
              headers: {'content-type': 'application/json'},
            );
          }),
          log: (_) {},
        );

        expect(
          outcome.failures.map((ScrapeFailure f) => f.reason).toList(),
          isEmpty,
          reason: 'the retry must clear the 429',
        );
        expect(calls, 2, reason: 'exactly one retry after the 429');
        expect(
          File(
            '${temp.path}/data/grounding_wikipedia/john-paul-ii.txt',
          ).existsSync(),
          isTrue,
        );
      },
    );

    test('sends the pinned API request shape', () async {
      final List<Uri> requested = <Uri>[];
      final ScrapeOutcome outcome = await runScrape(
        packageRootForTest: temp.path,
        seeds: <SaintSeedRow>[seedRow()],
        clientFactory: () => MockClient((http.Request request) async {
          requested.add(request.url);
          return http.Response(
            kJohnPaulExtractJson,
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
        log: (_) {},
      );

      expect(outcome.failures.map((ScrapeFailure f) => f.reason), isEmpty);
      expect(requested, hasLength(1));
      final Uri uri = requested.single;
      expect(uri.host, 'en.wikipedia.org');
      expect(uri.path, '/w/api.php');
      expect(uri.queryParameters['action'], 'query');
      expect(uri.queryParameters['prop'], 'extracts');
      expect(uri.queryParameters['explaintext'], '1');
      expect(uri.queryParameters['format'], 'json');
      expect(
        uri.queryParameters['titles'],
        'Pope John Paul II',
        reason: 'the title is percent-decoded once, never double-encoded',
      );
    });

    test(
      'records a failure for a too-short extract (modern-saint honesty)',
      () async {
        const String stub =
            '{"query":{"pages":[{"title":"St_Govans","extract":"A tiny stub '
            'about the chapel below the cliffs. It has very little text."}]}}';
        final ScrapeOutcome outcome = await runScrape(
          packageRootForTest: temp.path,
          seeds: <SaintSeedRow>[seedRow()],
          clientFactory: () => MockClient(
            (http.Request request) async => http.Response(
              stub,
              200,
              headers: {'content-type': 'application/json'},
            ),
          ),
          log: (_) {},
        );

        expect(outcome.failures, hasLength(1));
        expect(
          outcome.failures.single.reason,
          contains('too short'),
          reason: 'a <2000-char extract is a failure, never a grounding file',
        );
        expect(
          File(
            '${temp.path}/data/grounding_wikipedia/john-paul-ii.txt',
          ).existsSync(),
          isFalse,
        );
      },
    );

    test('resume: an existing non-empty file is not refetched', () async {
      final String dir = '${temp.path}/data/grounding_wikipedia';
      File('$dir/john-paul-ii.txt').createSync(recursive: true);
      File('$dir/john-paul-ii.txt').writeAsStringSync('pre-existing');
      int calls = 0;
      await runScrape(
        packageRootForTest: temp.path,
        seeds: <SaintSeedRow>[seedRow()],
        clientFactory: () => MockClient((http.Request request) async {
          calls = calls + 1;
          return http.Response('{"query":{"pages":[]}}', 200);
        }),
        log: (_) {},
      );
      expect(calls, 0, reason: 'existing grounding is never refetched');
    });
  });
}
