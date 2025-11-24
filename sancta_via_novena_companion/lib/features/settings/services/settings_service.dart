import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/auth_service.dart';
import '../providers/novena_app_settings_provider.dart';
import '../../../utils/logger.dart';

/// Service class to handle settings-related business logic
/// This separates business logic from UI components
class SettingsService {
  final Ref _ref;
  final AuthService _authService;

  SettingsService(this._ref, this._authService);

  /// Update daily reminder time
  Future<void> updateReminderTime(TimeOfDay time) async {
    try {
      await _ref.read(novenaAppSettingsProvider.notifier).updateDailyReminderTime(time);
      AppLogger.debug('Daily reminder time updated to ${time.hour}:${time.minute.toString().padLeft(2, '0')}', 'SETTINGS_SERVICE');
    } catch (e, stackTrace) {
      AppLogger.error('Failed to update reminder time', e, stackTrace, 'SETTINGS_SERVICE');
      rethrow;
    }
  }

  /// Set up PIN code with validation
  Future<void> setupPinCode(String pin) async {
    try {
      if (pin.length != 4) {
        throw ArgumentError('PIN must be exactly 4 digits');
      }
      
      await _ref.read(novenaAppSettingsProvider.notifier).setPinCode(pin);
      AppLogger.debug('PIN code set up successfully', 'SETTINGS_SERVICE');
    } catch (e, stackTrace) {
      AppLogger.error('Failed to set up PIN code', e, stackTrace, 'SETTINGS_SERVICE');
      rethrow;
    }
  }

  /// Change existing PIN code
  Future<void> changePinCode(String currentPin, String newPin) async {
    try {
      // Validate current PIN first
      final isValid = await _authService.validatePin(currentPin);
      if (!isValid) {
        throw Exception('Current PIN is incorrect');
      }

      // Clear current session for security
      _authService.logout();

      // Set new PIN
      await setupPinCode(newPin);
      AppLogger.debug('PIN code changed successfully', 'SETTINGS_SERVICE');
    } catch (e, stackTrace) {
      AppLogger.error('Failed to change PIN code', e, stackTrace, 'SETTINGS_SERVICE');
      rethrow;
    }
  }

  /// Remove PIN code
  Future<void> removePinCode(String currentPin) async {
    try {
      // Validate current PIN first
      final isValid = await _authService.validatePin(currentPin);
      if (!isValid) {
        throw Exception('Current PIN is incorrect');
      }

      // Clear current session for security
      _authService.logout();

      // Remove PIN
      await _ref.read(novenaAppSettingsProvider.notifier).clearPinCode();
      AppLogger.debug('PIN code removed successfully', 'SETTINGS_SERVICE');
    } catch (e, stackTrace) {
      AppLogger.error('Failed to remove PIN code', e, stackTrace, 'SETTINGS_SERVICE');
      rethrow;
    }
  }

  /// Toggle novena notifications
  Future<void> toggleNovenaNotifications(bool enabled) async {
    try {
      await _ref.read(novenaAppSettingsProvider.notifier).updateNovenaNotificationsEnabled(enabled);
      AppLogger.debug('Novena notifications ${enabled ? 'enabled' : 'disabled'}', 'SETTINGS_SERVICE');
    } catch (e, stackTrace) {
      AppLogger.error('Failed to toggle novena notifications', e, stackTrace, 'SETTINGS_SERVICE');
      rethrow;
    }
  }

  /// Toggle completion celebrations
  Future<void> toggleCompletionCelebrations(bool enabled) async {
    try {
      await _ref.read(novenaAppSettingsProvider.notifier).updateShowCompletionCelebrations(enabled);
      AppLogger.debug('Completion celebrations ${enabled ? 'enabled' : 'disabled'}', 'SETTINGS_SERVICE');
    } catch (e, stackTrace) {
      AppLogger.error('Failed to toggle completion celebrations', e, stackTrace, 'SETTINGS_SERVICE');
      rethrow;
    }
  }

  /// Validate PIN code
  Future<bool> validatePin(String pin) async {
    try {
      return await _authService.validatePin(pin);
    } catch (e, stackTrace) {
      AppLogger.error('Failed to validate PIN', e, stackTrace, 'SETTINGS_SERVICE');
      return false;
    }
  }

  /// Check if PIN is set up
  bool get hasPinCode {
    return _ref.read(novenaAppSettingsProvider).hasPinCode;
  }

  /// Get current reminder time
  TimeOfDay get currentReminderTime {
    return _ref.read(novenaAppSettingsProvider).dailyReminderTimeOfDay;
  }
}

/// Provider for the settings service
final settingsServiceProvider = Provider<SettingsService>((ref) {
  final authService = ref.read(authServiceProvider);
  return SettingsService(ref, authService);
});
