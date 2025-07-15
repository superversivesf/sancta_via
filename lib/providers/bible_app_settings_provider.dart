import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sancta_via_shared_ui/sancta_via_shared_ui.dart';
import 'package:bible_data/bible_data.dart';

import '../models/bible_app_settings.dart';

/// Debug logging utility
void debugLog(String message, [String? tag]) {
  final timestamp = DateTime.now().toIso8601String();
  // ignore: avoid_print
  print('[$timestamp] ${tag != null ? '[$tag] ' : ''}$message');
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
      debugLog('Loading Bible app settings...', 'BIBLE_SETTINGS');
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
          await _ref.read(baseSettingsProvider.notifier)
              .updateSettings(settings.baseSettings);
        }
        
        debugLog('Bible app settings loaded successfully', 'BIBLE_SETTINGS');
      } else {
        // No settings found, use defaults and sync base settings
        final defaultSettings = BibleAppSettings.defaults();
        state = defaultSettings;
        await _ref.read(baseSettingsProvider.notifier)
            .updateSettings(defaultSettings.baseSettings);
        
        debugLog('Using default Bible app settings', 'BIBLE_SETTINGS');
      }
    } catch (e) {
      debugLog('Error loading Bible app settings: $e', 'BIBLE_SETTINGS');
      // If there's an error, use defaults
      state = BibleAppSettings.defaults();
    }
  }

  /// Migrate from old individual preference keys
  Future<void> _migrateFromLegacySettings(SharedPreferences prefs) async {
    try {
      debugLog('Migrating from legacy Bible app settings...', 'MIGRATION');
      
      // Load old individual settings
      final oldFontSize = prefs.getDouble('fontSize') ?? 18.0;
      final oldTranslationId = prefs.getString('selectedBibleTranslation') ?? 'cpdv';
      
      debugLog('Found legacy settings - fontSize: $oldFontSize, translation: $oldTranslationId', 'MIGRATION');
      
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
      
      debugLog('Legacy settings migration completed', 'MIGRATION');
    } catch (e) {
      debugLog('Error during migration: $e', 'MIGRATION');
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
      
      debugLog('Bible app settings saved successfully', 'BIBLE_SETTINGS');
    } catch (e) {
      debugLog('Error saving Bible app settings: $e', 'BIBLE_SETTINGS');
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
    debugLog('Bible translation updated to: ${translation.name}', 'BIBLE_SETTINGS');
  }

  /// Update verse numbers visibility
  Future<void> setShowVerseNumbers(bool show) async {
    state = state.copyWith(showVerseNumbers: show);
    await _saveSettings();
    debugLog('Show verse numbers updated to: $show', 'BIBLE_SETTINGS');
  }

  /// Update current verse highlighting
  Future<void> setHighlightCurrentVerse(bool highlight) async {
    state = state.copyWith(highlightCurrentVerse: highlight);
    await _saveSettings();
    debugLog('Highlight current verse updated to: $highlight', 'BIBLE_SETTINGS');
  }

  /// Update active reading plan
  Future<void> setActiveReadingPlan(String? plan) async {
    state = state.copyWith(activeReadingPlan: plan);
    await _saveSettings();
    debugLog('Active reading plan updated to: $plan', 'BIBLE_SETTINGS');
  }

  /// Update daily reading notifications
  Future<void> setDailyReadingNotificationsEnabled(bool enabled) async {
    state = state.copyWith(dailyReadingNotificationsEnabled: enabled);
    await _saveSettings();
    debugLog('Daily reading notifications updated to: $enabled', 'BIBLE_SETTINGS');
  }

  /// Update font size (delegates to base settings)
  Future<void> setFontSize(double fontSize) async {
    await _ref.read(baseSettingsProvider.notifier).setFontSize(fontSize);
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
    await _ref.read(baseSettingsProvider.notifier).setNotificationsEnabled(enabled);
  }
}

/// Provider for Bible app settings
final bibleAppSettingsProvider = StateNotifierProvider<BibleAppSettingsNotifier, BibleAppSettings>((ref) {
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

/// Provider for active reading plan
final activeReadingPlanProvider = Provider<String?>((ref) {
  return ref.watch(bibleAppSettingsProvider).activeReadingPlan;
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
