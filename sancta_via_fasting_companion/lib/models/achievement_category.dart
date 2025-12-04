/// Categories of achievements
enum AchievementCategory {
  /// First-time achievements (first fast, first completion)
  firstTime,

  /// Duration-based achievements (16h, 24h, 48h, etc.)
  duration,

  /// Streak-based achievements (consecutive days)
  streak,

  /// Milestone achievements (total fasts, total hours)
  milestone,

  /// Special achievements (liturgical fasts, etc.)
  special,
}

extension AchievementCategoryExtension on AchievementCategory {
  /// Convert to JSON string
  String toJson() {
    return toString().split('.').last;
  }

  /// Create from JSON string
  static AchievementCategory fromJson(String json) {
    return AchievementCategory.values.firstWhere(
      (e) => e.toString().split('.').last == json,
      orElse: () => AchievementCategory.milestone,
    );
  }

  /// Get display name
  String get displayName {
    switch (this) {
      case AchievementCategory.firstTime:
        return 'First Time';
      case AchievementCategory.duration:
        return 'Duration';
      case AchievementCategory.streak:
        return 'Streak';
      case AchievementCategory.milestone:
        return 'Milestone';
      case AchievementCategory.special:
        return 'Special';
    }
  }
}
