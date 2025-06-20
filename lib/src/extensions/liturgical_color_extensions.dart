import 'package:flutter/material.dart';
import 'package:liturgical_calendar/liturgical_calendar.dart';
import '../providers/theme_providers.dart';

/// Extension to get liturgical colors as Flutter colors with intensity variations
extension LiturgicalColorExtension on LiturgicalColor {
  Color toFlutterColor([ColorIntensity intensity = ColorIntensity.vibrant]) {
    switch (this) {
      case LiturgicalColor.green:
        return intensity == ColorIntensity.vibrant 
            ? const Color(0xFF00C853) // Bright vibrant green
            : const Color(0xFF6B8E56); // Muted forest green
      case LiturgicalColor.purple:
        return intensity == ColorIntensity.vibrant 
            ? const Color(0xFF9C27B0) // Bright vibrant purple
            : const Color(0xFF6B4C93); // Muted purple
      case LiturgicalColor.rose:
        return intensity == ColorIntensity.vibrant 
            ? const Color(0xFFE91E63) // Bright vibrant pink/rose
            : const Color(0xFFD4A5A5); // Muted dusty rose
      case LiturgicalColor.white:
        return intensity == ColorIntensity.vibrant 
            ? const Color(0xFF2196F3) // Bright blue (for visibility)
            : const Color(0xFF7D8691); // Muted blue-grey
      case LiturgicalColor.red:
        return intensity == ColorIntensity.vibrant 
            ? const Color(0xFFD32F2F) // Bright vibrant red
            : const Color(0xFFB85450); // Muted burgundy red
      case LiturgicalColor.gold:
        return intensity == ColorIntensity.vibrant 
            ? const Color(0xFFFFB300) // Bright vibrant gold
            : const Color(0xFFB8860B); // Muted dark goldenrod
    }
  }

  Color toFlutterColorWithOpacity(double opacity, [ColorIntensity intensity = ColorIntensity.vibrant]) {
    return toFlutterColor(intensity).withValues(alpha: opacity);
  }
}

/// Extension to convert string liturgical colors to Flutter colors (for backward compatibility)
extension StringLiturgicalColorExtension on String {
  Color toLiturgicalColor([ColorIntensity intensity = ColorIntensity.vibrant]) {
    final liturgicalColor = LiturgicalColor.fromString(this);
    if (liturgicalColor != null) {
      return liturgicalColor.toFlutterColor(intensity);
    }

    // Fallback for unknown colors
    return intensity == ColorIntensity.vibrant 
        ? const Color(0xFF9C27B0) // Default bright purple
        : const Color(0xFF6B4C93); // Muted default purple
  }

  Color toLiturgicalColorWithOpacity(double opacity, [ColorIntensity intensity = ColorIntensity.vibrant]) {
    return toLiturgicalColor(intensity).withValues(alpha: opacity);
  }
}