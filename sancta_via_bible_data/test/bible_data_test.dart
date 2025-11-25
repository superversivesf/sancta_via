import 'package:test/test.dart';
import 'package:bible_data/bible_data.dart';

void main() {
  group('Bible Data Package Tests', () {
    test('BibleTranslation enum should have correct values', () {
      expect(BibleTranslation.cpdv.id, equals('cpdv'));
      expect(
          BibleTranslation.cpdv.name, equals('Catholic Public Domain Version'));
      expect(BibleTranslation.cpdv.abbreviation, equals('CPDV'));

      expect(BibleTranslation.fromId('cpdv'), equals(BibleTranslation.cpdv));
      expect(BibleTranslation.fromId('invalid'),
          equals(BibleTranslation.cpdv)); // default

      expect(BibleTranslation.isSupported('drc'), isTrue);
      expect(BibleTranslation.isSupported('invalid'), isFalse);
    });

    test('ScriptureReference.parse should handle various formats', () {
      final ref1 = ScriptureReference.parse('Genesis 1:1');
      expect(ref1.book, equals('Genesis'));
      expect(ref1.chapter, equals(1));
      expect(ref1.startVerse, equals(1));
      expect(ref1.endVerse, equals(1));

      final ref2 = ScriptureReference.parse('John 3:16-17');
      expect(ref2.book, equals('John'));
      expect(ref2.chapter, equals(3));
      expect(ref2.startVerse, equals(16));
      expect(ref2.endVerse, equals(17));

      final ref3 = ScriptureReference.parse('1 Corinthians 13');
      expect(ref3.book, equals('1 Corinthians'));
      expect(ref3.chapter, equals(13));
      expect(ref3.startVerse, isNull);
      expect(ref3.endVerse, isNull);
    });

    test('ScriptureReference factory methods should work correctly', () {
      final chapterRef = ScriptureReference.chapter('Matthew', 5);
      expect(chapterRef.isEntireChapter, isTrue);
      expect(chapterRef.isSingleVerse, isFalse);

      final verseRef = ScriptureReference.verse('Luke', 2, 14);
      expect(verseRef.isEntireChapter, isFalse);
      expect(verseRef.isSingleVerse, isTrue);

      final rangeRef = ScriptureReference.range('Romans', 8, 28, 30);
      expect(rangeRef.isVerseRange, isTrue);
      expect(rangeRef.verseCount, equals(3));
    });

    test('BibleBookMapping should find books correctly', () {
      final genesis = BibleBookMapping.getByName('Genesis');
      expect(genesis, isNotNull);
      expect(genesis!.id, equals('gen'));
      expect(genesis.order, equals(1));
      expect(genesis.isOldTestament, isTrue);

      final matthew = BibleBookMapping.getById('mat');
      expect(matthew, isNotNull);
      expect(matthew!.name, equals('Matthew'));
      expect(matthew.isOldTestament, isFalse);

      final ps = BibleBookMapping.getByAbbreviation('Ps');
      expect(ps, isNotNull);
      expect(ps!.name, equals('Psalms'));

      final found = BibleBookMapping.findBook('1 John');
      expect(found, isNotNull);
      expect(found!.id, equals('1jo'));
    });

    test('ReferenceParser should handle complex references', () {
      expect(ReferenceParser.isValidReference('Genesis 1:1'), isTrue);
      expect(ReferenceParser.isValidReference('invalid reference'), isFalse);

      final normalized = ReferenceParser.normalize('Mt 5:3-12');
      expect(normalized, isNotNull);
      expect(normalized,
          contains('Matthew')); // Should expand abbreviation to full name

      final bookName = ReferenceParser.extractBookName('2 Corinthians 12:9');
      expect(bookName, equals('2 Corinthians'));
    });

    test('BibleVerse should parse from JSON correctly', () {
      final json = {
        'number': 1,
        'text': 'In the beginning was the Word',
      };

      final verse = BibleVerse.fromJson(json);
      expect(verse.number, equals(1));
      expect(verse.text, equals('In the beginning was the Word'));

      final backToJson = verse.toJson();
      expect(backToJson['number'], equals(1));
      expect(backToJson['text'], equals('In the beginning was the Word'));
    });

    test('BibleChapter should manage verses correctly', () {
      final verses = [
        BibleVerse(number: 1, text: 'First verse'),
        BibleVerse(number: 2, text: 'Second verse'),
        BibleVerse(number: 3, text: 'Third verse'),
      ];

      final chapter = BibleChapter(number: 1, verses: verses);

      expect(chapter.getVerseText(2), equals('Second verse'));
      expect(chapter.getVerseText(99), isNull);
      expect(chapter.hasVerse(3), isTrue);
      expect(chapter.hasVerse(4), isFalse);
      expect(chapter.maxVerseNumber, equals(3));

      final range = chapter.getVerseRange(2, 3);
      expect(range.length, equals(2));
      expect(range.first.number, equals(2));
      expect(range.last.number, equals(3));
    });
  });
}
