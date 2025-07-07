import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sancta_via_shared_ui/sancta_via_shared_ui.dart';

import '../models/confession_app_settings.dart';
import '../features/examination/models/user_preferences_model.dart';
import '../config/constants.dart';

/// Debug logging utility
void debugLog(String message, [String? tag]) {
  final timestamp = DateTime.now().toIso8601String();
  // ignore: avoid_print
  print('[$timestamp] ${tag != null ? '[$tag] ' : ''}$message');
}

/// Provider for Confession app specific settings
class ConfessionAppSettingsNotifier extends StateNotifier<ConfessionAppSettings> {
  static const String _unifiedStorageKey = 'confession_app_settings_unified';
  static const String _migrationKey = 'confession_settings_migrated_v2';

  final Ref _ref;

  ConfessionAppSettingsNotifier(this._ref) : super(ConfessionAppSettings.defaults()) {
    _loadSettings();
    
    // Listen to base settings changes and sync them
    _ref.listen(baseSettingsProvider, (previous, next) {
      if (previous != next) {
        _syncBaseSettings(next);
      }
    });
  }

  /// Load settings from persistent storage with comprehensive migration support
  Future<void> _loadSettings() async {
    try {
      debugLog('Loading Confession app settings...', 'CONFESSION_SETTINGS');
      final prefs = await SharedPreferences.getInstance();
      
      // Check if we need to migrate from old format
      final needsMigration = prefs.getBool(_migrationKey) != true;
      
      if (needsMigration) {
        await _migrateFromLegacySettings(prefs);
      }
      
      // Load unified settings
      final settingsJson = prefs.getString(_unifiedStorageKey);
      
      if (settingsJson != null) {
        final settingsMap = json.decode(settingsJson) as Map<String, dynamic>;
        final settings = ConfessionAppSettings.fromJson(settingsMap);
        
        if (mounted) {
          state = settings;
          
          // Also sync the base settings provider
          await _ref.read(baseSettingsProvider.notifier)
              .updateSettings(settings.baseSettings);
        }
        
        debugLog('Confession app settings loaded successfully', 'CONFESSION_SETTINGS');
      } else {
        // No settings found, use defaults and sync base settings
        final defaultSettings = ConfessionAppSettings.defaults();
        state = defaultSettings;
        await _ref.read(baseSettingsProvider.notifier)
            .updateSettings(defaultSettings.baseSettings);
        
        debugLog('Using default Confession app settings', 'CONFESSION_SETTINGS');
      }
    } catch (e) {
      debugLog('Error loading Confession app settings: $e', 'CONFESSION_SETTINGS');
      // If there's an error, use defaults
      state = ConfessionAppSettings.defaults();
    }
  }

  /// Migrate from old format with multiple storage keys and different structure
  Future<void> _migrateFromLegacySettings(SharedPreferences prefs) async {
    try {
      debugLog('Migrating from legacy Confession app settings...', 'MIGRATION');
      
      // Load old app settings (JSON format)
      Map<String, dynamic> oldAppSettings = {};
      final oldSettingsJson = prefs.getString(AppConstants.settingsKey);
      if (oldSettingsJson != null) {
        oldAppSettings = json.decode(oldSettingsJson) as Map<String, dynamic>;
        debugLog('Found legacy app settings: $oldAppSettings', 'MIGRATION');
      }
      
      // Load old examination preferences (separate storage)
      Map<String, dynamic> oldExaminationPrefs = {};
      final oldPrefsJson = prefs.getString(AppConstants.examinationPreferencesKey);
      if (oldPrefsJson != null) {
        oldExaminationPrefs = json.decode(oldPrefsJson) as Map<String, dynamic>;
        debugLog('Found legacy examination preferences: $oldExaminationPrefs', 'MIGRATION');
      }
      
      // Combine old settings for migration
      final combinedOldSettings = <String, dynamic>{
        ...oldAppSettings,
        ...oldExaminationPrefs,
      };
      
      if (combinedOldSettings.isNotEmpty) {
        // Create new settings with migrated values
        final migratedSettings = ConfessionAppSettings.fromJson(combinedOldSettings);
        
        // Handle theme migration: if old darkMode was true, set theme to dark
        if (oldAppSettings['darkMode'] == true) {
          debugLog('Migrating darkMode=true to dark theme', 'MIGRATION');
          await _ref.read(themeModeProvider.notifier).setThemeMode(ThemeMode.dark);
        }
        
        // Save in new unified format
        await _saveSettings(migratedSettings);
        
        debugLog('Legacy settings migration completed', 'MIGRATION');
      }
      
      // Mark migration as complete
      await prefs.setBool(_migrationKey, true);
      
      // Clean up old keys
      await prefs.remove(AppConstants.settingsKey);
      await prefs.remove(AppConstants.examinationPreferencesKey);
      
    } catch (e) {
      debugLog('Error during migration: $e', 'MIGRATION');
      // Continue with defaults if migration fails
    }
  }

  /// Save settings to persistent storage
  Future<void> _saveSettings([ConfessionAppSettings? settings]) async {
    try {
      final settingsToSave = settings ?? state;
      final prefs = await SharedPreferences.getInstance();
      final settingsJson = json.encode(settingsToSave.toJson());
      await prefs.setString(_unifiedStorageKey, settingsJson);
      
      debugLog('Confession app settings saved successfully', 'CONFESSION_SETTINGS');
    } catch (e) {
      debugLog('Error saving Confession app settings: $e', 'CONFESSION_SETTINGS');
    }
  }

  /// Sync base settings changes into our state
  void _syncBaseSettings(BaseSettingsModel newBaseSettings) {
    if (state.baseSettings != newBaseSettings) {
      state = state.updateBaseSettings(newBaseSettings);
      _saveSettings();
    }
  }

  // ===========================================
  // BASE SETTINGS METHODS (delegate to base provider)
  // ===========================================

  /// Update font size (delegates to base settings)
  Future<void> setFontSize(double fontSize) async {
    await _ref.read(baseSettingsProvider.notifier).setFontSize(fontSize);
  }

  /// Update text scaling mode (delegates to base settings)
  Future<void> setTextScalingMode(TextScalingMode mode) async {
    await _ref.read(baseSettingsProvider.notifier).setTextScalingMode(mode);
  }

  /// Update default language (delegates to base settings)
  Future<void> setDefaultLanguage(AppLanguage language) async {
    await _ref.read(baseSettingsProvider.notifier).setDefaultLanguage(language);
  }

  /// Update notifications (delegates to base settings)
  Future<void> setNotificationsEnabled(bool enabled) async {
    await _ref.read(baseSettingsProvider.notifier).setNotificationsEnabled(enabled);
  }

  /// Update text scale for backward compatibility with existing TextScaling class
  Future<void> updateTextScale(double textScale) async {
    // Convert text scale multiplier to font size (base 18pt)
    final fontSize = (textScale * 18.0).clamp(12.0, 32.0);
    await setFontSize(fontSize);
  }

  // ===========================================
  // EXAMINATION-SPECIFIC SETTINGS METHODS
  // ===========================================

  /// Add favorite examination
  Future<void> addFavoriteExamination(String examinationId) async {
    final currentFavorites = List<String>.from(state.favoriteExaminationIds);
    if (!currentFavorites.contains(examinationId)) {
      currentFavorites.add(examinationId);
      final newPreferences = state.examinationPreferences.copyWith(
        favoriteExaminationIds: currentFavorites,
      );
      state = state.updateExaminationPreferences(newPreferences);
      await _saveSettings();
      debugLog('Added favorite examination: $examinationId', 'CONFESSION_SETTINGS');
    }
  }

  /// Remove favorite examination
  Future<void> removeFavoriteExamination(String examinationId) async {
    final currentFavorites = List<String>.from(state.favoriteExaminationIds);
    if (currentFavorites.remove(examinationId)) {
      final newPreferences = state.examinationPreferences.copyWith(
        favoriteExaminationIds: currentFavorites,
      );
      state = state.updateExaminationPreferences(newPreferences);
      await _saveSettings();
      debugLog('Removed favorite examination: $examinationId', 'CONFESSION_SETTINGS');
    }
  }

  /// Set default examination
  Future<void> setDefaultExamination(String? examinationId) async {
    final newPreferences = state.examinationPreferences.copyWith(
      defaultExaminationId: examinationId,
    );
    state = state.updateExaminationPreferences(newPreferences);
    await _saveSettings();
    debugLog('Set default examination: $examinationId', 'CONFESSION_SETTINGS');
  }

  // ===========================================
  // APP-SPECIFIC SETTINGS METHODS  
  // ===========================================

  /// Update progress visibility
  Future<void> setShowProgress(bool show) async {
    state = state.copyWith(showProgress: show);
    await _saveSettings();
    debugLog('Show progress updated to: $show', 'CONFESSION_SETTINGS');
  }

  /// Update guided mode
  Future<void> setUseGuidedMode(bool useGuided) async {
    state = state.copyWith(useGuidedMode: useGuided);
    await _saveSettings();
    debugLog('Use guided mode updated to: $useGuided', 'CONFESSION_SETTINGS');
  }

  /// Update examination history saving
  Future<void> setSaveExaminationHistory(bool save) async {
    state = state.copyWith(saveExaminationHistory: save);
    await _saveSettings();
    debugLog('Save examination history updated to: $save', 'CONFESSION_SETTINGS');
  }

  /// Update history retention period
  Future<void> setHistoryRetentionDays(int days) async {
    state = state.copyWith(historyRetentionDays: days.clamp(1, 365));
    await _saveSettings();
    debugLog('History retention days updated to: $days', 'CONFESSION_SETTINGS');
  }
}

/// Provider for Confession app settings
final confessionAppSettingsProvider = StateNotifierProvider<ConfessionAppSettingsNotifier, ConfessionAppSettings>((ref) {
  return ConfessionAppSettingsNotifier(ref);
});

/// Convenience providers for backward compatibility and easy access

/// Provider for text scale factor - backward compatibility with TextScaling class
final textScaleFactorProvider = Provider<double>((ref) {
  return ref.watch(confessionAppSettingsProvider).textScale;
});

/// Provider for default language - convenience access
final confessionDefaultLanguageProvider = Provider<AppLanguage>((ref) {
  return ref.watch(confessionAppSettingsProvider).defaultLanguage;
});

/// Provider for notifications enabled - convenience access  
final confessionNotificationsEnabledProvider = Provider<bool>((ref) {
  return ref.watch(confessionAppSettingsProvider).notificationsEnabled;
});

/// Provider for font size - convenience access
final confessionFontSizeProvider = Provider<double>((ref) {
  return ref.watch(confessionAppSettingsProvider).fontSize;
});

/// Provider for effective text scale factor
final confessionEffectiveTextScaleProvider = Provider<double>((ref) {
  return ref.watch(confessionAppSettingsProvider).effectiveTextScaleFactor;
});

/// Examination-specific providers

/// Provider for favorite examinations
final favoriteExaminationsProvider = Provider<List<String>>((ref) {
  return ref.watch(confessionAppSettingsProvider).favoriteExaminationIds;
});

/// Provider for default examination
final defaultExaminationProvider = Provider<String?>((ref) {
  return ref.watch(confessionAppSettingsProvider).defaultExaminationId;
});

/// Provider for examination preferences
final examinationPreferencesProvider = Provider<ExaminationPreferences>((ref) {
  return ref.watch(confessionAppSettingsProvider).examinationPreferences;
});

/// App-specific feature providers

/// Provider for progress visibility
final showProgressProvider = Provider<bool>((ref) {
  return ref.watch(confessionAppSettingsProvider).showProgress;
});

/// Provider for guided mode
final useGuidedModeProvider = Provider<bool>((ref) {
  return ref.watch(confessionAppSettingsProvider).useGuidedMode;
});

/// Provider for examination history saving
final saveExaminationHistoryProvider = Provider<bool>((ref) {
  return ref.watch(confessionAppSettingsProvider).saveExaminationHistory;
});

/// Provider for history retention period
final historyRetentionDaysProvider = Provider<int>((ref) {
  return ref.watch(confessionAppSettingsProvider).historyRetentionDays;
});

// Export the model class for use in other files
//export '../models/confession_app_settings.dart';
