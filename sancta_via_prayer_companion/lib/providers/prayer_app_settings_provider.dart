import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sancta_via_shared_ui/sancta_via_shared_ui.dart';

import '../models/prayer_app_settings.dart';
import '../widgets/enhanced_prayer_text.dart';

/// Provider for Prayer app specific settings
class PrayerAppSettingsNotifier extends StateNotifier<PrayerAppSettings> {
  static const String _storageKey = 'prayer_app_settings_unified';
  static const String _legacyStorageKey = 'prayer_preferences';
  static const String _migrationKey = 'prayer_settings_migrated_v1';

  final Ref _ref;

  PrayerAppSettingsNotifier(this._ref) : super(PrayerAppSettings.defaults()) {
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
        final settings = PrayerAppSettings.fromJson(settingsMap);

        if (mounted) {
          state = settings;
          await _ref
              .read(baseSettingsProvider.notifier)
              .updateSettings(settings.baseSettings);
        }
      } else {
        final defaultSettings = PrayerAppSettings.defaults();
        state = defaultSettings;
        await _ref
            .read(baseSettingsProvider.notifier)
            .updateSettings(defaultSettings.baseSettings);
      }
    } catch (e) {
      state = PrayerAppSettings.defaults();
    }
  }

  Future<void> _migrateFromLegacySettings(SharedPreferences prefs) async {
    try {
      final oldPrefsJson = prefs.getString(_legacyStorageKey);

      if (oldPrefsJson != null) {
        final oldPrefs = json.decode(oldPrefsJson) as Map<String, dynamic>;
        final migratedSettings = PrayerAppSettings.fromJson(oldPrefs);
        await _saveSettings(migratedSettings);
      }

      await prefs.setBool(_migrationKey, true);
      await prefs.remove(_legacyStorageKey);
    } catch (e) {
      // Continue with defaults if migration fails
    }
  }

  Future<void> _saveSettings([PrayerAppSettings? settings]) async {
    try {
      final settingsToSave = settings ?? state;
      final prefs = await SharedPreferences.getInstance();
      final settingsJson = json.encode(settingsToSave.toJson());
      await prefs.setString(_storageKey, settingsJson);
    } catch (e) {
      // Handle error
    }
  }

  void _syncBaseSettings(BaseSettingsModel newBaseSettings) {
    if (state.baseSettings != newBaseSettings) {
      state = state.updateBaseSettings(newBaseSettings);
      _saveSettings();
    }
  }

  // Base settings methods (delegate to base provider)
  Future<void> updateFontSize(double fontSize) async {
    await _ref.read(baseSettingsProvider.notifier).setFontSize(fontSize);
  }

  Future<void> updateDefaultLanguage(String language) async {
    AppLanguage appLanguage = AppLanguage.english;
    if (language == 'Latin') {
      appLanguage = AppLanguage.latin;
    } else if (language == 'Spanish') {
      appLanguage = AppLanguage.spanish;
    }
    await _ref
        .read(baseSettingsProvider.notifier)
        .setDefaultLanguage(appLanguage);
  }

  // Prayer-specific methods
  Future<void> toggleFavorite(String prayerId) async {
    if (state.isFavorite(prayerId)) {
      state = state.removeFavorite(prayerId);
    } else {
      state = state.addFavorite(prayerId);
    }
    await _saveSettings();
  }

  Future<void> addToRecent(String prayerId) async {
    state = state.addToRecent(prayerId);
    await _saveSettings();
  }

  Future<void> updateReadingMode(PrayerReadingMode readingMode) async {
    state = state.copyWith(readingMode: readingMode);
    await _saveSettings();
  }

  Future<void> updateVerseHighlighting(bool enabled) async {
    state = state.copyWith(verseHighlighting: enabled);
    await _saveSettings();
  }
}

/// Provider for Prayer app settings
final prayerAppSettingsProvider =
    StateNotifierProvider<PrayerAppSettingsNotifier, PrayerAppSettings>((ref) {
      return PrayerAppSettingsNotifier(ref);
    });

/// Convenience providers
final prayerFontSizeProvider = Provider<double>((ref) {
  return ref.watch(prayerAppSettingsProvider).fontSize;
});

final favoritePrayerIdsProvider = Provider<List<String>>((ref) {
  return ref.watch(prayerAppSettingsProvider).favoritePrayerIds;
});

final recentPrayerIdsProvider = Provider<List<String>>((ref) {
  return ref.watch(prayerAppSettingsProvider).recentPrayerIds;
});

final prayerReadingModeProvider = Provider<PrayerReadingMode>((ref) {
  return ref.watch(prayerAppSettingsProvider).readingMode;
});

final verseHighlightingProvider = Provider<bool>((ref) {
  return ref.watch(prayerAppSettingsProvider).verseHighlighting;
});
