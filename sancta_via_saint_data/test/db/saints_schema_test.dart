// Schema tests for the saints.db SQLite store (spec section 6 + schema v2).
//
// These run `createSaintsDatabase` against an in-memory FFIsqflite database
// and pin the spec DDL: user_version, the 3 tables + 5 indexes plus the v2
// `saints.history`/`saints.history_source` columns and the `sources` table,
// the FTS4 virtual table with the unicode61 tokenizer, usable inserts, the
// slug primary key, and prefix-phrase MATCH over pre-normalized text.
import 'package:flutter_test/flutter_test.dart';
import 'package:saint_data/src/db/saints_schema.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Opens a fresh, isolated in-memory database backed by the FFI factory.
Future<Database> _openInMemory() {
  return openDatabase(inMemoryDatabasePath, singleInstance: false);
}

/// A saint row shaped for the spec `saints` columns.
const Map<String, Object?> _garimaRow = <String, Object?>{
  'slug': 'abba-garima',
  'name': 'St. Abba Garima',
  'feast_day': '06-24',
  'canonized': 'Pre-Congregation',
  'bio': 'Abba Garima founded a monastery in the highlands of Tigray.',
  'prayer_text': 'O God, who sent blessed Garima to plant the Gospel.',
  'prayer_source': 'original',
  'featured': 1,
  'thumb_asset': 'packages/saint_data/assets/thumbs/abba-garima.jpg',
  'image_attribution': 'Wikimedia Commons',
  'image_alt': 'Portrait of St. Abba Garima',
};

void main() {
  setUp(() {
    databaseFactory = databaseFactoryFfi;
  });

  group('createSaintsDatabase', () {
    test('runs every spec section 6 schema statement', () async {
      final Database db = await _openInMemory();
      await createSaintsDatabase(db);

      final List<Map<String, Object?>> objects = await db.rawQuery(
        'SELECT name, type FROM sqlite_master ORDER BY name',
      );
      final Set<String> names = <String>{
        for (final Map<String, Object?> row in objects)
          (row['name'] as String).toLowerCase(),
      };

      expect(
        names,
        containsAll(<String>{
          'saints',
          'patronages',
          'need_synonyms',
          'sources',
          'idx_saints_feast',
          'idx_saints_featured',
          'idx_patronages_category',
          'idx_patronages_need',
          'idx_synonyms_synonym',
          'saint_fts',
        }),
      );

      await db.close();
    });

    test('creates the saints table with exactly the 13 v2 columns', () async {
      final Database db = await _openInMemory();
      await createSaintsDatabase(db);

      final List<Map<String, Object?>> columns = await db.rawQuery(
        'PRAGMA table_info(saints)',
      );
      expect(
        <String>[
          for (final Map<String, Object?> c in columns) c['name'] as String,
        ],
        <String>[
          'slug',
          'name',
          'feast_day',
          'canonized',
          'bio',
          'prayer_text',
          'prayer_source',
          'featured',
          'thumb_asset',
          'image_attribution',
          'image_alt',
          // Schema v2 (grounded histories).
          'history',
          'history_source',
        ],
      );

      await db.close();
    });

    test('sets PRAGMA user_version to saintsSchemaVersion (2)', () async {
      final Database db = await _openInMemory();
      await createSaintsDatabase(db);

      final List<Map<String, Object?>> version = await db.rawQuery(
        'PRAGMA user_version',
      );
      const int expected = saintsSchemaVersion;
      expect(expected, 2);
      expect(version.single['user_version'], expected);

      await db.close();
    });
  });

  group('inserts against the created schema', () {
    test('accepts a saint with two patronages and a synonym', () async {
      final Database db = await _openInMemory();
      await createSaintsDatabase(db);

      await db.insert('saints', _garimaRow);
      await db.insert('patronages', <String, Object?>{
        'slug': 'abba-garima',
        'need': 'monks',
        'category': 'spiritual',
      });
      await db.insert('patronages', <String, Object?>{
        'slug': 'abba-garima',
        'need': 'missionaries',
        'category': 'spiritual',
      });
      await db.insert('need_synonyms', <String, Object?>{
        'need': 'monks',
        'synonym': 'monastic fathers',
      });

      expect(
        (await db.query('saints')).length,
        1,
        reason: 'one saints row survives',
      );
      expect(
        (await db.query('patronages')).length,
        2,
        reason: 'two patronages rows survive',
      );
      expect(
        (await db.query('need_synonyms')).length,
        1,
        reason: 'one synonym row survives',
      );

      await db.close();
    });

    test('rejects a duplicate slug with a uniqueness error', () async {
      final Database db = await _openInMemory();
      await createSaintsDatabase(db);

      await db.insert('saints', _garimaRow);

      await expectLater(
        db.insert('saints', _garimaRow),
        throwsA(
          predicate<Exception>((Exception e) {
            return e.toString().contains('UNIQUE constraint');
          }),
        ),
        reason: 'slug is the saints primary key',
      );

      await db.close();
    });
  });

  group('sources table (schema v2)', () {
    test('round-trips source rows ordered by position', () async {
      final Database db = await _openInMemory();
      await createSaintsDatabase(db);

      await db.insert('saints', _garimaRow);
      await db.insert('sources', <String, Object?>{
        'slug': 'abba-garima',
        'url': 'https://en.wikipedia.org/wiki/Abba_Garima',
        'position': 0,
      });
      await db.insert('sources', <String, Object?>{
        'slug': 'abba-garima',
        'url': 'https://www.newadvent.org/cathen/06221a.htm',
        'position': 1,
      });

      final List<Map<String, Object?>> rows = await db.rawQuery(
        'SELECT url, position FROM sources '
        "WHERE slug = 'abba-garima' ORDER BY position",
      );
      expect(
        <String>[
          for (final Map<String, Object?> row in rows) row['url']! as String,
        ],
        <String>[
          'https://en.wikipedia.org/wiki/Abba_Garima',
          'https://www.newadvent.org/cathen/06221a.htm',
        ],
        reason: 'sources must come back in position order for getBySlug',
      );

      await db.close();
    });

    test(
      'rejects a duplicate (slug, position) with a uniqueness error',
      () async {
        final Database db = await _openInMemory();
        await createSaintsDatabase(db);

        await db.insert('saints', _garimaRow);
        await db.insert('sources', <String, Object?>{
          'slug': 'abba-garima',
          'url': 'https://en.wikipedia.org/wiki/Abba_Garima',
          'position': 0,
        });

        await expectLater(
          db.insert('sources', <String, Object?>{
            'slug': 'abba-garima',
            'url': 'https://en.wikipedia.org/wiki/Abba_Garima',
            'position': 0,
          }),
          throwsA(
            predicate<Exception>((Exception e) {
              return e.toString().contains('UNIQUE constraint');
            }),
          ),
          reason: '(slug, position) is the sources primary key',
        );

        await db.close();
      },
    );
  });

  group('saint_fts (fts4 + unicode61)', () {
    test(
      'MATCH with a unicode61 prefix query returns the seeded row',
      () async {
        final Database db = await _openInMemory();
        await createSaintsDatabase(db);

        await db.insert('saint_fts', <String, Object?>{
          'slug': 'abba-garima',
          'name': 'st abba garima',
          'patronages': 'monks missionaries',
          'bio': 'abba garima founded a monastery at enda garima',
          'prayer': 'o god who sent blessed garima',
        });

        final List<Map<String, Object?>> matches = await db.rawQuery(
          "SELECT slug FROM saint_fts WHERE saint_fts MATCH 'monk*'",
        );

        expect(
          <String>[
            for (final Map<String, Object?> row in matches)
              row['slug'] as String,
          ],
          contains('abba-garima'),
          reason:
              "fts4 + unicode61 must tokenize and 'monk*' must hit pre-"
              'normalized text',
        );

        await db.close();
      },
    );
  });
}
