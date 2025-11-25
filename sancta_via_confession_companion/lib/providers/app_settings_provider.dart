// MIGRATION NOTICE: This file now uses the new unified settings system
// All functionality has been preserved for backward compatibility
// The old implementation has been backed up as app_settings_provider_old.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sancta_via_shared_ui/sancta_via_shared_ui.dart';

// Import the new unified settings system
import 'confession_app_settings_provider.dart';
import '../models/confession_app_settings.dart';

// NEW UNIFIED SYSTEM: Re-export new providers for direct use
// New code should use these for full functionality
export 'confession_app_settings_provider.dart';

/// DEPRECATED: Old AppSettings model - maintained for backward compatibility
///
/// Use ConfessionAppSettings from confession_app_settings_provider.dart instead.
@Deprecated(
  'Use ConfessionAppSettings with the unified settings system instead',
)
class AppSettings {
  final bool darkMode; // DEPRECATED: Use theme providers instead
  final double textScale; // DEPRECATED: Use fontSize in unified system
  final String
  defaultLanguage; // DEPRECATED: Use AppLanguage enum in unified system
  final bool notificationsEnabled;

  AppSettings({
    this.darkMode = false,
    this.textScale = 1.0,
    this.defaultLanguage = 'English',
    this.notificationsEnabled = false,
  });

  /// Create from new unified settings for backward compatibility
  factory AppSettings.fromUnified(ConfessionAppSettings unified) {
    String languageString = 'English';
    switch (unified.defaultLanguage) {
      case AppLanguage.latin:
        languageString = 'Latin';
        break;
      case AppLanguage.spanish:
        languageString = 'Spanish';
        break;
      case AppLanguage.english:
        languageString = 'English';
        break;
    }

    return AppSettings(
      darkMode: false, // Always false - theme is handled by theme provider now
      textScale: unified.textScale,
      defaultLanguage: languageString,
      notificationsEnabled: unified.notificationsEnabled,
    );
  }

  // Keep existing methods for backward compatibility
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

/// BACKWARD COMPATIBILITY: Provider for app settings using new unified system
///
/// This provider now wraps the new ConfessionAppSettings but maintains the old AppSettings interface
/// for backward compatibility. New code should use confessionAppSettingsProvider directly.
// ignore: deprecated_member_use_from_same_package
final appSettingsProvider = Provider<AppSettings>((ref) {
  final confessionSettings = ref.watch(confessionAppSettingsProvider);
  // ignore: deprecated_member_use_from_same_package
  return AppSettings.fromUnified(confessionSettings);
});

/// BACKWARD COMPATIBILITY: Notifier wrapper for the old interface
///
/// This class provides the old interface but delegates to the new unified system.
/// Use ConfessionAppSettingsNotifier directly for new features.
class AppSettingsNotifier {
  final Ref _ref;

  AppSettingsNotifier(this._ref);

  /// Get current state (backward compatibility)
  // ignore: deprecated_member_use_from_same_package
  AppSettings get state {
    final confessionSettings = _ref.read(confessionAppSettingsProvider);
    // ignore: deprecated_member_use_from_same_package
    return AppSettings.fromUnified(confessionSettings);
  }

  Future<void> updateDarkMode(bool darkMode) async {
    // MIGRATION: Dark mode is now handled by theme provider
    if (darkMode) {
      await _ref.read(themeModeProvider.notifier).setThemeMode(ThemeMode.dark);
    } else {
      await _ref.read(themeModeProvider.notifier).setThemeMode(ThemeMode.light);
    }
  }

  Future<void> updateTextScale(double textScale) async {
    await _ref
        .read(confessionAppSettingsProvider.notifier)
        .updateTextScale(textScale);
  }

  Future<void> updateDefaultLanguage(String language) async {
    AppLanguage appLanguage = AppLanguage.english;
    if (language == 'Latin') {
      appLanguage = AppLanguage.latin;
    } else if (language == 'Spanish') {
      appLanguage = AppLanguage.spanish;
    }

    await _ref
        .read(confessionAppSettingsProvider.notifier)
        .setDefaultLanguage(appLanguage);
  }

  Future<void> updateNotifications(bool enabled) async {
    await _ref
        .read(confessionAppSettingsProvider.notifier)
        .setNotificationsEnabled(enabled);
  }
}

/// BACKWARD COMPATIBILITY: Provider for the notifier
final appSettingsNotifierProvider = Provider<AppSettingsNotifier>((ref) {
  return AppSettingsNotifier(ref);
});

/// Migration helper to access the new notifier from old code patterns
extension AppSettingsNotifierExtension on WidgetRef {
  /// Get the new unified Confession app settings notifier
  /// Use this instead of appSettingsProvider.notifier for new functionality
  ConfessionAppSettingsNotifier get confessionAppSettingsNotifier {
    return read(confessionAppSettingsProvider.notifier);
  }
}
