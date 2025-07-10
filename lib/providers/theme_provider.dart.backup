import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/theme.dart' as local_theme;
import '../features/settings/providers/novena_app_settings_provider.dart';
import 'liturgical_calendar_provider.dart';

// Theme mode state notifier
class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier() : super(ThemeMode.system) { // Default to system mode
    _loadThemeMode();
  }

  Future<void> _loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    // Default to system mode (index 0) if no preference saved
    final themeIndex = prefs.getInt('themeMode') ?? 0; // ThemeMode.system.index = 0
    
    // Handle invalid indices gracefully
    if (themeIndex >= 0 && themeIndex < ThemeMode.values.length) {
      state = ThemeMode.values[themeIndex];
    } else {
      // Invalid index, default to system mode and clear the invalid preference
      state = ThemeMode.system;
      await prefs.setInt('themeMode', ThemeMode.system.index);
    }
  }

  Future<void> setThemeMode(ThemeMode themeMode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('themeMode', themeMode.index);
    state = themeMode;
  }
}

// Provider for theme mode
final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier();
});

// Liturgical color override for preview (with color style override)
final liturgicalColorOverrideProvider = StateNotifierProvider<LiturgicalColorOverrideNotifier, LiturgicalColorOverride?>((ref) {
  return LiturgicalColorOverrideNotifier();
});

class LiturgicalColorOverride {
  final LiturgicalColor color;
  final local_theme.ColorSchemeStyle? styleOverride;

  LiturgicalColorOverride(this.color, {this.styleOverride});
}

class LiturgicalColorOverrideNotifier extends StateNotifier<LiturgicalColorOverride?> {
  LiturgicalColorOverrideNotifier() : super(null);

  void setColorOverride(LiturgicalColor? color, {local_theme.ColorSchemeStyle? styleOverride}) {
    state = color != null ? LiturgicalColorOverride(color, styleOverride: styleOverride) : null;
  }
}

// Light theme provider
final lightThemeProvider = Provider<ThemeData>((ref) {
  final override = ref.watch(liturgicalColorOverrideProvider);
  final liturgicalColor = ref.watch(activeLiturgicalColorProvider);
  final novenaSettings = ref.watch(novenaAppSettingsProvider);

  // Determine which color to use
  final LiturgicalColor colorToUse;
  final local_theme.ColorSchemeStyle colorStyleToUse;

  if (override != null) {
    // Preview mode - use the override color and style
    colorToUse = override.color;
    colorStyleToUse = override.styleOverride ?? 
        (novenaSettings.showLiturgicalColors ? local_theme.ColorSchemeStyle.vibrant : local_theme.ColorSchemeStyle.muted);
  } else {
    // Normal mode - use liturgical colors
    colorToUse = liturgicalColor;
    colorStyleToUse = novenaSettings.showLiturgicalColors ? local_theme.ColorSchemeStyle.vibrant : local_theme.ColorSchemeStyle.muted;
  }

  return local_theme.AppTheme.getLightTheme(colorToUse, colorStyle: colorStyleToUse);
});

// Dark theme provider
final darkThemeProvider = Provider<ThemeData>((ref) {
  final override = ref.watch(liturgicalColorOverrideProvider);
  final liturgicalColor = ref.watch(activeLiturgicalColorProvider);
  final novenaSettings = ref.watch(novenaAppSettingsProvider);

  // Determine which color to use
  final LiturgicalColor colorToUse;
  final local_theme.ColorSchemeStyle colorStyleToUse;

  if (override != null) {
    // Preview mode - use the override color and style
    colorToUse = override.color;
    colorStyleToUse = override.styleOverride ?? 
        (novenaSettings.showLiturgicalColors ? local_theme.ColorSchemeStyle.vibrant : local_theme.ColorSchemeStyle.muted);
  } else {
    // Normal mode - use liturgical colors
    colorToUse = liturgicalColor;
    colorStyleToUse = novenaSettings.showLiturgicalColors ? local_theme.ColorSchemeStyle.vibrant : local_theme.ColorSchemeStyle.muted;
  }

  return local_theme.AppTheme.getDarkTheme(colorToUse, colorStyle: colorStyleToUse);
});

// Legacy active theme provider for backward compatibility
final activeThemeProvider = Provider<ThemeData>((ref) {
  final themeMode = ref.watch(themeModeProvider);
  
  // For backward compatibility, return light theme by default
  // The main.dart should use lightThemeProvider and darkThemeProvider instead
  return themeMode == ThemeMode.dark
      ? ref.watch(darkThemeProvider)
      : ref.watch(lightThemeProvider);
});
