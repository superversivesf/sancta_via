import 'package:flutter_test/flutter_test.dart';
import 'package:sancta_via_fasting_companion/models/fast_type_category.dart';

void main() {
  group('FastTypeCategory', () {
    test('should have correct enum values', () {
      expect(FastTypeCategory.values.length, 5);
      expect(FastTypeCategory.values, contains(FastTypeCategory.intermittent));
      expect(FastTypeCategory.values, contains(FastTypeCategory.daily24hr));
      expect(FastTypeCategory.values, contains(FastTypeCategory.multiDay));
      expect(FastTypeCategory.values, contains(FastTypeCategory.liturgical));
      expect(FastTypeCategory.values, contains(FastTypeCategory.flexible));
    });

    test('toJson should return correct string', () {
      expect(FastTypeCategory.intermittent.toJson(), 'intermittent');
      expect(FastTypeCategory.daily24hr.toJson(), 'daily24hr');
      expect(FastTypeCategory.multiDay.toJson(), 'multiDay');
      expect(FastTypeCategory.liturgical.toJson(), 'liturgical');
      expect(FastTypeCategory.flexible.toJson(), 'flexible');
    });

    test('fromJson should parse correctly', () {
      expect(
        FastTypeCategory.fromJson('intermittent'),
        FastTypeCategory.intermittent,
      );
      expect(
        FastTypeCategory.fromJson('daily24hr'),
        FastTypeCategory.daily24hr,
      );
      expect(FastTypeCategory.fromJson('multiDay'), FastTypeCategory.multiDay);
      expect(
        FastTypeCategory.fromJson('liturgical'),
        FastTypeCategory.liturgical,
      );
      expect(
        FastTypeCategory.fromJson('flexible'),
        FastTypeCategory.flexible,
      );
    });

    test('fromJson should default to intermittent for invalid input', () {
      expect(
        FastTypeCategory.fromJson('invalid'),
        FastTypeCategory.intermittent,
      );
      expect(FastTypeCategory.fromJson(''), FastTypeCategory.intermittent);
    });

    test('displayName should return correct values', () {
      expect(FastTypeCategory.intermittent.displayName, 'Intermittent');
      expect(FastTypeCategory.daily24hr.displayName, '24-Hour');
      expect(FastTypeCategory.multiDay.displayName, 'Multi-Day');
      expect(FastTypeCategory.liturgical.displayName, 'Liturgical');
      expect(FastTypeCategory.flexible.displayName, 'Flexible');
    });

    test('description should return meaningful text', () {
      expect(
        FastTypeCategory.intermittent.description,
        contains('Time-restricted'),
      );
      expect(FastTypeCategory.daily24hr.description, contains('24-hour'));
      expect(FastTypeCategory.multiDay.description, contains('multiple days'));
      expect(FastTypeCategory.liturgical.description, contains('Catholic'));
      expect(FastTypeCategory.flexible.description, contains('Open-ended'));
    });

    test('should roundtrip through JSON', () {
      for (final category in FastTypeCategory.values) {
        final json = category.toJson();
        final parsed = FastTypeCategory.fromJson(json);
        expect(parsed, category);
      }
    });
  });
}
