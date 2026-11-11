#!/usr/bin/env dart

/// Source-snapshot structure emitter for the bible rebuild pipeline.
///
/// Reads the Task 1 snapshots from `assets/sources/` and the sibling
/// `tools/build_bibles/book_names.json` vocabulary, then:
/// - validates that every source book key resolves to exactly the 73-book
///   canonical DB vocabulary, and vice versa (per-source bijection);
/// - counts chapters and verses per chapter for each translation with the
///   adapters the builder will use (USFM `\c`/`\v` counting for engwebc,
///   `chapter` map sizes for CPDV and drc; non-numeric `P` prologue chapters
///   and the `charset` metadata key are skipped);
/// - verifies the reference verses pinned in this file against the snapshot
///   text (verse text is reconstructed with the same marker stripping the
///   parser will apply: footnote/cross-reference bodies dropped, `|strong=`
///   style word attributes dropped, backslash tags dropped, whitespace
///   collapsed); any mismatch fails the run;
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

const String _bookNamesRelativePath = 'tools/build_bibles/book_names.json';
const String _sourcesRelativeDir = 'assets/sources';
const String _usfmZipName = 'engwebc_usfm.zip';
const String _usfmFrontMatterCode = 'FRT';
const int _expectedBookCount = 73;
const String _cpdvJsonName = 'EntireBible-CPDV.json';
const String _cpdvMetadataKey = 'charset';
const String _cpdvBooksMetaName = 'CPDV-books.json';
const String _drcJsonName = 'drc.json';

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
  _Pin(
    'drc',
    'Genesis',
    'Genesis',
    1,
    1,
    'In the *beginning God created heaven',
  ),
  _Pin(
    'drc',
    'Ecclesiasticus',
    'Sirach',
    1,
    1,
    'All *wisdom is from the Lord God, and',
  ),
  _Pin(
    'drc',
    'Revelation',
    'Revelation',
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

  final Map<String, Map<int, int>> usfmCounts = <String, Map<int, int>>{};
  final Map<String, String> usfmText = <String, String>{};
  _parseUsfmZip(
    '${sourcesDir.path}/$_usfmZipName',
    keyToBook,
    usfmCounts,
    usfmText,
  );

  final Map<String, Map<int, int>> cpdvCounts = <String, Map<int, int>>{};
  final List<String> cpdvViolations = <String>[];
  final Map<String, Map<String, dynamic>> cpdvRoot = _parseChapterVerseJson(
    '${sourcesDir.path}/$_cpdvJsonName',
    keyToBook,
    skipTopLevelKey: _cpdvMetadataKey,
    counts: cpdvCounts,
    violations: cpdvViolations,
  );

  final Map<String, Map<int, int>> drcCounts = <String, Map<int, int>>{};
  final List<String> drcViolations = <String>[];
  final Map<String, Map<String, dynamic>> drcRoot = _parseChapterVerseJson(
    '${sourcesDir.path}/$_drcJsonName',
    keyToBook,
    skipTopLevelKey: null,
    counts: drcCounts,
    violations: drcViolations,
  );

  final Map<String, Map<String, Map<int, int>>> perTranslation =
      <String, Map<String, Map<int, int>>>{
        'engwebc': _byDbBook(usfmCounts, keyToBook, canonicalOrder, 'engwebc'),
        'cpdv': _byDbBook(cpdvCounts, keyToBook, canonicalOrder, 'cpdv'),
        'drc': _byDbBook(drcCounts, keyToBook, canonicalOrder, 'drc'),
      };

  _printCounts(perTranslation, canonicalOrder);
  _crossCheckCpdvMetadata(
    '${sourcesDir.path}/$_cpdvBooksMetaName',
    keyToBook,
    perTranslation['cpdv']!,
  );

  final List<String> failures = _verifyReferenceVerses(
    usfmText: usfmText,
    snapshotRoots: <String, Map<String, Map<String, dynamic>>>{
      'cpdv': cpdvRoot,
      'drc': drcRoot,
    },
  );

  final Map<String, String> excluded = <String, String>{};
  if (cpdvViolations.isNotEmpty) {
    excluded['cpdv'] =
        'chapter/verse coordinate violations: ${cpdvViolations.length}';
  }
  if (drcViolations.isNotEmpty) {
    excluded['drc'] =
        'chapter/verse coordinate violations: ${drcViolations.length}';
  }
  if (failures.isNotEmpty) {
    excluded['engwebc'] =
        'reference-verse verification failed: ${failures.length}';
  }

  stdout.writeln('--- BEGIN expected_structure.json ---');
  stdout.writeln(_manifestJson(perTranslation, canonicalOrder, excluded));
  stdout.writeln('--- END expected_structure.json ---');

  if (excluded.isNotEmpty) {
    for (final String id in _translationIds) {
      if (excluded.containsKey(id)) {
        stdout.writeln(
          '[excluded] $id: ${excluded[id]} (omitted from the emitted manifest)',
        );
      }
    }
    if (drcViolations.isNotEmpty) {
      stderr.writeln(
        '[fail]     drc structure violations (committed exanx DRB join '
        'is corrupt upstream; see Task 2 report):',
      );
      for (final String violation in drcViolations.take(40)) {
        stderr.writeln('  $violation');
      }
      stderr.writeln(
        '           ... total violations: ${drcViolations.length} across '
        '${drcViolations.map((String v) => v.split('"')[1]).toSet().length} books '
        '(plus missing tail chapters: 69 chapter keys short of the full DRB canon)',
      );
    }
    if (failures.isNotEmpty) {
      stderr.writeln('[fail]     reference-verse verification failures:');
      for (final String failure in failures.take(20)) {
        stderr.writeln('  $failure');
      }
    }
    stderr.writeln(
      '           The manifest above includes only translations whose '
      'structure verified; excluded translations must not be built until '
      'their sources are fixed.',
    );
    exitCode = 1;
  }
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
/// entry whose `\id` code is a mapped book (front matter is skipped), counts
/// verses per chapter and keeps the raw text for reference-verse extraction.
void _parseUsfmZip(
  String zipPath,
  Map<String, (String, int)> keyToBook,
  Map<String, Map<int, int>> counts,
  Map<String, String> textByCode,
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
    bookFiles += 1;
    dbBookNames.add(keyToBook[code]!.$1);
    final Map<int, int> chapters = <int, int>{};
    final Set<String> seenVerseMarkers = <String>{};
    int? current;
    for (final String line in text.split('\n')) {
      final String trimmed = line.trim();
      final RegExpMatch? chapterMatch = RegExp(
        r'\\c (\d+)\s*$',
      ).firstMatch(trimmed);
      if (chapterMatch != null) {
        current = int.parse(chapterMatch.group(1)!);
        chapters[current] = chapters[current] ?? 0;
        continue;
      }
      if (current == null) {
        continue;
      }
      for (final RegExpMatch match in RegExp(
        r'\\v (\S+)',
      ).allMatches(trimmed)) {
        final String label = match.group(1)!;
        if (int.tryParse(label) == null) {
          stdout.writeln(
            '[warn]     $baseName chapter $current: non-numeric verse marker '
            '"$label" (footnote-style composite kept in counts)',
          );
        }
        if (!seenVerseMarkers.add('$current/$label')) {
          stderr.writeln(
            '[fail]     $baseName duplicate verse marker "$current/$label"',
          );
          exit(1);
        }
        chapters[current] = (chapters[current] ?? 0) + 1;
      }
    }
    counts[code] = chapters;
    textByCode[code] = text;
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

/// Parses a `{<bookKey>: {<chapter>: {<verse>: "text"}}}` snapshot into
/// per-source-key verse counts. Non-numeric chapter keys (`P` prologues) are
/// skipped; an optional top-level metadata key (CPDV `charset`) is skipped.
/// Verse keys inside every chapter are additionally checked to be exactly
/// `1..N`; violations are collected into [violations] (grep-able, and the
/// caller fails the run once the manifest has been emitted). Returns the
/// parsed book maps for reference-verse lookups.
Map<String, Map<String, dynamic>> _parseChapterVerseJson(
  String path,
  Map<String, (String, int)> keyToBook, {
  required String? skipTopLevelKey,
  required Map<String, Map<int, int>> counts,
  List<String>? violations,
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
    final Map<int, int> chapters = <int, int>{};
    for (final MapEntry<String, dynamic> chapterEntry in value.entries) {
      final int? chapter = int.tryParse(chapterEntry.key);
      if (chapter == null) {
        stdout.writeln(
          '[skipped]  $path $bookKey: prologue chapter "${chapterEntry.key}"',
        );
        continue;
      }
      if (chapterEntry.value is! Map<String, dynamic>) {
        stderr.writeln(
          '[fail]     $path $bookKey chapter ${chapterEntry.key} is not an object',
        );
        exit(1);
      }
      if (violations != null) {
        final List<int> verseNumbers =
            chapterEntry.value.keys.map(int.tryParse).whereType<int>().toList()
              ..sort();
        final bool contiguous =
            verseNumbers.length == chapterEntry.value.length &&
            _isContiguousFromOne(verseNumbers);
        if (!contiguous) {
          violations.add(
            '"$bookKey" chapter "${chapterEntry.key}": verse keys are not '
            '1..${chapterEntry.value.length} '
            '(${verseNumbers.isEmpty ? 'none numeric' : '${verseNumbers.first}..${verseNumbers.last}'}); '
            'coordinates do not reflect the (book, chapter, verse) structure',
          );
        }
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
      chapters[chapter] = chapterEntry.value.length;
    }
    counts[bookKey] = chapters;
    bookMaps[bookKey] = value;
  }
  return bookMaps;
}

/// Re-keys per-source counts onto canonical db book names and validates that
/// the source covers exactly the 73-book vocabulary.
Map<String, Map<int, int>> _byDbBook(
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
  required Map<String, String> usfmText,
  required Map<String, Map<String, Map<String, dynamic>>> snapshotRoots,
}) {
  final List<String> failures = <String>[];
  for (final _Pin pin in _pins) {
    final String? text = _verseTextForPin(pin, usfmText, snapshotRoots);
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
String? _verseTextForPin(
  _Pin pin,
  Map<String, String> usfmText,
  Map<String, Map<String, Map<String, dynamic>>> snapshotRoots,
) {
  switch (pin.translation) {
    case 'engwebc':
      final String text = usfmText[pin.sourceKey] ?? '';
      return _usfmVerseText(text, pin.chapter, pin.verse);
    case 'cpdv':
    case 'drc':
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

/// Extracts one verse's text from USFM: the verse block starts at its
/// `\v <n>` line and runs until the next `\v`/`\c`/section-header line.
/// Footnote (`\f + … \f*`) and cross-reference (`\x + … \x*`) bodies are
/// dropped, `|key="value"` word attributes are dropped, remaining backslash
/// tags are dropped, the leading verse number is dropped, and whitespace is
/// collapsed. Mirrors the parser the builder will use.
String? _usfmVerseText(String usfm, int chapter, int verse) {
  final List<String> lines = usfm.split('\n');
  int? current;
  int? startIndex;
  for (int i = 0; i < lines.length; i++) {
    final String trimmed = lines[i].trim();
    final RegExpMatch? chapterMatch = RegExp(
      r'\\c (\d+)\s*$',
    ).firstMatch(trimmed);
    if (chapterMatch != null) {
      current = int.parse(chapterMatch.group(1)!);
      continue;
    }
    if (current == chapter && trimmed.startsWith('\\v $verse ')) {
      startIndex = i;
      break;
    }
  }
  if (startIndex == null) {
    return null;
  }
  final List<String> body = <String>[lines[startIndex]];
  for (int i = startIndex + 1; i < lines.length; i++) {
    final String trimmed = lines[i].trim();
    if (trimmed.isEmpty) {
      continue;
    }
    final bool nextChapter = RegExp(r'\\c (\d+)').hasMatch(trimmed);
    final bool nextVerse = trimmed.startsWith('\\v ');
    final bool sectionHeader = RegExp(
      r'\\(s\d|d\b|mt\d|ms\d|sp\b|cl\b|nb\b|pc\b)\b',
    ).hasMatch(trimmed);
    if (nextChapter || nextVerse || sectionHeader) {
      break;
    }
    body.add(lines[i]);
  }
  String text = body.join('\n');
  text = text
      .replaceAll(RegExp(r'\\f \+[\s\S]*?\\f\*'), '')
      .replaceAll(RegExp(r'\\x \+[\s\S]*?\\x\*'), '')
      .replaceAll(RegExp(r'\|\w+="[^"]*"'), '')
      .replaceAll(RegExp(r'\\[a-z0-9+]+\*?'), '');
  final RegExpMatch? leadingNumber = RegExp(r'^\s*(\d+)\b').firstMatch(text);
  if (leadingNumber != null) {
    text = text.substring(leadingNumber.end);
  }
  text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (text.contains('\\')) {
    throw StateError('stripped verse text retains a backslash marker: $text');
  }
  return text;
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
/// `{"translations": {"<id>": {"order": …, "chapters": …, "referenceVerses": …}}}`,
/// emitting only translations not excluded by [excluded].
Map<String, dynamic> _buildManifest(
  Map<String, Map<String, Map<int, int>>> perTranslation,
  List<String> canonicalOrder,
  Map<String, String> excluded,
) {
  final List<String> ids = _translationIds
      .where((String id) => !excluded.containsKey(id))
      .toList();
  if (ids.isEmpty) {
    stderr.writeln(
      '[fail]     every translation was excluded; nothing to emit',
    );
    exit(1);
  }
  return <String, dynamic>{
    'translations': <String, dynamic>{
      for (final String id in ids)
        id: <String, dynamic>{
          'order': canonicalOrder,
          'chapters': <String, dynamic>{
            for (final String book in canonicalOrder)
              book: <String, int>{
                for (final int chapter
                    in (perTranslation[id]![book] ?? <int, int>{}).keys.toList()
                      ..sort())
                  '$chapter':
                      (perTranslation[id]![book] ?? <int, int>{})[chapter]!,
              },
          },
          'referenceVerses': <Map<String, dynamic>>[
            for (final _Pin pin in _pins.where((_Pin p) => p.translation == id))
              <String, dynamic>{
                'book': pin.dbName,
                'chapter': pin.chapter,
                'verse': pin.verse,
                'startsWith': pin.startsWith,
              },
          ],
        },
    },
  };
}

/// Pretty-prints the manifest for the BEGIN/END stdout block.
String _manifestJson(
  Map<String, Map<String, Map<int, int>>> perTranslation,
  List<String> canonicalOrder,
  Map<String, String> excluded,
) {
  return const JsonEncoder.withIndent(
    '  ',
  ).convert(_buildManifest(perTranslation, canonicalOrder, excluded));
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
