import '../models/rosary_session.dart';
import '../models/rosary_statistics.dart';

class RosaryStatisticsSummary {
  const RosaryStatisticsSummary({
    required this.totalSessions,
    required this.totalRosaries,
    required this.totalDecades,
    required this.totalPrayerTimeMinutes,
    required this.averageTimePerSession,
    required this.currentStreak,
    required this.bestStreak,
    required this.weeklyStats,
    required this.monthlyStats,
    required this.yearlyStats,
  });

  final int totalSessions;
  final int totalRosaries;
  final int totalDecades;
  final int totalPrayerTimeMinutes;
  final double averageTimePerSession;
  final int currentStreak;
  final int bestStreak;
  final List<RosaryStatistics> weeklyStats;
  final List<RosaryStatistics> monthlyStats;
  final List<RosaryStatistics> yearlyStats;

  double get averageTimePerDecade {
    final totalDecadesAll = totalRosaries * 5 + totalDecades;
    if (totalDecadesAll == 0) return 0.0;
    return totalPrayerTimeMinutes.toDouble() / totalDecadesAll;
  }

  int get totalPrayerTimeHours => totalPrayerTimeMinutes ~/ 60;
  int get totalDaysActive => weeklyStats.length;

  RosaryStatisticsSummary copyWith({
    int? totalSessions,
    int? totalRosaries,
    int? totalDecades,
    int? totalPrayerTimeMinutes,
    double? averageTimePerSession,
    int? currentStreak,
    int? bestStreak,
    List<RosaryStatistics>? weeklyStats,
    List<RosaryStatistics>? monthlyStats,
    List<RosaryStatistics>? yearlyStats,
  }) {
    return RosaryStatisticsSummary(
      totalSessions: totalSessions ?? this.totalSessions,
      totalRosaries: totalRosaries ?? this.totalRosaries,
      totalDecades: totalDecades ?? this.totalDecades,
      totalPrayerTimeMinutes:
          totalPrayerTimeMinutes ?? this.totalPrayerTimeMinutes,
      averageTimePerSession:
          averageTimePerSession ?? this.averageTimePerSession,
      currentStreak: currentStreak ?? this.currentStreak,
      bestStreak: bestStreak ?? this.bestStreak,
      weeklyStats: weeklyStats ?? this.weeklyStats,
      monthlyStats: monthlyStats ?? this.monthlyStats,
      yearlyStats: yearlyStats ?? this.yearlyStats,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RosaryStatisticsSummary &&
        other.totalSessions == totalSessions &&
        other.totalRosaries == totalRosaries &&
        other.totalDecades == totalDecades &&
        other.totalPrayerTimeMinutes == totalPrayerTimeMinutes &&
        other.averageTimePerSession == averageTimePerSession &&
        other.currentStreak == currentStreak &&
        other.bestStreak == bestStreak &&
        other.weeklyStats == weeklyStats &&
        other.monthlyStats == monthlyStats &&
        other.yearlyStats == yearlyStats;
  }

  @override
  int get hashCode =>
      totalSessions.hashCode ^
      totalRosaries.hashCode ^
      totalDecades.hashCode ^
      totalPrayerTimeMinutes.hashCode ^
      averageTimePerSession.hashCode ^
      currentStreak.hashCode ^
      bestStreak.hashCode ^
      weeklyStats.hashCode ^
      monthlyStats.hashCode ^
      yearlyStats.hashCode;
}

class RosaryStatisticsService {
  static const int streakGracePeriodHours = 36;
  static const int minimumPrayerTimeMinutes = 5;

  static RosaryStatisticsSummary calculateSummary(
    List<RosarySession> sessions,
    List<RosaryStatistics> statistics,
  ) {
    if (sessions.isEmpty) {
      return const RosaryStatisticsSummary(
        totalSessions: 0,
        totalRosaries: 0,
        totalDecades: 0,
        totalPrayerTimeMinutes: 0,
        averageTimePerSession: 0.0,
        currentStreak: 0,
        bestStreak: 0,
        weeklyStats: [],
        monthlyStats: [],
        yearlyStats: [],
      );
    }

    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final monthStart = DateTime(now.year, now.month, 1);
    final yearStart = DateTime(now.year, 1, 1);

    int totalRosaries = 0;
    int totalDecades = 0;
    int totalPrayerTime = 0;
    List<int> sessionTimes = [];

    for (final session in sessions) {
      if (session.isComplete && session.completedBeads > 0) {
        final duration = session.estimatedDurationMinutes;

        if (duration >= minimumPrayerTimeMinutes) {
          totalPrayerTime += duration;
          sessionTimes.add(duration);

          if (session.completedBeads >= 53) {
            totalRosaries++;
          } else {
            totalDecades++;
          }
        }
      }
    }

    final averageTimePerSession = sessionTimes.isEmpty
        ? 0.0
        : sessionTimes.reduce((a, b) => a + b) / sessionTimes.length;

    final weeklyStats = _filterStatisticsByDate(statistics, weekStart, now);
    final monthlyStats = _filterStatisticsByDate(statistics, monthStart, now);
    final yearlyStats = _filterStatisticsByDate(statistics, yearStart, now);

    final streakData = _calculateStreaks(sessions);

    return RosaryStatisticsSummary(
      totalSessions: totalRosaries + totalDecades,
      totalRosaries: totalRosaries,
      totalDecades: totalDecades,
      totalPrayerTimeMinutes: totalPrayerTime,
      averageTimePerSession: averageTimePerSession,
      currentStreak: streakData['current'] ?? 0,
      bestStreak: streakData['best'] ?? 0,
      weeklyStats: weeklyStats,
      monthlyStats: monthlyStats,
      yearlyStats: yearlyStats,
    );
  }

  static List<RosaryStatistics> _filterStatisticsByDate(
    List<RosaryStatistics> statistics,
    DateTime startDate,
    DateTime endDate,
  ) {
    return statistics
        .where(
          (stats) =>
              !stats.date.isBefore(startDate) && !stats.date.isAfter(endDate),
        )
        .toList();
  }

  static Map<String, int> _calculateStreaks(List<RosarySession> sessions) {
    if (sessions.isEmpty) {
      return {'current': 0, 'best': 0};
    }

    final completedSessions = sessions
        .where((s) => s.isComplete && s.completedBeads > 0)
        .toList();

    if (completedSessions.isEmpty) {
      return {'current': 0, 'best': 0};
    }

    completedSessions.sort((a, b) => b.startTime.compareTo(a.startTime));

    int currentStreak = 0;
    int bestStreak = 0;
    int tempStreak = 0;
    DateTime? lastDate;

    for (final session in completedSessions) {
      final sessionDate = DateTime(
        session.startTime.year,
        session.startTime.month,
        session.startTime.day,
      );

      if (lastDate == null) {
        tempStreak = 1;
      } else {
        final daysDifference = lastDate.difference(sessionDate).inDays;

        if (daysDifference <= 1) {
          tempStreak++;
        } else if (daysDifference <= streakGracePeriodHours ~/ 24) {
        } else {
          if (tempStreak > bestStreak) {
            bestStreak = tempStreak;
          }
          tempStreak = 1;
        }
      }

      lastDate = sessionDate;

      if (tempStreak > bestStreak) {
        bestStreak = tempStreak;
      }

      if (currentStreak == 0 &&
          session.startTime.isAfter(
            DateTime.now().subtract(const Duration(days: 2)),
          )) {
        currentStreak = tempStreak;
      }
    }

    if (tempStreak > bestStreak) {
      bestStreak = tempStreak;
    }

    if (currentStreak == 0 && bestStreak > 0) {
      final latestSession = completedSessions.first;
      final daysSinceLatest = DateTime.now()
          .difference(latestSession.startTime)
          .inDays;

      if (daysSinceLatest <= 1) {
        currentStreak = tempStreak;
      }
    }

    return {'current': currentStreak, 'best': bestStreak};
  }

  static RosaryStatistics createDailyStatistics(
    DateTime date,
    List<RosarySession> sessions,
  ) {
    final dateStart = DateTime(date.year, date.month, date.day);
    final dateEnd = dateStart.add(const Duration(days: 1));

    int completedRosaries = 0;
    int completedDecades = 0;
    int totalPrayerTime = 0;
    String mysteryType = 'mixed';

    final daySessions = sessions.where((session) {
      return !session.startTime.isBefore(dateStart) &&
          session.startTime.isBefore(dateEnd) &&
          session.isComplete &&
          session.completedBeads > 0;
    }).toList();

    if (daySessions.isEmpty) {
      return RosaryStatistics(
        id: 'stats_${date.toIso8601String().split('T').first}',
        date: date,
        completedRosaries: 0,
        completedDecades: 0,
        mysteryType: 'none',
        totalPrayerTimeMinutes: 0,
      );
    }

    final mysteryTypes = <String>{};

    for (final session in daySessions) {
      final duration = session.estimatedDurationMinutes;

      if (duration >= minimumPrayerTimeMinutes) {
        totalPrayerTime += duration;
        mysteryTypes.add(session.mysteryType);

        if (session.completedBeads >= 53) {
          completedRosaries++;
        } else {
          completedDecades++;
        }
      }
    }

    if (mysteryTypes.length == 1) {
      mysteryType = mysteryTypes.first;
    } else if (mysteryTypes.length > 1) {
      mysteryType = 'mixed';
    }

    return RosaryStatistics(
      id: 'stats_${date.toIso8601String().split('T').first}',
      date: date,
      completedRosaries: completedRosaries,
      completedDecades: completedDecades,
      mysteryType: mysteryType,
      totalPrayerTimeMinutes: totalPrayerTime,
    );
  }

  static Map<String, dynamic> getMysteryStatistics(
    List<RosarySession> sessions,
    List<RosaryStatistics> statistics,
  ) {
    final mysteryCounts = <String, int>{};
    final mysteryTime = <String, int>{};

    for (final session in sessions) {
      if (session.isComplete && session.completedBeads > 0) {
        final duration = session.estimatedDurationMinutes;

        if (duration >= minimumPrayerTimeMinutes) {
          mysteryCounts[session.mysteryType] =
              (mysteryCounts[session.mysteryType] ?? 0) + 1;
          mysteryTime[session.mysteryType] =
              (mysteryTime[session.mysteryType] ?? 0) + duration;
        }
      }
    }

    for (final stats in statistics) {
      if (stats.mysteryType != 'mixed' && stats.mysteryType != 'none') {
        mysteryCounts[stats.mysteryType] =
            (mysteryCounts[stats.mysteryType] ?? 0) +
            stats.completedRosaries +
            stats.completedDecades;
        mysteryTime[stats.mysteryType] =
            (mysteryTime[stats.mysteryType] ?? 0) +
            stats.totalPrayerTimeMinutes;
      }
    }

    final sortedMysteries = mysteryCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return {
      'mysteryCounts': mysteryCounts,
      'mysteryTime': mysteryTime,
      'mostPrayedMystery': sortedMysteries.isNotEmpty
          ? sortedMysteries.first.key
          : null,
      'mostPrayedCount': sortedMysteries.isNotEmpty
          ? sortedMysteries.first.value
          : 0,
    };
  }
}
