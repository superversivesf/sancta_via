import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sancta_via_shared_ui/sancta_via_shared_ui.dart';

import '../models/novena_app_settings.dart';
import '../../../services/auth_service.dart';
import '../../../utils/logger.dart';
import '../../../utils/error_handler.dart';
import '../../../config/theme.dart';

/// Provider for Novena app specific settings
class NovenaAppSettingsNotifier extends StateNotifier<NovenaAppSettings> {
  static const String _storageKey = 'novena_app_settings_unified';
  // Legacy storage key no longer used but kept for reference
  // static const String _legacyStorageKey = 'settings_model';
  static const String _migrationKey = 'novena_settings_migrated_v1';

  final Ref _ref;
  final AuthService _authService;

  NovenaAppSettingsNotifier(this._ref, this._authService) : super(NovenaAppSettings.defaults()) {
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
          await _ref.read(baseSettingsProvider.notifier).updateSettings(settings.baseSettings);
        }
      } else {
        final defaultSettings = NovenaAppSettings.defaults();
        state = defaultSettings;
        await _ref.read(baseSettingsProvider.notifier).updateSettings(defaultSettings.baseSettings);
      }
      
      // Sync PIN status with auth service
      await _refreshPinStatus();
      
      AppLogger.debug('Novena settings loaded successfully', 'NOVENA_SETTINGS');
    } catch (e, stackTrace) {
      AppLogger.error('Failed to load novena settings', e, stackTrace, 'NOVENA_SETTINGS');
      ErrorHandler.handleError(e, stackTrace: stackTrace, tag: 'NOVENA_SETTINGS');
      state = NovenaAppSettings.defaults();
    }
  }

  Future<void> _migrateFromLegacySettings(SharedPreferences prefs) async {
    try {
      // Look for old settings format
      final oldFontSize = prefs.getDouble('fontSize');
      final oldColorSchemeStyle = prefs.getInt('colorSchemeStyle');
      // Theme mode is handled separately by theme provider
      // final oldThemeMode = prefs.getInt('themeMode');
      
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
      
      AppLogger.debug('Settings migration completed successfully', 'NOVENA_SETTINGS');
    } catch (e, stackTrace) {
      AppLogger.error('Settings migration failed', e, stackTrace, 'NOVENA_SETTINGS');
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
      AppLogger.error('Failed to save novena settings', e, stackTrace, 'NOVENA_SETTINGS');
      ErrorHandler.handleError(e, stackTrace: stackTrace, tag: 'NOVENA_SETTINGS');
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
      AppLogger.error('Failed to refresh PIN status', e, stackTrace, 'NOVENA_SETTINGS');
    }
  }

  // Base settings methods (delegate to shared UI providers)
  Future<void> updateFontSize(double fontSize) async {
    await _ref.read(baseSettingsProvider.notifier).setFontSize(fontSize);
  }

  Future<void> updateTextScalingMode(TextScalingMode mode) async {
    await _ref.read(baseSettingsProvider.notifier).setTextScalingMode(mode);
  }

  Future<void> updateDefaultLanguage(AppLanguage language) async {
    await _ref.read(baseSettingsProvider.notifier).setDefaultLanguage(language);
  }

  Future<void> updateNotificationsEnabled(bool enabled) async {
    await _ref.read(baseSettingsProvider.notifier).setNotificationsEnabled(enabled);
  }

  Future<void> updateShowLiturgicalColors(bool show) async {
    await _ref.read(baseSettingsProvider.notifier).setShowLiturgicalColors(show);
  }

  Future<void> updateHapticFeedbackEnabled(bool enabled) async {
    await _ref.read(baseSettingsProvider.notifier).setHapticFeedbackEnabled(enabled);
  }

  Future<void> updateReduceMotion(bool reduce) async {
    await _ref.read(baseSettingsProvider.notifier).setReduceMotion(reduce);
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
      AppLogger.error('Failed to set PIN code via novena settings', e, stackTrace, 'NOVENA_SETTINGS');
      ErrorHandler.handleError(e, stackTrace: stackTrace, tag: 'NOVENA_SETTINGS');
      rethrow;
    }
  }

  /// Clear PIN code using AuthService
  Future<void> clearPinCode() async {
    try {
      await _authService.clearPinCode();
      state = state.copyWith(hasPinCode: false);
      await _saveSettings();
      AppLogger.debug('PIN code cleared via novena settings', 'NOVENA_SETTINGS');
    } catch (e, stackTrace) {
      AppLogger.error('Failed to clear PIN code via novena settings', e, stackTrace, 'NOVENA_SETTINGS');
      ErrorHandler.handleError(e, stackTrace: stackTrace, tag: 'NOVENA_SETTINGS');
      rethrow;
    }
  }

  /// Refresh PIN status (useful after external PIN changes)
  Future<void> refreshPinStatus() async {
    await _refreshPinStatus();
  }

  /// Map color scheme style to shared UI color intensity
  Future<void> setColorSchemeStyle(ColorSchemeStyle style) async {
    // Map the old color scheme style to the new shared UI color intensity
    final colorIntensity = style == ColorSchemeStyle.vibrant 
        ? ColorIntensity.vibrant 
        : ColorIntensity.muted;
    
    // Use the shared UI color intensity provider
    await _ref.read(colorIntensityProvider.notifier).setColorIntensity(colorIntensity);
  }
}

/// Provider for Novena app settings
final novenaAppSettingsProvider = StateNotifierProvider<NovenaAppSettingsNotifier, NovenaAppSettings>((ref) {
  final authService = ref.read(authServiceProvider);
  return NovenaAppSettingsNotifier(ref, authService);
});

/// Convenience providers for specific settings
final novenaFontSizeProvider = Provider<double>((ref) {
  return ref.watch(novenaAppSettingsProvider).fontSize;
});

final novenaPinCodeProvider = Provider<bool>((ref) {
  return ref.watch(novenaAppSettingsProvider).hasPinCode;
});

final novenaNotificationsEnabledProvider = Provider<bool>((ref) {
  return ref.watch(novenaAppSettingsProvider).novenaNotificationsEnabled;
});

final novenaDailyReminderTimeProvider = Provider<TimeOfDay>((ref) {
  return ref.watch(novenaAppSettingsProvider).dailyReminderTimeOfDay;
});

final novenaShowCompletionCelebrationsProvider = Provider<bool>((ref) {
  return ref.watch(novenaAppSettingsProvider).showCompletionCelebrations;
});

final novenaAllowMultipleNovenaProvider = Provider<bool>((ref) {
  return ref.watch(novenaAppSettingsProvider).allowMultipleNovenas;
});

/// Legacy provider for backward compatibility
final legacySettingsProvider = Provider<dynamic>((ref) {
  final novenaSettings = ref.watch(novenaAppSettingsProvider);
  
  // Create a legacy-compatible object
  return LegacySettingsModel(
    fontSize: novenaSettings.fontSize <= 2.0 
        ? novenaSettings.fontSize // If it's a scale factor
        : novenaSettings.fontSize / 18.0, // Convert points to scale factor
    hasPinCode: novenaSettings.hasPinCode,
    colorSchemeStyle: novenaSettings.showLiturgicalColors 
        ? ColorSchemeStyle.vibrant 
        : ColorSchemeStyle.muted,
  );
});

/// Legacy settings model for backward compatibility
class LegacySettingsModel {
  final double fontSize;
  final bool hasPinCode;
  final ColorSchemeStyle colorSchemeStyle;

  LegacySettingsModel({
    required this.fontSize,
    required this.hasPinCode,
    required this.colorSchemeStyle,
  });

  LegacySettingsModel copyWith({
    double? fontSize,
    bool? hasPinCode,
    ColorSchemeStyle? colorSchemeStyle,
  }) {
    return LegacySettingsModel(
      fontSize: fontSize ?? this.fontSize,
      hasPinCode: hasPinCode ?? this.hasPinCode,
      colorSchemeStyle: colorSchemeStyle ?? this.colorSchemeStyle,
    );
  }
}