import 'package:flutter_test/flutter_test.dart';
import 'package:saint_data/src/services/saint_feast_service.dart';

void main() {
  group('SaintFeastService.feastKeyForDate', () {
    test('formats a regular date as zero-padded MM-DD', () {
      expect(SaintFeastService.feastKeyForDate(DateTime(2026, 3, 5)), '03-05');
      expect(SaintFeastService.feastKeyForDate(DateTime(2026, 1, 3)), '01-03');
    });

    test('formats the last day of a non-leap February', () {
      expect(SaintFeastService.feastKeyForDate(DateTime(2025, 2, 28)), '02-28');
    });

    test('keeps february 29 in a leap year', () {
      expect(SaintFeastService.feastKeyForDate(DateTime(2028, 2, 29)), '02-29');
    });
  });

  group('SaintFeastService.isLeapYear', () {
    test('leap years divisible by 4', () {
      expect(SaintFeastService.isLeapYear(2024), isTrue);
      expect(SaintFeastService.isLeapYear(2028), isTrue);
    });

    test('century years are not leap unless divisible by 400', () {
      expect(SaintFeastService.isLeapYear(2025), isFalse);
      expect(SaintFeastService.isLeapYear(1900), isFalse);
      expect(SaintFeastService.isLeapYear(2000), isTrue);
    });
  });
}
