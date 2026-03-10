import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../services/rosary_session_service.dart';
import 'session_provider.dart';

/// Provider for session statistics
final statisticsProvider = FutureProvider<RosaryStatistics>((ref) async {
  final service = ref.watch(rosarySessionServiceProvider);
  return service.getStatistics();
});

/// Provider for total number of completed rosaries
final totalRosariesProvider = FutureProvider<int>((ref) async {
  final service = ref.watch(rosarySessionServiceProvider);
  return service.getTotalRosaries();
});

/// Provider for current streak (consecutive days)
final currentStreakProvider = FutureProvider<int>((ref) async {
  final service = ref.watch(rosarySessionServiceProvider);
  return service.getCurrentStreak();
});

/// Provider for longest streak ever achieved
final longestStreakProvider = FutureProvider<int>((ref) async {
  final service = ref.watch(rosarySessionServiceProvider);
  return service.getLongestStreak();
});

/// Provider for total Hail Marys prayed
final totalHailMarysProvider = FutureProvider<int>((ref) async {
  final service = ref.watch(rosarySessionServiceProvider);
  return service.getTotalHailMarys();
});

/// Provider for number of full rosaries (total mysteries / 5)
final fullRosariesProvider = FutureProvider<int>((ref) async {
  final statsAsync = ref.watch(statisticsProvider);
  return statsAsync.when(
    data: (stats) => stats.fullRosaries,
    loading: () => 0,
    error: (_, __) => 0,
  );
});

/// Provider for extra mysteries beyond full rosaries
final extraMysteriesProvider = FutureProvider<int>((ref) async {
  final statsAsync = ref.watch(statisticsProvider);
  return statsAsync.when(
    data: (stats) => stats.extraMysteries,
    loading: () => 0,
    error: (_, __) => 0,
  );
});

/// Provider for sessions in the last 7 days
final weeklySessionsProvider = FutureProvider<List<RosarySession>>((ref) async {
  final service = ref.watch(rosarySessionServiceProvider);
  final now = DateTime.now();
  final weekAgo = now.subtract(const Duration(days: 7));
  return service.getSessionsInRange(weekAgo, now);
});

/// Provider for sessions in the last 30 days
final monthlySessionsProvider = FutureProvider<List<RosarySession>>((
  ref,
) async {
  final service = ref.watch(rosarySessionServiceProvider);
  final now = DateTime.now();
  final monthAgo = now.subtract(const Duration(days: 30));
  return service.getSessionsInRange(monthAgo, now);
});

/// Provider for today's sessions
final todaysSessionsProvider = FutureProvider<List<RosarySession>>((ref) async {
  final service = ref.watch(rosarySessionServiceProvider);
  final now = DateTime.now();
  final startOfDay = DateTime(now.year, now.month, now.day);
  final endOfDay = startOfDay.add(const Duration(days: 1));
  return service.getSessionsInRange(startOfDay, endOfDay);
});

/// Provider for whether a rosary has been completed today
final rosaryCompletedTodayProvider = FutureProvider<bool>((ref) async {
  final sessionsAsync = ref.watch(todaysSessionsProvider);
  return sessionsAsync.when(
    data: (sessions) => sessions.any((s) => s.completed),
    loading: () => false,
    error: (_, __) => false,
  );
});

/// Provider for count of completed rosaries today
final todaysCompletedCountProvider = FutureProvider<int>((ref) async {
  final sessionsAsync = ref.watch(todaysSessionsProvider);
  return sessionsAsync.when(
    data: (sessions) => sessions.where((s) => s.completed).length,
    loading: () => 0,
    error: (_, __) => 0,
  );
});

/// Provider for sessions grouped by mystery set
final sessionsByMysterySetProvider = FutureProvider<Map<MysterySet, int>>((
  ref,
) async {
  final service = ref.watch(rosarySessionServiceProvider);
  final sessions = await service.getCompletedSessions();

  final counts = <MysterySet, int>{};
  for (final set in MysterySet.values) {
    counts[set] = 0;
  }

  for (final session in sessions) {
    counts[session.mysterySet] =
        (counts[session.mysterySet] ?? 0) + session.completedCount;
  }

  return counts;
});

/// Provider for favorite/preferred mystery set
final favoriteMysterySetProvider = FutureProvider<MysterySet?>((ref) async {
  final sessionsAsync = ref.watch(sessionsByMysterySetProvider);
  return sessionsAsync.when(
    data: (counts) {
      if (counts.isEmpty) return null;

      MysterySet? favorite;
      var maxCount = 0;
      counts.forEach((set, count) {
        if (count > maxCount) {
          maxCount = count;
          favorite = set;
        }
      });

      return favorite;
    },
    loading: () => null,
    error: (_, __) => null,
  );
});

/// Provider for average session duration
final averageSessionDurationProvider = FutureProvider<Duration>((ref) async {
  final service = ref.watch(rosarySessionServiceProvider);
  final sessions = await service.getCompletedSessions();

  if (sessions.isEmpty) return Duration.zero;

  var totalMinutes = 0;
  var sessionsWithDuration = 0;

  for (final session in sessions) {
    final duration = session.durationMinutes;
    if (duration != null && duration > 0) {
      totalMinutes += duration;
      sessionsWithDuration++;
    }
  }

  if (sessionsWithDuration == 0) return Duration.zero;

  return Duration(minutes: totalMinutes ~/ sessionsWithDuration);
});

/// Provider for daily prayer goal (configurable, default 1)
final dailyGoalProvider = StateProvider<int>((ref) => 1);

/// Provider for today's progress toward daily goal
final dailyGoalProgressProvider = Provider<double>((ref) {
  final goal = ref.watch(dailyGoalProvider);
  final completedAsync = ref.watch(todaysCompletedCountProvider);

  return completedAsync.when(
    data: (completed) => (completed / goal).clamp(0.0, 1.0),
    loading: () => 0.0,
    error: (_, __) => 0.0,
  );
});

/// Provider for whether daily goal is met
final dailyGoalMetProvider = Provider<bool>((ref) {
  final goal = ref.watch(dailyGoalProvider);
  final completedAsync = ref.watch(todaysCompletedCountProvider);

  return completedAsync.when(
    data: (completed) => completed >= goal,
    loading: () => false,
    error: (_, __) => false,
  );
});

/// Notifier for weekly prayer goal
class WeeklyGoalNotifier extends StateNotifier<int> {
  WeeklyGoalNotifier() : super(7); // Default: one rosary per day

  void setGoal(int goal) {
    if (goal >= 1 && goal <= 35) {
      state = goal;
    }
  }
}

/// Provider for weekly prayer goal
final weeklyGoalProvider = StateNotifierProvider<WeeklyGoalNotifier, int>(
  (ref) => WeeklyGoalNotifier(),
);

/// Provider for weekly progress toward goal
final weeklyGoalProgressProvider = Provider<double>((ref) {
  final goal = ref.watch(weeklyGoalProvider);
  final weeklyAsync = ref.watch(weeklySessionsProvider);

  return weeklyAsync.when(
    data: (sessions) {
      final completedCount = sessions
          .where((s) => s.completed)
          .fold<int>(0, (sum, s) => sum + s.completedCount);
      return (completedCount / goal).clamp(0.0, 1.0);
    },
    loading: () => 0.0,
    error: (_, __) => 0.0,
  );
});

/// Provider for prayer streak heatmap data (last 30 days)
final streakHeatmapProvider = FutureProvider<List<StreakDay>>((ref) async {
  final service = ref.watch(rosarySessionServiceProvider);
  final now = DateTime.now();
  final history = await service.getSessionHistory();

  final days = <StreakDay>[];
  for (var i = 29; i >= 0; i--) {
    final date = now.subtract(Duration(days: i));
    final dayStart = DateTime(date.year, date.month, date.day);
    final dayEnd = dayStart.add(const Duration(days: 1));

    final daySessions = history.where((s) {
      return s.startTime.isAfter(dayStart) &&
          s.startTime.isBefore(dayEnd) &&
          s.completed;
    });

    final count = daySessions.fold<int>(0, (sum, s) => sum + s.completedCount);

    days.add(
      StreakDay(date: dayStart, completedCount: count, hasActivity: count > 0),
    );
  }

  return days;
});

/// Represents a day in the streak heatmap
class StreakDay {
  final DateTime date;
  final int completedCount;
  final bool hasActivity;

  const StreakDay({
    required this.date,
    required this.completedCount,
    required this.hasActivity,
  });

  /// Intensity level for heatmap coloring (0-4)
  int get intensityLevel {
    if (completedCount == 0) return 0;
    if (completedCount >= 5) return 4;
    return completedCount;
  }
}

/// Provider to refresh all statistics
final refreshStatisticsProvider = Provider<Future<void> Function()>((ref) {
  return () async {
    // Invalidate all statistics-related providers
    ref.invalidate(statisticsProvider);
    ref.invalidate(totalRosariesProvider);
    ref.invalidate(currentStreakProvider);
    ref.invalidate(longestStreakProvider);
    ref.invalidate(totalHailMarysProvider);
    ref.invalidate(fullRosariesProvider);
    ref.invalidate(extraMysteriesProvider);
    ref.invalidate(weeklySessionsProvider);
    ref.invalidate(monthlySessionsProvider);
    ref.invalidate(todaysSessionsProvider);
    ref.invalidate(sessionsByMysterySetProvider);
    ref.invalidate(streakHeatmapProvider);
  };
});
