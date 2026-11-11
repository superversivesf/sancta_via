// PatronageChip key contract (fix round 1).
//
// Ruling: the hardcoded `Key('patronage_chip')` could not survive more
// than one chip as siblings (Flutter's duplicate-key assertion). The
// default key now derives from the sanitized need and an explicit `key`
// constructor param overrides it.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saint_companion/widgets/patronage_chip.dart';
import 'package:saint_data/saint_data.dart';

void main() {
  testWidgets(
    'two sibling chips derive distinct keys from their sanitized needs',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Wrap(
              children: <Widget>[
                PatronageChip(
                  patronage: SaintPatronage(
                    need: 'lost items',
                    category: SaintCategory.everyday,
                  ),
                ),
                PatronageChip(
                  patronage: SaintPatronage(
                    need: 'day-laborers',
                    category: SaintCategory.jobs,
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      // Sanitized: lowercase, non-alphanumeric -> '_'.
      expect(
        find.byKey(const Key('patronage_chip_lost_items')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('patronage_chip_day_laborers')),
        findsOneWidget,
      );
      expect(find.byType(PatronageChip), findsNWidgets(2));
    },
  );

  testWidgets('an explicit key override wins over the derived key', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PatronageChip(
            patronage: SaintPatronage(
              need: 'lost items',
              category: SaintCategory.everyday,
            ),
            key: Key('custom_chip_key'),
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('custom_chip_key')), findsOneWidget);
    expect(find.byKey(const Key('patronage_chip_lost_items')), findsNothing);
  });
}
