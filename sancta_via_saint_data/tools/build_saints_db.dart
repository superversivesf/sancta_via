// Build tool for `assets/saints.db` (Task 5 of the saint-companion plan).
//
// Validates `data/saints_source.json` against the Task 2 record rules,
// cross-checks counts against `data/manifest.json`, then builds
// `assets/saints.db` with the spec section 6 schema: the `saints`,
// `patronages`, and `need_synonyms` tables plus the FTS4 (unicode61)
// `saint_fts` search table, whose rows are pre-filled here with
// `normalizeSearchText` output so build-side and query-side share one
// normalization function.
//
// Dev-only: tools/ is never imported by runtime code.
//
// Usage (from the package root):
//   dart run tools/build_saints_db.dart
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:saint_data/src/db/saints_schema.dart';
import 'package:saint_data/src/models/saint.dart';
import 'package:saint_data/src/utils/normalization.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Slug rule: kebab-case, 1-100 chars (`a-z`, `0-9`, single `-` separators).
final RegExp _kebabPattern = RegExp(r'^[a-z0-9]+(-[a-z0-9]+)*$');

/// Feast-day rule: `MM-DD` with a real calendar date, or `unknown`.
///
/// February allows day 29: the spec keeps Feb 29 feasts reachable every year
/// (celebrated Feb 28 in non-leap years), so `02-29` is a valid feast value.
final RegExp _feastPattern = RegExp(r'^(\d{2})-(\d{2})$');
const List<int> _daysInMonth = <int>[
  31,
  29,
  31,
  30,
  31,
  30,
  31,
  31,
  30,
  31,
  30,
  31,
];

/// Image URL rule: an absolute http(s) URL.
final RegExp _httpUrlPattern = RegExp(r'^https?://\S+$');

/// True when [value] is `MM-DD` with a real calendar date or `unknown`.
bool _isValidFeastDay(String value) {
  if (value == 'unknown') {
    return true;
  }
  final RegExpMatch? match = _feastPattern.firstMatch(value);
  if (match == null) {
    return false;
  }
  final int month = int.parse(match.group(1)!);
  final int day = int.parse(match.group(2)!);
  return month >= 1 &&
      month <= 12 &&
      day >= 1 &&
      day <= _daysInMonth[month - 1];
}

Future<void> main() async {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  try {
    await _run();
  } on BuildSaintsDbException catch (error) {
    stderr.writeln('build_saints_db: $error');
    exitCode = 1;
  }
}

/// A validation or manifest cross-check failure that aborts the build.
class BuildSaintsDbException implements Exception {
  /// Human-readable description of what went wrong.
  final String message;

  /// Creates an exception with [message].
  BuildSaintsDbException(this.message);

  @override
  String toString() => message;
}

Future<void> _run() async {
  final String packageRoot = Directory.current.path;
  final Directory dataDir = Directory(p.join(packageRoot, 'data'));
  final File dbFile = File(p.join(packageRoot, 'assets', 'saints.db'));

  // Load committed inputs.
  final Map<String, Object?> manifest =
      _readJson(File(p.join(dataDir.path, 'manifest.json')))
          as Map<String, Object?>;
  final List<Map<String, Object?>> categories = <Map<String, Object?>>[
    for (final Object? item
        in _readJson(File(p.join(dataDir.path, 'categories.json')))
            as List<Object?>)
      item! as Map<String, Object?>,
  ];
  final Set<String> categoryIds = <String>{
    for (final Map<String, Object?> category in categories)
      category['id']! as String,
  };
  final List<Object?> synonymItems =
      _readJson(File(p.join(dataDir.path, 'needs_synonyms.json')))
          as List<Object?>;
  final List<Map<String, Object?>> synonyms = <Map<String, Object?>>[
    for (final Object? item in synonymItems) item! as Map<String, Object?>,
  ];
  final Map<String, Object?> saintsPayload =
      _readJson(File(p.join(dataDir.path, 'saints_source.json')))
          as Map<String, Object?>;
  final List<Object?> recordItems = saintsPayload['saints']! as List<Object?>;
  final List<Map<String, Object?>> records = <Map<String, Object?>>[
    for (final Object? item in recordItems) item! as Map<String, Object?>,
  ];

  // Validate every record; skip drafts.
  final List<String> violations = <String>[];
  final List<String> offendingSlugs = <String>[];
  final List<Map<String, Object?>> recordsToInsert = <Map<String, Object?>>[];
  final Set<String> seenSlugs = <String>{};
  for (final Map<String, Object?> record in records) {
    if (record['draft'] == true) {
      continue;
    }
    final List<String> recordViolations = _validateRecord(record, seenSlugs);
    if (recordViolations.isEmpty) {
      recordsToInsert.add(record);
    } else {
      violations.addAll(recordViolations);
      final Object? slug = record['slug'];
      offendingSlugs.add(
        slug is String && slug.isNotEmpty ? slug : '<no slug>',
      );
    }
  }
  if (violations.isNotEmpty) {
    for (final String violation in violations) {
      stderr.writeln(violation);
    }
    throw BuildSaintsDbException(
      'validation failed: ${violations.length} violations in '
      '${offendingSlugs.toSet().length} records; offending slugs: '
      '${(offendingSlugs.toSet().toList()..sort())}',
    );
  }

  // Parse once with the Task 2 model: downstream inserts and counts all use
  // the same runtime shapes.
  final List<Saint> saints = <Saint>[
    for (final Map<String, Object?> record in recordsToInsert)
      Saint.fromSourceJson(record),
  ];

  // Cross-check the build against the committed manifest. Counts describe the
  // set the build actually inserts: draft records are the documented
  // exclusion mechanism and never reach the database.
  final int expectedSaintCount = manifest['saintCount']! as int;
  final List<String> manifestMismatches = <String>[];
  if (expectedSaintCount != saints.length) {
    manifestMismatches.add(
      'saintCount: manifest $expectedSaintCount vs inserted '
      '${saints.length} saints (${records.length} records, '
      '${records.length - saints.length} drafts skipped)',
    );
  }
  final Map<String, int> computedCategoryCounts = <String, int>{
    for (final String id in categoryIds) id: 0,
  };
  for (final Saint saint in saints) {
    for (final SaintPatronage patronage in saint.patronages) {
      computedCategoryCounts[patronage.category.name] =
          computedCategoryCounts[patronage.category.name]! + 1;
    }
  }
  final Map<String, Object?> expectedCategoryCounts =
      manifest['categoryCounts']! as Map<String, Object?>;
  for (final MapEntry<String, int> entry in computedCategoryCounts.entries) {
    final Object? expectedCount = expectedCategoryCounts[entry.key];
    if (expectedCount != entry.value) {
      manifestMismatches.add(
        'categoryCounts[${entry.key}]: manifest $expectedCount vs computed '
        '${entry.value}',
      );
    }
  }
  if (manifestMismatches.isNotEmpty) {
    for (final String mismatch in manifestMismatches) {
      stderr.writeln('MISMATCH $mismatch');
    }
    throw BuildSaintsDbException(
      'manifest cross-check failed: ${manifestMismatches.length} mismatches',
    );
  }

  // Build the database from scratch.
  if (dbFile.existsSync()) {
    dbFile.deleteSync();
  }
  final Directory assetsDir = Directory(p.join(packageRoot, 'assets'));
  if (!assetsDir.existsSync()) {
    assetsDir.createSync(recursive: true);
  }
  final Database db = await openDatabase(dbFile.path);
  try {
    await createSaintsDatabase(db);

    await db.transaction((Transaction txn) async {
      final Batch batch = txn.batch();
      for (final Saint saint in saints) {
        batch.insert('saints', <String, Object?>{
          'slug': saint.slug,
          'name': saint.name,
          'feast_day': saint.feastDay,
          'canonized': saint.canonized,
          'bio': saint.bio,
          'prayer_text': saint.prayer?.text,
          'prayer_source': saint.prayer?.source,
          'featured': saint.featured ? 1 : 0,
          'thumb_asset': saint.thumbAsset,
          'image_attribution': saint.imageAttribution,
          'image_alt': saint.imageAlt,
        });
        for (final SaintPatronage patronage in saint.patronages) {
          batch.insert('patronages', <String, Object?>{
            'slug': saint.slug,
            'need': patronage.need,
            'category': patronage.category.name,
          });
        }
        // FTS rows carry pre-normalized text only: build-side and query-side
        // both run `normalizeSearchText`, so diacritics and punctuation never
        // reach the unicode61 tokenizer.
        final String patronageText = saint.patronages
            .map(
              (SaintPatronage patronage) => normalizeSearchText(patronage.need),
            )
            .join(' ');
        batch.insert('saint_fts', <String, Object?>{
          'slug': saint.slug,
          'name': normalizeSearchText(saint.name),
          'patronages': patronageText,
          'bio': normalizeSearchText(saint.bio),
          'prayer': saint.prayer == null
              ? ''
              : normalizeSearchText(saint.prayer!.text),
        });
      }
      for (final Map<String, Object?> entry in synonyms) {
        final String need = entry['need']! as String;
        for (final Object? synonym in entry['synonyms']! as List<Object?>) {
          batch.insert('need_synonyms', <String, Object?>{
            'need': need,
            'synonym': synonym! as String,
          });
        }
      }
      await batch.commit(noResult: true);
    });
    await db.execute('VACUUM');
    await db.close();

    // Summary + warnings.
    final int draftsSkipped = records.length - recordsToInsert.length;
    final Set<String> patronageNeeds = <String>{
      for (final Saint saint in saints)
        for (final SaintPatronage patronage in saint.patronages) patronage.need,
    };
    final List<String> missingSynonymNeeds = <String>[
      for (final Map<String, Object?> entry in synonyms)
        if (!patronageNeeds.contains(entry['need'] as String))
          entry['need'] as String,
    ];
    if (missingSynonymNeeds.isNotEmpty) {
      for (final String need in missingSynonymNeeds) {
        stdout.writeln(
          'WARNING need_synonyms need not present in any patronage: $need',
        );
      }
    }
    final int synonymRows = synonyms.fold<int>(
      0,
      (int sum, Map<String, Object?> entry) =>
          sum + (entry['synonyms']! as List<Object?>).length,
    );
    final int featured = saints.where((Saint saint) => saint.featured).length;
    final int sizeBytes = dbFile.lengthSync();
    print('build_saints_db summary');
    print('  records: ${records.length} (drafts skipped: $draftsSkipped)');
    print(
      '  manifest cross-check: saintCount $expectedSaintCount == '
      '${saints.length} inserted (drafts skipped: $draftsSkipped); '
      'categoryCounts all match',
    );
    print('  saints rows: ${saints.length}');
    print(
      '  patronages rows: '
      '${computedCategoryCounts.values.fold(0, (int a, int b) => a + b)}',
    );
    print('  need_synonyms: ${synonyms.length} entries -> $synonymRows rows');
    print('  saint_fts rows: ${saints.length}');
    print('  featured: $featured (expected 6)');
    print(
      '  schema statements: ${saintsSchemaStatements.length}; '
      'user_version $saintsSchemaVersion',
    );
    print(
      '  db: ${dbFile.path} ($sizeBytes bytes, '
      '${(sizeBytes / 1024 / 1024).toStringAsFixed(2)} MB)',
    );
  } on Object {
    try {
      await db.close();
    } on Object {
      // Closing a failed database is best-effort.
    }
    rethrow;
  }
}

/// Reads and decodes a JSON file, with the file path in any decode error.
Object? _readJson(File file) {
  final String content = file.readAsStringSync();
  try {
    return jsonDecode(content) as Object?;
  } on FormatException catch (error) {
    throw BuildSaintsDbException('${file.path} is not valid JSON: $error');
  }
}

/// Runs the Task 2 record checks against one raw record.
///
/// Returns one violation line per failed check, each prefixed with the
/// record's slug (or `<no slug>` when the slug itself is unreadable).
List<String> _validateRecord(
  Map<String, Object?> record,
  Set<String> seenSlugs,
) {
  final List<String> violations = <String>[];
  final Object? rawSlug = record['slug'];
  final String slug = rawSlug is String ? rawSlug : '<no slug>';
  void add(String detail) => violations.add('  $slug: $detail');

  // Task 2 model parse: record shape, known categories, prayer fields.
  try {
    final Saint saint = Saint.fromSourceJson(record);

    if (slug.isEmpty || slug.length > 100) {
      add('slug length ${slug.length} outside 1..100');
    } else if (!_kebabPattern.hasMatch(slug)) {
      add('slug is not kebab-case: $slug');
    }
    if (seenSlugs.contains(slug)) {
      add('duplicate slug');
    }
    seenSlugs.add(slug);

    final String name = saint.name;
    if (name.isEmpty || name.length > 200) {
      add('name length ${name.length} outside 1..200');
    }

    if (!_isValidFeastDay(saint.feastDay)) {
      add(
        "feastDay ${saint.feastDay} is neither a valid MM-DD date nor "
        "'unknown'",
      );
    }

    if (saint.bio.length < 10 || saint.bio.length > 10000) {
      add('bio length ${saint.bio.length} outside 10..10000');
    }

    if (saint.patronages.isEmpty) {
      add('record has no patronages');
    }
    for (final SaintPatronage patronage in saint.patronages) {
      if (patronage.need.trim().isEmpty) {
        add('patronage need empty');
        continue;
      }
      if (patronage.need != patronage.need.toLowerCase()) {
        add('patronage need not lowercase: ${patronage.need}');
      }
      final int words = patronage.need.trim().split(' ').length;
      if (words > 4) {
        add('patronage need more than 4 words: ${patronage.need}');
      }
    }

    final SaintPrayer? prayer = saint.prayer;
    if (prayer != null) {
      if (prayer.text.length > 2000) {
        add('prayer text length ${prayer.text.length} > 2000');
      }
      if (!prayer.isValid) {
        add(
          'prayer invalid: empty text or source ${prayer.source} not '
          'traditional/original',
        );
      }
    }
  } on Object catch (error) {
    add('Saint.fromSourceJson failed: $error');
    return violations;
  }

  // Image checks run on the raw record: build decisions (bundling a thumb in
  // Task 6) need the URL; only attribution/alt text survive into the DB.
  final Object? image = record['image'];
  if (image is Map && image.isNotEmpty) {
    final Object? url = image['url'];
    if (url is! String || !_httpUrlPattern.hasMatch(url)) {
      add('image url missing or not a valid http(s) URL: $url');
    }
    final Object? attribution = image['attribution'];
    if (attribution is! String || attribution.trim().isEmpty) {
      add('image attribution empty or missing');
    }
    final Object? altText = image['altText'];
    if (altText != null && altText is! String) {
      add('image altText is not a string');
    }
  }

  return violations;
}
