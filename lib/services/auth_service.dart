import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import '../utils/logger.dart';
import '../utils/error_handler.dart';
import '../config/constants.dart';
import 'secure_storage_service.dart';

class AuthService {
  Timer? _sessionTimer;
  bool _isAuthenticated = false;

  /// Validate entered PIN against stored hash
  Future<bool> validatePin(String enteredPin) async {
    AppLogger.debug("=== AUTH SERVICE PIN VALIDATION START ===", 'AUTH');
    AppLogger.debug("Entered PIN length: ${enteredPin.length}", 'AUTH');
    AppLogger.debug("Expected PIN length: ${AppConstants.pinLength}", 'AUTH');
    
    try {
      // Check if currently locked out
      final isLockedOut = await SecureStorageService.isLockedOut();
      if (isLockedOut) {
        final remainingTime = await SecureStorageService.getRemainingLockoutTime();
        AppLogger.warning("PIN validation blocked - user is locked out", 'AUTH');
        throw AuthenticationException(
          'PIN entry is locked. Please wait ${_formatDuration(remainingTime)} before trying again.'
        );
      }

      // Check PIN length
      if (enteredPin.length != AppConstants.pinLength) {
        AppLogger.debug("PIN length validation failed: ${enteredPin.length} != ${AppConstants.pinLength}", 'AUTH');
        await SecureStorageService.incrementFailedAttempts();
        await _checkForLockout();
        return false;
      }
      AppLogger.debug("PIN length validation passed", 'AUTH');

      // Get stored PIN hash
      AppLogger.debug("Retrieving stored PIN hash", 'AUTH');
      final storedPinHash = await SecureStorageService.getPinHash();
      if (storedPinHash == null) {
        AppLogger.debug("No stored PIN hash found - PIN not set", 'AUTH');
        return false;
      }
      AppLogger.debug("Stored PIN hash found, length: ${storedPinHash.length}", 'AUTH');

      // Hash entered PIN and compare
      AppLogger.debug("Hashing entered PIN for comparison", 'AUTH');
      final enteredPinHash = await SecureStorageService.hashPin(enteredPin);
      AppLogger.debug("Entered PIN hash length: ${enteredPinHash.length}", 'AUTH');
      
      final isValid = storedPinHash == enteredPinHash;
      AppLogger.debug("Hash comparison result: $isValid", 'AUTH');
      
      if (isValid) {
        AppLogger.debug("=== SETTING AUTHENTICATED STATE ===", 'AUTH');
        AppLogger.debug("PIN validation successful - clearing failed attempts and setting authenticated", 'AUTH');
        await SecureStorageService.clearFailedAttempts();
        
        AppLogger.debug("Authentication state changing from $_isAuthenticated to true", 'AUTH');
        _isAuthenticated = true;
        AppLogger.debug("Authentication state is now: $_isAuthenticated", 'AUTH');
        
        _startSessionTimer();
        AppLogger.debug("Session authentication setup complete", 'AUTH');
      } else {
        AppLogger.debug("PIN validation failed - incrementing failed attempts", 'AUTH');
        await SecureStorageService.incrementFailedAttempts();
        await _checkForLockout();
        final newAttempts = await SecureStorageService.getFailedAttempts();
        AppLogger.debug("Failed attempts after increment: $newAttempts", 'AUTH');
      }
      
      AppLogger.debug("=== AUTH SERVICE PIN VALIDATION END: $isValid ===", 'AUTH');
      return isValid;
      
    } catch (e, stackTrace) {
      AppLogger.error('=== AUTH SERVICE PIN VALIDATION EXCEPTION ===', e, stackTrace, 'AUTH');
      AppLogger.debug("Exception type: ${e.runtimeType}", 'AUTH');
      AppLogger.debug("Exception message: ${e.toString()}", 'AUTH');
      throw AuthenticationException('PIN validation failed: ${e.toString()}');
    }
  }

  /// Check if user should be locked out after failed attempt
  Future<void> _checkForLockout() async {
    final attempts = await SecureStorageService.getFailedAttempts();
    if (attempts >= AppConstants.maxPinAttempts) {
      AppLogger.warning("Maximum PIN attempts reached ($attempts), setting lockout", 'AUTH');
      final lockoutUntil = DateTime.now().add(Duration(minutes: AppConstants.pinLockoutMinutes));
      await SecureStorageService.setLockoutTimestamp(lockoutUntil);
      
      final remainingTime = Duration(minutes: AppConstants.pinLockoutMinutes);
      throw AuthenticationException(
        'Too many failed attempts. PIN entry is locked for ${_formatDuration(remainingTime)}.'
      );
    }
  }

  /// Format duration for user display
  String _formatDuration(Duration? duration) {
    if (duration == null) return '0 minutes';
    
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    
    if (minutes > 0) {
      return '$minutes minute${minutes != 1 ? 's' : ''}';
    } else {
      return '$seconds second${seconds != 1 ? 's' : ''}';
    }
  }

  /// Set new PIN (hash and store securely)
  Future<void> setPinCode(String pinCode) async {
    AppLogger.debug("=== AUTH SERVICE SET PIN ===", 'AUTH');
    AppLogger.debug("PIN length: ${pinCode.length}, expected: ${AppConstants.pinLength}", 'AUTH');
    
    try {
      // Validate PIN length
      if (pinCode.length != AppConstants.pinLength) {
        AppLogger.debug("PIN length validation failed", 'AUTH');
        throw AuthenticationException('PIN must be exactly ${AppConstants.pinLength} digits');
      }
      AppLogger.debug("PIN length validation passed", 'AUTH');

      // Hash the PIN
      AppLogger.debug("Calling SecureStorageService.hashPin", 'AUTH');
      final hashedPin = await SecureStorageService.hashPin(pinCode);
      AppLogger.debug("PIN hashed successfully, hash length: ${hashedPin.length}", 'AUTH');
      
      // Store the hashed PIN and length
      AppLogger.debug("Calling SecureStorageService.storePinHash with length ${pinCode.length}", 'AUTH');
      await SecureStorageService.storePinHash(hashedPin, pinCode.length);
      AppLogger.debug("PIN hash and length stored successfully", 'AUTH');
      
      // Clear any failed attempts
      AppLogger.debug("Calling SecureStorageService.clearFailedAttempts", 'AUTH');
      await SecureStorageService.clearFailedAttempts();
      AppLogger.debug("Failed attempts cleared", 'AUTH');
      
      // IMPORTANT: Do NOT set authenticated after PIN setup
      // User must authenticate again to access protected content
      AppLogger.debug("PIN setup complete - user must authenticate separately", 'AUTH');
      _isAuthenticated = false; // Ensure user is not authenticated after PIN setup
      _sessionTimer?.cancel(); // Cancel any existing session
      
      AppLogger.debug("=== PIN CODE SET SUCCESSFULLY ===", 'AUTH');
    } catch (e, stackTrace) {
      AppLogger.error('=== FAILED TO SET PIN CODE ===', e, stackTrace, 'AUTH');
      AppLogger.debug("Error details: type=${e.runtimeType}, message=${e.toString()}", 'AUTH');
      
      if (e.toString().contains('Secure storage not available')) {
        AppLogger.debug("Throwing iOS Simulator exception", 'AUTH');
        throw AuthenticationException('PIN setup not available in iOS Simulator. Please test on a physical device.');
      } else {
        AppLogger.debug("Throwing generic exception", 'AUTH');
        throw AuthenticationException('Failed to set PIN code: ${e.toString()}');
      }
    }
  }

  /// Check if PIN exists
  Future<bool> hasPinCode() async {
    try {
      return await SecureStorageService.hasPinCode();
    } catch (e, stackTrace) {
      AppLogger.error('Failed to check PIN existence', e, stackTrace, 'AUTH');
      return false; // Fail safely - assume no PIN if we can't check
    }
  }

  /// Clear PIN (disable PIN protection)
  Future<void> clearPinCode() async {
    AppLogger.debug("Clearing PIN code", 'AUTH');
    
    try {
      await SecureStorageService.clearPinCode();
      _isAuthenticated = false;
      _sessionTimer?.cancel();
    } catch (e, stackTrace) {
      AppLogger.error('Failed to clear PIN code', e, stackTrace, 'AUTH');
      throw AuthenticationException('Failed to clear PIN code');
    }
  }

  /// Session Management
  void _startSessionTimer() {
    _sessionTimer?.cancel();
    _sessionTimer = Timer(Duration(minutes: AppConstants.sessionTimeoutMinutes), () {
      AppLogger.debug("=== SESSION TIMEOUT ===", 'AUTH');
      AppLogger.debug("Authentication state changing from true to false due to timeout", 'AUTH');
      _isAuthenticated = false;
      AppLogger.debug("Session timed out after ${AppConstants.sessionTimeoutMinutes} minutes", 'AUTH');
    });
    AppLogger.debug("Session timer started for ${AppConstants.sessionTimeoutMinutes} minutes", 'AUTH');
  }

  void refreshSession() {
    AppLogger.debug("=== REFRESH SESSION ===", 'AUTH');
    AppLogger.debug("Current auth state: $_isAuthenticated", 'AUTH');
    if (_isAuthenticated) {
      _startSessionTimer();
      AppLogger.debug("Session refreshed", 'AUTH');
    } else {
      AppLogger.debug("Cannot refresh session - not authenticated", 'AUTH');
    }
  }

  bool get isAuthenticated {
    AppLogger.debug("Authentication state queried: $_isAuthenticated", 'AUTH');
    return _isAuthenticated;
  }

  void logout() {
    AppLogger.debug("=== LOGOUT ===", 'AUTH');
    AppLogger.debug("Authentication state changing from $_isAuthenticated to false", 'AUTH');
    _isAuthenticated = false;
    _sessionTimer?.cancel();
    AppLogger.debug("User logged out and session timer cancelled", 'AUTH');
  }

  /// Check if authentication is required for app access
  Future<bool> isAuthRequired(WidgetRef ref) async {
    return await hasPinCode();
  }

  /// Get failed attempts count
  Future<int> getFailedAttempts() async {
    return await SecureStorageService.getFailedAttempts();
  }

  /// Get the stored PIN length
  Future<int?> getPinLength() async {
    try {
      return await SecureStorageService.getPinLength();
    } catch (e, stackTrace) {
      AppLogger.error('Failed to get PIN length', e, stackTrace, 'AUTH');
      return null;
    }
  }

  /// Lockout management
  Future<bool> isLockedOut() async {
    try {
      return await SecureStorageService.isLockedOut();
    } catch (e, stackTrace) {
      AppLogger.error('Failed to check lockout status', e, stackTrace, 'AUTH');
      return false;
    }
  }

  Future<Duration?> getRemainingLockoutTime() async {
    try {
      return await SecureStorageService.getRemainingLockoutTime();
    } catch (e, stackTrace) {
      AppLogger.error('Failed to get remaining lockout time', e, stackTrace, 'AUTH');
      return null;
    }
  }

  /// Clear lockout (can be called on app restart for casual security)
  Future<void> clearLockoutOnRestart() async {
    try {
      AppLogger.debug("Clearing lockout on app restart (casual security)", 'AUTH');
      await SecureStorageService.clearLockout();
      // Don't clear failed attempts - just the lockout timer
    } catch (e, stackTrace) {
      AppLogger.error('Failed to clear lockout on restart', e, stackTrace, 'AUTH');
    }
  }

  /// Get installation info for debugging
  Future<String?> getInstallationId() async {
    try {
      return await SecureStorageService.getInstallationId();
    } catch (e, stackTrace) {
      AppLogger.error('Failed to get installation ID', e, stackTrace, 'AUTH');
      return null;
    }
  }

  /// Force check for fresh installation (for testing)
  Future<bool> checkFreshInstallation() async {
    try {
      return await SecureStorageService.checkAndHandleFreshInstallation();
    } catch (e, stackTrace) {
      AppLogger.error('Failed to check fresh installation', e, stackTrace, 'AUTH');
      return false;
    }
  }

  /// For testing/debugging - clear all auth data
  Future<void> resetAuth() async {
    await clearPinCode();
    await SecureStorageService.clearFailedAttempts();
    AppLogger.debug("Auth data reset", 'AUTH');
  }

  /// For debugging - manually set authentication state
  void setAuthenticatedForDebug(bool authenticated) {
    AppLogger.debug("=== MANUAL AUTH STATE SET ===", 'AUTH');
    AppLogger.debug("Setting authentication state from $_isAuthenticated to $authenticated", 'AUTH');
    _isAuthenticated = authenticated;
    if (authenticated) {
      _startSessionTimer();
    } else {
      _sessionTimer?.cancel();
    }
  }

  /// Force logout to clear any stale authentication state
  void forceLogout() {
    AppLogger.debug("=== FORCE LOGOUT ===", 'AUTH');
    AppLogger.debug("Clearing any stale authentication state", 'AUTH');
    _isAuthenticated = false;
    _sessionTimer?.cancel();
    AppLogger.debug("Authentication state forcibly cleared", 'AUTH');
  }

  /// Debug method to check current auth state
  void debugAuthState() {
    AppLogger.debug("=== AUTH STATE DEBUG ===", 'AUTH');
    AppLogger.debug("Current authentication state: $_isAuthenticated", 'AUTH');
    AppLogger.debug("Session timer active: ${_sessionTimer?.isActive ?? false}", 'AUTH');
    if (_sessionTimer?.isActive == true) {
      AppLogger.debug("Session timeout: ${AppConstants.sessionTimeoutMinutes} minutes", 'AUTH');
    }
  }
}

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

// Provider to check if authentication is required
final authRequiredProvider = FutureProvider<bool>((ref) async {
  final authService = ref.read(authServiceProvider);
  return await authService.hasPinCode();
});