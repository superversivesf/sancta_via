import 'achievement_category.dart';

/// Represents an achievement that can be earned
class Achievement {
  /// Unique identifier for this achievement
  final String id;

  /// Achievement name
  final String name;

  /// Description of what's needed to earn this
  final String description;

  /// Category of achievement
  final AchievementCategory category;

  /// Icon name or emoji for the badge
  final String icon;

  /// Requirement value (e.g., 16 for 16-hour fast, 7 for 7-day streak)
  final int requirement;

  /// Points awarded for earning this achievement
  final int points;

  const Achievement({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.icon,
    required this.requirement,
    required this.points,
  });

  /// Create Achievement from JSON
  factory Achievement.fromJson(Map<String, dynamic> json) {
    return Achievement(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      category: AchievementCategoryExtension.fromJson(json['category'] as String),
      icon: json['icon'] as String,
      requirement: json['requirement'] as int,
      points: json['points'] as int,
    );
  }

  /// Convert Achievement to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'category': category.toJson(),
      'icon': icon,
      'requirement': requirement,
      'points': points,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is Achievement &&
        other.id == id &&
        other.name == name &&
        other.description == description &&
        other.category == category &&
        other.icon == icon &&
        other.requirement == requirement &&
        other.points == points;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      name,
      description,
      category,
      icon,
      requirement,
      points,
    );
  }

  @override
  String toString() {
    return 'Achievement(id: $id, name: $name, category: $category, requirement: $requirement, points: $points)';
  }
}
