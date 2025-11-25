import 'package:flutter_test/flutter_test.dart';
import 'package:prayer_companion/models/prayer_time_of_day.dart';

void main() {
  group('PrayerTimeOfDay enum tests', () {
    group('displayName', () {
      test('returns correct display name for morning', () {
        expect(PrayerTimeOfDay.morning.displayName, equals('Morning'));
      });

      test('returns correct display name for afternoon', () {
        expect(PrayerTimeOfDay.afternoon.displayName, equals('Afternoon'));
      });

      test('returns correct display name for evening', () {
        expect(PrayerTimeOfDay.evening.displayName, equals('Evening'));
      });

      test('returns correct display name for night', () {
        expect(PrayerTimeOfDay.night.displayName, equals('Night'));
      });

      test('returns correct display name for anytime', () {
        expect(PrayerTimeOfDay.anytime.displayName, equals('Any Time'));
      });
    });

    group('panelLabel', () {
      test('returns correct panel label for morning', () {
        expect(PrayerTimeOfDay.morning.panelLabel, equals('Morning Prayer'));
      });

      test('returns correct panel label for afternoon', () {
        expect(
          PrayerTimeOfDay.afternoon.panelLabel,
          equals('Afternoon Prayer'),
        );
      });

      test('returns correct panel label for evening', () {
        expect(PrayerTimeOfDay.evening.panelLabel, equals('Evening Prayer'));
      });

      test('returns correct panel label for night', () {
        expect(PrayerTimeOfDay.night.panelLabel, equals('Night Prayer'));
      });

      test('returns correct panel label for anytime', () {
        expect(PrayerTimeOfDay.anytime.panelLabel, equals('Prayer'));
      });
    });

    group('fromString', () {
      test('converts "morning" to morning', () {
        expect(
          PrayerTimeOfDay.fromString('morning'),
          equals(PrayerTimeOfDay.morning),
        );
      });

      test('converts "afternoon" to afternoon', () {
        expect(
          PrayerTimeOfDay.fromString('afternoon'),
          equals(PrayerTimeOfDay.afternoon),
        );
      });

      test('converts "evening" to evening', () {
        expect(
          PrayerTimeOfDay.fromString('evening'),
          equals(PrayerTimeOfDay.evening),
        );
      });

      test('converts "night" to night', () {
        expect(
          PrayerTimeOfDay.fromString('night'),
          equals(PrayerTimeOfDay.night),
        );
      });

      test('converts "anytime" to anytime', () {
        expect(
          PrayerTimeOfDay.fromString('anytime'),
          equals(PrayerTimeOfDay.anytime),
        );
      });

      test('handles uppercase strings correctly', () {
        expect(
          PrayerTimeOfDay.fromString('MORNING'),
          equals(PrayerTimeOfDay.morning),
        );
        expect(
          PrayerTimeOfDay.fromString('AFTERNOON'),
          equals(PrayerTimeOfDay.afternoon),
        );
        expect(
          PrayerTimeOfDay.fromString('EVENING'),
          equals(PrayerTimeOfDay.evening),
        );
      });

      test('handles mixed case strings correctly', () {
        expect(
          PrayerTimeOfDay.fromString('MoRnInG'),
          equals(PrayerTimeOfDay.morning),
        );
        expect(
          PrayerTimeOfDay.fromString('AfTeRnOoN'),
          equals(PrayerTimeOfDay.afternoon),
        );
      });

      test('returns anytime for null value', () {
        expect(
          PrayerTimeOfDay.fromString(null),
          equals(PrayerTimeOfDay.anytime),
        );
      });

      test('returns anytime for empty string', () {
        expect(PrayerTimeOfDay.fromString(''), equals(PrayerTimeOfDay.anytime));
      });

      test('returns anytime for invalid string', () {
        expect(
          PrayerTimeOfDay.fromString('invalid'),
          equals(PrayerTimeOfDay.anytime),
        );
        expect(
          PrayerTimeOfDay.fromString('xyz'),
          equals(PrayerTimeOfDay.anytime),
        );
      });
    });

    group('toStringValue', () {
      test('converts morning to "morning"', () {
        expect(PrayerTimeOfDay.morning.toStringValue(), equals('morning'));
      });

      test('converts afternoon to "afternoon"', () {
        expect(PrayerTimeOfDay.afternoon.toStringValue(), equals('afternoon'));
      });

      test('converts evening to "evening"', () {
        expect(PrayerTimeOfDay.evening.toStringValue(), equals('evening'));
      });

      test('converts night to "night"', () {
        expect(PrayerTimeOfDay.night.toStringValue(), equals('night'));
      });

      test('converts anytime to "anytime"', () {
        expect(PrayerTimeOfDay.anytime.toStringValue(), equals('anytime'));
      });
    });

    group('fromDateTime - Time period detection', () {
      test('detects morning period (5:00 AM - 8:59 AM)', () {
        // Test boundary cases
        expect(
          PrayerTimeOfDay.fromDateTime(DateTime(2025, 1, 1, 5, 0)),
          equals(PrayerTimeOfDay.morning),
        );
        expect(
          PrayerTimeOfDay.fromDateTime(DateTime(2025, 1, 1, 8, 59)),
          equals(PrayerTimeOfDay.morning),
        );

        // Test middle of range
        expect(
          PrayerTimeOfDay.fromDateTime(DateTime(2025, 1, 1, 7, 30)),
          equals(PrayerTimeOfDay.morning),
        );
      });

      test('detects anytime period (9:00 AM - 10:59 AM)', () {
        // Test boundary cases
        expect(
          PrayerTimeOfDay.fromDateTime(DateTime(2025, 1, 1, 9, 0)),
          equals(PrayerTimeOfDay.anytime),
        );
        expect(
          PrayerTimeOfDay.fromDateTime(DateTime(2025, 1, 1, 10, 59)),
          equals(PrayerTimeOfDay.anytime),
        );

        // Test middle of range
        expect(
          PrayerTimeOfDay.fromDateTime(DateTime(2025, 1, 1, 10, 0)),
          equals(PrayerTimeOfDay.anytime),
        );
      });

      test('detects afternoon period (11:00 AM - 4:59 PM)', () {
        // Test boundary cases
        expect(
          PrayerTimeOfDay.fromDateTime(DateTime(2025, 1, 1, 11, 0)),
          equals(PrayerTimeOfDay.afternoon),
        );
        expect(
          PrayerTimeOfDay.fromDateTime(DateTime(2025, 1, 1, 16, 59)),
          equals(PrayerTimeOfDay.afternoon),
        );

        // Test middle of range
        expect(
          PrayerTimeOfDay.fromDateTime(DateTime(2025, 1, 1, 13, 30)),
          equals(PrayerTimeOfDay.afternoon),
        );
      });

      test('detects evening period (5:00 PM - 8:59 PM)', () {
        // Test boundary cases
        expect(
          PrayerTimeOfDay.fromDateTime(DateTime(2025, 1, 1, 17, 0)),
          equals(PrayerTimeOfDay.evening),
        );
        expect(
          PrayerTimeOfDay.fromDateTime(DateTime(2025, 1, 1, 20, 59)),
          equals(PrayerTimeOfDay.evening),
        );

        // Test middle of range
        expect(
          PrayerTimeOfDay.fromDateTime(DateTime(2025, 1, 1, 19, 0)),
          equals(PrayerTimeOfDay.evening),
        );
      });

      test('detects night period (9:00 PM - 4:59 AM)', () {
        // Test late evening boundary
        expect(
          PrayerTimeOfDay.fromDateTime(DateTime(2025, 1, 1, 21, 0)),
          equals(PrayerTimeOfDay.night),
        );

        // Test midnight
        expect(
          PrayerTimeOfDay.fromDateTime(DateTime(2025, 1, 1, 0, 0)),
          equals(PrayerTimeOfDay.night),
        );

        // Test early morning boundary
        expect(
          PrayerTimeOfDay.fromDateTime(DateTime(2025, 1, 1, 4, 59)),
          equals(PrayerTimeOfDay.night),
        );

        // Test middle of night
        expect(
          PrayerTimeOfDay.fromDateTime(DateTime(2025, 1, 1, 2, 30)),
          equals(PrayerTimeOfDay.night),
        );
      });

      test('correctly handles all 24 hours', () {
        // Hour 0-4: Night
        for (int hour = 0; hour < 5; hour++) {
          expect(
            PrayerTimeOfDay.fromDateTime(DateTime(2025, 1, 1, hour, 0)),
            equals(PrayerTimeOfDay.night),
            reason: 'Hour $hour should be night',
          );
        }

        // Hour 5-8: Morning
        for (int hour = 5; hour < 9; hour++) {
          expect(
            PrayerTimeOfDay.fromDateTime(DateTime(2025, 1, 1, hour, 0)),
            equals(PrayerTimeOfDay.morning),
            reason: 'Hour $hour should be morning',
          );
        }

        // Hour 9-10: Anytime
        for (int hour = 9; hour < 11; hour++) {
          expect(
            PrayerTimeOfDay.fromDateTime(DateTime(2025, 1, 1, hour, 0)),
            equals(PrayerTimeOfDay.anytime),
            reason: 'Hour $hour should be anytime',
          );
        }

        // Hour 11-16: Afternoon
        for (int hour = 11; hour < 17; hour++) {
          expect(
            PrayerTimeOfDay.fromDateTime(DateTime(2025, 1, 1, hour, 0)),
            equals(PrayerTimeOfDay.afternoon),
            reason: 'Hour $hour should be afternoon',
          );
        }

        // Hour 17-20: Evening
        for (int hour = 17; hour < 21; hour++) {
          expect(
            PrayerTimeOfDay.fromDateTime(DateTime(2025, 1, 1, hour, 0)),
            equals(PrayerTimeOfDay.evening),
            reason: 'Hour $hour should be evening',
          );
        }

        // Hour 21-23: Night
        for (int hour = 21; hour < 24; hour++) {
          expect(
            PrayerTimeOfDay.fromDateTime(DateTime(2025, 1, 1, hour, 0)),
            equals(PrayerTimeOfDay.night),
            reason: 'Hour $hour should be night',
          );
        }
      });

      test('works with different dates', () {
        expect(
          PrayerTimeOfDay.fromDateTime(DateTime(2020, 6, 15, 7, 0)),
          equals(PrayerTimeOfDay.morning),
        );
        expect(
          PrayerTimeOfDay.fromDateTime(DateTime(2030, 12, 25, 19, 0)),
          equals(PrayerTimeOfDay.evening),
        );
      });
    });

    group('roundtrip conversion', () {
      test('fromString and toStringValue are inverse operations', () {
        for (final timeOfDay in PrayerTimeOfDay.values) {
          final stringValue = timeOfDay.toStringValue();
          final converted = PrayerTimeOfDay.fromString(stringValue);
          expect(converted, equals(timeOfDay));
        }
      });
    });
  });
}
