/// Types of prayers in the rosary
enum PrayerType {
  /// Sign of the Cross (first opening prayer)
  signOfCross,

  /// Apostles' Creed (second opening prayer)
  apostlesCreed,

  /// Opening Our Father (third opening prayer, before the decades)
  openingOurFather,

  /// Opening Hail Mary (fourth opening prayer, 3 Hail Marys before decades)
  openingHailMary,

  /// Mystery announcement and meditation
  mystery,

  /// The Our Father prayer (before each decade)
  ourFather,

  /// The Hail Mary prayer (10 per decade)
  hailMary,

  /// The Glory Be prayer (after each decade)
  gloryBe,

  /// The Fatima Prayer (optional, after each Glory Be)
  fatimaPrayer,

  /// Closing prayers (Hail Holy Queen, closing prayers)
  closing;

  /// Get the display name for this prayer type
  String get displayName {
    switch (this) {
      case PrayerType.signOfCross:
        return 'Sign of the Cross';
      case PrayerType.apostlesCreed:
        return 'Apostles\' Creed';
      case PrayerType.openingOurFather:
        return 'Our Father';
      case PrayerType.openingHailMary:
        return 'Hail Mary';
      case PrayerType.mystery:
        return 'Mystery';
      case PrayerType.ourFather:
        return 'Our Father';
      case PrayerType.hailMary:
        return 'Hail Mary';
      case PrayerType.gloryBe:
        return 'Glory Be';
      case PrayerType.fatimaPrayer:
        return 'Fatima Prayer';
      case PrayerType.closing:
        return 'Closing';
    }
  }

  /// Convert from string value (used for database/JSON)
  static PrayerType fromString(String? value) {
    if (value == null || value.isEmpty) {
      return PrayerType.signOfCross;
    }

    switch (value.toLowerCase()) {
      case 'opening':
      case 'signofcross':
      case 'sign_of_cross':
        return PrayerType.signOfCross;
      case 'apostlescreed':
      case 'apostles_creed':
        return PrayerType.apostlesCreed;
      case 'openingourfather':
      case 'opening_our_father':
        return PrayerType.openingOurFather;
      case 'openinghailmary':
      case 'opening_hail_mary':
        return PrayerType.openingHailMary;
      case 'mystery':
        return PrayerType.mystery;
      case 'ourfather':
      case 'our_father':
        return PrayerType.ourFather;
      case 'hailmary':
      case 'hail_mary':
        return PrayerType.hailMary;
      case 'glorybe':
      case 'glory_be':
        return PrayerType.gloryBe;
      case 'fatimaprayer':
      case 'fatima_prayer':
        return PrayerType.fatimaPrayer;
      case 'closing':
        return PrayerType.closing;
      default:
        return PrayerType.signOfCross;
    }
  }

  /// Convert to string value (used for database/JSON)
  String toStringValue() {
    return name;
  }
}
