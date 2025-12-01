import 'package:flutter_test/flutter_test.dart';
import 'package:sancta_via_rosary_companion/models/mystery_type.dart';

void main() {
  group('MysteryType', () {
    test('should have correct number of values', () {
      expect(MysteryType.values.length, 4);
    });

    test('should have correct string values', () {
      expect(MysteryType.joyful.value, 'joyful');
      expect(MysteryType.sorrowful.value, 'sorrowful');
      expect(MysteryType.glorious.value, 'glorious');
      expect(MysteryType.luminous.value, 'luminous');
    });

    test('fromString should return correct MysteryType', () {
      expect(MysteryType.fromString('joyful'), MysteryType.joyful);
      expect(MysteryType.fromString('sorrowful'), MysteryType.sorrowful);
      expect(MysteryType.fromString('glorious'), MysteryType.glorious);
      expect(MysteryType.fromString('luminous'), MysteryType.luminous);
    });

    test('fromString should return default joyful for unknown string', () {
      expect(MysteryType.fromString('unknown'), MysteryType.joyful);
      expect(MysteryType.fromString(''), MysteryType.joyful);
    });

    test('fromDate should return correct mystery type for each weekday', () {
      expect(MysteryType.fromDate(DateTime(2025, 1, 6)), MysteryType.joyful);
      expect(MysteryType.fromDate(DateTime(2025, 1, 7)), MysteryType.sorrowful);
      expect(MysteryType.fromDate(DateTime(2025, 1, 8)), MysteryType.glorious);
      expect(MysteryType.fromDate(DateTime(2025, 1, 9)), MysteryType.luminous);
      expect(MysteryType.fromDate(DateTime(2025, 1, 10)), MysteryType.sorrowful);
      expect(MysteryType.fromDate(DateTime(2025, 1, 11)), MysteryType.joyful);
      expect(MysteryType.fromDate(DateTime(2025, 1, 12)), MysteryType.glorious);
    });

    test('displayName should return formatted name', () {
      expect(MysteryType.joyful.displayName, 'Joyful Mysteries');
      expect(MysteryType.sorrowful.displayName, 'Sorrowful Mysteries');
      expect(MysteryType.glorious.displayName, 'Glorious Mysteries');
      expect(MysteryType.luminous.displayName, 'Luminous Mysteries');
    });
  });
}