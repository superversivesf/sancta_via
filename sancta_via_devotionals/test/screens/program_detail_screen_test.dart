// Program detail screen widget tests (Plan 2, Task 14).
//
// The harness mirrors Task 13's `today_screen_test` wiring — the REAL app
// repository over an isolated in-memory FFI store, the real seeded catalog,
// the wrapper's `programRepositoryOverride` chain, and `currentDateProvider`
// frozen with the workspace's `Stream.value` pattern — pumped into the REAL
// `ProgramDetailScreen` through the real router deep links (`initialLocation`
// is the detail route itself; a detail is a top-level page, no tab bar).
// Nothing stubs the chain: the prewarm resolves every async load (the seed,
// the detail provider, the enrolled flag) inside `tester.runAsync` BEFORE
// the widget phase (the ruled screen-harness discipline).
//
// Pinned cases from the brief:
// 1. `five_first_saturdays` detail shows the description, a schedule
//    preview containing 2026-12-05 (the frozen date — the commitment's
//    first projected anchor via `Projection.remainingDates`), the strict
//    policy and the 8-day confession grace window, and the Enroll CTA,
//    which routes to the Task-15 stub;
// 2. `novena_54_day` detail shows the two phase rows (petition/thanksgiving)
//    and the two strict/permissive explainer rows from the pack's variants;
// 3. an enrolled pack shows the enrolled state instead of the CTA.
//
// Minimal extras:
// 4. a weekly-loop pack (the rosary) renders the weekday table rows;
// 5. a time-of-day pack (the Angelus) renders the daily anchor row and its
//    season variant explainer (regina_caeli).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sancta_via_devotional_engine_riverpod/sancta_via_devotional_engine_riverpod.dart'
    show programDetailProvider;
import 'package:sancta_via_devotionals/config/routes.dart';
import 'package:sancta_via_devotionals/database/devotionals_database.dart';
import 'package:sancta_via_devotionals/providers/content_providers.dart'
    show
        appProgramRepositoryProvider,
        contentLoadedProvider,
        programEnrolledProvider,
        programRepositoryOverride;
import 'package:sancta_via_devotionals/repositories/program_repository.dart'
    show SqliteProgramRepository;
import 'package:sancta_via_devotionals/screens/practice/enroll_placeholder_screen.dart';
import 'package:sancta_via_liturgical_calendar_riverpod/sancta_via_liturgical_calendar_riverpod.dart'
    show currentDateProvider;
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// A fresh FFI in-memory store open factory (isolated per call).
Future<Database> _openInMemory() =>
    openDatabase(inMemoryDatabasePath, singleInstance: false);

/// The harness a test pumps against: the provider container (provider-level
/// asserts) and the app router (stack capture).
class _DetailHarness {
  const _DetailHarness(this.container, this.router);

  final ProviderContainer container;
  final GoRouter router;
}

/// Pumps the REAL `ProgramDetailScreen` for [packId] through the app router
/// over the production provider chain, settled before the widget phase.
///
/// The prewarm drains, in `runAsync` (outside the fake-async widget zone):
/// the content migration's seed, then the enrollments, then the detail and
/// enrolled provider futures for exactly [packId] — so the first pump
/// renders settled state (no frame races a SQLite read).
Future<_DetailHarness> _pumpDetail(
  WidgetTester tester, {
  required String packId,
  required DateTime today,
  List<String> enroll = const <String>[],
}) async {
  final DevotionalsDatabase database = DevotionalsDatabase(open: _openInMemory);
  final SqliteProgramRepository repository = SqliteProgramRepository(
    database: database,
  );
  final GoRouter router = buildAppRouter(initialLocation: '/program/$packId');
  final ProviderContainer container = ProviderContainer(
    // main.dart's root-scope wiring, reproduced for the test scope: the
    // wrapper's `programDetailProvider` flows through the same SQLite
    // repository the enrolled flag reads.
    overrides: <Override>[
      appProgramRepositoryProvider.overrideWithValue(repository),
      programRepositoryOverride,
      currentDateProvider.overrideWith(
        (Ref ref) => Stream<DateTime>.value(today),
      ),
    ],
  );
  addTearDown(container.dispose);

  // Order matters (Task 12's recipe): the content pipeline seeds the fresh
  // store first, then the enrollments land, and only then do the detail
  // providers resolve — cached before the widget phase.
  await tester.runAsync(() async {
    await container.read(contentLoadedProvider.future);
    for (final String enrolledId in enroll) {
      await repository.enroll(enrolledId, <String, dynamic>{'via': 'test'});
    }
    await container.read(programDetailProvider(packId).future);
    await container.read(programEnrolledProvider(packId).future);
  });

  tester.view.physicalSize = const Size(600, 1800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pump(const Duration(milliseconds: 50));
  return _DetailHarness(container, router);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'the five_first_saturdays detail shows the description, the schedule '
    'preview from 2026-12-05, the policy and grace explainers, and the '
    'Enroll CTA',
    (WidgetTester tester) async {
      final _DetailHarness harness = await _pumpDetail(
        tester,
        packId: 'five_first_saturdays',
        today: DateTime(2026, 12, 5),
      );

      // The pack renders by its own title, under its family label.
      expect(find.text('Five First Saturdays of Our Lady'), findsOneWidget);
      expect(find.text('Commitment'), findsOneWidget);

      // The description derives from the schedule data: the count, the
      // first-Saturday anchor, the strict policy, and the confession
      // grace window.
      expect(find.textContaining('5 fulfillments'), findsOneWidget);
      expect(
        find.textContaining('first Saturday of each month'),
        findsOneWidget,
      );
      expect(find.textContaining('within 8 days'), findsOneWidget);

      // The schedule preview: the commitment's projected anchor dates from
      // the frozen day (`Projection.remainingDates` through the wrapper's
      // `programDetailProvider`) — 2026-12-05 is the brief's pinned date,
      // and every projected date renders as its ISO stamp.
      expect(find.byKey(const Key('schedule_preview')), findsOneWidget);
      expect(find.text('2026-12-05'), findsOneWidget);
      expect(find.textContaining('2027-01-02'), findsOneWidget);
      expect(find.textContaining('2027-04-03'), findsOneWidget);

      // The commitment's restart policy surfaces as an explainer row.
      expect(find.text('Strict'), findsOneWidget);

      // The Enroll CTA routes to the Task-15 stub route.
      expect(find.byKey(const Key('enroll_cta')), findsOneWidget);
      await tester.tap(find.byKey(const Key('enroll_cta')));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      final RouteMatchList configuration =
          harness.router.routerDelegate.currentConfiguration;
      expect(
        configuration.matches.last.matchedLocation,
        '/program/five_first_saturdays/enroll',
      );
      expect(find.byType(EnrollPlaceholderScreen), findsOneWidget);
    },
  );

  testWidgets('the 54-day novena detail shows the two phase rows and the two '
      'strict/permissive explainer rows from its variants', (
    WidgetTester tester,
  ) async {
    await _pumpDetail(
      tester,
      packId: 'novena_54_day',
      today: DateTime(2026, 12, 5),
    );

    expect(find.text('The 54-Day Rosary Novena'), findsOneWidget);
    expect(find.text('Novena'), findsOneWidget);

    // Phase explainer rows, grouped from the pack's day variants:
    // days 1-27 petition, days 28-54 thanksgiving.
    expect(find.text('Petition'), findsOneWidget);
    expect(find.text('Thanksgiving'), findsOneWidget);
    expect(find.textContaining('days 1'), findsOneWidget);
    expect(find.textContaining('days 28'), findsOneWidget);

    // The two missed-day policy explainer rows render verbatim from the
    // pack's own variant notes.
    expect(find.text('Strict'), findsOneWidget);
    expect(find.text('Permissive'), findsOneWidget);
    expect(find.textContaining('missed day voids the streak'), findsOneWidget);
    expect(
      find.textContaining('series resumes where it stands'),
      findsOneWidget,
    );

    // The 54-day is not enrolled in this fixture: the Enroll CTA shows.
    expect(find.byKey(const Key('enroll_cta')), findsOneWidget);
  });

  testWidgets(
    'an enrolled pack shows the enrolled state instead of the enroll CTA',
    (WidgetTester tester) async {
      await _pumpDetail(
        tester,
        packId: 'five_first_saturdays',
        today: DateTime(2026, 12, 5),
        enroll: <String>['five_first_saturdays'],
      );

      // The enrolled ruling is `enrollmentParamsFor(packId) != null`
      // (Task 5/6): the chip replaces the CTA (Task 15 completes the flow's
      // states; the detail-only state is the pinned minimum here).
      expect(find.text('Enrolled'), findsOneWidget);
      expect(find.byKey(const Key('enroll_cta')), findsNothing);
    },
  );

  testWidgets('a weekly-loop pack renders the weekday table rows', (
    WidgetTester tester,
  ) async {
    await _pumpDetail(tester, packId: 'rosary', today: DateTime(2026, 12, 5));

    expect(find.byKey(const Key('schedule_preview')), findsOneWidget);
    // Every weekday of the loop renders its table row; the rosary loops
    // all seven, so each carries the due marker.
    expect(find.text('Monday'), findsOneWidget);
    expect(find.text('Tuesday'), findsOneWidget);
    expect(find.text('Wednesday'), findsOneWidget);
    expect(find.text('Thursday'), findsOneWidget);
    expect(find.text('Friday'), findsOneWidget);
    expect(find.text('Saturday'), findsOneWidget);
    expect(find.text('Sunday'), findsOneWidget);
    expect(find.text('Due'), findsNWidgets(7));
    expect(find.text('—'), findsNothing);
  });

  testWidgets(
    'a time-of-day pack renders its daily anchor row and season variant '
    'explainer',
    (WidgetTester tester) async {
      await _pumpDetail(
        tester,
        packId: 'angelus',
        today: DateTime(2026, 12, 5),
      );

      expect(find.byKey(const Key('schedule_preview')), findsOneWidget);
      // The engine's zero-padded HH:mm label for the Angelus anchor.
      expect(find.textContaining('Every day at 06:00'), findsOneWidget);
      // The pack's season variant surfaces by its variantId, with its
      // season match condition spelled out beside it.
      expect(find.text('regina_caeli'), findsOneWidget);
      expect(
        find.textContaining('Easter, Eastertide, Pentecost'),
        findsOneWidget,
      );
    },
  );
}
