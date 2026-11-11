#!/usr/bin/env dart

import 'dart:convert';
import 'dart:io';

import 'package:bible_data/src/utils/bible_structure_validator.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Validates the built `assets/bibles.db` against the pinned rebuild manifest
/// (`../sancta_via_bible_data/tools/build_bibles/expected_structure.json`).
///
/// Checks (every error is grep-able and prefixed with the translation id):
/// 1. Structure/content: all verse rows of all books of all translations are
///    checked against the manifest via `validateBibleStructure` (book set,
///    chapter sets, verse numbering including `verseNumbers` pins, empty
///    text, USFM backslash leak, reference-verse text prefixes).
/// 2. Row counts: per-translation `verses` rows must equal the manifest
///    verse totals (this also proves the UNIQUE constraint dropped nothing).
/// 3. Uniqueness: no duplicate `(translation_id, book_name, chapter_number,
///    verse_number)` rows.
/// 4. Book order: `books.book_order` must equal the manifest order index + 1.
/// 5. `books` summary counts must match the manifest (chapter_count and
///    verse_count for every book).
/// 6. `translations.verse_count` must equal the manifest totals.
///
/// Usage (from `sancta_via_bible_reading_app/`):
///   dart tools/validate_bible_db.dart
///
/// Returns 0 when the DB matches the manifest, 1 on any error.

// ignore: constant_identifier_names
const String _dbPath = 'assets/bibles.db';
// ignore: constant_identifier_names
const String _manifestPath =
    '../sancta_via_bible_data/tools/build_bibles/expected_structure.json';

Future<int> main() async {
  print('🔍 Validating Bible database against expected structure...');

  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  final List<String> errors = <String>[];
  try {
    // sqflite_common_ffi resolves *relative* paths against its own
    // CWD-relative databases directory (`.dart_tool/sqflite_common_ffi/databases/...`),
    // not against the CWD. The build tool produces its DB there, and this tool
    // must validate the literal `assets/bibles.db` the app ships — so an
    // absolute path is used here. Same applies to `tools/build_bible_database.dart`:
    // after building, copy the produced DB into `assets/bibles.db`.
    final Database database = await databaseFactoryFfi.openDatabase(
      File(_dbPath).absolute.path,
      options: OpenDatabaseOptions(readOnly: true),
    );
    try {
      final Map<String, dynamic> expectedStructure =
          jsonDecode(File(_manifestPath).readAsStringSync())
              as Map<String, dynamic>;
      final Map<String, dynamic> expectedTranslations =
          expectedStructure['translations'] as Map<String, dynamic>;

      errors.addAll(
        await _collectVersesStructure(database, expectedTranslations),
      );
      errors.addAll(
        await _collectVerseRowCounts(database, expectedTranslations),
      );
      errors.addAll(await _collectDuplicateVerses(database));
      errors.addAll(
        await _collectBookOrderChecks(database, expectedTranslations),
      );
      errors.addAll(
        await _collectBooksTableChecks(database, expectedTranslations),
      );
      errors.addAll(
        await _collectTranslationChecks(database, expectedTranslations),
      );

      _printResults(errors);
    } finally {
      await database.close();
    }
  } catch (e, stackTrace) {
    stderr.writeln('❌ validate_bible_db: FATAL $e');
    stderr.writeln(stackTrace);
    exitCode = 1;
    return 1;
  }
  exitCode = errors.isEmpty ? 0 : 1;
  return exitCode;
}

/// Reads all verse rows into `validateBibleStructure`'s translations map and
/// runs the structural/content checks.
Future<List<String>> _collectVersesStructure(
  Database database,
  Map<String, dynamic> expectedTranslations,
) async {
  final Map<String, Map<String, Map<int, Map<int, String>>>> translations =
      <String, Map<String, Map<int, Map<int, String>>>>{};
  final List<String> errors = <String>[];

  final List<Map<String, Object?>> rows = await database.rawQuery('''
    SELECT translation_id, book_name, chapter_number, verse_number, text
    FROM verses
  ''');
  for (final Map<String, Object?> row in rows) {
    final String translationId = row['translation_id'] as String;
    final String bookName = row['book_name'] as String;
    final Object? chapterObj = row['chapter_number'];
    final Object? verseObj = row['verse_number'];
    final Object? textObj = row['text'];
    if (chapterObj is! int || verseObj is! int || textObj is! String) {
      errors.add(
        '$translationId $bookName: malformed verse row '
        '(chapter=${chapterObj.runtimeType}, verse=${verseObj.runtimeType}, '
        'text=${textObj.runtimeType})',
      );
      continue;
    }
    final Map<String, Map<int, Map<int, String>>> books = translations
        .putIfAbsent(
          translationId,
          () => <String, Map<int, Map<int, String>>>{},
        );
    final Map<int, Map<int, String>> chapters = books.putIfAbsent(
      bookName,
      () => <int, Map<int, String>>{},
    );
    chapters.putIfAbsent(chapterObj, () => <int, String>{})[verseObj] = textObj;
  }

  print('   📖 Loaded ${rows.length} verse rows from the database');

  errors.addAll(
    validateBibleStructure(
      translations: translations,
      expectedStructure: <String, dynamic>{
        'translations': expectedTranslations,
      },
    ),
  );
  return errors;
}

/// Per-translation `verses` row counts must equal the manifest totals.
Future<List<String>> _collectVerseRowCounts(
  Database database,
  Map<String, dynamic> expectedTranslations,
) async {
  final List<Map<String, Object?>> rows = await database.rawQuery(
    'SELECT translation_id, COUNT(*) AS count FROM verses '
    'GROUP BY translation_id',
  );
  final Map<String, int> dbCounts = <String, int>{
    for (final Map<String, Object?> row in rows)
      row['translation_id'] as String: row['count'] as int,
  };

  final List<String> errors = <String>[];
  for (final MapEntry<String, dynamic> entry in expectedTranslations.entries) {
    final int manifestTotal = _manifestVerseTotal(entry.value);
    final int? dbCount = dbCounts[entry.key];
    if (dbCount == null) {
      errors.add('${entry.key}: DB has no verses rows');
    } else if (dbCount != manifestTotal) {
      errors.add(
        '${entry.key}: DB verses count $dbCount != manifest total '
        '$manifestTotal',
      );
    }
  }
  return errors;
}

/// Duplicate `(translation_id, book_name, chapter_number, verse_number)` rows
/// would violate the UNIQUE constraint; none may exist.
Future<List<String>> _collectDuplicateVerses(Database database) async {
  final List<Map<String, Object?>> rows = await database.rawQuery('''
    SELECT translation_id, book_name, chapter_number, verse_number, COUNT(*)
      AS count
    FROM verses
    GROUP BY translation_id, book_name, chapter_number, verse_number
    HAVING COUNT(*) > 1
  ''');
  return <String>[
    for (final Map<String, Object?> row in rows)
      '${row['translation_id']} ${row['book_name']} '
          '${row['chapter_number']}:${row['verse_number']}: '
          'duplicate verses rows (${row['count']})',
  ];
}

/// `books.book_order` must equal the manifest order index + 1 per translation.
Future<List<String>> _collectBookOrderChecks(
  Database database,
  Map<String, dynamic> expectedTranslations,
) async {
  final List<Map<String, Object?>> rows = await database.rawQuery(
    'SELECT translation_id, book_name, book_order FROM books',
  );
  final Map<String, Map<String, int>> dbOrders = <String, Map<String, int>>{};
  for (final Map<String, Object?> row in rows) {
    dbOrders.putIfAbsent(
      row['translation_id'] as String,
      () => <String, int>{},
    )[row['book_name'] as String] = row['book_order'] as int;
  }

  final List<String> errors = <String>[];
  for (final MapEntry<String, dynamic> entry in expectedTranslations.entries) {
    final String translationId = entry.key;
    final Map<String, dynamic> expected = entry.value as Map<String, dynamic>;
    final List<String> order = (expected['order'] as List<dynamic>)
        .cast<String>();
    final Map<String, int>? translationOrders = dbOrders[translationId];
    if (translationOrders == null) {
      errors.add('$translationId: DB books table has no rows');
      continue;
    }
    for (final MapEntry<String, int> bookOrder in translationOrders.entries) {
      final int index = order.indexOf(bookOrder.key);
      if (index < 0) {
        // The structural check reports the unexpected book; stay silent here.
        continue;
      }
      if (bookOrder.value != index + 1) {
        errors.add(
          '$translationId ${bookOrder.key}: DB book_order '
          '${bookOrder.value} != manifest order index + 1 (${index + 1})',
        );
      }
    }
  }
  return errors;
}

/// `books` summary counts must match the manifest per book.
Future<List<String>> _collectBooksTableChecks(
  Database database,
  Map<String, dynamic> expectedTranslations,
) async {
  final List<Map<String, Object?>> rows = await database.rawQuery(
    'SELECT translation_id, book_name, chapter_count, verse_count FROM books',
  );
  final Map<String, Map<String, Map<String, int>>> dbBooks =
      <String, Map<String, Map<String, int>>>{};
  for (final Map<String, Object?> row in rows) {
    dbBooks.putIfAbsent(
      row['translation_id'] as String,
      () => <String, Map<String, int>>{},
    )[row['book_name'] as String] = <String, int>{
      'chapter_count': row['chapter_count'] as int,
      'verse_count': row['verse_count'] as int,
    };
  }

  final List<String> errors = <String>[];
  for (final MapEntry<String, dynamic> entry in expectedTranslations.entries) {
    final String translationId = entry.key;
    final Map<String, dynamic> expected = entry.value as Map<String, dynamic>;
    final Map<String, dynamic> chapters =
        expected['chapters'] as Map<String, dynamic>;
    final Map<String, Map<String, int>>? books = dbBooks[translationId];
    if (books == null) {
      errors.add('$translationId: DB books table has no rows');
      continue;
    }

    final Set<String> manifestBooks = chapters.keys.toSet();
    for (final String book in manifestBooks.difference(books.keys.toSet())) {
      errors.add('$translationId $book: missing from DB books table');
    }
    for (final String book in books.keys.toSet().difference(manifestBooks)) {
      errors.add(
        '$translationId $book: unexpected book in DB books table '
        '(not in manifest order)',
      );
    }

    for (final String book in books.keys.toSet().intersection(manifestBooks)) {
      final Map<String, int> manifestCounts =
          (chapters[book] as Map<String, dynamic>).cast<String, int>();
      final int chapterCount = manifestCounts.length;
      final int verseCount = manifestCounts.values.reduce(
        (int a, int b) => a + b,
      );
      if (books[book]!['chapter_count'] != chapterCount) {
        errors.add(
          '$translationId $book: DB chapter_count '
          '${books[book]!['chapter_count']} != manifest $chapterCount',
        );
      }
      if (books[book]!['verse_count'] != verseCount) {
        errors.add(
          '$translationId $book: DB verse_count '
          '${books[book]!['verse_count']} != manifest $verseCount',
        );
      }
    }
  }
  return errors;
}

/// `translations` metadata must match the manifest totals per translation.
Future<List<String>> _collectTranslationChecks(
  Database database,
  Map<String, dynamic> expectedTranslations,
) async {
  final List<Map<String, Object?>> rows = await database.rawQuery(
    'SELECT id, book_count, verse_count FROM translations',
  );
  final Map<String, Map<String, Object?>> dbTranslations =
      <String, Map<String, Object?>>{
        for (final Map<String, Object?> row in rows) row['id'] as String: row,
      };

  final List<String> errors = <String>[];
  for (final MapEntry<String, dynamic> entry in expectedTranslations.entries) {
    final String translationId = entry.key;
    final Map<String, Object?>? dbRow = dbTranslations[translationId];
    if (dbRow == null) {
      errors.add('$translationId: missing from DB translations table');
      continue;
    }
    final Map<String, dynamic> expected = entry.value as Map<String, dynamic>;
    final int manifestTotal = _manifestVerseTotal(entry.value);
    final int bookCount = (expected['order'] as List<dynamic>).length;
    if (dbRow['verse_count'] != manifestTotal) {
      errors.add(
        '$translationId: translations.verse_count ${dbRow['verse_count']} '
        '!= manifest total $manifestTotal',
      );
    }
    if (dbRow['book_count'] != bookCount) {
      errors.add(
        '$translationId: translations.book_count ${dbRow['book_count']} '
        '!= manifest $bookCount books',
      );
    }
  }

  for (final String id in dbTranslations.keys) {
    if (!expectedTranslations.containsKey(id)) {
      errors.add('$id: unexpected translation in DB translations table');
    }
  }
  return errors;
}

/// Sums the manifest chapter verse counts for one translation entry.
int _manifestVerseTotal(Object? translationEntry) {
  final Map<String, dynamic> expected =
      translationEntry as Map<String, dynamic>;
  final Map<String, dynamic> chapters =
      expected['chapters'] as Map<String, dynamic>;
  int total = 0;
  for (final Map<String, dynamic> counts in chapters.values) {
    for (final int count in counts.values) {
      total += count;
    }
  }
  return total;
}

void _printResults(List<String> errors) {
  if (errors.isEmpty) {
    print('✅ Bible database matches the manifest');
    return;
  }
  print('❌ Bible database validation: ${errors.length} error(s):');
  for (final String error in errors) {
    print(error);
  }
}
