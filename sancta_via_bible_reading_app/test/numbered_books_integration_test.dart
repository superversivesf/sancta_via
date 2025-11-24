import 'package:flutter_test/flutter_test.dart';
import 'package:bible_data/bible_data.dart';

void main() {
  group('Numbered Books Integration Tests', () {
    
    test('optimized service should handle numbered books correctly', () async {
      // Test that numbered books can be found and have chapters
      
      // Create optimized service (this would normally be done by the provider)
      final loader = OptimizedSqliteBibleLoader(
        databaseAssetPath: 'assets/bibles.db',
      );
      final service = OptimizedBibleService(loader);
      
      // Test books with numbers that were previously failing
      final testBooks = [
        '1 Samuel', '2 Samuel', '1 Kings', '2 Kings',
        '1 Chronicles', '2 Chronicles', '1 Corinthians', '2 Corinthians',
        '1 Thessalonians', '2 Thessalonians', '1 Timothy', '2 Timothy',
        '1 Peter', '2 Peter', '1 John', '2 John', '3 John'
      ];
      
      final translation = BibleTranslation.cpdv;
      
      for (final bookName in testBooks) {
        // Test that book exists
        final hasBook = await service.hasBook(bookName, translation);
        expect(hasBook, isTrue, reason: 'Book "$bookName" should exist in ${translation.name}');
        
        // Test that book has chapters (should be > 0)
        final chapterCount = await service.getChapterCount(bookName, translation);
        expect(chapterCount, greaterThan(0), 
               reason: 'Book "$bookName" should have chapters, but got $chapterCount');
        
        print('✓ $bookName: $chapterCount chapters');
      }
    });

    test('should be able to load actual chapters from numbered books', () async {
      final loader = OptimizedSqliteBibleLoader(
        databaseAssetPath: 'assets/bibles.db',
      );
      final service = OptimizedBibleService(loader);
      final translation = BibleTranslation.cpdv;
      
      // Test loading actual chapter content from numbered books
      final testCases = [
        {'book': '1 Samuel', 'chapter': 1},
        {'book': '2 Samuel', 'chapter': 1},
        {'book': '1 Corinthians', 'chapter': 1},
        {'book': '2 Corinthians', 'chapter': 1},
        {'book': '1 John', 'chapter': 1},
      ];
      
      for (final testCase in testCases) {
        final bookName = testCase['book'] as String;
        final chapter = testCase['chapter'] as int;
        
        final reference = ScriptureReference.chapter(bookName, chapter);
        final content = await service.getScriptureContent(reference, translation);
        
        expect(content.found, isTrue, 
               reason: 'Should find content for $bookName chapter $chapter');
        expect(content.text.isNotEmpty, isTrue,
               reason: 'Content for $bookName chapter $chapter should not be empty');
        
        print('✓ $bookName $chapter: ${content.text.length} characters');
      }
    });

    test('book name normalization debug should show conversion', () {
      final testBooks = ['1 Samuel', '2 Corinthians', '3 John'];
      
      for (final book in testBooks) {
        final debugInfo = BookNameNormalizer.getDebugInfo(book);
        print('\nBook: $book');
        print('  Database format: ${debugInfo['database_format']}');
        print('  Display format: ${debugInfo['display_format']}');
        
        // Verify the conversion is working
        expect(debugInfo['database_format'], isNot(equals(book)),
               reason: 'Database format should be different (Roman numerals)');
        expect(debugInfo['display_format'], equals(book),
               reason: 'Display format should match original');
      }
    });
  });
}
