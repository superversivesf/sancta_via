import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bible_reading_app/main.dart';

void main() {
  testWidgets('Bible Reading App smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const ProviderScope(child: BibleReadingApp()));

    // Verify that our app loads
    expect(find.text('Bible Reading'), findsOneWidget);
  });
}
