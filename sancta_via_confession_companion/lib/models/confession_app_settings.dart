import 'package:flutter/foundation.dart';
import 'package:sancta_via_shared_ui/sancta_via_shared_ui.dart';
import '../features/examination/models/user_preferences_model.dart';

/// Confession Companion App specific settings that extends the base settings model
@immutable
class ConfessionAppSettings {
  /// Base settings common to all Sancta Via apps
  final BaseSettingsModel baseSettings;
  
  /// User preferences for examination of conscience features
  final ExaminationPreferences examinationPreferences;
  
  /// Whether to show completion progress
  final bool showProgress;
  
  /// Whether to use guided examination mode
  final bool useGuidedMode;
  
  /// Whether to save examination history
  final bool saveExaminationHistory;
  
  /// Number of days to keep examination history
  final int historyRetentionDays;

  const ConfessionAppSettings({
    required this.baseSettings,
    required this.examinationPreferences,
    this.showProgress = true,
    this.useGuidedMode = false,
    this.saveExaminationHistory = true,
    this.historyRetentionDays = 30,
  });

  /// Create default Confession app settings
  factory ConfessionAppSettings.defaults() {
    return ConfessionAppSettings(
      baseSettings: BaseSettingsModel.defaults(),
      examinationPreferences: ExaminationPreferences(),
    );
  }

  /// Create from JSON map - handles migration from old format
  factory ConfessionAppSettings.fromJson(Map<String, dynamic> json) {
    // Handle base settings
    BaseSettingsModel baseSettings;
    if (json.containsKey('baseSettings')) {
      baseSettings = BaseSettingsModel.fromJson(json['baseSettings'] as Map<String, dynamic>);
    } else {
      // Migration: create base settings from old individual values
      double fontSize = 18.0; // Default base
      
      // Convert old textScale to fontSize if present
      if (json['textScale'] != null) {
        final textScale = (json['textScale'] as num).toDouble().clamp(0.8, 1.5);
        fontSize = textScale * 18.0; // Base size was 18pt
      }
      
      // Handle deprecated darkMode by defaulting to system theme
      // (actual theme will be handled by theme provider)
      
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
        fontSize: fontSize.clamp(12.0, 32.0),
        defaultLanguage: language,
        notificationsEnabled: json['notificationsEnabled'] as bool? ?? false,
        // Other base settings use defaults for migration
      );
    }

    // Handle examination preferences
    ExaminationPreferences examinationPrefs = ExaminationPreferences();
    if (json.containsKey('examinationPreferences')) {
      examinationPrefs = ExaminationPreferences.fromJson(
          json['examinationPreferences'] as Map<String, dynamic>);
    } else if (json.containsKey('favoriteExaminationIds') || json.containsKey('defaultExaminationId')) {
      // Migrate old format where examination preferences were at root level
      examinationPrefs = ExaminationPreferences(
        favoriteExaminationIds: List<String>.from(json['favoriteExaminationIds'] ?? []),
        defaultExaminationId: json['defaultExaminationId'],
      );
    }

    return ConfessionAppSettings(
      baseSettings: baseSettings,
      examinationPreferences: examinationPrefs,
      showProgress: json['showProgress'] as bool? ?? true,
      useGuidedMode: json['useGuidedMode'] as bool? ?? false,
      saveExaminationHistory: json['saveExaminationHistory'] as bool? ?? true,
      historyRetentionDays: json['historyRetentionDays'] as int? ?? 30,
    );
  }

  /// Convert to JSON map
  Map<String, dynamic> toJson() {
    return {
      'baseSettings': baseSettings.toJson(),
      'examinationPreferences': examinationPreferences.toJson(),
      'showProgress': showProgress,
      'useGuidedMode': useGuidedMode,
      'saveExaminationHistory': saveExaminationHistory,
      'historyRetentionDays': historyRetentionDays,
    };
  }

  /// Create a copy with updated values
  ConfessionAppSettings copyWith({
    BaseSettingsModel? baseSettings,
    ExaminationPreferences? examinationPreferences,
    bool? showProgress,
    bool? useGuidedMode,
    bool? saveExaminationHistory,
    int? historyRetentionDays,
  }) {
    return ConfessionAppSettings(
      baseSettings: baseSettings ?? this.baseSettings,
      examinationPreferences: examinationPreferences ?? this.examinationPreferences,
      showProgress: showProgress ?? this.showProgress,
      useGuidedMode: useGuidedMode ?? this.useGuidedMode,
      saveExaminationHistory: saveExaminationHistory ?? this.saveExaminationHistory,
      historyRetentionDays: historyRetentionDays ?? this.historyRetentionDays,
    );
  }

  /// Update base settings while preserving Confession-specific settings
  ConfessionAppSettings updateBaseSettings(BaseSettingsModel newBaseSettings) {
    return copyWith(baseSettings: newBaseSettings);
  }

  /// Update examination preferences
  ConfessionAppSettings updateExaminationPreferences(ExaminationPreferences newPreferences) {
    return copyWith(examinationPreferences: newPreferences);
  }

  /// Convenience getters for commonly accessed base settings
  double get fontSize => baseSettings.fontSize;
  TextScalingMode get textScalingMode => baseSettings.textScalingMode;
  AppLanguage get defaultLanguage => baseSettings.defaultLanguage;
  bool get notificationsEnabled => baseSettings.notificationsEnabled;
  double get effectiveTextScaleFactor => baseSettings.effectiveTextScaleFactor;
  
  /// Get text scale factor for backward compatibility with existing TextScaling class
  double get textScale => effectiveTextScaleFactor;
  
  /// Convenience getters for examination preferences
  List<String> get favoriteExaminationIds => examinationPreferences.favoriteExaminationIds;
  String? get defaultExaminationId => examinationPreferences.defaultExaminationId;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ConfessionAppSettings &&
        other.baseSettings == baseSettings &&
        other.examinationPreferences == examinationPreferences &&
        other.showProgress == showProgress &&
        other.useGuidedMode == useGuidedMode &&
        other.saveExaminationHistory == saveExaminationHistory &&
        other.historyRetentionDays == historyRetentionDays;
  }

  @override
  int get hashCode {
    return Object.hash(
      baseSettings,
      examinationPreferences,
      showProgress,
      useGuidedMode,
      saveExaminationHistory,
      historyRetentionDays,
    );
  }

  @override
  String toString() {
    return 'ConfessionAppSettings('
        'baseSettings: $baseSettings, '
        'examinationPreferences: $examinationPreferences, '
        'showProgress: $showProgress, '
        'useGuidedMode: $useGuidedMode, '
        'saveExaminationHistory: $saveExaminationHistory, '
        'historyRetentionDays: $historyRetentionDays'
        ')';
  }
}
