import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:sancta_via_rosary_companion/models/color_intensity.dart';

void main() {
  group('ColorIntensity', () {
    test('should have correct number of values', () {
      expect(ColorIntensity.values.length, 3);
    });

    test('should have correct display names', () {
      expect(ColorIntensity.normal.displayName, 'Normal');
      expect(ColorIntensity.vivid.displayName, 'Vivid');
      expect(ColorIntensity.subdued.displayName, 'Subdued');
    });

    test('fromString should return correct ColorIntensity', () {
      expect(ColorIntensity.fromString('normal'), ColorIntensity.normal);
      expect(ColorIntensity.fromString('Normal'), ColorIntensity.normal);
      expect(ColorIntensity.fromString('vivid'), ColorIntensity.vivid);
      expect(ColorIntensity.fromString('Vivid'), ColorIntensity.vivid);
      expect(ColorIntensity.fromString('subdued'), ColorIntensity.subdued);
      expect(ColorIntensity.fromString('Subdued'), ColorIntensity.subdued);
    });

    test('fromString should return default normal for unknown string', () {
      expect(ColorIntensity.fromString('unknown'), ColorIntensity.normal);
      expect(ColorIntensity.fromString(''), ColorIntensity.normal);
      expect(ColorIntensity.fromString('bright'), ColorIntensity.normal);
    });

    test('applyToColor should return original color for normal intensity', () {
      const testColor = Color(0xFF123456);
      final result = ColorIntensity.normal.applyToColor(testColor);
      expect(result, testColor);
    });

    test('applyToColor should return vivid color with full opacity', () {
      const testColor = Color(0x80123456);
      final result = ColorIntensity.vivid.applyToColor(testColor);
      expect(result.alpha, 255);
      expect(result.red, 0x12);
      expect(result.green, 0x34);
      expect(result.blue, 0x56);
    });

    test('applyToColor should return subdued color with reduced opacity', () {
      const testColor = Color(0xFF123456);
      final result = ColorIntensity.subdued.applyToColor(testColor);
      expect(result.alpha, 153);
      expect(result.red, 0x12);
      expect(result.green, 0x34);
      expect(result.blue, 0x56);
    });
  });
}
