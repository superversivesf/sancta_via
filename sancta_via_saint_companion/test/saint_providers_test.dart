// Saint data provider tests (Task 10).
//
// Every provider is driven through a `ProviderContainer` whose
// `saintRepositoryProvider` is overridden with
// `SaintRepository.forDatabase(...)` over an in-memory FFI SQLite database
// seeded with the Task 7 repository fixture (same saints, patronages, and
// need synonyms) plus one extra no-patronage saint whose feast day is
// today, so `saintsTodayProvider` resolves deterministically without
// disturbing the pinned category counts. With an injected database
// `ensureLoaded` is a no-op, so the production wiring cannot hit the
// bundled asset here.
//
// Only provider-level wiring is pinned: the repository method semantics
// underneath are covered by sancta_via_saint_data's repository tests.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saint_companion/providers/saint_providers.dart';
import 'package:saint_data/saint_data.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Seeds one saint row + its patronages + its pre-normalized FTS row
/// (mirrors the Task 7 repository fixture seeder).
Future<void> _seedSaint(
  Database db, {
  required String slug,
  required String name,
  required String feastDay,
  required String bio,
  String prayerText = '',
  bool featured = false,
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
/// feast-today saint.
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
  // Deterministic `saintsTodayProvider` result: today's feast key, and no
  // patronages so the category counts above stay untouched.
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
  late ProviderContainer container;

  setUp(() async {
    db = await _createSeededDatabase();
    container = ProviderContainer(
      overrides: <Override>[
        saintRepositoryProvider.overrideWithValue(
          SaintRepository.forDatabase(db),
        ),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  group('saintsTodayProvider', () {
    test('resolves the seeded saint whose feast day is today', () async {
      final List<Saint> saints = await container.read(
        saintsTodayProvider.future,
      );
      expect(saints.map((Saint saint) => saint.slug), <String>['feast-today']);
    });
  });

  group('saintSearchProvider', () {
    test(
      'resolves Anthony of Padua for the synonym query "lost keys"',
      () async {
        final List<SaintSearchResult> results = await container.read(
          saintSearchProvider(('lost keys', null)).future,
        );
        expect(results, isNotEmpty);
        expect(results.first.saint.slug, 'anthony-of-padua');
      },
    );
  });

  group('categoryCountsProvider', () {
    test('matches the seeded distinct-saint counts per category', () async {
      final Map<SaintCategory, int> counts = await container.read(
        categoryCountsProvider.future,
      );
      expect(counts, <SaintCategory, int>{
        SaintCategory.everyday: 1,
        SaintCategory.spiritual: 2,
        SaintCategory.military: 2,
        SaintCategory.jobs: 1,
      });
    });
  });

  group('saintBySlugProvider', () {
    test('resolves null for an unknown slug', () async {
      final Saint? saint = await container.read(
        saintBySlugProvider('no-such-saint').future,
      );
      expect(saint, isNull);
    });
  });

  group('saintsByNeedProvider', () {
    test('reaches saints through need synonyms', () async {
      final List<Saint> saints = await container.read(
        saintsByNeedProvider('lost keys').future,
      );
      expect(saints.map((Saint saint) => saint.slug), <String>[
        'anthony-of-padua',
      ]);
    });
  });
}
