// Missed-day flow + session-completion writer tests (Plan 2, Task 9).
//
// Pins the two app-layer contracts this task owns:
//
// - Review Focus 6 (missed-day application order): the verdict runs against
//   the PERSISTED `lastFulfilled` before any today's-session write, and
//   `askUser` surfaces before new progress lands (it can never be applied).
//   A strict reset zeroes the streak and its badges; a permissive resume
//   leaves the persisted state untouched.
// - Plan-2 contract (a) (checkpoint gate): a session may only be finalized
//   when every `CheckpointStep.requiredForCompletion` step is present and
//   true in the session's checkpoint map; otherwise the pre-final
//   `SessionState` comes back unchanged and NOTHING is persisted — the
//   player renders the missing items from `missingRequiredItems`.
//
// The carry-forwards from Task 8 are pinned here too: commitment anchors are
// credited by the UNION of the two rules — grace-window items by
// `GraceWindowService.creditCheckpointsForAnchors` (never the per-anchor
// view), anchor-day items by their exact `<item>:<yyyy-mm-dd>` completion
// key — and completions dated after today never credit anything.
import 'package:flutter_test/flutter_test.dart';
import 'package:sancta_via_devotional_engine/sancta_via_devotional_engine.dart';
import 'package:sancta_via_devotional_engine_riverpod/sancta_via_devotional_engine_riverpod.dart'
    show ProgramRepository;
import 'package:sancta_via_devotionals/services/progress_service.dart';

/// A repository double that records every write, so "nothing was persisted"
/// is assertable rather than merely invisible.
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

/// The Five First Saturdays shape from the engine's own fixture: First
/// Saturdays of the month, a ±8-day confession grace window, and a session
/// whose `confession` checkpoint is NOT required for completion (it may land
/// in the grace window instead) while `communion` is.
ContentPack _firstSaturdaysPack({
  RestartPolicy policy = RestartPolicy.strict,
  List<GraceWindow>? windows,
}) {
  return ContentPack(
    id: 'five_first_saturdays',
    title: 'Five First Saturdays',
    family: PackFamily.commitment,
    schedule: ConsecutiveCommitmentSpec(
      anchor: NthWeekdayOfMonthSpec(DateTime.saturday, 1),
      count: 5,
      policy: policy,
      windows:
          windows ??
          <GraceWindow>[
            GraceWindow(item: 'confession', beforeDays: 8, afterDays: 8),
          ],
    ),
    session: SessionScript(
      id: 'five-first-saturdays-session',
      steps: <SessionStep>[
        const CheckpointStep(
          id: 'confession-step',
          item: 'confession',
          requiredForCompletion: false,
        ),
        const CheckpointStep(
          id: 'communion-step',
          item: 'communion',
          requiredForCompletion: true,
        ),
      ],
    ),
  );
}

/// The Nine First Fridays shape: no grace windows and a single required
/// anchor-day checkpoint.
ContentPack _firstFridaysPack() {
  return ContentPack(
    id: 'nine_first_fridays',
    title: 'Nine First Fridays',
    family: PackFamily.commitment,
    schedule: ConsecutiveCommitmentSpec(
      anchor: NthWeekdayOfMonthSpec(DateTime.friday, 1),
      count: 9,
      policy: RestartPolicy.strict,
    ),
    session: SessionScript(
      id: 'nine-first-fridays-session',
      steps: <SessionStep>[
        const CheckpointStep(
          id: 'communion-step',
          item: 'communion',
          requiredForCompletion: true,
        ),
      ],
    ),
  );
}

/// A routine pack with no commitment and no checkpoints (the Angelus shape):
/// one session a day, no anchor evaluation.
ContentPack _routinePack() {
  return ContentPack(
    id: 'angelus',
    title: 'The Angelus',
    family: PackFamily.routine,
    schedule: TimeOfDaySpec(6, 0, baseLabel: 'angelus'),
    session: SessionScript(
      id: 'angelus-session',
      steps: <SessionStep>[
        PrayerStep(
          id: 'angelus-prayer',
          text: PrayerText(
            id: 'angelus_text',
            text: 'The Angel of the Lord declared unto Mary.',
            source: 'Traditional',
            license: 'public-domain',
          ),
        ),
      ],
    ),
  );
}

/// Walks [pack]'s whole session, as the player does before completion.
SessionState _walked(ContentPack pack) {
  SessionState state = SessionRunner.forState(pack.session);
  while (!state.isComplete) {
    state = SessionRunner.completeCurrent(state, script: pack.session);
  }
  return state;
}

/// The First Saturdays of September 2026 through January 2027 — the five
/// anchor positions the 5/5 fixture completes.
final List<DateTime> _fiveSaturdays = <DateTime>[
  DateTime(2026, 9, 5),
  DateTime(2026, 10, 3),
  DateTime(2026, 11, 7),
  DateTime(2026, 12, 5),
  DateTime(2027, 1, 2),
];

/// Completion records satisfying [anchors] of the First Saturdays pack:
/// communion on the anchor day (the anchor-day rule) and confession on the
/// anchor day (an exact-day grace-window credit).
Map<String, String> _saturdayCompletions(List<DateTime> anchors) {
  final Map<String, String> completions = <String, String>{};
  for (final DateTime anchor in anchors) {
    final String day =
        '${anchor.year.toString().padLeft(4, '0')}-'
        '${anchor.month.toString().padLeft(2, '0')}-'
        '${anchor.day.toString().padLeft(2, '0')}';
    completions['communion:$day'] = 'First Saturday Mass';
    completions['confession:$day'] = 'First Saturday confession';
  }
  return completions;
}

/// A persisted progress state with [ordinals] badges already earned.
ProgressState _progressed({
  required String packId,
  required int ordinals,
  required DateTime lastFulfilled,
  Map<String, String>? completedItemsByDay,
  List<BadgeRecord>? badges,
}) {
  return ProgressState(
    packId: packId,
    fulfilledOrdinals: ordinals,
    lastFulfilled: lastFulfilled,
    repetitionsToday: 2,
    completedItemsByDay: completedItemsByDay ?? const <String, String>{},
    badges:
        badges ??
        <BadgeRecord>[
          BadgeRecord(title: 'Five First Saturdays', date: lastFulfilled),
        ],
  );
}

void main() {
  group('ProgressService.missedVerdict', () {
    test('askUser surfaces first when the state has nothing to reset, '
        'even under strict', () {
      // Zero fulfilled ordinals: there is no streak to continue or void, so
      // the rule itself demands the user's choice — the pack policy cannot
      // override it (Review Focus 6: askUser surfaces FIRST).
      final ProgressState state = ProgressState(
        packId: 'five_first_saturdays',
        lastFulfilled: DateTime(2026, 12, 5),
      );

      expect(
        ProgressService.missedVerdict(state, 'strict', DateTime(2027, 1, 1)),
        MissedDayVerdict.askUser,
      );
      expect(
        ProgressService.missedVerdict(
          state,
          'permissive',
          DateTime(2027, 1, 1),
        ),
        MissedDayVerdict.askUser,
      );
    });

    test('askUser when no progress was ever persisted', () {
      expect(
        ProgressService.missedVerdict(null, 'strict', DateTime(2027, 1, 1)),
        MissedDayVerdict.askUser,
        reason:
            'Nothing has been fulfilled, so nothing can be resumed or '
            'reset: the user starts afresh',
      );
    });

    test(
      'strict reads reset across a gap after the persisted lastFulfilled',
      () {
        // A daily-cadence series (the 54-day novena shape): the evaluator's
        // gap rule is exact for consecutive positions on adjacent calendar
        // days, and anchor-recurring commitments must not be driven by it.
        final ProgressState state = _progressed(
          packId: 'novena_54_day',
          ordinals: 5,
          lastFulfilled: DateTime(2026, 12, 5),
        );

        expect(
          ProgressService.missedVerdict(state, 'strict', DateTime(2027, 1, 1)),
          MissedDayVerdict.reset,
          reason:
              'The verdict runs against the PERSISTED lastFulfilled '
              '(2026-12-05), not the evaluation date',
        );
      },
    );

    test('permissive reads resume across the same gap', () {
      final ProgressState state = _progressed(
        packId: 'novena_54_day',
        ordinals: 5,
        lastFulfilled: DateTime(2026, 12, 5),
      );

      expect(
        ProgressService.missedVerdict(
          state,
          'permissive',
          DateTime(2027, 1, 1),
        ),
        MissedDayVerdict.resume,
      );
    });

    test('strict resumes when the evaluation date directly follows the '
        'lastFulfilled date', () {
      final ProgressState state = _progressed(
        packId: 'novena_54_day',
        ordinals: 5,
        lastFulfilled: DateTime(2026, 12, 31),
      );

      expect(
        ProgressService.missedVerdict(state, 'strict', DateTime(2027, 1, 1)),
        MissedDayVerdict.resume,
        reason: 'No calendar day lies strictly between adjacent dates',
      );
    });

    test('an unknown policy throws, as the engine does', () {
      expect(
        () => ProgressService.missedVerdict(
          _progressed(
            packId: 'novena_54_day',
            ordinals: 5,
            lastFulfilled: DateTime(2026, 12, 5),
          ),
          'lenient',
          DateTime(2027, 1, 1),
        ),
        throwsArgumentError,
        reason: 'Unknown policies must never fall back to a silent default',
      );
    });
  });

  group('ProgressService.applyMissedDay', () {
    test(
      'a strict reset zeroes the streak but keeps the earned badges',
      () async {
        final ContentPack pack = _firstSaturdaysPack();
        final ProgressState persisted = _progressed(
          packId: pack.id,
          ordinals: 4,
          lastFulfilled: DateTime(2026, 12, 5),
          completedItemsByDay: const <String, String>{
            'communion:2026-12-05': 'First Saturday Mass',
          },
          badges: <BadgeRecord>[
            BadgeRecord(title: pack.title, date: DateTime(2026, 9, 5)),
            BadgeRecord(title: pack.title, date: DateTime(2026, 10, 3)),
            BadgeRecord(title: pack.title, date: DateTime(2026, 11, 7)),
            BadgeRecord(title: pack.title, date: DateTime(2026, 12, 5)),
          ],
        );
        final _FakeProgramRepository repository = _FakeProgramRepository(
          packs: <ContentPack>[pack],
        );
        repository.progress[pack.id] = persisted;
        final ProgressService service = ProgressService(repository: repository);

        await service.applyMissedDay(
          packId: pack.id,
          verdict: MissedDayVerdict.reset,
        );

        final ProgressState? reset = await repository.progressFor(pack.id);
        expect(reset, isNotNull);
        expect(reset!.fulfilledOrdinals, 0);
        expect(reset.lastFulfilled, isNull);
        expect(reset.repetitionsToday, 0);
        expect(
          reset.badges,
          persisted.badges,
          reason:
              'Badges are the dated completion history the lifetime count is '
              'built from, not streak state: a reset voids only the streak',
        );
        expect(
          reset.completedItemsByDay,
          persisted.completedItemsByDay,
          reason:
              'Completion records are raw history, not streak state, so a '
              'reset keeps them',
        );
        expect(repository.saves, hasLength(1));
      },
    );

    test('a permissive resume keeps the persisted state untouched', () async {
      final ContentPack pack = _firstSaturdaysPack();
      final ProgressState persisted = _progressed(
        packId: pack.id,
        ordinals: 3,
        lastFulfilled: DateTime(2026, 11, 7),
      );
      final _FakeProgramRepository repository = _FakeProgramRepository(
        packs: <ContentPack>[pack],
      );
      repository.progress[pack.id] = persisted;
      final ProgressService service = ProgressService(repository: repository);

      await service.applyMissedDay(
        packId: pack.id,
        verdict: MissedDayVerdict.resume,
      );

      final ProgressState? kept = await repository.progressFor(pack.id);
      expect(kept!.fulfilledOrdinals, 3);
      expect(kept.lastFulfilled, DateTime(2026, 11, 7));
      expect(kept.badges, hasLength(1));
      expect(
        repository.saves,
        isEmpty,
        reason: 'A resume changes nothing, so nothing is written',
      );
    });

    test('askUser can never be applied — it must surface first', () async {
      final ContentPack pack = _firstSaturdaysPack();
      final _FakeProgramRepository repository = _FakeProgramRepository(
        packs: <ContentPack>[pack],
      );
      repository.progress[pack.id] = _progressed(
        packId: pack.id,
        ordinals: 2,
        lastFulfilled: DateTime(2026, 10, 3),
      );
      final ProgressService service = ProgressService(repository: repository);

      await expectLater(
        service.applyMissedDay(
          packId: pack.id,
          verdict: MissedDayVerdict.askUser,
        ),
        throwsArgumentError,
        reason: 'The user has not chosen yet: no new progress may land',
      );
      expect(repository.saves, isEmpty);
    });

    test('no persisted progress leaves the store untouched', () async {
      final ContentPack pack = _firstSaturdaysPack();
      final _FakeProgramRepository repository = _FakeProgramRepository(
        packs: <ContentPack>[pack],
      );
      final ProgressService service = ProgressService(repository: repository);

      await service.applyMissedDay(
        packId: pack.id,
        verdict: MissedDayVerdict.reset,
      );

      expect(repository.saves, isEmpty);
      expect(await repository.progressFor(pack.id), isNull);
    });
  });

  group('ProgressService.completeSession (the checkpoint gate)', () {
    test('an unsatisfied required checkpoint keeps the session pre-final and '
        'writes nothing', () async {
      final ContentPack pack = _firstSaturdaysPack();
      final _FakeProgramRepository repository = _FakeProgramRepository(
        packs: <ContentPack>[pack],
      );
      final ProgressService service = ProgressService(repository: repository);
      final SessionState walked = _walked(pack);

      final SessionState result = await service.completeSession(
        state: walked,
        pack: pack,
        checkpointStates: <String, bool>{'confession': true},
        completedItemsByDay: _saturdayCompletions(<DateTime>[
          DateTime(2026, 11, 7),
        ]),
        today: DateTime(2026, 11, 7),
      );

      expect(
        result,
        same(walked),
        reason:
            'The pre-final state is returned '
            'unchanged: the player renders what is missing',
      );
      expect(
        ProgressService.missingRequiredItems(pack, <String, bool>{
          'confession': true,
        }),
        <String>['communion'],
      );
      expect(repository.saves, isEmpty);
      expect(await repository.progressFor(pack.id), isNull);
    });

    test('an unfinished session is never finalized', () async {
      final ContentPack pack = _firstSaturdaysPack();
      final _FakeProgramRepository repository = _FakeProgramRepository(
        packs: <ContentPack>[pack],
      );
      final ProgressService service = ProgressService(repository: repository);
      final SessionState started = SessionRunner.forState(pack.session);

      final SessionState result = await service.completeSession(
        state: started,
        pack: pack,
        checkpointStates: <String, bool>{'confession': true, 'communion': true},
        completedItemsByDay: _saturdayCompletions(<DateTime>[
          DateTime(2026, 11, 7),
        ]),
        today: DateTime(2026, 11, 7),
      );

      expect(result, same(started));
      expect(repository.saves, isEmpty);
    });

    test(
      'satisfied required checkpoints finalize the session and persist it',
      () async {
        final ContentPack pack = _firstSaturdaysPack();
        final _FakeProgramRepository repository = _FakeProgramRepository(
          packs: <ContentPack>[pack],
        );
        final ProgressService service = ProgressService(repository: repository);
        final SessionState walked = _walked(pack);

        final SessionState result = await service.completeSession(
          state: walked,
          pack: pack,
          checkpointStates: <String, bool>{
            'confession': true,
            'communion': true,
          },
          completedItemsByDay: _saturdayCompletions(<DateTime>[
            DateTime(2026, 11, 7),
          ]),
          today: DateTime(2026, 11, 7),
        );

        expect(result, same(walked));
        final ProgressState? written = await repository.progressFor(pack.id);
        expect(written, isNotNull);
        expect(written!.fulfilledOrdinals, 1);
        expect(written.lastFulfilled, DateTime(2026, 11, 7));
        expect(written.badges, hasLength(1));
      },
    );

    test(
      'a checkpoint that is not required for completion may be skipped',
      () async {
        final ContentPack pack = _firstSaturdaysPack();
        final _FakeProgramRepository repository = _FakeProgramRepository(
          packs: <ContentPack>[pack],
        );
        final ProgressService service = ProgressService(repository: repository);

        await service.completeSession(
          state: _walked(pack),
          pack: pack,
          checkpointStates: <String, bool>{'communion': true},
          completedItemsByDay: <String, String>{
            'communion:2026-11-07': 'First Saturday Mass',
          },
          today: DateTime(2026, 11, 7),
        );

        final ProgressState? written = await repository.progressFor(pack.id);
        expect(
          written,
          isNotNull,
          reason:
              'The session gate passed: the '
              'confession checkpoint is not required for completion (it lands in '
              'the grace window instead), so the completion is written',
        );
        expect(
          written!.fulfilledOrdinals,
          1,
          reason:
              'The ordinal is streak arithmetic (persisted 0 + 1); the '
              'anchor itself is NOT credited — the composition answers that '
              'separately',
        );
        expect(
          ProgressService.fulfilledAnchorDates(
            pack: pack,
            spec: pack.schedule as ConsecutiveCommitmentSpec,
            completedItemsByDay: written.completedItemsByDay,
            today: DateTime(2026, 11, 7),
          ),
          isEmpty,
          reason:
              'The devotion\'s anchor still asks for the confession: with no '
              'credit in the ±8-day window no anchor is fulfilled',
        );
      },
    );

    test(
      'a required checkpoint that is present and FALSE blocks the gate',
      () async {
        // The ruling proves the gate end-to-end at the service level: a
        // checkpoint the player has recorded as not done is exactly as
        // blocking as one that was never touched.
        final ContentPack pack = _firstSaturdaysPack();
        final _FakeProgramRepository repository = _FakeProgramRepository(
          packs: <ContentPack>[pack],
        );
        final ProgressService service = ProgressService(repository: repository);
        final SessionState walked = _walked(pack);

        final SessionState result = await service.completeSession(
          state: walked,
          pack: pack,
          checkpointStates: <String, bool>{
            'confession': true,
            'communion': false,
          },
          completedItemsByDay: _saturdayCompletions(<DateTime>[
            DateTime(2026, 11, 7),
          ]),
          today: DateTime(2026, 11, 7),
        );

        expect(result, same(walked));
        expect(
          ProgressService.missingRequiredItems(pack, <String, bool>{
            'communion': false,
          }),
          <String>['communion'],
        );
        expect(repository.saves, isEmpty);
        expect(await repository.progressFor(pack.id), isNull);
      },
    );

    test(
      'a records-free completion advances claimed ordinals by one',
      () async {
        // Task 20's onboarding claims positions without completion records
        // (e.g. 3 ordinals, "I have kept three First Saturdays"). The ordinal
        // is the persisted streak plus one, so the first completed session
        // lands on 4 — no completion records needed.
        final ContentPack pack = _firstSaturdaysPack();
        final _FakeProgramRepository repository = _FakeProgramRepository(
          packs: <ContentPack>[pack],
        );
        repository.progress[pack.id] = ProgressState(
          packId: pack.id,
          fulfilledOrdinals: 3,
          lastFulfilled: DateTime(2026, 10, 3),
        );
        final ProgressService service = ProgressService(repository: repository);

        await service.completeSession(
          state: _walked(pack),
          pack: pack,
          checkpointStates: <String, bool>{
            'confession': true,
            'communion': true,
          },
          completedItemsByDay: const <String, String>{},
          today: DateTime(2026, 11, 7),
        );

        final ProgressState? written = await repository.progressFor(pack.id);
        expect(written!.fulfilledOrdinals, 4);
        expect(written.lastFulfilled, DateTime(2026, 11, 7));
        expect(written.badges, hasLength(1));
      },
    );

    test('missingRequiredItems names required steps only, in script order', () {
      final ContentPack pack = ContentPack(
        id: 'checkpoints',
        title: 'Checkpoints',
        family: PackFamily.commitment,
        schedule: TimeOfDaySpec(6, 0),
        session: SessionScript(
          id: 'checkpoints-session',
          steps: <SessionStep>[
            const CheckpointStep(
              id: 'a',
              item: 'rosary',
              requiredForCompletion: true,
            ),
            const CheckpointStep(
              id: 'b',
              item: 'confession',
              requiredForCompletion: false,
            ),
            const CheckpointStep(
              id: 'c',
              item: 'communion',
              requiredForCompletion: true,
            ),
          ],
        ),
      );

      expect(
        ProgressService.missingRequiredItems(pack, <String, bool>{
          'rosary': false,
        }),
        <String>['rosary', 'communion'],
      );
    });
  });

  group('ProgressService.persistCompletion (commitments)', () {
    test(
      'a satisfied 5th Saturday appends badge 5 and stores ordinal 5',
      () async {
        final ContentPack pack = _firstSaturdaysPack();
        final _FakeProgramRepository repository = _FakeProgramRepository(
          packs: <ContentPack>[pack],
        );
        final ProgressState persisted = ProgressState(
          packId: pack.id,
          fulfilledOrdinals: 4,
          lastFulfilled: DateTime(2026, 12, 5),
          repetitionsToday: 3,
          completedItemsByDay: _saturdayCompletions(
            _fiveSaturdays.take(4).toList(),
          ),
          badges: <BadgeRecord>[
            for (final DateTime anchor in _fiveSaturdays.take(4))
              BadgeRecord(title: pack.title, date: anchor),
          ],
        );
        final ProgressService service = ProgressService(repository: repository);

        await service.persistCompletion(
          pack: pack,
          progress: persisted,
          completedItemsByDay: _saturdayCompletions(<DateTime>[
            DateTime(2027, 1, 2),
          ]),
          today: DateTime(2027, 1, 2),
        );

        final ProgressState? written = await repository.progressFor(pack.id);
        expect(written!.fulfilledOrdinals, 5);
        expect(written.lastFulfilled, DateTime(2027, 1, 2));
        expect(written.badges, hasLength(5));
        expect(
          ProgressService.fulfilledAnchorDates(
            pack: pack,
            spec: pack.schedule as ConsecutiveCommitmentSpec,
            completedItemsByDay: written.completedItemsByDay,
            today: DateTime(2027, 1, 2),
          ),
          _fiveSaturdays.toSet(),
          reason: 'All five anchors are fulfilled by their records',
        );
        expect(
          written.badges.last.date,
          DateTime(2027, 1, 2),
          reason: 'The fifth badge is dated today',
        );
        expect(written.badges.last.title, pack.title);
        expect(written.repetitionsToday, 0, reason: 'The day counter resets');
        expect(
          written.completedItemsByDay.length,
          10,
          reason: 'The five anchors keep both of their completion records',
        );
      },
    );

    test(
      'a window item gates its anchor through the grace-window service',
      () async {
        // Four anchors are fully satisfied; the fifth has its anchor-day
        // communion but no confession anywhere in the ±8-day window, so the
        // fifth anchor is NOT fulfilled (the service credits only
        // grace-window items). The stored ordinal is streak arithmetic and is
        // not rewritten by this: the composition is what reports the miss.
        final ContentPack pack = _firstSaturdaysPack();
        final Map<String, String> completions = _saturdayCompletions(
          _fiveSaturdays.take(4).toList(),
        );
        completions['communion:2027-01-02'] = 'First Saturday Mass';
        final ConsecutiveCommitmentSpec commitment =
            pack.schedule as ConsecutiveCommitmentSpec;
        final Set<DateTime> fulfilled = ProgressService.fulfilledAnchorDates(
          pack: pack,
          spec: commitment,
          completedItemsByDay: completions,
          today: DateTime(2027, 1, 2),
        );

        expect(fulfilled, _fiveSaturdays.take(4).toSet());
        expect(
          fulfilled,
          isNot(contains(DateTime(2027, 1, 2))),
          reason: "The fifth anchor's confession never came",
        );
      },
    );

    test(
      'an anchor-day required item is not credited by any grace window',
      () async {
        // Mirror of the previous case: the fifth anchor has its confession but
        // no communion on the anchor day. The engine's anchor-day rule decides
        // that item; no window can credit it.
        final ContentPack pack = _firstSaturdaysPack();
        final Map<String, String> completions = _saturdayCompletions(
          _fiveSaturdays.take(4).toList(),
        );
        completions['confession:2027-01-02'] = 'First Saturday confession';
        final Set<DateTime> fulfilled = ProgressService.fulfilledAnchorDates(
          pack: pack,
          spec: pack.schedule as ConsecutiveCommitmentSpec,
          completedItemsByDay: completions,
          today: DateTime(2027, 1, 2),
        );

        expect(fulfilled, _fiveSaturdays.take(4).toSet());
      },
    );

    test('a window-only completion credits its anchor', () async {
      final ContentPack pack = _firstSaturdaysPack();

      final Set<DateTime> fulfilled = ProgressService.fulfilledAnchorDates(
        pack: pack,
        spec: pack.schedule as ConsecutiveCommitmentSpec,
        completedItemsByDay: <String, String>{
          'communion:2026-11-07': 'First Saturday Mass',
          'confession:2026-10-30': 'eight days early',
        },
        today: DateTime(2026, 11, 7),
      );

      expect(fulfilled, <DateTime>{
        DateTime(2026, 11, 7),
      }, reason: 'The confession sits on the inclusive -8 day edge');
    });

    test('a future-dated completion never credits an anchor', () async {
      // The grace-window service does none of the engine's "ignore
      // completions after today" filtering, so the service must: a
      // confession dated eight days AFTER today is in the window but is
      // still in the future, so it credits nothing.
      final ContentPack pack = _firstSaturdaysPack();
      final _FakeProgramRepository repository = _FakeProgramRepository(
        packs: <ContentPack>[pack],
      );
      final ProgressService service = ProgressService(repository: repository);

      final Set<DateTime> fulfilled = ProgressService.fulfilledAnchorDates(
        pack: pack,
        spec: pack.schedule as ConsecutiveCommitmentSpec,
        completedItemsByDay: <String, String>{
          'communion:2026-11-07': 'First Saturday Mass',
          'confession:2026-11-15': 'recorded ahead of time',
        },
        today: DateTime(2026, 11, 7),
      );
      expect(fulfilled, isEmpty);

      await service.persistCompletion(
        pack: pack,
        progress: ProgressState(packId: pack.id),
        completedItemsByDay: <String, String>{
          'communion:2026-11-07': 'First Saturday Mass',
          'confession:2026-11-15': 'recorded ahead of time',
        },
        today: DateTime(2026, 11, 7),
      );

      final ProgressState? written = await repository.progressFor(pack.id);
      expect(
        written!.completedItemsByDay,
        contains('confession:2026-11-15'),
        reason: 'The record is kept — only the evaluation ignores it',
      );
    });

    test(
      'a commitment without grace windows uses its anchor-day items only',
      () async {
        final ContentPack pack = _firstFridaysPack();

        final Set<DateTime> fulfilled = ProgressService.fulfilledAnchorDates(
          pack: pack,
          spec: pack.schedule as ConsecutiveCommitmentSpec,
          completedItemsByDay: <String, String>{
            'communion:2026-11-06': 'First Friday Mass',
          },
          today: DateTime(2026, 11, 6),
        );

        expect(fulfilled, <DateTime>{DateTime(2026, 11, 6)});
      },
    );

    test('a progress state for another pack is refused', () async {
      final ContentPack pack = _firstFridaysPack();
      final ProgressService service = ProgressService(
        repository: _FakeProgramRepository(packs: <ContentPack>[pack]),
      );

      await expectLater(
        service.persistCompletion(
          pack: pack,
          progress: ProgressState(packId: 'angelus'),
          completedItemsByDay: const <String, String>{},
          today: DateTime(2026, 11, 6),
        ),
        throwsArgumentError,
      );
    });
  });

  group('ProgressService.persistCompletion (non-commitment)', () {
    test('a routine completion increments the ordinal, resets the day '
        'counter and appends a badge', () async {
      final ContentPack pack = _routinePack();
      final _FakeProgramRepository repository = _FakeProgramRepository(
        packs: <ContentPack>[pack],
      );
      final ProgressState persisted = ProgressState(
        packId: pack.id,
        fulfilledOrdinals: 2,
        lastFulfilled: DateTime(2026, 11, 10),
        repetitionsToday: 1,
        badges: <BadgeRecord>[
          BadgeRecord(title: pack.title, date: DateTime(2026, 11, 9)),
          BadgeRecord(title: pack.title, date: DateTime(2026, 11, 10)),
        ],
      );
      final ProgressService service = ProgressService(repository: repository);

      await service.persistCompletion(
        pack: pack,
        progress: persisted,
        completedItemsByDay: const <String, String>{},
        today: DateTime(2026, 11, 12),
      );

      final ProgressState? written = await repository.progressFor(pack.id);
      expect(written!.fulfilledOrdinals, 3);
      expect(written.lastFulfilled, DateTime(2026, 11, 12));
      expect(written.repetitionsToday, 0);
      expect(written.badges, hasLength(3));
      expect(written.badges.last.date, DateTime(2026, 11, 12));
    });

    test('recorded completions are layered over the persisted ones', () async {
      final ContentPack pack = _routinePack();
      final _FakeProgramRepository repository = _FakeProgramRepository(
        packs: <ContentPack>[pack],
      );
      final ProgressService service = ProgressService(repository: repository);
      final ProgressState persisted = ProgressState(
        packId: pack.id,
        fulfilledOrdinals: 1,
        lastFulfilled: DateTime(2026, 11, 10),
        completedItemsByDay: const <String, String>{
          'communion:2026-11-10': 'kept',
        },
      );

      await service.persistCompletion(
        pack: pack,
        progress: persisted,
        completedItemsByDay: const <String, String>{
          'communion:2026-11-12': 'kept again',
        },
        today: DateTime(2026, 11, 12),
      );

      final ProgressState? written = await repository.progressFor(pack.id);
      expect(
        written!.completedItemsByDay.keys,
        containsAll(<String>['communion:2026-11-10', 'communion:2026-11-12']),
      );
    });

    test(
      'a backdated completion never moves lastFulfilled backwards',
      () async {
        final ContentPack pack = _routinePack();
        final _FakeProgramRepository repository = _FakeProgramRepository(
          packs: <ContentPack>[pack],
        );
        final ProgressService service = ProgressService(repository: repository);
        final ProgressState persisted = ProgressState(
          packId: pack.id,
          fulfilledOrdinals: 1,
          lastFulfilled: DateTime(2026, 11, 12),
        );

        await service.persistCompletion(
          pack: pack,
          progress: persisted,
          completedItemsByDay: const <String, String>{},
          today: DateTime(2026, 11, 10),
        );

        final ProgressState? written = await repository.progressFor(pack.id);
        expect(written!.lastFulfilled, DateTime(2026, 11, 12));
      },
    );
  });
}
