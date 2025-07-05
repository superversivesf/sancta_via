import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/theme.dart';
import '../features/settings/providers/settings_providers.dart';
import 'liturgical_calendar_provider.dart';

// Theme mode state notifier
class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier() : super(ThemeMode.dark) { // Default to dark mode
    _loadThemeMode();
  }

  Future<void> _loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    // Default to dark mode (index 2) if no preference saved
    final themeIndex = prefs.getInt('themeMode') ?? 2; // ThemeMode.dark.index = 2
    
    // Handle invalid indices gracefully
    if (themeIndex >= 0 && themeIndex < ThemeMode.values.length) {
      state = ThemeMode.values[themeIndex];
    } else {
      // Invalid index, default to dark mode and clear the invalid preference
      state = ThemeMode.dark;
      await prefs.setInt('themeMode', ThemeMode.dark.index);
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
  final ColorSchemeStyle? styleOverride;

  LiturgicalColorOverride(this.color, {this.styleOverride});
}

class LiturgicalColorOverrideNotifier extends StateNotifier<LiturgicalColorOverride?> {
  LiturgicalColorOverrideNotifier() : super(null);

  void setColorOverride(LiturgicalColor? color, {ColorSchemeStyle? styleOverride}) {
    state = color != null ? LiturgicalColorOverride(color, styleOverride: styleOverride) : null;
  }
}

// Theme data provider that uses liturgical colors
final activeThemeProvider = Provider<ThemeData>((ref) {
  final themeMode = ref.watch(themeModeProvider);
  final override = ref.watch(liturgicalColorOverrideProvider);
  final liturgicalColor = ref.watch(activeLiturgicalColorProvider);
  final settings = ref.watch(settingsProvider);

  // Determine which color to use
  final LiturgicalColor colorToUse;
  final ColorSchemeStyle colorStyleToUse;

  if (override != null) {
    // Preview mode - use the override color and style
    colorToUse = override.color;
    colorStyleToUse = override.styleOverride ?? settings.colorSchemeStyle;
  } else {
    // Normal mode - use liturgical colors
    colorToUse = liturgicalColor;
    colorStyleToUse = settings.colorSchemeStyle;
  }

  // Generate theme based on current mode
  return themeMode == ThemeMode.dark
      ? AppTheme.getDarkTheme(colorToUse, colorStyle: colorStyleToUse)
      : AppTheme.getLightTheme(colorToUse, colorStyle: colorStyleToUse);
});
