import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import "package:novena_companion/config/routes.dart";
import "package:novena_companion/main.dart";
import 'package:sancta_via_liturgical_calendar_riverpod/sancta_via_liturgical_calendar_riverpod.dart';

import 'helpers/platform_mocks.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(const {});
    installNovenaPlatformMocks(TestDefaultBinaryMessengerBinding.instance);
  });

  Widget appUnderTest() {
    // Override the periodic date stream from the shared liturgical calendar
    // package with a synchronous single-value stream so no lingering Timer
    // remains after test teardown (house pattern).
    return ProviderScope(
      overrides: [
        currentDateProvider.overrideWith(
          (ref) => Stream.value(DateTime(2026, 11, 12)),
        ),
      ],
      child: const NovenaCompanionApp(),
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

    // The database-backed routes keep async work alive; bounded pumping
    // proves the router mounted the screens instead of waiting for an
    // artificial quiescence.
    appRouter.go('/novenas');
    await tester.pump();
    for (var i = 0; i < 24; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.text('Page Not Found'), findsNothing);

    appRouter.go('/settings');
    await tester.pump();
    for (var i = 0; i < 24; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.text('Page Not Found'), findsNothing);

    appRouter.go('/');
    await tester.pumpAndSettle();
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
