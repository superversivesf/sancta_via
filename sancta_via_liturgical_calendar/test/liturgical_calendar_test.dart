import 'package:sancta_via_liturgical_calendar/sancta_via_liturgical_calendar.dart';
import 'package:test/test.dart';

void main() {
  group('LiturgicalCalendarService', () {
    test('should be ready immediately without initialization', () {
      expect(LiturgicalCalendarService.isInitialized, isTrue);
      expect(LiturgicalCalendarService.totalYears, equals(12));
    });

    test('should return available years correctly', () {
      final years = LiturgicalCalendarService.getAvailableYears();

      expect(years.length, equals(12));
      expect(years.first, equals(2024));
      expect(years.last, equals(2035));
      expect(years.contains(2025), isTrue);
    });

    test('should check year availability correctly', () {
      expect(LiturgicalCalendarService.isYearAvailable(2025), isTrue);
      expect(LiturgicalCalendarService.isYearAvailable(2020), isFalse);
      expect(LiturgicalCalendarService.isYearAvailable(2040), isFalse);
    });

    test('should return correct year range', () {
      final range = LiturgicalCalendarService.getYearRange();
      expect(range.start, equals(2024));
      expect(range.end, equals(2035));
    });

    test('should get liturgical day for valid dates', () {
      final christmas = LiturgicalCalendarService.getDayForDate(
        DateTime(2025, 12, 25),
      );

      expect(christmas, isNotNull);
      expect(christmas!.celebration.name, contains('Christmas'));
      expect(christmas.celebration.rank, equals('SOLEMNITY'));
      expect(christmas.celebration.prioritized, isTrue);
      expect(christmas.season, contains('Christmas'));
    });

    test('should return null for dates outside range', () {
      final outsideRange = LiturgicalCalendarService.getDayForDate(
        DateTime(2020, 12, 25),
      );
      expect(outsideRange, isNull);

      final futureDate = LiturgicalCalendarService.getDayForDate(
        DateTime(2040, 1, 1),
      );
      expect(futureDate, isNull);
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

    test('should get days in range correctly', () {
      final start = DateTime(2025, 12, 20);
      final end = DateTime(2025, 12, 30);
      final daysInRange = LiturgicalCalendarService.getDaysInRange(start, end);

      expect(daysInRange.length, equals(11)); // 20-30 inclusive
      expect(daysInRange.first.date, equals('2025-12-20'));
      expect(daysInRange.last.date, equals('2025-12-30'));

      // Verify chronological order
      for (int i = 1; i < daysInRange.length; i++) {
        expect(
          daysInRange[i].dateTime.isAfter(daysInRange[i - 1].dateTime),
          isTrue,
        );
      }
    });

    test('should find upcoming feasts', () {
      final feasts = LiturgicalCalendarService.getUpcomingFeasts(
        fromDate: DateTime(2025, 1, 1),
        daysAhead: 365,
      );

      expect(feasts, isNotEmpty);
      expect(
        feasts.every(
          (f) =>
              f.celebration.prioritized ||
              f.celebration.rank == 'SOLEMNITY' ||
              f.celebration.rank == 'FEAST' ||
              f.celebration.rank == 'MEMORIAL',
        ),
        isTrue,
      );

      // Should include Christmas
      expect(
        feasts.any((f) => f.celebration.name.contains('Christmas')),
        isTrue,
      );
    });

    test('should search celebrations by name', () {
      final maryFeasts = LiturgicalCalendarService.searchCelebrations(
        'Mary',
        year: 2025,
      );

      expect(maryFeasts, isNotEmpty);
      expect(
        maryFeasts.every(
          (f) => f.celebration.name.toLowerCase().contains('mary'),
        ),
        isTrue,
      );

      // Search across all years
      final allMaryFeasts = LiturgicalCalendarService.searchCelebrations(
        'Mary',
      );
      expect(allMaryFeasts.length, greaterThan(maryFeasts.length));
    });

    test('should get days for specific season', () {
      final adventDays = LiturgicalCalendarService.getDaysForSeason(
        2025,
        'Advent',
      );

      expect(adventDays, isNotEmpty);
      expect(
        adventDays.every((day) => day.season.toLowerCase().contains('advent')),
        isTrue,
      );

      // Should be in chronological order
      for (int i = 1; i < adventDays.length; i++) {
        expect(
          adventDays[i].dateTime.isAfter(adventDays[i - 1].dateTime),
          isTrue,
        );
      }
    });

    test('should get days by rank', () {
      final solemnities = LiturgicalCalendarService.getDaysByRank(
        2025,
        'SOLEMNITY',
      );

      expect(solemnities, isNotEmpty);
      expect(
        solemnities.every((day) => day.celebration.rank == 'SOLEMNITY'),
        isTrue,
      );
      expect(
        solemnities.any((day) => day.celebration.name.contains('Christmas')),
        isTrue,
      );
    });

    test('should get prioritized celebrations for year', () {
      final prioritized =
          LiturgicalCalendarService.getPrioritizedCelebrationsForYear(2025);

      expect(prioritized, isNotEmpty);
      expect(prioritized.every((day) => day.celebration.prioritized), isTrue);
      expect(prioritized.length, equals(72)); // Expected for 2025
    });

    test('should provide global statistics', () {
      final stats = LiturgicalCalendarService.getGlobalStatistics();

      expect(stats['totalYears'], equals(12));
      expect(stats['totalDays'], equals(4383));
      expect(stats['totalPrioritizedCelebrations'], equals(856));
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
      expect(nextChristmas.dateTime.month, equals(12));
      expect(nextChristmas.dateTime.day, equals(25));
    });

    test('should get all days for a year', () {
      final days2025 = LiturgicalCalendarService.getAllDaysForYear(2025);

      expect(days2025.length, equals(365)); // 2025 is not a leap year
      expect(days2025.first.date, equals('2025-01-01'));
      expect(days2025.last.date, equals('2025-12-31'));

      // Verify chronological order
      for (int i = 1; i < days2025.length; i++) {
        expect(days2025[i].dateTime.isAfter(days2025[i - 1].dateTime), isTrue);
      }
    });

    test('should handle leap years correctly', () {
      final days2024 = LiturgicalCalendarService.getAllDaysForYear(
        2024,
      ); // Leap year
      expect(days2024.length, equals(366));

      final days2025 = LiturgicalCalendarService.getAllDaysForYear(
        2025,
      ); // Not leap year
      expect(days2025.length, equals(365));
    });
  });

  group('LiturgicalDayData', () {
    test('should parse date correctly', () {
      final dayData = LiturgicalDayData(
        date: '2025-12-25',
        season: 'Christmas',
        seasonKey: 'christmas',
        celebration: const LiturgicalCelebration(
          key: 'christmas',
          name: 'Christmas',
          type: 'SOLEMNITY',
          rank: 'SOLEMNITY',
          color: 'WHITE',
          colorName: 'White',
          source: 'GENERAL',
          prioritized: true,
          titles: [],
        ),
        liturgicalYear: const LiturgicalYearInfo(
          year: 2025,
          cycle: LiturgicalCycle(key: 1, value: 'C'),
          week: 52,
          day: 4,
          weekOfSeason: 1,
        ),
        psalterWeek: const PsalterWeek(key: 1, value: 'Week I'),
      );

      expect(dayData.dateTime, equals(DateTime(2025, 12, 25)));
      expect(dayData.isSolemnity, isTrue);
      expect(dayData.hasPrioritizedCelebration, isTrue);
      expect(dayData.displayName, equals('Christmas'));
    });

    test('should identify celebration types correctly', () {
      final solemnity = LiturgicalDayData(
        date: '2025-12-25',
        season: 'Christmas',
        seasonKey: 'christmas',
        celebration: const LiturgicalCelebration(
          key: 'christmas',
          name: 'Christmas',
          type: 'SOLEMNITY',
          rank: 'SOLEMNITY',
          color: 'WHITE',
          colorName: 'White',
          source: 'GENERAL',
          prioritized: true,
          titles: [],
        ),
        liturgicalYear: const LiturgicalYearInfo(
          year: 2025,
          cycle: LiturgicalCycle(key: 1, value: 'C'),
          week: 52,
          day: 4,
          weekOfSeason: 1,
        ),
        psalterWeek: const PsalterWeek(key: 1, value: 'Week I'),
      );

      expect(solemnity.isSolemnity, isTrue);
      expect(solemnity.isFeast, isFalse);
      expect(solemnity.isMemorial, isFalse);
      expect(solemnity.isWeekday, isFalse);
    });
  });

  group('Enums', () {
    test('LiturgicalSeason should convert from string', () {
      expect(
        LiturgicalSeason.fromString('advent'),
        equals(LiturgicalSeason.advent),
      );
      expect(
        LiturgicalSeason.fromString('christmas'),
        equals(LiturgicalSeason.christmas),
      );
      expect(
        LiturgicalSeason.fromString('ordinary time'),
        equals(LiturgicalSeason.ordinaryTime),
      );
      expect(LiturgicalSeason.fromString('invalid'), isNull);
    });

    test('LiturgicalColor should convert from string', () {
      expect(
        LiturgicalColor.fromString('WHITE'),
        equals(LiturgicalColor.white),
      );
      expect(LiturgicalColor.fromString('red'), equals(LiturgicalColor.red));
      expect(
        LiturgicalColor.fromString('PURPLE'),
        equals(LiturgicalColor.purple),
      );
      expect(LiturgicalColor.fromString('invalid'), isNull);
    });

    test('LiturgicalColor should provide hex colors', () {
      expect(LiturgicalColor.white.hexColor, equals('#FFFFFF'));
      expect(LiturgicalColor.red.hexColor, equals('#DC143C'));
      expect(LiturgicalColor.green.hexColor, equals('#228B22'));
    });

    test('CelebrationRank should convert from string', () {
      expect(
        CelebrationRank.fromString('SOLEMNITY'),
        equals(CelebrationRank.solemnity),
      );
      expect(
        CelebrationRank.fromString('FEAST'),
        equals(CelebrationRank.feast),
      );
      expect(
        CelebrationRank.fromString('OPT_MEMORIAL'),
        equals(CelebrationRank.optionalMemorial),
      );
      expect(
        CelebrationRank.fromString('invalid'),
        equals(CelebrationRank.weekday),
      );
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
      expect(avgMicroseconds, lessThan(1000));
    });

    test('should have instant service availability', () {
      // Service should always be ready
      expect(LiturgicalCalendarService.isInitialized, isTrue);
      expect(LiturgicalCalendarService.totalYears, greaterThan(0));
    });
  });
}
