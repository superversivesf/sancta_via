// MIGRATION NOTICE: This file now uses the new unified settings system
// All functionality has been preserved for backward compatibility

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bible_data/bible_data.dart';

// Import the new unified settings system
import 'bible_app_settings_provider.dart';
import '../models/app_settings.dart';

// NEW UNIFIED SYSTEM: Re-export new providers for direct use
// New code should use these for full functionality
export 'bible_app_settings_provider.dart';

/// Debug logging utility
void debugLog(String message, [String? tag]) {
  final timestamp = DateTime.now().toIso8601String();
  // ignore: avoid_print
  print('[$timestamp] ${tag != null ? '[$tag] ' : ''}$message');
}

/// BACKWARD COMPATIBILITY: Provider for app settings using new unified system
/// 
/// This provider now wraps the new BibleAppSettings but maintains the old AppSettings interface
/// for backward compatibility. New code should use bibleAppSettingsProvider directly.
// ignore: deprecated_member_use_from_same_package
final appSettingsProvider = Provider<AppSettings>((ref) {
  final bibleSettings = ref.watch(bibleAppSettingsProvider);
  
  // Convert to old AppSettings format for backward compatibility
  // ignore: deprecated_member_use_from_same_package
  return AppSettings(
    fontSize: bibleSettings.fontSize,
    selectedBibleTranslation: bibleSettings.selectedBibleTranslation,
  );
});

/// BACKWARD COMPATIBILITY: Notifier wrapper for the old interface
/// 
/// This class provides the old interface but delegates to the new unified system.
/// Use BibleAppSettingsNotifier directly for new features.
class AppSettingsNotifier {
  final Ref _ref;
  
  AppSettingsNotifier(this._ref);
  
  /// Get current state (backward compatibility)
  // ignore: deprecated_member_use_from_same_package
  AppSettings get state {
    final bibleSettings = _ref.read(bibleAppSettingsProvider);
    // ignore: deprecated_member_use_from_same_package
    return AppSettings(
      fontSize: bibleSettings.fontSize,
      selectedBibleTranslation: bibleSettings.selectedBibleTranslation,
    );
  }

  Future<void> setFontSize(double value) async {
    await _ref.read(bibleAppSettingsProvider.notifier).setFontSize(value);
  }

  Future<void> setBibleTranslation(BibleTranslation translation) async {
    await _ref.read(bibleAppSettingsProvider.notifier).setBibleTranslation(translation);
  }
}

/// BACKWARD COMPATIBILITY: Provider for the notifier
final appSettingsNotifierProvider = Provider<AppSettingsNotifier>((ref) {
  return AppSettingsNotifier(ref);
});

/// BACKWARD COMPATIBILITY: Re-export convenience providers
/// These now use the new unified system but maintain the same interface

/// Provider for font size
final fontSizeProvider = Provider<double>((ref) {
  return ref.watch(bibleAppSettingsProvider).fontSize;
});

/// Provider for app's selected bible translation
final appSelectedBibleTranslationProvider = Provider<BibleTranslation>((ref) {
  return ref.watch(bibleAppSettingsProvider).selectedBibleTranslation;
});

/// Migration helper to access the new notifier from old code patterns
extension AppSettingsNotifierExtension on WidgetRef {
  /// Get the new unified Bible app settings notifier
  /// Use this instead of appSettingsProvider.notifier for new functionality
  BibleAppSettingsNotifier get bibleAppSettingsNotifier {
    return read(bibleAppSettingsProvider.notifier);
  }
}
