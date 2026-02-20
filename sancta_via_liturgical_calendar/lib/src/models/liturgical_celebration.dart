import '../enums/celebration_rank.dart';

/// Represents a liturgical celebration (feast, solemnity, memorial, etc.)
class LiturgicalCelebration {
  final String key;
  final String name;
  final String type;
  final String rank;
  final String color;
  final String colorName;
  final String source;
  final bool prioritized;
  final List<String> titles;

  const LiturgicalCelebration({
    required this.key,
    required this.name,
    required this.type,
    required this.rank,
    required this.color,
    required this.colorName,
    required this.source,
    required this.prioritized,
    required this.titles,
  });

  /// Get the parsed CelebrationRank enum for this celebration
  /// Defaults to weekday if rank string is unrecognized
  CelebrationRank get rankEnum => CelebrationRank.fromString(rank);

  /// Check if this is a solemnity
  bool get isSolemnity => rankEnum == CelebrationRank.solemnity;

  /// Check if this is a feast
  bool get isFeast => rankEnum == CelebrationRank.feast;

  /// Check if this is a memorial
  bool get isMemorial => rankEnum == CelebrationRank.memorial;

  /// Check if this is an optional memorial
  bool get isOptionalMemorial => rankEnum == CelebrationRank.optionalMemorial;

  /// Check if this is any type of memorial (memorial or optional)
  bool get isAnyMemorial => rankEnum.isMemorial;

  /// Check if this is a weekday
  bool get isWeekday => rankEnum == CelebrationRank.weekday;

  /// Check if this is a major celebration (solemnity or feast)
  bool get isMajorCelebration => rankEnum.isMajorCelebration;

  /// Check if this should be displayed prominently (solemnity, feast, or memorial)
  bool get isProminentCelebration => isSolemnity || isFeast || isMemorial;

  factory LiturgicalCelebration.fromJson(Map<String, dynamic> json) {
    return LiturgicalCelebration(
      key: json['key'] ?? '',
      name: json['name'] ?? '',
      type: json['type'] ?? '',
      rank: json['rank'] ?? '',
      color: json['color'] ?? '',
      colorName: json['colorName'] ?? '',
      source: json['source'] ?? '',
      prioritized: json['prioritized'] ?? false,
      titles: List<String>.from(json['titles'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'key': key,
      'name': name,
      'type': type,
      'rank': rank,
      'color': color,
      'colorName': colorName,
      'source': source,
      'prioritized': prioritized,
      'titles': titles,
    };
  }

  @override
  String toString() {
    return 'LiturgicalCelebration(name: $name, rank: $rank, color: $color)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is LiturgicalCelebration &&
            runtimeType == other.runtimeType &&
            key == other.key &&
            name == other.name &&
            rank == other.rank;
  }

  @override
  int get hashCode => key.hashCode ^ name.hashCode ^ rank.hashCode;
}
