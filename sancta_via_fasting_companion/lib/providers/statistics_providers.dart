import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/fast_type.dart';
import 'fast_type_providers.dart';

/// Provider for total completed fasts count
final completedFastsCountProvider = FutureProvider<int>((ref) async {
  final repository = ref.watch(fastingRepositoryProvider);
  return repository.getCompletedFastsCount();
});

/// Provider for total hours fasted
final totalHoursFastedProvider = FutureProvider<double>((ref) async {
  final repository = ref.watch(fastingRepositoryProvider);
  return repository.getTotalHoursFasted();
});

/// Provider for average fast duration
final averageFastDurationProvider = FutureProvider<double>((ref) async {
  final repository = ref.watch(fastingRepositoryProvider);
  return repository.getAverageFastDuration();
});

/// Provider for completion rate
final completionRateProvider = FutureProvider<double>((ref) async {
  final repository = ref.watch(fastingRepositoryProvider);
  return repository.getCompletionRate();
});

/// Provider for current streak
final currentStreakProvider = FutureProvider<int>((ref) async {
  final repository = ref.watch(fastingRepositoryProvider);
  return repository.getCurrentStreak();
});

/// Provider for longest streak
final longestStreakProvider = FutureProvider<int>((ref) async {
  final repository = ref.watch(fastingRepositoryProvider);
  return repository.getLongestStreak();
});

/// Provider for most common fast type
final mostCommonFastTypeProvider = FutureProvider<FastType?>((ref) async {
  final repository = ref.watch(fastingRepositoryProvider);
  return repository.getMostCommonFastType();
});

/// Combined statistics provider for dashboard
final dashboardStatisticsProvider = FutureProvider<DashboardStatistics>(
  (ref) async {
    final completedCount = await ref.watch(completedFastsCountProvider.future);
    final totalHours = await ref.watch(totalHoursFastedProvider.future);
    final currentStreak = await ref.watch(currentStreakProvider.future);
    final longestStreak = await ref.watch(longestStreakProvider.future);
    final completionRate = await ref.watch(completionRateProvider.future);
    final averageDuration = await ref.watch(averageFastDurationProvider.future);
    final mostCommonType = await ref.watch(mostCommonFastTypeProvider.future);

    return DashboardStatistics(
      completedFastsCount: completedCount,
      totalHoursFasted: totalHours,
      currentStreak: currentStreak,
      longestStreak: longestStreak,
      completionRate: completionRate,
      averageDuration: averageDuration,
      mostCommonFastType: mostCommonType,
    );
  },
);

/// Data class for dashboard statistics
class DashboardStatistics {
  final int completedFastsCount;
  final double totalHoursFasted;
  final int currentStreak;
  final int longestStreak;
  final double completionRate;
  final double averageDuration;
  final FastType? mostCommonFastType;

  const DashboardStatistics({
    required this.completedFastsCount,
    required this.totalHoursFasted,
    required this.currentStreak,
    required this.longestStreak,
    required this.completionRate,
    required this.averageDuration,
    this.mostCommonFastType,
  });
}
