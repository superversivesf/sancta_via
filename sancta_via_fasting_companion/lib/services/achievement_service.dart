import 'dart:convert';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/achievements_data.dart';
import '../models/achievement.dart';
import '../models/earned_achievement.dart';
import '../models/fast_session.dart';
import '../repositories/fasting_repository.dart';
import '../utils/app_logger.dart';

/// Service for tracking and managing achievements
class AchievementService {
  final FastingRepository repository;
  final FlutterLocalNotificationsPlugin notificationsPlugin;

  static const String _earnedAchievementsKey = 'earned_achievements';

  List<EarnedAchievement>? _cachedEarnedAchievements;

  AchievementService({
    required this.repository,
    required this.notificationsPlugin,
  });

  /// Get all available achievements
  List<Achievement> getAllAchievements() {
    return allAchievements;
  }

  /// Get all earned achievements
  Future<List<EarnedAchievement>> getEarnedAchievements() async {
    if (_cachedEarnedAchievements != null) {
      return _cachedEarnedAchievements!;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_earnedAchievementsKey);

      if (jsonString == null || jsonString.isEmpty) {
        _cachedEarnedAchievements = [];
        return [];
      }

      final List<dynamic> jsonList = json.decode(jsonString) as List<dynamic>;
      _cachedEarnedAchievements = jsonList
          .map((e) => EarnedAchievement.fromJson(e as Map<String, dynamic>))
          .toList();

      return _cachedEarnedAchievements!;
    } catch (e, stack) {
      AppLogger.error('Error loading earned achievements', e, stack, 'AchievementService');
      _cachedEarnedAchievements = [];
      return [];
    }
  }

  /// Save earned achievements
  Future<void> _saveEarnedAchievements(List<EarnedAchievement> earned) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = json.encode(earned.map((e) => e.toJson()).toList());
      await prefs.setString(_earnedAchievementsKey, jsonString);
      _cachedEarnedAchievements = earned;
    } catch (e, stack) {
      AppLogger.error('Error saving earned achievements', e, stack, 'AchievementService');
    }
  }

  /// Check if user has earned an achievement
  Future<bool> hasEarnedAchievement(String achievementId) async {
    final earned = await getEarnedAchievements();
    return earned.any((e) => e.achievementId == achievementId);
  }

  /// Get total achievement points earned
  Future<int> getTotalPoints() async {
    final earned = await getEarnedAchievements();
    int total = 0;

    for (final earnedAchievement in earned) {
      final achievement = allAchievements.firstWhere(
        (a) => a.id == earnedAchievement.achievementId,
        orElse: () => allAchievements.first,
      );
      total += achievement.points;
    }

    return total;
  }

  /// Get progress toward a specific achievement (0.0 to 1.0)
  Future<double> getAchievementProgress(Achievement achievement) async {
    final history = await repository.getFastHistory();

    switch (achievement.id) {
      // First time achievements
      case 'first_fast':
        return history.isEmpty ? 0.0 : 1.0;

      case 'first_target':
        final hasReachedTarget = history.any((s) => s.hasReachedTarget);
        return hasReachedTarget ? 1.0 : 0.0;

      case 'first_16h':
        final has16h = history.any((s) => s.elapsedHours >= 16);
        return has16h ? 1.0 : 0.0;

      // Duration achievements
      case 'duration_12h':
      case 'duration_16h':
      case 'duration_18h':
      case 'duration_24h':
      case 'duration_36h':
      case 'duration_48h':
      case 'duration_72h':
        final maxDuration = history.isEmpty
            ? 0
            : history.map((s) => s.elapsedHours).reduce((a, b) => a > b ? a : b);
        return (maxDuration / achievement.requirement).clamp(0.0, 1.0);

      // Streak achievements
      case 'streak_3':
      case 'streak_7':
      case 'streak_14':
      case 'streak_21':
      case 'streak_30':
      case 'streak_40':
      case 'streak_100':
        final streak = await _calculateCurrentStreak();
        return (streak / achievement.requirement).clamp(0.0, 1.0);

      // Total fasts milestones
      case 'total_5':
      case 'total_10':
      case 'total_25':
      case 'total_50':
      case 'total_100':
        final completed = history.where((s) => s.status.toString().contains('completed')).length;
        return (completed / achievement.requirement).clamp(0.0, 1.0);

      // Total hours fasted
      case 'hours_50':
      case 'hours_100':
      case 'hours_250':
      case 'hours_500':
      case 'hours_1000':
        final totalHours = history.fold<int>(0, (sum, s) => sum + s.elapsedHours);
        return (totalHours / achievement.requirement).clamp(0.0, 1.0);

      // Special achievements - return 0 or 1 based on completion
      default:
        return 0.0;
    }
  }

  /// Calculate current fast streak (consecutive days with completed fasts)
  Future<int> _calculateCurrentStreak() async {
    final history = await repository.getFastHistory();
    if (history.isEmpty) return 0;

    final completed = history
        .where((s) => s.status.toString().contains('completed'))
        .toList()
      ..sort((a, b) => b.startTime.compareTo(a.startTime)); // Most recent first

    if (completed.isEmpty) return 0;

    int streak = 0;
    DateTime? lastDate;

    for (final session in completed) {
      final sessionDate = DateTime(
        session.startTime.year,
        session.startTime.month,
        session.startTime.day,
      );

      if (lastDate == null) {
        // First session
        lastDate = sessionDate;
        streak = 1;
      } else {
        final dayDifference = lastDate.difference(sessionDate).inDays;
        if (dayDifference == 1) {
          // Consecutive day
          streak++;
          lastDate = sessionDate;
        } else if (dayDifference > 1) {
          // Gap in streak, stop counting
          break;
        }
        // dayDifference == 0 means same day, skip
      }
    }

    return streak;
  }

  /// Check for newly earned achievements after completing a fast
  Future<List<Achievement>> checkNewAchievements(FastSession completedSession) async {
    final List<Achievement> newlyEarned = [];
    final earned = await getEarnedAchievements();
    final earnedIds = earned.map((e) => e.achievementId).toSet();

    for (final achievement in allAchievements) {
      // Skip if already earned
      if (earnedIds.contains(achievement.id)) continue;

      // Check if achievement is now earned
      final progress = await getAchievementProgress(achievement);
      if (progress >= 1.0) {
        newlyEarned.add(achievement);

        // Add to earned list
        earned.add(EarnedAchievement(
          achievementId: achievement.id,
          earnedAt: DateTime.now(),
        ));
      }
    }

    if (newlyEarned.isNotEmpty) {
      await _saveEarnedAchievements(earned);

      // Send notifications for newly earned achievements
      for (final achievement in newlyEarned) {
        await _sendAchievementNotification(achievement);
      }

      AppLogger.info(
        'Earned ${newlyEarned.length} new achievements',
        'AchievementService',
      );
    }

    return newlyEarned;
  }

  /// Send a notification for a newly earned achievement
  Future<void> _sendAchievementNotification(Achievement achievement) async {
    try {
      const androidDetails = AndroidNotificationDetails(
        'achievements',
        'Achievements',
        channelDescription: 'Notifications for earned achievements and badges',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
        macOS: iosDetails,
      );

      await notificationsPlugin.show(
        achievement.id.hashCode.abs() % 2147483647,
        '${achievement.icon} Achievement Unlocked!',
        '${achievement.name}: ${achievement.description}',
        notificationDetails,
        payload: 'achievement_${achievement.id}',
      );

      AppLogger.info(
        'Sent achievement notification: ${achievement.name}',
        'AchievementService',
      );
    } catch (e, stack) {
      AppLogger.error(
        'Error sending achievement notification',
        e,
        stack,
        'AchievementService',
      );
    }
  }

  /// Mark an achievement as seen
  Future<void> markAchievementSeen(String achievementId) async {
    final earned = await getEarnedAchievements();
    final index = earned.indexWhere((e) => e.achievementId == achievementId);

    if (index != -1) {
      earned[index] = earned[index].copyWith(seen: true);
      await _saveEarnedAchievements(earned);
    }
  }

  /// Get count of unseen achievements
  Future<int> getUnseenCount() async {
    final earned = await getEarnedAchievements();
    return earned.where((e) => !e.seen).length;
  }

  /// Clear all achievements (for testing)
  Future<void> clearAllAchievements() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_earnedAchievementsKey);
    _cachedEarnedAchievements = null;
    AppLogger.info('Cleared all achievements', 'AchievementService');
  }

  /// Import an earned achievement (for data import/restore)
  Future<void> importEarnedAchievement(
    String achievementId,
    DateTime earnedAt,
    bool seen,
  ) async {
    final prefs = await SharedPreferences.getInstance();

    // Get existing earned achievements
    final earned = await getEarnedAchievements();

    // Check if already exists
    final exists = earned.any((e) => e.achievementId == achievementId);
    if (exists) {
      AppLogger.info(
        'Achievement $achievementId already exists, skipping import',
        'AchievementService',
      );
      return;
    }

    // Add new achievement
    final newAchievement = EarnedAchievement(
      achievementId: achievementId,
      earnedAt: earnedAt,
      seen: seen,
    );

    earned.add(newAchievement);

    // Save to SharedPreferences
    final json = earned.map((e) => e.toJson()).toList();
    await prefs.setString(_earnedAchievementsKey, jsonEncode(json));

    // Clear cache
    _cachedEarnedAchievements = null;

    AppLogger.info(
      'Imported achievement: $achievementId',
      'AchievementService',
    );
  }
}
