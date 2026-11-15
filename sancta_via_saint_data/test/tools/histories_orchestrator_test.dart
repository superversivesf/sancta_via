// Unit tests for `tools/histories_orchestrator.dart` (Task 3 of the
// saint-histories plan) — fixture-driven, NO network, NO real models.
//
// Every model call goes through an INJECTED fake runner (a Dart callable),
// so the tests pin the orchestration contract without spending a token:
//   * deterministic validator: 400–4000 chars, no `{{`, name presence,
//     feast-day consistency (rejects, before any model spend);
//   * author prompt carries the grounding text, the seed feast day, and the
//     `min(800, 1.5×anchorWords)` word target (floor 250);
//   * model JSON envelope parsing tolerates fenced JSON and prose;
//   * cross-check `pass` accepts, `issues` triggers exactly one repair
//     round, a second `issues` drops the entry (Review Focus: cross-check
//     honesty);
//   * two concurrent entries both complete (process-pool plumbing).
import 'package:flutter_test/flutter_test.dart';

import '../../tools/histories_orchestrator.dart';

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

const String kFrancisGrounding =
    'Founder of the Franciscan Order, born at Assisi in Umbria, in 1181 or '
    '1182 — the exact year is uncertain; died there, 3 October, 1226. '
    'His father, Pietro Bernardone, was a wealthy Assisian cloth merchant. '
    'Francis renounced his inheritance before the bishop of Assisi and '
    'embraced poverty; the Order of Friars Minor was approved in 1210.';

const SaintSeed kFrancisSeed = SaintSeed(
  slug: 'francis-of-assisi',
  name: 'St. Francis of Assisi',
  feastDay: '10-04',
  canonized: '1228',
  bio:
      'Born Giovanni di Pietro di Bernardone in Assisi around 1181, Francis '
      'renounced his inheritance, embraced poverty, and founded the Order of '
      'Friars Minor. He died in 1226 and was canonized in 1228.',
  patronages: <String>['animals', 'ecology'],
);

const GroundingText kFrancisGroundingText = GroundingText(
  slug: 'francis-of-assisi',
  ceCode: '06221a',
  url: 'https://www.newadvent.org/cathen/06221a.htm',
  text: kFrancisGrounding,
);

const SaintSeed kClareSeed = SaintSeed(
  slug: 'clare-of-assisi',
  name: 'St. Clare of Assisi',
  feastDay: '08-11',
  canonized: '1255',
  bio:
      'Clare of Assisi followed Francis in radical poverty and founded the '
      'Poor Clares. She died in 1253 and was canonized in 1255.',
  patronages: <String>['television'],
);

const GroundingText kClareGroundingText = GroundingText(
  slug: 'clare-of-assisi',
  ceCode: '04016a',
  url: 'https://www.newadvent.org/cathen/04016a.htm',
  text:
      'Clare of Assisi, born at Assisi in 1193, was the first woman to '
      'follow St. Francis; she founded the Poor Clares at San Damiano and '
      'died there on 11 August, 1253.',
);

/// A history of exactly [length] characters naming [token] and never
/// mentioning a feast day (so only length issues can fire).
String historyWith(String token, int length) {
  final String filler = '$token lived in poverty and prayer. ';
  final StringBuffer buffer = StringBuffer();
  while (buffer.length < length) {
    buffer.write(filler);
  }
  final String body = buffer.toString().substring(0, length);
  return body.endsWith(' ') ? '${body.substring(0, length - 1)}.' : body;
}

/// A history of exactly [length] characters that satisfies the Francis name
/// check and never mentions a feast day.
String historyOfLength(int length) => historyWith('Francis', length);

/// A comfortably valid history (≈700 chars) used by the cross-check tests.
String validFrancisHistory() => historyOfLength(700);

/// Envelope the author model is asked to return.
String authorEnvelope(String history) => '{"history": ${_jsonString(history)}}';

/// Verdict envelope the cross-check model is asked to return.
String verdictEnvelope(
  String verdict, [
  List<String> issues = const <String>[],
]) {
  final String encodedIssues = issues
      .map((String issue) => _jsonString(issue))
      .join(', ');
  return '{"verdict": ${_jsonString(verdict)}, "issues": [$encodedIssues]}';
}

String _jsonString(String value) {
  return '"${value.replaceAll(r'\', r'\\').replaceAll('"', r'\"').replaceAll('\n', ' ')}"';
}

/// Synchronous responder used by the concurrency test (reply derived from the
/// prompt so interleaved calls never consume each other's scripted lines).
typedef Responder = String Function(String model, String prompt);

/// Serialized scripted runner: each call consumes the next queued response.
/// Records the model + prompt of every call so tests can assert on them.
class ScriptedRunner {
  ScriptedRunner(this._script) : _responder = null;

  ScriptedRunner.responds(Responder responder)
    : _script = <String>[],
      _responder = responder;

  final List<String> _script;
  final Responder? _responder;
  final List<String> models = <String>[];
  final List<String> prompts = <String>[];
  int inFlight = 0;
  int maxInFlight = 0;

  ModelRunner get runner => _run;

  Future<String> _run({required String model, required String prompt}) async {
    models.add(model);
    prompts.add(prompt);
    inFlight++;
    maxInFlight = inFlight > maxInFlight ? inFlight : maxInFlight;
    try {
      // Yield so two workers can overlap (concurrency plumbing test).
      await Future<void>.delayed(const Duration(milliseconds: 5));
      final Responder? responder = _responder;
      if (responder != null) {
        return responder(model, prompt);
      }
      if (_script.isEmpty) {
        throw const ModelRunnerException('fake runner out of scripted replies');
      }
      return _script.removeAt(0);
    } finally {
      inFlight--;
    }
  }
}

HistoryOrchestrator orchestratorFor(ModelRunner runner, {int concurrency = 2}) {
  return HistoryOrchestrator(
    runModel: runner,
    authorModel: 'ollama/test-author',
    crossCheckModels: const <String>[
      'ollama/test-checker-a',
      'ollama/test-checker-b',
    ],
    concurrency: concurrency,
    log: (String message) {},
  );
}

List<AuthoringJob> francisJobs() {
  return <AuthoringJob>[
    const AuthoringJob(seed: kFrancisSeed, grounding: kFrancisGroundingText),
  ];
}

void main() {
  group('deterministic validator', () {
    test('rejects a history shorter than 400 characters', () {
      final List<String> issues = validateDraft(
        history: historyOfLength(399),
        seed: kFrancisSeed,
      );
      expect(issues, isNotEmpty);
      expect(issues.any((String issue) => issue.contains('400')), isTrue);
    });

    test('rejects a history longer than 4000 characters', () {
      final List<String> issues = validateDraft(
        history: historyOfLength(4001),
        seed: kFrancisSeed,
      );
      expect(issues.any((String issue) => issue.contains('4000')), isTrue);
    });

    test('accepts a history of exactly 400 and exactly 4000 characters', () {
      expect(
        validateDraft(history: historyOfLength(400), seed: kFrancisSeed),
        isEmpty,
      );
      expect(
        validateDraft(history: historyOfLength(4000), seed: kFrancisSeed),
        isEmpty,
      );
    });

    test('rejects template artifacts and a missing saint name', () {
      final String templated = '${historyOfLength(600)} {{history}}';
      expect(
        validateDraft(
          history: templated,
          seed: kFrancisSeed,
        ).any((String issue) => issue.contains('{{')),
        isTrue,
      );

      const String wrongSaint =
          'Clare of Assisi founded the Poor Clares and died in 1253 after a '
          'life of prayer, poverty, and service to the Church at San Damiano; '
          'she is remembered for her radical trust in providence and her '
          'long illness, and her order spread across Europe after her death. '
          'Her rule of life, the first written by a woman, was approved two '
          'days before she died, and her sisters still keep that rule today '
          'in houses on every continent, living by the same enclosure and '
          'common ownership that she professed at Assisi.';
      expect(
        validateDraft(
          history: wrongSaint,
          seed: kFrancisSeed,
        ).any((String issue) => issue.toLowerCase().contains('name')),
        isTrue,
      );
    });

    test('rejects a feast day that contradicts the seed record', () {
      const String conflicting =
          'Francis of Assisi founded the Franciscan Order in 1210 and died in '
          '1226 at the Portiuncula; his feast day is celebrated on '
          'October 5, and his followers spread throughout Europe carrying his '
          'rule of poverty, prayer, and preaching to the towns and courts of '
          'the thirteenth century, while his Canticle of the Sun praises God '
          'through creation and remains a landmark of Italian vernacular '
          'poetry to this day. The earliest life of the saint was written by '
          'Thomas of Celano at the request of Pope Gregory IX, and the '
          'Franciscan family he founded includes the Poor Clares, the '
          'Third Order, and a missionary tradition that reached Asia '
          'within his own lifetime.';
      final List<String> issues = validateDraft(
        history: conflicting,
        seed: kFrancisSeed,
      );
      expect(
        issues.any((String issue) => issue.toLowerCase().contains('feast')),
        isTrue,
      );

      // The seed's own feast day (4 October) is accepted.
      final String aligned =
          'Francis of Assisi founded the Franciscan Order in 1210 and died in '
          '1226 at the Portiuncula; his feast day is celebrated on '
          'October 4, and his followers spread throughout Europe carrying his '
          'rule of poverty, prayer, and preaching to the towns and courts of '
          'the thirteenth century, while his Canticle of the Sun praises God '
          'through creation and remains a landmark of Italian vernacular '
          'poetry to this day. The earliest life of the saint was written by '
          'Thomas of Celano at the request of Pope Gregory IX, and the '
          'Franciscan family he founded includes the Poor Clares, the '
          'Third Order, and a missionary tradition that reached Asia '
          'within his own lifetime.';
      expect(validateDraft(history: aligned, seed: kFrancisSeed), isEmpty);
    });

    test('historySource pins the CE 1907 provenance URL', () {
      expect(
        historySourceFor('06221a'),
        'catholic-encyclopedia-1907 '
        'https://www.newadvent.org/cathen/06221a.htm',
      );
    });
  });

  group('word target', () {
    test('is min(800, 1.5×anchorWords) with a 250-word floor', () {
      expect(targetWordCount(anchorWords: 1000), 800);
      expect(targetWordCount(anchorWords: 800), 800);
      expect(targetWordCount(anchorWords: 400), 600);
      expect(targetWordCount(anchorWords: 200), 300);
      expect(targetWordCount(anchorWords: 100), 250);
      expect(targetWordCount(anchorWords: 0), 250);
    });
  });

  group('prompts', () {
    test('author prompt carries grounding, feast day, and word target', () {
      final String prompt = buildAuthorPrompt(
        seed: kFrancisSeed,
        grounding: kFrancisGroundingText,
      );
      expect(prompt, contains(kFrancisGrounding));
      expect(prompt, contains('10-04'));
      // The Francis grounding is ~60 words → floor target 250.
      expect(prompt, contains('250'));
      expect(prompt, contains('St. Francis of Assisi'));
      expect(prompt, contains('tradition holds'));
      // Dates must be prose to prevent day-first/month-first ambiguity
      // (the 2026-11-15 batch lost 9 entries to numeric date drift).
      expect(prompt, contains('never use numeric'));
      expect(prompt, contains('Catholic Encyclopedia, 1907-12'));
    });

    test('author prompt labels the article text by the source class', () {
      final String wikiPrompt = buildAuthorPrompt(
        seed: kFrancisSeed,
        grounding: const GroundingText(
          slug: 'francis-of-assisi',
          ceCode: '06221a',
          url: 'https://en.wikipedia.org/wiki/Francis_of_Assisi',
          text: kFrancisGrounding,
        ),
        sourceClass: 'wikipedia',
      );
      expect(wikiPrompt, contains('Wikipedia article'));
      expect(wikiPrompt, isNot(contains('Catholic Encyclopedia, 1907-12')));
    });

    test('repair prompt carries the previous draft and the checker issues', () {
      final String prompt = buildRepairPrompt(
        seed: kFrancisSeed,
        grounding: kFrancisGroundingText,
        previousHistory: validFrancisHistory(),
        issues: const <String>['invented the year 1216 as the founding date'],
      );
      expect(prompt, contains('invented the year 1216'));
      expect(prompt, contains(validFrancisHistory()));
      expect(prompt, contains(kFrancisGrounding));
    });

    test('cross-check prompt carries grounding, seed record, and history', () {
      final String prompt = buildCrossCheckPrompt(
        seed: kFrancisSeed,
        grounding: kFrancisGroundingText,
        history: validFrancisHistory(),
      );
      expect(prompt, contains(kFrancisGrounding));
      expect(prompt, contains('St. Francis of Assisi'));
      expect(prompt, contains(validFrancisHistory()));
      expect(prompt, contains('"verdict"'));
    });
  });

  group('model envelope parsing', () {
    test('parses a bare JSON object', () {
      expect(parseModelEnvelope('{"history": "text"}')['history'], 'text');
    });

    test('tolerates fenced JSON and surrounding prose', () {
      final Map<String, dynamic> envelope = parseModelEnvelope(
        'Here is the entry:\n```json\n{"history": "grounded text"}\n```\n'
        'Hope that helps.',
      );
      expect(envelope['history'], 'grounded text');
    });

    test('parses nested braces and escaped newlines', () {
      final Map<String, dynamic> envelope = parseModelEnvelope(
        '{"history": "line one\\n\\nline two", "meta": {"ok": true}}',
      );
      expect(envelope['history'], 'line one\n\nline two');
    });

    test('throws a ModelRunnerException when no JSON object is present', () {
      expect(
        () => parseModelEnvelope('no json here at all'),
        throwsA(isA<ModelRunnerException>()),
      );
    });
  });

  group('cross-check loop', () {
    test('pass accepts the entry and records the checker model', () async {
      final String history = validFrancisHistory();
      final ScriptedRunner scripted = ScriptedRunner(<String>[
        authorEnvelope(history),
        verdictEnvelope('pass'),
      ]);

      final List<EntryOutcome> outcomes = await orchestratorFor(
        scripted.runner,
      ).runJobs(francisJobs());

      expect(outcomes, hasLength(1));
      expect(outcomes.single.status, EntryStatus.accepted);
      expect(outcomes.single.entry, isNotNull);
      expect(outcomes.single.entry!.history, history);
      expect(outcomes.single.entry!.checkedBy, 'ollama/test-checker-a');
      expect(outcomes.single.entry!.checkedBy, isNot('ollama/test-author'));
      expect(
        outcomes.single.entry!.historySource,
        'catholic-encyclopedia-1907 '
        'https://www.newadvent.org/cathen/06221a.htm',
      );
      expect(outcomes.single.roundsUsed, 1);
      expect(scripted.models.first, 'ollama/test-author');
    });

    test('issues triggers one repair round, then a pass accepts', () async {
      final String history = validFrancisHistory();
      final ScriptedRunner scripted = ScriptedRunner(<String>[
        authorEnvelope(history),
        verdictEnvelope('issues', <String>['claims a 1216 founding date']),
        authorEnvelope(history),
        verdictEnvelope('pass'),
      ]);

      final List<EntryOutcome> outcomes = await orchestratorFor(
        scripted.runner,
      ).runJobs(francisJobs());

      expect(outcomes.single.status, EntryStatus.accepted);
      expect(outcomes.single.roundsUsed, 2);
      // Four calls: author, check, repair, check.
      expect(scripted.models, hasLength(4));
      expect(scripted.prompts[2], contains('claims a 1216 founding date'));
      expect(scripted.models[1], 'ollama/test-checker-a');
      expect(scripted.models[3], 'ollama/test-checker-a');
    });

    test('a second issues verdict drops the entry (2-round cap)', () async {
      final String history = validFrancisHistory();
      final ScriptedRunner scripted = ScriptedRunner(<String>[
        authorEnvelope(history),
        verdictEnvelope('issues', <String>['invented a miracle account']),
        authorEnvelope(history),
        verdictEnvelope('issues', <String>['still invents a miracle account']),
      ]);

      final List<EntryOutcome> outcomes = await orchestratorFor(
        scripted.runner,
      ).runJobs(francisJobs());

      expect(outcomes.single.status, EntryStatus.dropped);
      expect(outcomes.single.entry, isNull);
      expect(outcomes.single.roundsUsed, 2);
      expect(outcomes.single.issues, isNotEmpty);
      expect(scripted.models, hasLength(4));
    });

    test(
      'a deterministically invalid draft is repaired before cross-check',
      () async {
        final String shortDraft = historyOfLength(200);
        final String history = validFrancisHistory();
        final ScriptedRunner scripted = ScriptedRunner(<String>[
          authorEnvelope(shortDraft),
          authorEnvelope(history),
          verdictEnvelope('pass'),
        ]);

        final List<EntryOutcome> outcomes = await orchestratorFor(
          scripted.runner,
        ).runJobs(francisJobs());

        expect(outcomes.single.status, EntryStatus.accepted);
        // No cross-check call for the invalid draft.
        expect(scripted.models, hasLength(3));
        expect(scripted.models[1], 'ollama/test-author');
      },
    );

    test('a thrown model call becomes an error entry, not a crash', () async {
      final ModelRunner failing =
          ({required String model, required String prompt}) async {
            throw const ModelRunnerException('opencode exited 1');
          };

      final List<EntryOutcome> outcomes = await orchestratorFor(
        failing,
      ).runJobs(francisJobs());

      expect(outcomes.single.status, EntryStatus.error);
      expect(outcomes.single.reason, contains('opencode exited 1'));
    });
  });

  group('concurrency + resume', () {
    test('two entries run concurrently and both complete', () async {
      final ScriptedRunner scripted = ScriptedRunner.responds((
        String model,
        String prompt,
      ) {
        if (model.startsWith('ollama/test-checker')) {
          return verdictEnvelope('pass');
        }
        final String token = prompt.contains('St. Clare of Assisi')
            ? 'Clare'
            : 'Francis';
        return authorEnvelope(historyWith(token, 700));
      });

      final List<AuthoringJob> jobs = <AuthoringJob>[
        const AuthoringJob(
          seed: kFrancisSeed,
          grounding: kFrancisGroundingText,
        ),
        const AuthoringJob(seed: kClareSeed, grounding: kClareGroundingText),
      ];

      final List<EntryOutcome> outcomes = await orchestratorFor(
        scripted.runner,
        concurrency: 2,
      ).runJobs(jobs);

      expect(outcomes, hasLength(2));
      expect(
        outcomes.every((EntryOutcome o) => o.status == EntryStatus.accepted),
        isTrue,
      );
      expect(scripted.maxInFlight, greaterThanOrEqualTo(2));
    });

    test('entries already in histories.json are skipped (resume)', () async {
      final ScriptedRunner scripted = ScriptedRunner(<String>[]);

      final List<EntryOutcome> outcomes = await orchestratorFor(
        scripted.runner,
      ).runJobs(francisJobs(), existingSlugs: <String>{'francis-of-assisi'});

      expect(outcomes.single.status, EntryStatus.skipped);
      expect(scripted.models, isEmpty);
    });
  });

  group('history entry + report shapes', () {
    test('accepted entry serializes the pinned key set', () async {
      final String history = validFrancisHistory();
      final ScriptedRunner scripted = ScriptedRunner(<String>[
        authorEnvelope(history),
        verdictEnvelope('pass'),
      ]);
      final List<EntryOutcome> outcomes = await orchestratorFor(
        scripted.runner,
      ).runJobs(francisJobs());
      final Map<String, dynamic> json = outcomes.single.entry!.toJson();

      expect(json.keys.toSet(), <String>{
        'slug',
        'history',
        'historySource',
        'ceCode',
        'authoredAt',
        'checkedBy',
        'roundsUsed',
      });
      expect(json['slug'], 'francis-of-assisi');
      expect(json['ceCode'], '06221a');
      expect(DateTime.parse(json['authoredAt'] as String).isUtc, isTrue);
      expect(json['roundsUsed'], 1);
    });

    test('run report counts every status', () async {
      final String history = validFrancisHistory();
      final ScriptedRunner scripted = ScriptedRunner(<String>[
        authorEnvelope(history),
        verdictEnvelope('pass'),
      ]);
      final List<EntryOutcome> outcomes = await orchestratorFor(
        scripted.runner,
      ).runJobs(francisJobs());
      final Map<String, dynamic> report = buildRunReport(
        outcomes: outcomes,
        authorModel: 'ollama/test-author',
        crossCheckModels: const <String>['ollama/test-checker-a'],
        generatedAt: DateTime.utc(2026, 11, 14),
      );

      expect(report['authorModel'], 'ollama/test-author');
      expect((report['counts'] as Map<String, dynamic>)['accepted'], 1);
      expect((report['counts'] as Map<String, dynamic>)['dropped'], 0);
      final List<dynamic> entries = report['entries'] as List<dynamic>;
      expect(entries, hasLength(1));
      expect(
        (entries.single as Map<String, dynamic>)['slug'],
        'francis-of-assisi',
      );
    });
  });

  group('source classes (modern-saint-histories Task 1)', () {
    test('wikipedia class builds wikipedia provenance from the manifest URL',
        () async {
      final GroundingText wikipediaGrounding = GroundingText(
        slug: 'francis-of-assisi',
        ceCode: '06221a',
        url: 'https://en.wikipedia.org/wiki/Francis_of_Assisi',
        text: kFrancisGrounding,
      );
      final AuthoringJob job = AuthoringJob(
        seed: kFrancisSeed,
        grounding: wikipediaGrounding,
      );
      final String history = validFrancisHistory();
      final ScriptedRunner scripted = ScriptedRunner(<String>[
        authorEnvelope(history),
        verdictEnvelope('pass'),
      ]);
      final List<EntryOutcome> outcomes = await orchestratorFor(
        scripted.runner,
      ).runJobs(<AuthoringJob>[job], sourceClass: 'wikipedia');

      expect(outcomes.single.status, EntryStatus.accepted);
      expect(
        outcomes.single.entry!.historySource,
        'wikipedia https://en.wikipedia.org/wiki/Francis_of_Assisi',
      );
    });

    test('unknown source class is rejected loudly before any model call',
        () async {
      final HistoryOrchestrator orchestrator = orchestratorFor(
        ScriptedRunner(<String>[]).runner,
      );
      await expectLater(
        orchestrator.runJobs(francisJobs(), sourceClass: 'random-site'),
        throwsArgumentError,
      );
    });
  });
}

