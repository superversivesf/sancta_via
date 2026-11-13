// Today screen widget tests (Plan 2, Task 13).
//
// The harness mirrors Task 12's `today_providers_test` wiring — the REAL app
// repository over an isolated in-memory FFI store, the real seeded catalog,
// the wrapper's `programRepositoryOverride` chain, and `currentDateProvider`
// frozen with the workspace's `Stream.value` pattern — pumped into the REAL
// `TodayScreen` through `UncontrolledProviderScope`. Nothing stubs the chain:
// the screen renders the same assembly production builds, and the real async
// load resolves inside `tester.runAsync` BEFORE the widget phase (the ruled
// screen-harness prewarm that keeps no frame racing a SQLite read).
//
// Pinned cases from the brief:
// 1. frozen 2026-12-05 renders the Commitments tile with its ordinal badge —
//    plus the liturgical header (celebration name + rank from the calendar
//    provider), the mercy group at its 3pm position (partitioned out of the
//    anchors section by the `mercy_hour` label seam), the §7 section order,
//    the anchor-time chips, and the feast tiles (name only, no navigation);
// 2. a Today tile's tap navigates to the session route (location capture);
// 3. an empty day shows the onboarding CTA, which routes to the stub route.
//
// Minimal extras:
// 4. `enableMercyHourAnchor` OFF hides the corresponding anchor (the
//    presentation-layer visibility Task 13 owns — the provider does not
//    filter);
// 5. `enableAngelusAnchors` OFF hides the Angelus anchor while due
//    commitments stay.
//
// Fix round 1:
// 6. the player is a PUSHED route (spec §7): Today remains beneath the
//    session route after a tile tap, and the delegate stack holds both;
// 7. enrolled-but-nothing-due still shows the CTA — with nothing-due-today
//    copy ('Nothing scheduled right now' / 'Take up a devotion'), never the
//    enrollment-claiming copy, and the CTA still routes to `/onboarding`.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sancta_via_devotional_engine/sancta_via_devotional_engine.dart'
    show ProgressState;
import 'package:sancta_via_devotionals/config/routes.dart';
import 'package:sancta_via_devotionals/database/devotionals_database.dart';
import 'package:sancta_via_devotionals/models/app_settings.dart'
    show DevotionsAppSettings;
import 'package:sancta_via_devotionals/providers/app_settings_provider.dart'
    show DevotionsSettingsNotifier, devotionsSettingsProvider;
import 'package:sancta_via_devotionals/providers/content_providers.dart'
    show
        appProgramRepositoryProvider,
        contentLoadedProvider,
        programRepositoryOverride;
import 'package:sancta_via_devotionals/providers/today_providers.dart'
    show TodayAssembly, todayAssemblyProvider;
import 'package:sancta_via_devotionals/repositories/program_repository.dart'
    show SqliteProgramRepository;
import 'package:sancta_via_devotionals/screens/home/today_screen.dart';
import 'package:sancta_via_devotionals/screens/onboarding/onboarding_screen.dart'
    show OnboardingScreen;
import 'package:sancta_via_devotionals/screens/session/session_player_screen.dart'
    show SessionPlayerScreen;
import 'package:sancta_via_liturgical_calendar_riverpod/sancta_via_liturgical_calendar_riverpod.dart'
    show LiturgicalDayData, currentLiturgicalDayProvider, currentDateProvider;
import 'package:sancta_via_shared_ui/sancta_via_shared_ui.dart'
    show BaseSettingsModel;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// A fresh FFI in-memory store open factory (isolated per call).
Future<Database> _openInMemory() =>
    openDatabase(inMemoryDatabasePath, singleInstance: false);

/// What the [DevotionsSettingsNotifier]'s SharedPreferences store carries.
///
/// The REAL settings provider loads from here (no override in these tests),
/// with `baseSettings` left at its defaults so the load overlay is a no-op
/// and the persisted app fields pass through untouched.
void _setMockSettings({
  bool angelusAnchors = true,
  bool mercyAnchor = true,
  bool onboardingComplete = false,
}) {
  final DevotionsAppSettings settings = DevotionsAppSettings(
    baseSettings: BaseSettingsModel.defaults(),
    enableAngelusAnchors: angelusAnchors,
    enableMercyHourAnchor: mercyAnchor,
    onboardingComplete: onboardingComplete,
  );
  SharedPreferences.setMockInitialValues(<String, Object>{
    DevotionsSettingsNotifier.storageKey: jsonEncode(settings.toJson()),
  });
}

/// The harness a test pumps against: the provider container (provider-level
/// asserts) and the app router (location capture).
class _ScreenHarness {
  const _ScreenHarness(this.container, this.router);

  final ProviderContainer container;
  final GoRouter router;

  /// The route the router sits on, as a location string.
  String get location => router.routeInformationProvider.value.uri.toString();
}

/// Pumps the REAL `TodayScreen` through the app router over the production
/// provider chain.
///
/// The prewarm drains, in `runAsync` (outside the fake-async widget zone):
/// the settings load (the real persistence store), the content migration's
/// seed, and the assembly future — so the first pump renders settled data
/// state, exactly as the seeded Task-11 screen harness discipline requires.
Future<_ScreenHarness> _pumpToday(
  WidgetTester tester, {
  required DateTime today,
  List<String> enroll = const <String>[],
  Map<String, int> progress = const <String, int>{},
  bool enableAngelusAnchors = true,
  bool enableMercyHourAnchor = true,
  bool onboardingComplete = false,
}) async {
  _setMockSettings(
    angelusAnchors: enableAngelusAnchors,
    mercyAnchor: enableMercyHourAnchor,
    onboardingComplete: onboardingComplete,
  );
  final DevotionalsDatabase database = DevotionalsDatabase(open: _openInMemory);
  final SqliteProgramRepository repository = SqliteProgramRepository(
    database: database,
  );
  final GoRouter router = buildAppRouter();
  final ProviderContainer container = ProviderContainer(
    // main.dart's root-scope wiring, reproduced for the test scope: the
    // wrapper's catalog providers flow through the same SQLite repository
    // the assembly reads.
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
  // store first, then the enrollments land, and only then does the assembly
  // resolve ONE time — so its cached future already describes the enrolled
  // day the screen must render.
  await tester.runAsync(() async {
    // Trigger the settings load (the constructor's async read) and let the
    // mock-store microtask layer drain.
    container.read(devotionsSettingsProvider.notifier);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await container.read(contentLoadedProvider.future);
    for (final String packId in enroll) {
      await repository.enroll(packId, <String, dynamic>{'via': 'test'});
    }
    for (final MapEntry<String, int> entry in progress.entries) {
      await repository.saveProgress(
        ProgressState(packId: entry.key, fulfilledOrdinals: entry.value),
      );
    }
    await container.read(todayAssemblyProvider.future);
  });

  tester.view.physicalSize = const Size(600, 3000);
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
  return _ScreenHarness(container, router);
}

double _topY(WidgetTester tester, Finder finder) =>
    tester.getTopLeft(finder.first).dy;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'frozen 2026-12-05 renders the liturgical header, the §7 section order, '
    'the mercy 3pm group, and the Commitments ordinal tile',
    (WidgetTester tester) async {
      final _ScreenHarness harness = await _pumpToday(
        tester,
        today: DateTime(2026, 12, 5),
        enroll: <String>['angelus', 'mercy_hour', 'five_first_saturdays'],
      );

      // The liturgical header: the calendar's celebration for the frozen day
      // (read through the same provider chain, never hardcoded), with its
      // rank label and the ribbon container present.
      final LiturgicalDayData? day = harness.container.read(
        currentLiturgicalDayProvider,
      );
      expect(day, isNotNull);
      expect(find.byKey(const Key('liturgical_header')), findsOneWidget);
      expect(find.text(day!.celebration.name), findsOneWidget);
      expect(find.text(day.celebration.rankEnum.displayName), findsOneWidget);

      // §7 order — Morning · Angelus times · 3pm · Evening · Commitments ·
      // Upcoming feasts. Task 24's schedule ships the Angelus' noon and
      // evening anchors, so all six sections render: the Angelus Times card
      // holds the noon tile, the Evening card the 18:00 tile (both partition
      // seams: the 3pm group stays partitioned out of the anchors section by
      // the `mercy_hour` label).
      expect(find.text('Morning'), findsOneWidget);
      expect(find.text('Angelus Times'), findsOneWidget);
      expect(find.text('3pm'), findsOneWidget);
      expect(find.text('Evening'), findsOneWidget);
      expect(find.text('Commitments'), findsOneWidget);
      expect(find.text('Upcoming Feasts'), findsOneWidget);
      final double morningY = _topY(tester, find.text('Morning'));
      final double angelusTimesY = _topY(tester, find.text('Angelus Times'));
      final double mercyY = _topY(tester, find.text('3pm'));
      final double eveningY = _topY(tester, find.text('Evening'));
      final double commitmentsY = _topY(tester, find.text('Commitments'));
      final double feastsY = _topY(tester, find.text('Upcoming Feasts'));
      expect(morningY < angelusTimesY, isTrue, reason: 'Morning precedes noon');
      expect(angelusTimesY < mercyY, isTrue, reason: 'noon precedes the 3pm');
      expect(mercyY < eveningY, isTrue, reason: '3pm precedes Evening');
      expect(
        eveningY < commitmentsY,
        isTrue,
        reason: 'Evening precedes Commitments',
      );
      expect(commitmentsY < feastsY, isTrue, reason: 'feasts come last');

      // The tiles: the Angelus renders its THREE anchor tiles (6/12/18 —
      // one walk, one link each, the Task-12 limitation the pack note
      // carries), the Hour of Mercy under the 3pm group, and the First
      // Saturday with its ordinal badge (Task 12's frozen-day resolution:
      // streak empty + 1).
      expect(
        find.text('The Angelus (Regina Caeli in Eastertide)'),
        findsNWidgets(3),
      );
      expect(find.text('6:00 AM'), findsOneWidget);
      expect(find.text('12:00 PM'), findsOneWidget);
      expect(find.text('6:00 PM'), findsOneWidget);
      final double angelusY = _topY(
        tester,
        find.text('The Angelus (Regina Caeli in Eastertide)'),
      );
      expect(
        angelusY > morningY && angelusY < angelusTimesY,
        isTrue,
        reason: 'the first Angelus tile sits inside the Morning section',
      );
      expect(find.text('The Hour of Mercy'), findsOneWidget);
      expect(find.text('3:00 PM'), findsOneWidget);
      final double mercyTileY = _topY(tester, find.text('The Hour of Mercy'));
      expect(
        mercyTileY > mercyY && mercyTileY < commitmentsY,
        isTrue,
        reason: 'the mercy tile sits inside the 3pm section',
      );
      expect(find.text('Five First Saturdays of Our Lady'), findsOneWidget);
      expect(find.text('ordinal 1'), findsOneWidget);

      // Feast tiles render their names — and only the name: a feast has no
      // deep link, so tapping it never navigates (location capture).
      expect(find.text('Saint Ambrose, Bishop and Doctor'), findsOneWidget);
      expect(find.text('Immaculate Conception'), findsOneWidget);
      await tester.tap(find.text('Saint Ambrose, Bishop and Doctor'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(harness.location, '/', reason: 'a feast tile never navigates');
    },
  );

  testWidgets('a Today tile tap pushes the session deep-link route over '
      'Today', (WidgetTester tester) async {
    final _ScreenHarness harness = await _pumpToday(
      tester,
      today: DateTime(2026, 12, 5),
      enroll: <String>['five_first_saturdays'],
    );

    expect(find.text('Five First Saturdays of Our Lady'), findsOneWidget);
    await tester.tap(find.text('Five First Saturdays of Our Lady'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    // Pushed (Spec §7; fix round 1): the delegate stack holds Today AND the
    // player — `go` would swap Today out (and system back would then exit
    // the app). Note the raw reported location is not the push evidence:
    // go_router 15 keeps the provider's value on the base for imperative
    // pushes, so the stack itself is asserted.
    final RouteMatchList configuration =
        harness.router.routerDelegate.currentConfiguration;
    expect(configuration.matches.length, 2);
    expect(configuration.matches.first.matchedLocation, '/');
    expect(
      configuration.matches.last.matchedLocation,
      '/session/five_first_saturdays',
    );
    expect(find.byType(SessionPlayerScreen), findsOneWidget);
    expect(
      find.byType(TodayScreen),
      findsOneWidget,
      reason: 'the player is a pushed route over Today (spec §7)',
    );
  });

  testWidgets(
    'an empty day shows the onboarding CTA, which routes to the onboarding '
    'stub route',
    (WidgetTester tester) async {
      final _ScreenHarness harness = await _pumpToday(
        tester,
        today: DateTime(2026, 12, 5),
      );

      // A truly-empty install: the fresh-start copy and CTA.
      expect(find.text('Nothing scheduled right now'), findsOneWidget);
      expect(find.byKey(const Key('onboarding_cta')), findsOneWidget);
      expect(find.text('Get started'), findsOneWidget);
      await tester.tap(find.byKey(const Key('onboarding_cta')));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      expect(harness.location, '/onboarding');
      expect(find.byType(OnboardingScreen), findsOneWidget);
    },
  );

  testWidgets(
    'an enrolled program with nothing due shows the CTA without claiming '
    'enrollment is absent',
    (WidgetTester tester) async {
      // 2026-12-06 is the day after the first Saturday of December: the
      // Five First Saturdays ARE enrolled but resolve due nowhere — every
      // devotion section is empty all the same ("empty" ≠ "not enrolled",
      // fix round 1).
      final _ScreenHarness harness = await _pumpToday(
        tester,
        today: DateTime(2026, 12, 6),
        enroll: <String>['five_first_saturdays'],
        onboardingComplete: true,
      );

      final TodayAssembly assembly = harness.container
          .read(todayAssemblyProvider)
          .value!;
      expect(assembly.isEmpty, isTrue);
      expect(
        assembly.hasEnrolledPrograms,
        isTrue,
        reason:
            'the enrolled set is non-empty even though nothing resolves '
            'due today',
      );

      // Nothing-due-today copy — and the CTA takes a devotion, it does not
      // claim the program list is empty.
      expect(find.text('Nothing scheduled right now'), findsOneWidget);
      expect(find.textContaining('nothing due right now'), findsOneWidget);
      expect(find.text('Take up a devotion'), findsOneWidget);
      expect(
        find.textContaining('Nothing is enrolled'),
        findsNothing,
        reason:
            'the enrollment-claiming copy of round 1 must never render '
            'while a program is enrolled',
      );

      // The CTA still routes to onboarding (it also serves "take up a
      // devotion").
      await tester.tap(find.byKey(const Key('onboarding_cta')));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
      expect(harness.location, '/onboarding');
    },
  );

  testWidgets('enableMercyHourAnchor OFF hides the 3pm group from Today', (
    WidgetTester tester,
  ) async {
    await _pumpToday(
      tester,
      today: DateTime(2026, 12, 5),
      enroll: <String>['mercy_hour'],
      enableMercyHourAnchor: false,
    );

    expect(find.text('3pm'), findsNothing);
    expect(find.text('The Hour of Mercy'), findsNothing);
    // The rest of the day still renders: header and feast window.
    expect(find.byKey(const Key('liturgical_header')), findsOneWidget);
    expect(find.text('Upcoming Feasts'), findsOneWidget);
  });

  testWidgets(
    'enableAngelusAnchors OFF hides the Angelus anchor, keeping commitments',
    (WidgetTester tester) async {
      await _pumpToday(
        tester,
        today: DateTime(2026, 12, 5),
        enroll: <String>['angelus', 'five_first_saturdays'],
        enableAngelusAnchors: false,
      );

      expect(find.text('Morning'), findsNothing);
      expect(find.text('Angelus Times'), findsNothing);
      expect(find.text('Evening'), findsNothing);
      expect(find.text('12:00 PM'), findsNothing);
      expect(find.text('6:00 PM'), findsNothing);
      expect(
        find.text('The Angelus (Regina Caeli in Eastertide)'),
        findsNothing,
      );
      // The due commitment is not an anchor; the toggle never touches it.
      expect(find.text('Five First Saturdays of Our Lady'), findsOneWidget);
      expect(find.text('ordinal 1'), findsOneWidget);
    },
  );
}
