import 'package:flutter_test/flutter_test.dart';
import 'package:saint_data/src/utils/normalization.dart';

void main() {
  group('normalizeSearchText', () {
    test('lowers case and folds diacritics', () {
      expect(
        normalizeSearchText('St. Thérèse of Lisieux'),
        'st therese of lisieux',
      );
    });

    test('folds common Latin-1/Latin-Extended diacritics', () {
      expect(normalizeSearchText('ÄÖÜ çñ'), 'aou cn');
    });

    test('strips punctuation and symbols', () {
      expect(normalizeSearchText('"Émile\'s —  Café!"'), 'emiles cafe');
    });

    test('collapses runs of spaces and trims', () {
      expect(normalizeSearchText('   '), '');
      expect(normalizeSearchText('  a   b  '), 'a b');
    });

    test('keeps digits and lowercase letters', () {
      expect(normalizeSearchText('John 23rd XII3'), 'john 23rd xii3');
    });
  });

  group('tokenizeSearchQuery', () {
    test('normalizes, splits on spaces, and drops empties', () {
      expect(tokenizeSearchQuery('"Émile\'s —  Café!"'), <String>[
        'emiles',
        'cafe',
      ]);
    });

    test('returns empty list for empty and whitespace-only queries', () {
      expect(tokenizeSearchQuery(''), <String>[]);
      expect(tokenizeSearchQuery('   '), <String>[]);
    });

    test('splits each word of a multi-word query', () {
      expect(tokenizeSearchQuery('Thérèse of Lisieux'), <String>[
        'therese',
        'of',
        'lisieux',
      ]);
    });
  });
}
