import '../widgets/enhanced_prayer_text.dart';

/// DEPRECATED: Model for prayer preferences
///
/// This class is deprecated in favor of the new unified settings system.
/// Use PrayerAppSettings from '../models/prayer_app_settings.dart' instead.
///
/// This class is maintained for backward compatibility only.
@Deprecated('Use PrayerAppSettings with the unified settings system instead')
class PrayerPreferences {
  final List<String> favoritePrayerIds;
  final List<String> recentPrayerIds;
  final double fontSize;
  final String defaultLanguage;
  final PrayerReadingMode readingMode;
  final bool verseHighlighting;

  PrayerPreferences({
    List<String>? favoritePrayerIds,
    List<String>? recentPrayerIds,
    this.fontSize = 18.0,
    this.defaultLanguage = 'English',
    this.readingMode = PrayerReadingMode.normal,
    this.verseHighlighting = false,
  }) : favoritePrayerIds = favoritePrayerIds ?? [],
       recentPrayerIds = recentPrayerIds ?? [];

  factory PrayerPreferences.fromJson(Map<String, dynamic> json) {
    double fontSize = json['fontSize']?.toDouble() ?? 18.0;
    // Clamp font size to new maximum of 27pt
    fontSize = fontSize.clamp(12.0, 27.0);

    // Parse reading mode
    PrayerReadingMode readingMode = PrayerReadingMode.normal;
    if (json['readingMode'] != null) {
      switch (json['readingMode']) {
        case 'contemplative':
          readingMode = PrayerReadingMode.contemplative;
          break;
        case 'immersive':
          readingMode = PrayerReadingMode.immersive;
          break;
        default:
          readingMode = PrayerReadingMode.normal;
      }
    }

    return PrayerPreferences(
      favoritePrayerIds: List<String>.from(json['favoritePrayerIds'] ?? []),
      recentPrayerIds: List<String>.from(json['recentPrayerIds'] ?? []),
      fontSize: fontSize,
      defaultLanguage: json['defaultLanguage'] ?? 'English',
      readingMode: readingMode,
      verseHighlighting: json['verseHighlighting'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    String readingModeString;
    switch (readingMode) {
      case PrayerReadingMode.contemplative:
        readingModeString = 'contemplative';
        break;
      case PrayerReadingMode.immersive:
        readingModeString = 'immersive';
        break;
      default:
        readingModeString = 'normal';
    }

    return {
      'favoritePrayerIds': favoritePrayerIds,
      'recentPrayerIds': recentPrayerIds,
      'fontSize': fontSize,
      'defaultLanguage': defaultLanguage,
      'readingMode': readingModeString,
      'verseHighlighting': verseHighlighting,
    };
  }

  // Create a copy with updated values
  PrayerPreferences copyWith({
    List<String>? favoritePrayerIds,
    List<String>? recentPrayerIds,
    double? fontSize,
    String? defaultLanguage,
    PrayerReadingMode? readingMode,
    bool? verseHighlighting,
  }) {
    return PrayerPreferences(
      favoritePrayerIds: favoritePrayerIds ?? this.favoritePrayerIds,
      recentPrayerIds: recentPrayerIds ?? this.recentPrayerIds,
      fontSize: fontSize ?? this.fontSize,
      defaultLanguage: defaultLanguage ?? this.defaultLanguage,
      readingMode: readingMode ?? this.readingMode,
      verseHighlighting: verseHighlighting ?? this.verseHighlighting,
    );
  }
}
