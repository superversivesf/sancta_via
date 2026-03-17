import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sancta_via_shared_ui/sancta_via_shared_ui.dart' hide AppLogger;

import '../models/settings_state.dart';
import '../services/notification_service.dart';
import '../utils/logger.dart';

/// Simplified provider for Rosary app settings with bi-directional sync
class RosaryAppSettingsNotifier extends StateNotifier<RosaryAppSettings> {
  static const String _storageKey = 'rosary_app_settings_unified';
  static const String _migrationKey = 'rosary_settings_migrated_v2';
  static const String _oldStorageKey = 'rosary_notification_settings';

  final Ref _ref;

  RosaryAppSettingsNotifier(this._ref) : super(RosaryAppSettings.defaults()) {
    _loadSettings();

    // Listen to base settings changes and sync them
    _ref.listen(baseSettingsProvider, (previous, next) {
      if (previous != next) {
        _syncBaseSettings(next);
      }
    });
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Check if we need to migrate from old format
      final needsMigration = !(prefs.getBool(_migrationKey) ?? false);

      if (needsMigration) {
        await _migrateFromLegacySettings(prefs);
      }

      // Load unified settings
      final settingsJson = prefs.getString(_storageKey);

      if (settingsJson != null) {
        final settingsMap = json.decode(settingsJson) as Map<String, dynamic>;
        final settings = RosaryAppSettings.fromJson(settingsMap);

        if (mounted) {
          state = settings;
          // Sync base settings to the shared provider
          await _ref
              .read(baseSettingsProvider.notifier)
              .updateSettings(settings.baseSettings);
        }
      } else {
        final defaultSettings = RosaryAppSettings.defaults();
        state = defaultSettings;
        await _ref
            .read(baseSettingsProvider.notifier)
            .updateSettings(defaultSettings.baseSettings);
      }

      // Apply notification settings if needed
      await _applyNotificationSettings();

      AppLogger.debug('Rosary settings loaded successfully', 'ROSARY_SETTINGS');
    } catch (e, stackTrace) {
      AppLogger.error(
        'Failed to load rosary settings',
        e,
        stackTrace,
        'ROSARY_SETTINGS',
      );
      state = RosaryAppSettings.defaults();
    }
  }

  Future<void> _migrateFromLegacySettings(SharedPreferences prefs) async {
    try {
      // Look for old settings format
      final oldSettingsJson = prefs.getString(_oldStorageKey);

      if (oldSettingsJson != null) {
        final oldSettingsMap =
            json.decode(oldSettingsJson) as Map<String, dynamic>;

        // Create settings from migration data
        final migratedSettings = RosaryAppSettings.fromJson(oldSettingsMap);
        await _saveSettings(migratedSettings);

        AppLogger.debug(
          'Settings migration completed from old format',
          'ROSARY_SETTINGS',
        );
      }

      // Check for other legacy keys
      final legacyKeys = [
        'fontSize',
        'colorSchemeStyle',
        'audio_enabled',
        'auto_play',
      ];

      final migrationData = <String, dynamic>{};
      for (final key in legacyKeys) {
        final value = prefs.get(key);
        if (value != null) {
          migrationData[key] = value;
        }
      }

      if (migrationData.isNotEmpty) {
        // Create settings from legacy data
        final migratedSettings = RosaryAppSettings.fromJson(migrationData);
        await _saveSettings(migratedSettings);
      }

      // Mark migration as complete
      await prefs.setBool(_migrationKey, true);

      AppLogger.debug(
        'Settings migration completed successfully',
        'ROSARY_SETTINGS',
      );
    } catch (e, stackTrace) {
      AppLogger.error(
        'Settings migration failed',
        e,
        stackTrace,
        'ROSARY_SETTINGS',
      );
      // Continue with defaults if migration fails
    }
  }

  Future<void> _saveSettings([RosaryAppSettings? settings]) async {
    try {
      final settingsToSave = settings ?? state;
      final prefs = await SharedPreferences.getInstance();
      final settingsJson = json.encode(settingsToSave.toJson());
      await prefs.setString(_storageKey, settingsJson);
    } catch (e, stackTrace) {
      AppLogger.error(
        'Failed to save rosary settings',
        e,
        stackTrace,
        'ROSARY_SETTINGS',
      );
    }
  }

  void _syncBaseSettings(BaseSettingsModel newBaseSettings) {
    if (state.baseSettings != newBaseSettings) {
      state = state.updateBaseSettings(newBaseSettings);
      _saveSettings();
    }
  }

  Future<void> _applyNotificationSettings() async {
    try {
      final notificationService = NotificationService.instance;
      await notificationService.initialize();

      if (state.rosaryNotificationsEnabled && state.dailyReminderEnabled) {
        await notificationService.scheduleDailyRosaryReminder(
          hour: state.dailyReminderTimeOfDay.hour,
          minute: state.dailyReminderTimeOfDay.minute,
        );
        AppLogger.info(
          'Scheduled daily reminder at ${state.formattedReminderTime}',
          'ROSARY_SETTINGS',
        );
      } else {
        await notificationService.cancelDailyRosaryReminder();
        AppLogger.info('Cancelled daily reminder', 'ROSARY_SETTINGS');
      }
    } catch (e, stackTrace) {
      AppLogger.error(
        'Failed to apply notification settings',
        e,
        stackTrace,
        'ROSARY_SETTINGS',
      );
    }
  }

  // Audio Settings Methods
  Future<void> setAudioEnabled(bool enabled) async {
    state = state.copyWith(audioEnabled: enabled);
    await _saveSettings();
  }

  Future<void> setAudioVolume(double volume) async {
    final clampedVolume = volume.clamp(0.0, 1.0);
    state = state.copyWith(audioVolume: clampedVolume);
    await _saveSettings();
  }

  Future<void> setAutoPlayPrayers(bool enabled) async {
    state = state.copyWith(autoPlayPrayers: enabled);
    await _saveSettings();
  }

  Future<void> setHapticFeedbackEnabled(bool enabled) async {
    state = state.copyWith(hapticFeedbackEnabled: enabled);
    await _saveSettings();
  }

  // Notification Settings Methods
  Future<void> setRosaryNotificationsEnabled(bool enabled) async {
    if (enabled) {
      // Request permissions first
      final granted = await NotificationService.instance.requestPermissions();
      if (!granted) {
        AppLogger.warning('Notification permission denied', 'ROSARY_SETTINGS');
        return;
      }
    }

    state = state.copyWith(
      rosaryNotificationsEnabled: enabled,
      dailyReminderEnabled: enabled ? state.dailyReminderEnabled : false,
    );
    await _saveSettings();
    await _applyNotificationSettings();
  }

  Future<void> setDailyReminderTime(TimeOfDay time) async {
    // Clamp values to valid ranges
    final clampedHour = time.hour.clamp(0, 23);
    final clampedMinute = time.minute.clamp(0, 59);

    state = state.withDailyReminderTime(
      TimeOfDay(hour: clampedHour, minute: clampedMinute),
    );
    await _saveSettings();
    await _applyNotificationSettings();
  }

  Future<void> setDailyReminderEnabled(bool enabled) async {
    if (enabled && !state.rosaryNotificationsEnabled) {
      // Must have general notifications enabled
      return;
    }

    state = state.copyWith(dailyReminderEnabled: enabled);
    await _saveSettings();
    await _applyNotificationSettings();
  }

  // Prayer Language
  Future<void> setPrayerLanguage(AppLanguage language) async {
    state = state.copyWith(prayerLanguage: language);
    await _saveSettings();
  }

  // Base Settings Proxy Methods (sync both ways)
  Future<void> setFontSize(double fontSize) async {
    final clampedSize = fontSize.clamp(12.0, 32.0);
    await _ref.read(baseSettingsProvider.notifier).setFontSize(clampedSize);
  }

  Future<void> setTextScalingMode(TextScalingMode mode) async {
    await _ref.read(baseSettingsProvider.notifier).setTextScalingMode(mode);
  }

  Future<void> setDefaultLanguage(AppLanguage language) async {
    await _ref.read(baseSettingsProvider.notifier).setDefaultLanguage(language);
  }

  Future<void> setNotificationsEnabled(bool enabled) async {
    await _ref
        .read(baseSettingsProvider.notifier)
        .setNotificationsEnabled(enabled);
  }

  Future<void> setShowLiturgicalColors(bool show) async {
    await _ref
        .read(baseSettingsProvider.notifier)
        .setShowLiturgicalColors(show);
  }

  Future<void> setReduceMotion(bool reduce) async {
    await _ref.read(baseSettingsProvider.notifier).setReduceMotion(reduce);
  }

  // Reset
  Future<void> resetToDefaults() async {
    state = RosaryAppSettings.defaults();
    await _saveSettings();
    await _ref
        .read(baseSettingsProvider.notifier)
        .updateSettings(state.baseSettings);
    await _applyNotificationSettings();
  }
}

/// Provider for Rosary app settings
final rosaryAppSettingsProvider =
    StateNotifierProvider<RosaryAppSettingsNotifier, RosaryAppSettings>((ref) {
      return RosaryAppSettingsNotifier(ref);
    });

// Convenience Providers

/// Audio enabled state
final rosaryAudioEnabledProvider = Provider<bool>((ref) {
  return ref.watch(rosaryAppSettingsProvider).audioEnabled;
});

/// Audio volume (0.0 to 1.0)
final rosaryAudioVolumeProvider = Provider<double>((ref) {
  return ref.watch(rosaryAppSettingsProvider).clampedAudioVolume;
});

/// Auto-play prayers state
final rosaryAutoPlayPrayersProvider = Provider<bool>((ref) {
  return ref.watch(rosaryAppSettingsProvider).autoPlayPrayers;
});

/// Haptic feedback enabled
final rosaryHapticFeedbackProvider = Provider<bool>((ref) {
  return ref.watch(rosaryAppSettingsProvider).hapticFeedbackEnabled;
});

/// Rosary notifications enabled
final rosaryNotificationsEnabledProvider = Provider<bool>((ref) {
  return ref.watch(rosaryAppSettingsProvider).rosaryNotificationsEnabled;
});

/// Daily reminder enabled
final rosaryDailyReminderEnabledProvider = Provider<bool>((ref) {
  return ref.watch(rosaryAppSettingsProvider).dailyReminderEnabled;
});

/// Daily reminder time as TimeOfDay
final rosaryDailyReminderTimeProvider = Provider<TimeOfDay>((ref) {
  return ref.watch(rosaryAppSettingsProvider).dailyReminderTimeOfDay;
});

/// Formatted reminder time string
final rosaryFormattedReminderTimeProvider = Provider<String>((ref) {
  return ref.watch(rosaryAppSettingsProvider).formattedReminderTime;
});

/// Prayer language preference
final rosaryPrayerLanguageProvider = Provider<AppLanguage>((ref) {
  return ref.watch(rosaryAppSettingsProvider).prayerLanguage;
});

/// Combined effective text scale (base settings)
final rosaryEffectiveTextScaleProvider = Provider<double>((ref) {
  return ref.watch(rosaryAppSettingsProvider).effectiveTextScaleFactor;
});
