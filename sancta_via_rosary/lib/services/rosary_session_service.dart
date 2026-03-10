import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';
import '../utils/logger.dart';

/// Service for managing rosary prayer sessions.
///
/// Handles session tracking, persistence to SharedPreferences,
/// and provides statistics about prayer history.
///
/// Usage:
/// ```dart
/// final service = RosarySessionService.instance;
/// final session = await service.startSession(MysterySet.joyful);
/// await service.recordPrayerCompletion(PrayerType.hailMary);
/// await service.completeMystery(1);
/// await service.finishSession();
/// ```
class RosarySessionService {
  static const String _sessionsKey = 'rosary_sessions';
  static const String _currentSessionKey = 'rosary_current_session';
  static const String _statisticsKey = 'rosary_statistics';

  // Singleton pattern
  static final RosarySessionService _instance =
      RosarySessionService._internal();
  static RosarySessionService get instance => _instance;

  RosarySessionService._internal();

  // Current active session (not persisted until complete)
  RosarySession? _currentSession;

  // In-memory cache for sessions
  List<RosarySession>? _cachedSessions;
  Map<String, dynamic>? _cachedStatistics;

  // =============================================================================
  // SESSION MANAGEMENT
  // =============================================================================

  /// Start a new rosary session
  ///
  /// [mysterySet] - Which set of mysteries to pray
  /// Returns the new session
  Future<RosarySession> startSession(MysterySet mysterySet) async {
    try {
      // Clear any existing incomplete session
      await _clearCurrentSession();

      _currentSession = RosarySession.createToday(mysterySet: mysterySet);
      await _persistCurrentSession();

      AppLogger.info(
        'Started new session: ${_currentSession!.id} with ${mysterySet.displayName}',
        'SESSION',
      );
      return _currentSession!;
    } catch (e) {
      AppLogger.error('Failed to start session', e, null, 'SESSION');
      // Return a session anyway so UI can continue
      return RosarySession.createToday(mysterySet: mysterySet);
    }
  }

  /// Get the current active session (if any)
  Future<RosarySession?> getCurrentSession() async {
    if (_currentSession != null) {
      return _currentSession;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_currentSessionKey);

      if (jsonString == null) return null;

      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      _currentSession = RosarySession.fromJson(json);

      AppLogger.info(
        'Loaded current session: ${_currentSession!.id}',
        'SESSION',
      );
      return _currentSession;
    } catch (e) {
      AppLogger.error('Failed to load current session', e, null, 'SESSION');
      return null;
    }
  }

  /// Resume an interrupted session
  Future<RosarySession?> resumeSession() async {
    return getCurrentSession();
  }

  /// Record completion of a prayer during the session
  ///
  /// [prayerType] - The type of prayer completed
  Future<void> recordPrayerCompletion(PrayerType prayerType) async {
    if (_currentSession == null) {
      AppLogger.warning('No active session to record prayer', 'SESSION');
      return;
    }

    try {
      // Update position based on prayer type
      var position = _currentSession!.currentPosition ?? 0;

      // Simple position tracking
      position += switch (prayerType) {
        PrayerType.signOfCross => 1,
        PrayerType.apostlesCreed => 1,
        PrayerType.openingOurFather => 1,
        PrayerType.openingHailMary => 1,
        PrayerType.ourFather => 1,
        PrayerType.hailMary => 1,
        PrayerType.gloryBe => 1,
        PrayerType.fatimaPrayer => 1,
        PrayerType.mystery => 1,
        PrayerType.closing => 1,
      };

      _currentSession = _currentSession!.copyWith(currentPosition: position);
      await _persistCurrentSession();

      AppLogger.info(
        'Recorded ${prayerType.name} completion at position $position',
        'SESSION',
      );
    } catch (e) {
      AppLogger.error('Failed to record prayer completion', e, null, 'SESSION');
    }
  }

  /// Mark a specific mystery as completed
  ///
  /// [mysteryNumber] - 1-5 indicating which mystery was completed
  Future<void> completeMystery(int mysteryNumber) async {
    if (_currentSession == null) {
      AppLogger.warning('No active session to complete mystery', 'SESSION');
      return;
    }

    if (mysteryNumber < 1 || mysteryNumber > 5) {
      AppLogger.warning('Invalid mystery number: $mysteryNumber', 'SESSION');
      return;
    }

    try {
      _currentSession = _currentSession!.completeMystery(mysteryNumber);
      await _persistCurrentSession();

      AppLogger.info(
        'Completed mystery $mysteryNumber in session ${_currentSession!.id}',
        'SESSION',
      );
    } catch (e) {
      AppLogger.error('Failed to complete mystery', e, null, 'SESSION');
    }
  }

  /// Mark the current session as complete
  ///
  /// Saves to session history and clears current session
  Future<RosarySession?> finishSession() async {
    if (_currentSession == null) {
      AppLogger.warning('No active session to finish', 'SESSION');
      return null;
    }

    try {
      // Mark as complete
      _currentSession = _currentSession!.finish();

      // Save to history
      await _saveSessionToHistory(_currentSession!);

      // Clear current session
      await _clearCurrentSession();

      // Update statistics
      await _updateStatisticsAfterCompletion(_currentSession!);

      final completedSession = _currentSession;
      _currentSession = null;
      _cachedSessions = null; // Invalidate cache

      AppLogger.info('Finished session: ${completedSession!.id}', 'SESSION');
      return completedSession;
    } catch (e) {
      AppLogger.error('Failed to finish session', e, null, 'SESSION');
      return null;
    }
  }

  /// Cancel/abandon the current session without completing
  Future<void> abandonSession() async {
    if (_currentSession == null) return;

    try {
      // Mark as abandoned (has end time but not completed)
      _currentSession = _currentSession!.copyWith(
        endTime: DateTime.now(),
        completed: false,
      );

      // Save to history as incomplete
      await _saveSessionToHistory(_currentSession!);
      await _clearCurrentSession();

      final abandonedId = _currentSession!.id;
      _currentSession = null;
      _cachedSessions = null;

      AppLogger.info('Abandoned session: $abandonedId', 'SESSION');
    } catch (e) {
      AppLogger.error('Failed to abandon session', e, null, 'SESSION');
    }
  }

  /// Update current progress within a decade
  Future<void> updateProgress({
    required int position,
    int? mysteryNumber,
    int? hailMary,
  }) async {
    if (_currentSession == null) return;

    try {
      _currentSession = _currentSession!.updatePosition(
        position: position,
        mysteryNumber: mysteryNumber,
        hailMary: hailMary,
      );
      await _persistCurrentSession();
    } catch (e) {
      AppLogger.error('Failed to update progress', e, null, 'SESSION');
    }
  }

  // =============================================================================
  // SESSION HISTORY
  // =============================================================================

  /// Get all completed sessions
  Future<List<RosarySession>> getSessionHistory() async {
    if (_cachedSessions != null) {
      return _cachedSessions!;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_sessionsKey);

      if (jsonString == null) {
        _cachedSessions = [];
        return [];
      }

      final List<dynamic> jsonList = jsonDecode(jsonString) as List<dynamic>;
      _cachedSessions =
          jsonList
              .map(
                (json) => RosarySession.fromJson(json as Map<String, dynamic>),
              )
              .toList()
            ..sort(
              (a, b) => b.startTime.compareTo(a.startTime),
            ); // Most recent first

      AppLogger.info(
        'Loaded ${_cachedSessions!.length} sessions from history',
        'SESSION',
      );
      return _cachedSessions!;
    } catch (e) {
      AppLogger.error('Failed to load session history', e, null, 'SESSION');
      return [];
    }
  }

  /// Get sessions for a specific date range
  Future<List<RosarySession>> getSessionsInRange(
    DateTime start,
    DateTime end,
  ) async {
    final allSessions = await getSessionHistory();
    return allSessions.where((s) {
      return s.startTime.isAfter(start) && s.startTime.isBefore(end);
    }).toList();
  }

  /// Get completed sessions only
  Future<List<RosarySession>> getCompletedSessions() async {
    final allSessions = await getSessionHistory();
    return allSessions.where((s) => s.completed).toList();
  }

  /// Clear all session history (use with caution)
  Future<void> clearHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_sessionsKey);
      await prefs.remove(_statisticsKey);
      _cachedSessions = null;
      _cachedStatistics = null;

      AppLogger.info('Cleared all session history', 'SESSION');
    } catch (e) {
      AppLogger.error('Failed to clear history', e, null, 'SESSION');
    }
  }

  // =============================================================================
  // STATISTICS
  // =============================================================================

  /// Get statistics about rosary prayer history
  Future<RosaryStatistics> getStatistics() async {
    if (_cachedStatistics != null) {
      return RosaryStatistics.fromJson(_cachedStatistics!);
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_statisticsKey);

      if (jsonString != null) {
        _cachedStatistics = jsonDecode(jsonString) as Map<String, dynamic>;
        return RosaryStatistics.fromJson(_cachedStatistics!);
      }

      // Calculate from scratch if no cached stats
      return await _calculateStatistics();
    } catch (e) {
      AppLogger.error('Failed to get statistics', e, null, 'SESSION');
      return RosaryStatistics.empty();
    }
  }

  /// Calculate total rosaries completed (each full 5-mystery rosary = 1)
  Future<int> getTotalRosaries() async {
    final stats = await getStatistics();
    return stats.totalCompletedRosaries;
  }

  /// Calculate current streak (consecutive days with completed rosaries)
  Future<int> getCurrentStreak() async {
    final stats = await getStatistics();
    return stats.currentStreak;
  }

  /// Get longest streak ever achieved
  Future<int> getLongestStreak() async {
    final stats = await getStatistics();
    return stats.longestStreak;
  }

  /// Get total Hail Marys prayed
  Future<int> getTotalHailMarys() async {
    final stats = await getStatistics();
    return stats.totalHailMarys;
  }

  // =============================================================================
  // PRIVATE METHODS
  // =============================================================================

  Future<void> _persistCurrentSession() async {
    if (_currentSession == null) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = jsonEncode(_currentSession!.toJson());
      await prefs.setString(_currentSessionKey, jsonString);
    } catch (e) {
      AppLogger.error('Failed to persist current session', e, null, 'SESSION');
    }
  }

  Future<void> _clearCurrentSession() async {
    _currentSession = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_currentSessionKey);
    } catch (e) {
      AppLogger.error('Failed to clear current session', e, null, 'SESSION');
    }
  }

  Future<void> _saveSessionToHistory(RosarySession session) async {
    try {
      final sessions = await getSessionHistory();

      // Check if session already exists
      final existingIndex = sessions.indexWhere((s) => s.id == session.id);
      if (existingIndex >= 0) {
        sessions[existingIndex] = session;
      } else {
        sessions.add(session);
      }

      // Limit history to last 100 sessions to prevent bloat
      if (sessions.length > 100) {
        sessions.removeRange(100, sessions.length);
      }

      // Save back
      final prefs = await SharedPreferences.getInstance();
      final jsonString = jsonEncode(sessions.map((s) => s.toJson()).toList());
      await prefs.setString(_sessionsKey, jsonString);

      _cachedSessions = sessions;
    } catch (e) {
      AppLogger.error('Failed to save session to history', e, null, 'SESSION');
    }
  }

  Future<RosaryStatistics> _calculateStatistics() async {
    final sessions = await getCompletedSessions();

    var totalRosaries = 0;
    var totalHailMarys = 0;
    final daysWithSessions = <DateTime>{};

    for (final session in sessions) {
      // Each completed mystery counts as 1/5 of a rosary
      totalRosaries += session.completedCount;

      // Each completed mystery = 10 Hail Marys
      totalHailMarys += session.completedCount * 10;

      // Track unique days
      final day = DateTime(
        session.startTime.year,
        session.startTime.month,
        session.startTime.day,
      );
      daysWithSessions.add(day);
    }

    // Calculate current streak
    final currentStreak = _calculateStreak(daysWithSessions);

    // Calculate longest streak
    final longestStreak = _calculateLongestStreak(daysWithSessions);

    final stats = RosaryStatistics(
      totalCompletedRosaries: totalRosaries,
      totalHailMarys: totalHailMarys,
      currentStreak: currentStreak,
      longestStreak: longestStreak,
      totalSessions: sessions.length,
    );

    // Cache statistics
    _cachedStatistics = stats.toJson();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_statisticsKey, jsonEncode(_cachedStatistics));

    return stats;
  }

  Future<void> _updateStatisticsAfterCompletion(RosarySession session) async {
    _cachedStatistics = null; // Invalidate cache
    await _calculateStatistics();
  }

  int _calculateStreak(Set<DateTime> days) {
    if (days.isEmpty) return 0;

    final sortedDays = days.toList()..sort((a, b) => b.compareTo(a));
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);

    // Check if there's activity today or yesterday
    final mostRecent = sortedDays.first;
    final yesterday = todayDate.subtract(const Duration(days: 1));

    if (mostRecent.isBefore(yesterday)) {
      return 0; // Streak broken
    }

    // Count consecutive days
    var streak = 1;
    for (var i = 1; i < sortedDays.length; i++) {
      final current = sortedDays[i];
      final previous = sortedDays[i - 1];
      final difference = previous.difference(current).inDays;

      if (difference == 1) {
        streak++;
      } else {
        break;
      }
    }

    return streak;
  }

  int _calculateLongestStreak(Set<DateTime> days) {
    if (days.isEmpty) return 0;

    final sortedDays = days.toList()..sort();
    var maxStreak = 1;
    var currentStreak = 1;

    for (var i = 1; i < sortedDays.length; i++) {
      final difference = sortedDays[i].difference(sortedDays[i - 1]).inDays;

      if (difference == 1) {
        currentStreak++;
        maxStreak = currentStreak > maxStreak ? currentStreak : maxStreak;
      } else {
        currentStreak = 1;
      }
    }

    return maxStreak;
  }
}

/// Immutable statistics about rosary prayer history
class RosaryStatistics {
  final int totalCompletedRosaries;
  final int totalHailMarys;
  final int currentStreak;
  final int longestStreak;
  final int totalSessions;

  const RosaryStatistics({
    required this.totalCompletedRosaries,
    required this.totalHailMarys,
    required this.currentStreak,
    required this.longestStreak,
    required this.totalSessions,
  });

  factory RosaryStatistics.empty() {
    return const RosaryStatistics(
      totalCompletedRosaries: 0,
      totalHailMarys: 0,
      currentStreak: 0,
      longestStreak: 0,
      totalSessions: 0,
    );
  }

  factory RosaryStatistics.fromJson(Map<String, dynamic> json) {
    return RosaryStatistics(
      totalCompletedRosaries: json['totalCompletedRosaries'] as int? ?? 0,
      totalHailMarys: json['totalHailMarys'] as int? ?? 0,
      currentStreak: json['currentStreak'] as int? ?? 0,
      longestStreak: json['longestStreak'] as int? ?? 0,
      totalSessions: json['totalSessions'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'totalCompletedRosaries': totalCompletedRosaries,
      'totalHailMarys': totalHailMarys,
      'currentStreak': currentStreak,
      'longestStreak': longestStreak,
      'totalSessions': totalSessions,
    };
  }

  /// Get full rosaries (dividing total mysteries by 5)
  int get fullRosaries => totalCompletedRosaries ~/ 5;

  /// Get extra mysteries beyond full rosaries
  int get extraMysteries => totalCompletedRosaries % 5;
}
