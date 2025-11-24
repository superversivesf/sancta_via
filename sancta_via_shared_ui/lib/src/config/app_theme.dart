import 'package:flutter/material.dart';
import 'package:sancta_via_liturgical_calendar/sancta_via_liturgical_calendar.dart';
import '../providers/theme_providers.dart';

class AppTheme {
  /// Creates a light theme with optional liturgical color accent and color intensity
  static ThemeData lightTheme([LiturgicalColor? liturgicalColor, ColorIntensity intensity = ColorIntensity.vibrant]) {
    final primaryColor = _getLiturgicalMaterialColor(liturgicalColor, intensity);
    
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        brightness: Brightness.light,
      ),
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      // Custom typography for liturgical content
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontFamily: 'Crimson',
          fontWeight: FontWeight.bold,
        ),
        headlineMedium: TextStyle(
          fontFamily: 'Crimson',
          fontWeight: FontWeight.bold,
        ),
        titleLarge: TextStyle(
          fontFamily: 'Crimson',
          fontWeight: FontWeight.w600,
        ),
        titleMedium: TextStyle(
          fontFamily: 'Crimson',
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  /// Creates a dark theme with optional liturgical color accent and color intensity
  static ThemeData darkTheme([LiturgicalColor? liturgicalColor, ColorIntensity intensity = ColorIntensity.vibrant]) {
    final primaryColor = _getLiturgicalMaterialColor(liturgicalColor, intensity);
    
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        brightness: Brightness.dark,
      ),
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      // Custom typography for liturgical content
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontFamily: 'Crimson',
          fontWeight: FontWeight.bold,
        ),
        headlineMedium: TextStyle(
          fontFamily: 'Crimson',
          fontWeight: FontWeight.bold,
        ),
        titleLarge: TextStyle(
          fontFamily: 'Crimson',
          fontWeight: FontWeight.w600,
        ),
        titleMedium: TextStyle(
          fontFamily: 'Crimson',
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  /// Converts liturgical color to Material Color with intensity variation
  static Color _getLiturgicalMaterialColor([LiturgicalColor? liturgicalColor, ColorIntensity intensity = ColorIntensity.vibrant]) {
    if (liturgicalColor == null) {
      return intensity == ColorIntensity.vibrant 
          ? const Color(0xFF9C27B0) // Default bright purple
          : const Color(0xFF6B4C93); // Muted default purple
    }

    switch (liturgicalColor) {
      case LiturgicalColor.green:
        return intensity == ColorIntensity.vibrant 
            ? const Color(0xFF00C853) // Bright green
            : const Color(0xFF6B8E56); // Muted forest green
      case LiturgicalColor.purple:
        return intensity == ColorIntensity.vibrant 
            ? const Color(0xFF9C27B0) // Bright purple
            : const Color(0xFF6B4C93); // Muted purple
      case LiturgicalColor.rose:
        return intensity == ColorIntensity.vibrant 
            ? const Color(0xFFE91E63) // Bright pink/rose
            : const Color(0xFFD4A5A5); // Muted dusty rose
      case LiturgicalColor.white:
        return intensity == ColorIntensity.vibrant 
            ? const Color(0xFF2196F3) // Bright blue for visibility
            : const Color(0xFF7D8691); // Muted blue-grey
      case LiturgicalColor.red:
        return intensity == ColorIntensity.vibrant 
            ? const Color(0xFFD32F2F) // Bright red
            : const Color(0xFFB85450); // Muted burgundy red
      case LiturgicalColor.gold:
        return intensity == ColorIntensity.vibrant 
            ? const Color(0xFFFFB300) // Bright gold
            : const Color(0xFFB8860B); // Muted dark goldenrod
    }
  }
}