import 'dart:convert';

import '../models/liturgical_calendar_data.dart';
import '../models/liturgical_day_data.dart';
import '../models/liturgical_index.dart';
import '../exceptions/liturgical_calendar_exception.dart';
import 'data_loader.dart';

/// Main service for liturgical calendar operations
/// 
/// This service provides methods to load, cache, and query liturgical calendar data.
/// It requires a [LiturgicalDataLoader] implementation to load the actual data.
class LiturgicalCalendarService {
  static LiturgicalIndex? _index;
  static final Map<int, LiturgicalCalendarData> _cachedYears = {};
  static LiturgicalDataLoader? _dataLoader;

  /// Initialize the service with a data loader
  static Future<void> initialize(LiturgicalDataLoader dataLoader) async {
    _dataLoader = dataLoader;
    
    try {
      final indexJson = await dataLoader.loadIndexData();
      final indexData = json.decode(indexJson);
      _index = LiturgicalIndex.fromJson(indexData);
    } catch (e) {
      throw LiturgicalCalendarException(
        'Failed to initialize liturgical calendar service: $e',
        type: LiturgicalCalendarExceptionType.initialization,
      );
    }
  }

  /// Get the index information
  static LiturgicalIndex? get index => _index;

  /// Check if the service is initialized
  static bool get isInitialized => _index != null && _dataLoader != null;

  /// Load liturgical data for a specific year
  static Future<LiturgicalCalendarData> loadYear(int year) async {
    if (!isInitialized) {
      throw LiturgicalCalendarException(
        'Liturgical calendar service not initialized. Call initialize() first.',
        type: LiturgicalCalendarExceptionType.notInitialized,
      );
    }

    // Check cache first
    if (_cachedYears.containsKey(year)) {
      return _cachedYears[year]!;
    }

    final yearInfo = _index!.getYearInfo(year);
    if (yearInfo == null) {
      throw LiturgicalCalendarException(
        'Year $year not available in liturgical data',
        type: LiturgicalCalendarExceptionType.yearNotAvailable,
      );
    }

    try {
      final yearJson = await _dataLoader!.loadYearData(yearInfo.file);
      final yearData = json.decode(yearJson);
      final liturgicalYear = LiturgicalCalendarData.fromJson(yearData);
      
      // Cache the loaded data
      _cachedYears[year] = liturgicalYear;
      
      return liturgicalYear;
    } catch (e) {
      throw LiturgicalCalendarException(
        'Failed to load liturgical data for year $year: $e',
        type: LiturgicalCalendarExceptionType.dataLoading,
      );
    }
  }

  /// Get liturgical day for a specific date
  static Future<LiturgicalDayData?> getDayForDate(DateTime date) async {
    if (!isInitialized) {
      return null; // Gracefully handle uninitialized state
    }

    final year = date.year;
    
    try {
      final yearData = await loadYear(year);
      return yearData.getDayForDate(date);
    } catch (e) {
      // Return null instead of throwing for day lookups
      return null;
    }
  }

  /// Get current liturgical day
  static Future<LiturgicalDayData?> getCurrentDay() async {
    return getDayForDate(DateTime.now());
  }

  /// Get liturgical days for a date range
  static Future<List<LiturgicalDayData>> getDaysInRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    if (!isInitialized) {
      return [];
    }

    final days = <LiturgicalDayData>[];
    
    // Determine which years we need to load
    final yearsToLoad = <int>{};
    for (var date = startDate; 
         date.isBefore(endDate.add(const Duration(days: 1))); 
         date = date.add(const Duration(days: 1))) {
      yearsToLoad.add(date.year);
    }

    // Load all required years
    for (final year in yearsToLoad) {
      try {
        await loadYear(year);
      } catch (e) {
        // Skip years that can't be loaded
        continue;
      }
    }

    // Collect days in range
    for (var date = startDate; 
         date.isBefore(endDate.add(const Duration(days: 1))); 
         date = date.add(const Duration(days: 1))) {
      final day = await getDayForDate(date);
      if (day != null) {
        days.add(day);
      }
    }

    return days;
  }

  /// Get upcoming feasts and solemnities
  static Future<List<LiturgicalDayData>> getUpcomingFeasts({
    int daysAhead = 30,
    DateTime? fromDate,
  }) async {
    final start = fromDate ?? DateTime.now();
    final end = start.add(Duration(days: daysAhead));
    
    final days = await getDaysInRange(start, end);
    
    return days.where((day) => 
      day.celebration.prioritized ||
      day.celebration.rank == 'SOLEMNITY' ||
      day.celebration.rank == 'FEAST' ||
      day.celebration.rank == 'MEMORIAL'
    ).toList();
  }

  /// Clear cached data
  static void clearCache() {
    _cachedYears.clear();
  }

  /// Get available years
  static List<int> getAvailableYears() {
    return _index?.availableYears ?? [];
  }

  /// Check if a year is available
  static bool isYearAvailable(int year) {
    return _index?.isYearAvailable(year) ?? false;
  }

  /// Get year range of available data
  static ({int start, int end}) getYearRange() {
    return _index?.yearRange ?? (start: 0, end: 0);
  }

  /// Reset the service (useful for testing)
  static void reset() {
    _index = null;
    _cachedYears.clear();
    _dataLoader = null;
  }
}