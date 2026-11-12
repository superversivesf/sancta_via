// Categories screens widget tests (Task 12).
//
// Mirrors the home screen test harness (Task 11): an in-memory FFI SQLite
// database seeded with the Task 7 fixture shape is injected via
// `saintRepositoryProvider.overrideWithValue(SaintRepository.forDatabase(db))`,
// and the repository-backed providers are resolved for real inside
// `tester.runAsync` before pumping, so the widget phase renders `AsyncData`
// synchronously and `pumpAndSettle` is safe (sqflite-FFI isolate replies
// never land inside the fake-async test zone). The load-failure test uses
// the REAL production first-load path through `SaintRepository.forAssetPath(
// 'assets/does-not-exist.db')` (final-review wave rehome: the app now
// bundles a working `assets/saints.db`, so asset absence can no longer
// force the failure), same technique as home_screen_test.dart.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:saint_companion/providers/saint_providers.dart';
import 'package:saint_companion/screens/categories/categories_screen.dart';
import 'package:saint_companion/screens/categories/category_detail_screen.dart';
import 'package:saint_companion/widgets/category_card.dart';
import 'package:saint_data/saint_data.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../helpers/saint_fixture_db.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Database db;

  setUp(() async {
    db = await createSeededDatabase();
  });

  tearDown(() async {
    await db.close();
  });

  /// Pumps the categories browse screen in a router-less harness:
  /// `MaterialApp(home: CategoriesScreen())` over an
  /// `UncontrolledProviderScope` whose container carries the repository
  /// override. The counts provider is resolved for real inside
  /// `tester.runAsync` (see the file header for why) unless [preWarm]
  /// is false. [extraOverrides] layers additional container overrides.
  Future<void> pumpCategoriesScreen(
    WidgetTester tester, {
    List<Override> extraOverrides = const <Override>[],
    bool preWarm = true,
  }) async {
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        saintRepositoryProvider.overrideWithValue(
          SaintRepository.forDatabase(db),
        ),
        ...extraOverrides,
      ],
    );
    addTearDown(container.dispose);
    if (preWarm) {
      await tester.runAsync(() async {
        await container.read(categoryCountsProvider.future);
      });
    }
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: CategoriesScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Pumps the category detail screen for [categoryId]: providers are
  /// resolved for real via `tester.runAsync` (when the id parses), then
  /// the screen is pumped. With [router], the screen is reached through
  /// that router (initial location must be the category detail route) so
  /// chip navigation can be observed for real.
  Future<void> pumpCategoryDetail(
    WidgetTester tester, {
    required String categoryId,
    List<Override> extraOverrides = const <Override>[],
    GoRouter? router,
  }) async {
    final SaintCategory? category = SaintCategory.tryParse(categoryId);
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        saintRepositoryProvider.overrideWithValue(
          SaintRepository.forDatabase(db),
        ),
        ...extraOverrides,
      ],
    );
    addTearDown(container.dispose);
    await tester.runAsync(() async {
      if (category != null) {
        await Future.wait(<Future<dynamic>>[
          container.read(saintsByCategoryProvider(category).future),
          container.read(needsForCategoryProvider(category).future),
        ]);
      }
    });
    final Widget app = router != null
        ? MaterialApp.router(routerConfig: router)
        : MaterialApp(home: CategoryDetailScreen(categoryId: categoryId));
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: app),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders 10 CategoryCards with the seeded counts', (
    WidgetTester tester,
  ) async {
    await pumpCategoriesScreen(tester);

    // All 10 categories render; the four categories without fixture saints
    // in this seeding show a zero count.
    expect(find.byType(CategoryCard), findsNWidgets(10));
    expect(find.text('2 saints'), findsNWidgets(2)); // spiritual + military
    expect(find.text('1 saint'), findsNWidgets(2)); // everyday + jobs
    expect(find.text('0 saints'), findsNWidgets(6));
    // Cards carry per-category keys (CategoryCard's overridable key).
    expect(find.byKey(const Key('category_card_military')), findsOneWidget);
    expect(find.byKey(const Key('category_card_everyday')), findsOneWidget);
  });

  testWidgets(
    'CategoryDetailScreen military shows need chip with count and saints list',
    (WidgetTester tester) async {
      await pumpCategoryDetail(tester, categoryId: 'military');

      // The saints section lists both military saints (repository order: by
      // name, i.e. George before Joan), each under the Task-11 slug key rule.
      expect(find.byKey(const Key('category_saints_section')), findsOneWidget);
      expect(find.byKey(const Key('saint_card_george')), findsOneWidget);
      expect(find.byKey(const Key('saint_card_joan-of-arc')), findsOneWidget);
      expect(find.text('St. George'), findsOneWidget);
      expect(find.text('St. Joan of Arc'), findsOneWidget);

      // The needs section renders the seeded `soldiers` need as an anchor
      // chip with its saint count (need -> key fragment is lowercased with
      // non-alphanumerics mapped to '_' — the Task-11 PatronageChip ruling).
      expect(find.byKey(const Key('category_needs_section')), findsOneWidget);
      expect(find.byKey(const Key('need_chip_soldiers')), findsOneWidget);
      expect(find.text('soldiers (2)'), findsOneWidget);
    },
  );

  testWidgets('invalid category id renders the category_not_found fallback', (
    WidgetTester tester,
  ) async {
    await pumpCategoryDetail(tester, categoryId: 'not-a-category');

    expect(find.byKey(const Key('category_not_found')), findsOneWidget);
    // Task-8 route-error style: a back-home affordance must be rendered.
    expect(find.widgetWithText(FilledButton, 'Back to Home'), findsOneWidget);
    // The valid-category sections never render.
    expect(find.byKey(const Key('category_saints_section')), findsNothing);
    expect(find.byKey(const Key('need_chip_soldiers')), findsNothing);
  });

  testWidgets('tapping a need chip pushes /search seeded with the need text', (
    WidgetTester tester,
  ) async {
    // Task-8 smoke precedent: navigate through a real router and observe
    // the destination route (content + matched location + forwarded extra,
    // the latter two captured by the route builder itself).
    Object? capturedExtra;
    String capturedSearchPath = '';
    final GoRouter router = GoRouter(
      initialLocation: '/categories/military',
      routes: <RouteBase>[
        GoRoute(
          path: '/categories/:category',
          builder: (BuildContext context, GoRouterState state) =>
              CategoryDetailScreen(
                categoryId: state.pathParameters['category']!,
              ),
        ),
        GoRoute(
          path: '/search',
          builder: (BuildContext context, GoRouterState state) {
            capturedExtra = state.extra;
            capturedSearchPath = state.uri.path;
            return const Scaffold(body: Text('SEARCH_PROBE'));
          },
        ),
      ],
    );

    await pumpCategoryDetail(tester, categoryId: 'military', router: router);
    expect(
      router.routeInformationProvider.value.uri.path,
      '/categories/military',
    );

    await tester.tap(find.byKey(const Key('need_chip_soldiers')));
    await tester.pumpAndSettle();

    expect(find.text('SEARCH_PROBE'), findsOneWidget);
    expect(capturedExtra, 'soldiers');
    expect(capturedSearchPath, '/search');
  });

  testWidgets(
    'renders categories_error_state with a retry affordance when the real database load fails',
    (WidgetTester tester) async {
      // Final-review fix wave rehome (was: SaintRepository.instance against
      // a read-only corrupt copy — a technique that relied on the app NOT
      // bundling `assets/saints.db`): the app now ships a working database,
      // so the reachability pin uses the saint_data error seam and NO
      // injected repository stub — the first-load failure is genuine,
      // produced by the loader's loud missing-asset path through
      // SaintRepository.forAssetPath. Pinned assertions unchanged.
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          saintRepositoryProvider.overrideWithValue(
            SaintRepository.forAssetPath('assets/does-not-exist.db'),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.runAsync(() async {
        final String previousDatabasesPath = await databaseFactory
            .getDatabasesPath();
        final Directory tempDir = await Directory.systemTemp.createTemp(
          'saints_categories_fail_',
        );
        await databaseFactory.setDatabasesPath(tempDir.path);
        try {
          // Warm the repository-backed provider through the genuine
          // first-load failure — expected, so the result is settled (value
          // or error) either way.
          await _settleFuture(container.read(categoryCountsProvider.future));
        } finally {
          await databaseFactory.setDatabasesPath(previousDatabasesPath);
        }
        await tempDir.delete(recursive: true);
      });

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: CategoriesScreen()),
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('categories_error_state')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('categories_error_state')),
          matching: find.text('Retry'),
        ),
        findsOneWidget,
      );
      // No grid renders through the failure.
      expect(find.byType(CategoryCard), findsNothing);
    },
  );
}

/// Awaits [future], returning its result or — when it completes with an
/// error — the error itself, so the real-path load-failure warm-up drives
/// the provider regardless of whether the load fails (error expected) or
/// silently succeeds (pre-fix behavior). Mirrors home_screen_test.dart.
Future<Object?> _settleFuture<T>(Future<T> future) async {
  try {
    return await future;
  } on Object catch (error) {
    return error;
  }
}
