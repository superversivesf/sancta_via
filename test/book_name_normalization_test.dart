import 'package:flutter_test/flutter_test.dart';
import 'package:bible_data/bible_data.dart';

void main() {
  group('Book Name Normalization Tests', () {
    
    test('should convert Arabic numerals to Roman numerals for database queries', () {
      // Test conversion from user input to database format
      expect(BookNameNormalizer.toDatabaseFormat('1 Samuel'), equals('I Samuel'));
      expect(BookNameNormalizer.toDatabaseFormat('2 Samuel'), equals('II Samuel'));
      expect(BookNameNormalizer.toDatabaseFormat('1 Corinthians'), equals('I Corinthians'));
      expect(BookNameNormalizer.toDatabaseFormat('2 Corinthians'), equals('II Corinthians'));
      expect(BookNameNormalizer.toDatabaseFormat('1 Timothy'), equals('I Timothy'));
      expect(BookNameNormalizer.toDatabaseFormat('2 Timothy'), equals('II Timothy'));
      expect(BookNameNormalizer.toDatabaseFormat('1 Peter'), equals('I Peter'));
      expect(BookNameNormalizer.toDatabaseFormat('2 Peter'), equals('II Peter'));
      expect(BookNameNormalizer.toDatabaseFormat('1 John'), equals('I John'));
      expect(BookNameNormalizer.toDatabaseFormat('2 John'), equals('II John'));
      expect(BookNameNormalizer.toDatabaseFormat('3 John'), equals('III John'));
    });

    test('should convert Roman numerals to Arabic numerals for display', () {
      // Test conversion from database format to user display
      expect(BookNameNormalizer.toDisplayFormat('I Samuel'), equals('1 Samuel'));
      expect(BookNameNormalizer.toDisplayFormat('II Samuel'), equals('2 Samuel'));
      expect(BookNameNormalizer.toDisplayFormat('I Corinthians'), equals('1 Corinthians'));
      expect(BookNameNormalizer.toDisplayFormat('II Corinthians'), equals('2 Corinthians'));
      expect(BookNameNormalizer.toDisplayFormat('I Timothy'), equals('1 Timothy'));
      expect(BookNameNormalizer.toDisplayFormat('II Timothy'), equals('2 Timothy'));
      expect(BookNameNormalizer.toDisplayFormat('I Peter'), equals('1 Peter'));
      expect(BookNameNormalizer.toDisplayFormat('II Peter'), equals('2 Peter'));
      expect(BookNameNormalizer.toDisplayFormat('I John'), equals('1 John'));
      expect(BookNameNormalizer.toDisplayFormat('II John'), equals('2 John'));
      expect(BookNameNormalizer.toDisplayFormat('III John'), equals('3 John'));
    });

    test('should leave non-numbered books unchanged', () {
      // Books without numbers should pass through unchanged
      expect(BookNameNormalizer.toDatabaseFormat('Genesis'), equals('Genesis'));
      expect(BookNameNormalizer.toDatabaseFormat('Exodus'), equals('Exodus'));
      expect(BookNameNormalizer.toDatabaseFormat('Matthew'), equals('Matthew'));
      expect(BookNameNormalizer.toDatabaseFormat('John'), equals('John'));
      expect(BookNameNormalizer.toDatabaseFormat('Revelation'), equals('Revelation'));
      
      expect(BookNameNormalizer.toDisplayFormat('Genesis'), equals('Genesis'));
      expect(BookNameNormalizer.toDisplayFormat('Exodus'), equals('Exodus'));
      expect(BookNameNormalizer.toDisplayFormat('Matthew'), equals('Matthew'));
      expect(BookNameNormalizer.toDisplayFormat('John'), equals('John'));
      expect(BookNameNormalizer.toDisplayFormat('Revelation'), equals('Revelation'));
    });

    test('should handle round-trip conversion correctly', () {
      final testBooks = [
        '1 Samuel', '2 Samuel', '1 Kings', '2 Kings',
        '1 Chronicles', '2 Chronicles', '1 Corinthians', '2 Corinthians',
        '1 Thessalonians', '2 Thessalonians', '1 Timothy', '2 Timothy',
        '1 Peter', '2 Peter', '1 John', '2 John', '3 John'
      ];
      
      for (final book in testBooks) {
        // Convert to database format and back to display format
        final dbFormat = BookNameNormalizer.toDatabaseFormat(book);
        final backToDisplay = BookNameNormalizer.toDisplayFormat(dbFormat);
        
        expect(backToDisplay, equals(book), 
               reason: 'Round-trip conversion failed for $book: $book → $dbFormat → $backToDisplay');
      }
    });

    test('should recognize equivalent book names', () {
      // Test that Arabic and Roman versions are considered equivalent
      expect(BookNameNormalizer.areEquivalent('1 Samuel', 'I Samuel'), isTrue);
      expect(BookNameNormalizer.areEquivalent('2 Corinthians', 'II Corinthians'), isTrue);
      expect(BookNameNormalizer.areEquivalent('3 John', 'III John'), isTrue);
      
      // Test that different books are not equivalent
      expect(BookNameNormalizer.areEquivalent('1 Samuel', '2 Samuel'), isFalse);
      expect(BookNameNormalizer.areEquivalent('1 Corinthians', '2 Corinthians'), isFalse);
    });

    test('should provide all variations for fuzzy matching', () {
      final variations1Samuel = BookNameNormalizer.getAllVariations('1 Samuel');
      expect(variations1Samuel, contains('1 Samuel'));
      expect(variations1Samuel, contains('I Samuel'));
      
      final variationsISamuel = BookNameNormalizer.getAllVariations('I Samuel');
      expect(variationsISamuel, contains('1 Samuel'));
      expect(variationsISamuel, contains('I Samuel'));
    });

    test('should handle common book name edge cases', () {
      // Test books that commonly have variations
      expect(BookNameNormalizer.toDatabaseFormat('Revelation'), equals('Revelation'));
      expect(BookNameNormalizer.toDatabaseFormat('Revelation of John'), equals('Revelation'));
    });

    test('should provide useful debug information', () {
      final debugInfo = BookNameNormalizer.getDebugInfo('1 Corinthians');
      
      expect(debugInfo['original'], equals('1 Corinthians'));
      expect(debugInfo['roman'], equals('I Corinthians'));
      expect(debugInfo['arabic'], equals('1 Corinthians'));
      expect(debugInfo['database_format'], equals('I Corinthians'));
      expect(debugInfo['display_format'], equals('1 Corinthians'));
    });
  });
}
