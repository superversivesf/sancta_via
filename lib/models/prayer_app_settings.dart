import 'package:flutter/foundation.dart';
import 'package:sancta_via_shared_ui/sancta_via_shared_ui.dart';
import '../widgets/enhanced_prayer_text.dart';

/// Prayer Companion App specific settings that extends the base settings model
@immutable
class PrayerAppSettings {
  /// Base settings common to all Sancta Via apps
  final BaseSettingsModel baseSettings;
  
  /// List of favorite prayer IDs
  final List<String> favoritePrayerIds;
  
  /// List of recently accessed prayer IDs (most recent first)
  final List<String> recentPrayerIds;
  
  /// Prayer reading mode for enhanced display
  final PrayerReadingMode readingMode;
  
  /// Whether verse highlighting is enabled
  final bool verseHighlighting;
  
  /// Maximum number of recent prayers to keep
  final int maxRecentPrayers;
  
  /// Whether to auto-advance verses in contemplative mode
  final bool autoAdvanceVerses;
  
  /// Auto-advance delay in seconds
  final int autoAdvanceDelaySeconds;

  const PrayerAppSettings({
    required this.baseSettings,
    this.favoritePrayerIds = const [],
    this.recentPrayerIds = const [],
    this.readingMode = PrayerReadingMode.normal,
    this.verseHighlighting = false,
    this.maxRecentPrayers = 10,
    this.autoAdvanceVerses = false,
    this.autoAdvanceDelaySeconds = 8,
  });

  /// Create default Prayer app settings
  factory PrayerAppSettings.defaults() {
    return PrayerAppSettings(
      baseSettings: BaseSettingsModel.defaults(),
    );
  }

  /// Create from JSON map - handles migration from old format
  factory PrayerAppSettings.fromJson(Map<String, dynamic> json) {
    // Handle base settings
    BaseSettingsModel baseSettings;
    if (json.containsKey('baseSettings')) {
      baseSettings = BaseSettingsModel.fromJson(json['baseSettings'] as Map<String, dynamic>);
    } else {
      // Migration: create base settings from old individual values
      double fontSize = 18.0; // Default
      
      // Handle old fontSize field
      if (json['fontSize'] != null) {
        fontSize = (json['fontSize'] as num).toDouble().clamp(12.0, 32.0);
      }
      
      // Handle old defaultLanguage
      AppLanguage language = AppLanguage.english;
      if (json['defaultLanguage'] != null) {
        final languageString = json['defaultLanguage'] as String;
        if (languageString == 'Latin') {
          language = AppLanguage.latin;
        } else if (languageString == 'Spanish') {
          language = AppLanguage.spanish;
        }
      }

      baseSettings = BaseSettingsModel(
        fontSize: fontSize,
        defaultLanguage: language,
        // Other base settings use defaults for migration
      );
    }

    // Handle prayer reading mode
    PrayerReadingMode readingMode = PrayerReadingMode.normal;
    if (json['readingMode'] != null) {
      final modeString = json['readingMode'] as String;
      switch (modeString) {
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

    return PrayerAppSettings(
      baseSettings: baseSettings,
      favoritePrayerIds: List<String>.from(json['favoritePrayerIds'] ?? []),
      recentPrayerIds: List<String>.from(json['recentPrayerIds'] ?? []),
      readingMode: readingMode,
      verseHighlighting: json['verseHighlighting'] as bool? ?? false,
      maxRecentPrayers: json['maxRecentPrayers'] as int? ?? 10,
      autoAdvanceVerses: json['autoAdvanceVerses'] as bool? ?? false,
      autoAdvanceDelaySeconds: json['autoAdvanceDelaySeconds'] as int? ?? 8,
    );
  }

  /// Convert to JSON map
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
      'baseSettings': baseSettings.toJson(),
      'favoritePrayerIds': favoritePrayerIds,
      'recentPrayerIds': recentPrayerIds,
      'readingMode': readingModeString,
      'verseHighlighting': verseHighlighting,
      'maxRecentPrayers': maxRecentPrayers,
      'autoAdvanceVerses': autoAdvanceVerses,
      'autoAdvanceDelaySeconds': autoAdvanceDelaySeconds,
    };
  }

  /// Create a copy with updated values
  PrayerAppSettings copyWith({
    BaseSettingsModel? baseSettings,
    List<String>? favoritePrayerIds,
    List<String>? recentPrayerIds,
    PrayerReadingMode? readingMode,
    bool? verseHighlighting,
    int? maxRecentPrayers,
    bool? autoAdvanceVerses,
    int? autoAdvanceDelaySeconds,
  }) {
    return PrayerAppSettings(
      baseSettings: baseSettings ?? this.baseSettings,
      favoritePrayerIds: favoritePrayerIds ?? this.favoritePrayerIds,
      recentPrayerIds: recentPrayerIds ?? this.recentPrayerIds,
      readingMode: readingMode ?? this.readingMode,
      verseHighlighting: verseHighlighting ?? this.verseHighlighting,
      maxRecentPrayers: maxRecentPrayers ?? this.maxRecentPrayers,
      autoAdvanceVerses: autoAdvanceVerses ?? this.autoAdvanceVerses,
      autoAdvanceDelaySeconds: autoAdvanceDelaySeconds ?? this.autoAdvanceDelaySeconds,
    );
  }

  /// Update base settings while preserving Prayer-specific settings
  PrayerAppSettings updateBaseSettings(BaseSettingsModel newBaseSettings) {
    return copyWith(baseSettings: newBaseSettings);
  }

  /// Add a prayer to favorites
  PrayerAppSettings addFavorite(String prayerId) {
    if (favoritePrayerIds.contains(prayerId)) return this;
    final newFavorites = [...favoritePrayerIds, prayerId];
    return copyWith(favoritePrayerIds: newFavorites);
  }

  /// Remove a prayer from favorites
  PrayerAppSettings removeFavorite(String prayerId) {
    final newFavorites = favoritePrayerIds.where((id) => id != prayerId).toList();
    return copyWith(favoritePrayerIds: newFavorites);
  }

  /// Add a prayer to recent list (most recent first)
  PrayerAppSettings addToRecent(String prayerId) {
    final newRecent = [prayerId];
    // Add existing items that aren't the same prayer
    newRecent.addAll(recentPrayerIds.where((id) => id != prayerId));
    // Trim to max length
    if (newRecent.length > maxRecentPrayers) {
      newRecent.removeRange(maxRecentPrayers, newRecent.length);
    }
    return copyWith(recentPrayerIds: newRecent);
  }

  /// Check if a prayer is favorited
  bool isFavorite(String prayerId) => favoritePrayerIds.contains(prayerId);

  /// Convenience getters for commonly accessed base settings
  double get fontSize => baseSettings.fontSize;
  TextScalingMode get textScalingMode => baseSettings.textScalingMode;
  AppLanguage get defaultLanguage => baseSettings.defaultLanguage;
  bool get notificationsEnabled => baseSettings.notificationsEnabled;
  double get effectiveTextScaleFactor => baseSettings.effectiveTextScaleFactor;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PrayerAppSettings &&
        other.baseSettings == baseSettings &&
        listEquals(other.favoritePrayerIds, favoritePrayerIds) &&
        listEquals(other.recentPrayerIds, recentPrayerIds) &&
        other.readingMode == readingMode &&
        other.verseHighlighting == verseHighlighting &&
        other.maxRecentPrayers == maxRecentPrayers &&
        other.autoAdvanceVerses == autoAdvanceVerses &&
        other.autoAdvanceDelaySeconds == autoAdvanceDelaySeconds;
  }

  @override
  int get hashCode {
    return Object.hash(
      baseSettings,
      Object.hashAll(favoritePrayerIds),
      Object.hashAll(recentPrayerIds),
      readingMode,
      verseHighlighting,
      maxRecentPrayers,
      autoAdvanceVerses,
      autoAdvanceDelaySeconds,
    );
  }

  @override
  String toString() {
    return 'PrayerAppSettings('
        'baseSettings: $baseSettings, '
        'favoritePrayerIds: $favoritePrayerIds, '
        'recentPrayerIds: $recentPrayerIds, '
        'readingMode: $readingMode, '
        'verseHighlighting: $verseHighlighting, '
        'maxRecentPrayers: $maxRecentPrayers, '
        'autoAdvanceVerses: $autoAdvanceVerses, '
        'autoAdvanceDelaySeconds: $autoAdvanceDelaySeconds'
        ')';
  }
}
