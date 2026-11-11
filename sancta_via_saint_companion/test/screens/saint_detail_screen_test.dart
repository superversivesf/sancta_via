// Saint detail screen widget tests (Task 13).
//
// Reuses the shared screen-test fixture (test/helpers/saint_fixture_db.dart,
// extracted from the Task 12 categories seeder) with ONE detail-only saint
// appended per database (bernard-of-clairvaux: attribution, canonized line,
// prayer, and a deliberately-missing thumb asset mirroring the Task 6
// carry-forward saints). The repository-backed provider is resolved for
// real inside `tester.runAsync` before pumping (Task 11/12 harness) so the
// widget phase renders `AsyncData` synchronously and `pumpAndSettle` is
// safe. The load-failure test uses the REAL production path
// (`SaintRepository.instance`) against a read-only corrupt database
// fixture, same technique as categories_screens_test.dart.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saint_companion/providers/saint_app_settings_provider.dart';
import 'package:saint_companion/providers/saint_providers.dart';
import 'package:saint_companion/screens/saint_detail/saint_detail_screen.dart';
import 'package:saint_data/saint_data.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../helpers/saint_fixture_db.dart';

const Key _placeholderKey = Key('saint_image_placeholder');

/// The shared screen fixture plus one detail-only saint exercising every
/// optional detail-page column: canonized line, prayer, attribution line,
/// and a deliberately-missing thumb whose asset load falls back to the
/// SaintImage placeholder through its errorBuilder (the Task 11
/// missing-asset ruling).
Future<Database> _createDetailSeededDatabase() async {
  final Database db = await createSeededDatabase();
  await seedSaint(
    db,
    slug: 'bernard-of-clairvaux',
    name: 'St. Bernard of Clairvaux',
    feastDay: '03-05',
    bio: 'A Cistercian abbot and Doctor of the Church.',
    canonized: 'Pre-Congregation',
    prayerText: 'O loving Bernard, intercede for us.',
    // A thumb path deliberately missing from the bundle (the real
    // `bernard-of-clairvaux.jpg` exists — 2,174-saint dataset) so the
    // screen exercises SaintImage's errorBuilder → placeholder fallback at
    // the screen level (Task 11 missing-asset ruling).
    thumbAsset: 'assets/thumbs/definitely-missing-detail-thumb.jpg',
    imageAttribution: 'Photo by Test Author (CC BY-SA 4.0)',
  );
  return db;
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Database db;

  setUp(() async {
    // The detail screen records the visit on open through
    // saintAppSettingsProvider, whose notifier persists to SharedPreferences
    // — mock its store so the serialized writes resolve in-test.
    SharedPreferences.setMockInitialValues(<String, Object>{});
    db = await _createDetailSeededDatabase();
  });

  tearDown(() async {
    await db.close();
  });

  /// Pumps the saint detail screen for [slug] in a router-less harness:
  /// `MaterialApp(home: SaintDetailScreen(slug))` over an
  /// `UncontrolledProviderScope` whose container carries the repository
  /// override. The slug provider is resolved for real inside
  /// `tester.runAsync` (unless [preWarm] is false) — see the file header.
  /// Returns the container so provider-state asserts can read it after taps.
  Future<ProviderContainer> pumpSaintDetail(
    WidgetTester tester, {
    required String slug,
    bool preWarm = true,
    List<Override> extraOverrides = const <Override>[],
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
        await container.read(saintBySlugProvider(slug).future);
      });
    }
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(home: SaintDetailScreen(slug: slug)),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets(
    'renders name, bio, feast day, all patronage chips, and the placeholder for a thumbless saint',
    (WidgetTester tester) async {
      await pumpSaintDetail(tester, slug: 'anthony-of-padua');

      // Name + bio render (the seed fixture's bio text, verbatim).
      expect(find.text('St. Anthony of Padua'), findsOneWidget);
      expect(
        find.text('A Franciscan preacher who helps find lost things.'),
        findsOneWidget,
      );
      // Feast day '06-13' is formatted human ('June 13').
      expect(find.text('June 13'), findsOneWidget);

      // ALL patronages render as chips keyed
      // `patronage_chip_<needKeyFragment(need)>` (Task 11 chip-key contract,
      // single-sourced in patronage_chip.dart).
      expect(
        find.byKey(const Key('patronage_chip_lost_items')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('patronage_chip_housework')), findsOneWidget);

      // Thumbless saint: the gray placeholder renders with no image widget at
      // all — saint imagery is never fetched over the network.
      expect(find.byKey(_placeholderKey), findsOneWidget);
      expect(find.byType(Image), findsNothing);
      expect(
        find.byWidgetPredicate(
          (Widget widget) => widget is Image && widget.image is NetworkImage,
        ),
        findsNothing,
      );

      // Attribution renders ONLY when imageAttribution != null — the seeded
      // rows carry none, so the keyed line never appears.
      expect(find.byKey(const Key('image_attribution')), findsNothing);
    },
  );

  testWidgets(
    'renders attribution, canonized line, prayer card, and March 5 feast formatting for the populated saint',
    (WidgetTester tester) async {
      await pumpSaintDetail(tester, slug: 'bernard-of-clairvaux');

      // The attribution line renders (pinned presence + exact text).
      expect(find.byKey(const Key('image_attribution')), findsOneWidget);
      expect(find.text('Photo by Test Author (CC BY-SA 4.0)'), findsOneWidget);

      // Feast day '03-05' formats as the brief-pinned human label 'March 5'.
      expect(find.text('March 5'), findsOneWidget);
      // Canonized line renders when present.
      expect(find.text('Canonized: Pre-Congregation'), findsOneWidget);

      // The prayer card renders with the seeded prayer text.
      expect(find.byKey(const Key('prayer_card')), findsOneWidget);
      expect(find.text('O loving Bernard, intercede for us.'), findsOneWidget);

      // Declared thumb whose file is missing from the bundle: the placeholder
      // surfaces through SaintImage's errorBuilder, still no network imagery.
      expect(find.byKey(_placeholderKey), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (Widget widget) => widget is Image && widget.image is NetworkImage,
        ),
        findsNothing,
      );
    },
  );

  testWidgets(
    'tapping favorite_toggle flips the icon and the provider container state',
    (WidgetTester tester) async {
      final ProviderContainer container = await pumpSaintDetail(
        tester,
        slug: 'anthony-of-padua',
      );

      // Starts outline (unfavorited).
      expect(find.byKey(const Key('favorite_toggle')), findsOneWidget);
      expect(find.byIcon(Icons.favorite_border), findsOneWidget);
      expect(find.byIcon(Icons.favorite), findsNothing);
      expect(container.read(saintAppSettingsProvider).favoriteSlugs, isEmpty);

      await tester.tap(find.byKey(const Key('favorite_toggle')));
      await tester.pumpAndSettle();

      // Now filled, and the provider CONTAINER state carries the slug (read
      // after the tap, not a widget-local readout).
      expect(find.byIcon(Icons.favorite), findsOneWidget);
      expect(find.byIcon(Icons.favorite_border), findsNothing);
      expect(container.read(saintAppSettingsProvider).favoriteSlugs, <String>[
        'anthony-of-padua',
      ]);

      // Tapping again flips back (toggle, not add).
      await tester.tap(find.byKey(const Key('favorite_toggle')));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.favorite_border), findsOneWidget);
      expect(find.byIcon(Icons.favorite), findsNothing);
      expect(container.read(saintAppSettingsProvider).favoriteSlugs, isEmpty);
    },
  );

  testWidgets('records the saint in the recents provider state on open', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = await pumpSaintDetail(
      tester,
      slug: 'joseph-the-worker',
    );

    // On open (initState) the screen calls addRecent — the settings state
    // carries the visited slug most-recent-first.
    expect(container.read(saintAppSettingsProvider).recentSlugs, <String>[
      'joseph-the-worker',
    ]);
  });

  testWidgets(
    'prayer card copy button copies the prayer and shows a snack bar',
    (WidgetTester tester) async {
      // Clipboard mock (Task-7-style platform-channel precedent): capture the
      // text Clipboard.setData receives without invoking real plugins.
      String? clipboardContents;
      tester.binding.defaultBinaryMessenger.setMockMessageHandler(
        SystemChannels.platform.name,
        (ByteData? message) async {
          final MethodCall call = const JSONMethodCodec().decodeMethodCall(
            message,
          );
          if (call.method == 'Clipboard.setData') {
            final Map<Object?, Object?> args =
                call.arguments as Map<Object?, Object?>;
            clipboardContents = args['text'] as String?;
          }
          return const JSONMethodCodec().encodeSuccessEnvelope(null);
        },
      );
      addTearDown(() {
        tester.binding.defaultBinaryMessenger.setMockMessageHandler(
          SystemChannels.platform.name,
          null,
        );
      });

      await pumpSaintDetail(tester, slug: 'bernard-of-clairvaux');

      await tester.tap(find.byIcon(Icons.copy));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byType(SnackBar), findsOneWidget);
      expect(clipboardContents, 'O loving Bernard, intercede for us.');

      // Flush the snackbar's dismissal timer so teardown has no pending
      // timers.
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    },
  );

  testWidgets('unknown slug renders the saint_not_found fallback', (
    WidgetTester tester,
  ) async {
    await pumpSaintDetail(tester, slug: 'unknown-saint');

    // Category-not-found style fallback: keyed message + back-home button.
    expect(find.byKey(const Key('saint_not_found')), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Back to Home'), findsOneWidget);

    // No detail content renders through the fallback.
    expect(find.byKey(const Key('prayer_card')), findsNothing);
    expect(find.byKey(const Key('patronage_chip_lost_items')), findsNothing);
    expect(find.text('March 5'), findsNothing);
  });

  testWidgets(
    'renders detail_error_state with a retry affordance when the real database load fails',
    (WidgetTester tester) async {
      // Reachability ruling carried over from home/categories (Task 11/12):
      // no injected repository — the production `SaintRepository.instance`
      // load path runs against a genuinely unopenable database (read-only
      // corrupt copy at a redirected databases path), so the keyed error
      // card is reached through the app's real failure mode.
      final ProviderContainer container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.runAsync(() async {
        final String previousDatabasesPath = await databaseFactory
            .getDatabasesPath();
        final Directory tempDir = await Directory.systemTemp.createTemp(
          'saints_detail_fail_',
        );
        await databaseFactory.setDatabasesPath(tempDir.path);
        final String dbPath = '${tempDir.path}/saints.db';
        await File(
          dbPath,
        ).writeAsBytes(List<int>.generate(5000, (int i) => i % 251));
        await Process.run('chmod', <String>['444', dbPath]);

        // Warm the slug provider through the production instance — the
        // failure is expected, so the result is settled (value or error)
        // either way.
        await _settleFuture(
          container.read(saintBySlugProvider('george').future),
        );

        await databaseFactory.setDatabasesPath(previousDatabasesPath);
        await tempDir.delete(recursive: true);
      });

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: SaintDetailScreen(slug: 'george')),
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('detail_error_state')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('detail_error_state')),
          matching: find.text('Retry'),
        ),
        findsOneWidget,
      );
      // No detail content renders through the failure.
      expect(find.text('St. George'), findsNothing);
      expect(find.byKey(const Key('prayer_card')), findsNothing);
    },
  );
}

/// Awaits [future], returning its result or — when it completes with an
/// error — the error itself, so the real-path load-failure warm-up drives
/// the provider regardless of whether the load fails (error expected) or
/// silently succeeds (pre-fix behavior). Mirrors categories_screens_test.dart.
Future<Object?> _settleFuture<T>(Future<T> future) async {
  try {
    return await future;
  } on Object catch (error) {
    return error;
  }
}
