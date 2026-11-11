import 'package:test/test.dart';

import '../tools/build_bibles/lib/usfm_parser.dart';

void main() {
  group('parseUsfmBook', () {
    test('parses the brief fixture: inline \\w stripped, footnote body '
        'dropped, inline \\v after the footnote split into a new verse', () {
      const String fixture = r'''
\id PSA
\d A superscription to be skipped
\c 18
\v 1 He said \w love|strong="H7902"\w* to them
\c 19
\v 1 Clouds darkened. \f + \fr 4:1 \ft footnote text\f* \v 2 Then light.
''';
      final List<UsfmChapter> chapters = parseUsfmBook(fixture);

      expect(chapters.map((UsfmChapter c) => c.number), <int>[18, 19]);
      expect(chapters[0].verses, hasLength(1));
      expect(chapters[0].verses[0].$1, 1);
      expect(chapters[0].verses[0].$2, 'He said love to them');

      expect(chapters[1].verses, hasLength(2));
      expect(chapters[1].verses[0].$1, 1);
      expect(chapters[1].verses[0].$2, 'Clouds darkened.');
      expect(chapters[1].verses[1].$1, 2);
      expect(chapters[1].verses[1].$2, 'Then light.');

      for (final UsfmChapter chapter in chapters) {
        for (final (int, String) verse in chapter.verses) {
          expect(verse.$2, isNot(contains('\\')));
          expect(verse.$2, isNot(contains('superscription')));
        }
      }
    });

    test('joins a \\q2 poetry continuation line into the prior verse', () {
      const String fixture = r'''
\id PSA
\c 19
\v 2 The heavens declare the glory of God.
\q2 and the firmament shows his handiwork.
\v 3 Day after day they utter speech.
''';
      final List<UsfmChapter> chapters = parseUsfmBook(fixture);

      expect(chapters, hasLength(1));
      expect(chapters[0].verses, hasLength(2));
      expect(
        chapters[0].verses[0].$2,
        'The heavens declare the glory of God. '
        'and the firmament shows his handiwork.',
      );
      expect(chapters[0].verses[1].$2, 'Day after day they utter speech.');
    });

    test('treats a \\d acrostic header line as a verse terminator, never as '
        'verse text', () {
      const String fixture = r'''
\id PSA
\c 119
\v 1 Blessed are the undefiled in the way.
\d ALEPH
\v 2 Blessed are they that search his testimonies.
''';
      final List<UsfmChapter> chapters = parseUsfmBook(fixture);

      expect(chapters, hasLength(1));
      expect(chapters[0].verses, hasLength(2));
      expect(chapters[0].verses[0].$1, 1);
      expect(chapters[0].verses[0].$2, 'Blessed are the undefiled in the way.');
      expect(chapters[0].verses[1].$1, 2);
      expect(
        chapters[0].verses[1].$2,
        'Blessed are they that search his testimonies.',
      );
      for (final (int, String) verse in chapters[0].verses) {
        expect(verse.$2, isNot(contains('ALEPH')));
      }
    });

    test('keeps the word when \\w carries a strong attribute and preserves '
        'the possessive suffix after \\w*', () {
      const String fixture = r'''
\id PSA
\c 1
\v 1 The \w word|strong="H3068"\w*'s light endures.
''';
      final List<UsfmChapter> chapters = parseUsfmBook(fixture);

      expect(chapters[0].verses, hasLength(1));
      expect(chapters[0].verses[0].$2, 'The word\'s light endures.');
      expect(chapters[0].verses[0].$2, isNot(contains('strong')));
      expect(chapters[0].verses[0].$2, isNot(contains('H3068')));
    });

    test('produces no verse for note-only markers, single or composite', () {
      const String fixture = r'''
\id SIR
\c 1
\v 5 \f + \fr 1:5 \ft Verse 5 is omitted by the best authorities.\f*
\v 6 To whom has the root of wisdom been revealed?
\c 11
\v 15-16 \f + \fr 11:15-16 \ft Verses 15 and 16 are omitted.\f*
\v 17 A heart that is glad is a life with cheerfulness.
''';
      final List<UsfmChapter> chapters = parseUsfmBook(fixture);

      expect(chapters, hasLength(2));
      expect(chapters[0].verses, hasLength(1));
      expect(chapters[0].verses[0].$1, 6);
      expect(
        chapters[0].verses[0].$2,
        'To whom has the root of wisdom been revealed?',
      );

      expect(chapters[1].verses, hasLength(1));
      expect(chapters[1].verses[0].$1, 17);
    });

    test('ignores text before the first \\v of a chapter and drops '
        'multi-line footnotes and cross-references', () {
      const String fixture = r'''
\id SIR
\c 3
\p This paragraph is not a verse.
\d A chapter heading note
\q1
\v 1 He rose.
\f +
\fr 3:5 \ft a footnote spanning
two lines\f*
\x + \xo 3:5 \xt cross-ref text\x*
\v 2 Day after day.
''';
      final List<UsfmChapter> chapters = parseUsfmBook(fixture);

      expect(chapters, hasLength(1));
      expect(chapters[0].verses, hasLength(2));
      expect(chapters[0].verses[0].$1, 1);
      expect(chapters[0].verses[0].$2, 'He rose.');
      expect(chapters[0].verses[1].$1, 2);
      expect(chapters[0].verses[1].$2, 'Day after day.');
      for (final (int, String) verse in chapters[0].verses) {
        expect(verse.$2, isNot(contains('paragraph')));
        expect(verse.$2, isNot(contains('heading')));
        expect(verse.$2, isNot(contains('footnote')));
        expect(verse.$2, isNot(contains('cross-ref')));
      }
    });

    test('throws on a composite verse label that carries text', () {
      const String fixture = r'''
\id SIR
\c 11
\v 15-16 Merged verses with real content.
''';
      expect(() => parseUsfmBook(fixture), throwsFormatException);
    });

    test('throws on a duplicate verse label within a chapter', () {
      const String fixture = r'''
\id GEN
\c 1
\v 1 First occurrence.
\v 1 Duplicate occurrence.
''';
      expect(() => parseUsfmBook(fixture), throwsFormatException);
    });

    test('throws on a duplicate chapter number', () {
      const String fixture = r'''
\id GEN
\c 1
\v 1 Some verse.
\c 1
\v 2 Another verse.
''';
      expect(() => parseUsfmBook(fixture), throwsFormatException);
    });
  });
}
