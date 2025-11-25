import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sancta_via_liturgical_calendar/sancta_via_liturgical_calendar.dart';

/// Current date provider that updates at midnight
final currentDateProvider = StreamProvider<DateTime>((ref) {
  return Stream.periodic(const Duration(minutes: 1), (_) => DateTime.now())
      .distinct(
        (previous, next) =>
            previous.year == next.year &&
            previous.month == next.month &&
            previous.day == next.day,
      )
      .asBroadcastStream();
});

/// Current liturgical day provider that updates automatically
final currentLiturgicalDayProvider = Provider<LiturgicalDayData?>((ref) {
  final dateAsync = ref.watch(currentDateProvider);

  return dateAsync.when(
    data: (date) => LiturgicalCalendarService.getDayForDate(date),
    loading: () => LiturgicalCalendarService.getCurrentDay(),
    error: (_, __) => LiturgicalCalendarService.getCurrentDay(),
  );
});

/// Provider for a specific liturgical day by date
final liturgicalDayProvider = Provider.family<LiturgicalDayData?, DateTime>((
  ref,
  date,
) {
  return LiturgicalCalendarService.getDayForDate(date);
});

/// Provider for upcoming feasts and celebrations
final upcomingFeastsProvider = Provider.family<List<LiturgicalDayData>, int>((
  ref,
  daysAhead,
) {
  return LiturgicalCalendarService.getUpcomingFeasts(daysAhead: daysAhead);
});

/// Provider for liturgical days in a date range
final daysInRangeProvider =
    Provider.family<List<LiturgicalDayData>, ({DateTime start, DateTime end})>((
      ref,
      range,
    ) {
      return LiturgicalCalendarService.getDaysInRange(range.start, range.end);
    });

/// Provider for searching celebrations by name
final searchCelebrationsProvider =
    Provider.family<List<LiturgicalDayData>, ({String query, int? year})>((
      ref,
      params,
    ) {
      return LiturgicalCalendarService.searchCelebrations(
        params.query,
        year: params.year,
      );
    });

/// Provider for liturgical days in a specific season
final seasonDaysProvider =
    Provider.family<List<LiturgicalDayData>, ({int year, String season})>((
      ref,
      params,
    ) {
      return LiturgicalCalendarService.getDaysForSeason(
        params.year,
        params.season,
      );
    });

/// Provider for liturgical days by rank
final daysByRankProvider =
    Provider.family<List<LiturgicalDayData>, ({int year, String rank})>((
      ref,
      params,
    ) {
      return LiturgicalCalendarService.getDaysByRank(params.year, params.rank);
    });

/// Provider for prioritized celebrations in a year
final prioritizedCelebrationsProvider =
    Provider.family<List<LiturgicalDayData>, int>((ref, year) {
      return LiturgicalCalendarService.getPrioritizedCelebrationsForYear(year);
    });

/// Provider for all days in a specific year
final allDaysInYearProvider = Provider.family<List<LiturgicalDayData>, int>((
  ref,
  year,
) {
  return LiturgicalCalendarService.getAllDaysForYear(year);
});

/// Provider for finding next occurrence of a celebration
final nextOccurrenceProvider =
    Provider.family<
      LiturgicalDayData?,
      ({String celebration, DateTime? fromDate})
    >((ref, params) {
      return LiturgicalCalendarService.getNextOccurrence(
        params.celebration,
        fromDate: params.fromDate,
      );
    });

/// Provider for available years
final availableYearsProvider = Provider<List<int>>((ref) {
  return LiturgicalCalendarService.getAvailableYears();
});

/// Provider for global liturgical statistics
final globalStatisticsProvider = Provider<Map<String, int>>((ref) {
  return LiturgicalCalendarService.getGlobalStatistics();
});

/// Provider for checking if a year is available
final yearAvailabilityProvider = Provider.family<bool, int>((ref, year) {
  return LiturgicalCalendarService.isYearAvailable(year);
});

/// Provider for year range information
final yearRangeProvider = Provider<({int start, int end})>((ref) {
  return LiturgicalCalendarService.getYearRange();
});

/// Provider for current liturgical season
final currentLiturgicalSeasonProvider = Provider<String?>((ref) {
  final currentDay = ref.watch(currentLiturgicalDayProvider);
  return currentDay?.season;
});

/// Provider for current liturgical color
final currentLiturgicalColorProvider = Provider<String?>((ref) {
  final currentDay = ref.watch(currentLiturgicalDayProvider);
  return currentDay?.celebration.color;
});

/// Provider for current celebration rank
final currentCelebrationRankProvider = Provider<String?>((ref) {
  final currentDay = ref.watch(currentLiturgicalDayProvider);
  return currentDay?.celebration.rank;
});

/// Provider for whether today has a prioritized celebration
final todayHasPrioritizedCelebrationProvider = Provider<bool>((ref) {
  final currentDay = ref.watch(currentLiturgicalDayProvider);
  return currentDay?.celebration.prioritized ?? false;
});

/// Provider for today's liturgical cycle information
final currentLiturgicalCycleProvider = Provider<LiturgicalCycle?>((ref) {
  final currentDay = ref.watch(currentLiturgicalDayProvider);
  return currentDay?.liturgicalYear.cycle;
});

/// Provider for today's psalter week
final currentPsalterWeekProvider = Provider<PsalterWeek?>((ref) {
  final currentDay = ref.watch(currentLiturgicalDayProvider);
  return currentDay?.psalterWeek;
});
