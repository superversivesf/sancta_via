import '../../../config/theme.dart';

class SettingsModel {
  final double fontSize;
  final bool hasPinCode;
  final ColorSchemeStyle colorSchemeStyle;

  SettingsModel({
    required this.fontSize,
    this.hasPinCode = false,
    this.colorSchemeStyle = ColorSchemeStyle.muted, // Default to muted colors
  });

  SettingsModel copyWith({
    double? fontSize,
    bool? hasPinCode,
    ColorSchemeStyle? colorSchemeStyle,
  }) {
    return SettingsModel(
      fontSize: fontSize ?? this.fontSize,
      hasPinCode: hasPinCode ?? this.hasPinCode,
      colorSchemeStyle: colorSchemeStyle ?? this.colorSchemeStyle,
    );
  }
}