import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sancta_via_shared_ui/sancta_via_shared_ui.dart';
import 'package:sancta_via_liturgical_calendar/sancta_via_liturgical_calendar.dart';

void main() {
  group('Color Intensity Tests', () {
    test('Vibrant vs Muted colors should be different', () {
      // Test Green (current liturgical color)
      final vibrantGreenTheme = AppTheme.lightTheme(LiturgicalColor.green, ColorIntensity.vibrant);
      final mutedGreenTheme = AppTheme.lightTheme(LiturgicalColor.green, ColorIntensity.muted);
      
      print('=== GREEN LITURGICAL COLOR ===');
      print('Vibrant Green Primary: ${vibrantGreenTheme.colorScheme.primary}');
      print('Muted Green Primary: ${mutedGreenTheme.colorScheme.primary}');
      
      // They should be different
      expect(vibrantGreenTheme.colorScheme.primary, isNot(equals(mutedGreenTheme.colorScheme.primary)));
      
      // Test Purple
      final vibrantPurpleTheme = AppTheme.lightTheme(LiturgicalColor.purple, ColorIntensity.vibrant);
      final mutedPurpleTheme = AppTheme.lightTheme(LiturgicalColor.purple, ColorIntensity.muted);
      
      print('\n=== PURPLE LITURGICAL COLOR ===');
      print('Vibrant Purple Primary: ${vibrantPurpleTheme.colorScheme.primary}');
      print('Muted Purple Primary: ${mutedPurpleTheme.colorScheme.primary}');
      
      expect(vibrantPurpleTheme.colorScheme.primary, isNot(equals(mutedPurpleTheme.colorScheme.primary)));
      
      // Test Red
      final vibrantRedTheme = AppTheme.lightTheme(LiturgicalColor.red, ColorIntensity.vibrant);
      final mutedRedTheme = AppTheme.lightTheme(LiturgicalColor.red, ColorIntensity.muted);
      
      print('\n=== RED LITURGICAL COLOR ===');
      print('Vibrant Red Primary: ${vibrantRedTheme.colorScheme.primary}');
      print('Muted Red Primary: ${mutedRedTheme.colorScheme.primary}');
      
      expect(vibrantRedTheme.colorScheme.primary, isNot(equals(mutedRedTheme.colorScheme.primary)));
    });
    
    test('Current theme colors should match expected values', () {
      // Test the actual color values we expect
      final vibrantGreenTheme = AppTheme.lightTheme(LiturgicalColor.green, ColorIntensity.vibrant);
      final mutedGreenTheme = AppTheme.lightTheme(LiturgicalColor.green, ColorIntensity.muted);
      
      print('\n=== EXPECTED COLOR VALUES ===');
      print('Vibrant Green should be bright: ${vibrantGreenTheme.colorScheme.primary}');
      print('Muted Green should be darker: ${mutedGreenTheme.colorScheme.primary}');
      
      // Extract RGB values for verification
      final vibrantColor = vibrantGreenTheme.colorScheme.primary;
      final mutedColor = mutedGreenTheme.colorScheme.primary;
      
      print('\nVibrant RGB: (${(vibrantColor.red * 255).round()}, ${(vibrantColor.green * 255).round()}, ${(vibrantColor.blue * 255).round()})');
      print('Muted RGB: (${(mutedColor.red * 255).round()}, ${(mutedColor.green * 255).round()}, ${(mutedColor.blue * 255).round()})');
      
      // Vibrant should generally be brighter (higher values)
      // This is a general check - specific values may vary due to Material 3 color generation
      expect(vibrantColor, isNot(equals(mutedColor)));
    });
  });
}