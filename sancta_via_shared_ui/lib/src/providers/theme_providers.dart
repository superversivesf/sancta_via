import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Enum for color intensity preferences
enum ColorIntensity {
  vibrant,
  muted;

  String get displayName {
    switch (this) {
      case ColorIntensity.vibrant:
        return 'Vibrant';
      case ColorIntensity.muted:
        return 'Muted';
    }
  }
}

// Theme mode state notifier with persistence
class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier() : super(ThemeMode.system) {
    _loadThemeMode();
  }

  Future<void> _loadThemeMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final themeIndex = prefs.getInt('themeMode') ?? ThemeMode.system.index;

      // Handle invalid indices gracefully
      if (themeIndex >= 0 && themeIndex < ThemeMode.values.length) {
        state = ThemeMode.values[themeIndex];
      } else {
        // Invalid index, default to system and clear the invalid preference
        state = ThemeMode.system;
        await prefs.setInt('themeMode', ThemeMode.system.index);
      }
    } catch (e) {
      // If loading fails, keep default
      state = ThemeMode.system;
    }
  }

  Future<void> setThemeMode(ThemeMode themeMode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('themeMode', themeMode.index);
      state = themeMode;
    } catch (e) {
      // If saving fails, still update state for current session
      state = themeMode;
    }
  }
}

// Color intensity state notifier with persistence
class ColorIntensityNotifier extends StateNotifier<ColorIntensity> {
  ColorIntensityNotifier() : super(ColorIntensity.vibrant) {
    _loadColorIntensity();
  }

  Future<void> _loadColorIntensity() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final intensityIndex =
          prefs.getInt('colorIntensity') ?? ColorIntensity.vibrant.index;

      // Handle invalid indices gracefully
      if (intensityIndex >= 0 &&
          intensityIndex < ColorIntensity.values.length) {
        state = ColorIntensity.values[intensityIndex];
      } else {
        // Invalid index, default to vibrant and clear the invalid preference
        state = ColorIntensity.vibrant;
        await prefs.setInt('colorIntensity', ColorIntensity.vibrant.index);
      }
    } catch (e) {
      // If loading fails, keep default
      state = ColorIntensity.vibrant;
    }
  }

  Future<void> setColorIntensity(ColorIntensity intensity) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('colorIntensity', intensity.index);
      state = intensity;
    } catch (e) {
      // If saving fails, still update state for current session
      state = intensity;
    }
  }
}

// Theme mode provider with persistence
final themeModeProvider =
    StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier();
});

// Color intensity provider with persistence
final colorIntensityProvider =
    StateNotifierProvider<ColorIntensityNotifier, ColorIntensity>((ref) {
  return ColorIntensityNotifier();
});
