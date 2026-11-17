import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/screens/calendar/calendar_screen.dart';
import '../lib/providers/calendar_providers.dart'
    as local_providers;
import 'package:sancta_via_liturgical_calendar/sancta_via_liturgical_calendar.dart';
import 'package:intl/intl.dart';
import 'package:mocktail/mocktail.dart';

// Mocks
class MockLiturgicalCalendarService extends Mock
    implements LiturgicalCalendarService {}

void main() {
  group('CalendarScreen', () {

    testWidgets('renders correctly and shows current month',
        (WidgetTester tester) async {
      final testDate = DateTime(2025, 12, 25);

      // Build our app and trigger a frame.
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            local_providers.displayedMonthProvider
                .overrideWith((ref) => testDate),
            local_providers.selectedDateProvider.overrideWith((ref) => testDate),
            local_providers.monthLiturgicalDaysProvider
                .overrideWith((ref) => {}),
            local_providers.upcomingFeastsProvider.overrideWith((ref) => []),
            local_providers.liturgicalDayForDateProvider(testDate)
                .overrideWith((ref) => null),
          ],
          child: const MaterialApp(
            home: CalendarScreen(),
          ),
        ),
      );

      // Verify that the app bar title is correct.
      expect(find.text('Liturgical Calendar'), findsOneWidget);

      // Verify that the current month and year are displayed.
      expect(find.text(DateFormat('MMMM yyyy').format(testDate)), findsOneWidget);
    });
      testWidgets('tapping "Go to today" button resets to current month',
        (WidgetTester tester) async {
      final initialDate = DateTime(2025, 1, 1);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      final container = ProviderContainer(
        overrides: [
          local_providers.displayedMonthProvider
              .overrideWith((ref) => initialDate),
          local_providers.selectedDateProvider.overrideWith((ref) => initialDate),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: CalendarScreen(),
          ),
        ),
      );

      // Verify that the initial month is displayed.
      expect(find.text(DateFormat('MMMM yyyy').format(initialDate)),
          findsOneWidget);

      // Tap the "Go to today" button.
      await tester.tap(find.byIcon(Icons.today));
      await tester.pump();

      // Verify that the displayed month is updated to the current month.
      final expectedMonth = DateTime(today.year, today.month, 1);
      expect(container.read(local_providers.displayedMonthProvider),
          expectedMonth);
      expect(container.read(local_providers.selectedDateProvider), today);
    });
  testWidgets('tapping "previous month" button updates the displayed month',
        (WidgetTester tester) async {
      final initialDate = DateTime(2025, 3, 15);
      final container = ProviderContainer(
        overrides: [
          local_providers.displayedMonthProvider
              .overrideWith((ref) => initialDate),
          local_providers.selectedDateProvider.overrideWith((ref) => initialDate),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: CalendarScreen(),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.chevron_left));
      await tester.pump();

      final expectedMonth = DateTime(initialDate.year, initialDate.month - 1, 1);
      expect(
          container.read(local_providers.displayedMonthProvider), expectedMonth);
    });

    testWidgets('tapping "next month" button updates the displayed month',
        (WidgetTester tester) async {
      final initialDate = DateTime(2025, 3, 15);
      final container = ProviderContainer(
        overrides: [
          local_providers.displayedMonthProvider
              .overrideWith((ref) => initialDate),
          local_providers.selectedDateProvider.overrideWith((ref) => initialDate),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: CalendarScreen(),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.chevron_right));
      await tester.pump();

      final expectedMonth = DateTime(initialDate.year, initialDate.month + 1, 1);
      expect(
          container.read(local_providers.displayedMonthProvider), expectedMonth);
    });
  });
}
