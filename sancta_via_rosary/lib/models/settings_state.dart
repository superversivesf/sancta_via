import 'package:flutter/material.dart';
import 'package:sancta_via_shared_ui/sancta_via_shared_ui.dart';

/// Rosary App specific settings that extends the base settings model
@immutable
class RosaryAppSettings {
  /// Base settings common to all Sancta Via apps
  final BaseSettingsModel baseSettings;

  // Audio Settings
  /// Whether audio is enabled for prayers
  final bool audioEnabled;

  /// Audio volume (0.0 to 1.0)
  final double audioVolume;

  /// Whether to auto-play prayers
  final bool autoPlayPrayers;

  /// Whether haptic feedback is enabled for bead transitions
  final bool hapticFeedbackEnabled;

  // Notification Settings
  /// Whether rosary notifications are enabled
  final bool rosaryNotificationsEnabled;

  /// Daily reminder time (in minutes from midnight)
  final int dailyReminderTime;

  /// Whether daily reminder is specifically enabled
  final bool dailyReminderEnabled;

  // Prayer Language
  /// Preferred language for rosary prayers
  final AppLanguage prayerLanguage;

  const RosaryAppSettings({
    required this.baseSettings,
    this.audioEnabled = true,
    this.audioVolume = 0.8,
    this.autoPlayPrayers = false,
    this.hapticFeedbackEnabled = true,
    this.rosaryNotificationsEnabled = false,
    this.dailyReminderTime = 1200, // 8:00 PM (20 * 60 minutes)
    this.dailyReminderEnabled = false,
    this.prayerLanguage = AppLanguage.english,
  });

  /// Create default Rosary app settings
  factory RosaryAppSettings.defaults() {
    return RosaryAppSettings(baseSettings: BaseSettingsModel.defaults());
  }

  /// Create from JSON map - handles migration from old format
  factory RosaryAppSettings.fromJson(Map<String, dynamic> json) {
    // Handle base settings
    BaseSettingsModel baseSettings;
    if (json.containsKey('baseSettings')) {
      baseSettings = BaseSettingsModel.fromJson(
        json['baseSettings'] as Map<String, dynamic>,
      );
    } else {
      // Migration: create base settings from old individual values
      double fontSize = 18.0; // Default

      // Handle old fontSize field
      if (json['fontSize'] != null) {
        final fontSizeValue = (json['fontSize'] as num).toDouble();
        // Convert scaling factor to point size if needed
        if (fontSizeValue <= 2.0) {
          fontSize = (fontSizeValue * 18.0).clamp(12.0, 32.0);
        } else {
          fontSize = fontSizeValue.clamp(12.0, 32.0);
        }
      }

      // Handle migration from old notification settings
      final bool notificationsEnabled =
          json['notificationsEnabled'] as bool? ?? false;
      final int reminderHour = json['reminderHour'] as int? ?? 20;
      final int reminderMinute = json['reminderMinute'] as int? ?? 0;
      final bool dailyReminder = json['dailyReminderEnabled'] as bool? ?? false;

      baseSettings = BaseSettingsModel(
        fontSize: fontSize,
        defaultLanguage: AppLanguage.english,
        notificationsEnabled: notificationsEnabled,
        showLiturgicalColors: true,
        hapticFeedbackEnabled: json['hapticFeedbackEnabled'] as bool? ?? true,
      );

      // Return early with migrated settings
      return RosaryAppSettings(
        baseSettings: baseSettings,
        audioEnabled: json['audioEnabled'] as bool? ?? true,
        audioVolume: (json['audioVolume'] as num?)?.toDouble() ?? 0.8,
        autoPlayPrayers: json['autoPlayPrayers'] as bool? ?? false,
        hapticFeedbackEnabled: json['hapticFeedbackEnabled'] as bool? ?? true,
        rosaryNotificationsEnabled: notificationsEnabled,
        dailyReminderTime: reminderHour * 60 + reminderMinute,
        dailyReminderEnabled: dailyReminder,
        prayerLanguage: _parseLanguage(json['prayerLanguage'] as String?),
      );
    }

    return RosaryAppSettings(
      baseSettings: baseSettings,
      audioEnabled: json['audioEnabled'] as bool? ?? true,
      audioVolume: (json['audioVolume'] as num?)?.toDouble() ?? 0.8,
      autoPlayPrayers: json['autoPlayPrayers'] as bool? ?? false,
      hapticFeedbackEnabled: json['hapticFeedbackEnabled'] as bool? ?? true,
      rosaryNotificationsEnabled:
          json['rosaryNotificationsEnabled'] as bool? ?? false,
      dailyReminderTime: json['dailyReminderTime'] as int? ?? 1200,
      dailyReminderEnabled: json['dailyReminderEnabled'] as bool? ?? false,
      prayerLanguage: _parseLanguage(json['prayerLanguage'] as String?),
    );
  }

  /// Parse language from string code
  static AppLanguage _parseLanguage(String? code) {
    if (code == null) return AppLanguage.english;
    return AppLanguage.values.firstWhere(
      (lang) => lang.code == code,
      orElse: () => AppLanguage.english,
    );
  }

  /// Convert to JSON map
  Map<String, dynamic> toJson() {
    return {
      'baseSettings': baseSettings.toJson(),
      'audioEnabled': audioEnabled,
      'audioVolume': audioVolume,
      'autoPlayPrayers': autoPlayPrayers,
      'hapticFeedbackEnabled': hapticFeedbackEnabled,
      'rosaryNotificationsEnabled': rosaryNotificationsEnabled,
      'dailyReminderTime': dailyReminderTime,
      'dailyReminderEnabled': dailyReminderEnabled,
      'prayerLanguage': prayerLanguage.code,
    };
  }

  /// Create a copy with updated values
  RosaryAppSettings copyWith({
    BaseSettingsModel? baseSettings,
    bool? audioEnabled,
    double? audioVolume,
    bool? autoPlayPrayers,
    bool? hapticFeedbackEnabled,
    bool? rosaryNotificationsEnabled,
    int? dailyReminderTime,
    bool? dailyReminderEnabled,
    AppLanguage? prayerLanguage,
  }) {
    return RosaryAppSettings(
      baseSettings: baseSettings ?? this.baseSettings,
      audioEnabled: audioEnabled ?? this.audioEnabled,
      audioVolume: audioVolume ?? this.audioVolume,
      autoPlayPrayers: autoPlayPrayers ?? this.autoPlayPrayers,
      hapticFeedbackEnabled:
          hapticFeedbackEnabled ?? this.hapticFeedbackEnabled,
      rosaryNotificationsEnabled:
          rosaryNotificationsEnabled ?? this.rosaryNotificationsEnabled,
      dailyReminderTime: dailyReminderTime ?? this.dailyReminderTime,
      dailyReminderEnabled: dailyReminderEnabled ?? this.dailyReminderEnabled,
      prayerLanguage: prayerLanguage ?? this.prayerLanguage,
    );
  }

  /// Update base settings while preserving Rosary-specific settings
  RosaryAppSettings updateBaseSettings(BaseSettingsModel newBaseSettings) {
    return copyWith(baseSettings: newBaseSettings);
  }

  /// Convenience getters for commonly accessed base settings
  double get fontSize => baseSettings.fontSize;
  TextScalingMode get textScalingMode => baseSettings.textScalingMode;
  AppLanguage get defaultLanguage => baseSettings.defaultLanguage;
  bool get notificationsEnabled => baseSettings.notificationsEnabled;
  bool get showLiturgicalColors => baseSettings.showLiturgicalColors;
  bool get reduceMotion => baseSettings.reduceMotion;
  double get effectiveTextScaleFactor => baseSettings.effectiveTextScaleFactor;

  /// Get daily reminder time as TimeOfDay
  TimeOfDay get dailyReminderTimeOfDay {
    final hours = dailyReminderTime ~/ 60;
    final minutes = dailyReminderTime % 60;
    return TimeOfDay(hour: hours, minute: minutes);
  }

  /// Set daily reminder time from TimeOfDay
  RosaryAppSettings withDailyReminderTime(TimeOfDay time) {
    final totalMinutes = time.hour * 60 + time.minute;
    return copyWith(dailyReminderTime: totalMinutes);
  }

  /// Get the formatted reminder time (e.g., "8:00 PM")
  String get formattedReminderTime {
    final hour = dailyReminderTime ~/ 60;
    final minute = dailyReminderTime % 60;
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    final displayMinute = minute.toString().padLeft(2, '0');
    return '$displayHour:$displayMinute $period';
  }

  /// Get audio volume clamped to valid range
  double get clampedAudioVolume => audioVolume.clamp(0.0, 1.0);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RosaryAppSettings &&
        other.baseSettings == baseSettings &&
        other.audioEnabled == audioEnabled &&
        other.audioVolume == audioVolume &&
        other.autoPlayPrayers == autoPlayPrayers &&
        other.hapticFeedbackEnabled == hapticFeedbackEnabled &&
        other.rosaryNotificationsEnabled == rosaryNotificationsEnabled &&
        other.dailyReminderTime == dailyReminderTime &&
        other.dailyReminderEnabled == dailyReminderEnabled &&
        other.prayerLanguage == prayerLanguage;
  }

  @override
  int get hashCode {
    return Object.hash(
      baseSettings,
      audioEnabled,
      audioVolume,
      autoPlayPrayers,
      hapticFeedbackEnabled,
      rosaryNotificationsEnabled,
      dailyReminderTime,
      dailyReminderEnabled,
      prayerLanguage,
    );
  }

  @override
  String toString() {
    return 'RosaryAppSettings('
        'baseSettings: $baseSettings, '
        'audioEnabled: $audioEnabled, '
        'audioVolume: $audioVolume, '
        'autoPlayPrayers: $autoPlayPrayers, '
        'hapticFeedbackEnabled: $hapticFeedbackEnabled, '
        'rosaryNotificationsEnabled: $rosaryNotificationsEnabled, '
        'dailyReminderTime: $dailyReminderTime, '
        'dailyReminderEnabled: $dailyReminderEnabled, '
        'prayerLanguage: $prayerLanguage'
        ')';
  }
}
