import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/achievements_data.dart';
import '../models/achievement.dart';
import '../models/achievement_category.dart';
import '../models/earned_achievement.dart';
import '../services/achievement_service.dart';
import 'fast_type_providers.dart';

/// Provider for achievement service
final achievementServiceProvider = Provider<AchievementService>((ref) {
  final repository = ref.watch(fastingRepositoryProvider);
  final notificationsPlugin = FlutterLocalNotificationsPlugin();

  return AchievementService(
    repository: repository,
    notificationsPlugin: notificationsPlugin,
  );
});

/// Provider for all available achievements
final allAchievementsProvider = Provider<List<Achievement>>((ref) {
  return allAchievements;
});

/// Provider for earned achievements
final earnedAchievementsProvider = FutureProvider<List<EarnedAchievement>>((ref) async {
  final service = ref.watch(achievementServiceProvider);
  return service.getEarnedAchievements();
});

/// Provider for total achievement points
final totalAchievementPointsProvider = FutureProvider<int>((ref) async {
  final service = ref.watch(achievementServiceProvider);
  return service.getTotalPoints();
});

/// Provider for unseen achievement count
final unseenAchievementCountProvider = FutureProvider<int>((ref) async {
  final service = ref.watch(achievementServiceProvider);
  return service.getUnseenCount();
});

/// Provider for achievement progress (by achievement ID)
final achievementProgressProvider =
    FutureProvider.family<double, String>((ref, achievementId) async {
  final service = ref.watch(achievementServiceProvider);
  final allAchievements = ref.watch(allAchievementsProvider);

  final achievement = allAchievements.firstWhere(
    (a) => a.id == achievementId,
    orElse: () => allAchievements.first,
  );

  return service.getAchievementProgress(achievement);
});

/// Provider for checking if user has earned a specific achievement
final hasEarnedAchievementProvider =
    FutureProvider.family<bool, String>((ref, achievementId) async {
  final service = ref.watch(achievementServiceProvider);
  return service.hasEarnedAchievement(achievementId);
});

/// Provider for achievements grouped by category
final achievementsByCategoryProvider = Provider<Map<String, List<Achievement>>>((ref) {
  final achievements = ref.watch(allAchievementsProvider);

  final Map<String, List<Achievement>> grouped = {};

  for (final achievement in achievements) {
    final category = achievement.category.displayName;
    grouped.putIfAbsent(category, () => []).add(achievement);
  }

  return grouped;
});
