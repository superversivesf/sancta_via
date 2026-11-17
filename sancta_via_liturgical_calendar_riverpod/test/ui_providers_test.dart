import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sancta_via_liturgical_calendar/sancta_via_liturgical_calendar.dart';
import 'package:sancta_via_liturgical_calendar_riverpod/src/providers/ui_providers.dart';
import 'package:sancta_via_liturgical_calendar_riverpod/src/providers/liturgical_providers.dart';
import 'package:sancta_via_shared_ui/sancta_via_shared_ui.dart';

void main() {
  group('UI Providers - Colors', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('liturgicalColorProvider returns a valid Color', () {
      final color = container.read(liturgicalColorProvider);
      expect(color, isA<Color>());
    });

    test('liturgicalColorByDateProvider returns valid color for date', () {
      final christmas = DateTime(2025, 12, 25);
      final color = container.read(liturgicalColorByDateProvider(christmas));
      expect(color, isA<Color>());
    });

    test('liturgicalColorByDateProvider returns white color for Christmas', () {
      final christmas = DateTime(2025, 12, 25);
      final color = container.read(liturgicalColorByDateProvider(christmas));
      final day = container.read(liturgicalDayProvider(christmas));
      expect(day?.celebration.color.toUpperCase(), equals('WHITE'));
      // WHITE color uses vibrant blue (0xFF2196F3) for visibility
      expect(color, equals(LiturgicalColor.white.toFlutterColor()));
    });
  });

  group('UI Providers - Theme', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('liturgicalThemeProvider returns valid ThemeData', () {
      final theme = container.read(liturgicalThemeProvider);
      expect(theme, isA<ThemeData>());
      expect(theme.colorScheme, isA<ColorScheme>());
    });
  });

  group('UI Providers - Display', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('currentCelebrationDisplayProvider returns string', () {
      final display = container.read(currentCelebrationDisplayProvider);
      expect(display, isA<String>());
      expect(display.isNotEmpty, isTrue);
    });

    test('liturgicalInfoProvider returns info map', () {
      final info = container.read(liturgicalInfoProvider);
      expect(info, isA<Map<String, String>>());
      expect(info['date'], isNotNull);
      expect(info['celebration'], isNotNull);
      expect(info['season'], isNotNull);
    });
  });

  group('UI Providers - Upcoming', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('upcomingCelebrationsUIProvider returns formatted list', () {
      final upcoming = container.read(upcomingCelebrationsUIProvider);
      expect(upcoming, isA<List<Map<String, String>>>());
      for (final item in upcoming) {
        expect(item['date'], isNotNull);
        expect(item['name'], isNotNull);
        expect(item['rank'], isNotNull);
        expect(item['daysUntil'], isNotNull);
      }
    });
  });

  group('UI Providers - Calendar State', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('liturgicalCalendarStateProvider returns state map', () {
      final state = container.read(liturgicalCalendarStateProvider);
      expect(state, isA<Map<String, dynamic>>());
      expect(state['hasData'], isA<bool>());
      expect(state['liturgicalColor'], isA<Color>());
      expect(state['upcomingCount'], isA<int>());
    });
  });

  group('UI Providers - Icons', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('seasonIconProvider returns valid IconData', () {
      final icon = container.read(seasonIconProvider);
      expect(icon, isA<IconData>());
    });

    test('rankIconProvider returns valid IconData', () {
      final icon = container.read(rankIconProvider);
      expect(icon, isA<IconData>());
    });
  });

  group('UI Providers - Notifications', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('liturgicalNotificationProvider returns map or null', () {
      final notification = container.read(liturgicalNotificationProvider);
      if (notification != null) {
        expect(notification['title'], isA<String>());
        expect(notification['subtitle'], isA<String>());
        expect(notification['color'], isA<Color>());
        expect(notification['priority'], isA<String>());
      }
    });
  });
}
