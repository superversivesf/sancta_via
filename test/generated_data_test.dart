import 'package:test/test.dart';
import 'package:liturgical_calendar/liturgical_calendar.dart';

void main() {
  group('Generated Liturgical Data', () {
    test('should have all expected years available', () {
      final availableYears = GeneratedLiturgicalData.getAvailableYears();
      
      expect(availableYears.length, equals(12));
      expect(availableYears.first, equals(2024));
      expect(availableYears.last, equals(2035));
      expect(availableYears.contains(2025), isTrue);
    });

    test('should provide correct year range', () {
      final yearRange = GeneratedLiturgicalData.yearRange;
      
      expect(yearRange.start, equals(2024));
      expect(yearRange.end, equals(2035));
    });

    test('should return calendar data for valid years', () {
      final year2025Data = GeneratedLiturgicalData.getYearData(2025);
      
      expect(year2025Data, isNotNull);
      expect(year2025Data!.isNotEmpty, isTrue);
      expect(year2025Data.length, equals(365)); // 2025 is not a leap year
    });

    test('should return null for invalid years', () {
      final invalidYearData = GeneratedLiturgicalData.getYearData(2020);
      
      expect(invalidYearData, isNull);
    });

    test('should find Christmas Day correctly', () {
      final christmas = GeneratedLiturgicalData.getDayForDate(DateTime(2025, 12, 25));
      
      expect(christmas, isNotNull);
      expect(christmas!.celebration.name, contains('Christmas'));
      expect(christmas.celebration.rank, equals('SOLEMNITY'));
      expect(christmas.celebration.prioritized, isTrue);
    });

    test('should return null for dates outside range', () {
      final outsideRange = GeneratedLiturgicalData.getDayForDate(DateTime(2020, 1, 1));
      
      expect(outsideRange, isNull);
    });

    test('should have correct total statistics', () {
      final totalDays = GeneratedLiturgicalData.getTotalDays();
      final totalCelebrations = GeneratedLiturgicalData.getTotalPrioritizedCelebrations();
      
      expect(totalDays, equals(4383)); // 12 years of days
      expect(totalCelebrations, equals(856)); // Total prioritized celebrations
    });

    test('should provide year metadata', () {
      final metadata = GeneratedLiturgicalData.getYearMetadata(2025);
      
      expect(metadata, isNotNull);
      expect(metadata!['year'], equals(2025));
      expect(metadata['totalDays'], equals(365));
      expect(metadata['dataVersion'], equals('1.0.0'));
      expect(metadata['romcalVersion'], equals('1.3.0'));
    });
  });

  group('LiturgicalCalendarService', () {
    test('should be ready without initialization', () {
      expect(LiturgicalCalendarService.isInitialized, isTrue);
    });

    test('should get current day if in range', () {
      final today = LiturgicalCalendarService.getCurrentDay();
      final now = DateTime.now();
      
      if (now.year >= 2024 && now.year <= 2035) {
        expect(today, isNotNull);
        expect(today!.dateTime.year, equals(now.year));
        expect(today.dateTime.month, equals(now.month));
        expect(today.dateTime.day, equals(now.day));
      } else {
        expect(today, isNull);
      }
    });

    test('should get liturgical day for specific date', () {
      final christmas = LiturgicalCalendarService.getDayForDate(DateTime(2025, 12, 25));
      
      expect(christmas, isNotNull);
      expect(christmas!.celebration.name, contains('Christmas'));
      expect(christmas.season, contains('Christmas'));
    });

    test('should get days in range correctly', () {
      final start = DateTime(2025, 12, 20);
      final end = DateTime(2025, 12, 30);
      final daysInRange = LiturgicalCalendarService.getDaysInRange(start, end);
      
      expect(daysInRange.length, equals(11)); // 20-30 inclusive
      expect(daysInRange.first.date, equals('2025-12-20'));
      expect(daysInRange.last.date, equals('2025-12-30'));
    });

    test('should find upcoming feasts', () {
      final feasts = LiturgicalCalendarService.getUpcomingFeasts(
        fromDate: DateTime(2025, 1, 1),
        daysAhead: 365,
      );
      
      expect(feasts, isNotEmpty);
      expect(feasts.every((f) => f.celebration.prioritized || 
                              f.celebration.rank == 'SOLEMNITY' || 
                              f.celebration.rank == 'FEAST' || 
                              f.celebration.rank == 'MEMORIAL'), isTrue);
    });

    test('should get prioritized celebrations for year', () {
      final prioritized = LiturgicalCalendarService.getPrioritizedCelebrationsForYear(2025);
      
      expect(prioritized, isNotEmpty);
      expect(prioritized.every((day) => day.celebration.prioritized), isTrue);
      expect(prioritized.length, equals(72)); // Expected for 2025
    });

    test('should search celebrations by name', () {
      final maryFeasts = LiturgicalCalendarService.searchCelebrations('Mary', year: 2025);
      
      expect(maryFeasts, isNotEmpty);
      expect(maryFeasts.every((f) => f.celebration.name.toLowerCase().contains('mary')), isTrue);
    });

    test('should get days for specific season', () {
      final adventDays = LiturgicalCalendarService.getDaysForSeason(2025, 'Advent');
      
      expect(adventDays, isNotEmpty);
      expect(adventDays.every((day) => day.season.toLowerCase().contains('advent')), isTrue);
    });

    test('should get days by rank', () {
      final solemnities = LiturgicalCalendarService.getDaysByRank(2025, 'SOLEMNITY');
      
      expect(solemnities, isNotEmpty);
      expect(solemnities.every((day) => day.celebration.rank == 'SOLEMNITY'), isTrue);
    });

    test('should provide global statistics', () {
      final stats = LiturgicalCalendarService.getGlobalStatistics();
      
      expect(stats['totalYears'], equals(12));
      expect(stats['totalDays'], equals(4383));
      expect(stats['yearStart'], equals(2024));
      expect(stats['yearEnd'], equals(2035));
    });

    test('should find next occurrence of celebration', () {
      final nextChristmas = LiturgicalCalendarService.getNextOccurrence(
        'Christmas',
        fromDate: DateTime(2025, 1, 1),
      );
      
      expect(nextChristmas, isNotNull);
      expect(nextChristmas!.celebration.name, contains('Christmas'));
      expect(nextChristmas.dateTime.isAfter(DateTime(2025, 1, 1)), isTrue);
    });

    test('should get available years', () {
      final years = LiturgicalCalendarService.getAvailableYears();
      
      expect(years.length, equals(12));
      expect(years.contains(2025), isTrue);
      expect(years.first, equals(2024));
      expect(years.last, equals(2035));
    });

    test('should check year availability', () {
      expect(LiturgicalCalendarService.isYearAvailable(2025), isTrue);
      expect(LiturgicalCalendarService.isYearAvailable(2020), isFalse);
    });

    test('should get all days for a year', () {
      final days2025 = LiturgicalCalendarService.getAllDaysForYear(2025);
      
      expect(days2025.length, equals(365));
      expect(days2025.first.date, equals('2025-01-01'));
      expect(days2025.last.date, equals('2025-12-31'));
    });
  });

  group('Data Integrity', () {
    test('should have continuous dates within years', () {
      final year2025Data = GeneratedLiturgicalData.getYearData(2025)!;
      final dates = year2025Data.keys.toList()..sort();
      
      // Should have 365 days for 2025 (not a leap year)
      expect(dates.length, equals(365));
      expect(dates.first, equals('2025-01-01'));
      expect(dates.last, equals('2025-12-31'));
    });

    test('should have all years with data', () {
      final years = GeneratedLiturgicalData.getAvailableYears();
      
      for (final year in years) {
        final data = GeneratedLiturgicalData.getYearData(year);
        expect(data, isNotNull, reason: 'Year $year should have data');
        expect(data!.isNotEmpty, isTrue, reason: 'Year $year should not be empty');
      }
    });

    test('should have expected leap year days', () {
      // Test leap years in our range: 2024, 2028, 2032
      final leapYears = [2024, 2028, 2032];
      
      for (final year in leapYears) {
        final data = GeneratedLiturgicalData.getYearData(year)!;
        expect(data.length, equals(366), reason: '$year should have 366 days (leap year)');
      }
    });

    test('should have Christmas in all years', () {
      final years = GeneratedLiturgicalData.getAvailableYears();
      
      for (final year in years) {
        final christmas = GeneratedLiturgicalData.getDayForDate(DateTime(year, 12, 25));
        expect(christmas, isNotNull, reason: 'Christmas should exist in $year');
        expect(christmas!.celebration.name, contains('Christmas'), 
               reason: 'December 25 should be Christmas in $year');
      }
    });
  });

  group('Performance', () {
    test('should have fast data access', () {
      final stopwatch = Stopwatch()..start();
      
      // Test 1000 rapid accesses
      for (int i = 0; i < 1000; i++) {
        LiturgicalCalendarService.getDayForDate(DateTime(2025, 12, 25));
      }
      
      stopwatch.stop();
      final avgMicroseconds = stopwatch.elapsedMicroseconds / 1000;
      
      // Should be very fast (under 1ms average)
      expect(avgMicroseconds, lessThan(1000), 
             reason: 'Average access time should be under 1ms');
    });

    test('should have instant initialization', () {
      // Service should always be ready
      expect(LiturgicalCalendarService.isInitialized, isTrue);
      expect(LiturgicalCalendarService.totalYears, equals(12));
    });
  });
}
