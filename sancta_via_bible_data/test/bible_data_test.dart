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

    test('BibleBookMapping testament helpers should work correctly', () {
      // Test Old Testament boundary
      // Genesis (order 1) is OT
      expect(BibleBookMapping.isOldTestamentByOrder(1), isTrue);
      expect(BibleBookMapping.isOldTestamentByIndex(0), isTrue);

      // Malachi (order 39) is OT
      expect(BibleBookMapping.isOldTestamentByOrder(39), isTrue);
      expect(BibleBookMapping.isOldTestamentByIndex(38), isTrue);

      // Deuterocanonical books (orders 40-46) are OT
      expect(BibleBookMapping.isOldTestamentByOrder(40), isTrue); // Tobit
      expect(BibleBookMapping.isOldTestamentByOrder(46),
          isTrue); // Baruch (last OT)
      expect(BibleBookMapping.isOldTestamentByIndex(45),
          isTrue); // Baruch at index 45

      // Matthew (order 47) is NT (first NT book)
      expect(BibleBookMapping.isOldTestamentByOrder(47), isFalse);
      expect(BibleBookMapping.isOldTestamentByIndex(46), isFalse);

      // Revelation (order 73) is NT
      expect(BibleBookMapping.isOldTestamentByOrder(73), isFalse);
      expect(BibleBookMapping.isOldTestamentByIndex(72), isFalse);

      // Verify counts
      expect(BibleBookMapping.oldTestamentBooks.length, equals(46));
      expect(BibleBookMapping.newTestamentBooks.length, equals(27));
      expect(BibleBookMapping.allBooks.length, equals(73));

      // Verify Baruch metadata (order 46, last OT book)
      final baruch = BibleBookMapping.getByName('Baruch');
      expect(baruch, isNotNull);
      expect(baruch!.order, equals(46));
      expect(baruch.isOldTestament, isTrue);

      // Verify Matthew metadata (order 47, first NT book)
      final matthew = BibleBookMapping.getByName('Matthew');
      expect(matthew, isNotNull);
      expect(matthew!.order, equals(47));
      expect(matthew.isOldTestament, isFalse);
    });
  });
}
