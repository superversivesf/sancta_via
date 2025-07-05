import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bible_data_riverpod/bible_data_riverpod.dart';

import '../models/app_settings.dart';

/// Debug logging utility
void debugLog(String message, [String? tag]) {
  final timestamp = DateTime.now().toIso8601String();
  print('[$timestamp] ${tag != null ? '[$tag] ' : ''}$message');
}

/// Provider for app settings
final appSettingsProvider = StateNotifierProvider<AppSettingsNotifier, AppSettings>((ref) {
  return AppSettingsNotifier();
});

/// Notifier for managing app settings
class AppSettingsNotifier extends StateNotifier<AppSettings> {
  AppSettingsNotifier() : super(AppSettings.defaults()) {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      debugLog('Loading app settings...', 'SETTINGS');
      final prefs = await SharedPreferences.getInstance();
      
      final fontSize = prefs.getDouble('fontSize') ?? 18.0;
      final selectedTranslationId = prefs.getString('selectedBibleTranslation') ?? 'cpdv';
      
      debugLog('Loaded fontSize: $fontSize, translation: $selectedTranslationId', 'SETTINGS');
      
      final translation = BibleTranslation.fromId(selectedTranslationId);
      debugLog('Resolved translation: ${translation.name} (${translation.id})', 'SETTINGS');
      
      state = AppSettings(
        fontSize: fontSize,
        selectedBibleTranslation: translation,
      );
      
      debugLog('App settings loaded successfully', 'SETTINGS');
    } catch (e) {
      debugLog('Error loading settings: $e', 'SETTINGS');
      // If there's an error loading settings, stick with defaults
      state = AppSettings.defaults();
      debugLog('Using default settings', 'SETTINGS');
    }
  }

  Future<void> setFontSize(double value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('fontSize', value);
      state = state.copyWith(fontSize: value);
    } catch (e) {
      // Handle error silently
    }
  }

  Future<void> setBibleTranslation(BibleTranslation translation) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('selectedBibleTranslation', translation.id);
      state = state.copyWith(selectedBibleTranslation: translation);
    } catch (e) {
      // Handle error silently
    }
  }
}

/// Provider for font size
final fontSizeProvider = Provider<double>((ref) {
  final settings = ref.watch(appSettingsProvider);
  return settings.fontSize;
});

/// Provider for app's selected bible translation
final appSelectedBibleTranslationProvider = Provider<BibleTranslation>((ref) {
  final settings = ref.watch(appSettingsProvider);
  return settings.selectedBibleTranslation;
});
