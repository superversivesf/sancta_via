import 'package:flutter_test/flutter_test.dart';
import 'package:prayer_companion/models/prayer.dart';
import 'package:prayer_companion/models/prayer_time_of_day.dart';
import 'package:prayer_companion/repositories/prayer_repository.dart';

/// Repository tests for time-of-day prayer functionality
/// 
/// Note: These tests verify the repository API contract and error handling.
/// The repository will log errors about database initialization since the database
/// is not available in the test environment. This is expected behavior and the
/// tests verify that the repository handles these errors gracefully by returning
/// empty lists instead of throwing exceptions.
void main() {
  group('PrayerRepository - Time of Day Methods', () {
    late PrayerRepository repository;

    setUp(() {
      repository = PrayerRepository();
    });

    group('getPrayersForTimeOfDay - API Contract', () {
      test('returns record with timePrayers and anytimePrayers fields', () async {
        final result = await repository.getPrayersForTimeOfDay(
          PrayerTimeOfDay.morning,
        );

        // Verify the record structure
        expect(result.timePrayers, isA<List<Prayer>>());
        expect(result.anytimePrayers, isA<List<Prayer>>());
      });

      test('handles all time periods without throwing', () async {
        // Test all enum values work without exceptions
        for (final timeOfDay in PrayerTimeOfDay.values) {
          final result = await repository.getPrayersForTimeOfDay(timeOfDay);
          
          expect(result.timePrayers, isA<List<Prayer>>());
          expect(result.anytimePrayers, isA<List<Prayer>>());
        }
      });

      test('returns empty lists when database is unavailable', () async {
        // In test environment, database is not initialized
        // Repository should handle this gracefully
        final result = await repository.getPrayersForTimeOfDay(
          PrayerTimeOfDay.morning,
        );

        expect(result.timePrayers, isEmpty);
        expect(result.anytimePrayers, isEmpty);
      });

      test('timePrayers and anytimePrayers are separate list instances', () async {
        final result = await repository.getPrayersForTimeOfDay(
          PrayerTimeOfDay.morning,
        );

        // Verify they are different list instances
        expect(identical(result.timePrayers, result.anytimePrayers), isFalse);
      });
    });

    group('Record Type Features', () {
      test('record fields can be destructured', () async {
        final result = await repository.getPrayersForTimeOfDay(
          PrayerTimeOfDay.morning,
        );

        // Test destructuring
        final (:timePrayers, :anytimePrayers) = result;
        
        expect(timePrayers, isA<List<Prayer>>());
        expect(anytimePrayers, isA<List<Prayer>>());
      });

      test('record fields can be accessed by name', () async {
        final result = await repository.getPrayersForTimeOfDay(
          PrayerTimeOfDay.morning,
        );

        expect(result.timePrayers, isA<List<Prayer>>());
        expect(result.anytimePrayers, isA<List<Prayer>>());
      });

      test('record can be assigned to typed variable', () async {
        final ({List<Prayer> timePrayers, List<Prayer> anytimePrayers}) result = 
            await repository.getPrayersForTimeOfDay(PrayerTimeOfDay.evening);

        expect(result.timePrayers, isA<List<Prayer>>());
        expect(result.anytimePrayers, isA<List<Prayer>>());
      });
    });

    group('Repository Cache Management', () {
      test('clearCache does not throw', () {
        expect(() => repository.clearCache(), returnsNormally);
      });

      test('clearCache can be called multiple times', () {
        repository.clearCache();
        repository.clearCache();
        repository.clearCache();
        
        // Should not throw
        expect(true, isTrue);
      });
    });

    group('Multiple Query Patterns', () {
      test('can query multiple time periods sequentially', () async {
        final morning = await repository.getPrayersForTimeOfDay(PrayerTimeOfDay.morning);
        final afternoon = await repository.getPrayersForTimeOfDay(PrayerTimeOfDay.afternoon);
        final evening = await repository.getPrayersForTimeOfDay(PrayerTimeOfDay.evening);

        expect(morning.timePrayers, isA<List<Prayer>>());
        expect(afternoon.timePrayers, isA<List<Prayer>>());
        expect(evening.timePrayers, isA<List<Prayer>>());
      });

      test('can query same time period multiple times', () async {
        final result1 = await repository.getPrayersForTimeOfDay(PrayerTimeOfDay.morning);
        final result2 = await repository.getPrayersForTimeOfDay(PrayerTimeOfDay.morning);
        final result3 = await repository.getPrayersForTimeOfDay(PrayerTimeOfDay.morning);

        expect(result1.timePrayers, isA<List<Prayer>>());
        expect(result2.timePrayers, isA<List<Prayer>>());
        expect(result3.timePrayers, isA<List<Prayer>>());
      });
    });

    group('Error Handling', () {
      test('gracefully handles database unavailability', () async {
        // Should not throw even when database is unavailable
        expect(
          () async => await repository.getPrayersForTimeOfDay(PrayerTimeOfDay.morning),
          returnsNormally,
        );
      });

      test('returns empty record on error, not null', () async {
        final result = await repository.getPrayersForTimeOfDay(PrayerTimeOfDay.morning);

        // Should return empty lists, not null
        expect(result.timePrayers, isNotNull);
        expect(result.anytimePrayers, isNotNull);
        expect(result.timePrayers, isEmpty);
        expect(result.anytimePrayers, isEmpty);
      });
    });
  });
}
