/// Category of encouragement content
enum EncouragementCategory {
  /// Biblical scripture passage
  scripture,

  /// Quote from a Catholic saint
  saintQuote,

  /// Catholic prayer
  prayer;

  /// Convert category to JSON string
  String toJson() => name;

  /// Create category from JSON string
  static EncouragementCategory fromJson(String json) {
    return EncouragementCategory.values.firstWhere(
      (category) => category.name == json,
      orElse: () => EncouragementCategory.scripture,
    );
  }

  /// Human-readable display name
  String get displayName {
    switch (this) {
      case EncouragementCategory.scripture:
        return 'Scripture';
      case EncouragementCategory.saintQuote:
        return 'Saint Quote';
      case EncouragementCategory.prayer:
        return 'Prayer';
    }
  }
}
