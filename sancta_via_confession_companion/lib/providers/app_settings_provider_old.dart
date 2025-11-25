import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../config/constants.dart';

// App settings model
class AppSettings {
  final bool darkMode;
  final double textScale;
  final String defaultLanguage;
  final bool notificationsEnabled;

  AppSettings({
    this.darkMode = false,
    this.textScale = 1.0,
    this.defaultLanguage = 'English',
    this.notificationsEnabled = false,
  });

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      darkMode: json['darkMode'] ?? false,
      textScale: json['textScale'] ?? 1.0,
      defaultLanguage: json['defaultLanguage'] ?? 'English',
      notificationsEnabled: json['notificationsEnabled'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'darkMode': darkMode,
      'textScale': textScale,
      'defaultLanguage': defaultLanguage,
      'notificationsEnabled': notificationsEnabled,
    };
  }

  AppSettings copyWith({
    bool? darkMode,
    double? textScale,
    String? defaultLanguage,
    bool? notificationsEnabled,
  }) {
    return AppSettings(
      darkMode: darkMode ?? this.darkMode,
      textScale: textScale ?? this.textScale,
      defaultLanguage: defaultLanguage ?? this.defaultLanguage,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
    );
  }
}

// Settings provider
final appSettingsProvider =
    StateNotifierProvider<AppSettingsNotifier, AppSettings>((ref) {
      return AppSettingsNotifier();
    });

class AppSettingsNotifier extends StateNotifier<AppSettings> {
  AppSettingsNotifier() : super(AppSettings()) {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final settingsJson = prefs.getString(AppConstants.settingsKey);

      if (settingsJson != null) {
        final settings = AppSettings.fromJson(json.decode(settingsJson));
        if (mounted) {
          state = settings;
        }
      }
    } catch (e) {
      // Handle error, keep default settings
    }
  }

  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        AppConstants.settingsKey,
        json.encode(state.toJson()),
      );
    } catch (e) {
      // Handle error
    }
  }

  Future<void> updateDarkMode(bool darkMode) async {
    state = state.copyWith(darkMode: darkMode);
    await _saveSettings();
  }

  Future<void> updateTextScale(double textScale) async {
    state = state.copyWith(textScale: textScale);
    await _saveSettings();
  }

  Future<void> updateDefaultLanguage(String language) async {
    state = state.copyWith(defaultLanguage: language);
    await _saveSettings();
  }

  Future<void> updateNotifications(bool enabled) async {
    state = state.copyWith(notificationsEnabled: enabled);
    await _saveSettings();
  }
}
