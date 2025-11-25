import 'dart:math';

import '../models/prayer.dart';
import '../models/prayer_time_of_day.dart';

/// Service for selecting time-of-day appropriate prayers
class TimeOfDayPrayerService {
  /// Select a random prayer for the current time of day
  ///
  /// Only selects from prayers specifically tagged for the current time period.
  /// Uses the date as a seed for consistent daily selection.
  ///
  /// [prayers] - Prayers for the current time of day
  /// [date] - Date to use as seed for random selection (ensures same prayer all day)
  static Prayer? selectRandomPrayer({
    required List<Prayer> prayers,
    required DateTime date,
  }) {
    return _selectFromList(prayers, date);
  }

  /// Select a prayer from a list using date-based seeding
  static Prayer? _selectFromList(List<Prayer> prayers, DateTime date) {
    if (prayers.isEmpty) return null;

    // Create a seed from the date (year * 1000 + day of year)
    // This ensures the same prayer is selected throughout the day
    final dayOfYear = date.difference(DateTime(date.year, 1, 1)).inDays;
    final seed = date.year * 1000 + dayOfYear;

    final random = Random(seed);
    final index = random.nextInt(prayers.length);

    return prayers[index];
  }

  /// Get a different random prayer (for manual refresh)
  ///
  /// Uses a timestamp to get variety when manually refreshing
  static Prayer? selectDifferentPrayer({
    required List<Prayer> prayers,
    required DateTime dateTime,
  }) {
    if (prayers.isEmpty) return null;

    // Use full timestamp for variety when manually refreshing
    final seed = dateTime.millisecondsSinceEpoch;
    final random = Random(seed);
    final index = random.nextInt(prayers.length);

    return prayers[index];
  }

  /// Get the current time of day period
  static PrayerTimeOfDay getCurrentTimeOfDay() {
    return PrayerTimeOfDay.current();
  }

  /// Get time of day for a specific DateTime
  static PrayerTimeOfDay getTimeOfDayFor(DateTime dateTime) {
    return PrayerTimeOfDay.fromDateTime(dateTime);
  }
}
