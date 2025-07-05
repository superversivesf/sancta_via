import 'package:bible_data/bible_data.dart';

/// Model for app settings
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
