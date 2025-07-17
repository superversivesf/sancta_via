import 'package:flutter/foundation.dart';
import 'package:sancta_via_shared_ui/sancta_via_shared_ui.dart';
import 'package:bible_data/bible_data.dart';

/// Bible Reading App specific settings that extends the base settings model
@immutable
class BibleAppSettings {
  /// Base settings common to all Sancta Via apps
  final BaseSettingsModel baseSettings;
  
  /// Selected Bible translation for reading
  final BibleTranslation selectedBibleTranslation;
  
  /// Whether to show verse numbers
  final bool showVerseNumbers;
  
  /// Whether to highlight current verse in audio mode
  final bool highlightCurrentVerse;
  
  /// Whether daily reading notifications are enabled
  final bool dailyReadingNotificationsEnabled;

  const BibleAppSettings({
    required this.baseSettings,
    required this.selectedBibleTranslation,
    this.showVerseNumbers = true,
    this.highlightCurrentVerse = true,
    this.dailyReadingNotificationsEnabled = false,
  });

  /// Create default Bible app settings
  factory BibleAppSettings.defaults() {
    return BibleAppSettings(
      baseSettings: BaseSettingsModel.defaults(),
      selectedBibleTranslation: BibleTranslation.cpdv,
    );
  }

  /// Create from JSON map - handles migration from old format
  factory BibleAppSettings.fromJson(Map<String, dynamic> json) {
    // Handle base settings
    BaseSettingsModel baseSettings;
    if (json.containsKey('baseSettings')) {
      baseSettings = BaseSettingsModel.fromJson(json['baseSettings'] as Map<String, dynamic>);
    } else {
      // Migration: create base settings from old individual values
      baseSettings = BaseSettingsModel(
        fontSize: (json['fontSize'] as num?)?.toDouble() ?? 18.0,
        // Other base settings use defaults for migration
      );
    }

    // Handle Bible translation
    BibleTranslation translation = BibleTranslation.cpdv;
    if (json['selectedBibleTranslation'] != null) {
      try {
        final translationId = json['selectedBibleTranslation'] as String;
        translation = BibleTranslation.fromId(translationId);
      } catch (e) {
        // Keep default if parsing fails
      }
    }

    return BibleAppSettings(
      baseSettings: baseSettings,
      selectedBibleTranslation: translation,
      showVerseNumbers: json['showVerseNumbers'] as bool? ?? true,
      highlightCurrentVerse: json['highlightCurrentVerse'] as bool? ?? true,
      dailyReadingNotificationsEnabled: json['dailyReadingNotificationsEnabled'] as bool? ?? false,
    );
  }

  /// Convert to JSON map
  Map<String, dynamic> toJson() {
    return {
      'baseSettings': baseSettings.toJson(),
      'selectedBibleTranslation': selectedBibleTranslation.id,
      'showVerseNumbers': showVerseNumbers,
      'highlightCurrentVerse': highlightCurrentVerse,
      'dailyReadingNotificationsEnabled': dailyReadingNotificationsEnabled,
    };
  }

  /// Create a copy with updated values
  BibleAppSettings copyWith({
    BaseSettingsModel? baseSettings,
    BibleTranslation? selectedBibleTranslation,
    bool? showVerseNumbers,
    bool? highlightCurrentVerse,
    bool? dailyReadingNotificationsEnabled,
  }) {
    return BibleAppSettings(
      baseSettings: baseSettings ?? this.baseSettings,
      selectedBibleTranslation: selectedBibleTranslation ?? this.selectedBibleTranslation,
      showVerseNumbers: showVerseNumbers ?? this.showVerseNumbers,
      highlightCurrentVerse: highlightCurrentVerse ?? this.highlightCurrentVerse,
      dailyReadingNotificationsEnabled: dailyReadingNotificationsEnabled ?? this.dailyReadingNotificationsEnabled,
    );
  }

  /// Update base settings while preserving Bible-specific settings
  BibleAppSettings updateBaseSettings(BaseSettingsModel newBaseSettings) {
    return copyWith(baseSettings: newBaseSettings);
  }

  /// Convenience getters for commonly accessed base settings
  double get fontSize => baseSettings.fontSize;
  TextScalingMode get textScalingMode => baseSettings.textScalingMode;
  AppLanguage get defaultLanguage => baseSettings.defaultLanguage;
  bool get notificationsEnabled => baseSettings.notificationsEnabled;
  double get effectiveTextScaleFactor => baseSettings.effectiveTextScaleFactor;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BibleAppSettings &&
        other.baseSettings == baseSettings &&
        other.selectedBibleTranslation == selectedBibleTranslation &&
        other.showVerseNumbers == showVerseNumbers &&
        other.highlightCurrentVerse == highlightCurrentVerse &&
        other.dailyReadingNotificationsEnabled == dailyReadingNotificationsEnabled;
  }

  @override
  int get hashCode {
    return Object.hash(
      baseSettings,
      selectedBibleTranslation,
      showVerseNumbers,
      highlightCurrentVerse,
      dailyReadingNotificationsEnabled,
    );
  }

  @override
  String toString() {
    return 'BibleAppSettings('
        'baseSettings: $baseSettings, '
        'selectedBibleTranslation: $selectedBibleTranslation, '
        'showVerseNumbers: $showVerseNumbers, '
        'highlightCurrentVerse: $highlightCurrentVerse, '
        'dailyReadingNotificationsEnabled: $dailyReadingNotificationsEnabled'
        ')';
  }
}
