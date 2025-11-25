/// Represents the time of day categories for prayers
enum PrayerTimeOfDay {
  /// Morning prayers (5:00 AM - 9:00 AM)
  morning,

  /// Afternoon prayers (11:00 AM - 5:00 PM)
  afternoon,

  /// Evening prayers (5:00 PM - 9:00 PM)
  evening,

  /// Night prayers (9:00 PM - 5:00 AM)
  night,

  /// Prayers suitable for any time of day
  anytime;

  /// Get the display name for this time of day
  String get displayName {
    switch (this) {
      case PrayerTimeOfDay.morning:
        return 'Morning';
      case PrayerTimeOfDay.afternoon:
        return 'Afternoon';
      case PrayerTimeOfDay.evening:
        return 'Evening';
      case PrayerTimeOfDay.night:
        return 'Night';
      case PrayerTimeOfDay.anytime:
        return 'Any Time';
    }
  }

  /// Get a descriptive label for the panel (e.g., "Morning Prayer")
  String get panelLabel {
    switch (this) {
      case PrayerTimeOfDay.morning:
        return 'Morning Prayer';
      case PrayerTimeOfDay.afternoon:
        return 'Afternoon Prayer';
      case PrayerTimeOfDay.evening:
        return 'Evening Prayer';
      case PrayerTimeOfDay.night:
        return 'Night Prayer';
      case PrayerTimeOfDay.anytime:
        return 'Prayer';
    }
  }

  /// Convert from string value (used for database/JSON)
  static PrayerTimeOfDay fromString(String? value) {
    if (value == null || value.isEmpty) {
      return PrayerTimeOfDay.anytime;
    }

    switch (value.toLowerCase()) {
      case 'morning':
        return PrayerTimeOfDay.morning;
      case 'afternoon':
        return PrayerTimeOfDay.afternoon;
      case 'evening':
        return PrayerTimeOfDay.evening;
      case 'night':
        return PrayerTimeOfDay.night;
      case 'anytime':
      default:
        return PrayerTimeOfDay.anytime;
    }
  }

  /// Convert to string value (used for database/JSON)
  String toStringValue() {
    return name;
  }

  /// Determine the current time of day based on the given DateTime
  ///
  /// Time ranges:
  /// - Morning: 5:00 AM - 9:00 AM
  /// - Anytime: 9:00 AM - 11:00 AM
  /// - Afternoon: 11:00 AM - 5:00 PM
  /// - Evening: 5:00 PM - 9:00 PM
  /// - Night: 9:00 PM - 5:00 AM
  static PrayerTimeOfDay fromDateTime(DateTime dateTime) {
    final hour = dateTime.hour;

    if (hour >= 5 && hour < 9) {
      return PrayerTimeOfDay.morning;
    } else if (hour >= 9 && hour < 11) {
      return PrayerTimeOfDay.anytime;
    } else if (hour >= 11 && hour < 17) {
      return PrayerTimeOfDay.afternoon;
    } else if (hour >= 17 && hour < 21) {
      return PrayerTimeOfDay.evening;
    } else {
      // 9 PM (21:00) to 5 AM
      return PrayerTimeOfDay.night;
    }
  }

  /// Get the current time of day
  static PrayerTimeOfDay current() {
    return fromDateTime(DateTime.now());
  }
}
