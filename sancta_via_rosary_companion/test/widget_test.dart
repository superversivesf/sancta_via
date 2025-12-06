import 'package:flutter_test/flutter_test.dart';

import 'package:sancta_via_rosary_companion/main.dart';

void main() {
  testWidgets('Home screen loads correctly', (WidgetTester tester) async {
    await tester.pumpWidget(const RosaryApp());

    expect(find.text('Rosary Companion'), findsOneWidget);
    expect(find.text('Home Screen - Under Construction'), findsOneWidget);
  });
}
