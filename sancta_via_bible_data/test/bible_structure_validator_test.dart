import 'package:bible_data/src/utils/bible_structure_validator.dart';
import 'package:test/test.dart';

/// Builds a per-translation entry of an expected_structure.json fixture.
Map<String, dynamic> _translation({
  required List<String> order,
  required Map<String, Map<String, int>> chapters,
  List<Map<String, dynamic>> referenceVerses = const <Map<String, dynamic>>[],
  Map<String, Map<String, List<int>>> verseNumbers =
      const <String, Map<String, List<int>>>{},
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
    if (verseNumbers.isNotEmpty) 'verseNumbers': verseNumbers,
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

  group('validateBibleStructure — verseNumbers exception chapters', () {
    /// A Sirach-1-shaped fixture: the manifest pins a verse-count of 4 but the
    /// verseNumbers exception chapter lists exactly [1, 2, 3, 4, 6, 8]
    /// (verses 5 and 7 are footnote-only in engwebc Sirach 1).
    final Map<String, Map<String, Map<int, Map<int, String>>>> validData =
        <String, Map<String, Map<int, Map<int, String>>>>{
          'engwebc': <String, Map<int, Map<int, String>>>{
            'Sirach': <int, Map<int, String>>{
              1: <int, String>{
                1: 'All wisdom comes from the Lord.',
                2: 'Who can count the sand of the seas?',
                3: 'Who will search out the height of the sky?',
                4: 'Wisdom has been created before all things,',
                6: 'To whom has the root of wisdom been revealed?',
                8: 'To whom has the knowledge of wisdom been revealed?',
              },
            },
          },
        };
    final Map<String, dynamic> manifestForValidData = _expectedStructure(
      <String, dynamic>{
        'engwebc': _translation(
          order: const <String>['Sirach'],
          chapters: const <String, Map<String, int>>{
            'Sirach': <String, int>{'1': 6},
          },
          verseNumbers: const <String, Map<String, List<int>>>{
            'Sirach': <String, List<int>>{
              '1': <int>[1, 2, 3, 4, 6, 8],
            },
          },
        ),
      },
    );

    /// Plain-rule-clean data (contiguous 1..3) for shape tests that inject
    /// broken `verseNumbers` elsewhere, isolating the shape error.
    final Map<String, Map<String, Map<int, Map<int, String>>>> plainRuleData =
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

    test(
      'accepts a listed chapter whose data matches the pinned list exactly',
      () {
        final List<String> errors = validateBibleStructure(
          translations: validData,
          expectedStructure: manifestForValidData,
        );

        expect(errors, isEmpty);
      },
    );

    test('flags a data verse that is not listed for a listed chapter', () {
      final Map<String, Map<String, Map<int, Map<int, String>>>> withExtra =
          <String, Map<String, Map<int, Map<int, String>>>>{
            'engwebc': <String, Map<int, Map<int, String>>>{
              'Sirach': <int, Map<int, String>>{
                1: <int, String>{
                  1: 'All wisdom comes from the Lord.',
                  2: 'Who can count the sand of the seas?',
                  3: 'Who will search out the height of the sky?',
                  4: 'Wisdom has been created before all things,',
                  5: 'A footnote-only verse wrongly emitted as data.',
                  6: 'To whom has the root of wisdom been revealed?',
                  8: 'To whom has the knowledge of wisdom been revealed?',
                },
              },
            },
          };

      final List<String> errors = validateBibleStructure(
        translations: withExtra,
        expectedStructure: manifestForValidData,
      );

      expect(
        errors,
        contains(
          'engwebc Sirach 1: verseNumbers unlisted verse 5 '
          '(listed exactly [1, 2, 3, 4, 6, 8])',
        ),
      );
      expect(errors, hasLength(1));
    });

    test('flags a listed verse missing from the data of a listed chapter', () {
      final Map<String, Map<String, Map<int, Map<int, String>>>> withGap =
          <String, Map<String, Map<int, Map<int, String>>>>{
            'engwebc': <String, Map<int, Map<int, String>>>{
              'Sirach': <int, Map<int, String>>{
                1: <int, String>{
                  1: 'All wisdom comes from the Lord.',
                  2: 'Who can count the sand of the seas?',
                  3: 'Who will search out the height of the sky?',
                  4: 'Wisdom has been created before all things,',
                  8: 'To whom has the knowledge of wisdom been revealed?',
                },
              },
            },
          };

      final List<String> errors = validateBibleStructure(
        translations: withGap,
        expectedStructure: manifestForValidData,
      );

      expect(
        errors,
        contains('engwebc Sirach 1: verseNumbers missing listed verse 6'),
      );
      expect(errors, hasLength(1));
    });

    test('still flags a listed chapter that is absent from the data', () {
      final Map<String, Map<String, Map<int, Map<int, String>>>> empty =
          <String, Map<String, Map<int, Map<int, String>>>>{
            'engwebc': <String, Map<int, Map<int, String>>>{
              'Sirach': <int, Map<int, String>>{},
            },
          };

      final List<String> errors = validateBibleStructure(
        translations: empty,
        expectedStructure: manifestForValidData,
      );

      expect(
        errors,
        contains('engwebc Sirach 1: missing chapter (required by manifest)'),
      );
      expect(errors, hasLength(1));
    });

    test('keeps contiguous numbering enforcement and footnote-only failures '
        'for chapters NOT listed', () {
      final Map<String, dynamic> manifest = _expectedStructure(
        <String, dynamic>{
          'engwebc': _translation(
            order: const <String>['Sirach', 'Psalms'],
            chapters: const <String, Map<String, int>>{
              'Sirach': <String, int>{'1': 6},
              'Psalms': <String, int>{'118': 3},
            },
            verseNumbers: const <String, Map<String, List<int>>>{
              'Sirach': <String, List<int>>{
                '1': <int>[1, 2, 3, 4, 6, 8],
              },
            },
          ),
        },
      );
      final Map<String, Map<String, Map<int, Map<int, String>>>> data =
          <String, Map<String, Map<int, Map<int, String>>>>{
            'engwebc': <String, Map<int, Map<int, String>>>{
              'Sirach': validData['engwebc']!['Sirach']!,
              'Psalms': <int, Map<int, String>>{
                // Psalms 118 is NOT listed: verse 3 absent = footnote-only
                // marker treated as a hard gap.
                118: <int, String>{
                  1: 'Blessed are the undefiled in the way.',
                  2: 'Blessed are they that search his testimonies.',
                },
              },
            },
          };

      final List<String> errors = validateBibleStructure(
        translations: data,
        expectedStructure: manifest,
      );

      expect(
        errors,
        contains('engwebc Psalms 118: contiguous numbering gap at verse 3'),
      );
      expect(errors, hasLength(1));
    });

    test('still reports empty verse text inside a listed chapter', () {
      final Map<String, Map<String, Map<int, Map<int, String>>>> withEmpty =
          <String, Map<String, Map<int, Map<int, String>>>>{
            'engwebc': <String, Map<int, Map<int, String>>>{
              'Sirach': <int, Map<int, String>>{
                1: <int, String>{
                  1: 'All wisdom comes from the Lord.',
                  2: '   ',
                  3: 'Who will search out the height of the sky?',
                  4: 'Wisdom has been created before all things,',
                  6: 'To whom has the root of wisdom been revealed?',
                  8: 'To whom has the knowledge of wisdom been revealed?',
                },
              },
            },
          };

      final List<String> errors = validateBibleStructure(
        translations: withEmpty,
        expectedStructure: manifestForValidData,
      );

      expect(errors, contains('engwebc Sirach 1:2: empty verse text'));
      expect(errors, hasLength(1));
    });

    test('reports malformed verseNumbers entries', () {
      final Map<String, dynamic> malformedMap = _expectedStructure(
        <String, dynamic>{
          'engwebc': _translation(
            order: const <String>['Genesis'],
            chapters: const <String, Map<String, int>>{
              'Genesis': <String, int>{'1': 3},
            },
          ),
        },
      );
      malformedMap['translations']['engwebc']['verseNumbers'] =
          <String, dynamic>{'not-a-list': 'Genesis'};

      final List<String> errors = validateBibleStructure(
        translations: plainRuleData,
        expectedStructure: malformedMap,
      );

      expect(
        errors,
        contains('engwebc: malformed verseNumbers entry for "not-a-list"'),
      );
      expect(errors, hasLength(1));
    });

    test('reports non-integer or non-ascending verseNumbers lists', () {
      final Map<String, dynamic> malformedList = _expectedStructure(
        <String, dynamic>{
          'engwebc': _translation(
            order: const <String>['Genesis'],
            chapters: const <String, Map<String, int>>{
              'Genesis': <String, int>{'1': 3},
            },
          ),
        },
      );
      malformedList['translations']['engwebc']['verseNumbers'] =
          <String, dynamic>{
            'Genesis': <String, dynamic>{
              '1': <Object>[1, 2, '3', 5, 4],
            },
          };

      final List<String> errors = validateBibleStructure(
        translations: plainRuleData,
        expectedStructure: malformedList,
      );

      expect(
        errors,
        contains(
          'engwebc Genesis 1: malformed verseNumbers entry '
          '(ascending non-empty integer list expected)',
        ),
      );
      expect(errors, hasLength(1));
    });

    test('reports malformed verseNumbers chapter keys', () {
      final Map<String, dynamic> malformedKey = _expectedStructure(
        <String, dynamic>{
          'engwebc': _translation(
            order: const <String>['Genesis'],
            chapters: const <String, Map<String, int>>{
              'Genesis': <String, int>{'1': 3},
            },
          ),
        },
      );
      malformedKey['translations']['engwebc']['verseNumbers'] =
          <String, dynamic>{
            'Genesis': <String, dynamic>{
              'P': <int>[1, 2, 3],
            },
          };

      final List<String> errors = validateBibleStructure(
        translations: plainRuleData,
        expectedStructure: malformedKey,
      );

      expect(
        errors,
        contains(
          'engwebc Genesis: malformed verseNumbers chapter key "P" '
          '(decimal string expected)',
        ),
      );
      expect(errors, hasLength(1));
    });
  });
}
