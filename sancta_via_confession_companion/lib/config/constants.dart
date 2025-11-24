import 'package:package_info_plus/package_info_plus.dart';

class AppConstants {
  static const String appName = 'Confession Companion';
  
  // Get app version dynamically from package info
  static Future<String> get appVersion async {
    final packageInfo = await PackageInfo.fromPlatform();
    return packageInfo.version;
  }
  
  // Storage keys
  static const String examinationPreferencesKey = 'examination_preferences';
  static const String settingsKey = 'app_settings';
  static const String themeKey = 'theme_settings';
  
  // Asset paths
  static const String examinationsMetadataFile = 'examinations_metadata.json';
  static const String examinationsFolder = 'examinations';
  
  // Secure storage keys
  static const String activeExaminationSessionKey = 'active_examination_session';
  static const String completedExaminationsKey = 'completed_examinations';
}
