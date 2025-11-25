import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/base_settings_model.dart';

/// Provider for managing base settings across all Sancta Via apps
class BaseSettingsNotifier extends StateNotifier<BaseSettingsModel> {
  static const String _storageKey = 'sancta_via_base_settings';

  BaseSettingsNotifier() : super(BaseSettingsModel.defaults()) {
    _loadSettings();
  }

  /// Load settings from persistent storage
  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final settingsJson = prefs.getString(_storageKey);

      if (settingsJson != null) {
        final settingsMap = json.decode(settingsJson) as Map<String, dynamic>;
        final settings = BaseSettingsModel.fromJson(settingsMap);
        if (mounted) {
          state = settings;
        }
      }
    } catch (e) {
      // If loading fails, keep default settings
      // Log error in production apps
    }
  }

  /// Save settings to persistent storage
  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final settingsJson = json.encode(state.toJson());
      await prefs.setString(_storageKey, settingsJson);
    } catch (e) {
      // Handle error in production apps
    }
  }

  /// Update font size
  Future<void> setFontSize(double fontSize) async {
    // Clamp to reasonable bounds
    final clampedSize = fontSize.clamp(12.0, 32.0);
    state = state.copyWith(fontSize: clampedSize);
    await _saveSettings();
  }

  /// Update text scaling mode
  Future<void> setTextScalingMode(TextScalingMode mode) async {
    state = state.copyWith(textScalingMode: mode);
    await _saveSettings();
  }

  /// Update default language
  Future<void> setDefaultLanguage(AppLanguage language) async {
    state = state.copyWith(defaultLanguage: language);
    await _saveSettings();
  }

  /// Update notifications enabled
  Future<void> setNotificationsEnabled(bool enabled) async {
    state = state.copyWith(notificationsEnabled: enabled);
    await _saveSettings();
  }

  /// Update liturgical colors visibility
  Future<void> setShowLiturgicalColors(bool show) async {
    state = state.copyWith(showLiturgicalColors: show);
    await _saveSettings();
  }

  /// Update haptic feedback
  Future<void> setHapticFeedbackEnabled(bool enabled) async {
    state = state.copyWith(hapticFeedbackEnabled: enabled);
    await _saveSettings();
  }

  /// Update reduce motion setting
  Future<void> setReduceMotion(bool reduce) async {
    state = state.copyWith(reduceMotion: reduce);
    await _saveSettings();
  }

  /// Reset all settings to defaults
  Future<void> resetToDefaults() async {
    state = BaseSettingsModel.defaults();
    await _saveSettings();
  }

  /// Bulk update settings
  Future<void> updateSettings(BaseSettingsModel newSettings) async {
    state = newSettings;
    await _saveSettings();
  }
}

/// Provider for base settings
final baseSettingsProvider =
    StateNotifierProvider<BaseSettingsNotifier, BaseSettingsModel>((ref) {
  return BaseSettingsNotifier();
});

/// Convenience providers for specific settings
final fontSizeProvider = Provider<double>((ref) {
  return ref.watch(baseSettingsProvider).fontSize;
});

final textScalingModeProvider = Provider<TextScalingMode>((ref) {
  return ref.watch(baseSettingsProvider).textScalingMode;
});

final defaultLanguageProvider = Provider<AppLanguage>((ref) {
  return ref.watch(baseSettingsProvider).defaultLanguage;
});

final notificationsEnabledProvider = Provider<bool>((ref) {
  return ref.watch(baseSettingsProvider).notificationsEnabled;
});

final showLiturgicalColorsProvider = Provider<bool>((ref) {
  return ref.watch(baseSettingsProvider).showLiturgicalColors;
});

final hapticFeedbackEnabledProvider = Provider<bool>((ref) {
  return ref.watch(baseSettingsProvider).hapticFeedbackEnabled;
});

final reduceMotionProvider = Provider<bool>((ref) {
  return ref.watch(baseSettingsProvider).reduceMotion;
});

/// Combined text scale factor provider
final effectiveTextScaleProvider = Provider<double>((ref) {
  return ref.watch(baseSettingsProvider).effectiveTextScaleFactor;
});
