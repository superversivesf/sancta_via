import 'package:bible_data/bible_data.dart';

/// DEPRECATED: Model for app settings
/// 
/// This class is deprecated in favor of the new unified settings system.
/// Use BibleAppSettings from '../models/bible_app_settings.dart' instead.
/// 
/// This class is maintained for backward compatibility only.
@Deprecated('Use BibleAppSettings with the unified settings system instead')
class AppSettings {
  final double fontSize;
  final BibleTranslation selectedBibleTranslation;

  const AppSettings({
    required this.fontSize,
    required this.selectedBibleTranslation,
  });

  /// Create default settings
  factory AppSettings.defaults() {
    return const AppSettings(
      fontSize: 18.0,
      selectedBibleTranslation: BibleTranslation.cpdv,
    );
  }

  /// Create copy with updated values
  AppSettings copyWith({
    double? fontSize,
    BibleTranslation? selectedBibleTranslation,
  }) {
    return AppSettings(
      fontSize: fontSize ?? this.fontSize,
      selectedBibleTranslation: selectedBibleTranslation ?? this.selectedBibleTranslation,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AppSettings &&
        other.fontSize == fontSize &&
        other.selectedBibleTranslation == selectedBibleTranslation;
  }

  @override
  int get hashCode {
    return Object.hash(fontSize, selectedBibleTranslation);
  }
}
