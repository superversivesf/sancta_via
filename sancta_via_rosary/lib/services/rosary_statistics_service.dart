import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/mystery_set.dart';
import '../models/rosary_session.dart';

/// Statistics data container for rosary prayer tracking
class RosaryStatistics {
  /// Total number of completed rosaries (all time)
  final int totalRosariesCompleted;

  /// Current consecutive day streak
  final int currentStreak;

  /// Longest streak ever achieved
  final int longestStreak;

  /// Total time spent praying in minutes
  final int totalMinutesPrayed;

  /// Favorite mystery set (most prayed)
  final MysterySet? favoriteMysterySet;

  /// Count per mystery set
  final Map<MysterySet, int> mysterySetCounts;

  /// Daily counts for last 7 days (key: date string YYYY-MM-DD)
  final Map<String, int> weeklyCounts;

  /// Weekly counts for last 4 weeks (key: week start date YYYY-MM-DD)
  final Map<String, int> monthlyCounts;

  /// Recent completed sessions (last 20)
  final List<RosarySession> recentSessions;

  /// Whether any statistics exist yet
  bool get hasData => totalRosariesCompleted > 0;

  const RosaryStatistics({
    this.totalRosariesCompleted = 0,
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.totalMinutesPrayed = 0,
    this.favoriteMysterySet,
    this.mysterySetCounts = const {},
    this.weeklyCounts = const {},
    this.monthlyCounts = const {},
    this.recentSessions = const [],
  });

  /// Total hours prayed (formatted)
  String get totalTimeFormatted {
    if (totalMinutesPrayed < 60) {
      return '$totalMinutesPrayed min';
    }
    final hours = totalMinutesPrayed ~/ 60;
    final minutes = totalMinutesPrayed % 60;
    if (minutes == 0) {
      return '$hours hr';
    }
    return '$hours hr $minutes min';
  }
}

/// Service for calculating and managing rosary statistics
class RosaryStatisticsService {
  static const String _sessionsKey = 'rosary_completed_sessions';
  static const String _longestStreakKey = 'rosary_longest_streak';

  final SharedPreferences _prefs;

  RosaryStatisticsService(this._prefs);

  /// Factory to create service with initialized SharedPreferences
  static Future<RosaryStatisticsService> create() async {
    final prefs = await SharedPreferences.getInstance();
    return RosaryStatisticsService(prefs);
  }

  /// Get all calculated statistics
  Future<RosaryStatistics> getStatistics() async {
    final sessions = await _getCompletedSessions();

    if (sessions.isEmpty) {
      return const RosaryStatistics();
    }

    final totalCompleted = sessions.where((s) => s.completed).length;
    final currentStreak = _calculateCurrentStreak(sessions);
    final longestStreak = _calculateLongestStreak(sessions);
    final totalMinutes = sessions.fold<int>(
      0,
      (sum, s) => sum + (s.durationMinutes ?? 15), // Default 15 min if unknown
    );
    final mysteryCounts = _calculateMysteryCounts(sessions);
    final favoriteMystery = _getFavoriteMystery(mysteryCounts);
    final weeklyCounts = _calculateWeeklyCounts(sessions);
    final monthlyCounts = _calculateMonthlyCounts(sessions);
    final recentSessions = sessions.where((s) => s.completed).toList()
      ..sort((a, b) => b.endTime!.compareTo(a.endTime!));

    return RosaryStatistics(
      totalRosariesCompleted: totalCompleted,
      currentStreak: currentStreak,
      longestStreak: longestStreak,
      totalMinutesPrayed: totalMinutes,
      favoriteMysterySet: favoriteMystery,
      mysterySetCounts: mysteryCounts,
      weeklyCounts: weeklyCounts,
      monthlyCounts: monthlyCounts,
      recentSessions: recentSessions.take(20).toList(),
    );
  }

  /// Record a completed session
  Future<void> recordSession(RosarySession session) async {
    if (!session.completed) return;

    final sessions = await _getCompletedSessions();
    sessions.add(session);
    await _saveSessions(sessions);
  }

  /// Get all completed sessions from storage
  Future<List<RosarySession>> _getCompletedSessions() async {
    final jsonString = _prefs.getString(_sessionsKey);
    if (jsonString == null) return [];

    try {
      final List<dynamic> jsonList = jsonDecode(jsonString) as List<dynamic>;
      return jsonList
          .map((json) => RosarySession.fromJson(json as Map<String, dynamic>))
          .where((s) => s.completed)
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Save sessions to storage
  Future<void> _saveSessions(List<RosarySession> sessions) async {
    final jsonList = sessions.map((s) => s.toJson()).toList();
    await _prefs.setString(_sessionsKey, jsonEncode(jsonList));
  }

  /// Calculate current consecutive day streak
  int _calculateCurrentStreak(List<RosarySession> sessions) {
    if (sessions.isEmpty) return 0;

    final completedDates =
        sessions
            .where((s) => s.completed && s.endTime != null)
            .map((s) => _dateKey(s.endTime!))
            .toSet()
          ..toList().sort((a, b) => b.compareTo(a)); // Sort descending

    if (completedDates.isEmpty) return 0;

    final sortedDates = completedDates.toList()..sort((a, b) => b.compareTo(a));
    final today = _dateKey(DateTime.now());
    final yesterday = _dateKey(
      DateTime.now().subtract(const Duration(days: 1)),
    );

    // If no activity today or yesterday, streak is broken
    if (!sortedDates.contains(today) && !sortedDates.contains(yesterday)) {
      return 0;
    }

    // Count consecutive days from most recent
    int streak = 0;
    DateTime checkDate = sortedDates.contains(today)
        ? DateTime.now()
        : DateTime.now().subtract(const Duration(days: 1));

    while (sortedDates.contains(_dateKey(checkDate))) {
      streak++;
      checkDate = checkDate.subtract(const Duration(days: 1));
    }

    return streak;
  }

  /// Calculate longest streak ever
  int _calculateLongestStreak(List<RosarySession> sessions) {
    if (sessions.isEmpty) return 0;

    final completedDates =
        sessions
            .where((s) => s.completed && s.endTime != null)
            .map((s) => _dateKey(s.endTime!))
            .toSet()
          ..toList().sort();

    if (completedDates.isEmpty) return 0;

    final sortedDates = completedDates.toList()..sort();
    int longestStreak = 1;
    int currentStreak = 1;

    for (int i = 1; i < sortedDates.length; i++) {
      final prevDate = DateTime.parse(sortedDates[i - 1]);
      final currDate = DateTime.parse(sortedDates[i]);
      final difference = currDate.difference(prevDate).inDays;

      if (difference == 1) {
        currentStreak++;
        longestStreak = currentStreak > longestStreak
            ? currentStreak
            : longestStreak;
      } else if (difference > 1) {
        currentStreak = 1;
      }
    }

    return longestStreak;
  }

  /// Calculate counts per mystery set
  Map<MysterySet, int> _calculateMysteryCounts(List<RosarySession> sessions) {
    final counts = <MysterySet, int>{};

    for (final session in sessions.where((s) => s.completed)) {
      counts[session.mysterySet] = (counts[session.mysterySet] ?? 0) + 1;
    }

    return counts;
  }

  /// Get favorite mystery set
  MysterySet? _getFavoriteMystery(Map<MysterySet, int> counts) {
    if (counts.isEmpty) return null;

    var favorite = counts.entries.first;
    for (final entry in counts.entries) {
      if (entry.value > favorite.value) {
        favorite = entry;
      }
    }
    return favorite.key;
  }

  /// Calculate daily counts for last 7 days
  Map<String, int> _calculateWeeklyCounts(List<RosarySession> sessions) {
    final counts = <String, int>{};
    final now = DateTime.now();

    // Initialize last 7 days with 0
    for (int i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      counts[_dateKey(date)] = 0;
    }

    // Count sessions per day
    for (final session in sessions.where(
      (s) => s.completed && s.endTime != null,
    )) {
      final dateKey = _dateKey(session.endTime!);
      if (counts.containsKey(dateKey)) {
        counts[dateKey] = counts[dateKey]! + 1;
      }
    }

    return counts;
  }

  /// Calculate weekly counts for last 4 weeks
  Map<String, int> _calculateMonthlyCounts(List<RosarySession> sessions) {
    final counts = <String, int>{};
    final now = DateTime.now();

    // Initialize last 4 weeks with 0
    for (int i = 3; i >= 0; i--) {
      final weekStart = _weekStart(now.subtract(Duration(days: i * 7)));
      counts[_dateKey(weekStart)] = 0;
    }

    // Count sessions per week
    for (final session in sessions.where(
      (s) => s.completed && s.endTime != null,
    )) {
      final weekStart = _weekStart(session.endTime!);
      final weekKey = _dateKey(weekStart);

      // Only count if within last 4 weeks
      final matchingKey = counts.keys.firstWhere(
        (key) => key == weekKey,
        orElse: () => '',
      );
      if (matchingKey.isNotEmpty) {
        counts[matchingKey] = counts[matchingKey]! + 1;
      }
    }

    return counts;
  }

  /// Get normalized date key (YYYY-MM-DD)
  String _dateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// Get start of week (Sunday) for a date
  DateTime _weekStart(DateTime date) {
    // weekday is 1-7 (Monday-Sunday in Dart), we want Sunday as week start
    final daysSinceSunday = date.weekday % 7;
    return DateTime(date.year, date.month, date.day - daysSinceSunday);
  }

  /// Clear all statistics (for testing/reset)
  Future<void> clearAll() async {
    await _prefs.remove(_sessionsKey);
    await _prefs.remove(_longestStreakKey);
  }
}
