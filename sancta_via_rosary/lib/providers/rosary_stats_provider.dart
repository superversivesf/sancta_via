import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/rosary_statistics_service.dart';

/// Provider for the statistics service instance
final rosaryStatisticsServiceProvider = Provider<RosaryStatisticsService>((
  ref,
) {
  throw UnimplementedError('Initialize with override in ProviderScope');
});

/// Future provider for fetching all statistics
final rosaryStatisticsProvider = FutureProvider<RosaryStatistics>((ref) async {
  final service = ref.watch(rosaryStatisticsServiceProvider);
  return await service.getStatistics();
});

/// Stream provider for real-time statistics updates
final rosaryStatisticsStreamProvider = StreamProvider<RosaryStatistics>((
  ref,
) async* {
  final service = ref.watch(rosaryStatisticsServiceProvider);

  // Yield initial data
  yield await service.getStatistics();

  // Stream periodic updates (every 30 seconds when active)
  await for (final _ in Stream.periodic(const Duration(seconds: 30))) {
    yield await service.getStatistics();
  }
});

/// Provider for just the total completed count
final totalCompletedProvider = Provider<AsyncValue<int>>((ref) {
  final statsAsync = ref.watch(rosaryStatisticsProvider);
  return statsAsync.when(
    data: (stats) => AsyncValue.data(stats.totalRosariesCompleted),
    loading: () => const AsyncValue.loading(),
    error: (err, stack) => AsyncValue.error(err, stack),
  );
});

/// Provider for current streak
final currentStreakProvider = Provider<AsyncValue<int>>((ref) {
  final statsAsync = ref.watch(rosaryStatisticsProvider);
  return statsAsync.when(
    data: (stats) => AsyncValue.data(stats.currentStreak),
    loading: () => const AsyncValue.loading(),
    error: (err, stack) => AsyncValue.error(err, stack),
  );
});

/// Provider for longest streak
final longestStreakProvider = Provider<AsyncValue<int>>((ref) {
  final statsAsync = ref.watch(rosaryStatisticsProvider);
  return statsAsync.when(
    data: (stats) => AsyncValue.data(stats.longestStreak),
    loading: () => const AsyncValue.loading(),
    error: (err, stack) => AsyncValue.error(err, stack),
  );
});

/// Provider for weekly chart data (last 7 days)
final weeklyChartDataProvider = Provider<AsyncValue<Map<String, int>>>((ref) {
  final statsAsync = ref.watch(rosaryStatisticsProvider);
  return statsAsync.when(
    data: (stats) => AsyncValue.data(stats.weeklyCounts),
    loading: () => const AsyncValue.loading(),
    error: (err, stack) => AsyncValue.error(err, stack),
  );
});

/// Provider for monthly chart data (last 4 weeks)
final monthlyChartDataProvider = Provider<AsyncValue<Map<String, int>>>((ref) {
  final statsAsync = ref.watch(rosaryStatisticsProvider);
  return statsAsync.when(
    data: (stats) => AsyncValue.data(stats.monthlyCounts),
    loading: () => const AsyncValue.loading(),
    error: (err, stack) => AsyncValue.error(err, stack),
  );
});

/// Provider for favorite mystery set
final favoriteMysteryProvider = Provider<AsyncValue>((ref) {
  final statsAsync = ref.watch(rosaryStatisticsProvider);
  return statsAsync.when(
    data: (stats) => AsyncValue.data(stats.favoriteMysterySet),
    loading: () => const AsyncValue.loading(),
    error: (err, stack) => AsyncValue.error(err, stack),
  );
});

/// Provider for recent sessions
final recentSessionsProvider = Provider<AsyncValue<List>>((ref) {
  final statsAsync = ref.watch(rosaryStatisticsProvider);
  return statsAsync.when(
    data: (stats) => AsyncValue.data(stats.recentSessions),
    loading: () => const AsyncValue.loading(),
    error: (err, stack) => AsyncValue.error(err, stack),
  );
});

/// Provider for total time spent praying
final totalTimeProvider = Provider<AsyncValue<String>>((ref) {
  final statsAsync = ref.watch(rosaryStatisticsProvider);
  return statsAsync.when(
    data: (stats) => AsyncValue.data(stats.totalTimeFormatted),
    loading: () => const AsyncValue.loading(),
    error: (err, stack) => AsyncValue.error(err, stack),
  );
});

/// Provider for whether statistics exist
final hasStatisticsProvider = Provider<AsyncValue<bool>>((ref) {
  final statsAsync = ref.watch(rosaryStatisticsProvider);
  return statsAsync.when(
    data: (stats) => AsyncValue.data(stats.hasData),
    loading: () => const AsyncValue.loading(),
    error: (err, stack) => AsyncValue.error(err, stack),
  );
});

/// Notifier for refreshing statistics
class StatisticsRefreshNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;

  StatisticsRefreshNotifier(this._ref) : super(const AsyncValue.data(null));

  /// Force refresh of statistics
  Future<void> refresh() async {
    state = const AsyncValue.loading();
    try {
      // Invalidate the provider to trigger a refetch
      _ref.invalidate(rosaryStatisticsProvider);
      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }
}

/// Provider for refresh functionality
final statisticsRefreshProvider =
    StateNotifierProvider<StatisticsRefreshNotifier, AsyncValue<void>>(
      (ref) => StatisticsRefreshNotifier(ref),
    );
