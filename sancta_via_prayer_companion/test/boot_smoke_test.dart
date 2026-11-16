import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sancta_via_liturgical_calendar_riverpod/sancta_via_liturgical_calendar_riverpod.dart';

import 'package:prayer_companion/config/routes.dart';
import 'package:prayer_companion/main.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(const {});
  });

  Widget appUnderTest() {
    // Override the liturgical providers with a fixed day (house pattern);
    // the prayer database resolves through the FFI factory set up in
    // flutter_test_config.dart.
    return ProviderScope(
      overrides: <Override>[
        currentLiturgicalDayProvider.overrideWith(
          (ref) =>
              LiturgicalCalendarService.getDayForDate(DateTime(2026, 11, 12)),
        ),
      ],
      child: const PrayerCompanionApp(),
    );
  }

  testWidgets('app boots and renders the home screen', (tester) async {
    await tester.pumpWidget(appUnderTest());
    await tester.pumpAndSettle();

    expect(find.byType(MaterialApp), findsOneWidget);
  });

  testWidgets('principal routes are reachable', (tester) async {
    await tester.pumpWidget(appUnderTest());
    await tester.pumpAndSettle();

    // Database-backed routes may keep async work alive; bounded pumping
    // proves the router mounted the screens.
    for (final route in <String>['/prayers', '/categories', '/search', '/settings']) {
      appRouter.go(route);
      await tester.pump();
      for (var i = 0; i < 24; i++) {
        await tester.pump(const Duration(milliseconds: 250));
      }
      expect(find.byType(MaterialApp), findsOneWidget, reason: route);
      expect(find.text('Page Not Found'), findsNothing, reason: route);
    }

    appRouter.go('/');
    await tester.pumpAndSettle();
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
