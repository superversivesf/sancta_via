import 'package:flutter_test/flutter_test.dart';
import 'package:prayer_companion/models/prayer.dart';
import 'package:prayer_companion/models/prayer_time_of_day.dart';
import 'package:prayer_companion/services/time_of_day_prayer_service.dart';

void main() {
  group('TimeOfDayPrayerService', () {
    // Helper to create test prayers
    Prayer createPrayer(String id, String title) {
      return Prayer(
        id: id,
        title: title,
        description: 'Test prayer $id',
        text: 'Prayer text for $id',
        categories: ['test'],
        tags: [],
        timeOfDay: 'anytime',
      );
    }

    group('selectRandomPrayer', () {
      test('returns null when prayer list is empty', () {
        final result = TimeOfDayPrayerService.selectRandomPrayer(
          prayers: [],
          date: DateTime(2025, 1, 1),
        );

        expect(result, isNull);
      });

      test('returns the only prayer when list has one item', () {
        final prayer = createPrayer('1', 'Morning Prayer');
        final result = TimeOfDayPrayerService.selectRandomPrayer(
          prayers: [prayer],
          date: DateTime(2025, 1, 1),
        );

        expect(result, equals(prayer));
      });

      test('returns a prayer from the list when multiple prayers exist', () {
        final prayers = [
          createPrayer('1', 'Prayer 1'),
          createPrayer('2', 'Prayer 2'),
          createPrayer('3', 'Prayer 3'),
        ];

        final result = TimeOfDayPrayerService.selectRandomPrayer(
          prayers: prayers,
          date: DateTime(2025, 1, 1),
        );

        expect(result, isNotNull);
        expect(prayers.contains(result), isTrue);
      });

      test('returns same prayer for same date (consistency)', () {
        final prayers = [
          createPrayer('1', 'Prayer 1'),
          createPrayer('2', 'Prayer 2'),
          createPrayer('3', 'Prayer 3'),
          createPrayer('4', 'Prayer 4'),
          createPrayer('5', 'Prayer 5'),
        ];

        final date = DateTime(2025, 3, 15);

        // Select prayer multiple times on the same date
        final result1 = TimeOfDayPrayerService.selectRandomPrayer(
          prayers: prayers,
          date: date,
        );
        final result2 = TimeOfDayPrayerService.selectRandomPrayer(
          prayers: prayers,
          date: date,
        );
        final result3 = TimeOfDayPrayerService.selectRandomPrayer(
          prayers: prayers,
          date: date,
        );

        // All should be the same prayer
        expect(result1, equals(result2));
        expect(result2, equals(result3));
      });

      test('returns different prayers for different dates', () {
        final prayers = [
          createPrayer('1', 'Prayer 1'),
          createPrayer('2', 'Prayer 2'),
          createPrayer('3', 'Prayer 3'),
          createPrayer('4', 'Prayer 4'),
          createPrayer('5', 'Prayer 5'),
        ];

        // Collect prayers for different dates
        final results = <Prayer>{};
        for (int day = 1; day <= 100; day++) {
          final prayer = TimeOfDayPrayerService.selectRandomPrayer(
            prayers: prayers,
            date: DateTime(2025, 1, day),
          );
          if (prayer != null) {
            results.add(prayer);
          }
        }

        // Over 100 days, we should get variety (at least 3 different prayers)
        expect(results.length, greaterThanOrEqualTo(3));
      });

      test('uses date seed correctly - year boundary', () {
        final prayers = [
          createPrayer('1', 'Prayer 1'),
          createPrayer('2', 'Prayer 2'),
          createPrayer('3', 'Prayer 3'),
        ];

        // Same day of year but different years should potentially differ
        final result2024 = TimeOfDayPrayerService.selectRandomPrayer(
          prayers: prayers,
          date: DateTime(2024, 6, 15),
        );
        final result2025 = TimeOfDayPrayerService.selectRandomPrayer(
          prayers: prayers,
          date: DateTime(2025, 6, 15),
        );

        // These should be selected (both non-null)
        expect(result2024, isNotNull);
        expect(result2025, isNotNull);

        // They may be different (different years = different seeds)
        // Just verify they're both from the list
        expect(prayers.contains(result2024), isTrue);
        expect(prayers.contains(result2025), isTrue);
      });

      test('handles different times on same date consistently', () {
        final prayers = [
          createPrayer('1', 'Prayer 1'),
          createPrayer('2', 'Prayer 2'),
          createPrayer('3', 'Prayer 3'),
        ];

        // Same date but different times
        final date = DateTime(2025, 3, 15);
        final morning = DateTime(2025, 3, 15, 8, 0);
        final afternoon = DateTime(2025, 3, 15, 14, 0);
        final evening = DateTime(2025, 3, 15, 19, 0);

        final result1 = TimeOfDayPrayerService.selectRandomPrayer(
          prayers: prayers,
          date: date,
        );
        final result2 = TimeOfDayPrayerService.selectRandomPrayer(
          prayers: prayers,
          date: morning,
        );
        final result3 = TimeOfDayPrayerService.selectRandomPrayer(
          prayers: prayers,
          date: afternoon,
        );
        final result4 = TimeOfDayPrayerService.selectRandomPrayer(
          prayers: prayers,
          date: evening,
        );

        // All should select the same prayer (date-based seed ignores time)
        expect(result1, equals(result2));
        expect(result2, equals(result3));
        expect(result3, equals(result4));
      });
    });

    group('selectDifferentPrayer', () {
      test('returns null when prayer list is empty', () {
        final result = TimeOfDayPrayerService.selectDifferentPrayer(
          prayers: [],
          dateTime: DateTime(2025, 1, 1, 10, 30),
        );

        expect(result, isNull);
      });

      test('returns the only prayer when list has one item', () {
        final prayer = createPrayer('1', 'Morning Prayer');
        final result = TimeOfDayPrayerService.selectDifferentPrayer(
          prayers: [prayer],
          dateTime: DateTime(2025, 1, 1, 10, 30),
        );

        expect(result, equals(prayer));
      });

      test('returns a prayer from the list', () {
        final prayers = [
          createPrayer('1', 'Prayer 1'),
          createPrayer('2', 'Prayer 2'),
          createPrayer('3', 'Prayer 3'),
        ];

        final result = TimeOfDayPrayerService.selectDifferentPrayer(
          prayers: prayers,
          dateTime: DateTime(2025, 1, 1, 10, 30),
        );

        expect(result, isNotNull);
        expect(prayers.contains(result), isTrue);
      });

      test('returns different prayers for different timestamps', () {
        final prayers = [
          createPrayer('1', 'Prayer 1'),
          createPrayer('2', 'Prayer 2'),
          createPrayer('3', 'Prayer 3'),
          createPrayer('4', 'Prayer 4'),
          createPrayer('5', 'Prayer 5'),
        ];

        // Collect prayers for different timestamps
        final results = <Prayer>{};
        final baseTime = DateTime(2025, 1, 1, 10, 0);

        for (int i = 0; i < 50; i++) {
          final prayer = TimeOfDayPrayerService.selectDifferentPrayer(
            prayers: prayers,
            dateTime: baseTime.add(Duration(milliseconds: i * 100)),
          );
          if (prayer != null) {
            results.add(prayer);
          }
        }

        // Over 50 different timestamps, we should get variety
        expect(results.length, greaterThanOrEqualTo(3));
      });

      test('uses timestamp for variation - same date different times', () {
        final prayers = [
          createPrayer('1', 'Prayer 1'),
          createPrayer('2', 'Prayer 2'),
          createPrayer('3', 'Prayer 3'),
          createPrayer('4', 'Prayer 4'),
          createPrayer('5', 'Prayer 5'),
        ];

        // Multiple calls with different timestamps should give variety
        final results = <Prayer>{};

        final time1 = DateTime(2025, 1, 1, 10, 0, 0);
        final time2 = DateTime(2025, 1, 1, 10, 0, 1);
        final time3 = DateTime(2025, 1, 1, 10, 1, 0);
        final time4 = DateTime(2025, 1, 1, 11, 0, 0);
        final time5 = DateTime(2025, 1, 1, 15, 30, 45);

        results.add(
          TimeOfDayPrayerService.selectDifferentPrayer(
            prayers: prayers,
            dateTime: time1,
          )!,
        );
        results.add(
          TimeOfDayPrayerService.selectDifferentPrayer(
            prayers: prayers,
            dateTime: time2,
          )!,
        );
        results.add(
          TimeOfDayPrayerService.selectDifferentPrayer(
            prayers: prayers,
            dateTime: time3,
          )!,
        );
        results.add(
          TimeOfDayPrayerService.selectDifferentPrayer(
            prayers: prayers,
            dateTime: time4,
          )!,
        );
        results.add(
          TimeOfDayPrayerService.selectDifferentPrayer(
            prayers: prayers,
            dateTime: time5,
          )!,
        );

        // Should get at least 2 different prayers
        expect(results.length, greaterThanOrEqualTo(2));
      });

      test('is deterministic for same timestamp', () {
        final prayers = [
          createPrayer('1', 'Prayer 1'),
          createPrayer('2', 'Prayer 2'),
          createPrayer('3', 'Prayer 3'),
        ];

        final timestamp = DateTime(2025, 1, 1, 10, 30, 45, 123);

        final result1 = TimeOfDayPrayerService.selectDifferentPrayer(
          prayers: prayers,
          dateTime: timestamp,
        );
        final result2 = TimeOfDayPrayerService.selectDifferentPrayer(
          prayers: prayers,
          dateTime: timestamp,
        );

        // Same timestamp should give same result
        expect(result1, equals(result2));
      });
    });

    group('getCurrentTimeOfDay', () {
      test('returns a valid PrayerTimeOfDay', () {
        final result = TimeOfDayPrayerService.getCurrentTimeOfDay();

        expect(result, isA<PrayerTimeOfDay>());
        expect(PrayerTimeOfDay.values.contains(result), isTrue);
      });
    });

    group('getTimeOfDayFor', () {
      test('returns morning for morning time', () {
        final result = TimeOfDayPrayerService.getTimeOfDayFor(
          DateTime(2025, 1, 1, 7, 0),
        );
        expect(result, equals(PrayerTimeOfDay.morning));
      });

      test('returns afternoon for afternoon time', () {
        final result = TimeOfDayPrayerService.getTimeOfDayFor(
          DateTime(2025, 1, 1, 13, 0),
        );
        expect(result, equals(PrayerTimeOfDay.afternoon));
      });

      test('returns evening for evening time', () {
        final result = TimeOfDayPrayerService.getTimeOfDayFor(
          DateTime(2025, 1, 1, 19, 0),
        );
        expect(result, equals(PrayerTimeOfDay.evening));
      });

      test('returns night for night time', () {
        final result = TimeOfDayPrayerService.getTimeOfDayFor(
          DateTime(2025, 1, 1, 22, 0),
        );
        expect(result, equals(PrayerTimeOfDay.night));
      });

      test('returns anytime for anytime period', () {
        final result = TimeOfDayPrayerService.getTimeOfDayFor(
          DateTime(2025, 1, 1, 10, 0),
        );
        expect(result, equals(PrayerTimeOfDay.anytime));
      });
    });
  });
}
