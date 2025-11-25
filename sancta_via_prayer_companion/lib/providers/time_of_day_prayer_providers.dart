import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/prayer.dart';
import '../models/prayer_time_of_day.dart';
import '../services/time_of_day_prayer_service.dart';
import 'prayer_providers.dart';

/// Provider for the current time of day period
///
/// Returns the current time period (morning, afternoon, evening, night)
/// based on the device's current time.
final currentTimeOfDayProvider = Provider<PrayerTimeOfDay>((ref) {
  return PrayerTimeOfDay.current();
});

/// Provider for prayers available for the current time of day
///
/// Returns only prayers specifically tagged for the current time period.
/// No fallback to "anytime" prayers - exact matches only.
final timeOfDayPrayersProvider = FutureProvider<List<Prayer>>((ref) async {
  final repository = ref.watch(prayerRepositoryProvider);
  final currentTime = ref.watch(currentTimeOfDayProvider);

  // Get prayers for exact time of day only (no anytime fallback)
  final result = await repository.getPrayersForTimeOfDay(currentTime);
  return result.timePrayers;
});

/// Provider for the time-of-day prayer
///
/// Selects a random prayer from the current time period.
/// Only selects from exact time-of-day matches (no anytime prayers).
/// The selection randomizes on each app opening.
final dailyTimeOfDayPrayerProvider = FutureProvider<Prayer?>((ref) async {
  final prayers = await ref.watch(timeOfDayPrayersProvider.future);
  final now = DateTime.now();

  return TimeOfDayPrayerService.selectDifferentPrayer(
    prayers: prayers,
    dateTime: now,
  );
});

/// Provider for the time-of-day prayer context
///
/// Returns metadata about the current time-of-day prayer selection
/// useful for UI display (e.g., "Morning Prayer", "Evening Prayer")
final timeOfDayPrayerContextProvider = Provider<Map<String, String>>((ref) {
  final currentTime = ref.watch(currentTimeOfDayProvider);

  return {
    'timeOfDay': currentTime.toStringValue(),
    'displayName': currentTime.displayName,
    'panelLabel': currentTime.panelLabel,
  };
});

/// Provider to get the count of available prayers for each time period
///
/// Useful for debugging or displaying statistics
final timeOfDayPrayerStatsProvider = FutureProvider<Map<String, int>>((
  ref,
) async {
  final repository = ref.watch(prayerRepositoryProvider);
  final allPrayers = await repository.getAllPrayers();

  final stats = <String, int>{
    'morning': 0,
    'afternoon': 0,
    'evening': 0,
    'night': 0,
    'anytime': 0,
  };

  for (final prayer in allPrayers) {
    final timeOfDay = prayer.timeOfDay;
    stats[timeOfDay] = (stats[timeOfDay] ?? 0) + 1;
  }

  return stats;
});
