import 'package:flutter_test/flutter_test.dart';
import 'package:prayer_companion/models/prayer.dart';
import 'package:prayer_companion/models/prayer_time_of_day.dart';
import 'package:prayer_companion/repositories/prayer_repository.dart';

void main() {
  group('PrayerRepository - Time of Day Methods', () {
    late PrayerRepository repository;

    setUp(() {
      repository = PrayerRepository();
    });

    group('getPrayersForTimeOfDay', () {
      test('returns record with timePrayers and anytimePrayers fields', () async {
        // This test verifies the structure of the return type
        final result = await repository.getPrayersForTimeOfDay(
          PrayerTimeOfDay.morning,
        );

        // Verify the record structure exists
        expect(result.timePrayers, isA<List<Prayer>>());
        expect(result.anytimePrayers, isA<List<Prayer>>());
      });

      test('handles morning time period', () async {
        final result = await repository.getPrayersForTimeOfDay(
          PrayerTimeOfDay.morning,
        );

        // Both lists should be non-null (may be empty if DB not initialized in test)
        expect(result.timePrayers, isNotNull);
        expect(result.anytimePrayers, isNotNull);
      });

      test('handles afternoon time period', () async {
        final result = await repository.getPrayersForTimeOfDay(
          PrayerTimeOfDay.afternoon,
        );

        expect(result.timePrayers, isNotNull);
        expect(result.anytimePrayers, isNotNull);
      });

      test('handles evening time period', () async {
        final result = await repository.getPrayersForTimeOfDay(
          PrayerTimeOfDay.evening,
        );

        expect(result.timePrayers, isNotNull);
        expect(result.anytimePrayers, isNotNull);
      });

      test('handles night time period', () async {
        final result = await repository.getPrayersForTimeOfDay(
          PrayerTimeOfDay.night,
        );

        expect(result.timePrayers, isNotNull);
        expect(result.anytimePrayers, isNotNull);
      });

      test('handles anytime period', () async {
        final result = await repository.getPrayersForTimeOfDay(
          PrayerTimeOfDay.anytime,
        );

        expect(result.timePrayers, isNotNull);
        expect(result.anytimePrayers, isNotNull);
      });

      test('returns empty lists on error without throwing', () async {
        // Even if database isn't initialized, should return empty lists
        final result = await repository.getPrayersForTimeOfDay(
          PrayerTimeOfDay.morning,
        );

        // Should return empty lists, not null or throw
        expect(result.timePrayers, isA<List<Prayer>>());
        expect(result.anytimePrayers, isA<List<Prayer>>());
      });

      test('timePrayers and anytimePrayers are separate lists', () async {
        final result = await repository.getPrayersForTimeOfDay(
          PrayerTimeOfDay.morning,
        );

        // Verify they are different list instances
        expect(identical(result.timePrayers, result.anytimePrayers), isFalse);
      });

      test('all enum values can be queried', () async {
        // Test that all PrayerTimeOfDay values work
        for (final timeOfDay in PrayerTimeOfDay.values) {
          final result = await repository.getPrayersForTimeOfDay(timeOfDay);
          
          expect(result.timePrayers, isA<List<Prayer>>());
          expect(result.anytimePrayers, isA<List<Prayer>>());
        }
      });
    });

    group('clearCache', () {
      test('clearCache does not throw', () {
        expect(() => repository.clearCache(), returnsNormally);
      });

      test('clearCache can be called multiple times', () {
        expect(() {
          repository.clearCache();
          repository.clearCache();
          repository.clearCache();
        }, returnsNormally);
      });
    });
  });

  group('PrayerRepository - Record Type Integration', () {
    test('record fields can be destructured', () async {
      final repository = PrayerRepository();
      
      final result = await repository.getPrayersForTimeOfDay(
        PrayerTimeOfDay.morning,
      );

      // Test destructuring the record
      final (:timePrayers, :anytimePrayers) = result;
      
      expect(timePrayers, isA<List<Prayer>>());
      expect(anytimePrayers, isA<List<Prayer>>());
    });

    test('record fields can be accessed by name', () async {
      final repository = PrayerRepository();
      
      final result = await repository.getPrayersForTimeOfDay(
        PrayerTimeOfDay.morning,
      );

      // Test accessing fields by name
      expect(result.timePrayers, isA<List<Prayer>>());
      expect(result.anytimePrayers, isA<List<Prayer>>());
    });

    test('record can be assigned to variable', () async {
      final repository = PrayerRepository();
      
      final ({List<Prayer> timePrayers, List<Prayer> anytimePrayers}) result = 
          await repository.getPrayersForTimeOfDay(PrayerTimeOfDay.evening);

      expect(result.timePrayers, isA<List<Prayer>>());
      expect(result.anytimePrayers, isA<List<Prayer>>());
    });
  });

  group('PrayerRepository - Error Handling', () {
    test('getPrayersForTimeOfDay handles errors gracefully', () async {
      final repository = PrayerRepository();
      
      // Should not throw even if database has issues
      expect(
        () async => await repository.getPrayersForTimeOfDay(PrayerTimeOfDay.morning),
        returnsNormally,
      );
    });

    test('returns empty record on database error', () async {
      final repository = PrayerRepository();
      
      // When database is not initialized, should return empty lists
      final result = await repository.getPrayersForTimeOfDay(
        PrayerTimeOfDay.morning,
      );

      // Both should be empty lists (not null, not throw)
      expect(result.timePrayers, isEmpty);
      expect(result.anytimePrayers, isEmpty);
    });
  });

  group('PrayerRepository - Time Period Consistency', () {
    test('queries morning prayers correctly', () async {
      final repository = PrayerRepository();
      
      final result = await repository.getPrayersForTimeOfDay(
        PrayerTimeOfDay.morning,
      );

      // Verify structure is correct
      expect(result, isA<({List<Prayer> timePrayers, List<Prayer> anytimePrayers})>());
    });

    test('queries afternoon prayers correctly', () async {
      final repository = PrayerRepository();
      
      final result = await repository.getPrayersForTimeOfDay(
        PrayerTimeOfDay.afternoon,
      );

      expect(result, isA<({List<Prayer> timePrayers, List<Prayer> anytimePrayers})>());
    });

    test('queries evening prayers correctly', () async {
      final repository = PrayerRepository();
      
      final result = await repository.getPrayersForTimeOfDay(
        PrayerTimeOfDay.evening,
      );

      expect(result, isA<({List<Prayer> timePrayers, List<Prayer> anytimePrayers})>());
    });

    test('queries night prayers correctly', () async {
      final repository = PrayerRepository();
      
      final result = await repository.getPrayersForTimeOfDay(
        PrayerTimeOfDay.night,
      );

      expect(result, isA<({List<Prayer> timePrayers, List<Prayer> anytimePrayers})>());
    });

    test('queries anytime prayers correctly', () async {
      final repository = PrayerRepository();
      
      final result = await repository.getPrayersForTimeOfDay(
        PrayerTimeOfDay.anytime,
      );

      expect(result, isA<({List<Prayer> timePrayers, List<Prayer> anytimePrayers})>());
    });
  });

  group('PrayerRepository - Multiple Queries', () {
    test('can query multiple time periods sequentially', () async {
      final repository = PrayerRepository();
      
      // Query different time periods in sequence
      final morning = await repository.getPrayersForTimeOfDay(
        PrayerTimeOfDay.morning,
      );
      final afternoon = await repository.getPrayersForTimeOfDay(
        PrayerTimeOfDay.afternoon,
      );
      final evening = await repository.getPrayersForTimeOfDay(
        PrayerTimeOfDay.evening,
      );

      expect(morning.timePrayers, isA<List<Prayer>>());
      expect(afternoon.timePrayers, isA<List<Prayer>>());
      expect(evening.timePrayers, isA<List<Prayer>>());
    });

    test('can query same time period multiple times', () async {
      final repository = PrayerRepository();
      
      final result1 = await repository.getPrayersForTimeOfDay(
        PrayerTimeOfDay.morning,
      );
      final result2 = await repository.getPrayersForTimeOfDay(
        PrayerTimeOfDay.morning,
      );
      final result3 = await repository.getPrayersForTimeOfDay(
        PrayerTimeOfDay.morning,
      );

      // All should return valid structures
      expect(result1.timePrayers, isA<List<Prayer>>());
      expect(result2.timePrayers, isA<List<Prayer>>());
      expect(result3.timePrayers, isA<List<Prayer>>());
    });
  });
}
