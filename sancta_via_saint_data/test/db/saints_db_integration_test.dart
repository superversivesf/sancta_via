// Integration test for the committed `assets/saints.db` build output.
//
// Opens the database read-only (this is the artifact that ships with the app)
// and pins the manifest-linked counts, the spec DDL shape, feast-day values,
// category integrity, FTS4/unicode61 behavior, the featured set, and the
// synonym table.
//
// Run from the package root (`flutter test`) — `Directory.current` is the
// package root there, so the absolute db path resolves as the plan requires.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:saint_data/src/db/saints_schema.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// The 10 committed category ids from data/categories.json.
late Set<String> categoryIds;

/// The committed manifest's saintCount.
late int manifestSaintCount;

/// The committed manifest's total patronage count
/// (sum of categoryCounts).
late int manifestPatronageCount;

/// The number of {need, synonyms} entries committed from
/// data/needs_synonyms.json (Task 4 verified: 183).
const int expectedSynonymNeedCount = 183;

Future<Database> _openDb = Future<Database>.error(
  StateError('db opened by setUpAll'),
);
bool _dbOpened = false;

void main() {
  setUpAll(() async {
    sqfliteFfiInit();

    final Map<String, Object?> manifest =
        jsonDecode(
              File(
                '${Directory.current.path}/data/manifest.json',
              ).readAsStringSync(),
            )
            as Map<String, Object?>;
    manifestSaintCount = manifest['saintCount']! as int;
    manifestPatronageCount =
        (manifest['categoryCounts']! as Map<String, Object?>).values
            .cast<int>()
            .fold(0, (int sum, int count) => sum + count);
    final List<Object?> categoryList =
        jsonDecode(
              File(
                '${Directory.current.path}/data/categories.json',
              ).readAsStringSync(),
            )
            as List<Object?>;
    categoryIds = <String>{
      for (final Object? category in categoryList)
        (category! as Map<String, Object?>)['id']! as String,
    };

    _openDb = databaseFactoryFfi.openDatabase(
      '${Directory.current.path}/assets/saints.db',
      // singleInstance false: keep this test isolated from any other open of
      // the same file in the test VM.
      options: OpenDatabaseOptions(readOnly: true, singleInstance: false),
    );
    _dbOpened = true;
  });

  tearDownAll(() async {
    if (_dbOpened) {
      await (await _openDb).close();
    }
  });

  group('committed assets/saints.db', () {
    test('stamps PRAGMA user_version = 2', () async {
      final Database db = await _openDb;
      final List<Map<String, Object?>> version = await db.rawQuery(
        'PRAGMA user_version',
      );
      expect(version.single['user_version'], saintsSchemaVersion);
      // Downgrade-loud: the committed asset pins schema v2 (saint histories);
      // a constant knocked back to 1 fails here immediately.
      expect(saintsSchemaVersion, 2);
    });

    test(
      'carries the v2 history columns and a populated sources table',
      () async {
        final Database db = await _openDb;
        final List<Map<String, Object?>> columns = await db.rawQuery(
          'PRAGMA table_info(saints)',
        );
        expect(<String>[
          for (final Map<String, Object?> c in columns) c['name'] as String,
        ], containsAll(<String>['history', 'history_source']));
        final List<Map<String, Object?>> sourcesTables = await db.rawQuery(
          "SELECT COUNT(*) AS n FROM sqlite_master WHERE name = 'sources'",
        );
        expect(sourcesTables.single['n'], 1);
      },
    );

    test('holds one history per accepted histories entry', () async {
      final Database db = await _openDb;
      final Map<String, Object?> histories =
          jsonDecode(
                File(
                  '${Directory.current.path}/data/histories.json',
                ).readAsStringSync(),
              )
              as Map<String, Object?>;
      expect(histories, isNotEmpty);

      final List<Map<String, Object?>> counts = await db.rawQuery(
        'SELECT COUNT(*) AS n FROM saints WHERE history IS NOT NULL',
      );
      expect(
        counts.single['n'] as int,
        histories.length,
        reason:
            'every accepted histories entry merges into the committed db '
            '(Task 4 accepted ${histories.length} entries)',
      );
      final List<Map<String, Object?>> francis = await db.rawQuery(
        "SELECT history, history_source FROM saints WHERE slug = 'francis-of-assisi'",
      );
      expect(francis.single['history'], isNotNull);
      expect(
        RegExp(
          r'^catholic-encyclopedia-1907 '
          r'https?://www\.newadvent\.org/cathen/\S+$',
        ).hasMatch(francis.single['history_source']! as String),
        isTrue,
      );
    });

    test('holds one sources row per seed source, in position order', () async {
      final Database db = await _openDb;
      final Map<String, Object?> payload =
          jsonDecode(
                File(
                  '${Directory.current.path}/data/saints_source.json',
                ).readAsStringSync(),
              )
              as Map<String, Object?>;
      final Map<String, List<String>> expected = <String, List<String>>{};
      for (final Object? item in payload['saints']! as List<Object?>) {
        final Map<String, Object?> record = item! as Map<String, Object?>;
        expected[record['slug']! as String] = <String>[
          for (final Object? url
              in record['sources'] as List<Object?>? ?? const <Object?>[])
            url! as String,
        ];
      }

      final List<Map<String, Object?>> rows = await db.rawQuery(
        'SELECT slug, url, position FROM sources ORDER BY slug, position',
      );
      // Recompute per-slug ordered lists from the db rows.
      final Map<String, List<String>> actual = <String, List<String>>{};
      int? lastPosition;
      String lastSlug = '';
      for (final Map<String, Object?> row in rows) {
        final String slug = row['slug']! as String;
        final int position = row['position']! as int;
        if (slug == lastSlug) {
          expect(
            position,
            lastPosition! + 1,
            reason: 'positions are dense per slug',
          );
        } else {
          expect(position, 0, reason: 'each slug restarts at position 0');
        }
        lastSlug = slug;
        lastPosition = position;
        actual.putIfAbsent(slug, () => <String>[]).add(row['url']! as String);
      }
      expect(actual, expected);
    });

    test('has one saints row per committed manifest saintCount', () async {
      final Database db = await _openDb;
      final List<Map<String, Object?>> counts = await db.rawQuery(
        'SELECT COUNT(*) AS n FROM saints',
      );
      expect(
        counts.single['n'] as int,
        manifestSaintCount,
        reason: 'saints rows must equal manifest saintCount',
      );
      // The Task 4 manifest pinned 2174 saints; Task 7 curation grew the
      // snapshot to 2180 (6 curated moderns, partner-approved 2026-11-16).
      expect(manifestSaintCount, 2180);
    });

    test('has every manifest patronage row across the 10 categories', () async {
      final Database db = await _openDb;
      final List<Map<String, Object?>> counts = await db.rawQuery(
        'SELECT COUNT(*) AS n FROM patronages',
      );
      final int total = counts.single['n'] as int;
      expect(
        total,
        manifestPatronageCount,
        reason: 'patronages rows must equal the manifest categoryCounts sum',
      );
      // The plan estimated "> 8000", but the committed (sha-pinned) manifest
      // says the verified total is below; the manifest is the authority.
      expect(manifestPatronageCount, 4854);

      final List<Map<String, Object?>> categories = await db.rawQuery(
        'SELECT DISTINCT category FROM patronages ORDER BY category',
      );
      final Set<String> used = <String>{
        for (final Map<String, Object?> row in categories)
          row['category']! as String,
      };
      expect(
        used.difference(categoryIds),
        isEmpty,
        reason: 'every patronages.category must be one of the 10 ids',
      );
    });

    test('stores only MM-DD feast days or unknown', () async {
      final Database db = await _openDb;
      final List<Map<String, Object?>> rows = await db.rawQuery(
        'SELECT DISTINCT feast_day FROM saints',
      );
      final RegExp pattern = RegExp(r'^(?:\d{2}-\d{2}|unknown)$');
      for (final Map<String, Object?> row in rows) {
        expect(
          pattern.hasMatch(row['feast_day']! as String),
          isTrue,
          reason: "feast_day ${row['feast_day']} must be 'MM-DD' or 'unknown'",
        );
      }
      expect(rows, isNotEmpty);
    });

    test(
      "FTS MATCH 'therese*' finds at least one saint via unicode61",
      () async {
        final Database db = await _openDb;
        final List<Map<String, Object?>> matches = await db.rawQuery(
          "SELECT slug FROM saint_fts WHERE saint_fts MATCH 'therese*'",
        );
        final List<String> slugs = <String>[
          for (final Map<String, Object?> row in matches)
            row['slug']! as String,
        ];
        expect(
          slugs,
          isNotEmpty,
          reason:
              'St. Therese of Lisieux must be found: the unicode61 prefix '
              "query 'therese*' matches the normalized 'Thérèse' name token",
        );
        expect(slugs, contains('therese-of-lisieux'));
      },
    );

    test('featured set is populated (expected 6, asserted >= 1)', () async {
      final Database db = await _openDb;
      final List<Map<String, Object?>> counts = await db.rawQuery(
        'SELECT COUNT(*) AS n FROM saints WHERE featured = 1',
      );
      final int featured = counts.single['n'] as int;
      // The plan rules the featured assertion soft: data-dependent.
      expect(
        featured,
        greaterThanOrEqualTo(1),
        reason: 'featured must be populated for the home screen',
      );
      // The committed dataset carries exactly 6 featured saints; print for
      // the report (not asserted hard).
      print('featured saints in db: $featured (expected 6 per plan)');
    });

    test('need_synonyms holds the 183 committed entries', () async {
      final Database db = await _openDb;
      final List<Map<String, Object?>> distinctNeeds = await db.rawQuery(
        'SELECT COUNT(DISTINCT need) AS n FROM need_synonyms',
      );
      final List<Map<String, Object?>> totalRows = await db.rawQuery(
        'SELECT COUNT(*) AS n FROM need_synonyms',
      );
      expect(
        distinctNeeds.single['n'] as int,
        expectedSynonymNeedCount,
        reason: 'the 183 synonym entries map to distinct needs (Task 4)',
      );
      expect(
        totalRows.single['n'] as int,
        1700,
        reason: '183 {need, synonyms} entries expand to 1700 rows',
      );
    });
  });
}
