import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sancta_via_liturgical_calendar_riverpod/sancta_via_liturgical_calendar_riverpod.dart';
import 'package:bible_data_riverpod/bible_data_riverpod.dart';

import 'package:bible_reading_app/screens/verse_selection/verse_selection_screen.dart';

/// Verse tiles for a chapter whose numbering is contiguous (1..15): the
/// selection grid must show exactly scripture.verses.length tiles, each
/// labeled with its TRUE number.
final List<BibleVerse> contiguousFixtureVerses = List<BibleVerse>.generate(15, (
  int index,
) {
  return BibleVerse(number: index + 1, text: kjvGenesis1[index]);
});

/// Compact realistic whole-chapter text: each verse prefixed with its true
/// number, mirroring how BibleService derives the display text.
final String contiguousFixtureText = contiguousFixtureVerses
    .map((BibleVerse verse) => '${verse.number} ${verse.text}')
    .join(' ');

/// Fixture verses with a deliberate numbering gap (1, 5, 7) so the grid can
/// be asserted to use the TRUE numbers from [ScriptureContent.verses] instead
/// of numbering tiles positionally (which would render 1, 2, 3).
const List<BibleVerse> gappedFixtureVerses = <BibleVerse>[
  BibleVerse(number: 1, text: 'Alpha text.'),
  BibleVerse(number: 5, text: 'Beta says 12 (5 + 7) done.'),
  BibleVerse(number: 7, text: 'Gamma text.'),
];

const String gappedFixtureText =
    '1 Alpha text. 5 Beta says 12 (5 + 7) done. 7 Gamma text.';

/// Compact realistic 1..15 fixture (KJV Genesis 1:1-15; digit-free verse
/// texts so the text itself does not introduce spurious numbers).
const List<String> kjvGenesis1 = <String>[
  'In the beginning God created the heaven and the earth.',
  'And the earth was without form, and void; and darkness was upon the face of the deep. And the Spirit of God moved upon the face of the waters.',
  'And God said, Let there be light: and there was light.',
  'And God saw the light, that it was good: and God divided the light from the darkness.',
  'And God called the light Day, and the darkness he called Night. And the evening and the morning were the first day.',
  'And God said, Let there be a firmament in the midst of the waters, and let it divide the waters from the waters.',
  'And God made the firmament, and divided the waters which were under the firmament from the waters which were above the firmament: and it was so.',
  'And God called the firmament Heaven. And the evening and the morning were the second day.',
  'And God said, Let the waters under the heaven be gathered together unto one place, and let the dry land appear: and it was so.',
  'And God called the dry land Earth; and the gathering together of the waters called he Seas: and God saw that it was good.',
  'And God said, Let the earth bring forth grass, the herb yielding seed, and the fruit tree yielding fruit after his kind, whose seed is in itself, upon the earth: and it was so.',
  'And the earth brought forth grass, and herb yielding seed after his kind, and the tree yielding fruit, whose seed was in itself, after his kind: and God saw that it was good.',
  'And the evening and the morning were the third day.',
  'And God said, Let there be lights in the firmament of the heaven to divide the day from the night; and let them be for signs, and for seasons, and for days, and years:',
  'And let them be for lights in the firmament of the heaven to give light upon the earth: and it was so.',
];

ScriptureContent fixtureContent(List<BibleVerse> verses, String text) {
  return ScriptureContent.found(
    reference: ScriptureReference.chapter('Genesis', 1),
    text: text,
    translation: BibleTranslation.cpdv,
    verses: verses,
  );
}

void main() {
  /// Pumps the verse selection screen through a minimal GoRouter (so
  /// [VerseSelectionScreen] can context.push the chapter route like it does
  /// in the app) with an overridden scripture provider so the grid renders
  /// exactly the fixture's structured verses.
  Future<void> pumpScreen(
    WidgetTester tester, {
    required ScriptureContent content,
    required GoRouter router,
  }) {
    SharedPreferences.setMockInitialValues({});
    return tester.pumpWidget(
      ProviderScope(
        overrides: [
          // Replace the periodic liturgical date stream with a synchronous
          // single-value stream so no lingering Timer survives teardown (same
          // trick as test/widget_test.dart and the Task 7 screen tests).
          currentDateProvider.overrideWith(
            (ref) => Stream.value(DateTime.now()),
          ),
          // Non-optimized provider (the one this screen consumes). Overriding
          // it means no Bible service/database is ever touched.
          scriptureByReferenceProvider.overrideWith(
            (ref, params) async => content,
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
  }

  /// Test router mirroring the app route shapes: the screen is rendered at
  /// /verse-selection/:bookName/:chapter, and the /chapter/:bookName/:chapter
  /// route it pushes to reports the pushed location (query included) via
  /// [onChapterRoutePushed], so the navigation can be asserted to carry the
  /// TRUE verse number.
  GoRouter testRouter({void Function(String location)? onChapterRoutePushed}) {
    return GoRouter(
      initialLocation: '/verse-selection/Genesis/1',
      routes: [
        GoRoute(
          path: '/verse-selection/:bookName/:chapter',
          builder: (BuildContext context, GoRouterState state) {
            return VerseSelectionScreen(
              bookName: Uri.decodeComponent(state.pathParameters['bookName']!),
              chapter: int.parse(state.pathParameters['chapter']!),
            );
          },
        ),
        GoRoute(
          path: '/chapter/:bookName/:chapter',
          builder: (BuildContext context, GoRouterState state) {
            onChapterRoutePushed?.call(state.uri.toString());
            return const Scaffold(body: Text('Chapter screen probe'));
          },
        ),
      ],
    );
  }

  /// The verse tiles of the grid (every tile is a Card with an InkWell).
  Finder gridTiles() {
    return find.descendant(
      of: find.byType(GridView),
      matching: find.byType(InkWell),
    );
  }

  group('VerseSelectionScreen structured verses', () {
    testWidgets('renders 15 tiles with true numbers for a 1..15 chapter', (
      WidgetTester tester,
    ) async {
      await pumpScreen(
        tester,
        content: fixtureContent(contiguousFixtureVerses, contiguousFixtureText),
        router: testRouter(),
      );
      await tester.pumpAndSettle();

      // Grid item count comes from scripture.verses.length (15), NOT from a
      // positional re-parse of the flattened text.
      expect(gridTiles(), findsNWidgets(15));
      expect(find.text('Genesis 1 has 15 verses'), findsOneWidget);
      for (int verseNumber = 1; verseNumber <= 15; verseNumber++) {
        expect(find.text('$verseNumber'), findsOneWidget);
      }
    });

    testWidgets(
      'renders gap-chapter tiles 1, 5, 7 and navigates with verse 5',
      (WidgetTester tester) async {
        await pumpScreen(
          tester,
          content: fixtureContent(gappedFixtureVerses, gappedFixtureText),
          router: testRouter(),
        );
        await tester.pumpAndSettle();

        // Exactly the 3 structured verses; NOT renumbered 1, 2, 3.
        expect(gridTiles(), findsNWidgets(3));
        expect(find.text('1'), findsOneWidget);
        expect(find.text('5'), findsOneWidget);
        expect(find.text('7'), findsOneWidget);
        expect(find.text('2'), findsNothing);
        expect(find.text('3'), findsNothing);
      },
    );

    testWidgets('tapping the tile labeled 5 navigates carrying verse 5', (
      WidgetTester tester,
    ) async {
      String? capturedTargetUri;
      await pumpScreen(
        tester,
        content: fixtureContent(gappedFixtureVerses, gappedFixtureText),
        router: testRouter(
          onChapterRoutePushed: (String location) =>
              capturedTargetUri = location,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('5'), findsOneWidget);
      await tester.tap(find.text('5'));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('Chapter screen probe'), findsOneWidget);
      // The pushed location must carry the TRUE verse number 5, not a
      // positionally derived one.
      expect(capturedTargetUri, '/chapter/Genesis/1?startVerse=5');
    });
  });
}
