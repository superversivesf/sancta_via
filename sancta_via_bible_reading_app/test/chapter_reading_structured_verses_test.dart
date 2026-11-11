import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sancta_via_liturgical_calendar_riverpod/sancta_via_liturgical_calendar_riverpod.dart';
import 'package:bible_data_riverpod/bible_data_riverpod.dart';

import 'package:bible_reading_app/screens/chapter/chapter_reading_screen.dart';

/// Fixture verses with a deliberate numbering gap (1, 5, 7) so the screen can
/// be asserted to render the TRUE verse numbers from
/// [OptimizedScriptureContent.verses] instead of re-parsing the flattened
/// chapter text positionally.
const List<BibleVerse> fixtureVerses = [
  BibleVerse(number: 1, text: 'Alpha text.'),
  BibleVerse(number: 5, text: 'Beta says 12 (5 + 7) done.'),
  BibleVerse(number: 7, text: 'Gamma text.'),
];

final OptimizedScriptureContent fixtureContent =
    OptimizedScriptureContent.found(
      reference: ScriptureReference.chapter('Genesis', 1),
      text: '1 Alpha text. 5 Beta says 12 (5 + 7) done. 7 Gamma text.',
      translation: BibleTranslation.cpdv,
      verses: fixtureVerses,
    );

void main() {
  /// Pumps the chapter reading screen with an overridden scripture provider so
  /// the screen renders exactly the three structured verses above.
  Future<void> pumpScreen(WidgetTester tester) {
    SharedPreferences.setMockInitialValues({});
    return tester.pumpWidget(
      ProviderScope(
        overrides: [
          // Replace the periodic liturgical date stream with a synchronous
          // single-value stream so no lingering Timer survives teardown (same
          // trick as test/widget_test.dart).
          currentDateProvider.overrideWith(
            (ref) => Stream.value(DateTime.now()),
          ),
          // No Bible service/database needed: both provider families are
          // overridden, so the screen renders only from the fixture.
          optimizedChapterCountProvider.overrideWith((ref, params) async => 50),
          optimizedScriptureByReferenceProvider.overrideWith(
            (ref, params) async => fixtureContent,
          ),
        ],
        child: const MaterialApp(
          home: ChapterReadingScreen(bookName: 'Genesis', chapter: 1),
        ),
      ),
    );
  }

  /// True for the RichText of a verse row: a root span whose first child is
  /// the standalone verse-number span (e.g. '1 ') followed by the verse text.
  bool isVerseRow(Widget widget) {
    if (widget is! RichText) {
      return false;
    }
    final InlineSpan root = widget.text;
    if (root is! TextSpan) {
      return false;
    }
    final List<InlineSpan> children = root.children ?? const <InlineSpan>[];
    if (children.length != 2) {
      return false;
    }
    final InlineSpan numberSpan = children.first;
    return numberSpan is TextSpan &&
        numberSpan.text != null &&
        int.tryParse(numberSpan.text!.trim()) != null;
  }

  /// The verse rows of the screen, in display order.
  List<RichText> verseRows(WidgetTester tester) {
    return tester
        .widgetList<RichText>(find.byWidgetPredicate(isVerseRow))
        .toList();
  }

  /// The bold leading verse-number span of a verse row.
  TextSpan numberSpanOf(RichText row) {
    final TextSpan root = row.text as TextSpan;
    return root.children!.first as TextSpan;
  }

  group('ChapterReadingScreen structured verses', () {
    testWidgets('renders the true verse numbers from structured verses', (
      WidgetTester tester,
    ) async {
      await pumpScreen(tester);
      await tester.pumpAndSettle();

      final List<RichText> rows = verseRows(tester);
      expect(rows, hasLength(3)); // gap 5 -> 7 must NOT be renumbered 1, 2, 3
      expect(numberSpanOf(rows[0]).text, '1 ');
      expect(numberSpanOf(rows[1]).text, '5 ');
      expect(numberSpanOf(rows[2]).text, '7 ');
      // Bold leading number style preserved as today.
      expect(numberSpanOf(rows[0]).style?.fontWeight, FontWeight.bold);
      expect(rows[0].text.toPlainText(), '1 Alpha text.');
      expect(rows[1].text.toPlainText(), '5 Beta says 12 (5 + 7) done.');
      expect(rows[2].text.toPlainText(), '7 Gamma text.');
    });

    testWidgets('copies the true verse number when a row is tapped', (
      WidgetTester tester,
    ) async {
      String? clipboardContents;
      tester.binding.defaultBinaryMessenger.setMockMessageHandler(
        SystemChannels.platform.name,
        (ByteData? message) async {
          final MethodCall call = const JSONMethodCodec().decodeMethodCall(
            message,
          );
          if (call.method == 'Clipboard.setData') {
            final Map<Object?, Object?> args =
                call.arguments as Map<Object?, Object?>;
            clipboardContents = args['text'] as String?;
          }
          return const JSONMethodCodec().encodeSuccessEnvelope(null);
        },
      );

      await pumpScreen(tester);
      await tester.pumpAndSettle();

      final Finder row2 = find.byWidgetPredicate(
        (widget) =>
            widget is RichText &&
            isVerseRow(widget) &&
            widget.text.toPlainText().contains('Beta says 12 (5 + 7)'),
      );
      expect(row2, findsOneWidget);
      await tester.tap(row2);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(clipboardContents, isNotNull);
      expect(clipboardContents, contains('(Genesis 1:5, '));

      // Flush the snackbar's dismissal timer so teardown has no pending timers.
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
    });
  });
}
