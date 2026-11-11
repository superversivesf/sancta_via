// Home screen widget tests (Task 11).
//
// Mirrors the Task 10 provider test seeding: an in-memory FFI SQLite
// database seeded with the Task 7 fixture (plus the feast-today saint) and
// injected via `saintRepositoryProvider.overrideWithValue(
// SaintRepository.forDatabase(db))`. The liturgical day provider is
// overridden with a fixed `LiturgicalDayData` (or null) at every test, which
// both pins the celebration rendering and keeps
// `currentDateProvider`'s periodic timer out of the fake-async test zone.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saint_companion/providers/saint_providers.dart';
import 'package:saint_companion/screens/home/home_screen.dart';
import 'package:saint_companion/widgets/category_card.dart';
import 'package:saint_companion/widgets/liturgical_day_card.dart';
import 'package:saint_data/saint_data.dart';
import 'package:sancta_via_liturgical_calendar_riverpod/sancta_via_liturgical_calendar_riverpod.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Fixed liturgical day used to pin the celebration card rendering.
LiturgicalDayData _fixedLiturgicalDay() {
  return const LiturgicalDayData(
    date: '2026-11-12',
    season: 'Ordinary Time',
    seasonKey: 'ordinary_time',
    celebration: LiturgicalCelebration(
      key: 'saint-paul-of-the-cross',
      name: 'Saint Paul of the Cross',
      type: 'memorial',
      rank: 'MEMORIAL',
      color: 'RED',
      colorName: 'Red',
      source: 'test-fixture',
      prioritized: true,
      titles: <String>[],
    ),
    liturgicalYear: LiturgicalYearInfo(
      year: 2026,
      cycle: LiturgicalCycle(key: 1, value: 'C'),
      week: 32,
      day: 4,
      weekOfSeason: 3,
    ),
    psalterWeek: PsalterWeek(key: 4, value: 'Week IV'),
  );
}

const Key _placeholderKey = Key('saint_image_placeholder');

/// Seeds one saint row + its patronages + its pre-normalized FTS row
/// (reused from the Task 10 provider test seeder, plus an optional thumb).
Future<void> _seedSaint(
  Database db, {
  required String slug,
  required String name,
  required String feastDay,
  required String bio,
  String prayerText = '',
  bool featured = false,
  String? thumbAsset,
  List<({String need, SaintCategory category})> patronages =
      const <({String need, SaintCategory category})>[],
}) async {
  await db.insert('saints', <String, Object?>{
    'slug': slug,
    'name': name,
    'feast_day': feastDay,
    'bio': bio,
    'prayer_text': prayerText.isEmpty ? null : prayerText,
    'prayer_source': prayerText.isEmpty ? null : 'traditional',
    'featured': featured ? 1 : 0,
    'thumb_asset': thumbAsset,
  });
  for (final ({String need, SaintCategory category}) patronage in patronages) {
    await db.insert('patronages', <String, Object?>{
      'slug': slug,
      'need': patronage.need,
      'category': patronage.category.name,
    });
  }
  await db.insert('saint_fts', <String, Object?>{
    'slug': slug,
    'name': normalizeSearchText(name),
    'patronages': patronages
        .map(
          (({String need, SaintCategory category}) p) =>
              normalizeSearchText(p.need),
        )
        .join(' '),
    'bio': normalizeSearchText(bio),
    'prayer': prayerText.isEmpty ? '' : normalizeSearchText(prayerText),
  });
}

/// Builds the seeded in-memory database with the Task 7 fixture plus the
/// feast-today saint (same shape as the Task 10 provider test).
Future<Database> _createSeededDatabase() async {
  final Database db = await openDatabase(
    inMemoryDatabasePath,
    singleInstance: false,
  );
  await createSaintsDatabase(db);
  await _seedSaint(
    db,
    slug: 'anthony-of-padua',
    name: 'St. Anthony of Padua',
    feastDay: '06-13',
    bio: 'A Franciscan preacher who helps find lost things.',
    prayerText: 'O gentle helper, restore what is lost to me.',
    featured: true,
    thumbAsset: 'assets/thumbs/anthony-of-padua.jpg',
    patronages: <({String need, SaintCategory category})>[
      (need: 'lost items', category: SaintCategory.everyday),
    ],
  );
  await _seedSaint(
    db,
    slug: 'therese-of-lisieux',
    name: 'St. Thérèse of Lisieux',
    feastDay: '10-01',
    bio: 'A Carmelite nun known for her little way.',
    featured: true,
    patronages: <({String need, SaintCategory category})>[
      (need: 'missions', category: SaintCategory.spiritual),
    ],
  );
  await _seedSaint(
    db,
    slug: 'joan-of-arc',
    name: 'St. Joan of Arc',
    feastDay: '05-30',
    bio: 'She rallied France after lost battles.',
    patronages: <({String need, SaintCategory category})>[
      (need: 'soldiers', category: SaintCategory.military),
    ],
  );
  await _seedSaint(
    db,
    slug: 'george',
    name: 'St. George',
    feastDay: '04-23',
    bio: 'A dragon slaying knight.',
    patronages: <({String need, SaintCategory category})>[
      (need: 'soldiers', category: SaintCategory.military),
    ],
  );
  await _seedSaint(
    db,
    slug: 'sebastian',
    name: 'St. Sebastian',
    feastDay: '01-20',
    bio: 'Shot with arrows by his own soldiers.',
  );
  await _seedSaint(
    db,
    slug: 'zephyrinus',
    name: 'St. Zephyrinus',
    feastDay: 'unknown',
    bio: 'A bishop of Rome in early times.',
  );
  await _seedSaint(
    db,
    slug: 'john-mary-vianney',
    name: 'St. John Mary Vianney',
    feastDay: '08-08',
    bio: 'A parish priest famous for long hours in the confessional.',
    patronages: <({String need, SaintCategory category})>[
      (need: 'fathers', category: SaintCategory.spiritual),
    ],
  );
  await _seedSaint(
    db,
    slug: 'joseph-the-worker',
    name: 'St. Joseph the Worker',
    feastDay: '05-01',
    bio: 'A carpenter who worked as a day laborer and trusted in honest work.',
    patronages: <({String need, SaintCategory category})>[
      (need: 'day-laborers', category: SaintCategory.jobs),
    ],
  );
  // Gives `saintsTodayProvider` a guaranteed hit at today's MM-DD key.
  await _seedSaint(
    db,
    slug: 'feast-today',
    name: 'St. Feast Today',
    feastDay: SaintFeastService.feastKeyForDate(DateTime.now()),
    bio: 'A saint remembered on this calendar day.',
  );
  await db.insert('need_synonyms', <String, Object?>{
    'need': 'lost items',
    'synonym': 'lost keys',
  });
  await db.insert('need_synonyms', <String, Object?>{
    'need': 'lost items',
    'synonym': 'misplaced objects',
  });
  await db.insert('need_synonyms', <String, Object?>{
    'need': 'priests',
    'synonym': 'fathers',
  });
  return db;
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Database db;

  setUp(() async {
    db = await _createSeededDatabase();
  });

  tearDown(() async {
    await db.close();
  });

  /// Pumps the home screen in a router-less harness:
  /// `MaterialApp(home: HomeScreen())` over an `UncontrolledProviderScope`
  /// whose container carries the repository override plus the liturgical
  /// day override ([liturgicalDay], null when omitted).
  ///
  /// The sqflite FFI queries run on a real background isolate and never
  /// land inside the fake-async test zone, so the [preWarm] providers are
  /// first resolved for real (via `tester.runAsync`) — after which the
  /// widget phase renders `AsyncData` synchronously and `pumpAndSettle` is
  /// safe (no loading spinner animating forever).
  Future<void> pumpHomeScreen(
    WidgetTester tester, {
    LiturgicalDayData? liturgicalDay,
    List<Override> extraOverrides = const <Override>[],
    bool preWarmToday = true,
    bool pumpSettleFrames = true,
  }) async {
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        saintRepositoryProvider.overrideWithValue(
          SaintRepository.forDatabase(db),
        ),
        currentLiturgicalDayProvider.overrideWith((Ref ref) => liturgicalDay),
        ...extraOverrides,
      ],
    );
    addTearDown(container.dispose);
    await tester.runAsync(() async {
      await Future.wait(<Future<dynamic>>[
        container.read(featuredSaintsProvider.future),
        container.read(categoryCountsProvider.future),
        if (preWarmToday) container.read(saintsTodayProvider.future),
      ]);
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    if (pumpSettleFrames) {
      await tester.pumpAndSettle();
    }
  }

  testWidgets('renders today\'s saint under today_saints_section', (
    WidgetTester tester,
  ) async {
    await pumpHomeScreen(tester);

    expect(find.byKey(const Key('today_saints_section')), findsOneWidget);
    expect(find.byKey(const Key('saint_card_feast-today')), findsOneWidget);
    expect(find.text('St. Feast Today'), findsOneWidget);
  });

  testWidgets('shows a loading spinner while a provider is still resolving', (
    WidgetTester tester,
  ) async {
    // A future that never completes pins the loading state: the today's
    // saints section shows its spinner while the rest of the screen
    // renders from the pre-warmed providers. No pumpAndSettle here —
    // the spinner animation never settles by design.
    await pumpHomeScreen(tester, preWarmToday: false, pumpSettleFrames: false);

    expect(find.byType(CircularProgressIndicator), findsWidgets);
    expect(find.text('St. Feast Today'), findsNothing);
  });

  testWidgets(
    'renders today_empty_state when no saints share today\'s feast day',
    (WidgetTester tester) async {
      // Review Focus #3: an empty feast day must show the empty state.
      await pumpHomeScreen(
        tester,
        extraOverrides: <Override>[
          saintsTodayProvider.overrideWith((Ref ref) async => const <Saint>[]),
        ],
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('today_empty_state')), findsOneWidget);
      expect(find.text('St. Feast Today'), findsNothing);

      // The rest of the home screen still renders.
      expect(find.byKey(const Key('featured_section')), findsOneWidget);
    },
  );

  testWidgets(
    'renders the featured saints row with a card per featured saint',
    (WidgetTester tester) async {
      await pumpHomeScreen(tester);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('featured_section')), findsOneWidget);
      expect(
        find.byKey(const Key('saint_card_anthony-of-padua')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('saint_card_therese-of-lisieux')),
        findsOneWidget,
      );
      expect(find.text('St. Anthony of Padua'), findsOneWidget);
      // The featured cards use bundled thumbs via SaintImage's asset path.
      final Image featuredImage = tester.widget<Image>(
        find.byType(Image).first,
      );
      expect(featuredImage.image, isA<AssetImage>());
    },
  );

  testWidgets('renders 10 CategoryCards in the grid with the seeded counts', (
    WidgetTester tester,
  ) async {
    await pumpHomeScreen(tester);
    await tester.pumpAndSettle();

    // All 10 categories render; the 6 categories without fixture saints
    // show a zero count.
    expect(find.byType(CategoryCard), findsNWidgets(10));
    expect(find.text('1 saint'), findsNWidgets(2)); // everyday + jobs
    expect(find.text('2 saints'), findsNWidgets(2)); // spiritual + military
    expect(find.text('0 saints'), findsNWidgets(6));
    expect(
      find.byWidgetPredicate(
        (Widget widget) => widget is Image && widget.image is NetworkImage,
      ),
      findsNothing,
    );
  });

  testWidgets(
    'renders the liturgical celebration name, rank label, and colored dot',
    (WidgetTester tester) async {
      await pumpHomeScreen(tester, liturgicalDay: _fixedLiturgicalDay());
      await tester.pumpAndSettle();

      expect(find.text('Saint Paul of the Cross'), findsOneWidget);
      expect(find.text('Memorial'), findsOneWidget);

      // The colored dot comes from celebrations' RED color (shared palette's
      // vibrant red).
      final Finder dotFinder = find.byWidgetPredicate(
        (Widget widget) =>
            widget is Container &&
            widget.decoration is BoxDecoration &&
            (widget.decoration! as BoxDecoration).shape == BoxShape.circle,
      );
      expect(dotFinder, findsOneWidget);
      final Container dot = tester.widget<Container>(dotFinder);
      expect((dot.decoration! as BoxDecoration).color, const Color(0xFFD32F2F));
    },
  );

  testWidgets(
    'renders the load error state with a retry affordance when a provider fails',
    (WidgetTester tester) async {
      // Ledger preflight ruling: failed repository loads surface a
      // keyed error state with a retry button instead of a blank screen.
      await pumpHomeScreen(
        tester,
        preWarmToday: false, // the today provider is stubbed to throw
        extraOverrides: <Override>[
          saintsTodayProvider.overrideWith(
            (Ref ref) async => throw Exception('saints db unavailable'),
          ),
        ],
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('load_error_state')), findsOneWidget);
      expect(find.byType(FilledButton), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    },
  );

  testWidgets('LiturgicalDayCard with a null day renders nothing', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: LiturgicalDayCard(day: null))),
    );
    await tester.pumpAndSettle();

    expect(find.byType(LiturgicalDayCard), findsOneWidget);
    expect(find.byType(Text), findsNothing);
    expect(find.byKey(_placeholderKey), findsNothing);
    expect(find.byType(Container), findsNothing);
    expect(find.byType(Icon), findsNothing);
  });
}
