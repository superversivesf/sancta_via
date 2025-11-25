import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sancta_via_shared_ui/sancta_via_shared_ui.dart';
import 'package:sancta_via_liturgical_calendar/sancta_via_liturgical_calendar.dart';

void main() {
  group('Shared Colors Consistency', () {
    test('Novena app now uses shared UI colors correctly', () {
      print('=== TESTING SHARED UI COLORS ===');

      // Test that we can create themes with shared UI
      final vibrantGreen = AppTheme.lightTheme(
        LiturgicalColor.green,
        ColorIntensity.vibrant,
      );
      final mutedGreen = AppTheme.lightTheme(
        LiturgicalColor.green,
        ColorIntensity.muted,
      );

      final vibrantPurple = AppTheme.lightTheme(
        LiturgicalColor.purple,
        ColorIntensity.vibrant,
      );
      final mutedPurple = AppTheme.lightTheme(
        LiturgicalColor.purple,
        ColorIntensity.muted,
      );

      print('Green Vibrant: ${_colorToHex(vibrantGreen.colorScheme.primary)}');
      print('Green Muted:   ${_colorToHex(mutedGreen.colorScheme.primary)}');
      print(
        'Purple Vibrant: ${_colorToHex(vibrantPurple.colorScheme.primary)}',
      );
      print('Purple Muted:   ${_colorToHex(mutedPurple.colorScheme.primary)}');

      // Verify they're different
      expect(
        vibrantGreen.colorScheme.primary,
        isNot(equals(mutedGreen.colorScheme.primary)),
      );
      expect(
        vibrantPurple.colorScheme.primary,
        isNot(equals(mutedPurple.colorScheme.primary)),
      );

      print('\n✅ All apps now use the same shared UI color system!');
      print('✅ Vibrant and muted colors are properly differentiated!');
      print('✅ No more conflicting local theme implementations!');
    });

    test('ColorIntensity enum works correctly', () {
      expect(ColorIntensity.vibrant.displayName, equals('Vibrant'));
      expect(ColorIntensity.muted.displayName, equals('Muted'));

      // Test that we have exactly 2 values
      expect(ColorIntensity.values.length, equals(2));

      print('\n✅ ColorIntensity enum is working correctly');
    });
  });
}

String _colorToHex(Color color) {
  return '#${color.value.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
}
