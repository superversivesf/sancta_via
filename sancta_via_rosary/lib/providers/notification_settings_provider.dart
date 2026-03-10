import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/notification_service.dart';
import '../utils/logger.dart';

/// Rosary-specific settings model that extends base settings with notification preferences.
@immutable
class RosarySettings {
  final bool notificationsEnabled;
  final int reminderHour;
  final int reminderMinute;
  final bool dailyReminderEnabled;

  const RosarySettings({
    this.notificationsEnabled = false,
    this.reminderHour = 20, // Default 8:00 PM
    this.reminderMinute = 0,
    this.dailyReminderEnabled = false,
  });

  /// Create default settings
  factory RosarySettings.defaults() {
    return const RosarySettings();
  }

  /// Create from JSON map
  factory RosarySettings.fromJson(Map<String, dynamic> json) {
    return RosarySettings(
      notificationsEnabled: json['notificationsEnabled'] as bool? ?? false,
      reminderHour: json['reminderHour'] as int? ?? 20,
      reminderMinute: json['reminderMinute'] as int? ?? 0,
      dailyReminderEnabled: json['dailyReminderEnabled'] as bool? ?? false,
    );
  }

  /// Convert to JSON map
  Map<String, dynamic> toJson() {
    return {
      'notificationsEnabled': notificationsEnabled,
      'reminderHour': reminderHour,
      'reminderMinute': reminderMinute,
      'dailyReminderEnabled': dailyReminderEnabled,
    };
  }

  /// Create a copy with updated values
  RosarySettings copyWith({
    bool? notificationsEnabled,
    int? reminderHour,
    int? reminderMinute,
    bool? dailyReminderEnabled,
  }) {
    return RosarySettings(
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      reminderHour: reminderHour ?? this.reminderHour,
      reminderMinute: reminderMinute ?? this.reminderMinute,
      dailyReminderEnabled: dailyReminderEnabled ?? this.dailyReminderEnabled,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RosarySettings &&
        other.notificationsEnabled == notificationsEnabled &&
        other.reminderHour == reminderHour &&
        other.reminderMinute == reminderMinute &&
        other.dailyReminderEnabled == dailyReminderEnabled;
  }

  @override
  int get hashCode {
    return Object.hash(
      notificationsEnabled,
      reminderHour,
      reminderMinute,
      dailyReminderEnabled,
    );
  }
}

/// Provider for managing Rosary app notification settings.
class RosarySettingsNotifier extends StateNotifier<RosarySettings> {
  static const String _storageKey = 'rosary_notification_settings';

  RosarySettingsNotifier() : super(RosarySettings.defaults()) {
    _loadSettings();
  }

  /// Load settings from persistent storage
  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final settingsJson = prefs.getString(_storageKey);

      if (settingsJson != null) {
        final settingsMap = json.decode(settingsJson) as Map<String, dynamic>;
        final settings = RosarySettings.fromJson(settingsMap);
        if (mounted) {
          state = settings;
        }

        // Apply loaded settings
        await _applyNotificationSettings(settings);
      }
    } catch (e) {
      AppLogger.error(
        'Failed to load notification settings',
        e,
        null,
        'SETTINGS',
      );
    }
  }

  /// Save settings to persistent storage
  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final settingsJson = json.encode(state.toJson());
      await prefs.setString(_storageKey, settingsJson);
    } catch (e) {
      AppLogger.error(
        'Failed to save notification settings',
        e,
        null,
        'SETTINGS',
      );
    }
  }

  /// Apply notification settings to the notification service
  Future<void> _applyNotificationSettings(RosarySettings settings) async {
    final notificationService = NotificationService.instance;
    await notificationService.initialize();

    if (settings.notificationsEnabled && settings.dailyReminderEnabled) {
      // Schedule daily reminder
      await notificationService.scheduleDailyRosaryReminder(
        hour: settings.reminderHour,
        minute: settings.reminderMinute,
      );
      AppLogger.info(
        'Scheduled daily reminder at ${settings.reminderHour}:${settings.reminderMinute.toString().padLeft(2, '0')}',
        'SETTINGS',
      );
    } else {
      // Cancel daily reminder
      await notificationService.cancelDailyRosaryReminder();
      AppLogger.info('Cancelled daily reminder', 'SETTINGS');
    }
  }

  /// Enable/disable notifications and daily reminders
  Future<void> setNotificationsEnabled(bool enabled) async {
    if (enabled) {
      // Request permissions first
      final granted = await NotificationService.instance.requestPermissions();
      if (!granted) {
        AppLogger.warning('Notification permission denied', 'SETTINGS');
        return;
      }
    }

    state = state.copyWith(
      notificationsEnabled: enabled,
      dailyReminderEnabled: enabled ? state.dailyReminderEnabled : false,
    );
    await _saveSettings();
    await _applyNotificationSettings(state);
  }

  /// Set the daily reminder time
  Future<void> setReminderTime(int hour, int minute) async {
    // Clamp values to valid ranges
    final clampedHour = hour.clamp(0, 23);
    final clampedMinute = minute.clamp(0, 59);

    state = state.copyWith(
      reminderHour: clampedHour,
      reminderMinute: clampedMinute,
    );
    await _saveSettings();

    // Reschedule if daily reminder is enabled
    if (state.notificationsEnabled && state.dailyReminderEnabled) {
      await _applyNotificationSettings(state);
    }
  }

  /// Enable/disable daily reminder specifically
  Future<void> setDailyReminderEnabled(bool enabled) async {
    if (enabled && !state.notificationsEnabled) {
      // Must have general notifications enabled
      return;
    }

    state = state.copyWith(dailyReminderEnabled: enabled);
    await _saveSettings();
    await _applyNotificationSettings(state);
  }

  /// Reset all notification settings to defaults
  Future<void> resetToDefaults() async {
    await NotificationService.instance.cancelDailyRosaryReminder();
    state = RosarySettings.defaults();
    await _saveSettings();
  }

  /// Get the formatted reminder time (e.g., "8:00 PM")
  String get formattedReminderTime {
    final hour = state.reminderHour;
    final minute = state.reminderMinute;
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    final displayMinute = minute.toString().padLeft(2, '0');
    return '$displayHour:$displayMinute $period';
  }
}

/// Provider for Rosary notification settings
final rosarySettingsProvider =
    StateNotifierProvider<RosarySettingsNotifier, RosarySettings>((ref) {
      return RosarySettingsNotifier();
    });

/// Convenience provider for notifications enabled
final rosaryNotificationsEnabledProvider = Provider<bool>((ref) {
  return ref.watch(rosarySettingsProvider).notificationsEnabled;
});

/// Convenience provider for daily reminder enabled
final dailyReminderEnabledProvider = Provider<bool>((ref) {
  return ref.watch(rosarySettingsProvider).dailyReminderEnabled;
});

/// Convenience provider for reminder time as TimeOfDay
final reminderTimeProvider = Provider<({int hour, int minute})>((ref) {
  final settings = ref.watch(rosarySettingsProvider);
  return (hour: settings.reminderHour, minute: settings.reminderMinute);
});

/// Convenience provider for formatted reminder time string
final formattedReminderTimeProvider = Provider<String>((ref) {
  return ref.watch(rosarySettingsProvider.notifier).formattedReminderTime;
});
