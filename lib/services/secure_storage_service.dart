import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/constants.dart';
import '../utils/logger.dart';

class SecureStorageService {
  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  // Save active examination session
  static Future<void> saveActiveExaminationSession(String sessionData) async {
    try {
      await _storage.write(
        key: AppConstants.activeExaminationSessionKey,
        value: sessionData,
      );
      AppLogger.log('Active examination session saved to secure storage');
    } catch (e) {
      AppLogger.error('Failed to save active examination session', e, null);
      rethrow;
    }
  }

  // Get active examination session
  static Future<String?> getActiveExaminationSession() async {
    try {
      final sessionData = await _storage.read(
        key: AppConstants.activeExaminationSessionKey,
      );
      AppLogger.log('Retrieved active examination session from secure storage');
      return sessionData;
    } catch (e) {
      AppLogger.error('Failed to get active examination session', e, null);
      return null;
    }
  }

  // Clear active examination session
  static Future<void> clearActiveExaminationSession() async {
    try {
      await _storage.delete(key: AppConstants.activeExaminationSessionKey);
      AppLogger.log('Cleared active examination session from secure storage');
    } catch (e) {
      AppLogger.error('Failed to clear active examination session', e, null);
      rethrow;
    }
  }

  // Save completed examinations
  static Future<void> saveCompletedExaminations(String examinationsData) async {
    try {
      await _storage.write(
        key: AppConstants.completedExaminationsKey,
        value: examinationsData,
      );
      AppLogger.log('Completed examinations saved to secure storage');
    } catch (e) {
      AppLogger.error('Failed to save completed examinations', e, null);
      rethrow;
    }
  }

  // Get completed examinations
  static Future<String?> getCompletedExaminations() async {
    try {
      final examinationsData = await _storage.read(
        key: AppConstants.completedExaminationsKey,
      );
      AppLogger.log('Retrieved completed examinations from secure storage');
      return examinationsData;
    } catch (e) {
      AppLogger.error('Failed to get completed examinations', e, null);
      return null;
    }
  }

  // Clear all secure storage (for testing or reset)
  static Future<void> clearAll() async {
    try {
      await _storage.deleteAll();
      AppLogger.log('Cleared all secure storage');
    } catch (e) {
      AppLogger.error('Failed to clear secure storage', e, null);
      rethrow;
    }
  }
}
