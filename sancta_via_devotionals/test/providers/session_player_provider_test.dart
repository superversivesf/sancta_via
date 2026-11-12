// Session player controller tests (Plan 2, Task 10).
//
// Pins the five briefing cases plus the minimal real edges:
//
// 1. an Angelus walk completes, persists its JSON snapshot on every
//    transition, and clears it when the completion lands;
// 2. the 54-day novena's day-27 variant substitutes `{{day}}` = '27' and the
//    mystery tokens from the day's mystery cycle;
// 3. a repetition step blocks `completeStep` until its target is recorded;
// 4. the checkpoint gate holds the session incomplete until the required
//    checkpoint is toggled (the controller reflects Task 9's answer — it
//    never forces the completion);
// 5. a resume round-trip restores the step index and the checkpoint map
//    mid-session;
// 6. an unknown pack surfaces an error state instead of throwing;
// 7. the reflection countdown deadline persists and clears;
// 8. an unresolved placeholder surfaces the leakage gate as an error state.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sancta_via_devotional_engine/sancta_via_devotional_engine.dart';
import 'package:sancta_via_devotional_engine_riverpod/sancta_via_devotional_engine_riverpod.dart'
    show ProgramRepository;
import 'package:sancta_via_devotionals/database/devotionals_database.dart';
import 'package:sancta_via_devotionals/providers/session_player_provider.dart';
import 'package:sancta_via_devotionals/services/substitution_service.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// A repository double carrying the packs under test and recording writes.
class _FakeProgramRepository implements ProgramRepository {
  _FakeProgramRepository({required this.packs});

  final List<ContentPack> packs;
  final Map<String, ProgressState> progress = <String, ProgressState>{};
  final List<ProgressState> saves = <ProgressState>[];

  @override
  Future<List<ContentPack>> loadPacks() async => packs;

  @override
  Future<ProgressState?> progressFor(String packId) async => progress[packId];

  @override
  Future<void> enroll(String packId, Map<String, dynamic> params) async {}

  @override
  Future<void> saveProgress(ProgressState s) async {
    progress[s.packId] = s;
    saves.add(s);
  }
}

/// A fresh isolated in-memory `meta` store (the FFI factory is installed by
/// `test/flutter_test_config.dart`).
DevotionalsDatabase _inMemoryDatabase() {
  return DevotionalsDatabase(
    open: () => openDatabase(inMemoryDatabasePath, singleInstance: false),
  );
}

/// The shipped pack asset with [id] (the app bundles the engine fixtures
/// byte-for-byte, so this is the real content the player renders).
ContentPack _assetPack(String id) {
  final String raw = File('assets/content/packs/$id.json').readAsStringSync();
  return PackLoader.loadFromJsonString(raw);
}

/// Walks [controller] to the end, recording each counted bead group's target
/// as the engine requires.
Future<void> _walkToEnd(SessionPlayerController controller) async {
  while (!controller.state.session.isComplete) {
    final SessionStep? step = controller.state.currentStep;
    if (step is BeadGroupStep) {
      await controller.record(step.hailMaryCount);
    }
    await controller.completeStep();
  }
}

/// The decoded persisted snapshot of [packId], or null when none exists.
Future<Map<String, dynamic>?> _snapshot(
  DevotionalsDatabase database,
  String packId,
) async {
  final String? raw = await database.getMeta('active_session_$packId');
  if (raw == null) {
    return null;
  }
  return jsonDecode(raw) as Map<String, dynamic>;
}

/// Every user-visible string of [script] in step order — the comparison basis
/// for the resume identity pin (substituted text must survive the round trip
/// byte-for-byte).
List<String> _stepTexts(SessionScript script) {
  final List<String> texts = <String>[];
  for (final SessionStep step in script.steps) {
    texts.addAll(switch (step) {
      PrayerStep() => <String>[
        step.title ?? '',
        step.text.text,
        step.text.latin ?? '',
      ],
      VerseStep() => <String>[
        step.title ?? '',
        step.versicle,
        step.response,
        step.closing?.text ?? '',
      ],
      ReflectionStep() => <String>[step.title ?? '', step.text?.text ?? ''],
      CheckpointStep() => <String>[step.title ?? '', step.item],
      IntercessionStep() => <String>[step.title ?? '', step.prompt],
      BeadGroupStep() => <String>[
        step.title ?? '',
        step.mysteryTitle ?? '',
        step.mysteryFruit ?? '',
      ],
      RepetitionStep() => <String>[step.title ?? '', step.text.text],
      LitanyStep() => <String>[
        step.title ?? '',
        step.response,
        ...step.invocations,
      ],
    });
  }
  return texts;
}

void main() {
  group('SessionPlayerController.startSession', () {
    test('an angelus walk completes and persists its JSON snapshot', () async {
      final ContentPack angelus = _assetPack('angelus');
      final _FakeProgramRepository repository = _FakeProgramRepository(
        packs: <ContentPack>[angelus],
      );
      final DevotionalsDatabase database = _inMemoryDatabase();
      final SessionPlayerController controller = SessionPlayerController(
        repository: repository,
        database: database,
        clock: () => DateTime(2026, 12, 5, 6),
      );

      await controller.startSession('angelus', forDate: DateTime(2026, 12, 5));

      expect(controller.state.status, SessionPlayerStatus.active);
      expect(controller.state.script.steps, hasLength(4));
      expect(controller.state.script.id, 'angelus-session');
      expect(controller.state.tokens, isEmpty, reason: 'no day variant');
      expect(
        controller.state.currentStep,
        isA<VerseStep>(),
        reason: 'the walk opens on the first verse',
      );

      await controller.completeStep();
      expect(controller.state.session.stepIndex, 1);

      // The transition wrote the full snapshot: session JSON, tokens, day.
      final Map<String, dynamic>? midWalk = await _snapshot(
        database,
        'angelus',
      );
      expect(midWalk, isNotNull);
      expect((midWalk!['session'] as Map<String, dynamic>)['stepIndex'], 1);
      expect(
        (midWalk['session'] as Map<String, dynamic>)['scriptId'],
        'angelus-session',
      );
      expect(midWalk['day'], '2026-12-05');
      expect(midWalk['tokens'], isA<Map<String, dynamic>>());

      await _walkToEnd(controller);

      expect(controller.state.status, SessionPlayerStatus.finalized);
      expect(controller.state.session.isComplete, isTrue);
      expect(controller.state.isFinalizable, isTrue);
      expect(
        await _snapshot(database, 'angelus'),
        isNull,
        reason: 'a finalized session is no longer resumable',
      );
      final ProgressState? written = await repository.progressFor('angelus');
      expect(written, isNotNull);
      expect(written!.fulfilledOrdinals, 1);
      expect(written.lastFulfilled, DateTime(2026, 12, 5));
      expect(written.badges, hasLength(1));
    });

    test(
      'the 54-day day-27 variant substitutes the day and the mystery cycle',
      () async {
        final ContentPack novena = _assetPack('novena_54_day');
        final _FakeProgramRepository repository = _FakeProgramRepository(
          packs: <ContentPack>[novena],
        );
        final DevotionalsDatabase database = _inMemoryDatabase();
        final SessionPlayerController controller = SessionPlayerController(
          repository: repository,
          database: database,
          clock: () => DateTime(2026, 12, 6, 8),
        );

        // 2026-11-10 + 26 days = day 27 of the fixture series.
        await controller.startSession(
          'novena_54_day',
          forDate: DateTime(2026, 12, 6),
        );

        expect(controller.state.status, SessionPlayerStatus.active);
        expect(controller.state.tokens['day'], '27');
        // Day 27's cycle is the glorious set (the fixture's J-S-G rotation),
        // and the pack ships no individual mystery titles, so the token
        // carries the set's title and the day's virtue as its fruit.
        expect(controller.state.tokens['mysteryTitle'], 'Glorious Mysteries');
        expect(controller.state.tokens['mysteryFruit'], 'faith');
        expect(
          controller.state.tokens['petition'],
          contains('full-blown roses'),
        );
        expect(controller.state.tokens['phase'], 'petition');

        // Every placeholder in the resolved script is substituted: the three
        // decades carry the day's mystery header, never the raw token.
        final List<BeadGroupStep> decades = controller.state.script.steps
            .whereType<BeadGroupStep>()
            .toList();
        expect(decades, hasLength(3));
        for (final BeadGroupStep decade in decades) {
          expect(decade.mysteryTitle, 'Glorious Mysteries');
          expect(decade.mysteryFruit, 'faith');
        }
        for (final SessionStep step in controller.state.script.steps) {
          if (step is BeadGroupStep) {
            expect(step.mysteryTitle, isNot(contains('{{')));
          }
          if (step is PrayerStep) {
            expect(step.text.text, isNot(contains('{{')));
          }
        }

        // Pause/resume keeps the day's substituted text byte-identical: the
        // script is re-derived from the PERSISTED tokens/variant, so the
        // delivered strings survive the round trip unchanged.
        final List<String> before = _stepTexts(controller.state.script);
        final SessionPlayerController resumed = SessionPlayerController(
          repository: repository,
          database: database,
          clock: () => DateTime(2026, 12, 7, 8),
          resumePackId: 'novena_54_day',
        );
        await resumed.ready;

        expect(resumed.state.status, SessionPlayerStatus.active);
        expect(resumed.state.tokens['day'], '27', reason: 'snapshot tokens');
        expect(_stepTexts(resumed.state.script), before);
      },
    );

    test('an in-text {{day}} placeholder is substituted on delivery', () async {
      final ContentPack mercy = _assetPack('divine_mercy_novena');
      final _FakeProgramRepository repository = _FakeProgramRepository(
        packs: <ContentPack>[mercy],
      );
      final SessionPlayerController controller = SessionPlayerController(
        repository: repository,
        database: _inMemoryDatabase(),
        clock: () => DateTime(2026, 4, 5, 9),
      );

      // Easter Sunday 2026 is the window's day 3 (Good Friday + 2).
      await controller.startSession(
        'divine_mercy_novena',
        forDate: DateTime(2026, 4, 5),
      );
      expect(controller.state.tokens['day'], '3');

      final IntercessionStep intercession = controller.state.script.steps
          .whereType<IntercessionStep>()
          .single;
      expect(intercession.prompt, isNot(contains('{{')));
      expect(intercession.prompt, contains('3 of the Divine Mercy Novena'));
      expect(
        SubstitutionService.requireFullySubstituted(intercession.prompt),
        intercession.prompt,
        reason: 'the delivered text passes the render gate',
      );
    });

    test('a repetition step blocks completeStep before its target', () async {
      final ContentPack rosary = _assetPack('rosary');
      final _FakeProgramRepository repository = _FakeProgramRepository(
        packs: <ContentPack>[rosary],
      );
      final DevotionalsDatabase database = _inMemoryDatabase();
      final SessionPlayerController controller = SessionPlayerController(
        repository: repository,
        database: database,
        clock: () => DateTime(2026, 12, 14, 9),
      );

      // 2026-12-14 is a Monday: the cycle's joyful set.
      await controller.startSession('rosary', forDate: DateTime(2026, 12, 14));
      expect(controller.state.tokens['mysteryTitle'], 'The Annunciation');
      final List<BeadGroupStep> decades = controller.state.script.steps
          .whereType<BeadGroupStep>()
          .toList();
      expect(decades[0].mysteryTitle, 'The Annunciation');
      expect(decades[1].mysteryTitle, 'The Visitation');
      expect(decades[4].mysteryTitle, 'The Finding in the Temple');

      // The opening verse, creed, and Our Father complete directly.
      for (int i = 0; i < 3; i++) {
        await controller.completeStep();
      }
      expect(controller.state.session.stepIndex, 3);
      expect(controller.state.currentStep, isA<RepetitionStep>());

      // The three Hail Marys are still unrecorded: the engine refuses, and
      // the controller keeps the session on the step.
      await controller.completeStep();
      expect(
        controller.state.session.stepIndex,
        3,
        reason: 'a counted step never advances before its target',
      );

      await controller.record(3);

      // The record transition persisted the engine counter in the snapshot.
      final Map<String, dynamic>? recorded = await _snapshot(
        database,
        'rosary',
      );
      expect(
        (recorded!['session'] as Map<String, dynamic>)['recordedCounts'],
        <String, dynamic>{'3': 3},
      );

      await controller.completeStep();
      expect(controller.state.session.stepIndex, 4);
    });

    test(
      'the checkpoint gate holds the session incomplete until toggled',
      () async {
        final ContentPack saturdays = _assetPack('five_first_saturdays');
        final _FakeProgramRepository repository = _FakeProgramRepository(
          packs: <ContentPack>[saturdays],
        );
        final DevotionalsDatabase database = _inMemoryDatabase();
        final SessionPlayerController controller = SessionPlayerController(
          repository: repository,
          database: database,
          clock: () => DateTime(2026, 12, 5, 8),
        );

        await controller.startSession(
          'five_first_saturdays',
          forDate: DateTime(2026, 12, 5),
        );
        await _walkToEnd(controller);

        // The walk is finished, but the required communion checkpoint is not
        // recorded: Task 9's gate returns the walked state and writes nothing.
        expect(controller.state.session.isComplete, isTrue);
        expect(controller.state.status, SessionPlayerStatus.active);
        expect(controller.state.isFinalizable, isFalse);
        expect(controller.state.missingRequiredItems, <String>['communion']);
        expect(await repository.progressFor('five_first_saturdays'), isNull);
        expect(
          await _snapshot(database, 'five_first_saturdays'),
          isNotNull,
          reason: 'an unfinalized walk stays resumable',
        );

        // Recording the required checkpoint retries the finalization.
        await controller.toggleCheckpoint('communion');

        expect(controller.state.status, SessionPlayerStatus.finalized);
        expect(controller.state.isFinalizable, isTrue);
        expect(controller.state.missingRequiredItems, isEmpty);
        final ProgressState? written = await repository.progressFor(
          'five_first_saturdays',
        );
        expect(written, isNotNull);
        expect(written!.fulfilledOrdinals, 1);
        expect(
          written.completedItemsByDay.keys,
          contains('communion:2026-12-05'),
          reason: 'the recorded checkpoint is dated at the session day',
        );
        expect(await _snapshot(database, 'five_first_saturdays'), isNull);
      },
    );

    test(
      'an unknown pack surfaces an error state instead of throwing',
      () async {
        final _FakeProgramRepository repository = _FakeProgramRepository(
          packs: <ContentPack>[_assetPack('angelus')],
        );
        final SessionPlayerController controller = SessionPlayerController(
          repository: repository,
          database: _inMemoryDatabase(),
        );

        await controller.startSession('no_such_pack');

        expect(controller.state.status, SessionPlayerStatus.error);
        expect(controller.state.errorMessage, contains('no_such_pack'));
      },
    );

    test(
      'an unresolved placeholder surfaces the leakage gate as an error',
      () async {
        final ContentPack leaky = ContentPack(
          id: 'leaky',
          title: 'Leaky pack',
          family: PackFamily.routine,
          schedule: TimeOfDaySpec(6, 0),
          session: SessionScript(
            id: 'leaky-session',
            steps: <SessionStep>[
              PrayerStep(
                id: 'leaky-prayer',
                text: PrayerText(
                  id: 'leaky-prayer-text',
                  text: 'color of the roses: {{color}}',
                  source: 'test',
                  license: 'test',
                ),
              ),
            ],
          ),
        );
        final _FakeProgramRepository repository = _FakeProgramRepository(
          packs: <ContentPack>[leaky],
        );
        final SessionPlayerController controller = SessionPlayerController(
          repository: repository,
          database: _inMemoryDatabase(),
        );

        await controller.startSession('leaky');

        expect(controller.state.status, SessionPlayerStatus.error);
        expect(controller.state.errorMessage, contains('{{color}}'));
      },
    );
  });

  group('SessionPlayerController resume', () {
    test(
      'a resume round-trip restores the step index and checkpoint map',
      () async {
        final ContentPack saturdays = _assetPack('five_first_saturdays');
        final _FakeProgramRepository repository = _FakeProgramRepository(
          packs: <ContentPack>[saturdays],
        );
        final DevotionalsDatabase database = _inMemoryDatabase();

        final SessionPlayerController first = SessionPlayerController(
          repository: repository,
          database: database,
          clock: () => DateTime(2026, 12, 5, 8),
        );
        await first.startSession(
          'five_first_saturdays',
          forDate: DateTime(2026, 12, 5),
        );
        await first.completeStep(); // confession checkpoint step
        await first.toggleCheckpoint('confession');
        await first.completeStep(); // communion checkpoint step

        expect(first.state.session.stepIndex, 2);
        expect(first.state.checkpoints, <String, bool>{'confession': true});

        // A fresh player (the construction-time resume path) restores the
        // same pack's unfinished session.
        final SessionPlayerController second = SessionPlayerController(
          repository: repository,
          database: database,
          clock: () => DateTime(2026, 12, 5, 20),
          resumePackId: 'five_first_saturdays',
        );
        await second.ready;

        expect(second.state.status, SessionPlayerStatus.active);
        expect(second.state.session.stepIndex, 2);
        expect(second.state.session.stepCount, first.state.session.stepCount);
        expect(second.state.checkpoints, <String, bool>{'confession': true});
        expect(
          second.state.script.steps,
          hasLength(first.state.script.steps.length),
        );
        expect(second.state.currentStep, isA<BeadGroupStep>());

        // The checkpoint's completion DATE survived the round trip: walking
        // on to the gate and finalizing writes the confession record with the
        // original session day, proving `checkpointDates` was restored (not
        // re-dated by the resume's clock).
        await _walkToEnd(second);
        await second.toggleCheckpoint('communion');
        expect(second.state.status, SessionPlayerStatus.finalized);
        final ProgressState? written = await repository.progressFor(
          'five_first_saturdays',
        );
        expect(
          written!.completedItemsByDay.keys,
          containsAll(<String>[
            'confession:2026-12-05',
            'communion:2026-12-05',
          ]),
        );
      },
    );

    test('a different day starts fresh over the stale snapshot', () async {
      final ContentPack saturdays = _assetPack('five_first_saturdays');
      final _FakeProgramRepository repository = _FakeProgramRepository(
        packs: <ContentPack>[saturdays],
      );
      final DevotionalsDatabase database = _inMemoryDatabase();
      final SessionPlayerController first = SessionPlayerController(
        repository: repository,
        database: database,
        clock: () => DateTime(2026, 12, 5, 8),
      );
      await first.startSession(
        'five_first_saturdays',
        forDate: DateTime(2026, 12, 5),
      );
      await first.completeStep();
      expect(first.state.session.stepIndex, 1);

      final SessionPlayerController nextMonth = SessionPlayerController(
        repository: repository,
        database: database,
        clock: () => DateTime(2027, 1, 2, 8),
      );
      await nextMonth.startSession(
        'five_first_saturdays',
        forDate: DateTime(2027, 1, 2),
      );

      expect(nextMonth.state.session.stepIndex, 0);
      final Map<String, dynamic>? snapshot = await _snapshot(
        database,
        'five_first_saturdays',
      );
      expect(snapshot!['day'], '2027-01-02');
    });

    test('a completed snapshot that outlived its completion write is resumed '
        'finalized and never written twice', () async {
      final ContentPack saturdays = _assetPack('five_first_saturdays');
      final _FakeProgramRepository repository = _FakeProgramRepository(
        packs: <ContentPack>[saturdays],
      );
      final DevotionalsDatabase database = _inMemoryDatabase();

      // The walk the crash left behind: complete, with the required
      // checkpoint recorded (Task 9's gate is satisfied).
      SessionState walked = SessionRunner.forState(saturdays.session);
      while (!walked.isComplete) {
        final SessionStep step = saturdays.session.steps[walked.stepIndex];
        if (step is BeadGroupStep) {
          walked = SessionRunner.record(walked, step.hailMaryCount);
        }
        walked = SessionRunner.completeCurrent(
          walked,
          script: saturdays.session,
        );
      }
      // The completion landed (saveProgress done) and the app died before
      // the snapshot was cleared: ordinal 1, one badge, both on disk.
      final ProgressState alreadyWritten = ProgressState(
        packId: 'five_first_saturdays',
        fulfilledOrdinals: 1,
        lastFulfilled: DateTime(2026, 12, 5),
        completedItemsByDay: const <String, String>{
          'communion:2026-12-05': 'done',
        },
        badges: <BadgeRecord>[
          BadgeRecord(title: saturdays.title, date: DateTime(2026, 12, 5)),
        ],
      );
      repository.progress['five_first_saturdays'] = alreadyWritten;
      await database.setMeta(
        'active_session_five_first_saturdays',
        jsonEncode(<String, dynamic>{
          'packId': 'five_first_saturdays',
          'day': '2026-12-05',
          'dayIndex': null,
          'variant': <String, dynamic>{},
          'session': walked.toJson(),
          'checkpoints': <String, bool>{'communion': true},
          'checkpointDates': <String, String>{'communion': '2026-12-05'},
          'reflectionEndsAt': null,
          'tokens': <String, String>{},
        }),
      );

      final SessionPlayerController controller = SessionPlayerController(
        repository: repository,
        database: database,
        clock: () => DateTime(2026, 12, 5, 20),
        resumePackId: 'five_first_saturdays',
      );
      await controller.ready;

      expect(controller.state.status, SessionPlayerStatus.finalized);
      expect(controller.state.isFinalizable, isTrue);
      expect(
        await _snapshot(database, 'five_first_saturdays'),
        isNull,
        reason: 'the stale completed snapshot is cleared on resume',
      );
      expect(repository.saves, isEmpty, reason: 'no completion was written');

      // Any later player interaction stays out of the completion writer.
      await controller.toggleCheckpoint('communion');
      await controller.completeStep();

      expect(repository.saves, isEmpty);
      final ProgressState? progressed = await repository.progressFor(
        'five_first_saturdays',
      );
      expect(progressed!.fulfilledOrdinals, 1);
      expect(progressed.badges, hasLength(1));
      expect(progressed.lastFulfilled, DateTime(2026, 12, 5));
      expect(await _snapshot(database, 'five_first_saturdays'), isNull);
    });
  });

  group('SessionPlayerController.tickReflection', () {
    test('the reflection deadline persists and clears', () async {
      final ContentPack reflectionPack = ContentPack(
        id: 'reflection_pack',
        title: 'Reflection pack',
        family: PackFamily.routine,
        schedule: TimeOfDaySpec(21, 0),
        session: SessionScript(
          id: 'reflection-session',
          steps: <SessionStep>[
            const ReflectionStep(
              id: 'silence',
              title: 'Silence',
              duration: Duration(minutes: 10),
            ),
          ],
        ),
      );
      final _FakeProgramRepository repository = _FakeProgramRepository(
        packs: <ContentPack>[reflectionPack],
      );
      final DevotionalsDatabase database = _inMemoryDatabase();
      final DateTime now = DateTime(2026, 12, 5, 21);
      final SessionPlayerController controller = SessionPlayerController(
        repository: repository,
        database: database,
        clock: () => now,
      );

      await controller.startSession(
        'reflection_pack',
        forDate: DateTime(2026, 12, 5),
      );
      expect(controller.state.reflectionEndsAt, isNull);

      await controller.tickReflection(const Duration(minutes: 5));
      expect(
        controller.state.reflectionEndsAt,
        now.add(const Duration(minutes: 5)),
      );
      final Map<String, dynamic>? snapshot = await _snapshot(
        database,
        'reflection_pack',
      );
      expect(
        snapshot!['reflectionEndsAt'],
        now.add(const Duration(minutes: 5)).toIso8601String(),
      );

      // Pause/resume restores the running deadline from the snapshot.
      final SessionPlayerController resumed = SessionPlayerController(
        repository: repository,
        database: database,
        clock: () => now.add(const Duration(minutes: 2)),
        resumePackId: 'reflection_pack',
      );
      await resumed.ready;
      expect(
        resumed.state.reflectionEndsAt,
        now.add(const Duration(minutes: 5)),
      );

      await controller.tickReflection(Duration.zero);
      expect(controller.state.reflectionEndsAt, isNull);
    });
  });
}
