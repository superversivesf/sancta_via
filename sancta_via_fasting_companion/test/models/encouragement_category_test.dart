import 'package:flutter_test/flutter_test.dart';
import 'package:sancta_via_fasting_companion/models/encouragement_category.dart';

void main() {
  group('EncouragementCategory', () {
    test('should have correct enum values', () {
      expect(EncouragementCategory.values.length, 3);
      expect(
        EncouragementCategory.values,
        contains(EncouragementCategory.scripture),
      );
      expect(
        EncouragementCategory.values,
        contains(EncouragementCategory.saintQuote),
      );
      expect(
        EncouragementCategory.values,
        contains(EncouragementCategory.prayer),
      );
    });

    test('toJson should return correct string', () {
      expect(EncouragementCategory.scripture.toJson(), 'scripture');
      expect(EncouragementCategory.saintQuote.toJson(), 'saintQuote');
      expect(EncouragementCategory.prayer.toJson(), 'prayer');
    });

    test('fromJson should parse correctly', () {
      expect(
        EncouragementCategory.fromJson('scripture'),
        EncouragementCategory.scripture,
      );
      expect(
        EncouragementCategory.fromJson('saintQuote'),
        EncouragementCategory.saintQuote,
      );
      expect(
        EncouragementCategory.fromJson('prayer'),
        EncouragementCategory.prayer,
      );
    });

    test('fromJson should default to scripture for invalid input', () {
      expect(
        EncouragementCategory.fromJson('invalid'),
        EncouragementCategory.scripture,
      );
      expect(EncouragementCategory.fromJson(''), EncouragementCategory.scripture);
    });

    test('displayName should return correct values', () {
      expect(EncouragementCategory.scripture.displayName, 'Scripture');
      expect(EncouragementCategory.saintQuote.displayName, 'Saint Quote');
      expect(EncouragementCategory.prayer.displayName, 'Prayer');
    });

    test('should roundtrip through JSON', () {
      for (final category in EncouragementCategory.values) {
        final json = category.toJson();
        final parsed = EncouragementCategory.fromJson(json);
        expect(parsed, category);
      }
    });
  });
}
