import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sancta_via_liturgical_calendar/sancta_via_liturgical_calendar.dart';
import 'package:sancta_via_liturgical_calendar_riverpod/src/providers/liturgical_providers.dart';
import 'package:fake_async/fake_async.dart';

void main() {
  group('Liturgical Providers', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('availableYearsProvider returns list of years', () {
      final years = container.read(availableYearsProvider);
      expect(years, isA<List<int>>());
      expect(years, isNotEmpty);
      expect(years.first, equals(LiturgicalCalendarService.getAvailableYears().first));
    });

    test('globalStatisticsProvider returns map of statistics', () {
      final stats = container.read(globalStatisticsProvider);
      expect(stats, isA<Map<String, int>>());
      expect(stats, isNotEmpty);
      expect(stats['totalYears'],
          equals(LiturgicalCalendarService.getGlobalStatistics()['totalYears']));
    });

    test('liturgicalDayProvider returns LiturgicalDayData for a specific date',
        () {
      final testDate = DateTime(2025, 12, 25); // Christmas Day
      final liturgicalDay = container.read(liturgicalDayProvider(testDate));

      expect(liturgicalDay, isA<LiturgicalDayData>());
      expect(liturgicalDay!.date, equals('2025-12-25'));
      expect(liturgicalDay.celebration.name, contains('Christmas'));
    });

    test('upcomingFeastsProvider returns a list of upcoming feasts', () {
      final feasts = container.read(upcomingFeastsProvider(10)); // Next 10 days
      expect(feasts, isA<List<LiturgicalDayData>>());
      expect(feasts, isNotEmpty);
    });

    test(
        'currentLiturgicalDayProvider returns current day or null if outside range',
        () {
      // Since the actual date of running the test determines the result for
      // LiturgicalCalendarService.getCurrentDay(), we need to check if the
      // current date falls within the pre-generated data range (2024-2035).
      // The test will only pass if the current date is within that range.
      final now = DateTime.now();
      final currentDay = container.read(currentLiturgicalDayProvider);

      if (now.year >= 2024 && now.year <= 2035) {
        expect(currentDay, isA<LiturgicalDayData>());
        expect(currentDay!.dateTime.year, equals(now.year));
        expect(currentDay.dateTime.month, equals(now.month));
        expect(currentDay.dateTime.day, equals(now.day));
      } else {
        expect(currentDay, isNull);
      }
    });

  });
}