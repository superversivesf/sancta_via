// Saint detail screen widget tests (Task 13).
//
// Reuses the shared screen-test fixture (test/helpers/saint_fixture_db.dart,
// extracted from the Task 12 categories seeder) with ONE detail-only saint
// appended per database (bernard-of-clairvaux: attribution, canonized line,
// prayer, and a deliberately-missing thumb asset mirroring the Task 6
// carry-forward saints) and one Task-6 history-backed saint
// (francis-of-assisi: schema-v2 history + history_source columns and a
// two-row `sources` table). The repository-backed provider is resolved for
// real inside `tester.runAsync` before pumping (Task 11/12 harness) so the
// widget phase renders `AsyncData` synchronously and `pumpAndSettle` is
// safe. The load-failure test uses the REAL production first-load path
// through `SaintRepository.forAssetPath('assets/does-not-exist.db')`
// (final-review wave rehome: the app now bundles a working
// `assets/saints.db`, so asset absence can no longer force the failure),
// same technique as categories_screens_test.dart.
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

/// The Task-6 history-backed saint's seeded content, referenced verbatim by
/// the tests below.
const String _francisHistory =
    'Born in Assisi in 1181, he renounced his family wealth and founded the '
    'Friars Minor, serving the poor and preaching peace until his death in '
    '1226.';

const String _francisHistorySource =
    'catholic-encyclopedia-1907 https://www.newadvent.org/cathen/06221a.htm';

const String _historyAttribution =
    'Adapted from the Catholic Encyclopedia (1907–12)';

/// The seeded `sources` rows for the history-backed saint, `position` order.
const List<String> _francisSources = <String>[
  _francisHistorySource,
  'https://en.wikisource.org/wiki/St._Francis_of_Assisi',
];

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
  await seedSaint(
    db,
    slug: 'francis-of-assisi',
    name: 'St. Francis of Assisi',
    feastDay: '10-04',
    bio: 'He renounced a life of wealth to preach poverty and peace.',
    prayerText: 'O blessed Francis, pray for us.',
    history: _francisHistory,
    historySource: _francisHistorySource,
    sources: _francisSources,
  );
  return db;
}

/// A saint resolved by [_FakeSaintRepository] for the visit-tracking tests:
/// enough fields for the screen to render a populated detail page.
const Saint _fakeJoseph = Saint(
  slug: 'joseph-the-worker',
  name: 'St. Joseph the Worker',
  feastDay: '05-01',
  bio: 'A carpenter who worked as a day laborer and trusted in honest work.',
);

/// A repository whose [SaintRepository.getBySlug] completes synchronously
/// with [resolve]() (null = not-found). The visit-tracking tests must drive
/// the deferred initState task's await through the TEST's fake-async zone:
/// futures resolved for real inside `tester.runAsync` (prewarm) are created
/// in the binding's real-time zone and never resume under fake-async, which
/// would leave the deferred task suspended instead of exercising the mounted
/// re-check and the null guard.
class _FakeSaintRepository extends Fake implements SaintRepository {
  _FakeSaintRepository(this.resolve);

  final Future<Saint?> Function() resolve;

  @override
  Future<void> ensureLoaded() async {}

  @override
  Future<Saint?> getBySlug(String slug) => resolve();
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
  /// When [fakeResolver] is set it replaces the seeded repository (and the
  /// prewarm step) with [_FakeSaintRepository] — see the visit-tracking
  /// tests below for why. Returns the container so provider-state asserts
  /// can read it after taps.
  Future<ProviderContainer> pumpSaintDetail(
    WidgetTester tester, {
    required String slug,
    bool preWarm = true,
    Future<Saint?> Function()? fakeResolver,
    List<Override> extraOverrides = const <Override>[],
  }) async {
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        saintRepositoryProvider.overrideWithValue(
          fakeResolver == null
              ? SaintRepository.forDatabase(db)
              : _FakeSaintRepository(fakeResolver),
        ),
        ...extraOverrides,
      ],
    );
    addTearDown(container.dispose);
    if (fakeResolver == null && preWarm) {
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
    'history-present saint renders a History section with the CE attribution between bio and prayer',
    (WidgetTester tester) async {
      await pumpSaintDetail(tester, slug: 'francis-of-assisi');

      // The 'History' header, the seeded schema-v2 body, and the pinned
      // provenance line — exactly worded "Adapted from ..." (the text is a
      // grounded summary, never presented as the Encyclopedia's own prose).
      expect(find.text('History'), findsOneWidget);
      expect(find.text(_francisHistory), findsOneWidget);
      expect(find.text(_historyAttribution), findsOneWidget);
      expect(find.byKey(const Key('history_attribution')), findsOneWidget);

      // Scrollable with the page (no inner viewport): the section renders
      // inside the existing SingleChildScrollView between the bio paragraph
      // and the prayer card.
      final List<String> texts = _detailTextsInPaintOrder(tester);
      final int bioIndex = texts.indexOf(
        'He renounced a life of wealth to preach poverty and peace.',
      );
      final int headerIndex = texts.indexOf('History');
      final int historyIndex = texts.indexOf(_francisHistory);
      final int attributionIndex = texts.indexOf(_historyAttribution);
      final int prayerIndex = texts.indexOf('O blessed Francis, pray for us.');
      expect(bioIndex, isNonNegative, reason: 'the bio renders');
      expect(
        headerIndex,
        greaterThan(bioIndex),
        reason: 'the History header follows the bio paragraph',
      );
      expect(
        historyIndex,
        greaterThan(headerIndex),
        reason: 'the history body follows its header',
      );
      expect(
        attributionIndex,
        greaterThan(historyIndex),
        reason: 'the attribution line sits directly under the history body',
      );
      expect(
        prayerIndex,
        greaterThan(attributionIndex),
        reason: 'the prayer card follows the History section',
      );
    },
  );

  testWidgets(
    'Source rows render as plain launch-less text in position order',
    (WidgetTester tester) async {
      await pumpSaintDetail(tester, slug: 'francis-of-assisi');

      // The previously-dormant Sources section goes live: a header and one
      // plain-text URL per `sources` row.
      expect(find.text('Sources'), findsOneWidget);
      expect(find.text(_francisSources[0]), findsOneWidget);
      expect(find.text(_francisSources[1]), findsOneWidget);

      // `position` order: row 0 paints before row 1.
      final List<String> texts = _detailTextsInPaintOrder(tester);
      expect(
        texts.indexOf(_francisSources[0]),
        lessThan(texts.indexOf(_francisSources[1])),
        reason: 'sources rows render in their stored position order',
      );

      // Launch-less (Task-13 ruling: this app carries no url_launcher
      // dependency): each row's InkWell carries no tap handler — the URL
      // text never launches — and no action icon suggests it opens anywhere.
      for (final String url in _francisSources) {
        final Iterable<InkWell> rowInk = tester.widgetList<InkWell>(
          find.ancestor(of: find.text(url), matching: find.byType(InkWell)),
        );
        expect(rowInk, isNotEmpty, reason: '$url renders in a tile row');
        expect(
          rowInk.every((InkWell ink) => ink.onTap == null),
          isTrue,
          reason: '$url renders launch-less: no tap handler on its row',
        );
        expect(
          find.ancestor(
            of: find.text(url),
            matching: find.byIcon(Icons.open_in_new),
          ),
          findsNothing,
        );
      }
    },
  );

  testWidgets(
    'a saint without history renders exactly as today (no History header, attribution, or Sources)',
    (WidgetTester tester) async {
      await pumpSaintDetail(tester, slug: 'anthony-of-padua');

      // Today's layout: bio + the seeded patronage chips (no prayer seeded →
      // no prayer card).
      expect(
        find.text('A Franciscan preacher who helps find lost things.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('prayer_card')), findsNothing);

      // The Task-6 sections stay fully dormant for a record with no history
      // and no source rows (the fallback honesty pin).
      expect(find.text('History'), findsNothing);
      expect(find.text(_historyAttribution), findsNothing);
      expect(find.byKey(const Key('history_attribution')), findsNothing);
      expect(find.text('Sources'), findsNothing);
      expect(find.textContaining('newadvent'), findsNothing);
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
    // Fake-resolver harness (see [_FakeSaintRepository]): drives the
    // deferred visit task's await through the test's fake-async zone so the
    // mounted re-checks and the non-null guard actually execute, then the
    // write lands.
    final ProviderContainer container = await pumpSaintDetail(
      tester,
      slug: 'joseph-the-worker',
      fakeResolver: () async => _fakeJoseph,
    );

    // On open (initState) the screen calls addRecent — the settings state
    // carries the visited slug most-recent-first.
    expect(container.read(saintAppSettingsProvider).recentSlugs, <String>[
      'joseph-the-worker',
    ]);
  });

  testWidgets('unknown slug leaves the recents provider state untouched', (
    WidgetTester tester,
  ) async {
    // Fix round 1 ruling: recents record only RESOLVED saints — the null
    // guard executes for real here (fake-resolver harness), and an unknown
    // slug never enters the list.
    final ProviderContainer container = await pumpSaintDetail(
      tester,
      slug: 'unknown-saint',
      fakeResolver: () async => null,
    );

    expect(container.read(saintAppSettingsProvider).recentSlugs, isEmpty);
  });

  testWidgets(
    'a screen disposed before its deferred visit turn records nothing',
    (WidgetTester tester) async {
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          saintRepositoryProvider.overrideWithValue(
            SaintRepository.forDatabase(db),
          ),
        ],
      );
      addTearDown(container.dispose);
      // Resolve the saint for real BEFORE pumping, so that a missing guard
      // would let the deferred task's await complete and still write recents —
      // the test must not pass merely because the future never resolves.
      await tester.runAsync(() async {
        await container.read(saintBySlugProvider('george').future);
      });
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: SaintDetailScreen(slug: 'george')),
        ),
      );
      // A plain pumpWidget does not advance the fake clock, so the zero-delay
      // (Future-run) visit task is still pending. Popping the route here —
      // disposing the screen before its deferred turn — is the review's
      // scenario: without the [mounted] guard, riverpod 2.6.1 raises
      // `StateError: Cannot use "ref" after the widget was disposed.` from the
      // timer callback (consumer.dart _assertNotDisposed).
      await tester.pumpWidget(const SizedBox());
      // Flush the deferred turn now that the screen is gone.
      await tester.pump(const Duration(milliseconds: 100));

      expect(container.read(saintAppSettingsProvider).recentSlugs, isEmpty);
    },
  );

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

    testWidgets(
    'wikipedia-class history renders its own attribution line',
    (WidgetTester tester) async {
      // sqflite FFI futures must resolve outside the fake-async zone
      // (see the pumpSaintDetail prewarm comment) — the in-test seeding
      // rides `runAsync` like the prewarm does.
      await tester.runAsync(
        () => seedSaint(
          db,
          slug: 'modern-saint',
          name: 'St. A Modern Saint',
          feastDay: '05-01',
          bio: 'A modern-era saint for the attribution test.',
          prayerText: 'Pray for us.',
          history: 'A grounded modern-era summary written in 2026.',
          historySource:
              'wikipedia https://en.wikipedia.org/wiki/A_Modern_Saint',
        ),
      );

      await pumpSaintDetail(tester, slug: 'modern-saint');

      expect(
        find.text('Adapted from Wikipedia (CC BY-SA 4.0)'),
        findsOneWidget,
        reason: 'the wikipedia class renders its pinned attribution line',
      );
      // The CE line must NOT appear for a wikipedia-sourced saint.
      expect(find.text(_historyAttribution), findsNothing);
    },
  );

  testWidgets(
    'unknown history source class falls back to a generic attribution',
    (WidgetTester tester) async {
      // sqflite FFI inside runAsync (same zone constraint as above).
      await tester.runAsync(
        () => seedSaint(
          db,
          slug: 'odd-source-saint',
          name: 'St. Odd Source',
          feastDay: '06-02',
          bio: 'A saint whose source class predates the registry.',
          prayerText: 'Pray for us.',
          history: 'A grounded summary with an unrecognized source class.',
          historySource: 'random-site https://www.example.com/saint',
        ),
      );

      await pumpSaintDetail(tester, slug: 'odd-source-saint');

      expect(
        find.text('Adapted from a Catholic source'),
        findsOneWidget,
        reason: 'an unknown class never renders the CE line',
      );
      expect(find.text(_historyAttribution), findsNothing);
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
      // Final-review fix wave rehome (was: SaintRepository.instance against
      // a read-only corrupt copy — a technique that relied on the app NOT
      // bundling `assets/saints.db`): the reachability pin forces the
      // genuine first-load failure through the saint_data error seam
      // SaintRepository.forAssetPath (no injected repository stub). Pinned
      // assertions unchanged.
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
          'saints_detail_fail_',
        );
        await databaseFactory.setDatabasesPath(tempDir.path);
        try {
          // Warm the slug provider through the genuine first-load failure —
          // expected, so the result is settled (value or error) either way.
          await _settleFuture(
            container.read(saintBySlugProvider('george').future),
          );
        } finally {
          await databaseFactory.setDatabasesPath(previousDatabasesPath);
        }
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

/// Plain text of every [Text] inside the detail screen's scroll view, in
/// paint order — a stable proxy for the Column's child order, used to pin
/// the Task-6 section ordering (bio → History → attribution → prayer) and
/// the `sources` rows' `position` order.
List<String> _detailTextsInPaintOrder(WidgetTester tester) {
  return tester
      .widgetList<Text>(
        find.descendant(
          of: find.byType(SingleChildScrollView),
          matching: find.byType(Text),
        ),
      )
      .map((Text text) => text.data ?? '')
      .toList();
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
