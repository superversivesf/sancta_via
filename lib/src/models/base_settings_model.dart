import 'package:flutter/foundation.dart';

/// Text scaling mode for font size preferences
enum TextScalingMode {
  small(0.85, 'Small'),
  normal(1.0, 'Normal'), 
  large(1.15, 'Large'),
  extraLarge(1.3, 'Extra Large');

  const TextScalingMode(this.scaleFactor, this.displayName);
  
  final double scaleFactor;
  final String displayName;
}

/// Supported languages across Sancta Via apps
enum AppLanguage {
  english('English', 'en'),
  latin('Latin', 'la'),
  spanish('Spanish', 'es');

  const AppLanguage(this.displayName, this.code);
  
  final String displayName;
  final String code;
}

/// Base settings model that provides common settings for all Sancta Via apps.
/// Individual apps can extend this with their specific settings.
@immutable
class BaseSettingsModel {
  /// Font size for text content (in points)
  final double fontSize;
  
  /// Text scaling mode for accessibility
  final TextScalingMode textScalingMode;
  
  /// Default language for the app
  final AppLanguage defaultLanguage;
  
  /// Whether notifications are enabled
  final bool notificationsEnabled;
  
  /// Whether to show liturgical color indicators
  final bool showLiturgicalColors;
  
  /// Whether to enable haptic feedback
  final bool hapticFeedbackEnabled;
  
  /// Whether to reduce motion for accessibility
  final bool reduceMotion;

  const BaseSettingsModel({
    this.fontSize = 18.0,
    this.textScalingMode = TextScalingMode.normal,
    this.defaultLanguage = AppLanguage.english,
    this.notificationsEnabled = false,
    this.showLiturgicalColors = true,
    this.hapticFeedbackEnabled = true,
    this.reduceMotion = false,
  });

  /// Create default settings
  factory BaseSettingsModel.defaults() {
    return const BaseSettingsModel();
  }

  /// Create from JSON map
  factory BaseSettingsModel.fromJson(Map<String, dynamic> json) {
    // Parse text scaling mode
    TextScalingMode textScaling = TextScalingMode.normal;
    if (json['textScalingMode'] != null) {
      try {
        final index = json['textScalingMode'] as int;
        if (index >= 0 && index < TextScalingMode.values.length) {
          textScaling = TextScalingMode.values[index];
        }
      } catch (e) {
        // Keep default if parsing fails
      }
    }

    // Parse language
    AppLanguage language = AppLanguage.english;
    if (json['defaultLanguage'] != null) {
      try {
        final languageCode = json['defaultLanguage'] as String;
        language = AppLanguage.values.firstWhere(
          (lang) => lang.code == languageCode,
          orElse: () => AppLanguage.english,
        );
      } catch (e) {
        // Keep default if parsing fails
      }
    }

    // Clamp font size to reasonable bounds
    double fontSize = (json['fontSize'] as num?)?.toDouble() ?? 18.0;
    fontSize = fontSize.clamp(12.0, 32.0);

    return BaseSettingsModel(
      fontSize: fontSize,
      textScalingMode: textScaling,
      defaultLanguage: language,
      notificationsEnabled: json['notificationsEnabled'] as bool? ?? false,
      showLiturgicalColors: json['showLiturgicalColors'] as bool? ?? true,
      hapticFeedbackEnabled: json['hapticFeedbackEnabled'] as bool? ?? true,
      reduceMotion: json['reduceMotion'] as bool? ?? false,
    );
  }

  /// Convert to JSON map
  Map<String, dynamic> toJson() {
    return {
      'fontSize': fontSize,
      'textScalingMode': textScalingMode.index,
      'defaultLanguage': defaultLanguage.code,
      'notificationsEnabled': notificationsEnabled,
      'showLiturgicalColors': showLiturgicalColors,
      'hapticFeedbackEnabled': hapticFeedbackEnabled,
      'reduceMotion': reduceMotion,
    };
  }

  /// Create a copy with updated values
  BaseSettingsModel copyWith({
    double? fontSize,
    TextScalingMode? textScalingMode,
    AppLanguage? defaultLanguage,
    bool? notificationsEnabled,
    bool? showLiturgicalColors,
    bool? hapticFeedbackEnabled,
    bool? reduceMotion,
  }) {
    return BaseSettingsModel(
      fontSize: fontSize ?? this.fontSize,
      textScalingMode: textScalingMode ?? this.textScalingMode,
      defaultLanguage: defaultLanguage ?? this.defaultLanguage,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      showLiturgicalColors: showLiturgicalColors ?? this.showLiturgicalColors,
      hapticFeedbackEnabled: hapticFeedbackEnabled ?? this.hapticFeedbackEnabled,
      reduceMotion: reduceMotion ?? this.reduceMotion,
    );
  }

  /// Get the effective text scale factor combining both fontSize and textScalingMode
  double get effectiveTextScaleFactor {
    // Base scale from the scaling mode
    double baseScale = textScalingMode.scaleFactor;
    
    // Additional scale from font size (relative to 18pt baseline)
    double fontScale = fontSize / 18.0;
    
    return baseScale * fontScale;
  }

  /// Get font size label for UI display
  String get fontSizeLabel {
    if (fontSize <= 12) return 'Smallest';
    if (fontSize <= 14) return 'Smaller';
    if (fontSize <= 16) return 'Small';
    if (fontSize <= 18) return 'Normal';
    if (fontSize <= 20) return 'Large';
    if (fontSize <= 24) return 'Larger';
    return 'Largest';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BaseSettingsModel &&
        other.fontSize == fontSize &&
        other.textScalingMode == textScalingMode &&
        other.defaultLanguage == defaultLanguage &&
        other.notificationsEnabled == notificationsEnabled &&
        other.showLiturgicalColors == showLiturgicalColors &&
        other.hapticFeedbackEnabled == hapticFeedbackEnabled &&
        other.reduceMotion == reduceMotion;
  }

  @override
  int get hashCode {
    return Object.hash(
      fontSize,
      textScalingMode,
      defaultLanguage,
      notificationsEnabled,
      showLiturgicalColors,
      hapticFeedbackEnabled,
      reduceMotion,
    );
  }

  @override
  String toString() {
    return 'BaseSettingsModel('
        'fontSize: $fontSize, '
        'textScalingMode: $textScalingMode, '
        'defaultLanguage: $defaultLanguage, '
        'notificationsEnabled: $notificationsEnabled, '
        'showLiturgicalColors: $showLiturgicalColors, '
        'hapticFeedbackEnabled: $hapticFeedbackEnabled, '
        'reduceMotion: $reduceMotion'
        ')';
  }
}
