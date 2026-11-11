import 'package:bible_data/src/utils/bible_structure_validator.dart';
import 'package:test/test.dart';

/// Builds a per-translation entry of an expected_structure.json fixture.
Map<String, dynamic> _translation({
  required List<String> order,
  required Map<String, Map<String, int>> chapters,
  List<Map<String, dynamic>> referenceVerses = const <Map<String, dynamic>>[],
}) {
  final chaptersJson = <String, dynamic>{};
  for (final MapEntry<String, Map<String, int>> book in chapters.entries) {
    final verseCounts = <String, dynamic>{};
    for (final MapEntry<String, int> chapter in book.value.entries) {
      verseCounts[chapter.key] = chapter.value;
    }
    chaptersJson[book.key] = verseCounts;
  }
  return <String, dynamic>{
    'order': order,
    'chapters': chaptersJson,
    'referenceVerses': referenceVerses,
  };
}

/// Builds a fixture shaped like a parsed expected_structure.json.
Map<String, dynamic> _expectedStructure(Map<String, dynamic> translations) {
  return <String, dynamic>{'translations': translations};
}

void main() {
  group('validateBibleStructure', () {
    test('returns empty list for a valid two-translation fixture', () {
      final Map<String, Map<String, Map<int, Map<int, String>>>> translations =
          <String, Map<String, Map<int, Map<int, String>>>>{
            'engwebc': <String, Map<int, Map<int, String>>>{
              'Genesis': <int, Map<int, String>>{
                1: <int, String>{
                  1: 'In the beginning God created heaven.',
                  2: 'And the earth was void and empty.',
                  3: 'And God said: Be light made.',
                },
              },
              'Psalms': <int, Map<int, String>>{
                118: <int, String>{
                  1: 'Blessed are the undefiled in the way.',
                  2: 'Blessed are they that search his testimonies.',
                  3: 'For they that work iniquity have not walked in his ways.',
                },
              },
            },
            'cpdv': <String, Map<int, Map<int, String>>>{
              'Genesis': <int, Map<int, String>>{
                1: <int, String>{
                  1: 'In the beginning God created the heavens.',
                  2: 'And the earth was without form.',
                  3: 'And God said, Let there be light.',
                },
              },
              'Psalms': <int, Map<int, String>>{
                118: <int, String>{
                  1: 'Blessed are those whose way is blameless.',
                  2: 'Blessed are those who keep his testimonies.',
                  3: 'They also do no iniquity.',
                },
              },
            },
          };
      final Map<String, dynamic> expectedStructure = _expectedStructure(
        <String, dynamic>{
          'engwebc': _translation(
            order: const <String>['Genesis', 'Psalms'],
            chapters: const <String, Map<String, int>>{
              'Genesis': <String, int>{'1': 3},
              'Psalms': <String, int>{'118': 3},
            },
            referenceVerses: <Map<String, dynamic>>[
              <String, dynamic>{
                'book': 'Psalms',
                'chapter': 118,
                'verse': 1,
                'startsWith': 'Blessed are the undefiled in the way.',
              },
            ],
          ),
          'cpdv': _translation(
            order: const <String>['Genesis', 'Psalms'],
            chapters: const <String, Map<String, int>>{
              'Genesis': <String, int>{'1': 3},
              'Psalms': <String, int>{'118': 3},
            },
          ),
        },
      );

      final List<String> errors = validateBibleStructure(
        translations: translations,
        expectedStructure: expectedStructure,
      );

      expect(errors, isEmpty);
    });

    test('reports a manifest book missing from the data', () {
      final Map<String, Map<String, Map<int, Map<int, String>>>> translations =
          <String, Map<String, Map<int, Map<int, String>>>>{
            'engwebc': <String, Map<int, Map<int, String>>>{
              'Genesis': <int, Map<int, String>>{
                1: <int, String>{
                  1: 'In the beginning God created heaven.',
                  2: 'And the earth was void and empty.',
                  3: 'And God said: Be light made.',
                },
              },
            },
          };
      final Map<String, dynamic> expectedStructure = _expectedStructure(
        <String, dynamic>{
          'engwebc': _translation(
            order: const <String>['Genesis', 'Psalms'],
            chapters: const <String, Map<String, int>>{
              'Genesis': <String, int>{'1': 3},
              'Psalms': <String, int>{'118': 3},
            },
          ),
        },
      );

      final List<String> errors = validateBibleStructure(
        translations: translations,
        expectedStructure: expectedStructure,
      );

      expect(errors, isNotEmpty);
      expect(
        errors,
        contains('engwebc Psalms: missing book (required by manifest order)'),
      );
    });

    test('reports a chapter whose verse count mismatches the manifest', () {
      final Map<String, Map<String, Map<int, Map<int, String>>>> translations =
          <String, Map<String, Map<int, Map<int, String>>>>{
            'engwebc': <String, Map<int, Map<int, String>>>{
              'Genesis': <int, Map<int, String>>{
                1: <int, String>{
                  1: 'In the beginning God created heaven.',
                  2: 'And the earth was void and empty.',
                },
              },
            },
          };
      final Map<String, dynamic> expectedStructure = _expectedStructure(
        <String, dynamic>{
          'engwebc': _translation(
            order: const <String>['Genesis'],
            chapters: const <String, Map<String, int>>{
              'Genesis': <String, int>{'1': 3},
            },
          ),
        },
      );

      final List<String> errors = validateBibleStructure(
        translations: translations,
        expectedStructure: expectedStructure,
      );

      expect(errors, isNotEmpty);
      expect(errors, everyElement(contains('engwebc Genesis 1:')));
    });

    test('reports a contiguous-numbering gap in verse keys', () {
      final Map<String, Map<String, Map<int, Map<int, String>>>> translations =
          <String, Map<String, Map<int, Map<int, String>>>>{
            'engwebc': <String, Map<int, Map<int, String>>>{
              'Psalms': <int, Map<int, String>>{
                118: <int, String>{
                  1: 'Blessed are the undefiled in the way.',
                  2: 'Blessed are they that search his testimonies.',
                  4: 'For they that work iniquity have not walked in his ways.',
                },
              },
            },
          };
      final Map<String, dynamic> expectedStructure = _expectedStructure(
        <String, dynamic>{
          'engwebc': _translation(
            order: const <String>['Psalms'],
            chapters: const <String, Map<String, int>>{
              'Psalms': <String, int>{'118': 4},
            },
          ),
        },
      );

      final List<String> errors = validateBibleStructure(
        translations: translations,
        expectedStructure: expectedStructure,
      );

      expect(errors, isNotEmpty);
      expect(
        errors,
        contains('engwebc Psalms 118: contiguous numbering gap at verse 3'),
      );
    });

    test('reports empty or whitespace-only verse text', () {
      final Map<String, Map<String, Map<int, Map<int, String>>>> translations =
          <String, Map<String, Map<int, Map<int, String>>>>{
            'engwebc': <String, Map<int, Map<int, String>>>{
              'Genesis': <int, Map<int, String>>{
                1: <int, String>{
                  1: 'In the beginning God created heaven.',
                  2: '   ',
                  3: 'And God said: Be light made.',
                },
              },
            },
          };
      final Map<String, dynamic> expectedStructure = _expectedStructure(
        <String, dynamic>{
          'engwebc': _translation(
            order: const <String>['Genesis'],
            chapters: const <String, Map<String, int>>{
              'Genesis': <String, int>{'1': 3},
            },
          ),
        },
      );

      final List<String> errors = validateBibleStructure(
        translations: translations,
        expectedStructure: expectedStructure,
      );

      expect(errors, isNotEmpty);
      expect(errors, contains('engwebc Genesis 1:2: empty verse text'));
    });

    test('reports a USFM marker leaked into verse text', () {
      final Map<String, Map<String, Map<int, Map<int, String>>>> translations =
          <String, Map<String, Map<int, Map<int, String>>>>{
            'engwebc': <String, Map<int, Map<int, String>>>{
              'Genesis': <int, Map<int, String>>{
                1: <int, String>{
                  1: 'In the beginning God created heaven.',
                  2: 'He said \\d text',
                  3: 'And God said: Be light made.',
                },
              },
            },
          };
      final Map<String, dynamic> expectedStructure = _expectedStructure(
        <String, dynamic>{
          'engwebc': _translation(
            order: const <String>['Genesis'],
            chapters: const <String, Map<String, int>>{
              'Genesis': <String, int>{'1': 3},
            },
          ),
        },
      );

      final List<String> errors = validateBibleStructure(
        translations: translations,
        expectedStructure: expectedStructure,
      );

      expect(errors, isNotEmpty);
      expect(
        errors,
        contains('engwebc Genesis 1:2: backslash in text (USFM marker leak)'),
      );
    });

    test('reports a reference-verse pin that does not match the text', () {
      final Map<String, Map<String, Map<int, Map<int, String>>>> translations =
          <String, Map<String, Map<int, Map<int, String>>>>{
            'engwebc': <String, Map<int, Map<int, String>>>{
              'Genesis': <int, Map<int, String>>{
                1: <int, String>{1: 'In the beginning God created heaven.'},
              },
            },
          };
      final Map<String, dynamic> expectedStructure = _expectedStructure(
        <String, dynamic>{
          'engwebc': _translation(
            order: const <String>['Genesis'],
            chapters: const <String, Map<String, int>>{
              'Genesis': <String, int>{'1': 1},
            },
            referenceVerses: <Map<String, dynamic>>[
              <String, dynamic>{
                'book': 'Genesis',
                'chapter': 1,
                'verse': 1,
                'startsWith': 'For God so loved',
              },
            ],
          ),
        },
      );

      final List<String> errors = validateBibleStructure(
        translations: translations,
        expectedStructure: expectedStructure,
      );

      expect(errors, isNotEmpty);
      expect(
        errors,
        contains(
          'engwebc Genesis 1:1: reference-verse text mismatch '
          '(expected prefix "For God so loved")',
        ),
      );
    });
  });
}
