/// Application-wide constants for Sancta Via
class AppConstants {
  // App Information
  static const String appName = 'Sancta Via';
  static const String appVersion = '1.0.0';
  static const String appDescription = 'A Catholic lifestyle app';

  // Timing Constants
  static const int autoSaveIntervalSeconds = 10;
  static const Duration loadingTimeout = Duration(seconds: 10);

  // Storage Keys
  static const String activeSessionKey = 'active_examination_session';
  static const String completedSessionsKey = 'completed_examination_sessions';
  static const String examinationPreferencesKey = 'examination_preferences';
  static const String settingsKey = 'app_settings';
  static const String themeKey = 'theme_mode';
  static const String liturgicalColorsKey = 'use_liturgical_colors';
  static const String fontSizeKey = 'font_size';

  // Asset Paths
  static const String examinationsFolder = 'assets/examinations/';
  static const String prayersFolder = 'assets/prayers/';
  static const String imagesFolder = 'assets/images/';
  static const String iconsFolder = 'assets/icons/';

  // File Names
  static const String examinationsMetadataFile = 'examinations_metadata.json';
  static const String prayersMetadataFile = 'prayers_metadata.json';

  // Security - Enhanced for production
  static const int pinLength = 6; // Fixed 6-character PIN
  static const int maxPinAttempts = 3; // Max attempts before lockout
  static const int pinLockoutMinutes = 5; // Lockout duration after max attempts
  static const int sessionTimeoutMinutes = 15; // Session timeout

  // Legacy constants for backwards compatibility
  @Deprecated('Use pinLength instead')
  static const int minPinLength = 6;
  @Deprecated('Use pinLength instead')
  static const int maxPinLength = 6;

  // UI Constants
  static const double cardElevation = 2.0;
  static const double cardBorderRadius = 16.0;
  static const double buttonBorderRadius = 8.0;
  static const double defaultPadding = 16.0;
  static const double defaultMargin = 8.0;

  // Font Scale Limits
  static const double minFontScale = 0.8;
  static const double maxFontScale = 1.5;
  static const double defaultFontScale = 1.0;

  // Grid Layout
  static const int homeGridCrossAxisCount = 2;
  static const double homeGridChildAspectRatio = 0.9;
  static const double homeGridSpacing = 16.0;

  // Error Messages
  static const String genericErrorMessage =
      'An unexpected error occurred. Please try again.';
  static const String networkErrorMessage =
      'Please check your internet connection and try again.';
  static const String sessionExpiredMessage =
      'Your session has expired. Please start a new examination.';
  static const String pinIncorrectMessage = 'Incorrect PIN. Please try again.';
  static const String maxAttemptsMessage =
      'Too many failed attempts. Please wait before trying again.';
  static const String pinLockedMessage =
      'PIN entry is temporarily locked due to multiple failed attempts.';

  // Feature Flags (for beta testing)
  static const bool enablePinFeature = false;
  static const bool enableAnalytics = false;
  static const bool enableCrashReporting = false;
  static const bool enableBetaFeatures = true;
}

/// Prayer-specific constants
class PrayerConstants {
  static const List<String> categories = [
    'Essential',
    'Morning',
    'Evening',
    'Marian',
    'Saints',
    'Liturgical',
  ];

  static const List<String> tags = [
    'Traditional',
    'Modern',
    'Latin',
    'Devotional',
    'Seasonal',
  ];
}

/// Examination-specific constants
class ExaminationConstants {
  static const List<String> targetAudiences = [
    'Adults',
    'Teens',
    'Children',
    'Married Couples',
    'Religious',
    'General',
  ];

  static const int maxNoteLength = 500;
  static const int sessionAutoSaveInterval = 30; // seconds
}

/// Liturgical constants
class LiturgicalConstants {
  static const List<String> seasons = [
    'Advent',
    'Christmas',
    'Ordinary Time',
    'Lent',
    'Easter',
  ];

  static const List<String> colors = [
    'Green',
    'Purple',
    'White',
    'Red',
    'Rose',
    'Gold',
  ];
}
