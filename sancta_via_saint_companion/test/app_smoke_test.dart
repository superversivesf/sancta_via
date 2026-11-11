import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saint_companion/app/app.dart';
import 'package:saint_companion/config/routes.dart';
import 'package:sancta_via_liturgical_calendar_riverpod/sancta_via_liturgical_calendar_riverpod.dart';

void main() {
  testWidgets('SaintCompanionApp renders MaterialApp with Saints home header', (
    tester,
  ) async {
    // Override the liturgical color provider so the app never mounts
    // currentDateProvider's periodic timer in the fake-async test zone.
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          currentLiturgicalColorProvider.overrideWith((ref) => null),
        ],
        child: const SaintCompanionApp(),
      ),
    );

    // MaterialApp.router should be present
    expect(find.byType(MaterialApp), findsOneWidget);

    // Placeholder home shows a Text('Saints') header
    expect(find.text('Saints'), findsWidgets);
  });

  testWidgets('unknown route renders error screen with back-home affordance', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          currentLiturgicalColorProvider.overrideWith((ref) => null),
        ],
        child: const SaintCompanionApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Navigate to a bogus route
    appRouter.go('/nope');
    await tester.pumpAndSettle();

    // Back-home affordance must be rendered
    expect(find.byType(FilledButton), findsOneWidget);

    // Tapping it returns to home
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(find.text('Saints'), findsWidgets);
  });
}
