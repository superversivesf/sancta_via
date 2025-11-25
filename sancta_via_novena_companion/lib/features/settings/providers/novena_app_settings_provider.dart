import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sancta_via_shared_ui/sancta_via_shared_ui.dart';

import '../models/novena_app_settings.dart';
import '../../../services/auth_service.dart';
import '../../../utils/logger.dart';
import '../../../utils/error_handler.dart';

/// Simplified provider for Novena app settings
class NovenaAppSettingsNotifier extends StateNotifier<NovenaAppSettings> {
  static const String _storageKey = 'novena_app_settings_unified';
  static const String _migrationKey = 'novena_settings_migrated_v2';

  final Ref _ref;
  final AuthService _authService;

  NovenaAppSettingsNotifier(this._ref, this._authService)
    : super(NovenaAppSettings.defaults()) {
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
        final settings = NovenaAppSettings.fromJson(settingsMap);

        if (mounted) {
          state = settings;
          await _ref
              .read(baseSettingsProvider.notifier)
              .updateSettings(settings.baseSettings);
        }
      } else {
        final defaultSettings = NovenaAppSettings.defaults();
        state = defaultSettings;
        await _ref
            .read(baseSettingsProvider.notifier)
            .updateSettings(defaultSettings.baseSettings);
      }

      // Sync PIN status with auth service
      await _refreshPinStatus();

      AppLogger.debug('Novena settings loaded successfully', 'NOVENA_SETTINGS');
    } catch (e, stackTrace) {
      AppLogger.error(
        'Failed to load novena settings',
        e,
        stackTrace,
        'NOVENA_SETTINGS',
      );
      ErrorHandler.handleError(
        e,
        stackTrace: stackTrace,
        tag: 'NOVENA_SETTINGS',
      );
      state = NovenaAppSettings.defaults();
    }
  }

  Future<void> _migrateFromLegacySettings(SharedPreferences prefs) async {
    try {
      // Look for old settings format
      final oldFontSize = prefs.getDouble('fontSize');
      final oldColorSchemeStyle = prefs.getInt('colorSchemeStyle');

      // Check if auth service has PIN
      final hasPinCode = await _authService.hasPinCode();

      // Create migration data
      final migrationData = <String, dynamic>{};

      if (oldFontSize != null) {
        migrationData['fontSize'] = oldFontSize;
      }

      if (oldColorSchemeStyle != null) {
        migrationData['colorSchemeStyle'] = oldColorSchemeStyle;
      }

      migrationData['hasPinCode'] = hasPinCode;

      // Create settings from migration data
      final migratedSettings = NovenaAppSettings.fromJson(migrationData);
      await _saveSettings(migratedSettings);

      // Mark migration as complete
      await prefs.setBool(_migrationKey, true);

      AppLogger.debug(
        'Settings migration completed successfully',
        'NOVENA_SETTINGS',
      );
    } catch (e, stackTrace) {
      AppLogger.error(
        'Settings migration failed',
        e,
        stackTrace,
        'NOVENA_SETTINGS',
      );
      // Continue with defaults if migration fails
    }
  }

  Future<void> _saveSettings([NovenaAppSettings? settings]) async {
    try {
      final settingsToSave = settings ?? state;
      final prefs = await SharedPreferences.getInstance();
      final settingsJson = json.encode(settingsToSave.toJson());
      await prefs.setString(_storageKey, settingsJson);
    } catch (e, stackTrace) {
      AppLogger.error(
        'Failed to save novena settings',
        e,
        stackTrace,
        'NOVENA_SETTINGS',
      );
      ErrorHandler.handleError(
        e,
        stackTrace: stackTrace,
        tag: 'NOVENA_SETTINGS',
      );
    }
  }

  void _syncBaseSettings(BaseSettingsModel newBaseSettings) {
    if (state.baseSettings != newBaseSettings) {
      state = state.updateBaseSettings(newBaseSettings);
      _saveSettings();
    }
  }

  Future<void> _refreshPinStatus() async {
    try {
      final hasPin = await _authService.hasPinCode();
      if (state.hasPinCode != hasPin) {
        state = state.copyWith(hasPinCode: hasPin);
        await _saveSettings();
      }
    } catch (e, stackTrace) {
      AppLogger.error(
        'Failed to refresh PIN status',
        e,
        stackTrace,
        'NOVENA_SETTINGS',
      );
    }
  }

  // Novena-specific methods
  Future<void> updateNovenaNotificationsEnabled(bool enabled) async {
    state = state.copyWith(novenaNotificationsEnabled: enabled);
    await _saveSettings();
  }

  Future<void> updateDailyReminderTime(TimeOfDay time) async {
    state = state.withDailyReminderTime(time);
    await _saveSettings();
  }

  Future<void> updateShowCompletionCelebrations(bool show) async {
    state = state.copyWith(showCompletionCelebrations: show);
    await _saveSettings();
  }

  Future<void> updateAllowMultipleNovenas(bool allow) async {
    state = state.copyWith(allowMultipleNovenas: allow);
    await _saveSettings();
  }

  /// Set PIN code using AuthService
  Future<void> setPinCode(String pinCode) async {
    try {
      await _authService.setPinCode(pinCode);
      state = state.copyWith(hasPinCode: true);
      await _saveSettings();
      AppLogger.debug('PIN code set via novena settings', 'NOVENA_SETTINGS');
    } catch (e, stackTrace) {
      AppLogger.error(
        'Failed to set PIN code via novena settings',
        e,
        stackTrace,
        'NOVENA_SETTINGS',
      );
      ErrorHandler.handleError(
        e,
        stackTrace: stackTrace,
        tag: 'NOVENA_SETTINGS',
      );
      rethrow;
    }
  }

  /// Clear PIN code using AuthService
  Future<void> clearPinCode() async {
    try {
      await _authService.clearPinCode();
      state = state.copyWith(hasPinCode: false);
      await _saveSettings();
      AppLogger.debug(
        'PIN code cleared via novena settings',
        'NOVENA_SETTINGS',
      );
    } catch (e, stackTrace) {
      AppLogger.error(
        'Failed to clear PIN code via novena settings',
        e,
        stackTrace,
        'NOVENA_SETTINGS',
      );
      ErrorHandler.handleError(
        e,
        stackTrace: stackTrace,
        tag: 'NOVENA_SETTINGS',
      );
      rethrow;
    }
  }

  /// Refresh PIN status (useful after external PIN changes)
  Future<void> refreshPinStatus() async {
    await _refreshPinStatus();
  }
}

/// Provider for Novena app settings
final novenaAppSettingsProvider =
    StateNotifierProvider<NovenaAppSettingsNotifier, NovenaAppSettings>((ref) {
      final authService = ref.read(authServiceProvider);
      return NovenaAppSettingsNotifier(ref, authService);
    });

/// Simplified convenience providers for specific settings
final novenaNotificationsEnabledProvider = Provider<bool>((ref) {
  return ref.watch(novenaAppSettingsProvider).novenaNotificationsEnabled;
});

final novenaDailyReminderTimeProvider = Provider<TimeOfDay>((ref) {
  return ref.watch(novenaAppSettingsProvider).dailyReminderTimeOfDay;
});

final novenaShowCompletionCelebrationsProvider = Provider<bool>((ref) {
  return ref.watch(novenaAppSettingsProvider).showCompletionCelebrations;
});
