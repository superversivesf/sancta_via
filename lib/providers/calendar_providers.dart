import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sancta_via_liturgical_calendar/sancta_via_liturgical_calendar.dart';

// Provider for the selected date in the calendar
final selectedDateProvider = StateProvider<DateTime>((ref) => DateTime.now());

// Provider for the currently displayed month - initially set to the current month
final displayedMonthProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, 1); // First day of current month
});

// Provider for liturgical days in the currently displayed month
final monthLiturgicalDaysProvider = Provider<Map<int, LiturgicalDayData>>((ref) {
  final displayedMonth = ref.watch(displayedMonthProvider);

  // Get the first and last day of the displayed month
  final firstDay = DateTime(displayedMonth.year, displayedMonth.month, 1);
  final lastDay = DateTime(displayedMonth.year, displayedMonth.month + 1, 0);

  final daysData = LiturgicalCalendarService.getDaysInRange(firstDay, lastDay);
  final Map<int, LiturgicalDayData> monthDays = {};
  
  for (final data in daysData) {
    final date = DateTime.parse(data.date);
    monthDays[date.day] = data;
  }
  
  return monthDays;
});

// Provider for liturgical day by specific date
final liturgicalDayForDateProvider = Provider.family<LiturgicalDayData?, DateTime>((ref, date) {
  return LiturgicalCalendarService.getDayForDate(date);
});

// Provider for upcoming feasts and celebrations
final upcomingFeastsProvider = Provider<List<LiturgicalDayData>>((ref) {
  return LiturgicalCalendarService.getUpcomingFeasts(daysAhead: 30);
});

// Provider for search functionality
final searchQueryProvider = StateProvider<String>((ref) => '');

final searchResultsProvider = Provider<List<LiturgicalDayData>>((ref) {
  final query = ref.watch(searchQueryProvider);
  
  if (query.isEmpty) {
    return [];
  }
  
  // Get all search results
  final allResults = LiturgicalCalendarService.searchCelebrations(query);
  
  // Filter results to only show celebrations within one year from today
  final today = DateTime.now();
  final oneYearFromToday = DateTime(
    today.year + 1, 
    today.month, 
    today.day,
  );
  
  final filteredResults = allResults.where((result) {
    final resultDate = DateTime.parse(result.date);
    // Show results from today onwards up to one year from today
    return resultDate.isAfter(today.subtract(const Duration(days: 1))) && 
           resultDate.isBefore(oneYearFromToday.add(const Duration(days: 1)));
  }).toList();
  
  // Sort results by date (chronological order)
  filteredResults.sort((a, b) {
    final dateA = DateTime.parse(a.date);
    final dateB = DateTime.parse(b.date);
    return dateA.compareTo(dateB);
  });
  
  return filteredResults;
});