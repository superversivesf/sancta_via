/// Ranks of liturgical celebrations in order of precedence
enum CelebrationRank {
  solemnity('SOLEMNITY', 'Solemnity', 1),
  feast('FEAST', 'Feast', 2),
  memorial('MEMORIAL', 'Memorial', 3),
  optionalMemorial('OPT_MEMORIAL', 'Optional Memorial', 4),
  weekday('WEEKDAY', 'Weekday', 5);

  const CelebrationRank(this.code, this.displayName, this.precedence);

  final String code;
  final String displayName;
  final int precedence; // Lower number = higher precedence

  /// Convert from string to enum
  static CelebrationRank? fromString(String rank) {
    switch (rank.toUpperCase()) {
      case 'SOLEMNITY':
        return CelebrationRank.solemnity;
      case 'FEAST':
        return CelebrationRank.feast;
      case 'MEMORIAL':
        return CelebrationRank.memorial;
      case 'OPT_MEMORIAL':
      case 'OPTIONAL_MEMORIAL':
        return CelebrationRank.optionalMemorial;
      case 'WEEKDAY':
        return CelebrationRank.weekday;
      default:
        return CelebrationRank.weekday; // Default fallback
    }
  }

  /// Check if this rank takes precedence over another
  bool takesPrecedenceOver(CelebrationRank other) {
    return precedence < other.precedence;
  }

  /// Check if this is a major celebration
  bool get isMajorCelebration {
    return this == CelebrationRank.solemnity || this == CelebrationRank.feast;
  }

  /// Check if this is a memorial
  bool get isMemorial {
    return this == CelebrationRank.memorial || this == CelebrationRank.optionalMemorial;
  }

  /// Get appropriate display symbol
  String get symbol {
    switch (this) {
      case CelebrationRank.solemnity:
        return '★★★';
      case CelebrationRank.feast:
        return '★★';
      case CelebrationRank.memorial:
        return '★';
      case CelebrationRank.optionalMemorial:
        return '☆';
      case CelebrationRank.weekday:
        return '';
    }
  }
}