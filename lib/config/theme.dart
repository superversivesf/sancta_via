import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/liturgical_calendar_provider.dart';

// Color scheme options
enum ColorSchemeStyle {
  vibrant,
  muted,
}

// Liturgical color scheme mapping
class LiturgicalColorScheme {
  /// Get liturgical color with style variant
  static Color getLiturgicalColor(LiturgicalColor color, {ColorSchemeStyle style = ColorSchemeStyle.vibrant}) {
    switch (color) {
      case LiturgicalColor.green:
        return style == ColorSchemeStyle.muted 
            ? const Color(0xFF6B8E56) // Muted forest green
            : const Color(0xFF4CAF50); // Vibrant green for Ordinary Time
      case LiturgicalColor.purple:
        return style == ColorSchemeStyle.muted 
            ? const Color(0xFF6B4C93) // Muted purple
            : const Color(0xFF7B1FA2); // Vibrant purple for Advent/Lent
      case LiturgicalColor.rose:
        return style == ColorSchemeStyle.muted 
            ? const Color(0xFFD4A5A5) // Muted dusty rose
            : const Color(0xFFE91E63); // Vibrant rose for Gaudete/Laetare
      case LiturgicalColor.white:
        return style == ColorSchemeStyle.muted 
            ? const Color(0xFF7D8691) // Muted blue-grey
            : const Color(0xFF2196F3); // Blue for Christmas/Easter (better than white for UI)
      case LiturgicalColor.red:
        return style == ColorSchemeStyle.muted 
            ? const Color(0xFFB85450) // Muted burgundy red
            : const Color(0xFFE53935); // Vibrant red for Pentecost/martyrs
      case LiturgicalColor.gold:
        return style == ColorSchemeStyle.muted 
            ? const Color(0xFFB8860B) // Muted dark goldenrod
            : const Color(0xFFFFB300); // Vibrant gold for high feasts
    }
  }

  /// Get color from hex string (for custom colors)
  static Color getColorFromHex(String hexColor) {
    final hex = hexColor.replaceAll('#', '');
    
    if (hex.length == 3) {
      final expandedHex = hex.split('').map((char) => char + char).join();
      return Color(int.parse('FF$expandedHex', radix: 16));
    }
    
    if (hex.length == 6) {
      return Color(int.parse('FF$hex', radix: 16));
    }
    
    if (hex.length == 8) {
      return Color(int.parse(hex, radix: 16));
    }
    
    // Fallback to green if invalid hex
    return const Color(0xFF4CAF50);
  }
}

// Theme configuration for the app
class AppTheme {
  static ThemeData getLightTheme(LiturgicalColor liturgicalColor, {ColorSchemeStyle colorStyle = ColorSchemeStyle.vibrant}) {
    final primaryColor = LiturgicalColorScheme.getLiturgicalColor(liturgicalColor, style: colorStyle);

    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.light(
        primary: primaryColor,
        secondary: primaryColor.withValues(alpha: 0.7),
        onPrimary: Colors.white,
        surface: Colors.white,
        surfaceContainerHighest: const Color(0xFFF5F5F5),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      textTheme: GoogleFonts.merriweatherTextTheme(
        ThemeData.light().textTheme,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }

  static ThemeData getDarkTheme(LiturgicalColor liturgicalColor, {ColorSchemeStyle colorStyle = ColorSchemeStyle.vibrant}) {
    final primaryColor = LiturgicalColorScheme.getLiturgicalColor(liturgicalColor, style: colorStyle);

    return ThemeData.dark().copyWith(
      colorScheme: ColorScheme.dark(
        primary: primaryColor,
        secondary: primaryColor.withValues(alpha: 0.7),
        onPrimary: Colors.white,
        surface: const Color(0xFF1E1E1E),
        surfaceContainerHighest: const Color(0xFF2C2C2C),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: const Color(0xFF1E1E1E),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        elevation: 4,
        color: const Color(0xFF2C2C2C),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      textTheme: GoogleFonts.merriweatherTextTheme(
        ThemeData.dark().textTheme,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }
}
