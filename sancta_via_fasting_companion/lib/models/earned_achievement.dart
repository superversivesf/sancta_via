/// Represents an achievement that has been earned by the user
class EarnedAchievement {
  /// Achievement ID
  final String achievementId;

  /// When this achievement was earned
  final DateTime earnedAt;

  /// Whether the user has seen the notification
  final bool seen;

  const EarnedAchievement({
    required this.achievementId,
    required this.earnedAt,
    this.seen = false,
  });

  /// Create EarnedAchievement from JSON
  factory EarnedAchievement.fromJson(Map<String, dynamic> json) {
    return EarnedAchievement(
      achievementId: json['achievementId'] as String,
      earnedAt: DateTime.parse(json['earnedAt'] as String),
      seen: json['seen'] as bool? ?? false,
    );
  }

  /// Convert EarnedAchievement to JSON
  Map<String, dynamic> toJson() {
    return {
      'achievementId': achievementId,
      'earnedAt': earnedAt.toIso8601String(),
      'seen': seen,
    };
  }

  /// Create a copy with modified fields
  EarnedAchievement copyWith({
    String? achievementId,
    DateTime? earnedAt,
    bool? seen,
  }) {
    return EarnedAchievement(
      achievementId: achievementId ?? this.achievementId,
      earnedAt: earnedAt ?? this.earnedAt,
      seen: seen ?? this.seen,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is EarnedAchievement &&
        other.achievementId == achievementId &&
        other.earnedAt == earnedAt &&
        other.seen == seen;
  }

  @override
  int get hashCode {
    return Object.hash(achievementId, earnedAt, seen);
  }

  @override
  String toString() {
    return 'EarnedAchievement(achievementId: $achievementId, earnedAt: $earnedAt, seen: $seen)';
  }
}
