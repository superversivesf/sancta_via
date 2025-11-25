import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'dart:math';
import '../utils/logger.dart';

class SecureStorageService {
  static const _secureStorage = FlutterSecureStorage();

  // Storage keys
  static const String _pinSaltKey = 'pin_salt_installation_unique';
  static const String _pinHashKey = 'pin_hash';
  static const String _pinLengthKey = 'pin_length';
  static const String _activeSessionKey = 'examination_session_active';
  static const String _completedSessionsKey = 'examination_sessions_completed';
  static const String _failedAttemptsKey = 'pin_failed_attempts';
  static const String _lockoutTimestampKey = 'pin_lockout_timestamp';
  static const String _installationIdKey = 'installation_id_unique';

  /// Generate or retrieve unique salt per installation
  static Future<String> _getOrCreateSalt() async {
    AppLogger.debug('=== GETTING OR CREATING SALT ===', 'SECURE_STORAGE');

    try {
      final String? existingSalt = await _secureStorage.read(key: _pinSaltKey);
      if (existingSalt != null) {
        AppLogger.debug(
          "Found existing salt: '${existingSalt.substring(0, 10)}...' (length: ${existingSalt.length})",
          'SECURE_STORAGE',
        );
        return existingSalt;
      }

      AppLogger.debug(
        'No existing salt found, generating new one',
        'SECURE_STORAGE',
      );

      // Generate cryptographically secure random salt (32 bytes)
      final random = Random.secure();
      final saltBytes = List<int>.generate(32, (i) => random.nextInt(256));
      final newSalt = base64Encode(saltBytes);

      AppLogger.debug(
        "Generated new salt: '${newSalt.substring(0, 10)}...' (length: ${newSalt.length})",
        'SECURE_STORAGE',
      );

      await _secureStorage.write(key: _pinSaltKey, value: newSalt);
      AppLogger.debug('New salt stored successfully', 'SECURE_STORAGE');

      // Verify salt was stored correctly
      final verificationSalt = await _secureStorage.read(key: _pinSaltKey);
      if (verificationSalt == newSalt) {
        AppLogger.debug(
          'Salt storage verification successful',
          'SECURE_STORAGE',
        );
      } else {
        AppLogger.warning('Salt storage verification failed', 'SECURE_STORAGE');
      }

      return newSalt;
    } catch (e, stackTrace) {
      AppLogger.error(
        'Failed to get/create salt',
        e,
        stackTrace,
        'SECURE_STORAGE',
      );
      rethrow;
    }
  }

  /// Hash PIN with unique salt
  static Future<String> hashPin(String pin) async {
    AppLogger.debug('=== HASHING PIN ===', 'SECURE_STORAGE');
    AppLogger.debug(
      "Input PIN: '$pin' (length: ${pin.length})",
      'SECURE_STORAGE',
    );

    try {
      final salt = await _getOrCreateSalt();
      AppLogger.debug(
        "Salt retrieved: '$salt' (length: ${salt.length})",
        'SECURE_STORAGE',
      );

      final saltedPin = pin + salt;
      AppLogger.debug(
        'Salted PIN created: length ${saltedPin.length}',
        'SECURE_STORAGE',
      );

      final bytes = utf8.encode(saltedPin);
      AppLogger.debug(
        'UTF8 bytes created: length ${bytes.length}',
        'SECURE_STORAGE',
      );

      final digest = sha256.convert(bytes);
      final hash = digest.toString();
      AppLogger.debug(
        "Final hash: '$hash' (length: ${hash.length})",
        'SECURE_STORAGE',
      );

      return hash;
    } catch (e, stackTrace) {
      AppLogger.error('Failed to hash PIN', e, stackTrace, 'SECURE_STORAGE');
      rethrow;
    }
  }

  /// PIN Management with error handling for iOS simulator issues
  static Future<void> storePinHash(String pinHash, int pinLength) async {
    AppLogger.debug('=== STORING PIN HASH AND LENGTH ===', 'SECURE_STORAGE');
    AppLogger.debug(
      'Attempting to store PIN hash, length: ${pinHash.length}, PIN length: $pinLength',
      'SECURE_STORAGE',
    );

    try {
      await _secureStorage.write(key: _pinHashKey, value: pinHash);
      await _secureStorage.write(
        key: _pinLengthKey,
        value: pinLength.toString(),
      );
      AppLogger.debug(
        'PIN hash and length stored successfully in secure storage',
        'SECURE_STORAGE',
      );

      // Verify the storage worked
      final verification = await _secureStorage.read(key: _pinHashKey);
      final lengthVerification = await _secureStorage.read(key: _pinLengthKey);
      if (verification == pinHash &&
          lengthVerification == pinLength.toString()) {
        AppLogger.debug(
          'PIN hash and length storage verified successfully',
          'SECURE_STORAGE',
        );
      } else {
        AppLogger.warning(
          "PIN storage verification failed - stored values don't match",
          'SECURE_STORAGE',
        );
      }
    } catch (e) {
      AppLogger.error(
        'Failed to store PIN hash and length - keychain access issue',
        e,
        null,
        'SECURE_STORAGE',
      );
      throw Exception(
        'Secure storage not available. This may happen in iOS simulator or due to missing entitlements.',
      );
    }
  }

  static Future<String?> getPinHash() async {
    AppLogger.debug('=== GETTING PIN HASH ===', 'SECURE_STORAGE');
    try {
      final hash = await _secureStorage.read(key: _pinHashKey);
      if (hash != null) {
        AppLogger.debug(
          "PIN hash retrieved successfully: '${hash.substring(0, 10)}...' (length: ${hash.length})",
          'SECURE_STORAGE',
        );
      } else {
        AppLogger.debug(
          'No PIN hash found in secure storage',
          'SECURE_STORAGE',
        );
      }
      return hash;
    } catch (e) {
      AppLogger.error(
        'Failed to read PIN hash - keychain access issue',
        e,
        null,
        'SECURE_STORAGE',
      );
      return null; // Return null instead of throwing to allow app to continue
    }
  }

  static Future<int?> getPinLength() async {
    try {
      final lengthStr = await _secureStorage.read(key: _pinLengthKey);
      return lengthStr != null ? int.tryParse(lengthStr) : null;
    } catch (e) {
      AppLogger.error(
        'Failed to read PIN length - keychain access issue',
        e,
        null,
        'SECURE_STORAGE',
      );
      return null; // Return null instead of throwing to allow app to continue
    }
  }

  static Future<bool> hasPinCode() async {
    try {
      final pinHash = await getPinHash();
      final pinLength = await getPinLength();
      return pinHash != null && pinHash.isNotEmpty && pinLength != null;
    } catch (e) {
      AppLogger.error(
        'Failed to check PIN existence - keychain access issue',
        e,
        null,
        'SECURE_STORAGE',
      );
      return false; // Return false to allow app to continue without PIN protection
    }
  }

  static Future<void> clearPinCode() async {
    try {
      await _secureStorage.delete(key: _pinHashKey);
      await _secureStorage.delete(key: _pinLengthKey);
      await _secureStorage.delete(key: _failedAttemptsKey);
      await _secureStorage.delete(key: _lockoutTimestampKey);
      AppLogger.debug('PIN code cleared', 'SECURE_STORAGE');
    } catch (e) {
      AppLogger.error(
        'Failed to clear PIN code - keychain access issue',
        e,
        null,
        'SECURE_STORAGE',
      );
      throw Exception(
        'Secure storage not available. This may happen in iOS simulator or due to missing entitlements.',
      );
    }
  }

  /// Failed attempts tracking with error handling
  static Future<int> getFailedAttempts() async {
    try {
      final attemptsStr = await _secureStorage.read(key: _failedAttemptsKey);
      return int.tryParse(attemptsStr ?? '0') ?? 0;
    } catch (e) {
      AppLogger.error(
        'Failed to read failed attempts - keychain access issue',
        e,
        null,
        'SECURE_STORAGE',
      );
      return 0; // Return 0 to allow app to continue
    }
  }

  static Future<void> incrementFailedAttempts() async {
    try {
      final attempts = await getFailedAttempts();
      await _secureStorage.write(
        key: _failedAttemptsKey,
        value: (attempts + 1).toString(),
      );
    } catch (e) {
      AppLogger.error(
        'Failed to increment failed attempts - keychain access issue',
        e,
        null,
        'SECURE_STORAGE',
      );
      // Don't throw - just log the error
    }
  }

  static Future<void> clearFailedAttempts() async {
    try {
      await _secureStorage.delete(key: _failedAttemptsKey);
      await _secureStorage.delete(
        key: _lockoutTimestampKey,
      ); // Clear lockout too
    } catch (e) {
      AppLogger.error(
        'Failed to clear failed attempts - keychain access issue',
        e,
        null,
        'SECURE_STORAGE',
      );
      // Don't throw - just log the error
    }
  }

  /// PIN Lockout Management
  static Future<void> setLockoutTimestamp(DateTime lockoutTime) async {
    try {
      await _secureStorage.write(
        key: _lockoutTimestampKey,
        value: lockoutTime.millisecondsSinceEpoch.toString(),
      );
      AppLogger.debug(
        'Lockout timestamp set: ${lockoutTime.toIso8601String()}',
        'SECURE_STORAGE',
      );
    } catch (e) {
      AppLogger.error(
        'Failed to set lockout timestamp',
        e,
        null,
        'SECURE_STORAGE',
      );
    }
  }

  static Future<DateTime?> getLockoutTimestamp() async {
    try {
      final timestampStr = await _secureStorage.read(key: _lockoutTimestampKey);
      if (timestampStr != null) {
        final timestamp = int.tryParse(timestampStr);
        if (timestamp != null) {
          return DateTime.fromMillisecondsSinceEpoch(timestamp);
        }
      }
      return null;
    } catch (e) {
      AppLogger.error(
        'Failed to read lockout timestamp',
        e,
        null,
        'SECURE_STORAGE',
      );
      return null;
    }
  }

  static Future<bool> isLockedOut() async {
    try {
      final lockoutTime = await getLockoutTimestamp();
      if (lockoutTime == null) return false;

      final now = DateTime.now();
      final isStillLocked = now.isBefore(lockoutTime);

      if (!isStillLocked) {
        // Lockout period has expired, clear it
        await clearLockout();
      }

      return isStillLocked;
    } catch (e) {
      AppLogger.error(
        'Failed to check lockout status',
        e,
        null,
        'SECURE_STORAGE',
      );
      return false; // Don't lock user out due to storage errors
    }
  }

  static Future<Duration?> getRemainingLockoutTime() async {
    try {
      final lockoutTime = await getLockoutTimestamp();
      if (lockoutTime == null) return null;

      final now = DateTime.now();
      if (now.isAfter(lockoutTime)) {
        return null; // Lockout has expired
      }

      return lockoutTime.difference(now);
    } catch (e) {
      AppLogger.error(
        'Failed to get remaining lockout time',
        e,
        null,
        'SECURE_STORAGE',
      );
      return null;
    }
  }

  static Future<void> clearLockout() async {
    try {
      await _secureStorage.delete(key: _lockoutTimestampKey);
      AppLogger.debug('Lockout cleared', 'SECURE_STORAGE');
    } catch (e) {
      AppLogger.error('Failed to clear lockout', e, null, 'SECURE_STORAGE');
    }
  }

  /// Examination Session Storage (Secure)
  static Future<void> saveActiveExaminationSession(String sessionData) async {
    await _secureStorage.write(key: _activeSessionKey, value: sessionData);
    AppLogger.debug(
      'Active examination session saved securely',
      'SECURE_STORAGE',
    );
  }

  static Future<String?> getActiveExaminationSession() async {
    return await _secureStorage.read(key: _activeSessionKey);
  }

  static Future<void> clearActiveExaminationSession() async {
    await _secureStorage.delete(key: _activeSessionKey);
    AppLogger.debug('Active examination session cleared', 'SECURE_STORAGE');
  }

  /// Completed Examinations Storage (Secure)
  static Future<void> saveCompletedExaminations(String completedData) async {
    await _secureStorage.write(
      key: _completedSessionsKey,
      value: completedData,
    );
    AppLogger.debug('Completed examinations saved securely', 'SECURE_STORAGE');
  }

  static Future<String?> getCompletedExaminations() async {
    return await _secureStorage.read(key: _completedSessionsKey);
  }

  /// Fresh Installation Detection
  static Future<String> _getCurrentInstallationId() async {
    // Generate a unique ID based on current timestamp and random data
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = Random.secure();
    final randomBytes = List<int>.generate(16, (i) => random.nextInt(256));
    final randomString = base64Encode(randomBytes);
    return '$timestamp-$randomString';
  }

  static Future<bool> checkAndHandleFreshInstallation() async {
    AppLogger.debug(
      '=== CHECKING FOR FRESH INSTALLATION ===',
      'SECURE_STORAGE',
    );

    try {
      // Try to read the stored installation ID
      final storedInstallationId = await _secureStorage.read(
        key: _installationIdKey,
      );

      if (storedInstallationId == null) {
        AppLogger.debug(
          'No installation ID found - this is a fresh installation',
          'SECURE_STORAGE',
        );

        // This is a fresh installation, clear any leftover data
        await _clearLeftoverDataOnFreshInstall();

        // Generate and store new installation ID
        final newInstallationId = await _getCurrentInstallationId();
        await _secureStorage.write(
          key: _installationIdKey,
          value: newInstallationId,
        );

        AppLogger.debug(
          'Fresh installation setup complete with new ID: ${newInstallationId.substring(0, 20)}...',
          'SECURE_STORAGE',
        );
        return true;
      } else {
        AppLogger.debug(
          'Installation ID found: ${storedInstallationId.substring(0, 20)}... - existing installation',
          'SECURE_STORAGE',
        );
        return false;
      }
    } catch (e, stackTrace) {
      AppLogger.error(
        'Failed to check installation status',
        e,
        stackTrace,
        'SECURE_STORAGE',
      );
      return false;
    }
  }

  static Future<void> _clearLeftoverDataOnFreshInstall() async {
    AppLogger.debug(
      '=== CLEARING LEFTOVER DATA FROM PREVIOUS INSTALLATION ===',
      'SECURE_STORAGE',
    );

    try {
      // Clear all PIN-related data
      await _secureStorage.delete(key: _pinHashKey);
      await _secureStorage.delete(key: _pinLengthKey);
      await _secureStorage.delete(key: _pinSaltKey);
      await _secureStorage.delete(key: _failedAttemptsKey);
      await _secureStorage.delete(key: _lockoutTimestampKey);

      // Clear all examination data
      await _secureStorage.delete(key: _activeSessionKey);
      await _secureStorage.delete(key: _completedSessionsKey);

      AppLogger.debug('Leftover data cleared successfully', 'SECURE_STORAGE');
    } catch (e, stackTrace) {
      AppLogger.error(
        'Failed to clear leftover data',
        e,
        stackTrace,
        'SECURE_STORAGE',
      );
      // Don't throw - just log the error
    }
  }

  /// Complete wipe (for testing/reset)
  static Future<void> clearAllSecureData() async {
    await _secureStorage.deleteAll();
    AppLogger.debug('All secure data cleared', 'SECURE_STORAGE');
  }

  /// Health check
  static Future<bool> isSecureStorageAvailable() async {
    try {
      await _secureStorage.write(key: 'test_key', value: 'test_value');
      final testValue = await _secureStorage.read(key: 'test_key');
      await _secureStorage.delete(key: 'test_key');
      return testValue == 'test_value';
    } catch (e) {
      AppLogger.error(
        'Secure storage not available',
        e,
        null,
        'SECURE_STORAGE',
      );
      return false;
    }
  }

  /// For debugging - get installation info
  static Future<String?> getInstallationId() async {
    try {
      return await _secureStorage.read(key: _installationIdKey);
    } catch (e) {
      AppLogger.error(
        'Failed to get installation ID',
        e,
        null,
        'SECURE_STORAGE',
      );
      return null;
    }
  }
}
