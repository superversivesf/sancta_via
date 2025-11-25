import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sancta_via_shared_ui/sancta_via_shared_ui.dart';
import 'package:bible_data/bible_data.dart';

import '../models/bible_app_settings.dart';

/// Conditional logging utility for development
void _logDebug(String message, [String? tag]) {
  if (kDebugMode) {
    final timestamp = DateTime.now().toIso8601String().substring(11, 19);
    debugPrint('[$timestamp] ${tag != null ? '[$tag] ' : ''}$message');
  }
}

/// Provider for Bible app specific settings
class BibleAppSettingsNotifier extends StateNotifier<BibleAppSettings> {
  static const String _storageKey = 'bible_app_settings';
  static const String _legacyMigrationKey = 'bible_settings_migrated_v1';

  final Ref _ref;

  BibleAppSettingsNotifier(this._ref) : super(BibleAppSettings.defaults()) {
    _loadSettings();

    // Listen to base settings changes and sync them
    _ref.listen(baseSettingsProvider, (previous, next) {
      if (previous != next) {
        _syncBaseSettings(next);
      }
    });
  }

  /// Load settings from persistent storage with migration support
  Future<void> _loadSettings() async {
    try {
      _logDebug('Loading Bible app settings...');
      final prefs = await SharedPreferences.getInstance();

      // Check if we need to migrate from old format
      final needsMigration = prefs.getBool(_legacyMigrationKey) != true;

      if (needsMigration) {
        await _migrateFromLegacySettings(prefs);
      }

      // Load unified settings
      final settingsJson = prefs.getString(_storageKey);

      if (settingsJson != null) {
        final settingsMap = json.decode(settingsJson) as Map<String, dynamic>;
        final settings = BibleAppSettings.fromJson(settingsMap);

        if (mounted) {
          state = settings;

          // Also sync the base settings provider
          await _ref
              .read(baseSettingsProvider.notifier)
              .updateSettings(settings.baseSettings);
        }

        _logDebug('Settings loaded successfully');
      } else {
        // No settings found, use defaults and sync base settings
        final defaultSettings = BibleAppSettings.defaults();
        state = defaultSettings;
        await _ref
            .read(baseSettingsProvider.notifier)
            .updateSettings(defaultSettings.baseSettings);

        _logDebug('Using default settings');
      }
    } catch (e) {
      _logDebug('Error loading settings: $e');
      // If there's an error, use defaults
      state = BibleAppSettings.defaults();
    }
  }

  /// Migrate from old individual preference keys
  Future<void> _migrateFromLegacySettings(SharedPreferences prefs) async {
    try {
      _logDebug('Migrating from legacy settings...');

      // Load old individual settings
      final oldFontSize = prefs.getDouble('fontSize') ?? 18.0;
      final oldTranslationId =
          prefs.getString('selectedBibleTranslation') ?? 'cpdv';

      _logDebug(
        'Found legacy settings - fontSize: $oldFontSize, translation: $oldTranslationId',
      );

      // Create new settings with migrated values
      final translation = BibleTranslation.fromId(oldTranslationId);
      final migratedSettings = BibleAppSettings(
        baseSettings: BaseSettingsModel(
          fontSize: oldFontSize.clamp(12.0, 32.0), // Ensure within new range
          // Other base settings use defaults
        ),
        selectedBibleTranslation: translation,
      );

      // Save in new format
      await _saveSettings(migratedSettings);

      // Mark migration as complete
      await prefs.setBool(_legacyMigrationKey, true);

      // Clean up old keys
      await prefs.remove('fontSize');
      await prefs.remove('selectedBibleTranslation');

      _logDebug('Legacy settings migration completed');
    } catch (e) {
      _logDebug('Error during migration: $e');
      // Continue with defaults if migration fails
    }
  }

  /// Save settings to persistent storage
  Future<void> _saveSettings([BibleAppSettings? settings]) async {
    try {
      final settingsToSave = settings ?? state;
      final prefs = await SharedPreferences.getInstance();
      final settingsJson = json.encode(settingsToSave.toJson());
      await prefs.setString(_storageKey, settingsJson);

      _logDebug('Settings saved successfully');
    } catch (e) {
      _logDebug('Error saving settings: $e');
    }
  }

  /// Sync base settings changes into our state
  void _syncBaseSettings(BaseSettingsModel newBaseSettings) {
    if (state.baseSettings != newBaseSettings) {
      state = state.updateBaseSettings(newBaseSettings);
      _saveSettings();
    }
  }

  /// Update Bible translation
  Future<void> setBibleTranslation(BibleTranslation translation) async {
    state = state.copyWith(selectedBibleTranslation: translation);
    await _saveSettings();
    _logDebug('Bible translation updated to: ${translation.name}');
  }

  /// Update verse numbers visibility
  Future<void> setShowVerseNumbers(bool show) async {
    state = state.copyWith(showVerseNumbers: show);
    await _saveSettings();
    _logDebug('Show verse numbers updated to: $show');
  }

  /// Update current verse highlighting
  Future<void> setHighlightCurrentVerse(bool highlight) async {
    state = state.copyWith(highlightCurrentVerse: highlight);
    await _saveSettings();
    _logDebug('Highlight current verse updated to: $highlight');
  }

  /// Update daily reading notifications
  Future<void> setDailyReadingNotificationsEnabled(bool enabled) async {
    state = state.copyWith(dailyReadingNotificationsEnabled: enabled);
    await _saveSettings();
    _logDebug('Daily reading notifications updated to: $enabled');
  }

  /// Update font size (delegates to base settings)
  Future<void> setFontSize(double fontSize) async {
    // Validate font size range
    final clampedSize = fontSize.clamp(12.0, 32.0);
    if (clampedSize != fontSize) {
      _logDebug('Font size $fontSize clamped to $clampedSize');
    }
    await _ref.read(baseSettingsProvider.notifier).setFontSize(clampedSize);
    // Base settings listener will update our state automatically
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
    await _ref
        .read(baseSettingsProvider.notifier)
        .setNotificationsEnabled(enabled);
  }

  /// Reset all settings to defaults
  Future<void> resetToDefaults() async {
    _logDebug('Resetting settings to defaults');
    final defaultSettings = BibleAppSettings.defaults();
    state = defaultSettings;
    await _saveSettings();

    // Also reset base settings
    await _ref
        .read(baseSettingsProvider.notifier)
        .updateSettings(defaultSettings.baseSettings);
  }

  /// Export settings for backup
  Map<String, dynamic> exportSettings() {
    return state.toJson();
  }

  /// Import settings from backup
  Future<void> importSettings(Map<String, dynamic> settingsJson) async {
    try {
      final importedSettings = BibleAppSettings.fromJson(settingsJson);
      state = importedSettings;
      await _saveSettings();

      // Also update base settings
      await _ref
          .read(baseSettingsProvider.notifier)
          .updateSettings(importedSettings.baseSettings);

      _logDebug('Settings imported successfully');
    } catch (e) {
      _logDebug('Error importing settings: $e');
      rethrow;
    }
  }
}

/// Provider for Bible app settings
final bibleAppSettingsProvider =
    StateNotifierProvider<BibleAppSettingsNotifier, BibleAppSettings>((ref) {
      return BibleAppSettingsNotifier(ref);
    });

/// Convenience providers for backward compatibility and easy access

/// Provider for font size - backward compatibility
final fontSizeProvider = Provider<double>((ref) {
  return ref.watch(bibleAppSettingsProvider).fontSize;
});

/// Provider for Bible translation - backward compatibility
final appSelectedBibleTranslationProvider = Provider<BibleTranslation>((ref) {
  return ref.watch(bibleAppSettingsProvider).selectedBibleTranslation;
});

/// Provider for effective text scale factor
final effectiveBibleTextScaleProvider = Provider<double>((ref) {
  return ref.watch(bibleAppSettingsProvider).effectiveTextScaleFactor;
});

/// Provider for verse numbers visibility
final showVerseNumbersProvider = Provider<bool>((ref) {
  return ref.watch(bibleAppSettingsProvider).showVerseNumbers;
});

/// Provider for current verse highlighting
final highlightCurrentVerseProvider = Provider<bool>((ref) {
  return ref.watch(bibleAppSettingsProvider).highlightCurrentVerse;
});

/// Provider for default language - convenience access
final bibleDefaultLanguageProvider = Provider<AppLanguage>((ref) {
  return ref.watch(bibleAppSettingsProvider).defaultLanguage;
});

/// Provider for notifications enabled - convenience access
final bibleNotificationsEnabledProvider = Provider<bool>((ref) {
  return ref.watch(bibleAppSettingsProvider).notificationsEnabled;
});

/// Provider for daily reading notifications
final dailyReadingNotificationsEnabledProvider = Provider<bool>((ref) {
  return ref.watch(bibleAppSettingsProvider).dailyReadingNotificationsEnabled;
});
