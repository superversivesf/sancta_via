import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sancta_via_devotionals/main.dart';
import 'package:sancta_via_devotionals/screens/home/today_screen.dart';
import 'package:sancta_via_liturgical_calendar_riverpod/sancta_via_liturgical_calendar_riverpod.dart'
    show currentDateProvider;

void main() {
  testWidgets('root widget renders the Today home route', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      // The Today screen's calendar provider derives from
      // `currentDateProvider`, whose production stream keeps a periodic
      // midnight timer — pending forever in a widget test. The ruled
      // harness pattern freezes it on a fixed day (Task 5/12; the smoke
      // scope stays otherwise real: no repository or settings overrides —
      // the home route mounts and shows its honest loading state).
      ProviderScope(
        overrides: <Override>[
          currentDateProvider.overrideWith(
            (Ref ref) => Stream<DateTime>.value(DateTime(2026, 12, 5)),
          ),
        ],
        child: const SanctaViaDevotionalsApp(),
      ),
    );
    // Fixed pumps, not `pumpAndSettle`: the Today screen's loading state is
    // a spinner (an animation `pumpAndSettle` can never settle), and the
    // smoke scope's assembly load stays pending — the smoke test only pins
    // that the app builds and mounts its real home screen.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(AppBar), findsOneWidget);
    expect(find.byType(TodayScreen), findsOneWidget);
    // Task 14's shell grew a NavigationBar whose Today destination label
    // carries the same string as the AppBar title — the pin now means "the
    // home route mounts under its own title" (present, not unique).
    expect(find.text('Today'), findsWidgets);
  });
}
