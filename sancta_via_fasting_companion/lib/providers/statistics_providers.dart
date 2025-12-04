import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/fast_session.dart';
import '../models/fast_type.dart';
import '../models/statistics_data.dart';
import 'fast_session_providers.dart';
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

/// Provider for fasting activity over time (for charts)
final fastingActivityDataProvider =
    FutureProvider.family<List<FastingActivityData>, StatisticsPeriod>(
  (ref, period) async {
    final history = await ref.watch(fastHistoryProvider.future);
    final startDate = period.startDate;

    // Filter sessions by period
    final filteredSessions = history.where((session) {
      return session.startTime.isAfter(startDate) &&
          session.status.toString().contains('completed');
    }).toList();

    // Group by date
    final Map<String, List<FastSession>> groupedByDate = {};
    for (final session in filteredSessions) {
      final dateKey =
          '${session.startTime.year}-${session.startTime.month.toString().padLeft(2, '0')}-${session.startTime.day.toString().padLeft(2, '0')}';
      groupedByDate.putIfAbsent(dateKey, () => []).add(session);
    }

    // Create data points
    final List<FastingActivityData> dataPoints = [];
    for (final entry in groupedByDate.entries) {
      final date = DateTime.parse(entry.key);
      final sessions = entry.value;
      final totalHours = sessions.fold<double>(
        0,
        (sum, s) => sum + (s.elapsedMinutes / 60),
      );

      dataPoints.add(FastingActivityData(
        date: date,
        fastsCount: sessions.length,
        totalHours: totalHours,
      ));
    }

    // Sort by date
    dataPoints.sort((a, b) => a.date.compareTo(b.date));
    return dataPoints;
  },
);

/// Provider for fast duration distribution (for pie chart)
final durationDistributionProvider =
    FutureProvider<List<DurationDistribution>>((ref) async {
  final history = await ref.watch(fastHistoryProvider.future);
  final completed = history.where((s) => s.status.toString().contains('completed'));

  final Map<String, int> distribution = {
    '0-6h': 0,
    '6-12h': 0,
    '12-18h': 0,
    '18-24h': 0,
    '24-48h': 0,
    '48+h': 0,
  };

  for (final session in completed) {
    final hours = session.elapsedHours;
    if (hours < 6) {
      distribution['0-6h'] = distribution['0-6h']! + 1;
    } else if (hours < 12) {
      distribution['6-12h'] = distribution['6-12h']! + 1;
    } else if (hours < 18) {
      distribution['12-18h'] = distribution['12-18h']! + 1;
    } else if (hours < 24) {
      distribution['18-24h'] = distribution['18-24h']! + 1;
    } else if (hours < 48) {
      distribution['24-48h'] = distribution['24-48h']! + 1;
    } else {
      distribution['48+h'] = distribution['48+h']! + 1;
    }
  }

  return distribution.entries
      .where((e) => e.value > 0)
      .map((e) => DurationDistribution(range: e.key, count: e.value))
      .toList();
});

/// Provider for fast type distribution (for pie chart)
final fastTypeDistributionProvider =
    FutureProvider<List<FastTypeDistribution>>((ref) async {
  final history = await ref.watch(fastHistoryProvider.future);
  final allFastTypes = await ref.watch(allFastTypesProvider.future);
  final completed = history.where((s) => s.status.toString().contains('completed'));

  final Map<String, int> counts = {};
  for (final session in completed) {
    counts[session.fastTypeId] = (counts[session.fastTypeId] ?? 0) + 1;
  }

  final total = completed.length;
  if (total == 0) return [];

  final List<FastTypeDistribution> distribution = [];
  for (final entry in counts.entries) {
    final fastType = allFastTypes.firstWhere(
      (ft) => ft.id == entry.key,
      orElse: () => allFastTypes.first,
    );
    distribution.add(FastTypeDistribution(
      fastTypeName: fastType.name,
      count: entry.value,
      percentage: (entry.value / total) * 100,
    ));
  }

  // Sort by count descending
  distribution.sort((a, b) => b.count.compareTo(a.count));
  return distribution;
});
