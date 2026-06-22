// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sancta_via_liturgical_calendar_riverpod/sancta_via_liturgical_calendar_riverpod.dart';

import 'package:novena_companion/main.dart';

void main() {
  testWidgets('App starts correctly', (WidgetTester tester) async {
    // Override the periodic date stream from the shared liturgical calendar
    // package with a synchronous single-value stream so no lingering Timer
    // remains after the test framework tears down the widget tree.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentDateProvider.overrideWith((ref) => Stream.value(DateTime.now())),
        ],
        child: const NovenaCompanionApp(),
      ),
    );

    // Pump past initial routing (GoRouter performs async navigation).
    await tester.pumpAndSettle();

    // Verify that the app title appears in the home screen AppBar.
    expect(find.text('Novena Companion'), findsOneWidget);
  });
}