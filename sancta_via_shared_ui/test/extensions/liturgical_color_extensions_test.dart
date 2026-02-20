import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sancta_via_liturgical_calendar/sancta_via_liturgical_calendar.dart';
import 'package:sancta_via_shared_ui/src/extensions/liturgical_color_extensions.dart';
import 'package:sancta_via_shared_ui/src/providers/theme_providers.dart';

void main() {
  group('LiturgicalColorExtension', () {
    test('toFlutterColor returns vibrant colors by default', () {
      expect(
        LiturgicalColor.green.toFlutterColor(),
        equals(LiturgicalColor.green.toFlutterColor(ColorIntensity.vibrant)),
      );
    });

    test('toFlutterColor returns different colors for different intensities',
        () {
      for (final color in LiturgicalColor.values) {
        final vibrant = color.toFlutterColor(ColorIntensity.vibrant);
        final muted = color.toFlutterColor(ColorIntensity.muted);
        expect(vibrant, isNot(equals(muted)),
            reason: '$color should have different vibrant/muted colors');
      }
    });

    test('toFlutterColorWithOpacity applies opacity correctly', () {
      final color = LiturgicalColor.green.toFlutterColorWithOpacity(0.5);
      expect(color.alpha, equals(128)); // 0.5 * 255 ≈ 128
    });

    test('all liturgical colors have valid Flutter colors', () {
      for (final color in LiturgicalColor.values) {
        final vibrant = color.toFlutterColor(ColorIntensity.vibrant);
        final muted = color.toFlutterColor(ColorIntensity.muted);
        expect(vibrant.alpha, equals(255));
        expect(muted.alpha, equals(255));
      }
    });
  });

  group('StringLiturgicalColorExtension', () {
    test('toLiturgicalColor converts valid color names', () {
      expect(
        'green'.toLiturgicalColor(),
        equals(LiturgicalColor.green.toFlutterColor()),
      );
      expect(
        'purple'.toLiturgicalColor(),
        equals(LiturgicalColor.purple.toFlutterColor()),
      );
      expect(
        'red'.toLiturgicalColor(),
        equals(LiturgicalColor.red.toFlutterColor()),
      );
    });

    test('toLiturgicalColor returns fallback for invalid names', () {
      final result = 'invalid'.toLiturgicalColor();
      final fallback = const Color(0xFF9C27B0);
      expect(result, equals(fallback));
    });

    test('toLiturgicalColorWithOpacity applies opacity correctly', () {
      final color = 'green'.toLiturgicalColorWithOpacity(0.7);
      expect(color.alpha, equals(179)); // 0.7 * 255 ≈ 179
    });
  });
}
