// Progress screen widget tests (Plan 2, Task 16).
//
// The harness mirrors Task 13/15's real-chain recipe: the REAL app repository
// over an isolated in-memory FFI store, the REAL seeded catalog (the content
// pipeline's first-launch migration), the wrapper's `programRepositoryOverride`
// chain, and `currentDateProvider` frozen with the workspace's `Stream.value`
// pattern. Every async load is drained inside `tester.runAsync` BEFORE the
// widget phase; taps are drained through short real-time windows (Task 15's
// `_drain` recipe for fake-async SQLite futures).
//
// Pinned cases (brief steps + Review Focus):
// 1. an in-progress commitment renders the ordinal counter chip at the
//    ruled position (persisted+1, fix round 1: '4 of 9') AND the
//    Projection.remainingDates line ('next: …') from the wrapper's
//    programDetailProvider;
// 2. Review Focus 2 / plan pin: a 5/5 First-Saturdays program renders
//    'Complete' with its dated badges — NEVER an ordinal chip and no
//    projection line;
// 3. the 54-day series renders the phase banner 'Petition · day 6 of 54'
//    from the pack's own day-variant data (VariantService day→phase), with
//    the series chip reading the schedule's own day index;
// 4. a strict-policy series whose lastFulfilled lags past due dates surfaces
//    the missed-day verdict with the Apply affordance; applying resets the
//    persisted streak to zero while the badge history STAYS (Task 9 ruling)
//    and the card disappears;
// 5. the per-pack policy ruling (Task 15 carry): the missed-day verdict reads
//    `enrollmentParamsFor(pack)['restartPolicy']` when present, falling back
//    to the settings default otherwise;
// 6. a completed program's and an anchor program's badges render dated
//    entries; the header's lifetime count equals the badge count
//    (documented = badges length);
// 7. intentions add/remove route through IntentionsRepository and persist in
//    the real store;
// 8. the indulgence sheet opens its static conditions checklist and the
//    one-per-day plenary cap note;
// 9. with nothing enrolled the tab shows an honest empty state, and the
//    intentions editor still renders.
//
// Fix round 1:
// 10. a fresh commitment renders the NEXT position ('1 of 9'), never the
//     completions reading '0 of 9' (the chip counts persisted+1, the same
//     position Today's `ordinal` badge reports);
// 11. the reset card's copy promises what the reset does — the streak
//     count clears, badge history stays — never 'day 1' (startDate is
//     untouched);
// 12. a progress claim with ordinals but no completion date surfaces the
//     un-anchored state read-only: `askUser` is no longer swallowed, and
//     the service's refusal to apply it is honored with no Apply button.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sancta_via_devotional_engine/sancta_via_devotional_engine.dart'
    show BadgeRecord, ProgressState;
import 'package:sancta_via_devotionals/database/devotionals_database.dart';
import 'package:sancta_via_devotionals/providers/app_settings_provider.dart'
    show missedDayDefaultPolicyProvider;
import 'package:sancta_via_devotionals/providers/content_providers.dart'
    show
        appProgramRepositoryProvider,
        contentLoadedProvider,
        intentionsProvider,
        programRepositoryOverride;
import 'package:sancta_via_devotionals/providers/progress_providers.dart'
    show progressAssemblyProvider;
import 'package:sancta_via_devotionals/repositories/program_repository.dart'
    show SqliteProgramRepository;
import 'package:sancta_via_devotionals/screens/progress/progress_screen.dart';
import 'package:sancta_via_liturgical_calendar_riverpod/sancta_via_liturgical_calendar_riverpod.dart'
    show currentDateProvider;
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// A fresh, isolated in-memory store open factory.
Future<Database> _openInMemory() =>
    openDatabase(inMemoryDatabasePath, singleInstance: false);

/// The harness a test pumps against.
class _ProgressHarness {
  const _ProgressHarness(this.container, this.repository);

  final ProviderContainer container;
  final SqliteProgramRepository repository;
}

/// Pumps the REAL `ProgressScreen` over the production provider chain,
/// settled before the widget phase.
///
/// [enrollments] maps pack id → enrollment params (the Task 15 ruling reads
/// the per-pack missed-day policy from these), and [progress] maps pack id →
/// the persisted progress state the store holds before the screen renders.
Future<_ProgressHarness> _pumpProgress(
  WidgetTester tester, {
  required DateTime today,
  Map<String, Map<String, dynamic>> enrollments =
      const <String, Map<String, dynamic>>{},
  Map<String, ProgressState> progress = const <String, ProgressState>{},
  String settingsPolicy = 'permissive',
  Size viewport = const Size(700, 4200),
}) async {
  final DevotionalsDatabase database = DevotionalsDatabase(open: _openInMemory);
  final SqliteProgramRepository repository = SqliteProgramRepository(
    database: database,
  );
  final ProviderContainer container = ProviderContainer(
    overrides: <Override>[
      appProgramRepositoryProvider.overrideWithValue(repository),
      programRepositoryOverride,
      currentDateProvider.overrideWith(
        (Ref ref) => Stream<DateTime>.value(today),
      ),
      // The policy default is a settings read in production; the harness
      // pins it directly (Task 15's recipe) so widget tests are independent
      // of SharedPreferences.
      missedDayDefaultPolicyProvider.overrideWithValue(settingsPolicy),
    ],
  );
  addTearDown(container.dispose);

  // Order matters (Task 13's recipe): seed first, then the enrollments and
  // progress land, and only then does the assembly resolve ONE time — its
  // cached future already describes the day the screen must render.
  await tester.runAsync(() async {
    await container.read(contentLoadedProvider.future);
    for (final MapEntry<String, Map<String, dynamic>> entry
        in enrollments.entries) {
      await repository.enroll(entry.key, entry.value);
    }
    for (final MapEntry<String, ProgressState> entry in progress.entries) {
      await repository.saveProgress(entry.value);
    }
    await container.read(progressAssemblyProvider.future);
    // The intentions editor reads through `intentionsProvider` in the widget
    // phase; settle it here so the first pump renders data, not loading.
    await container.read(intentionsProvider.future);
  });

  tester.view.physicalSize = viewport;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: ProgressScreen()),
    ),
  );
  await tester.pump(const Duration(milliseconds: 50));
  return _ProgressHarness(container, repository);
}

/// Flushes a tap's await chain (Task 15's recipe, widened): the fake-async
/// zone's queued microtasks clear one layer per real-time window, so the
/// rounds settle a write's reads/writes AND the post-write provider
/// invalidations' recompute — which re-resolves the whole enrolled catalog
/// (params + progress + detail, ~20 SQLite round trips), more than Task
/// 15's two-write flows needed.
Future<void> _drain(WidgetTester tester) async {
  for (int round = 0; round < 20; round++) {
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 15));
    });
    await tester.pump(const Duration(milliseconds: 15));
  }
}

/// Taps [finder] (after scrolling it into view) and drains the async chain.
Future<void> _tapAndDrain(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder.last);
  await tester.pump(const Duration(milliseconds: 10));
  await tester.tap(finder.last);
  await _drain(tester);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'an in-progress commitment renders the ordinal chip and the projection '
    'line from the program detail',
    (WidgetTester tester) async {
      await _pumpProgress(
        tester,
        today: DateTime(2026, 12, 5),
        enrollments: const <String, Map<String, dynamic>>{
          'nine_first_fridays': <String, dynamic>{},
        },
        progress: <String, ProgressState>{
          'nine_first_fridays': ProgressState(
            packId: 'nine_first_fridays',
            fulfilledOrdinals: 3,
            lastFulfilled: DateTime(2026, 11, 6),
            badges: <BadgeRecord>[
              BadgeRecord(
                title: 'Nine First Fridays of the Sacred Heart',
                date: DateTime(2026, 11, 6),
              ),
            ],
          ),
        },
      );

      // The ordinal counter chip at the ruled position (fix round 1): the
      // position the NEXT completion takes — persisted streak + 1, the
      // same position Today's `ordinal` badge reports — of the 9 First
      // Fridays.
      expect(
        find.byKey(const Key('position_chip_nine_first_fridays')),
        findsOneWidget,
      );
      expect(find.text('4 of 9'), findsOneWidget);

      // The projection line (the wrapper's Projection.remainingDates): the
      // next First Fridays after 2026-12-05 are Jan 1, Feb 5, Mar 5, …
      expect(
        find.byKey(const Key('projection_line_nine_first_fridays')),
        findsOneWidget,
      );
      expect(find.textContaining('next: Jan 1, Feb 5, Mar 5'), findsOneWidget);

      // Not complete: no 'Complete' state anywhere.
      expect(find.text('Complete'), findsNothing);

      // The dated badge entry and the lifetime count (one badge earned).
      expect(find.text('2026-11-06'), findsOneWidget);
      final Text lifetime = tester.widget<Text>(
        find.byKey(const Key('lifetime_count')),
      );
      expect(lifetime.data, '1');
    },
  );

  testWidgets(
    'a fresh commitment renders the next position (1 of 9) — never 0 of 9 '
    '(fix round 1: the chip counts the ruled persisted+1 position)',
    (WidgetTester tester) async {
      await _pumpProgress(
        tester,
        today: DateTime(2026, 12, 5),
        enrollments: const <String, Map<String, dynamic>>{
          'nine_first_fridays': <String, dynamic>{},
        },
      );

      // No progress yet: the chip reads the position the FIRST completion
      // takes (persisted + 1 — the same position Today's `ordinal` badge
      // reports), never the '0 of 9' completions reading.
      expect(
        find.byKey(const Key('position_chip_nine_first_fridays')),
        findsOneWidget,
      );
      expect(find.text('1 of 9'), findsOneWidget);
      expect(find.text('0 of 9'), findsNothing);

      // The fresh program's projection still points at the next anchors.
      expect(
        find.byKey(const Key('projection_line_nine_first_fridays')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'Review Focus 2: a completed 5/5 First-Saturdays renders Complete with '
    'dated badges — never an ordinal',
    (WidgetTester tester) async {
      await _pumpProgress(
        tester,
        today: DateTime(2026, 12, 5),
        enrollments: const <String, Map<String, dynamic>>{
          'five_first_saturdays': <String, dynamic>{},
        },
        progress: <String, ProgressState>{
          'five_first_saturdays': ProgressState(
            packId: 'five_first_saturdays',
            fulfilledOrdinals: 5,
            lastFulfilled: DateTime(2026, 11, 7),
            badges: <BadgeRecord>[
              BadgeRecord(
                title: 'Five First Saturdays of Our Lady',
                date: DateTime(2026, 8, 1),
              ),
              BadgeRecord(
                title: 'Five First Saturdays of Our Lady',
                date: DateTime(2026, 9, 5),
              ),
              BadgeRecord(
                title: 'Five First Saturdays of Our Lady',
                date: DateTime(2026, 10, 3),
              ),
              BadgeRecord(
                title: 'Five First Saturdays of Our Lady',
                date: DateTime(2026, 11, 7),
              ),
            ],
          ),
        },
      );

      // The completed state — never an ordinal chip, never a projection.
      expect(
        find.byKey(const Key('position_chip_five_first_saturdays')),
        findsOneWidget,
      );
      expect(find.text('Complete'), findsOneWidget);
      expect(find.text('5 of 5'), findsNothing);
      expect(
        find.byKey(const Key('projection_line_five_first_saturdays')),
        findsNothing,
      );
      expect(find.textContaining('next:'), findsNothing);

      // The completed program is not due (the plan's resurrection pin): the
      // row stays a Complete state without any due-session residue.
      expect(
        find.byKey(const Key('missed_day_five_first_saturdays')),
        findsNothing,
      );

      // The dated badge entries with their dates, and the header's lifetime
      // count = the badge count.
      expect(find.textContaining('2026-08-01'), findsOneWidget);
      expect(find.textContaining('2026-09-05'), findsOneWidget);
      expect(find.textContaining('2026-10-03'), findsOneWidget);
      expect(find.textContaining('2026-11-07'), findsOneWidget);
      final Text lifetime = tester.widget<Text>(
        find.byKey(const Key('lifetime_count')),
      );
      expect(lifetime.data, '4');
    },
  );

  testWidgets(
    'the 54-day series renders the phase banner from the pack variants and '
    'the series day chip',
    (WidgetTester tester) async {
      // The seeded series starts 2026-11-10, so 2026-11-15 is day 6 — the
      // pack's own day-6 variant carries phase 'petition' (VariantService's
      // day→phase seam, nothing hardcoded in the app).
      await _pumpProgress(
        tester,
        today: DateTime(2026, 11, 15),
        enrollments: const <String, Map<String, dynamic>>{
          'novena_54_day': <String, dynamic>{'via': 'test'},
        },
        progress: <String, ProgressState>{
          'novena_54_day': ProgressState(
            packId: 'novena_54_day',
            fulfilledOrdinals: 5,
            lastFulfilled: DateTime(2026, 11, 15),
            badges: <BadgeRecord>[
              BadgeRecord(
                title: 'The 54-Day Rosary Novena',
                date: DateTime(2026, 11, 15),
              ),
            ],
          ),
        },
      );

      // The series chip reads the schedule's own day index: day 6 of 54.
      expect(
        find.byKey(const Key('position_chip_novena_54_day')),
        findsOneWidget,
      );
      expect(find.text('day 6 of 54'), findsOneWidget);

      // The phase banner reads the pack's variant data for day 6.
      expect(
        find.byKey(const Key('phase_banner_novena_54_day')),
        findsOneWidget,
      );
      expect(find.text('Petition · day 6 of 54'), findsOneWidget);

      // Kept current (lastFulfilled = today): no missed-day card under the
      // default permissive policy.
      expect(find.byKey(const Key('missed_day_novena_54_day')), findsNothing);
      expect(find.text('Complete'), findsNothing);
    },
  );

  testWidgets(
    'a lagging strict series surfaces the missed-day verdict; applying keeps '
    'the badges and zeroes the streak (Task 9)',
    (WidgetTester tester) async {
      final _ProgressHarness harness = await _pumpProgress(
        tester,
        today: DateTime(2026, 11, 15),
        enrollments: const <String, Map<String, dynamic>>{
          // The per-pack policy (Task 15 carry): strict via the enrollment
          // params, overriding the settings default.
          'novena_54_day': <String, dynamic>{
            'startDate': '2026-11-10',
            'restartPolicy': 'strict',
          },
        },
        progress: <String, ProgressState>{
          'novena_54_day': ProgressState(
            packId: 'novena_54_day',
            fulfilledOrdinals: 7,
            lastFulfilled: DateTime(2026, 11, 11),
            badges: <BadgeRecord>[
              BadgeRecord(
                title: 'The 54-Day Rosary Novena',
                date: DateTime(2026, 11, 10),
              ),
              BadgeRecord(
                title: 'The 54-Day Rosary Novena',
                date: DateTime(2026, 11, 11),
              ),
            ],
          ),
        },
      );

      // The verdict card: the missed-day state (lastFulfilled lags 4 days
      // past the due dates under the strict policy) with its Apply
      // affordance.
      expect(find.byKey(const Key('missed_day_novena_54_day')), findsOneWidget);
      expect(find.textContaining('Missed days'), findsOneWidget);
      // Fix round 1: the copy promises what the reset actually does — the
      // streak COUNT clears and the badge history stays (startDate is not
      // touched; "day 1" is never promised).
      expect(find.textContaining('clears your streak count'), findsOneWidget);
      expect(find.textContaining('resets the count to day 1'), findsNothing);
      final Finder apply = find.byKey(
        const Key('apply_missed_day_novena_54_day'),
      );
      expect(apply, findsOneWidget);

      await _tapAndDrain(tester, apply);

      // The store holds the reset: the streak zeroed, the badge history
      // kept (Task 9's ruled reset semantics).

      // The store holds the reset: the streak zeroed, the badge history
      // kept (Task 9's ruled reset semantics).
      final ProgressState? stored = await tester.runAsync<ProgressState?>(
        () => harness.repository.progressFor('novena_54_day'),
      );
      expect(stored, isNotNull);
      expect(stored!.fulfilledOrdinals, 0);
      expect(stored.lastFulfilled, isNull);
      expect(stored.badges, hasLength(2));

      // The card left (fulfilled == 0 under a live series reads askUser:
      // nothing to continue or reset), the badges remain in the list, and
      // the series chip still reads the schedule's day.
      expect(find.byKey(const Key('missed_day_novena_54_day')), findsNothing);
      expect(find.text('day 6 of 54'), findsOneWidget);
      expect(find.textContaining('2026-11-10'), findsOneWidget);
      expect(find.textContaining('2026-11-11'), findsOneWidget);
    },
  );

  testWidgets(
    'a lagging series without a per-pack policy falls back to the settings '
    'default policy',
    (WidgetTester tester) async {
      await _pumpProgress(
        tester,
        today: DateTime(2026, 11, 15),
        enrollments: const <String, Map<String, dynamic>>{
          // No restartPolicy in the params: the settings default (strict in
          // this scenario) drives the verdict.
          'novena_54_day': <String, dynamic>{'via': 'test'},
        },
        progress: <String, ProgressState>{
          'novena_54_day': ProgressState(
            packId: 'novena_54_day',
            fulfilledOrdinals: 7,
            lastFulfilled: DateTime(2026, 11, 11),
          ),
        },
        settingsPolicy: 'strict',
      );

      expect(find.byKey(const Key('missed_day_novena_54_day')), findsOneWidget);
      expect(
        find.byKey(const Key('apply_missed_day_novena_54_day')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'a progress claim that wrote ordinals without a completion date renders '
    'the un-anchored state read-only (fix round 1: askUser is not swallowed)',
    (WidgetTester tester) async {
      await _pumpProgress(
        tester,
        today: DateTime(2026, 11, 15),
        enrollments: const <String, Map<String, dynamic>>{
          'novena_54_day': <String, dynamic>{'via': 'test'},
        },
        progress: <String, ProgressState>{
          // The Task-19 claim shape: ordinals recorded, NO lastFulfilled —
          // missedVerdict reads askUser for exactly this state.
          'novena_54_day': ProgressState(
            packId: 'novena_54_day',
            fulfilledOrdinals: 7,
          ),
        },
      );

      // The un-anchored card surfaces the state explicitly, read-only: the
      // service refuses to apply an askUser verdict, so there is no Apply.
      expect(
        find.byKey(const Key('unanchored_progress_novena_54_day')),
        findsOneWidget,
      );
      expect(find.textContaining('un-anchored'), findsOneWidget);
      expect(
        find.byKey(const Key('apply_missed_day_novena_54_day')),
        findsNothing,
      );
      // It is not a reset card, and the chip still reads the schedule's day.
      expect(find.byKey(const Key('missed_day_novena_54_day')), findsNothing);
      expect(find.text('day 6 of 54'), findsOneWidget);
    },
  );

  testWidgets(
    'an anchor program renders its dated badges and the header lifetime '
    'count equals the badge total',
    (WidgetTester tester) async {
      await _pumpProgress(
        tester,
        today: DateTime(2026, 12, 5),
        enrollments: const <String, Map<String, dynamic>>{
          'angelus': <String, dynamic>{},
        },
        progress: <String, ProgressState>{
          'angelus': ProgressState(
            packId: 'angelus',
            fulfilledOrdinals: 2,
            lastFulfilled: DateTime(2026, 12, 4),
            badges: <BadgeRecord>[
              BadgeRecord(
                title: 'The Angelus (Regina Caeli in Eastertide)',
                date: DateTime(2026, 12, 3),
              ),
              BadgeRecord(
                title: 'The Angelus (Regina Caeli in Eastertide)',
                date: DateTime(2026, 12, 4),
              ),
            ],
          ),
        },
      );

      // A time-of-day anchor carries no ordinal chip and no projection.
      expect(find.byKey(const Key('position_chip_angelus')), findsNothing);
      expect(find.textContaining('next:'), findsNothing);
      // The pack title renders three times with the shipped data: the card
      // header plus the two badge entries (each badge record's own title).
      expect(find.textContaining('The Angelus'), findsNWidgets(3));

      // The dated entries; the lifetime header counts them all.
      expect(find.textContaining('2026-12-03'), findsOneWidget);
      expect(find.textContaining('2026-12-04'), findsOneWidget);
      final Text lifetime = tester.widget<Text>(
        find.byKey(const Key('lifetime_count')),
      );
      expect(lifetime.data, '2');
      expect(find.textContaining('lifetime completions'), findsOneWidget);
    },
  );

  testWidgets(
    'intentions add and remove route through the repository and persist',
    (WidgetTester tester) async {
      final _ProgressHarness harness = await _pumpProgress(
        tester,
        today: DateTime(2026, 12, 5),
      );

      expect(find.textContaining('No intentions yet'), findsOneWidget);

      // Add an intention …
      await tester.enterText(
        find.byKey(const Key('intention_text')),
        'For a sick friend',
      );
      await _tapAndDrain(tester, find.byKey(const Key('add_intention')));
      expect(find.text('For a sick friend'), findsOneWidget);
      expect(find.textContaining('intention'), findsWidgets);

      // … and a soul.
      await tester.enterText(
        find.byKey(const Key('intention_text')),
        'Grandmother',
      );
      await _tapAndDrain(tester, find.byKey(const Key('add_soul')));
      expect(find.text('Grandmother'), findsOneWidget);

      // Persisted through the real store: the wrapper's own rows.
      final List<IntentionRow> stored = (await tester
          .runAsync<List<IntentionRow>>(
            () => harness.repository.database.getAllIntentions(),
          ))!;
      expect(
        stored.map((IntentionRow row) => row.text),
        containsAllInOrder(<String>['For a sick friend', 'Grandmother']),
      );
      final IntentionRow soulRow = stored.lastWhere(
        (IntentionRow row) => row.kind == 'soul',
      );
      final IntentionRow intentionRow = stored.firstWhere(
        (IntentionRow row) => row.kind == 'intention',
      );

      // Remove the soul: the row leaves the list and the store.
      await _tapAndDrain(
        tester,
        find.byKey(Key('remove_intention_${soulRow.id}')),
      );
      expect(find.text('Grandmother'), findsNothing);
      final List<IntentionRow> after = (await tester
          .runAsync<List<IntentionRow>>(
            () => harness.repository.database.getAllIntentions(),
          ))!;
      expect(after.map((IntentionRow row) => row.id), <String>[
        intentionRow.id,
      ]);
    },
  );

  testWidgets(
    'the indulgence sheet opens its static conditions and the one-per-day '
    'plenary cap note',
    (WidgetTester tester) async {
      await _pumpProgress(tester, today: DateTime(2026, 12, 5));

      await _tapAndDrain(tester, find.byKey(const Key('indulgence_info')));

      expect(find.byKey(const Key('indulgence_sheet')), findsOneWidget);
      expect(find.byKey(const Key('indulgence_conditions')), findsOneWidget);
      expect(find.byKey(const Key('indulgence_daily_cap')), findsOneWidget);
      expect(find.textContaining('once per day'), findsOneWidget);

      // Dismiss via the sheet's own close affordance.
      await tester.tap(find.byKey(const Key('close_indulgence_sheet')));
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
      expect(find.byKey(const Key('indulgence_sheet')), findsNothing);
    },
  );

  testWidgets(
    'with nothing enrolled the tab shows its honest empty state and the '
    'intentions editor',
    (WidgetTester tester) async {
      await _pumpProgress(tester, today: DateTime(2026, 12, 5));

      expect(find.textContaining('No programs to track yet'), findsOneWidget);
      expect(find.byKey(const Key('intention_text')), findsOneWidget);
      expect(find.byKey(const Key('add_intention')), findsOneWidget);
      // Nothing renders an ordinal or a projection for an empty day.
      expect(find.textContaining('next:'), findsNothing);
    },
  );
}
