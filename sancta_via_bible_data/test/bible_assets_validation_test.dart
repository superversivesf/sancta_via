import 'dart:convert';
import 'dart:io';

import 'package:bible_data/src/utils/bible_structure_validator.dart';
import 'package:test/test.dart';

/// Validation of the rebuilt `assets/bibles/*.json` build outputs against the
/// pinned `tools/build_bibles/expected_structure.json` manifest. These files
/// are BUILD OUTPUTS (never hand-patched); a failure here means the
/// adapters/parser or the manifest are wrong.
const List<String> _translationIds = <String>['engwebc', 'cpdv', 'drc'];

/// Rebuilt metadata pins (amendments: names, abbreviations, real totals).
const Map<String, Map<String, Object>> _metadataPins =
    <String, Map<String, Object>>{
      'engwebc': <String, Object>{
        'translation': 'World English Bible (Catholic Edition)',
        'name': 'World English Bible (Catholic Edition)',
        'abbreviation': 'WEB-C',
        'books': 73,
        'verses': 35379,
      },
      'cpdv': <String, Object>{
        'translation': 'Catholic Public Domain Version (2009 Original Edition)',
        'name': 'Catholic Public Domain Version (2009 Original Edition)',
        'abbreviation': 'CPDV',
        'books': 73,
        'verses': 35827,
      },
      'drc': <String, Object>{
        'translation': 'Douay-Rheims 1899 American Edition (Challoner)',
        'name': 'Douay-Rheims 1899 American Edition (Challoner)',
        'abbreviation': 'DRA',
        'books': 73,
        'verses': 35811,
      },
    };

/// The 5 ghost books from the 78-book ghost-era legacy files.
const List<String> _ghostBooks = <String>[
  'I Esdras',
  'II Esdras',
  'Laodiceans',
  'Prayer of Manasses',
  'Additional Psalm',
];

Map<String, dynamic> _asset(String id) {
  final File file = File('assets/bibles/$id.json');
  if (!file.existsSync()) {
    fail('missing rebuilt asset: ${file.path}');
  }
  return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
}

/// Converts one asset JSON to the validator's triple map
/// (book name -> chapter -> verse -> text), requiring int chapter/verse keys.
Map<String, Map<int, Map<int, String>>> _toTriple(Map<String, dynamic> asset) {
  final List<dynamic> books = asset['books'] as List<dynamic>;
  final Map<String, Map<int, Map<int, String>>> result =
      <String, Map<int, Map<int, String>>>{};
  for (final dynamic bookObj in books) {
    final Map<String, dynamic> book = bookObj as Map<String, dynamic>;
    final String name = book['name'] as String;
    final List<dynamic> chapters = book['chapters'] as List<dynamic>;
    final Map<int, Map<int, String>> chaptersMap = <int, Map<int, String>>{};
    for (final dynamic chapterObj in chapters) {
      final Map<String, dynamic> chapter = chapterObj as Map<String, dynamic>;
      final Object? chapterNo = chapter['chapter'];
      expect(
        chapterNo,
        isA<int>(),
        reason: '$name chapter must be an int, got ${chapterNo.runtimeType}',
      );
      final List<dynamic> verses = chapter['verses'] as List<dynamic>;
      final Map<int, String> versesMap = <int, String>{};
      for (final dynamic verseObj in verses) {
        final Map<String, dynamic> verse = verseObj as Map<String, dynamic>;
        final Object? verseNo = verse['verse'];
        expect(
          verseNo,
          isA<int>(),
          reason:
              '$name chapter $chapterNo verse must be an int, '
              'got ${verseNo.runtimeType}',
        );
        versesMap[verseNo as int] = verse['text'] as String;
      }
      chaptersMap[chapterNo as int] = versesMap;
    }
    result[name] = chaptersMap;
  }
  return result;
}

void main() {
  group('rebuilt assets/bibles/*.json', () {
    late final Map<String, Map<String, Map<int, Map<int, String>>>>
    translations;
    late final Map<String, dynamic> expectedStructure;

    setUpAll(() {
      translations = <String, Map<String, Map<int, Map<int, String>>>>{
        for (final String id in _translationIds) id: _toTriple(_asset(id)),
      };
      expectedStructure =
          jsonDecode(
                File(
                  'tools/build_bibles/expected_structure.json',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>;
    });

    test('all three translations validate against expected_structure.json', () {
      final List<String> errors = validateBibleStructure(
        translations: translations,
        expectedStructure: expectedStructure,
      );

      expect(errors, isEmpty);
    });

    test('every data chapter in a listed verseNumbers chapter matches the '
        'pinned list exactly', () {
      for (final String id in _translationIds) {
        final Map<String, dynamic> entry =
            expectedStructure['translations'][id] as Map<String, dynamic>;
        final Object? verseNumbers = entry['verseNumbers'];
        if (verseNumbers == null) {
          continue;
        }
        final Map<String, dynamic> books = verseNumbers as Map<String, dynamic>;
        for (final MapEntry<String, dynamic> book in books.entries) {
          final Map<int, Map<int, String>> dataChapters =
              translations[id]![book.key]!;
          final Map<String, dynamic> listedChapters =
              book.value as Map<String, dynamic>;
          for (final MapEntry<String, dynamic> chapter
              in listedChapters.entries) {
            final int chapterNo = int.parse(chapter.key);
            final List<int> listed = (chapter.value as List<dynamic>)
                .cast<int>();
            expect(
              listedChapters.keys,
              contains(chapter.key),
              reason: '$id ${book.key}: listed chapter must exist in manifest',
            );
            expect(
              dataChapters,
              contains(chapterNo),
              reason: '$id ${book.key}: listed chapter must exist in data',
            );
            expect(
              dataChapters[chapterNo]!.keys.toList()..sort(),
              listed..sort(),
              reason:
                  '$id ${book.key} $chapterNo: data keys must equal the '
                  'pinned verseNumbers list',
            );
          }
        }
      }
    });

    test('metadata and translation names match the rebuilt pins', () {
      for (final String id in _translationIds) {
        final Map<String, dynamic> asset = _asset(id);
        final Map<String, dynamic> metadata =
            asset['metadata'] as Map<String, dynamic>;
        for (final MapEntry<String, Object> pin in _metadataPins[id]!.entries) {
          final Object? actual = pin.key == 'translation'
              ? asset['translation']
              : metadata[pin.key];
          expect(actual, pin.value, reason: '$id metadata.${pin.key}');
        }
      }
    });

    test('verse and chapter numbers are true ints everywhere', () {
      // _toTriple throws with a reason when a chapter or verse is not an int.
      expect(
        translations.values.every(
          (Map<String, Map<int, Map<int, String>>> books) => books.values.every(
            (Map<int, Map<int, String>> chapters) => chapters.values.every(
              (Map<int, String> verses) => verses.isNotEmpty,
            ),
          ),
        ),
        isTrue,
      );
    });

    test('no verse text contains a backslash', () {
      for (final String id in _translationIds) {
        for (final Map<int, Map<int, String>> chapters
            in translations[id]!.values) {
          for (final Map<int, String> verses in chapters.values) {
            for (final String text in verses.values) {
              expect(
                text.contains('\\'),
                isFalse,
                reason: '$id: backslash leaked into verse text',
              );
            }
          }
        }
      }
    });

    test('no translation contains any of the 5 ghost books', () {
      for (final String id in _translationIds) {
        for (final String ghost in _ghostBooks) {
          expect(
            translations[id],
            isNot(contains(ghost)),
            reason: '$id: ghost book "$ghost" rebuilt',
          );
        }
      }
    });

    test('Sirach chapter list excludes chapter 0 and has 51 chapters', () {
      for (final String id in _translationIds) {
        final Map<int, Map<int, String>> sirach = translations[id]!['Sirach']!;
        expect(sirach, isNot(contains(0)), reason: '$id Sirach chapter 0');
        expect(sirach.length, 51, reason: '$id Sirach chapter count');
      }
    });

    test('spec-pinned Psalm regressions', () {
      expect(
        translations['engwebc']!['Psalms']![18]!.length,
        50,
        reason: 'engwebc Psalms 18',
      );
      expect(
        translations['engwebc']!['Psalms']![19]!.length,
        14,
        reason: 'engwebc Psalms 19',
      );
      expect(
        translations['engwebc']!['Psalms']![119]!.length,
        176,
        reason: 'engwebc Psalms 119',
      );
      expect(
        translations['cpdv']!['Psalms']![18]!.length,
        15,
        reason: 'cpdv Psalms 18',
      );
    });

    test('engwebc Sirach 1 has no verse 5 or 7 (note-only markers)', () {
      final Map<int, String> sirach1 = translations['engwebc']!['Sirach']![1]!;
      expect(sirach1, isNot(contains(5)));
      expect(sirach1, isNot(contains(7)));
      expect(sirach1, contains(6));
    });

    test('drc Esther has 16 chapters including chapter 16', () {
      final Map<int, Map<int, String>> esther = translations['drc']!['Esther']!;
      expect(esther.length, 16);
      expect(esther, contains(16));
    });

    test('cpdv verse total is 35,827', () {
      int total = 0;
      for (final Map<int, Map<int, String>> chapters
          in translations['cpdv']!.values) {
        for (final Map<int, String> verses in chapters.values) {
          total += verses.length;
        }
      }
      expect(total, 35827);
    });
  });
}
