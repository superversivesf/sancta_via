import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:confession_companion/config/routes.dart';
import 'package:confession_companion/main.dart';
import 'package:sancta_via_liturgical_calendar_riverpod/sancta_via_liturgical_calendar_riverpod.dart';

import 'helpers/platform_mocks.dart';

void main() {
  Widget appUnderTest() {
    // Override the root liturgical-day provider with a fixed day so the app
    // never mounts currentDateProvider's periodic timer in the fake-async
    // zone (same house pattern as the saint companion smoke test).
    return ProviderScope(
      overrides: <Override>[
        currentLiturgicalDayProvider.overrideWith(
          (ref) =>
              LiturgicalCalendarService.getDayForDate(DateTime(2026, 11, 12)),
        ),
      ],
      child: const ConfessionCompanionApp(),
    );
  }

  setUp(() {
    SharedPreferences.setMockInitialValues(const {});
    installConfessionPlatformMocks(TestDefaultBinaryMessengerBinding.instance);
  });

  testWidgets('app boots and renders the home screen', (tester) async {
    await tester.pumpWidget(appUnderTest());
    await tester.pumpAndSettle();

    expect(find.byType(MaterialApp), findsOneWidget);
  });

  testWidgets('principal routes are reachable', (tester) async {
    await tester.pumpWidget(appUnderTest());
    await tester.pumpAndSettle();

    // The router is the single navigation surface; driving it directly keeps
    // the smoke independent of on-screen affordances. The list screen keeps
    // a periodic animation alive (theme/scroll), so settle with bounded
    // pumps instead of pumpAndSettle.
    appRouter.go('/examinations');
    await tester.pump();
    bool reached = false;
    for (var i = 0; i < 40 && !reached; i++) {
      await tester.pump(const Duration(milliseconds: 250));
      reached = find.text('Examination of Conscience').evaluate().isNotEmpty;
    }
    expect(reached, isTrue, reason: 'examinations list screen never appeared');

    appRouter.go('/');
    await tester.pump();
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
