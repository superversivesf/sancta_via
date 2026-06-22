import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sancta_via_liturgical_calendar_riverpod/sancta_via_liturgical_calendar_riverpod.dart';

import 'package:bible_reading_app/main.dart';

void main() {
  testWidgets('Bible Reading App smoke test', (WidgetTester tester) async {
    // The app launches via AppWrapper, which shows the OnboardingScreen
    // (title "Sancta Via Bible") until onboarding completes and the Bible
    // service has loaded. Ensure a clean SharedPreferences state so the
    // onboarding screen is the first thing rendered.
    SharedPreferences.setMockInitialValues({});

    // Override the periodic date stream from the shared liturgical calendar
    // package with a synchronous single-value stream so no lingering Timer
    // remains after the test framework tears down the widget tree.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentDateProvider.overrideWith((ref) => Stream.value(DateTime.now())),
        ],
        child: const BibleReadingApp(),
      ),
    );

    // Allow the first frame to render (the onboarding screen builds
    // synchronously on the initial route '/').
    await tester.pump();

    // Verify that the app loads and renders the onboarding title that is
    // shown to first-time users. The "Bible Reading App" AppBar title only
    // appears on the HomeScreen after onboarding completes.
    expect(find.text('Sancta Via Bible'), findsOneWidget);

    // Let any pending onboarding timers (Future.delayed in
    // OnboardingNotifier._initializeBibleDatabase) flush out so the test
    // binding does not fail on pending timers during teardown.
    await tester.pumpAndSettle(const Duration(seconds: 1));
  });
}