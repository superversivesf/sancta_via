import '../models/liturgical_day_data.dart';
import '../data/generated/generated_liturgical_data.dart';

/// High-performance liturgical calendar service using embedded Dart data
/// 
/// This service provides zero-overhead access to liturgical calendar data
/// by using pre-generated Dart objects directly, with no external dependencies.
class LiturgicalCalendarService {
  /// Check if the service has data available
  static bool get isInitialized => true; // Always ready - data is embedded

  /// Get the total number of available years
  static int get totalYears => GeneratedLiturgicalData.getAvailableYears().length;

  /// Get liturgical day for a specific date
  /// 
  /// Returns null if the date is outside the available range.
  /// This is the fastest possible liturgical data access.
  static LiturgicalDayData? getDayForDate(DateTime date) {
    return GeneratedLiturgicalData.getDayForDate(date);
  }

  /// Get current liturgical day
  static LiturgicalDayData? getCurrentDay() {
    return getDayForDate(DateTime.now());
  }

  /// Get liturgical days for a date range
  static List<LiturgicalDayData> getDaysInRange(
    DateTime startDate,
    DateTime endDate,
  ) {
    final days = <LiturgicalDayData>[];
    
    for (var date = startDate; 
         date.isBefore(endDate.add(const Duration(days: 1))); 
         date = date.add(const Duration(days: 1))) {
      final day = getDayForDate(date);
      if (day != null) {
        days.add(day);
      }
    }
    
    return days;
  }

  /// Get upcoming feasts and solemnities
  static List<LiturgicalDayData> getUpcomingFeasts({
    int daysAhead = 30,
    DateTime? fromDate,
  }) {
    final start = fromDate ?? DateTime.now();
    final end = start.add(Duration(days: daysAhead));
    
    final days = getDaysInRange(start, end);
    
    return days.where((day) => 
      day.celebration.prioritized ||
      day.celebration.rank == 'SOLEMNITY' ||
      day.celebration.rank == 'FEAST' ||
      day.celebration.rank == 'MEMORIAL'
    ).toList();
  }

  /// Get all prioritized celebrations in a year
  static List<LiturgicalDayData> getPrioritizedCelebrationsForYear(int year) {
    final yearData = GeneratedLiturgicalData.getYearData(year);
    if (yearData == null) return [];
    
    return yearData.values
        .where((day) => day.celebration.prioritized)
        .toList();
  }

  /// Get all available years
  static List<int> getAvailableYears() {
    return GeneratedLiturgicalData.getAvailableYears();
  }

  /// Check if a year is available
  static bool isYearAvailable(int year) {
    return GeneratedLiturgicalData.isYearAvailable(year);
  }

  /// Get year range of available data
  static ({int start, int end}) getYearRange() {
    return GeneratedLiturgicalData.yearRange;
  }

  /// Get all liturgical days for a specific year
  static List<LiturgicalDayData> getAllDaysForYear(int year) {
    final yearData = GeneratedLiturgicalData.getYearData(year);
    if (yearData == null) return [];
    
    return yearData.values.toList()..sort((a, b) => a.date.compareTo(b.date));
  }

  /// Get liturgical days for a specific season in a year
  static List<LiturgicalDayData> getDaysForSeason(int year, String season) {
    final yearData = GeneratedLiturgicalData.getYearData(year);
    if (yearData == null) return [];
    
    return yearData.values
        .where((day) => day.season.toLowerCase() == season.toLowerCase())
        .toList()
        ..sort((a, b) => a.date.compareTo(b.date));
  }

  /// Get liturgical days by rank
  static List<LiturgicalDayData> getDaysByRank(
    int year, 
    String rank,
  ) {
    final yearData = GeneratedLiturgicalData.getYearData(year);
    if (yearData == null) return [];
    
    return yearData.values
        .where((day) => day.celebration.rank == rank)
        .toList()
        ..sort((a, b) => a.date.compareTo(b.date));
  }

  /// Get total statistics across all years
  static Map<String, int> getGlobalStatistics() {
    return {
      'totalYears': GeneratedLiturgicalData.getAvailableYears().length,
      'totalDays': GeneratedLiturgicalData.getTotalDays(),
      'totalPrioritizedCelebrations': GeneratedLiturgicalData.getTotalPrioritizedCelebrations(),
      'yearStart': GeneratedLiturgicalData.yearRange.start,
      'yearEnd': GeneratedLiturgicalData.yearRange.end,
    };
  }

  /// Search for celebrations by name (case-insensitive)
  static List<LiturgicalDayData> searchCelebrations(String query, {int? year}) {
    final searchQuery = query.toLowerCase();
    final results = <LiturgicalDayData>[];
    
    if (year != null) {
      // Search in specific year
      final yearData = GeneratedLiturgicalData.getYearData(year);
      if (yearData != null) {
        results.addAll(
          yearData.values.where((day) => 
            day.celebration.name.toLowerCase().contains(searchQuery)
          )
        );
      }
    } else {
      // Search across all years
      for (final searchYear in GeneratedLiturgicalData.getAvailableYears()) {
        final yearData = GeneratedLiturgicalData.getYearData(searchYear);
        if (yearData != null) {
          results.addAll(
            yearData.values.where((day) => 
              day.celebration.name.toLowerCase().contains(searchQuery)
            )
          );
        }
      }
    }
    
    return results..sort((a, b) => a.date.compareTo(b.date));
  }

  /// Get next occurrence of a specific celebration
  static LiturgicalDayData? getNextOccurrence(
    String celebrationName, {
    DateTime? fromDate,
  }) {
    final start = fromDate ?? DateTime.now();
    final searchQuery = celebrationName.toLowerCase();
    
    // Search in the current year and next year
    for (var year = start.year; year <= start.year + 1; year++) {
      final yearData = GeneratedLiturgicalData.getYearData(year);
      if (yearData == null) continue;
      
      final matches = yearData.values
          .where((day) => 
            day.celebration.name.toLowerCase().contains(searchQuery) &&
            day.dateTime.isAfter(start)
          )
          .toList()
          ..sort((a, b) => a.date.compareTo(b.date));
      
      if (matches.isNotEmpty) {
        return matches.first;
      }
    }
    
    return null;
  }
}
