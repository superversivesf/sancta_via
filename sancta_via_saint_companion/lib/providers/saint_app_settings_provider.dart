import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/saint_app_settings.dart';
import '../utils/logger.dart';

/// Notifier for Saint app specific settings (favorites + recents),
/// persisted to SharedPreferences.
class SaintAppSettingsNotifier extends StateNotifier<SaintAppSettings> {
  static const String storageKey = 'saint_app_settings';

  SaintAppSettingsNotifier() : super(SaintAppSettings.defaults()) {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final settingsJson = prefs.getString(storageKey);

      if (settingsJson != null) {
        final settingsMap = json.decode(settingsJson) as Map<String, dynamic>;
        final settings = SaintAppSettings.fromJson(settingsMap);

        if (mounted) {
          state = settings;
        }
      } else {
        state = SaintAppSettings.defaults();
      }
    } catch (e) {
      AppLogger.error('Failed to load saint settings', e, null, 'SETTINGS');
      // Continue with defaults — never crash the app on a bad settings store.
      if (mounted) {
        state = SaintAppSettings.defaults();
      }
    }
  }

  Future<void> _saveSettings([SaintAppSettings? settings]) async {
    try {
      final settingsToSave = settings ?? state;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(storageKey, json.encode(settingsToSave.toJson()));
    } catch (e) {
      AppLogger.error('Failed to save saint settings', e, null, 'SETTINGS');
    }
  }

  /// Add or remove a saint from favorites, persisting the change
  Future<void> toggleFavorite(String slug) async {
    if (state.isFavorite(slug)) {
      state = state.removeFavorite(slug);
    } else {
      state = state.addFavorite(slug);
    }
    await _saveSettings();
  }

  /// Record a saint as recently viewed (most-recent-first, dedupe, cap 50)
  Future<void> addRecent(String slug) async {
    state = state.addToRecent(slug);
    await _saveSettings();
  }

  /// Whether a saint is favorited
  bool isFavorite(String slug) => state.isFavorite(slug);
}

/// Provider for Saint app settings
final saintAppSettingsProvider =
    StateNotifierProvider<SaintAppSettingsNotifier, SaintAppSettings>((ref) {
      return SaintAppSettingsNotifier();
    });
