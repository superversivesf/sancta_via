import 'package:flutter/material.dart';
import 'package:sancta_via_shared_ui/sancta_via_shared_ui.dart';

/// Novena Companion App specific settings that extends the base settings model
@immutable
class NovenaAppSettings {
  /// Base settings common to all Sancta Via apps
  final BaseSettingsModel baseSettings;
  
  /// Whether PIN code is enabled for protecting examination data
  final bool hasPinCode;
  
  /// Notification preferences for novena reminders
  final bool novenaNotificationsEnabled;
  
  /// Daily reminder time for novena prayers (in minutes from midnight)
  final int dailyReminderTime;
  
  /// Whether to show completion celebrations
  final bool showCompletionCelebrations;
  
  /// Whether to allow multiple active novenas (future feature)
  final bool allowMultipleNovenas;

  const NovenaAppSettings({
    required this.baseSettings,
    this.hasPinCode = false,
    this.novenaNotificationsEnabled = false,
    this.dailyReminderTime = 480, // 8:00 AM (8 * 60 minutes)
    this.showCompletionCelebrations = true,
    this.allowMultipleNovenas = false,
  });

  /// Create default Novena app settings
  factory NovenaAppSettings.defaults() {
    return NovenaAppSettings(
      baseSettings: BaseSettingsModel.defaults(),
    );
  }

  /// Create from JSON map - handles migration from old format
  factory NovenaAppSettings.fromJson(Map<String, dynamic> json) {
    // Handle base settings
    BaseSettingsModel baseSettings;
    if (json.containsKey('baseSettings')) {
      baseSettings = BaseSettingsModel.fromJson(json['baseSettings'] as Map<String, dynamic>);
    } else {
      // Migration: create base settings from old individual values
      double fontSize = 18.0; // Default
      
      // Handle old fontSize field (might be stored as scaling factor)
      if (json['fontSize'] != null) {
        final fontSizeValue = (json['fontSize'] as num).toDouble();
        // Convert scaling factor to point size if needed
        if (fontSizeValue <= 2.0) {
          fontSize = (fontSizeValue * 18.0).clamp(12.0, 32.0);
        } else {
          fontSize = fontSizeValue.clamp(12.0, 32.0);
        }
      }
      
      // Handle color scheme style migration
      final AppLanguage language = AppLanguage.english;
      bool showLiturgicalColors = true;
      
      // Map old color scheme style to show liturgical colors
      if (json['colorSchemeStyle'] != null) {
        // 0 = vibrant, 1 = muted - both should show liturgical colors
        showLiturgicalColors = true;
      }

      baseSettings = BaseSettingsModel(
        fontSize: fontSize,
        defaultLanguage: language,
        showLiturgicalColors: showLiturgicalColors,
        // Other base settings use defaults for migration
      );
    }

    return NovenaAppSettings(
      baseSettings: baseSettings,
      hasPinCode: json['hasPinCode'] as bool? ?? false,
      novenaNotificationsEnabled: json['novenaNotificationsEnabled'] as bool? ?? false,
      dailyReminderTime: json['dailyReminderTime'] as int? ?? 480,
      showCompletionCelebrations: json['showCompletionCelebrations'] as bool? ?? true,
      allowMultipleNovenas: json['allowMultipleNovenas'] as bool? ?? false,
    );
  }

  /// Convert to JSON map
  Map<String, dynamic> toJson() {
    return {
      'baseSettings': baseSettings.toJson(),
      'hasPinCode': hasPinCode,
      'novenaNotificationsEnabled': novenaNotificationsEnabled,
      'dailyReminderTime': dailyReminderTime,
      'showCompletionCelebrations': showCompletionCelebrations,
      'allowMultipleNovenas': allowMultipleNovenas,
    };
  }

  /// Create a copy with updated values
  NovenaAppSettings copyWith({
    BaseSettingsModel? baseSettings,
    bool? hasPinCode,
    bool? novenaNotificationsEnabled,
    int? dailyReminderTime,
    bool? showCompletionCelebrations,
    bool? allowMultipleNovenas,
  }) {
    return NovenaAppSettings(
      baseSettings: baseSettings ?? this.baseSettings,
      hasPinCode: hasPinCode ?? this.hasPinCode,
      novenaNotificationsEnabled: novenaNotificationsEnabled ?? this.novenaNotificationsEnabled,
      dailyReminderTime: dailyReminderTime ?? this.dailyReminderTime,
      showCompletionCelebrations: showCompletionCelebrations ?? this.showCompletionCelebrations,
      allowMultipleNovenas: allowMultipleNovenas ?? this.allowMultipleNovenas,
    );
  }

  /// Update base settings while preserving Novena-specific settings
  NovenaAppSettings updateBaseSettings(BaseSettingsModel newBaseSettings) {
    return copyWith(baseSettings: newBaseSettings);
  }

  /// Convenience getters for commonly accessed base settings
  double get fontSize => baseSettings.fontSize;
  TextScalingMode get textScalingMode => baseSettings.textScalingMode;
  AppLanguage get defaultLanguage => baseSettings.defaultLanguage;
  bool get notificationsEnabled => baseSettings.notificationsEnabled;
  bool get showLiturgicalColors => baseSettings.showLiturgicalColors;
  bool get hapticFeedbackEnabled => baseSettings.hapticFeedbackEnabled;
  bool get reduceMotion => baseSettings.reduceMotion;
  double get effectiveTextScaleFactor => baseSettings.effectiveTextScaleFactor;

  /// Get daily reminder time as TimeOfDay
  TimeOfDay get dailyReminderTimeOfDay {
    final hours = dailyReminderTime ~/ 60;
    final minutes = dailyReminderTime % 60;
    return TimeOfDay(hour: hours, minute: minutes);
  }

  /// Set daily reminder time from TimeOfDay
  NovenaAppSettings withDailyReminderTime(TimeOfDay time) {
    final totalMinutes = time.hour * 60 + time.minute;
    return copyWith(dailyReminderTime: totalMinutes);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is NovenaAppSettings &&
        other.baseSettings == baseSettings &&
        other.hasPinCode == hasPinCode &&
        other.novenaNotificationsEnabled == novenaNotificationsEnabled &&
        other.dailyReminderTime == dailyReminderTime &&
        other.showCompletionCelebrations == showCompletionCelebrations &&
        other.allowMultipleNovenas == allowMultipleNovenas;
  }

  @override
  int get hashCode {
    return Object.hash(
      baseSettings,
      hasPinCode,
      novenaNotificationsEnabled,
      dailyReminderTime,
      showCompletionCelebrations,
      allowMultipleNovenas,
    );
  }

  @override
  String toString() {
    return 'NovenaAppSettings('
        'baseSettings: $baseSettings, '
        'hasPinCode: $hasPinCode, '
        'novenaNotificationsEnabled: $novenaNotificationsEnabled, '
        'dailyReminderTime: $dailyReminderTime, '
        'showCompletionCelebrations: $showCompletionCelebrations, '
        'allowMultipleNovenas: $allowMultipleNovenas'
        ')';
  }
}