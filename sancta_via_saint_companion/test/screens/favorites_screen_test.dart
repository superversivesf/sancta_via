// Favorites screen widget tests (Task 15).
//
// Harness (Tasks 11-14 pattern): an in-memory FFI SQLite database seeded
// with the shared Task 7 fixture shape is injected via
// `saintRepositoryProvider.overrideWithValue(SaintRepository.forDatabase(db))`,
// and the per-slug lookups the screen watches are resolved for real inside
// `tester.runAsync` before pumping, so the widget phase renders `AsyncData`
// synchronously and `pumpAndSettle` is safe (sqflite-FFI isolate replies
// never land inside the fake-async test zone).
//
// Settings come through the Task-9 provider: SharedPreferences.setMockInitialValues
// seeds the stored `saint_app_settings` JSON BEFORE the container (and with it
// the settings notifier) is created, and the fire-and-forget async load is
// drained inside the same `runAsync` warm-up.
//
// The FAILURE pin uses the REAL production path (Task 11/12/13/14
// reachability ruling): `SaintRepository.instance` against a genuinely
// unopenable database (read-only corrupt copy at a redirected databases
// path) — the first-load `ensureLoaded` failure is the production route to
// the keyed error card.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saint_companion/providers/saint_app_settings_provider.dart';
import 'package:saint_companion/providers/saint_providers.dart';
import 'package:saint_companion/screens/favorites/favorites_screen.dart';
import 'package:saint_data/saint_data.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../helpers/saint_fixture_db.dart';

const Key _favoritesSectionKey = Key('favorites_section');
const Key _recentsSectionKey = Key('recents_section');
const Key _favoritesEmptyKey = Key('favorites_empty_state');
const Key _recentsEmptyKey = Key('recents_empty_state');
const Key _favoritesErrorKey = Key('favorites_error_state');

/// The stored settings JSON the Task-9 provider loads
/// (`saint_app_settings`): [favorites] favorite slugs plus [recents]
/// recent slugs in most-recent-first order.
Map<String, Object> _prefsSeed({
  List<String> favorites = const <String>[],
  List<String> recents = const <String>[],
}) {
  return <String, Object>{
    SaintAppSettingsNotifier.storageKey: json.encode(<String, dynamic>{
      'favoriteSlugs': favorites,
      'recentSlugs': recents,
    }),
  };
}

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

  /// Pumps the favorites screen over an `UncontrolledProviderScope` whose
  /// container carries the seeded-database repository override. The mock
  /// SharedPreferences store is seeded BEFORE the container is created
  /// (Task-9 pattern), and the settings notifier's fire-and-forget load is
  /// drained inside the same `tester.runAsync` warm-up that prewarms the
  /// per-slug lookups under test (Task 11/12/14 harness — see file
  /// header). Slugs NOT prewarmed stay resolving during the widget phase.
  Future<ProviderContainer> pumpFavoritesScreen(
    WidgetTester tester, {
    required Map<String, Object> prefsSeed,
    List<String> preWarmSlugs = const <String>[],
  }) async {
    SharedPreferences.setMockInitialValues(prefsSeed);
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        saintRepositoryProvider.overrideWithValue(
          SaintRepository.forDatabase(db),
        ),
      ],
    );
    addTearDown(container.dispose);
    if (preWarmSlugs.isNotEmpty) {
      await tester.runAsync(() async {
        // Construct the settings notifier (starts its fire-and-forget
        // async load against the seeded mock store) and drain the load.
        container.read(saintAppSettingsProvider.notifier);
        for (var i = 0; i < 10; i++) {
          await Future<void>.delayed(Duration.zero);
        }
        // Prewarm the per-slug saint lookups (real repository paths) so
        // the widget phase renders AsyncData synchronously.
        await Future.wait(<Future<dynamic>>[
          for (final String slug in preWarmSlugs)
            container.read(saintBySlugProvider(slug).future),
        ]);
      });
    }
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: FavoritesScreen()),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('favorites render as keyed rows under favorites_section', (
    WidgetTester tester,
  ) async {
    await pumpFavoritesScreen(
      tester,
      prefsSeed: _prefsSeed(
        favorites: <String>['anthony-of-padua', 'joan-of-arc'],
      ),
      preWarmSlugs: const <String>['anthony-of-padua', 'joan-of-arc'],
    );

    expect(find.byKey(_favoritesSectionKey), findsOneWidget);
    expect(
      find.byKey(const Key('favorite_row_anthony-of-padua')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('favorite_row_joan-of-arc')), findsOneWidget);
    expect(find.text('St. Anthony of Padua'), findsOneWidget);
    expect(find.text('St. Joan of Arc'), findsOneWidget);
    // Each favorites row carries its remove (unfavorite) button.
    expect(
      find.byKey(const Key('favorite_remove_anthony-of-padua')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('favorite_remove_joan-of-arc')),
      findsOneWidget,
    );

    // Nothing was seeded into recents: that section shows its empty
    // state alongside the populated favorites section.
    expect(find.byKey(_recentsEmptyKey), findsOneWidget);
    expect(find.byKey(const Key('recent_row_anthony-of-padua')), findsNothing);
  });

  testWidgets(
    'a favorite slug the database no longer resolves is ignored gracefully',
    (WidgetTester tester) async {
      // Missing-slug ruling (favorites_screen.dart): a settings slug that
      // prewarms to AsyncData(null) — possible only across a data-asset
      // reset — is IGNORED instead of rendering a broken row or crashing.
      await pumpFavoritesScreen(
        tester,
        prefsSeed: _prefsSeed(
          favorites: <String>['anthony-of-padua', 'no-such-slug'],
        ),
        preWarmSlugs: const <String>['anthony-of-padua', 'no-such-slug'],
      );

      // The resolvable favorite renders; the unknown slug renders nothing.
      expect(
        find.byKey(const Key('favorite_row_anthony-of-padua')),
        findsOneWidget,
      );
      expect(find.text('St. Anthony of Padua'), findsOneWidget);
      expect(find.byKey(const Key('favorite_row_no-such-slug')), findsNothing);
      expect(
        find.byKey(const Key('favorite_remove_no-such-slug')),
        findsNothing,
      );
      // The ignored slug misclassified into NO section state either: not
      // empty, not error, not loading — the happy path filtered it out.
      expect(find.byKey(_favoritesEmptyKey), findsNothing);
      expect(find.byKey(_favoritesErrorKey), findsNothing);
      expect(find.byKey(const Key('favorites_loading_state')), findsNothing);
    },
  );

  testWidgets(
    'an all-unknown favorites list renders only the empty section wrapper',
    (WidgetTester tester) async {
      // Zero-row edge: EVERY favorite slug resolves null, so the section
      // wrapper renders with zero rows — deliberately NOT the empty state
      // (the user has favorites; they are merely unresolvable).
      await pumpFavoritesScreen(
        tester,
        prefsSeed: _prefsSeed(favorites: <String>['no-such-slug', 'also-gone']),
        preWarmSlugs: const <String>['no-such-slug', 'also-gone'],
      );

      expect(find.byKey(_favoritesSectionKey), findsOneWidget);
      expect(find.byKey(_favoritesEmptyKey), findsNothing);
      expect(find.byKey(_favoritesErrorKey), findsNothing);
      expect(find.byType(IconButton), findsNothing);
    },
  );

  testWidgets(
    'tapping a row\'s remove button unfavorites it immediately and leaves the rest',
    (WidgetTester tester) async {
      final ProviderContainer container = await pumpFavoritesScreen(
        tester,
        prefsSeed: _prefsSeed(
          favorites: <String>['anthony-of-padua', 'joan-of-arc'],
          recents: <String>['therese-of-lisieux'],
        ),
        preWarmSlugs: const <String>[
          'anthony-of-padua',
          'joan-of-arc',
          'therese-of-lisieux',
        ],
      );

      expect(
        find.byKey(const Key('favorite_row_anthony-of-padua')),
        findsOneWidget,
      );

      // ONE pump: the row disappears on the very next frame (the pinned
      // immediate update — no settle grace period).
      await tester.tap(
        find.byKey(const Key('favorite_remove_anthony-of-padua')),
      );
      await tester.pump();

      expect(
        find.byKey(const Key('favorite_row_anthony-of-padua')),
        findsNothing,
      );
      // The untouched favorite stays, and the recents section is unaffected.
      expect(find.byKey(const Key('favorite_row_joan-of-arc')), findsOneWidget);
      expect(
        find.byKey(const Key('recent_row_therese-of-lisieux')),
        findsOneWidget,
      );
      // The Task-9 settings provider state already reflects the removal.
      expect(container.read(saintAppSettingsProvider).favoriteSlugs, <String>[
        'joan-of-arc',
      ]);
    },
  );

  testWidgets('recents render most-recent-first under recents_section', (
    WidgetTester tester,
  ) async {
    // Stored order is most-recent-first (Task-9 addRecent semantics): the
    // list head (Joan) is the MOST recently viewed saint.
    await pumpFavoritesScreen(
      tester,
      prefsSeed: _prefsSeed(
        recents: <String>[
          'joan-of-arc',
          'anthony-of-padua',
          'therese-of-lisieux',
        ],
      ),
      preWarmSlugs: const <String>[
        'joan-of-arc',
        'anthony-of-padua',
        'therese-of-lisieux',
      ],
    );

    expect(find.byKey(_favoritesEmptyKey), findsOneWidget);
    expect(find.byKey(_recentsSectionKey), findsOneWidget);
    // Every seeded recent renders as a keyed row (names render too).
    expect(find.byKey(const Key('recent_row_joan-of-arc')), findsOneWidget);
    expect(
      find.byKey(const Key('recent_row_anthony-of-padua')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('recent_row_therese-of-lisieux')),
      findsOneWidget,
    );
    // Stored order = render order: the most recent sits on top.
    final Offset joanTop = tester.getTopLeft(
      find.byKey(const Key('recent_row_joan-of-arc')),
    );
    final Offset anthonyTop = tester.getTopLeft(
      find.byKey(const Key('recent_row_anthony-of-padua')),
    );
    final Offset thereseTop = tester.getTopLeft(
      find.byKey(const Key('recent_row_therese-of-lisieux')),
    );
    expect(joanTop.dy, lessThan(anthonyTop.dy));
    expect(anthonyTop.dy, lessThan(thereseTop.dy));

    // Recents rows are NOT removable (unfavorite lives in the favorites
    // section only): no remove buttons anywhere.
    expect(find.byType(IconButton), findsNothing);
  });

  testWidgets('both sections show their empty states with nothing seeded', (
    WidgetTester tester,
  ) async {
    await pumpFavoritesScreen(tester, prefsSeed: _prefsSeed());

    expect(find.byKey(_favoritesEmptyKey), findsOneWidget);
    expect(find.byKey(_recentsEmptyKey), findsOneWidget);
    // The sections still render (keyed wrappers) around their empty states.
    expect(find.byKey(_favoritesSectionKey), findsOneWidget);
    expect(find.byKey(_recentsSectionKey), findsOneWidget);
    // No rows anywhere.
    expect(
      find.byKey(const Key('favorite_row_anthony-of-padua')),
      findsNothing,
    );
    expect(find.byKey(const Key('recent_row_joan-of-arc')), findsNothing);
  });

  testWidgets(
    'favorites_error_state renders with a retry affordance when the real database load fails',
    (WidgetTester tester) async {
      // Reachability ruling carried over from home/categories/detail/search
      // (Tasks 11-14 fix rounds): no injected repository — the production
      // `SaintRepository.instance` load path runs against a genuinely
      // unopenable database, so the keyed error card is reached through the
      // app's real failure mode. Presence-only assertion (Task-15 ruling).
      final ProviderContainer container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.runAsync(() async {
        SharedPreferences.setMockInitialValues(
          _prefsSeed(favorites: <String>['anthony-of-padua']),
        );
        // Construct + drain the settings load so the section attempts the
        // slug lookup at all.
        container.read(saintAppSettingsProvider.notifier);
        for (var i = 0; i < 10; i++) {
          await Future<void>.delayed(Duration.zero);
        }

        final String previousDatabasesPath = await databaseFactory
            .getDatabasesPath();
        final Directory tempDir = await Directory.systemTemp.createTemp(
          'saints_favorites_fail_',
        );
        await databaseFactory.setDatabasesPath(tempDir.path);
        final String dbPath = '${tempDir.path}/saints.db';
        await File(
          dbPath,
        ).writeAsBytes(List<int>.generate(5000, (int i) => i % 251));
        await Process.run('chmod', <String>['444', dbPath]);

        // Warm the per-slug lookup through the production instance — the
        // first-load failure is expected, so the result is settled (error)
        // either way; the cached AsyncError then lands synchronously when
        // the screen watches this key.
        try {
          await container.read(saintBySlugProvider('anthony-of-padua').future);
        } on Object catch (_) {
          // Expected: the ensureLoaded failure surfaces here.
        }

        await databaseFactory.setDatabasesPath(previousDatabasesPath);
        await tempDir.delete(recursive: true);
      });

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: FavoritesScreen()),
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.byKey(_favoritesErrorKey), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(_favoritesErrorKey),
          matching: find.text('Retry'),
        ),
        findsOneWidget,
      );
      // No favorites rows render through the failure.
      expect(
        find.byKey(const Key('favorite_row_anthony-of-padua')),
        findsNothing,
      );
    },
  );
}
