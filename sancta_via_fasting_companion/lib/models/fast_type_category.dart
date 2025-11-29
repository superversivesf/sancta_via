/// Category of fasting type
enum FastTypeCategory {
  /// Intermittent fasting (16:8, 18:6, 20:4, etc.)
  intermittent,

  /// Single 24-hour fast
  daily24hr,

  /// Multi-day fast (2-5+ days)
  multiDay,

  /// Liturgical/seasonal fasts (Advent, Lent, etc.)
  liturgical;

  /// Convert category to JSON string
  String toJson() => name;

  /// Create category from JSON string
  static FastTypeCategory fromJson(String json) {
    return FastTypeCategory.values.firstWhere(
      (category) => category.name == json,
      orElse: () => FastTypeCategory.intermittent,
    );
  }

  /// Human-readable display name
  String get displayName {
    switch (this) {
      case FastTypeCategory.intermittent:
        return 'Intermittent';
      case FastTypeCategory.daily24hr:
        return '24-Hour';
      case FastTypeCategory.multiDay:
        return 'Multi-Day';
      case FastTypeCategory.liturgical:
        return 'Liturgical';
    }
  }

  /// Description of this category
  String get description {
    switch (this) {
      case FastTypeCategory.intermittent:
        return 'Time-restricted eating patterns like 16:8 or 18:6';
      case FastTypeCategory.daily24hr:
        return 'Complete 24-hour fasting period';
      case FastTypeCategory.multiDay:
        return 'Extended fasts lasting multiple days';
      case FastTypeCategory.liturgical:
        return 'Traditional Catholic seasonal fasts';
    }
  }
}
