// SaintRepository service tests (Task 7).
//
// The repository is driven against an in-memory FFI SQLite database seeded
// with a pinned fixture (anthony-of-padua, therese-of-lisieux with an é in
// the name, joan-of-arc with 'lost battles' in the bio, george, one
// bio-only-match saint, and one unknown-feast saint), plus the
// `lost items` -> ['lost keys', 'misplaced objects'] synonym rows. The
// seeded FTS rows are written pre-normalized by the same
// `normalizeSearchText` the build tool uses, so query-side tokens line up.
//
// The tiered-search contract pinned here:
//   tier 1 name -> tier 2 patronage (FTS + direct need union) -> tier 3
//   bio/prayer, deduped by slug, rationale attached, then category filter
//   and limit applied.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:saint_data/src/db/saints_schema.dart';
import 'package:saint_data/src/models/saint.dart';
import 'package:saint_data/src/models/saint_category.dart';
import 'package:saint_data/src/models/saint_search_result.dart';
import 'package:saint_data/src/services/saint_repository.dart';
import 'package:saint_data/src/services/saints_db_loader.dart';
import 'package:saint_data/src/utils/normalization.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Patronage (need, category) tuple shape used by the seeder.
typedef _Patronage = ({String need, SaintCategory category});

/// Seeds one saint row + its patronages + its pre-normalized FTS row.
Future<void> _seedSaint(
  Database db, {
  required String slug,
  required String name,
  required String feastDay,
  required String bio,
  String prayerText = '',
  String prayerSource = 'traditional',
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
    'prayer_source': prayerText.isEmpty ? null : prayerSource,
    'featured': featured ? 1 : 0,
    'thumb_asset': thumbAsset,
    'image_attribution': thumbAsset == null ? null : 'Fixture attribution',
    'image_alt': thumbAsset == null ? null : '$name thumbnail',
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

/// Builds the seeded in-memory database with the pinned fixture.
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
    patronages: <_Patronage>[
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
    patronages: <_Patronage>[
      (need: 'missions', category: SaintCategory.spiritual),
    ],
  );
  await _seedSaint(
    db,
    slug: 'joan-of-arc',
    name: 'St. Joan of Arc',
    feastDay: '05-30',
    bio: 'She rallied France after lost battles.',
    thumbAsset: 'assets/thumbs/joan-of-arc.jpg',
    patronages: <_Patronage>[
      (need: 'soldiers', category: SaintCategory.military),
    ],
  );
  await _seedSaint(
    db,
    slug: 'george',
    name: 'St. George',
    feastDay: '04-23',
    bio: 'A dragon slaying knight.',
    patronages: <_Patronage>[
      (need: 'soldiers', category: SaintCategory.military),
    ],
  );
  await _seedSaint(
    db,
    slug: 'sebastian',
    name: 'St. Sebastian',
    feastDay: '01-20',
    // Bio-only match for 'soldiers': the word appears in no other column.
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
    patronages: <_Patronage>[
      (need: 'fathers', category: SaintCategory.spiritual),
    ],
  );
  await _seedSaint(
    db,
    slug: 'joseph-the-worker',
    name: 'St. Joseph the Worker',
    feastDay: '05-01',
    bio: 'A carpenter who worked as a day laborer and trusted in honest work.',
    patronages: <_Patronage>[
      (need: 'day-laborers', category: SaintCategory.jobs),
    ],
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

/// (slug, rationale) pairs for compact search assertions.
List<(String, String)> _pairs(List<SaintSearchResult> results) =>
    <(String, String)>[
      for (final SaintSearchResult result in results)
        (result.saint.slug, result.matchRationale),
    ];

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Database db;
  late SaintRepository repository;

  setUp(() async {
    db = await _createSeededDatabase();
    repository = SaintRepository.forDatabase(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('getBySlug', () {
    test('returns anthony-of-padua with its single patronage', () async {
      final Saint? anthony = await repository.getBySlug('anthony-of-padua');
      expect(anthony, isNotNull);
      expect(anthony!.slug, 'anthony-of-padua');
      expect(anthony.name, 'St. Anthony of Padua');
      expect(anthony.feastDay, '06-13');
      expect(anthony.featured, isTrue);
      expect(anthony.patronages.length, 1);
      expect(anthony.patronages.single.need, 'lost items');
      expect(anthony.patronages.single.category, SaintCategory.everyday);
      // The committed schema stores no per-saint sources table (spec
      // section 6), so DB-loaded saints carry no source rows.
      expect(anthony.sources, isEmpty);
    });

    test('returns null for an unknown slug', () async {
      expect(await repository.getBySlug('no-such-saint'), isNull);
    });

    test('returns the stored thumb fields as-is', () async {
      final Saint? joan = await repository.getBySlug('joan-of-arc');
      expect(joan!.thumbAsset, 'assets/thumbs/joan-of-arc.jpg');
      expect(joan.imageAttribution, 'Fixture attribution');
      expect(joan.imageAlt, 'St. Joan of Arc thumbnail');
    });
  });

  group('getSaintsForFeastDay', () {
    test('returns each seeded saint for its seeded feast key', () async {
      final Map<String, String> seeded = <String, String>{
        '06-13': 'anthony-of-padua',
        '10-01': 'therese-of-lisieux',
        '04-23': 'george',
        '05-30': 'joan-of-arc',
      };
      for (final MapEntry<String, String> entry in seeded.entries) {
        final List<Saint> saints = await repository.getSaintsForFeastDay(
          entry.key,
        );
        expect(
          <String>[for (final Saint saint in saints) saint.slug],
          <String>[entry.value],
          reason: 'feast key ${entry.key} must resolve to its seeded saint',
        );
        expect(<bool>[
          for (final Saint saint in saints) saint.feastDay == entry.key,
        ], everyElement(isTrue));
      }
    });

    test('never returns the unknown-feast saint', () async {
      expect(await repository.getSaintsForFeastDay('unknown'), isEmpty);
      expect(await repository.getSaintsForFeastDay('12-25'), isEmpty);

      final Set<String> slugs = <String>{};
      for (final String key in <String>['06-13', '10-01', '04-23', '05-30']) {
        final List<Saint> saints = await repository.getSaintsForFeastDay(key);
        slugs.addAll(<String>[for (final Saint saint in saints) saint.slug]);
      }
      expect(slugs, isNot(contains('zephyrinus')));
    });
  });

  group('getFeaturedSaints', () {
    test('returns only featured saints ordered by name', () async {
      final List<Saint> featured = await repository.getFeaturedSaints();
      expect(
        <String>[for (final Saint saint in featured) saint.slug],
        <String>['anthony-of-padua', 'therese-of-lisieux'],
      );
      expect(<bool>[
        for (final Saint saint in featured) saint.featured,
      ], everyElement(isTrue));
    });
  });

  group('searchSaints', () {
    test(
      'finds Anthony first via synonym-free FTS plus the direct need union '
      '(lost keys), with patronage rationale and tier-3 bio matches after',
      () async {
        final List<SaintSearchResult> results = await repository.searchSaints(
          'lost keys',
        );
        expect(_pairs(results), <(String, String)>[
          ('anthony-of-padua', 'patronage'),
          ('joan-of-arc', 'bio'),
        ]);
      },
    );

    test('matches Thérèse by name across diacritics', () async {
      final List<SaintSearchResult> results = await repository.searchSaints(
        'therese',
      );
      expect(_pairs(results), <(String, String)>[
        ('therese-of-lisieux', 'name'),
      ]);
    });

    test('treats FTS-operator-looking input as literal tokens', () async {
      // tokenizeSearchQuery strips the quotes and keeps the words, so the
      // expression never sees a raw OR/NOT operator; this must neither
      // throw nor change the result set.
      final List<SaintSearchResult> plain = await repository.searchSaints(
        'therese',
      );
      final List<SaintSearchResult> mangled = await repository.searchSaints(
        '"therese" OR NOT',
      );
      expect(mangled, equals(plain));
      expect(_pairs(mangled), <(String, String)>[
        ('therese-of-lisieux', 'name'),
      ]);
    });

    test('orders patronage matches before bio-only matches', () async {
      final List<SaintSearchResult> results = await repository.searchSaints(
        'soldiers',
      );
      expect(_pairs(results), <(String, String)>[
        ('george', 'patronage'),
        ('joan-of-arc', 'patronage'),
        ('sebastian', 'bio'),
      ]);
    });

    test('returns [] for an empty query even with a category', () async {
      expect(
        await repository.searchSaints('', category: SaintCategory.military),
        isEmpty,
      );
    });

    test('filters results by category', () async {
      final List<SaintSearchResult> results = await repository.searchSaints(
        'joan',
        category: SaintCategory.military,
      );
      expect(_pairs(results), <(String, String)>[('joan-of-arc', 'name')]);
    });

    test('excludes saints outside the requested category', () async {
      final List<SaintSearchResult> results = await repository.searchSaints(
        'joan',
        category: SaintCategory.nature,
      );
      expect(results, isEmpty);
    });

    test('applies the limit after merging tiers', () async {
      final List<SaintSearchResult> results = await repository.searchSaints(
        'soldiers',
        limit: 1,
      );
      expect(_pairs(results), <(String, String)>[('george', 'patronage')]);
    });
  });

  group('getSaintsForNeed', () {
    test('returns Anthony for the canonical need lost items', () async {
      final List<Saint> saints = await repository.getSaintsForNeed(
        'lost items',
      );
      expect(
        <String>[for (final Saint saint in saints) saint.slug],
        <String>['anthony-of-padua'],
      );
    });

    test('expands a synonym need to its canonical need', () async {
      final List<Saint> saints = await repository.getSaintsForNeed('lost keys');
      expect(
        <String>[for (final Saint saint in saints) saint.slug],
        <String>['anthony-of-padua'],
      );
    });

    test('honors the limit', () async {
      final List<Saint> saints = await repository.getSaintsForNeed(
        'soldiers',
        limit: 1,
      );
      expect(
        <String>[for (final Saint saint in saints) saint.slug],
        <String>['george'],
      );
    });
  });

  group('getSaintsForNeed bidirectional and raw keys (fix round 1)', () {
    test('canonical input pulls in synonym-shaped patronages', () async {
      // john-mary-vianney stores need 'fathers', a synonym of 'priests';
      // the downward direction of the synonym union must reach him.
      final List<Saint> saints = await repository.getSaintsForNeed('priests');
      expect(<String>[
        for (final Saint saint in saints) saint.slug,
      ], contains('john-mary-vianney'));
    });

    test('raw synonym-shaped key matches directly and upward', () async {
      final List<Saint> saints = await repository.getSaintsForNeed('fathers');
      expect(<String>[
        for (final Saint saint in saints) saint.slug,
      ], contains('john-mary-vianney'));
    });

    test('hyphenated raw need key resolves', () async {
      // 'day-laborers' passes through normalizeSearchText as 'daylaborers',
      // which matches no stored raw value; the raw variant must resolve.
      final List<Saint> saints = await repository.getSaintsForNeed(
        'day-laborers',
      );
      expect(
        <String>[for (final Saint saint in saints) saint.slug],
        <String>['joseph-the-worker'],
      );
    });
  });

  group('category aggregation', () {
    test('counts distinct saints per category', () async {
      // Fixture extended in fix round 1 with john-mary-vianney (spiritual
      // 'fathers' patronage) and joseph-the-worker (jobs 'day-laborers'
      // patronage), so spiritual rises to 2 and jobs appears with 1.
      final Map<SaintCategory, int> counts = await repository
          .getCategoryCounts();
      expect(counts, <SaintCategory, int>{
        SaintCategory.everyday: 1,
        SaintCategory.spiritual: 2,
        SaintCategory.military: 2,
        SaintCategory.jobs: 1,
      });
    });

    test('orders needs by saint count descending', () async {
      final Map<String, int> needs = await repository.getNeedsForCategory(
        SaintCategory.military,
      );
      expect(needs, <String, int>{'soldiers': 2});
    });
  });

  group('getSaintsByCategory', () {
    test('returns saints carrying that category ordered by name', () async {
      final List<Saint> saints = await repository.getSaintsByCategory(
        SaintCategory.military,
      );
      expect(
        <String>[for (final Saint saint in saints) saint.slug],
        <String>['george', 'joan-of-arc'],
      );
      expect(<bool>[
        for (final Saint saint in saints)
          saint.patronages.any(
            (SaintPatronage p) => p.category == SaintCategory.military,
          ),
      ], everyElement(isTrue));
    });

    test('respects the limit', () async {
      final List<Saint> saints = await repository.getSaintsByCategory(
        SaintCategory.military,
        limit: 1,
      );
      expect(
        <String>[for (final Saint saint in saints) saint.slug],
        <String>['george'],
      );
    });
  });

  group('needsAssetRecopy', () {
    test('is true only when the bundled version is newer than disk', () {
      expect(
        needsAssetRecopy(bundledVersion: 2, diskVersion: 1),
        isTrue,
        reason: 'a newer bundled schema must force a re-copy',
      );
      expect(needsAssetRecopy(bundledVersion: 2, diskVersion: 2), isFalse);
      expect(
        needsAssetRecopy(bundledVersion: 1, diskVersion: 2),
        isFalse,
        reason: 'a newer disk copy must be kept',
      );
    });
  });

  group('committed assets/saints.db (injected-path integration)', () {
    late Database committedDb;
    bool opened = false;

    setUpAll(() async {
      committedDb = await databaseFactoryFfi.openDatabase(
        '${Directory.current.path}/assets/saints.db',
        // singleInstance false: keep this open isolated in the test VM; the
        // repository only reads, so a read-only open is safe.
        options: OpenDatabaseOptions(readOnly: true, singleInstance: false),
      );
      opened = true;
    });

    tearDownAll(() async {
      if (opened) {
        await committedDb.close();
      }
    });

    test(
      'searchSaints("lost keys") is non-empty through the repository',
      () async {
        final SaintRepository committedRepository = SaintRepository.forDatabase(
          committedDb,
        );
        final List<SaintSearchResult> results = await committedRepository
            .searchSaints('lost keys');
        expect(results, isNotEmpty);
        expect(<String>[
          for (final SaintSearchResult result in results) result.saint.slug,
        ], contains('anthony-of-padua'));
      },
    );

    test('shipped synonym and raw-key needs resolve (fix round 1)', () async {
      final SaintRepository committedRepository = SaintRepository.forDatabase(
        committedDb,
      );

      // 69 saints store 'priests' directly and 18 more store need
      // 'fathers' (a 'priests' synonym): both directions must resolve to
      // the 87-saint union (before this fix only 69 were reachable).
      final List<Saint> priests = await committedRepository.getSaintsForNeed(
        'priests',
      );
      expect(priests.length, 87);
      expect(<String>[
        for (final Saint saint in priests) saint.slug,
      ], contains('basil-the-elder'));

      // The raw hyphenated need key must resolve against its two shipped
      // saints (normalizeSearchText alone yields 'daylaborers', stored
      // nowhere).
      final List<Saint> dayLaborers = await committedRepository
          .getSaintsForNeed('day-laborers');
      expect(
        <String>[for (final Saint saint in dayLaborers) saint.slug],
        <String>['guy-of-anderlecht', 'vitalis-of-gaza'],
      );

      // The shipped synonym row 'cross-country skiing' -> 'skiers' must be
      // reachable by the raw phrase; its normalized form 'crosscountry
      // skiing' is stored nowhere.
      expect(
        await committedRepository.getSaintsForNeed('cross-country skiing'),
        isNotEmpty,
      );
    });

    test(
      'invariant: every reported need resolves to at least one saint',
      () async {
        final SaintRepository committedRepository = SaintRepository.forDatabase(
          committedDb,
        );
        final Set<String> allNeeds = <String>{};
        for (final SaintCategory category in SaintCategory.values) {
          final Map<String, int> needs = await committedRepository
              .getNeedsForCategory(category);
          expect(needs, isNotEmpty, reason: '${category.name} has patronages');
          for (final String need in needs.keys) {
            final List<Saint> saints = await committedRepository
                .getSaintsForNeed(need);
            expect(
              saints,
              isNotEmpty,
              reason:
                  'need "$need" (category ${category.name}) reported by '
                  'getNeedsForCategory must be reachable by getSaintsForNeed',
            );
            allNeeds.add(need);
          }
        }
        // The shipped dataset carries 183 distinct patronage needs.
        expect(allNeeds.length, 183);
      },
    );
  });
}
