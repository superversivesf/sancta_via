import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/settings_model.dart';
import '../../../services/auth_service.dart';
import '../../../utils/logger.dart';
import '../../../utils/error_handler.dart';
import '../../../config/theme.dart';

class SettingsNotifier extends StateNotifier<SettingsModel> {
  final AuthService _authService;

  SettingsNotifier(this._authService) : super(
    SettingsModel(
      fontSize: 1.0,
      hasPinCode: false,
      colorSchemeStyle: ColorSchemeStyle.muted,
    ),
  ) {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final hasPin = await _authService.hasPinCode();
      
      // Load color scheme style from preferences
      final colorSchemeIndex = prefs.getInt('colorSchemeStyle') ?? ColorSchemeStyle.muted.index;
      final colorSchemeStyle = ColorSchemeStyle.values[colorSchemeIndex];

      state = SettingsModel(
        fontSize: prefs.getDouble('fontSize') ?? 1.0,
        hasPinCode: hasPin,
        colorSchemeStyle: colorSchemeStyle,
      );
      
      AppLogger.debug("Settings loaded successfully", 'SETTINGS');
    } catch (e, stackTrace) {
      AppLogger.error('Failed to load settings', e, stackTrace, 'SETTINGS');
      ErrorHandler.handleError(e, stackTrace: stackTrace, tag: 'SETTINGS');
    }
  }

  Future<void> setFontSize(double value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('fontSize', value);
      state = state.copyWith(fontSize: value);
      AppLogger.debug("Font size updated: $value", 'SETTINGS');
    } catch (e, stackTrace) {
      AppLogger.error('Failed to update font size', e, stackTrace, 'SETTINGS');
      ErrorHandler.handleError(e, stackTrace: stackTrace, tag: 'SETTINGS');
    }
  }

  Future<void> setColorSchemeStyle(ColorSchemeStyle value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('colorSchemeStyle', value.index);
      state = state.copyWith(colorSchemeStyle: value);
      AppLogger.debug("Color scheme style updated: $value", 'SETTINGS');
    } catch (e, stackTrace) {
      AppLogger.error('Failed to update color scheme style', e, stackTrace, 'SETTINGS');
      ErrorHandler.handleError(e, stackTrace: stackTrace, tag: 'SETTINGS');
    }
  }

  /// Set PIN code using AuthService
  Future<void> setPinCode(String pinCode) async {
    try {
      await _authService.setPinCode(pinCode);
      state = state.copyWith(hasPinCode: true);
      AppLogger.debug("PIN code set via settings", 'SETTINGS');
    } catch (e, stackTrace) {
      AppLogger.error('Failed to set PIN code via settings', e, stackTrace, 'SETTINGS');
      ErrorHandler.handleError(e, stackTrace: stackTrace, tag: 'SETTINGS');
      rethrow; // Re-throw so UI can handle the error
    }
  }

  /// Clear PIN code using AuthService
  Future<void> clearPinCode() async {
    try {
      await _authService.clearPinCode();
      state = state.copyWith(hasPinCode: false);
      AppLogger.debug("PIN code cleared via settings", 'SETTINGS');
    } catch (e, stackTrace) {
      AppLogger.error('Failed to clear PIN code via settings', e, stackTrace, 'SETTINGS');
      ErrorHandler.handleError(e, stackTrace: stackTrace, tag: 'SETTINGS');
      rethrow; // Re-throw so UI can handle the error
    }
  }

  /// Refresh PIN status (useful after external PIN changes)
  Future<void> refreshPinStatus() async {
    try {
      final hasPin = await _authService.hasPinCode();
      state = state.copyWith(hasPinCode: hasPin);
      AppLogger.debug("PIN status refreshed: $hasPin", 'SETTINGS');
    } catch (e, stackTrace) {
      AppLogger.error('Failed to refresh PIN status', e, stackTrace, 'SETTINGS');
      ErrorHandler.handleError(e, stackTrace: stackTrace, tag: 'SETTINGS');
    }
  }
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, SettingsModel>((ref) {
  final authService = ref.read(authServiceProvider);
  return SettingsNotifier(authService);
});