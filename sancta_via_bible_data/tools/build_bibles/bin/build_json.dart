#!/usr/bin/env dart

/// Builds the three `assets/bibles/{engwebc,cpdv,drc}.json` translation
/// assets from the Task 1 snapshots (`assets/sources/`).
///
/// Adapters (amended drc ruling: drc is USFM, NOT DRB.json):
/// - engwebc: `engwebc_usfm.zip` (eBible eng-web-c), per-file `\id` codes
///   routed through `tools/build_bibles/book_names.json` (`ESG`/`DAG`);
/// - drc: `drc_usfm.zip` (eBible engDRA, Douay-Rheims 1899 American Edition),
///   same USFM path through its own codes (`EST`/`DAN`);
/// - cpdv: `EntireBible-CPDV.json` (`{book: {chapter: {verse: text}}}`),
///   skipping the `charset` metadata key and the non-numeric `P` prologue
///   chapters (skip rules, not dropped verses).
///
/// Both USFM snapshots go through the shared rich parser
/// (`../lib/usfm_parser.dart`) — the same parser `validate_sources.dart`
/// counts with — so note-only verse markers (footnote/cross-ref bodies only,
/// single or composite) produce NO verse, header lines never leak into verse
/// text, and word attributes are dropped. CPDV verse text is used verbatim
/// (trimmed). Verse and chapter numbers are emitted as true ints.
///
/// After building, the assets are validated against
/// `tools/build_bibles/expected_structure.json` with `validateBibleStructure`
/// (same library the app-side validation test uses); any error fails the run
/// with exit 1. The generated JSON is never patched by hand — fix the
/// adapter/parser or the manifest.
///
/// Output schema:
/// ```
/// {
///   "translation": "<display name>",
///   "metadata": {"name": …, "abbreviation": …, "books": 73, "verses": N},
///   "books": [
///     {"name": "Genesis",
///      "chapters": [{"chapter": 1, "verses": [{"verse": 1, "text": …}]}]}
///   ]
/// }
/// ```
///
/// Usage (from `sancta_via_bible_data/`):
/// ```
/// dart tools/build_bibles/bin/build_json.dart
/// ```

import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';

import '../../../lib/src/utils/bible_structure_validator.dart';
import '../lib/usfm_parser.dart';

const String _bookNamesRelativePath = 'tools/build_bibles/book_names.json';
const String _expectedStructureRelativePath =
    'tools/build_bibles/expected_structure.json';
const String _sourcesRelativeDir = 'assets/sources';
const String _usfmZipName = 'engwebc_usfm.zip';
const String _drcUsfmZipName = 'drc_usfm.zip';
const String _cpdvJsonName = 'EntireBible-CPDV.json';
const String _cpdvMetadataKey = 'charset';
const String _usfmFrontMatterCode = 'FRT';
const int _expectedBookCount = 73;

/// Per-translation display metadata (amendments: rebuilt translation names
/// and abbreviations; the legacy 78-book-ghost-era names are gone).
const Map<String, (String, String)> _translationMeta =
    <String, (String, String)>{
      'engwebc': ('World English Bible (Catholic Edition)', 'WEB-C'),
      'cpdv': (
        'Catholic Public Domain Version (2009 Original Edition)',
        'CPDV',
      ),
      'drc': ('Douay-Rheims 1899 American Edition (Challoner)', 'DRA'),
    };

/// Canonical translation ids in output order.
const List<String> _translationIds = <String>['engwebc', 'cpdv', 'drc'];

/// Built structures: translation id -> book name -> chapter -> verse -> text.
typedef _BuiltTranslations =
    Map<String, Map<String, Map<int, Map<int, String>>>>;

Future<void> main(List<String> args) async {
  final Directory packageRoot = _packageRoot();
  final Directory sourcesDir = Directory(
    '${packageRoot.path}/$_sourcesRelativeDir',
  );
  final Directory biblesDir = Directory('${packageRoot.path}/assets/bibles');

  final Map<String, (String, int)> keyToBook = _loadBookNames(
    File('${packageRoot.path}/$_bookNamesRelativePath'),
  );
  final List<String> canonicalOrder = _canonicalOrder(keyToBook);

  final _BuiltTranslations built =
      <String, Map<String, Map<int, Map<int, String>>>>{
        'engwebc': _fromUsfmZip(
          '${sourcesDir.path}/$_usfmZipName',
          'engwebc',
          keyToBook,
          canonicalOrder,
        ),
        'cpdv': _fromCpdvJson(
          '${sourcesDir.path}/$_cpdvJsonName',
          keyToBook,
          canonicalOrder,
        ),
        'drc': _fromUsfmZip(
          '${sourcesDir.path}/$_drcUsfmZipName',
          'drc',
          keyToBook,
          canonicalOrder,
        ),
      };

  // Validate BEFORE writing: the manifest is the single source of truth.
  final Map<String, dynamic> expectedStructure = _loadJsonObject(
    File('${packageRoot.path}/$_expectedStructureRelativePath'),
    'expected_structure.json must be a JSON object',
  );
  final Map<String, Map<String, Map<int, Map<int, String>>>> forValidation =
      <String, Map<String, Map<int, Map<int, String>>>>{
        for (final String id in _translationIds) id: built[id]!,
      };
  final List<String> errors = validateBibleStructure(
    translations: forValidation,
    expectedStructure: expectedStructure,
  );
  if (errors.isNotEmpty) {
    stderr.writeln('[fail]     built data fails expected_structure.json:');
    for (final String error in errors.take(40)) {
      stderr.writeln('  $error');
    }
    stderr.writeln(
      '           Fix the adapter/parser or the manifest — never the '
      'generated JSON by hand.',
    );
    exit(1);
  }
  stdout.writeln(
    '[ok]       all three translations validate against expected_structure.json',
  );

  for (final String id in _translationIds) {
    final (String name, String abbreviation) = _translationMeta[id]!;
    final Map<String, Map<int, Map<int, String>>> books = built[id]!;
    final int verseTotal = _verseTotal(books);
    _writeAsset(biblesDir, id, name, abbreviation, books, canonicalOrder);
    stdout.writeln(
      '[built]    assets/bibles/$id.json: ${books.length} books, '
      '$verseTotal verses (metadata.verses=$verseTotal)',
    );
  }
}

/// Writes one pretty-printed asset JSON (trailing newline, legacy shape):
/// `{translation, metadata: {name, abbreviation, books, verses},
///   books: [{name, chapters: [{chapter, verses: [{verse, text}]}]}]}`.
void _writeAsset(
  Directory biblesDir,
  String id,
  String name,
  String abbreviation,
  Map<String, Map<int, Map<int, String>>> books,
  List<String> canonicalOrder,
) {
  final Map<String, dynamic> builtAsset = <String, dynamic>{
    'translation': name,
    'metadata': <String, dynamic>{
      'name': name,
      'abbreviation': abbreviation,
      'books': books.length,
      'verses': _verseTotal(books),
    },
    'books': <Map<String, dynamic>>[
      for (final String book in canonicalOrder)
        if (books.containsKey(book))
          <String, dynamic>{
            'name': book,
            'chapters': _chaptersJson(books[book]!),
          },
    ],
  };
  final String json = const JsonEncoder.withIndent('  ').convert(builtAsset);
  final File file = File('${biblesDir.path}/$id.json');
  file.writeAsStringSync('$json\n');
}

/// Total verse count across all books.
int _verseTotal(Map<String, Map<int, Map<int, String>>> books) {
  int total = 0;
  for (final Map<int, Map<int, String>> chapters in books.values) {
    for (final Map<int, String> verses in chapters.values) {
      total += verses.length;
    }
  }
  return total;
}

/// Serializes chapters: [{chapter, verses: [{verse, text}]}].
List<Map<String, dynamic>> _chaptersJson(Map<int, Map<int, String>> book) {
  return <Map<String, dynamic>>[
    for (final int chapter in book.keys.toList()..sort())
      <String, dynamic>{
        'chapter': chapter,
        'verses': <Map<String, dynamic>>[
          for (final int verse in book[chapter]!.keys.toList()..sort())
            <String, dynamic>{'verse': verse, 'text': book[chapter]![verse]!},
        ],
      },
  ];
}

/// Loads `book_names.json` and validates the pinned
/// `{sourceKey: {dbName, order}}` shape.
Map<String, (String, int)> _loadBookNames(File file) {
  final Map<String, dynamic> raw = _loadJsonObject(
    file,
    'book_names.json must be a JSON object',
  );
  final Map<String, (String, int)> result = <String, (String, int)>{};
  for (final MapEntry<String, dynamic> entry in raw.entries) {
    if (entry.value is! Map<String, dynamic>) {
      stderr.writeln(
        '[fail]     book_names.json["${entry.key}"] must be {dbName, order}',
      );
      exit(1);
    }
    final Map<String, dynamic> value = entry.value;
    final String dbName = value['dbName'] as String? ?? '';
    final Object? orderRaw = value['order'];
    final int? order = orderRaw is int ? orderRaw : int.tryParse('$orderRaw');
    if (dbName.isEmpty || order == null || order < 1) {
      stderr.writeln(
        '[fail]     book_names.json["${entry.key}"] must be {dbName, order}',
      );
      exit(1);
    }
    result[entry.key] = (dbName, order);
  }
  if (result.values.map(((String, int) entry) => entry.$1).toSet().length !=
      _expectedBookCount) {
    stderr.writeln(
      '[fail]     book_names.json must contain $_expectedBookCount db books',
    );
    exit(1);
  }
  return result;
}

/// The canonical db book order (orders 1..73 contiguous), as the validator
/// and the manifest pin it.
List<String> _canonicalOrder(Map<String, (String, int)> keyToBook) {
  final Map<String, int> byDbName = <String, int>{};
  for (final (String dbName, int order) in keyToBook.values) {
    final int? existing = byDbName[dbName];
    if (existing != null && existing != order) {
      stderr.writeln(
        '[fail]     db book "$dbName" has conflicting orders $existing/$order',
      );
      exit(1);
    }
    byDbName[dbName] = order;
  }
  final List<String> names = byDbName.keys.toList()
    ..sort((String a, String b) => byDbName[a]!.compareTo(byDbName[b]!));
  for (int i = 0; i < names.length; i++) {
    if (byDbName[names[i]] != i + 1) {
      stderr.writeln(
        '[fail]     db book orders must be 1..$_expectedBookCount contiguous',
      );
      exit(1);
    }
  }
  return names;
}

/// USFM zip adapter: parses every mapped book file with the shared parser and
/// returns db-name-keyed chapter/verse text maps (REAL verses only).
Map<String, Map<int, Map<int, String>>> _fromUsfmZip(
  String zipPath,
  String translationId,
  Map<String, (String, int)> keyToBook,
  List<String> canonicalOrder,
) {
  final List<int> bytes = File(zipPath).readAsBytesSync();
  final Archive archive = ZipDecoder().decodeBytes(bytes);
  final Map<String, Map<int, Map<int, String>>> byDbBook =
      <String, Map<int, Map<int, String>>>{};
  for (final ArchiveFile entry in archive.files) {
    if (!entry.isFile || !entry.name.toLowerCase().endsWith('.usfm')) {
      continue;
    }
    final String text = utf8.decode(entry.content as List<int>);
    final String code =
        RegExp(r'\\id\s+(\S+)').firstMatch(text)?.group(1) ?? '';
    if (code == _usfmFrontMatterCode) {
      continue;
    }
    final (String dbBook, _) =
        keyToBook[code] ??
        (() {
          stderr.writeln(
            '[fail]     $translationId: ${entry.name}: book code "$code" is '
            'not mapped in book_names.json',
          );
          exit(1);
        })();
    if (byDbBook.containsKey(dbBook)) {
      stderr.writeln(
        '[fail]     $translationId: duplicate db book "$dbBook" '
        '(${entry.name})',
      );
      exit(1);
    }
    final Map<int, Map<int, String>> chapters = <int, Map<int, String>>{};
    for (final UsfmChapter chapter in parseUsfmBook(text)) {
      chapters[chapter.number] = <int, String>{
        for (final (int verse, String verseText) in chapter.verses)
          verse: verseText,
      };
    }
    byDbBook[dbBook] = chapters;
  }
  _assertFullVocabulary(byDbBook, translationId, canonicalOrder);
  return byDbBook;
}

/// CPDV adapter: `{bookKey: {chapterKey: {verseKey: text}}}`; the `charset`
/// metadata key and non-numeric (P) prologue chapters are skipped; verse text
/// is emitted verbatim, trimmed.
Map<String, Map<int, Map<int, String>>> _fromCpdvJson(
  String jsonPath,
  Map<String, (String, int)> keyToBook,
  List<String> canonicalOrder,
) {
  final Map<String, dynamic> root = _loadJsonObject(
    File(jsonPath),
    'CPDV snapshot must be a JSON object',
  );
  final Map<String, Map<int, Map<int, String>>> byDbBook =
      <String, Map<int, Map<int, String>>>{};
  for (final MapEntry<String, dynamic> entry in root.entries) {
    if (entry.key == _cpdvMetadataKey) {
      if (entry.value is! String) {
        stderr.writeln(
          '[fail]     CPDV metadata key "charset" must be a string',
        );
        exit(1);
      }
      continue;
    }
    final (String dbBook, _) =
        keyToBook[entry.key] ??
        (() {
          stderr.writeln(
            '[fail]     CPDV: book key "${entry.key}" is not mapped in '
            'book_names.json',
          );
          exit(1);
        })();
    if (entry.value is! Map<String, dynamic>) {
      stderr.writeln('[fail]     CPDV: book "${entry.key}" is not an object');
      exit(1);
    }
    final Map<String, dynamic> chaptersRaw = entry.value;
    final Map<int, Map<int, String>> chapters = <int, Map<int, String>>{};
    for (final MapEntry<String, dynamic> chapterEntry in chaptersRaw.entries) {
      final int? chapterNo = int.tryParse(chapterEntry.key);
      if (chapterNo == null) {
        stdout.writeln(
          '[skipped]  CPDV $dbBook: prologue chapter "${chapterEntry.key}"',
        );
        continue;
      }
      if (chapterEntry.value is! Map<String, dynamic>) {
        stderr.writeln(
          '[fail]     CPDV: $dbBook chapter ${chapterEntry.key} is not an object',
        );
        exit(1);
      }
      final Map<String, dynamic> versesRaw = chapterEntry.value;
      final Map<int, String> verses = <int, String>{};
      for (final MapEntry<String, dynamic> verseEntry in versesRaw.entries) {
        final int? verseNo = int.tryParse(verseEntry.key);
        if (verseNo == null) {
          stderr.writeln(
            '[fail]     CPDV: $dbBook chapter $chapterNo: verse key '
            '"${verseEntry.key}" is not a decimal string',
          );
          exit(1);
        }
        if (verseEntry.value is! String) {
          stderr.writeln(
            '[fail]     CPDV: $dbBook chapter $chapterNo verse $verseNo: '
            'text is not a string',
          );
          exit(1);
        }
        verses[verseNo] = (verseEntry.value as String).trim();
      }
      chapters[chapterNo] = verses;
    }
    byDbBook[dbBook] = chapters;
  }
  _assertFullVocabulary(byDbBook, 'cpdv', canonicalOrder);
  return byDbBook;
}

/// Requires the adapter to cover exactly the 73-book canonical vocabulary.
void _assertFullVocabulary(
  Map<String, Map<int, Map<int, String>>> byDbBook,
  String translationId,
  List<String> canonicalOrder,
) {
  if (byDbBook.length != canonicalOrder.length) {
    stderr.writeln(
      '[fail]     $translationId covers ${byDbBook.length} of expected '
      '${canonicalOrder.length} db books',
    );
    exit(1);
  }
  for (final String book in canonicalOrder) {
    if (!byDbBook.containsKey(book)) {
      stderr.writeln(
        '[fail]     $translationId is missing canonical book "$book"',
      );
      exit(1);
    }
  }
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
