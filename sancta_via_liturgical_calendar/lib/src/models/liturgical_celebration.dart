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
