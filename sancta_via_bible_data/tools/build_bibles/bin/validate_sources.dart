#!/usr/bin/env dart

/// Source-snapshot structure emitter for the bible rebuild pipeline.
///
/// Reads the Task 1 snapshots from `assets/sources/` and the sibling
/// `tools/build_bibles/book_names.json` vocabulary, then:
/// - validates that every source book key resolves to exactly the 73-book
///   canonical DB vocabulary, and vice versa (per-source bijection);
/// - counts REAL verses per chapter for each translation with the shared
///   USFM parser (`../lib/usfm_parser.dart`, also used by `build_json.dart`):
///   note-only verse markers (footnote/cross-ref bodies only, including
///   composite labels such as `\v 15-16`) produce no verse, and header lines
///   (`\d`/`\s\d` acrostics, section titles) never append to verse text.
///   engwebc and drc are both USFM zips keyed by their own `\id` codes
///   (engwebc: `ESG`/`DAG` for Esther/Daniel; drc: `EST`/`DAN`);
///   CPDV is a `{book: {chapter: {verse: text}}}` JSON snapshot (the
///   `charset` metadata key and the non-numeric `P` prologue chapters are
///   skipped — skip rules, not dropped verses);
/// - verifies that drc and CPDV are gap-free: EVERY chapter of those two
///   translations must have verse keys exactly 1..N. Any gap in them is a
///   hard stop ([exit 1], `[needs-context]` evidence lines): a
///   `verseNumbers` exception entry must never be forced for them;
/// - emits an OPTIONAL per-translation `verseNumbers` map (decimal-string
///   chapter -> exact ascending verse numbers) for the engwebc chapters whose
///   real verse keys are NOT 1..N (footnote-only verse markers); chapters not
///   listed remain strictly contiguous. This re-emit is the single source of
///   truth for the manifest;
/// - verifies the reference verses pinned in this file against the snapshot
///   text (verse text is reconstructed with the same marker stripping the
///   shared parser applies); any mismatch fails the run;
/// - cross-checks the CPDV counts against the `CPDV-books.json`
///   `chapter_verses` metadata;
/// - prints a human-readable per-book summary and emits the exact
///   `expected_structure.json` content between BEGIN/END markers for pasting
///   into `tools/build_bibles/expected_structure.json`.
///
/// Known-edition divergences between the plan-stage pins and the snapshots
/// (see the Task 2 report) are printed as `[info]` lines; they do not change
/// the emitted manifest, which always records the snapshot-verbatim text.
///
/// Usage (from `sancta_via_bible_data/`):
/// ```
/// dart tools/build_bibles/bin/validate_sources.dart
/// ```

import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';

import '../lib/usfm_parser.dart';

const String _bookNamesRelativePath = 'tools/build_bibles/book_names.json';
const String _sourcesRelativeDir = 'assets/sources';
const String _usfmZipName = 'engwebc_usfm.zip';
const String _usfmFrontMatterCode = 'FRT';
const int _expectedBookCount = 73;
const String _cpdvJsonName = 'EntireBible-CPDV.json';
const String _cpdvMetadataKey = 'charset';
const String _cpdvBooksMetaName = 'CPDV-books.json';
const String _drcUsfmZipName = 'drc_usfm.zip';

/// Canonical translation ids used as `expected_structure.json` keys.
const List<String> _translationIds = <String>['engwebc', 'cpdv', 'drc'];

/// A reference verse pinned against one snapshot: [sourceKey] names the
/// snapshot book (USFM code or JSON key), [dbName] the canonical DB name, and
/// [startsWith] the verified snapshot prefix recorded in
/// `expected_structure.json`.
final class _Pin {
  const _Pin(
    this.translation,
    this.sourceKey,
    this.dbName,
    this.chapter,
    this.verse,
    this.startsWith,
  );

  final String translation;
  final String sourceKey;
  final String dbName;
  final int chapter;
  final int verse;
  final String startsWith;
}

/// Reference verses, recorded from the committed snapshots after verification
/// (25-40 character prefixes).
const List<_Pin> _pins = <_Pin>[
  _Pin('engwebc', 'PSA', 'Psalms', 18, 16, 'He sent from on high. He took me.'),
  _Pin(
    'engwebc',
    'PSA',
    'Psalms',
    19,
    11,
    'Moreover your servant is warned by them.',
  ),
  _Pin('engwebc', 'PSA', 'Psalms', 119, 8, 'I will observe your statutes.'),
  _Pin(
    'engwebc',
    'MAT',
    'Matthew',
    6,
    33,
    'But seek first God’s Kingdom and his',
  ),
  _Pin('engwebc', 'ESG', 'Esther', 4, 1, 'But Mordecai, having perceived what'),
  _Pin('cpdv', 'Psalms', 'Psalms', 18, 1, 'Unto the end. A Psalm of David.'),
  _Pin('cpdv', 'Psalms', 'Psalms', 119, 7, 'With those who hated peace, I was'),
  _Pin('cpdv', 'Acts', 'Acts', 20, 7, 'Then, on the first Sabbath, when we'),
  _Pin('drc', 'GEN', 'Genesis', 1, 1, 'In the beginning God created heaven'),
  _Pin('drc', 'SIR', 'Sirach', 1, 1, 'All wisdom is from the Lord God, and'),
  _Pin(
    'drc',
    'REV',
    'Revelation of John',
    22,
    21,
    'The grace of our Lord Jesus Christ be',
  ),
];

/// Plan-stage pin wording for the two verses where the plan was drafted from a
/// different upstream edition than the committed snapshot; informational only.
const Map<String, String> _planPinWording = <String, String>{
  'engwebc Psalms 19:11': 'Moreover by them',
  'cpdv Acts 20:7': 'On the first day of the week',
};

void main() {
  final Directory packageRoot = _packageRoot();
  final Directory sourcesDir = Directory(
    '${packageRoot.path}/$_sourcesRelativeDir',
  );

  final Map<String, dynamic> bookNamesRaw = _loadJsonObject(
    File('${packageRoot.path}/$_bookNamesRelativePath'),
    'book_names.json must be a JSON object',
  );
  final Map<String, (String, int)> keyToBook = _validateBookNames(bookNamesRaw);
  final List<String> canonicalOrder = _canonicalOrder(keyToBook);

  // Parsed USFM books: code -> chapter -> verse -> text (REAL verses only;
  // note-only markers are absent by construction of the shared parser).
  final Map<String, Map<int, Map<int, String>>> engwebcParsed =
      <String, Map<int, Map<int, String>>>{};
  _parseUsfmZip('${sourcesDir.path}/$_usfmZipName', keyToBook, engwebcParsed);

  final Map<String, Map<int, Map<int, String>>> drcParsed =
      <String, Map<int, Map<int, String>>>{};
  _parseUsfmZip('${sourcesDir.path}/$_drcUsfmZipName', keyToBook, drcParsed);

  final Map<String, Map<String, dynamic>> cpdvRoot = _parseChapterVerseJson(
    '${sourcesDir.path}/$_cpdvJsonName',
    keyToBook,
    skipTopLevelKey: _cpdvMetadataKey,
  );

  // Real-verse counts per translation, re-keyed onto canonical db books.
  final Map<String, Map<String, Map<int, int>>> perTranslation =
      <String, Map<String, Map<int, int>>>{
        'engwebc': _countsByDbBook(
          _realCounts(engwebcParsed),
          keyToBook,
          canonicalOrder,
          'engwebc',
        ),
        'cpdv': _countsByDbBook(
          _cpdvCounts(cpdvRoot),
          keyToBook,
          canonicalOrder,
          'cpdv',
        ),
        'drc': _countsByDbBook(
          _realCounts(drcParsed),
          keyToBook,
          canonicalOrder,
          'drc',
        ),
      };

  _printCounts(perTranslation, canonicalOrder);
  _crossCheckCpdvMetadata(
    '${sourcesDir.path}/$_cpdvBooksMetaName',
    keyToBook,
    perTranslation['cpdv']!,
  );

  // Optional verseNumbers exception maps per translation (gap chapters only).
  final Map<String, Map<String, Map<String, List<int>>>> verseNumbers =
      <String, Map<String, Map<String, List<int>>>>{
        'engwebc': _verseNumbers(engwebcParsed, keyToBook, canonicalOrder),
        'cpdv': _verseNumbersFromKeyedMap(cpdvRoot, canonicalOrder),
        'drc': _verseNumbers(drcParsed, keyToBook, canonicalOrder),
      };

  // Hard stop: drc and CPDV must be gap-free. Never force verseNumbers onto
  // them; a gap there means the pinned expectations are wrong (report
  // NEEDS_CONTEXT with evidence instead).
  final List<String> needsContext = <String>[];
  for (final String id in const <String>['cpdv', 'drc']) {
    if (verseNumbers[id]!.isEmpty) {
      continue;
    }
    final Map<String, Map<int, int>> books = perTranslation[id]!;
    final List<String> orderedBooks = canonicalOrder
        .where((String book) => verseNumbers[id]!.containsKey(book))
        .toList();
    needsContext.add(id);
    stderr.writeln(
      '[needs-context] $id has gap chapters; expected_structure must stay '
      'gap-free for $id rather than forcing verseNumbers lists:',
    );
    for (final String book in orderedBooks) {
      for (final String chapter in verseNumbers[id]![book]!.keys) {
        stderr.writeln(
          '[needs-context]   $id $book $chapter: real verse keys '
          '${verseNumbers[id]![book]![chapter]} (manifest counts '
          '${books[book]?[int.parse(chapter)]})',
        );
      }
    }
  }
  if (needsContext.isNotEmpty) {
    stderr.writeln(
      '[needs-context] STOP: report NEEDS_CONTEXT instead of building '
      '(${needsContext.join(', ')} are not gap-free)',
    );
    exitCode = 1;
    return;
  }

  final List<String> failures = _verifyReferenceVerses(
    parsedUsfms: <String, Map<String, Map<int, Map<int, String>>>>{
      'engwebc': engwebcParsed,
      'drc': drcParsed,
    },
    snapshotRoots: <String, Map<String, Map<String, dynamic>>>{
      'cpdv': cpdvRoot,
    },
  );

  if (failures.isNotEmpty) {
    stderr.writeln('[fail]     reference-verse verification failures:');
    for (final String failure in failures.take(20)) {
      stderr.writeln('  $failure');
    }
    stderr.writeln(
      '           Fix the adapter/parser — never the manifest by hand.',
    );
    exitCode = 1;
  }

  stdout.writeln('--- BEGIN expected_structure.json ---');
  stdout.writeln(_manifestJson(perTranslation, canonicalOrder, verseNumbers));
  stdout.writeln('--- END expected_structure.json ---');
}

/// Loads `book_names.json`, validates the pinned shape
/// `{"<source-key>": {"dbName": string, "order": int}}`, and rejects any entry
/// whose shape is wrong.
Map<String, (String, int)> _validateBookNames(Map<String, dynamic> raw) {
  final Map<String, (String, int)> result = <String, (String, int)>{};
  for (final MapEntry<String, dynamic> entry in raw.entries) {
    final String sourceKey = entry.key;
    final Object? value = entry.value;
    if (value is! Map<String, dynamic>) {
      stderr.writeln(
        '[fail]     book_names.json["$sourceKey"] entry is not an object',
      );
      exit(1);
    }
    final String dbName = value['dbName'] as String? ?? '';
    final Object? orderRaw = value['order'];
    final int? order = orderRaw is int ? orderRaw : int.tryParse('$orderRaw');
    if (dbName.isEmpty || order == null || order < 1) {
      stderr.writeln(
        '[fail]     book_names.json["$sourceKey"] must be {dbName, order}',
      );
      exit(1);
    }
    if (result.containsKey(sourceKey)) {
      stderr.writeln('[fail]     book_names.json duplicate key "$sourceKey"');
      exit(1);
    }
    result[sourceKey] = (dbName, order);
  }
  return result;
}

/// Returns the canonical db book order, requiring orders 1..73 contiguous.
List<String> _canonicalOrder(Map<String, (String, int)> keyToBook) {
  final Map<String, int> byDbName = <String, int>{};
  keyToBook.forEach((String key, (String, int) value) {
    final (String dbName, int order) = value;
    final int? existing = byDbName[dbName];
    if (existing != null && existing != order) {
      stderr.writeln(
        '[fail]     db book "$dbName" has conflicting orders $existing/$order',
      );
      exit(1);
    }
    byDbName[dbName] = order;
  });
  if (byDbName.length != _expectedBookCount) {
    stderr.writeln(
      '[fail]     vocabulary must contain $_expectedBookCount db books, '
      'got ${byDbName.length}',
    );
    exit(1);
  }
  final List<String> names = byDbName.keys.toList()
    ..sort((String a, String b) => byDbName[a]!.compareTo(byDbName[b]!));
  for (int i = 0; i < names.length; i++) {
    if (byDbName[names[i]] != i + 1) {
      stderr.writeln(
        '[fail]     db book orders must be 1..$_expectedBookCount contiguous; '
        '"${names[i]}" is ${byDbName[names[i]]!} at index $i',
      );
      exit(1);
    }
  }
  return names;
}

/// Reads the committed USFM snapshot zip in memory and, for every `.usfm`
/// entry whose `\id` code is a mapped book (front matter is skipped), parses
/// the book with the shared USFM parser into REAL verses
/// (code -> chapter -> verse -> text). Duplicate/composite markers with text
/// throw inside [parseUsfmBook]; entry context is added around the failure.
/// Non-integer raw verse labels are logged as informational composite
/// (note-only) markers.
void _parseUsfmZip(
  String zipPath,
  Map<String, (String, int)> keyToBook,
  Map<String, Map<int, Map<int, String>>> parsedByCode,
) {
  final List<int> bytes = File(zipPath).readAsBytesSync();
  final Archive archive = ZipDecoder().decodeBytes(bytes);
  int bookFiles = 0;
  final Set<String> dbBookNames = <String>{};
  for (final ArchiveFile entry in archive.files) {
    if (!entry.isFile || !entry.name.toLowerCase().endsWith('.usfm')) {
      continue;
    }
    final String baseName = entry.name.split('/').last;
    final String text = utf8.decode(entry.content as List<int>);
    final String code =
        RegExp(r'\\id\s+(\S+)').firstMatch(text)?.group(1) ?? '';
    if (code == _usfmFrontMatterCode) {
      continue;
    }
    if (!keyToBook.containsKey(code)) {
      stderr.writeln(
        '[fail]     ${entry.name}: book code "$code" is not mapped in book_names.json',
      );
      exit(1);
    }
    for (final RegExpMatch match in RegExp(r'\\v (\S+)').allMatches(text)) {
      final String label = match.group(1)!;
      if (int.tryParse(label) == null) {
        stdout.writeln(
          '[info]     $baseName: composite verse marker "$label" is note-only '
          '(no verse emitted for it)',
        );
      }
    }
    bookFiles += 1;
    dbBookNames.add(keyToBook[code]!.$1);
    final List<UsfmChapter> chapters;
    try {
      chapters = parseUsfmBook(text);
    } on FormatException catch (e) {
      stderr.writeln('[fail]     ${entry.name}: ${e.message}');
      exit(1);
    }
    final Map<int, Map<int, String>> chapterVerses = <int, Map<int, String>>{};
    for (final UsfmChapter chapter in chapters) {
      final Map<int, String> verses = <int, String>{
        for (final (int verse, String text) in chapter.verses) verse: text,
      };
      if (verses.length != chapter.verses.length) {
        // Impossible: duplicate verse numbers would have thrown inside the
        // parser; the map literal would otherwise silently collapse them.
        stderr.writeln(
          '[fail]     ${entry.name}: duplicate verse number collapsed in '
          'chapter ${chapter.number}',
        );
        exit(1);
      }
      chapterVerses[chapter.number] = verses;
    }
    parsedByCode[code] = chapterVerses;
  }
  if (bookFiles != _expectedBookCount ||
      dbBookNames.length != _expectedBookCount) {
    stderr.writeln(
      '[fail]     expected $_expectedBookCount mapped book files in the USFM '
      'zip, found $bookFiles files covering ${dbBookNames.length} db books',
    );
    exit(1);
  }
}

/// Parses a `{<bookKey>: {<chapter>: {<verse>: "text"}}}` snapshot into its
/// book maps. The optional top-level metadata key (CPDV `charset`) must be a
/// string and is skipped; non-numeric chapter keys (`P` prologues) are
/// skipped (skip rules, not dropped verses). Verse text must be a string.
/// Returns the parsed book maps.
Map<String, Map<String, dynamic>> _parseChapterVerseJson(
  String path,
  Map<String, (String, int)> keyToBook, {
  required String? skipTopLevelKey,
}) {
  final Map<String, dynamic> root = _loadJsonObject(
    File(path),
    'snapshot must be a JSON object',
  );
  final Map<String, Map<String, dynamic>> bookMaps =
      <String, Map<String, dynamic>>{};
  for (final MapEntry<String, dynamic> entry in root.entries) {
    final String bookKey = entry.key;
    final Object? value = entry.value;
    if (skipTopLevelKey != null && bookKey == skipTopLevelKey) {
      if (value is! String) {
        stderr.writeln(
          '[fail]     $path metadata key "$bookKey" is not a string',
        );
        exit(1);
      }
      continue;
    }
    if (!keyToBook.containsKey(bookKey)) {
      stderr.writeln(
        '[fail]     $path book key "$bookKey" is not mapped in book_names.json',
      );
      exit(1);
    }
    if (value is! Map<String, dynamic>) {
      stderr.writeln('[fail]     $path book "$bookKey" is not an object');
      exit(1);
    }
    for (final MapEntry<String, dynamic> chapterEntry in value.entries) {
      if (int.tryParse(chapterEntry.key) == null) {
        stdout.writeln(
          '[skipped]  $path $bookKey: prologue chapter "${chapterEntry.key}"',
        );
      }
      if (chapterEntry.value is! Map<String, dynamic>) {
        stderr.writeln(
          '[fail]     $path $bookKey chapter ${chapterEntry.key} is not an object',
        );
        exit(1);
      }
      for (final String verseKey in chapterEntry.value.keys) {
        if (chapterEntry.value[verseKey] is! String) {
          stderr.writeln(
            '[fail]     $path $bookKey chapter ${chapterEntry.key} '
            'verse "$verseKey" text is not a string',
          );
          exit(1);
        }
      }
    }
    bookMaps[bookKey] = value;
  }
  return bookMaps;
}

/// Real verse counts from a parsed USFM book map: chapter -> verse list size.
Map<String, Map<int, int>> _realCounts(
  Map<String, Map<int, Map<int, String>>> parsedByCode,
) {
  return <String, Map<int, int>>{
    for (final MapEntry<String, Map<int, Map<int, String>>> code
        in parsedByCode.entries)
      code.key: <int, int>{
        for (final MapEntry<int, Map<int, String>> chapter
            in code.value.entries)
          chapter.key: chapter.value.length,
      },
  };
}

/// Verse counts from the CPDV keyed snapshot: numeric chapter -> verse count.
Map<String, Map<int, int>> _cpdvCounts(Map<String, Map<String, dynamic>> root) {
  return <String, Map<int, int>>{
    for (final MapEntry<String, Map<String, dynamic>> book in root.entries)
      book.key: <int, int>{
        for (final MapEntry<String, dynamic> chapter in book.value.entries)
          if (int.tryParse(chapter.key) != null)
            int.parse(chapter.key): chapter.value.length,
      },
  };
}

/// Re-keys per-source counts onto canonical db book names and validates that
/// the source covers exactly the 73-book vocabulary.
Map<String, Map<int, int>> _countsByDbBook(
  Map<String, Map<int, int>> sourceCounts,
  Map<String, (String, int)> keyToBook,
  List<String> canonicalOrder,
  String translationId,
) {
  final Map<String, Map<int, int>> result = <String, Map<int, int>>{};
  for (final MapEntry<String, Map<int, int>> entry in sourceCounts.entries) {
    final String dbName = keyToBook[entry.key]!.$1;
    if (result.containsKey(dbName)) {
      stderr.writeln(
        '[fail]     $translationId: duplicate db book "$dbName" '
        'from key "${entry.key}"',
      );
      exit(1);
    }
    result[dbName] = entry.value;
  }
  if (result.length != canonicalOrder.length) {
    stderr.writeln(
      '[fail]     $translationId covers ${result.length} of expected '
      '${canonicalOrder.length} db books',
    );
    exit(1);
  }
  return result;
}

/// Builds the per-translation `verseNumbers` map (db book name ->
/// decimal-string chapter -> exact ascending verse numbers) for chapters
/// whose real verse keys are NOT exactly 1..N.
Map<String, Map<String, List<int>>> _verseNumbers(
  Map<String, Map<int, Map<int, String>>> parsedByCode,
  Map<String, (String, int)> keyToBook,
  List<String> canonicalOrder,
) {
  final Map<String, Map<String, List<int>>> result =
      <String, Map<String, List<int>>>{};
  for (final MapEntry<String, Map<int, Map<int, String>>> code
      in parsedByCode.entries) {
    final String dbBook = keyToBook[code.key]!.$1;
    final Map<String, List<int>> listed = <String, List<int>>{};
    for (final int chapter in code.value.keys.toList()..sort()) {
      final List<int> numbers = code.value[chapter]!.keys.toList()..sort();
      if (_isContiguousFromOne(numbers)) {
        continue;
      }
      listed['$chapter'] = numbers;
    }
    if (listed.isNotEmpty) {
      result[dbBook] = listed;
    }
  }
  // Canonical book order in the emitted JSON.
  return <String, Map<String, List<int>>>{
    for (final String book in canonicalOrder)
      if (result.containsKey(book)) book: result[book]!,
  };
}

/// `verseNumbers` from the CPDV keyed snapshot (numeric chapter keys only);
/// the exact ascending verse numbers come from the JSON keys themselves.
Map<String, Map<String, List<int>>> _verseNumbersFromKeyedMap(
  Map<String, Map<String, dynamic>> root,
  List<String> canonicalOrder,
) {
  final Map<String, Map<String, List<int>>> result =
      <String, Map<String, List<int>>>{};
  for (final String book in canonicalOrder) {
    final Map<String, dynamic>? chapters = root[book];
    if (chapters == null) {
      continue;
    }
    for (final MapEntry<String, dynamic> chapter in chapters.entries) {
      final Object? verseMap = chapter.value;
      if (verseMap is! Map<String, dynamic>) {
        continue;
      }
      final List<int> numbers =
          verseMap.keys.map(int.tryParse).whereType<int>().toList()..sort();
      if (!_isContiguousFromOne(numbers)) {
        (result[book] ??= <String, List<int>>{})[chapter.key] = numbers;
      }
    }
  }
  return result;
}

/// Prints the per-translation, per-book chapter/verse summary.
void _printCounts(
  Map<String, Map<String, Map<int, int>>> perTranslation,
  List<String> canonicalOrder,
) {
  for (final String id in _translationIds) {
    final Map<String, Map<int, int>> books = perTranslation[id]!;
    final int chapterCount = books.values.fold(
      0,
      (int n, Map<int, int> c) => n + c.length,
    );
    final int verseCount = books.values.fold(
      0,
      (int n, Map<int, int> c) => n + c.values.fold(0, (int m, int v) => m + v),
    );
    stdout.writeln(
      '[counts]   $id: ${books.length} books, '
      '$chapterCount chapters, $verseCount verses',
    );
    for (final String book in canonicalOrder) {
      final Map<int, int> chapters = books[book] ?? <int, int>{};
      stdout.writeln(
        '[counts]     $book: ${chapters.length} chapters, '
        '${chapters.values.fold(0, (int a, int b) => a + b)} verses',
      );
    }
  }
}

/// Cross-checks the CPDV snapshot counts against the upstream
/// `CPDV-books.json` `chapter_verses` metadata; any mismatch fails the run.
void _crossCheckCpdvMetadata(
  String metaPath,
  Map<String, (String, int)> keyToBook,
  Map<String, Map<int, int>> cpdvByDbBook,
) {
  final Map<String, dynamic> root = _loadJsonObject(
    File(metaPath),
    'CPDV-books.json must be a JSON object',
  );
  final List<Object?> books = root['books'] as List<Object?>? ?? <Object?>[];
  int misses = 0;
  for (final Object? entry in books) {
    if (entry is! Map<String, dynamic>) {
      stderr.writeln(
        '[fail]     CPDV-books.json "books" entry is not an object',
      );
      exit(1);
    }
    final String bookKey = entry['key'] as String? ?? '';
    final Object? chapterVersesRaw = entry['chapter_verses'];
    if (!keyToBook.containsKey(bookKey)) {
      stderr.writeln(
        '[fail]     CPDV-books.json book key "$bookKey" is not mapped in book_names.json',
      );
      exit(1);
    }
    final String dbName = keyToBook[bookKey]!.$1;
    final Map<int, int> snapshot = cpdvByDbBook[dbName] ?? <int, int>{};
    if (chapterVersesRaw is! Map<String, dynamic>) {
      stderr.writeln(
        '[fail]     CPDV-books.json $bookKey chapter_verses is not an object',
      );
      exit(1);
    }
    chapterVersesRaw.forEach((String chapterKey, Object? verseCount) {
      final int? chapter = int.tryParse(chapterKey);
      if (chapter == null || verseCount is! int) {
        return;
      }
      if (snapshot[chapter] != verseCount) {
        misses += 1;
        stderr.writeln(
          '[fail]     CPDV metadata expects $dbName '
          '$chapter: $verseCount verses, snapshot has ${snapshot[chapter]}',
        );
      }
    });
  }
  if (misses == 0) {
    stdout.writeln(
      '[ok]       CPDV chapter_verses metadata matches the EntireBible snapshot',
    );
  } else {
    stderr.writeln('[fail]     CPDV metadata mismatches vs snapshot: $misses');
    exit(1);
  }
}

/// Verifies each pinned reference verse against the snapshot text and prints
/// an informational line for the known plan-vs-snapshot wording divergences.
List<String> _verifyReferenceVerses({
  required Map<String, Map<String, Map<int, Map<int, String>>>> parsedUsfms,
  required Map<String, Map<String, Map<String, dynamic>>> snapshotRoots,
}) {
  final List<String> failures = <String>[];
  for (final _Pin pin in _pins) {
    final String? text = _verseTextForPin(pin, parsedUsfms, snapshotRoots);
    if (text == null) {
      failures.add(
        'missing verse ${pin.dbName} ${pin.chapter}:${pin.verse} in ${pin.translation}',
      );
      continue;
    }
    if (!text.startsWith(pin.startsWith)) {
      failures.add(
        '${pin.translation} ${pin.dbName} ${pin.chapter}:${pin.verse} does not '
        'start with "${pin.startsWith}"; snapshot text starts with '
        '"${_prefix(text, 60)}"',
      );
    }
    final String? planWording =
        _planPinWording['${pin.translation} ${pin.dbName} ${pin.chapter}:${pin.verse}'];
    if (planWording != null) {
      final bool planMatches = text.startsWith(planWording);
      stdout.writeln(
        '[info]     ${pin.translation} ${pin.dbName} ${pin.chapter}:${pin.verse}: '
        'snapshot text "${_prefix(text, 60)}"; plan pin "$planWording" '
        '${planMatches ? 'matches' : 'does NOT match the committed snapshot '
                  '(wording from a different upstream edition; see Task 2 report)'}',
      );
    }
  }
  return failures;
}

/// Resolves a pinned reference verse to its snapshot text, or null when the
/// verse does not exist (which itself fails `.startsWith` verification).
/// engwebc and drc are both USFM zips (decoded by the shared parser, hence
/// REAL verses only); cpdv is a `{bookKey: {chapter: {verse: text}}}` JSON
/// snapshot.
String? _verseTextForPin(
  _Pin pin,
  Map<String, Map<String, Map<int, Map<int, String>>>> parsedUsfms,
  Map<String, Map<String, Map<String, dynamic>>> snapshotRoots,
) {
  switch (pin.translation) {
    case 'engwebc':
    case 'drc':
      final Map<int, Map<int, String>>? chapters =
          parsedUsfms[pin.translation]?[pin.sourceKey];
      return chapters?[pin.chapter]?[pin.verse];
    case 'cpdv':
      final Object? book = snapshotRoots[pin.translation]?[pin.sourceKey];
      if (book is! Map<String, dynamic>) {
        return null;
      }
      final Object? chapter = book['${pin.chapter}'];
      if (chapter is! Map<String, dynamic>) {
        return null;
      }
      final Object? verse = chapter['${pin.verse}'];
      return verse is String ? verse.trim() : null;
    default:
      return null;
  }
}

/// Whether [numbers] is exactly 1..length (deep-compare, unlike `List ==`).
bool _isContiguousFromOne(List<int> numbers) {
  for (int i = 0; i < numbers.length; i++) {
    if (numbers[i] != i + 1) {
      return false;
    }
  }
  return true;
}

/// Renders the manifest value:
/// `{"translations": {"<id>": {"order": …, "chapters": …,
///  "verseNumbers"?: {book: {chapter: [verses]}}, "referenceVerses": …}}}`,
/// emitting `verseNumbers` only for translations that have gap chapters
/// (engwebc only, in practice — drc and CPDV are gap-free hard stops).
Map<String, dynamic> _buildManifest(
  Map<String, Map<String, Map<int, int>>> perTranslation,
  List<String> canonicalOrder,
  Map<String, Map<String, Map<String, List<int>>>> verseNumbers,
) {
  final List<String> ids = _translationIds
      .where((String id) => perTranslation.containsKey(id))
      .toList();
  if (ids.isEmpty) {
    stderr.writeln('[fail]     no translation verified; nothing to emit');
    exit(1);
  }
  return <String, dynamic>{
    'translations': <String, dynamic>{
      for (final String id in ids)
        id: _translationEntry(id, perTranslation, canonicalOrder, verseNumbers),
    },
  };
}

/// One per-translation manifest entry.
Map<String, dynamic> _translationEntry(
  String id,
  Map<String, Map<String, Map<int, int>>> perTranslation,
  List<String> canonicalOrder,
  Map<String, Map<String, Map<String, List<int>>>> verseNumbers,
) {
  final Map<String, dynamic> entry = <String, dynamic>{
    'order': canonicalOrder,
    'chapters': <String, dynamic>{
      for (final String book in canonicalOrder)
        book: <String, int>{
          for (final int chapter
              in (perTranslation[id]![book] ?? <int, int>{}).keys.toList()
                ..sort())
            '$chapter': (perTranslation[id]![book] ?? <int, int>{})[chapter]!,
        },
    },
  };
  final Map<String, Map<String, List<int>>>? gaps = verseNumbers[id];
  if (gaps != null && gaps.isNotEmpty) {
    final Map<String, dynamic> listed = <String, dynamic>{};
    for (final String book in canonicalOrder) {
      final Map<String, List<int>>? chapters = gaps[book];
      if (chapters == null) {
        continue;
      }
      final Map<String, List<int>> sortedChapters = <String, List<int>>{};
      for (final int chapterNo
          in chapters.keys.map(int.tryParse).whereType<int>().toList()
            ..sort()) {
        final String chapterKey = '$chapterNo';
        sortedChapters[chapterKey] = List<int>.of(chapters[chapterKey]!)
          ..sort();
      }
      listed[book] = sortedChapters;
    }
    entry['verseNumbers'] = listed;
  }
  entry['referenceVerses'] = <Map<String, dynamic>>[
    for (final _Pin pin in _pins.where((_Pin p) => p.translation == id))
      <String, dynamic>{
        'book': pin.dbName,
        'chapter': pin.chapter,
        'verse': pin.verse,
        'startsWith': pin.startsWith,
      },
  ];
  return entry;
}

/// Pretty-prints the manifest for the BEGIN/END stdout block.
String _manifestJson(
  Map<String, Map<String, Map<int, int>>> perTranslation,
  List<String> canonicalOrder,
  Map<String, Map<String, Map<String, List<int>>>> verseNumbers,
) {
  return const JsonEncoder.withIndent(
    '  ',
  ).convert(_buildManifest(perTranslation, canonicalOrder, verseNumbers));
}

/// Bounded prefix of `text` for log lines.
String _prefix(String text, int max) {
  return text.length <= max ? text : text.substring(0, max);
}

/// Loads a JSON object file, exiting on malformed input.
Map<String, dynamic> _loadJsonObject(File file, String failureMessage) {
  final Object? decoded = jsonDecode(file.readAsStringSync());
  if (decoded is! Map<String, dynamic>) {
    stderr.writeln('[fail]     ${file.path}: $failureMessage');
    exit(1);
  }
  return decoded;
}

/// Walks up from this script's location until a `pubspec.yaml` is found (the
/// package root); falls back to the current working directory.
Directory _packageRoot() {
  Directory dir = File.fromUri(Platform.script).parent;
  for (int i = 0; i < 8; i++) {
    if (File('${dir.path}/pubspec.yaml').existsSync()) {
      return dir;
    }
    final Directory parent = dir.parent;
    if (parent.path == dir.path) {
      break;
    }
    dir = parent;
  }
  return Directory.current;
}
