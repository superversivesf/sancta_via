import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:prayer_companion/database/prayer_database.dart';
import 'package:prayer_companion/models/prayer.dart';
import 'package:prayer_companion/models/prayer_time_of_day.dart';
import 'package:prayer_companion/repositories/prayer_repository.dart';

// Generate mocks for PrayerDatabase
@GenerateMocks([PrayerDatabase])
import 'prayer_repository_test.mocks.dart';

void main() {
  group('PrayerRepository - Time of Day Methods', () {
    late MockPrayerDatabase mockDatabase;
    late PrayerRepository repository;

    // Helper to create test prayers
    Prayer createPrayer(String id, String title, String timeOfDay) {
      return Prayer(
        id: id,
        title: title,
        description: 'Test prayer $id',
        text: 'Prayer text for $id',
        categories: ['test'],
        tags: [],
        timeOfDay: timeOfDay,
      );
    }

    setUp(() {
      mockDatabase = MockPrayerDatabase();
      repository = PrayerRepository(database: mockDatabase);
    });

    group('getPrayersForTimeOfDay with Mocked Database', () {
      test('returns prayers from mocked database', () async {
        // Setup mock data
        final morningPrayers = [
          createPrayer('1', 'Morning Prayer 1', 'morning'),
          createPrayer('2', 'Morning Prayer 2', 'morning'),
        ];
        final anytimePrayers = [
          createPrayer('3', 'Anytime Prayer 1', 'anytime'),
        ];

        // Mock the database calls
        when(
          mockDatabase.getPrayersForExactTimeOfDay('morning'),
        ).thenAnswer((_) async => morningPrayers);
        when(
          mockDatabase.getPrayersForExactTimeOfDay('anytime'),
        ).thenAnswer((_) async => anytimePrayers);

        // Call repository method
        final result = await repository.getPrayersForTimeOfDay(
          PrayerTimeOfDay.morning,
        );

        // Verify results
        expect(result.timePrayers, hasLength(2));
        expect(result.anytimePrayers, hasLength(1));
        expect(result.timePrayers.first.title, equals('Morning Prayer 1'));
        expect(result.anytimePrayers.first.title, equals('Anytime Prayer 1'));

        // Verify database was called correctly
        verify(mockDatabase.getPrayersForExactTimeOfDay('morning')).called(1);
        verify(mockDatabase.getPrayersForExactTimeOfDay('anytime')).called(1);
      });

      test('returns empty lists when no prayers exist', () async {
        // Mock empty results
        when(
          mockDatabase.getPrayersForExactTimeOfDay(any),
        ).thenAnswer((_) async => []);

        final result = await repository.getPrayersForTimeOfDay(
          PrayerTimeOfDay.afternoon,
        );

        expect(result.timePrayers, isEmpty);
        expect(result.anytimePrayers, isEmpty);
      });

      test('handles all time periods correctly', () async {
        // Setup mock for all time periods
        when(
          mockDatabase.getPrayersForExactTimeOfDay(any),
        ).thenAnswer((_) async => []);

        for (final timeOfDay in PrayerTimeOfDay.values) {
          final result = await repository.getPrayersForTimeOfDay(timeOfDay);

          expect(result.timePrayers, isA<List<Prayer>>());
          expect(result.anytimePrayers, isA<List<Prayer>>());
        }
      });

      test('returns correct record structure', () async {
        when(
          mockDatabase.getPrayersForExactTimeOfDay(any),
        ).thenAnswer((_) async => []);

        final result = await repository.getPrayersForTimeOfDay(
          PrayerTimeOfDay.evening,
        );

        // Verify record type
        expect(result.timePrayers, isA<List<Prayer>>());
        expect(result.anytimePrayers, isA<List<Prayer>>());
        expect(identical(result.timePrayers, result.anytimePrayers), isFalse);
      });

      test('returns different prayers for different time periods', () async {
        final morningPrayers = [createPrayer('1', 'Morning', 'morning')];
        final afternoonPrayers = [createPrayer('2', 'Afternoon', 'afternoon')];
        final anytimePrayers = [createPrayer('3', 'Anytime', 'anytime')];

        // Setup different responses for different time periods
        when(
          mockDatabase.getPrayersForExactTimeOfDay('morning'),
        ).thenAnswer((_) async => morningPrayers);
        when(
          mockDatabase.getPrayersForExactTimeOfDay('afternoon'),
        ).thenAnswer((_) async => afternoonPrayers);
        when(
          mockDatabase.getPrayersForExactTimeOfDay('anytime'),
        ).thenAnswer((_) async => anytimePrayers);

        final morningResult = await repository.getPrayersForTimeOfDay(
          PrayerTimeOfDay.morning,
        );
        final afternoonResult = await repository.getPrayersForTimeOfDay(
          PrayerTimeOfDay.afternoon,
        );

        expect(morningResult.timePrayers.first.title, equals('Morning'));
        expect(afternoonResult.timePrayers.first.title, equals('Afternoon'));
      });
    });

    group('Record Type Features', () {
      setUp(() {
        when(
          mockDatabase.getPrayersForExactTimeOfDay(any),
        ).thenAnswer((_) async => []);
      });

      test('record fields can be destructured', () async {
        final result = await repository.getPrayersForTimeOfDay(
          PrayerTimeOfDay.morning,
        );

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

    group('Error Handling', () {
      test('handles database errors gracefully', () async {
        // Mock database throwing an error
        when(
          mockDatabase.getPrayersForExactTimeOfDay(any),
        ).thenThrow(Exception('Database error'));

        final result = await repository.getPrayersForTimeOfDay(
          PrayerTimeOfDay.morning,
        );

        // Should return empty lists on error
        expect(result.timePrayers, isEmpty);
        expect(result.anytimePrayers, isEmpty);
      });

      test('does not throw when database fails', () async {
        when(
          mockDatabase.getPrayersForExactTimeOfDay(any),
        ).thenThrow(Exception('Database error'));

        expect(
          () async =>
              await repository.getPrayersForTimeOfDay(PrayerTimeOfDay.morning),
          returnsNormally,
        );
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

        expect(true, isTrue);
      });
    });

    group('Multiple Query Patterns', () {
      setUp(() {
        when(
          mockDatabase.getPrayersForExactTimeOfDay(any),
        ).thenAnswer((_) async => []);
      });

      test('can query multiple time periods sequentially', () async {
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
        final result1 = await repository.getPrayersForTimeOfDay(
          PrayerTimeOfDay.morning,
        );
        final result2 = await repository.getPrayersForTimeOfDay(
          PrayerTimeOfDay.morning,
        );
        final result3 = await repository.getPrayersForTimeOfDay(
          PrayerTimeOfDay.morning,
        );

        expect(result1.timePrayers, isA<List<Prayer>>());
        expect(result2.timePrayers, isA<List<Prayer>>());
        expect(result3.timePrayers, isA<List<Prayer>>());
      });
    });

    group('Mock Verification', () {
      test('database methods are called with correct parameters', () async {
        when(
          mockDatabase.getPrayersForExactTimeOfDay(any),
        ).thenAnswer((_) async => []);

        await repository.getPrayersForTimeOfDay(PrayerTimeOfDay.morning);

        verify(mockDatabase.getPrayersForExactTimeOfDay('morning')).called(1);
        verify(mockDatabase.getPrayersForExactTimeOfDay('anytime')).called(1);
        verifyNoMoreInteractions(mockDatabase);
      });

      test('database is not called more than necessary', () async {
        when(
          mockDatabase.getPrayersForExactTimeOfDay(any),
        ).thenAnswer((_) async => []);

        await repository.getPrayersForTimeOfDay(PrayerTimeOfDay.afternoon);

        // Should only call for specific time period and anytime
        verify(mockDatabase.getPrayersForExactTimeOfDay('afternoon')).called(1);
        verify(mockDatabase.getPrayersForExactTimeOfDay('anytime')).called(1);
        verifyNoMoreInteractions(mockDatabase);
      });
    });
  });
}
