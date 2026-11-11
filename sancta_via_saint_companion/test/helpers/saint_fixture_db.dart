// Shared in-memory fixture database for the saint_companion screen widget
// tests (Task 13). Extracted from the Task 12 categories test's Task-7
// fixture seeding — the categories and saint-detail screen tests import it
// so the seeding lives in exactly one place. The home screen and provider
// tests keep their own seeders: their fixtures carry extra reviewed pins
// (feast-today saint, featured set, synonyms) that this shared shape does
// not include.
import 'package:saint_data/saint_data.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Seeds one saint row + its patronages + its pre-normalized FTS row (same
/// shape the Task 7–12 screen test seeders share, now single-sourced). The
/// detail-page columns default to unset, matching the original copy's
/// behavior; set [prayerText]/[thumbAsset]/[imageAttribution] to exercise
/// the prayer card, a declared thumbnail, and the attribution line.
Future<void> seedSaint(
  Database db, {
  required String slug,
  required String name,
  required String feastDay,
  required String bio,
  String? canonized,
  String? prayerText,
  String prayerSource = 'traditional',
  bool featured = false,
  String? thumbAsset,
  String? imageAttribution,
  String? imageAlt,
  List<({String need, SaintCategory category})> patronages =
      const <({String need, SaintCategory category})>[],
}) async {
  await db.insert('saints', <String, Object?>{
    'slug': slug,
    'name': name,
    'feast_day': feastDay,
    'canonized': canonized,
    'bio': bio,
    'prayer_text': prayerText,
    'prayer_source': prayerText == null ? null : prayerSource,
    'featured': featured ? 1 : 0,
    'thumb_asset': thumbAsset,
    'image_attribution': imageAttribution,
    'image_alt': imageAlt,
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
    'prayer': prayerText == null ? '' : normalizeSearchText(prayerText),
  });
}

/// Builds the seeded in-memory database shared by the categories + saint
/// detail screen tests: one saint per counted category (anthony/everyday
/// with two everyday patronages, joseph/jobs), two spiritual saints, and
/// two military saints sharing the `soldiers` need — the category saint
/// counts stay identical to the home screen fixture's ('1 saint' ×2, '2
/// saints' ×2, six zero-count categories) because Anthony's second
/// patronage stays in his counted category.
Future<Database> createSeededDatabase() async {
  final Database db = await openDatabase(
    inMemoryDatabasePath,
    singleInstance: false,
  );
  await createSaintsDatabase(db);
  await seedSaint(
    db,
    slug: 'anthony-of-padua',
    name: 'St. Anthony of Padua',
    feastDay: '06-13',
    bio: 'A Franciscan preacher who helps find lost things.',
    patronages: <({String need, SaintCategory category})>[
      (need: 'lost items', category: SaintCategory.everyday),
      (need: 'housework', category: SaintCategory.everyday),
    ],
  );
  await seedSaint(
    db,
    slug: 'therese-of-lisieux',
    name: 'St. Thérèse of Lisieux',
    feastDay: '10-01',
    bio: 'A Carmelite nun known for her little way.',
    patronages: <({String need, SaintCategory category})>[
      (need: 'missions', category: SaintCategory.spiritual),
    ],
  );
  await seedSaint(
    db,
    slug: 'john-mary-vianney',
    name: 'St. John Mary Vianney',
    feastDay: '08-08',
    bio: 'A parish priest famous for long hours in the confessional.',
    patronages: <({String need, SaintCategory category})>[
      (need: 'fathers', category: SaintCategory.spiritual),
    ],
  );
  await seedSaint(
    db,
    slug: 'joseph-the-worker',
    name: 'St. Joseph the Worker',
    feastDay: '05-01',
    bio: 'A carpenter who worked as a day laborer and trusted in honest work.',
    patronages: <({String need, SaintCategory category})>[
      (need: 'day-laborers', category: SaintCategory.jobs),
    ],
  );
  await seedSaint(
    db,
    slug: 'joan-of-arc',
    name: 'St. Joan of Arc',
    feastDay: '05-30',
    bio: 'She rallied France after lost battles.',
    patronages: <({String need, SaintCategory category})>[
      (need: 'soldiers', category: SaintCategory.military),
    ],
  );
  await seedSaint(
    db,
    slug: 'george',
    name: 'St. George',
    feastDay: '04-23',
    bio: 'A dragon slaying knight.',
    patronages: <({String need, SaintCategory category})>[
      (need: 'soldiers', category: SaintCategory.military),
    ],
  );
  return db;
}
