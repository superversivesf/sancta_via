/// The four sets of mysteries in the Holy Rosary
enum MysterySet {
  /// Joyful Mysteries (Monday, Saturday, Advent)
  /// Annunciation, Visitation, Nativity, Presentation, Finding in the Temple
  joyful,

  /// Sorrowful Mysteries (Tuesday, Friday, Lent)
  /// Agony in the Garden, Scourging, Crowning with Thorns,
  /// Carrying the Cross, Crucifixion
  sorrowful,

  /// Glorious Mysteries (Wednesday, Sunday, Easter Season)
  /// Resurrection, Ascension, Pentecost, Assumption, Coronation
  glorious,

  /// Luminous Mysteries (Thursday)
  /// Baptism, Wedding at Cana, Proclamation of the Kingdom,
  /// Transfiguration, Institution of the Eucharist
  luminous;

  /// Get the display name for this mystery set
  String get displayName {
    switch (this) {
      case MysterySet.joyful:
        return 'Joyful Mysteries';
      case MysterySet.sorrowful:
        return 'Sorrowful Mysteries';
      case MysterySet.glorious:
        return 'Glorious Mysteries';
      case MysterySet.luminous:
        return 'Luminous Mysteries';
    }
  }

  /// Get the short name for this mystery set
  String get shortName {
    switch (this) {
      case MysterySet.joyful:
        return 'Joyful';
      case MysterySet.sorrowful:
        return 'Sorrowful';
      case MysterySet.glorious:
        return 'Glorious';
      case MysterySet.luminous:
        return 'Luminous';
    }
  }

  /// Get the color associated with this mystery set (for theming)
  /// Returns a hex color string that can be parsed with Color(int.parse())
  String get themeColorHex {
    switch (this) {
      case MysterySet.joyful:
        return 'FF4CAF50'; // Green
      case MysterySet.sorrowful:
        return 'FF9C27B0'; // Purple
      case MysterySet.glorious:
        return 'FFFFD700'; // Gold
      case MysterySet.luminous:
        return 'FF2196F3'; // Light blue
    }
  }

  /// Get the traditional days for this mystery set
  List<String> get traditionalDays {
    switch (this) {
      case MysterySet.joyful:
        return ['Monday', 'Saturday'];
      case MysterySet.sorrowful:
        return ['Tuesday', 'Friday'];
      case MysterySet.glorious:
        return ['Wednesday', 'Sunday'];
      case MysterySet.luminous:
        return ['Thursday'];
    }
  }

  /// Get the recommended mystery set for a given weekday
  /// 1 = Monday, 7 = Sunday
  static MysterySet forWeekday(int weekday) {
    switch (weekday) {
      case 1: // Monday
        return MysterySet.joyful;
      case 2: // Tuesday
        return MysterySet.sorrowful;
      case 3: // Wednesday
        return MysterySet.glorious;
      case 4: // Thursday
        return MysterySet.luminous;
      case 5: // Friday
        return MysterySet.sorrowful;
      case 6: // Saturday
        return MysterySet.joyful;
      case 7: // Sunday
        return MysterySet.glorious;
      default:
        return MysterySet.joyful;
    }
  }

  /// Get the recommended mystery set for today
  static MysterySet forToday() {
    return forWeekday(DateTime.now().weekday);
  }

  /// Convert from string value (used for database/JSON)
  static MysterySet fromString(String? value) {
    if (value == null || value.isEmpty) {
      return MysterySet.joyful;
    }

    switch (value.toLowerCase()) {
      case 'joyful':
        return MysterySet.joyful;
      case 'sorrowful':
        return MysterySet.sorrowful;
      case 'glorious':
        return MysterySet.glorious;
      case 'luminous':
        return MysterySet.luminous;
      default:
        return MysterySet.joyful;
    }
  }

  /// Convert to string value (used for database/JSON)
  String toStringValue() {
    return name;
  }

  /// Get all mysteries in this set
  List<int> get allMysteries => [1, 2, 3, 4, 5];
}
