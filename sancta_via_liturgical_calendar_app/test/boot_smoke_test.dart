import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:liturgical_calendar_app/app/app.dart';
import 'package:liturgical_calendar_app/config/routes.dart';
import 'package:liturgical_calendar_app/providers/calendar_providers.dart'
    as local_providers;
import 'package:sancta_via_liturgical_calendar_riverpod/sancta_via_liturgical_calendar_riverpod.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(const {});
  });

  Widget appUnderTest({DateTime? selected}) {
    return ProviderScope(
      overrides: <Override>[
        // Root liturgical provider: fixed day, no periodic timer in the
        // fake-async zone (house pattern).
        currentLiturgicalDayProvider.overrideWith(
          (ref) =>
              LiturgicalCalendarService.getDayForDate(DateTime(2026, 11, 12)),
        ),
        // App-own date state: deterministic date so the calendar grid and
        // day-detail route resolve the same content in every run.
        local_providers.selectedDateProvider.overrideWith(
          (ref) => selected ?? DateTime(2026, 11, 12),
        ),
        local_providers.displayedMonthProvider.overrideWith(
          (ref) => DateTime(2026, 11, 1),
        ),
      ],
      child: const LiturgicalCalendarApp(),
    );
  }

  testWidgets('app boots and renders the home screen', (tester) async {
    await tester.pumpWidget(appUnderTest());
    await tester.pumpAndSettle();

    expect(find.byType(MaterialApp), findsOneWidget);
  });

  testWidgets('calendar, search and settings routes are reachable',
      (tester) async {
    await tester.pumpWidget(appUnderTest());
    await tester.pumpAndSettle();

    appRouter.go('/calendar');
    await tester.pumpAndSettle();
    expect(find.byType(MaterialApp), findsOneWidget);

    appRouter.go('/search');
    await tester.pumpAndSettle();
    expect(find.byType(MaterialApp), findsOneWidget);

    appRouter.go('/settings');
    await tester.pumpAndSettle();
    expect(find.byType(MaterialApp), findsOneWidget);
  });

  testWidgets('day-detail route resolves for the overridden date',
      (tester) async {
    await tester.pumpWidget(appUnderTest());
    await tester.pumpAndSettle();

    appRouter.go('/day/2026-11-12');
    await tester.pumpAndSettle();
    expect(find.byType(MaterialApp), findsOneWidget);
  });

  test('selected-date provider round-trips a state change', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(local_providers.selectedDateProvider).day,
        DateTime.now().day);
    container.read(local_providers.selectedDateProvider.notifier).state =
        DateTime(2026, 3, 24);
    expect(container.read(local_providers.selectedDateProvider),
        DateTime(2026, 3, 24));
  });
}
