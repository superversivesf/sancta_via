import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sancta_via_devotionals/main.dart';

void main() {
  testWidgets('root widget renders the Sancta Via Devotionals app bar', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: SanctaViaDevotionalsApp()),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AppBar), findsOneWidget);
    expect(find.text('Sancta Via Devotionals'), findsOneWidget);
  });
}
