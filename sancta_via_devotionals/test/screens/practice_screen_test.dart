// Practice tab widget tests (Plan 2, Task 14).
//
// The harness mirrors Task 13's `today_screen_test` wiring — the REAL app
// repository over an isolated in-memory FFI store, the real seeded catalog,
// the wrapper's `programRepositoryOverride` chain, and `currentDateProvider`
// frozen with the workspace's `Stream.value` pattern — pumped through the
// REAL app router (the Task-14 `StatefulShellRoute`) with
// `UncontrolledProviderScope`. Nothing stubs the chain.
//
// Pinned cases from the brief:
// 1. the Practice tab opens the catalog: the 8 seeded packs grouped by
//    family (commitment | novena | office | routine | chaplet — the engine
//    enum's declaration order), reached through the shell tab bar; empty
//    families (office, chaplet — no packs ship yet) render no header;
// 2. a catalog tile's tap opens the program detail route
//    (`/program/:packId`) over the shell.
//
// The contents of the detail screen are `program_detail_screen_test`'s
// pins; this file only proves the tab, the grouping, and the navigation.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sancta_via_devotional_engine_riverpod/sancta_via_devotional_engine_riverpod.dart'
    show programDetailProvider;
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
    show todayAssemblyProvider;
import 'package:sancta_via_devotionals/repositories/program_repository.dart'
    show SqliteProgramRepository;
import 'package:sancta_via_devotionals/screens/home/today_screen.dart';
import 'package:sancta_via_devotionals/screens/practice/practice_screen.dart';
import 'package:sancta_via_devotionals/screens/practice/program_detail_screen.dart';
import 'package:sancta_via_liturgical_calendar_riverpod/sancta_via_liturgical_calendar_riverpod.dart'
    show currentDateProvider;
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
/// The Today branch mounts the REAL settings provider (no override); the
/// defaults keep the load overlay a no-op.
void _setMockSettings() {
  final DevotionsAppSettings settings = DevotionsAppSettings(
    baseSettings: BaseSettingsModel.defaults(),
    enableAngelusAnchors: true,
    enableMercyHourAnchor: true,
    onboardingComplete: false,
  );
  SharedPreferences.setMockInitialValues(<String, Object>{
    DevotionsSettingsNotifier.storageKey: jsonEncode(settings.toJson()),
  });
}

/// The harness a test pumps against: the provider container (provider-level
/// asserts) and the app router (stack capture).
class _ScreenHarness {
  const _ScreenHarness(this.container, this.router);

  final ProviderContainer container;
  final GoRouter router;
}

/// Pumps the REAL app shell over the production provider chain, settled on
/// the Today tab.
///
/// The prewarm drains, in `runAsync` (outside the fake-async widget zone):
/// the settings load, the content migration's seed, the enrollments, the
/// Today assembly, and the detail future the tap-through pins navigate to —
/// so the first pump renders settled state exactly as the seeded Task-12/13
/// screen-harness discipline requires (no frame races a SQLite read even
/// after the shell switches branches or pushes the detail).
Future<_ScreenHarness> _pumpCatalog(
  WidgetTester tester, {
  required DateTime today,
}) async {
  _setMockSettings();
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

  // Order matters (Task 12's recipe): seed first, then the dependent
  // provider futures — one resolution each, cached before the widget phase.
  await tester.runAsync(() async {
    container.read(devotionsSettingsProvider.notifier);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await container.read(contentLoadedProvider.future);
    await container.read(todayAssemblyProvider.future);
    await container.read(programDetailProvider('novena_54_day').future);
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
  return _ScreenHarness(container, router);
}

double _topY(WidgetTester tester, Finder finder) =>
    tester.getTopLeft(finder.first).dy;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'the Practice tab opens the catalog: the 8 seeded packs grouped by family',
    (WidgetTester tester) async {
      await _pumpCatalog(tester, today: DateTime(2026, 12, 5));

      // The shell's Today tab is on screen first.
      expect(find.byType(TodayScreen), findsOneWidget);
      expect(find.byType(PracticeScreen), findsNothing);

      // Switching tabs through the NavigationBar mounts the catalog.
      await tester.tap(find.text('Practice'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(PracticeScreen), findsOneWidget);

      // Families WITH shipped packs render their group headers, in the
      // engine enum's declaration order (commitment → novena → routine):
      expect(find.text('Commitments'), findsOneWidget);
      expect(find.text('Novenas'), findsOneWidget);
      expect(find.text('Routines'), findsOneWidget);
      final double commitmentsY = _topY(tester, find.text('Commitments'));
      final double novenasY = _topY(tester, find.text('Novenas'));
      final double routinesY = _topY(tester, find.text('Routines'));
      expect(commitmentsY < novenasY, isTrue, reason: 'commitments first');
      expect(novenasY < routinesY, isTrue, reason: 'novenas precede routines');

      // Families with NO shipped packs (office, chaplet — Tasks 21/23)
      // render no header at all.
      expect(find.text('Office'), findsNothing);
      expect(find.text('Chaplets'), findsNothing);

      // All 8 seeded packs render — the catalog is the discovery surface,
      // so it lists every pack whether enrolled or not (Task 5/6 ruling).
      expect(find.text('Five First Saturdays of Our Lady'), findsOneWidget);
      expect(
        find.text('Nine First Fridays of the Sacred Heart'),
        findsOneWidget,
      );
      expect(
        find.text('Total Consecration to Jesus through Mary'),
        findsOneWidget,
      );
      expect(find.text('The Divine Mercy Novena'), findsOneWidget);
      expect(find.text('The 54-Day Rosary Novena'), findsOneWidget);
      expect(
        find.text('The Angelus (Regina Caeli in Eastertide)'),
        findsOneWidget,
      );
      expect(find.text('The Hour of Mercy'), findsOneWidget);
      expect(find.text('The Holy Rosary'), findsOneWidget);
    },
  );

  testWidgets(
    'a catalog tile tap pushes the program detail route over the shell',
    (WidgetTester tester) async {
      final _ScreenHarness harness = await _pumpCatalog(
        tester,
        today: DateTime(2026, 12, 5),
      );

      await tester.tap(find.text('Practice'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(PracticeScreen), findsOneWidget);

      await tester.tap(find.byKey(const Key('catalog_item_novena_54_day')));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      // PUSHED over the shell (the Today route stays beneath, the same
      // stack shape Task 13 pinned for the session player): the shell match
      // holds the base — now the practice branch — and the detail sits on
      // top of the delegate stack.
      final RouteMatchList configuration =
          harness.router.routerDelegate.currentConfiguration;
      expect(configuration.matches.length, 2);
      expect(configuration.matches.first.matchedLocation, '/practice');
      expect(
        configuration.matches.last.matchedLocation,
        '/program/novena_54_day',
      );
      expect(find.byType(ProgramDetailScreen), findsOneWidget);
    },
  );
}
