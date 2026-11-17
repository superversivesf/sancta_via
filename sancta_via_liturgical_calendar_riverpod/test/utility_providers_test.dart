import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sancta_via_liturgical_calendar/sancta_via_liturgical_calendar.dart';
import 'package:sancta_via_liturgical_calendar_riverpod/src/providers/utility_providers.dart';


void main() {
  group('Utility Providers - Major Feasts', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('majorFeastsProvider returns solemnities for a year', () {
      final feasts = container.read(majorFeastsProvider(2025));
      expect(feasts, isA<List<LiturgicalDayData>>());
      for (final feast in feasts) {
        expect(feast.celebration.rank, equals('SOLEMNITY'));
        expect(feast.celebration.prioritized, isTrue);
      }
    });

    test('majorFeastsProvider includes Christmas', () {
      final feasts = container.read(majorFeastsProvider(2025));
      final christmas = feasts.where((f) => f.date.endsWith('-12-25'));
      expect(christmas.isNotEmpty, isTrue);
      expect(christmas.first.celebration.name, contains('Christmas'));
    });
  });

  group('Utility Providers - Mary Feasts', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('maryFeastsProvider returns Mary-related celebrations', () {
      final maryFeasts = container.read(maryFeastsProvider(2025));
      expect(maryFeasts, isA<List<LiturgicalDayData>>());
      for (final feast in maryFeasts) {
        expect(feast.celebration.name.toLowerCase(), contains('mary'));
      }
    });
  });

  group('Utility Providers - Saint Commemorations', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('saintCommemorationsProvider returns memorials', () {
      final saints = container.read(saintCommemorationsProvider(2025));
      expect(saints, isA<List<LiturgicalDayData>>());
      for (final saint in saints) {
        expect(
          saint.celebration.rank,
          anyOf('MEMORIAL', 'OPTIONAL_MEMORIAL', 'OPT_MEMORIAL'),
        );
      }
    });
  });

  group('Utility Providers - Date Range', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('thisWeekProvider returns days in current week', () {
      final week = container.read(thisWeekProvider);
      expect(week, isA<List<LiturgicalDayData>>());
      final now = DateTime.now();
      for (final day in week) {
        final dayDate = DateTime.parse(day.date);
        expect(dayDate.year, equals(now.year));
      }
    });

    test('thisMonthProvider returns days in current month', () {
      final month = container.read(thisMonthProvider);
      expect(month, isA<List<LiturgicalDayData>>());
      final now = DateTime.now();
      for (final day in month) {
        final dayDate = DateTime.parse(day.date);
        expect(dayDate.month, equals(now.month));
      }
    });

    test('feastDaysThisMonthProvider returns prioritized days', () {
      final feasts = container.read(feastDaysThisMonthProvider);
      expect(feasts, isA<List<LiturgicalDayData>>());
      for (final feast in feasts) {
        final isFeast =
            feast.celebration.prioritized ||
            feast.celebration.rank == 'SOLEMNITY' ||
            feast.celebration.rank == 'FEAST';
        expect(isFeast, isTrue);
      }
    });
  });

  group('Utility Providers - Analytics', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('liturgicalAnalyticsProvider returns statistics', () {
      final analytics = container.read(liturgicalAnalyticsProvider(2025));
      expect(analytics, isA<Map<String, dynamic>>());
      expect(analytics['totalDays'], isA<int>());
      expect(analytics['seasonCounts'], isA<Map<String, int>>());
      expect(analytics['colorCounts'], isA<Map<String, int>>());
      expect(analytics['rankCounts'], isA<Map<String, int>>());
      expect(analytics['prioritizedCount'], isA<int>());
    });

    test('liturgicalAnalyticsProvider counts match total days', () {
      final analytics = container.read(liturgicalAnalyticsProvider(2025));
      final seasonCounts = analytics['seasonCounts'] as Map<String, int>;
      final totalFromSeasons = seasonCounts.values.fold(0, (a, b) => a + b);
      expect(totalFromSeasons, equals(analytics['totalDays']));
    });
  });

  group('Utility Providers - Next Celebration', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('nextMajorCelebrationProvider returns a celebration or null', () {
      final next = container.read(nextMajorCelebrationProvider);
      expect(next, anyOf(isNull, isA<LiturgicalDayData>()));
    });

    test('daysUntilMajorCelebrationProvider returns int or null', () {
      final days = container.read(daysUntilMajorCelebrationProvider);
      expect(days, anyOf(isNull, isA<int>()));
    });
  });

  group('Utility Providers - Liturgical Mode', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('liturgicalModeProvider returns mode info', () {
      final mode = container.read(liturgicalModeProvider);
      expect(mode, isA<Map<String, dynamic>>());
      expect(mode['mode'], isA<String>());
      expect(mode['emphasis'], isA<String>());
    });

    test('liturgicalYearProgressProvider returns progress info', () {
      final progress = container.read(liturgicalYearProgressProvider);
      expect(progress, isA<Map<String, dynamic>>());
      expect(progress['progress'], isA<double>());
      expect(progress['dayOfYear'], isA<int>());
      expect(progress['totalDays'], isA<int>());
    });
  });

  group('Utility Providers - Reminders', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('liturgicalRemindersProvider returns prioritized reminders', () {
      final reminders = container.read(liturgicalRemindersProvider);
      expect(reminders, isA<List<Map<String, dynamic>>>());
      for (final reminder in reminders) {
        expect(reminder['title'], isA<String>());
        expect(reminder['date'], isA<String>());
        expect(reminder['daysUntil'], isA<int>());
      }
    });

    test('seasonalColorProgressionProvider returns season transitions', () {
      final progression = container.read(seasonalColorProgressionProvider);
      expect(progression, isA<List<Map<String, dynamic>>>());
      expect(progression.length, greaterThan(0));
      for (final season in progression) {
        expect(season['season'], isA<String>());
        expect(season['color'], isA<String>());
        expect(season['startDate'], isA<String>());
        expect(season['endDate'], isA<String>());
      }
    });
  });
}
