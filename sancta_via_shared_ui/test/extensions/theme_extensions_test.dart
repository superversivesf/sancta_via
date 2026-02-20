import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sancta_via_shared_ui/src/extensions/theme_extensions.dart';

void main() {
  group('ThemeModeExtension', () {
    test('displayName returns correct strings', () {
      expect(ThemeMode.system.displayName, equals('System'));
      expect(ThemeMode.light.displayName, equals('Light'));
      expect(ThemeMode.dark.displayName, equals('Dark'));
    });

    test('all theme modes have display names', () {
      for (final mode in ThemeMode.values) {
        expect(mode.displayName, isNotEmpty);
      }
    });
  });

  group('StringExtension', () {
    test('capitalize capitalizes first letter', () {
      expect('hello'.capitalize(), equals('Hello'));
      expect('world'.capitalize(), equals('World'));
    });

    test('capitalize handles empty string', () {
      expect(''.capitalize(), equals(''));
    });

    test('capitalize handles single character', () {
      expect('a'.capitalize(), equals('A'));
    });

    test('capitalize does not change already capitalized', () {
      expect('Hello'.capitalize(), equals('Hello'));
    });
  });
}
