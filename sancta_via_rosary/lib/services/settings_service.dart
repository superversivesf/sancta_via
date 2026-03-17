import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sancta_via_shared_ui/sancta_via_shared_ui.dart' hide AppLogger;

import '../providers/settings_provider.dart';
import '../services/notification_service.dart';
import '../utils/logger.dart';

/// Service class to handle Rosary settings-related business logic
/// This separates business logic from UI components
class RosarySettingsService {
  final Ref _ref;

  RosarySettingsService(this._ref);

  /// Update audio enabled state
  Future<void> updateAudioEnabled(bool enabled) async {
    try {
      await _ref
          .read(rosaryAppSettingsProvider.notifier)
          .setAudioEnabled(enabled);
      AppLogger.debug(
        'Audio ${enabled ? 'enabled' : 'disabled'}',
        'ROSARY_SETTINGS_SERVICE',
      );
    } catch (e, stackTrace) {
      AppLogger.error(
        'Failed to update audio enabled',
        e,
        stackTrace,
        'ROSARY_SETTINGS_SERVICE',
      );
      rethrow;
    }
  }

  /// Update audio volume (0.0 to 1.0)
  Future<void> updateAudioVolume(double volume) async {
    try {
      final clampedVolume = volume.clamp(0.0, 1.0);
      await _ref
          .read(rosaryAppSettingsProvider.notifier)
          .setAudioVolume(clampedVolume);
      AppLogger.debug(
        'Audio volume updated to ${(clampedVolume * 100).toInt()}%',
        'ROSARY_SETTINGS_SERVICE',
      );
    } catch (e, stackTrace) {
      AppLogger.error(
        'Failed to update audio volume',
        e,
        stackTrace,
        'ROSARY_SETTINGS_SERVICE',
      );
      rethrow;
    }
  }

  /// Update auto-play prayers setting
  Future<void> updateAutoPlayPrayers(bool enabled) async {
    try {
      await _ref
          .read(rosaryAppSettingsProvider.notifier)
          .setAutoPlayPrayers(enabled);
      AppLogger.debug(
        'Auto-play prayers ${enabled ? 'enabled' : 'disabled'}',
        'ROSARY_SETTINGS_SERVICE',
      );
    } catch (e, stackTrace) {
      AppLogger.error(
        'Failed to update auto-play prayers',
        e,
        stackTrace,
        'ROSARY_SETTINGS_SERVICE',
      );
      rethrow;
    }
  }

  /// Update haptic feedback enabled
  Future<void> updateHapticFeedbackEnabled(bool enabled) async {
    try {
      await _ref
          .read(rosaryAppSettingsProvider.notifier)
          .setHapticFeedbackEnabled(enabled);
      AppLogger.debug(
        'Haptic feedback ${enabled ? 'enabled' : 'disabled'}',
        'ROSARY_SETTINGS_SERVICE',
      );
    } catch (e, stackTrace) {
      AppLogger.error(
        'Failed to update haptic feedback',
        e,
        stackTrace,
        'ROSARY_SETTINGS_SERVICE',
      );
      rethrow;
    }
  }

  /// Toggle rosary notifications
  Future<void> toggleRosaryNotifications(bool enabled) async {
    try {
      await _ref
          .read(rosaryAppSettingsProvider.notifier)
          .setRosaryNotificationsEnabled(enabled);
      AppLogger.debug(
        'Rosary notifications ${enabled ? 'enabled' : 'disabled'}',
        'ROSARY_SETTINGS_SERVICE',
      );
    } catch (e, stackTrace) {
      AppLogger.error(
        'Failed to toggle rosary notifications',
        e,
        stackTrace,
        'ROSARY_SETTINGS_SERVICE',
      );
      rethrow;
    }
  }

  /// Update daily reminder time
  Future<void> updateDailyReminderTime(TimeOfDay time) async {
    try {
      await _ref
          .read(rosaryAppSettingsProvider.notifier)
          .setDailyReminderTime(time);
      AppLogger.debug(
        'Daily reminder time updated to ${time.hour}:${time.minute.toString().padLeft(2, '0')}',
        'ROSARY_SETTINGS_SERVICE',
      );
    } catch (e, stackTrace) {
      AppLogger.error(
        'Failed to update daily reminder time',
        e,
        stackTrace,
        'ROSARY_SETTINGS_SERVICE',
      );
      rethrow;
    }
  }

  /// Toggle daily reminder
  Future<void> toggleDailyReminder(bool enabled) async {
    try {
      await _ref
          .read(rosaryAppSettingsProvider.notifier)
          .setDailyReminderEnabled(enabled);
      AppLogger.debug(
        'Daily reminder ${enabled ? 'enabled' : 'disabled'}',
        'ROSARY_SETTINGS_SERVICE',
      );
    } catch (e, stackTrace) {
      AppLogger.error(
        'Failed to toggle daily reminder',
        e,
        stackTrace,
        'ROSARY_SETTINGS_SERVICE',
      );
      rethrow;
    }
  }

  /// Update prayer language
  Future<void> updatePrayerLanguage(AppLanguage language) async {
    try {
      await _ref
          .read(rosaryAppSettingsProvider.notifier)
          .setPrayerLanguage(language);
      AppLogger.debug(
        'Prayer language updated to ${language.displayName}',
        'ROSARY_SETTINGS_SERVICE',
      );
    } catch (e, stackTrace) {
      AppLogger.error(
        'Failed to update prayer language',
        e,
        stackTrace,
        'ROSARY_SETTINGS_SERVICE',
      );
      rethrow;
    }
  }

  /// Update base font size
  Future<void> updateFontSize(double fontSize) async {
    try {
      await _ref.read(rosaryAppSettingsProvider.notifier).setFontSize(fontSize);
      AppLogger.debug(
        'Font size updated to $fontSize',
        'ROSARY_SETTINGS_SERVICE',
      );
    } catch (e, stackTrace) {
      AppLogger.error(
        'Failed to update font size',
        e,
        stackTrace,
        'ROSARY_SETTINGS_SERVICE',
      );
      rethrow;
    }
  }

  /// Update text scaling mode
  Future<void> updateTextScalingMode(TextScalingMode mode) async {
    try {
      await _ref
          .read(rosaryAppSettingsProvider.notifier)
          .setTextScalingMode(mode);
      AppLogger.debug(
        'Text scaling mode updated to ${mode.displayName}',
        'ROSARY_SETTINGS_SERVICE',
      );
    } catch (e, stackTrace) {
      AppLogger.error(
        'Failed to update text scaling mode',
        e,
        stackTrace,
        'ROSARY_SETTINGS_SERVICE',
      );
      rethrow;
    }
  }

  /// Update show liturgical colors
  Future<void> updateShowLiturgicalColors(bool show) async {
    try {
      await _ref
          .read(rosaryAppSettingsProvider.notifier)
          .setShowLiturgicalColors(show);
      AppLogger.debug(
        'Liturgical colors ${show ? 'enabled' : 'disabled'}',
        'ROSARY_SETTINGS_SERVICE',
      );
    } catch (e, stackTrace) {
      AppLogger.error(
        'Failed to update liturgical colors setting',
        e,
        stackTrace,
        'ROSARY_SETTINGS_SERVICE',
      );
      rethrow;
    }
  }

  /// Request notification permissions
  Future<bool> requestNotificationPermissions() async {
    try {
      final granted = await NotificationService.instance.requestPermissions();
      AppLogger.debug(
        'Notification permissions ${granted ? 'granted' : 'denied'}',
        'ROSARY_SETTINGS_SERVICE',
      );
      return granted;
    } catch (e, stackTrace) {
      AppLogger.error(
        'Failed to request notification permissions',
        e,
        stackTrace,
        'ROSARY_SETTINGS_SERVICE',
      );
      return false;
    }
  }

  /// Show test notification
  Future<void> showTestNotification() async {
    try {
      await NotificationService.instance.showTestNotification();
      AppLogger.debug('Test notification shown', 'ROSARY_SETTINGS_SERVICE');
    } catch (e, stackTrace) {
      AppLogger.error(
        'Failed to show test notification',
        e,
        stackTrace,
        'ROSARY_SETTINGS_SERVICE',
      );
      rethrow;
    }
  }

  /// Reset all settings to defaults
  Future<void> resetToDefaults() async {
    try {
      await _ref.read(rosaryAppSettingsProvider.notifier).resetToDefaults();
      AppLogger.debug(
        'All settings reset to defaults',
        'ROSARY_SETTINGS_SERVICE',
      );
    } catch (e, stackTrace) {
      AppLogger.error(
        'Failed to reset settings',
        e,
        stackTrace,
        'ROSARY_SETTINGS_SERVICE',
      );
      rethrow;
    }
  }

  // Getters for current values

  /// Get current audio enabled state
  bool get isAudioEnabled {
    return _ref.read(rosaryAppSettingsProvider).audioEnabled;
  }

  /// Get current audio volume
  double get audioVolume {
    return _ref.read(rosaryAppSettingsProvider).clampedAudioVolume;
  }

  /// Get current auto-play state
  bool get isAutoPlayEnabled {
    return _ref.read(rosaryAppSettingsProvider).autoPlayPrayers;
  }

  /// Get current haptic feedback state
  bool get isHapticFeedbackEnabled {
    return _ref.read(rosaryAppSettingsProvider).hapticFeedbackEnabled;
  }

  /// Get current rosary notifications state
  bool get areRosaryNotificationsEnabled {
    return _ref.read(rosaryAppSettingsProvider).rosaryNotificationsEnabled;
  }

  /// Get current daily reminder state
  bool get isDailyReminderEnabled {
    return _ref.read(rosaryAppSettingsProvider).dailyReminderEnabled;
  }

  /// Get current reminder time
  TimeOfDay get currentReminderTime {
    return _ref.read(rosaryAppSettingsProvider).dailyReminderTimeOfDay;
  }

  /// Get formatted reminder time
  String get formattedReminderTime {
    return _ref.read(rosaryAppSettingsProvider).formattedReminderTime;
  }

  /// Get current prayer language
  AppLanguage get prayerLanguage {
    return _ref.read(rosaryAppSettingsProvider).prayerLanguage;
  }

  /// Get effective text scale factor
  double get effectiveTextScaleFactor {
    return _ref.read(rosaryAppSettingsProvider).effectiveTextScaleFactor;
  }
}

/// Provider for the Rosary settings service
final rosarySettingsServiceProvider = Provider<RosarySettingsService>((ref) {
  return RosarySettingsService(ref);
});
