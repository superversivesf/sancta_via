// Search screen widget tests (Task 14).
//
// Harness (documented per the Task 13 report's real-time/fake-async
// resolver finding — futures resolved inside `tester.runAsync` complete in
// the binding's real-time zone and never resume under fake-async): a
// live-typing search screen creates a NEW saintSearchProvider family entry
// per keystroke, and the seeded repository's sqflite-FFI isolate replies
// never land inside the test's fake-async zone (prewarming every
// intermediate single-char key is not viable). So:
//
// - Interaction flows (live typing without debounce, submit, clear,
//   category narrowing, error surface) run through [_FakeSearchRepository]:
//   the Task-13 fakeResolver technique lifted to the search seam
//   (Fake-implements `SaintRepository`, `searchSaints` resolves canned
//   results through synchronously-completing futures, so every family
//   entry resolves under the test's fake-async zone).
// - Repository-behavior pins (which saint the REAL search resolver returns
//   for a query, tiered rationale values, the PatronageChip extra prefill
//   through the production route table) run against the shared seeded
//   fixture database (test/helpers/saint_fixture_db.dart) with ONLY the
//   provider keys under test prewarmed inside `tester.runAsync` (Task
//   11/12 pattern) — the widget phase then renders `AsyncData`
//   synchronously and `pumpAndSettle` is safe.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:saint_companion/config/routes.dart' show appRoutes;
import 'package:saint_companion/providers/saint_providers.dart';
import 'package:saint_companion/screens/search/search_screen.dart';
import 'package:saint_data/saint_data.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../helpers/saint_fixture_db.dart';

const Key _searchFieldKey = Key('search_field');
const Key _rationaleBadgeKey = Key('rationale_badge');

/// Canned saints for [_FakeSearchRepository] — full model objects (the
/// result tiles render name, first patronage, and rationale badge),
/// mirroring the seeded fixture's anthony/joan shapes.
const Saint _anthony = Saint(
  slug: 'anthony-of-padua',
  name: 'St. Anthony of Padua',
  feastDay: '06-13',
  bio: 'A Franciscan preacher who helps find lost things.',
  patronages: <SaintPatronage>[
    SaintPatronage(need: 'lost items', category: SaintCategory.everyday),
  ],
);

const Saint _joan = Saint(
  slug: 'joan-of-arc',
  name: 'St. Joan of Arc',
  feastDay: '05-30',
  bio: 'She rallied France after lost battles.',
  patronages: <SaintPatronage>[
    SaintPatronage(need: 'soldiers', category: SaintCategory.military),
  ],
);

SaintSearchResult _hit(Saint saint, String rationale) =>
    SaintSearchResult(saint: saint, matchRationale: rationale);

/// A repository whose [searchSaints] resolves canned results through a
/// synchronously-completing future (so the provider resolves under the
/// test's fake-async zone — see the file header), or fails when
/// [failSearch] is set (the error-state test). [calls] records every
/// `(query, category)` family key actually searched — the narrowing test
/// reads it to prove the provider key switched.
class _FakeSearchRepository extends Fake implements SaintRepository {
  _FakeSearchRepository({required this.resultsFor, this.failSearch = false});

  final List<SaintSearchResult> Function(String query, SaintCategory? category)
  resultsFor;
  final bool failSearch;

  final List<(String, SaintCategory?)> calls = <(String, SaintCategory?)>[];

  @override
  Future<void> ensureLoaded() async {}

  @override
  Future<List<SaintSearchResult>> searchSaints(
    String query, {
    SaintCategory? category,
    int limit = 100,
  }) {
    calls.add((query, category));
    if (failSearch) {
      return Future<List<SaintSearchResult>>.error(
        Exception('search index unavailable'),
      );
    }
    return Future<List<SaintSearchResult>>.value(
      List<SaintSearchResult>.of(resultsFor(query, category)),
    );
  }
}

/// Fake mapping for the live-typing test: only the exact query `lost`
/// resolves (Anthony via patronage), everything else is empty.
List<SaintSearchResult> _typingResults(String query, SaintCategory? category) {
  if (query == 'lost') {
    return <SaintSearchResult>[_hit(_anthony, 'patronage')];
  }
  return const <SaintSearchResult>[];
}

/// Fake mapping for the narrowing test: unfiltered `lost keys` returns both
/// saints (Anthony matched at the patronage tier, Joan at the name tier);
/// the military filter narrows to Joan only.
List<SaintSearchResult> _narrowingResults(
  String query,
  SaintCategory? category,
) {
  if (query != 'lost keys') {
    return const <SaintSearchResult>[];
  }
  if (category == SaintCategory.military) {
    return <SaintSearchResult>[_hit(_joan, 'patronage')];
  }
  if (category == null) {
    return <SaintSearchResult>[
      _hit(_anthony, 'patronage'),
      _hit(_joan, 'name'),
    ];
  }
  return const <SaintSearchResult>[];
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Database db;

  setUp(() async {
    // The search screen itself touches no settings state, but the
    // prefill test opens the saint detail screen (which records visits
    // through saintAppSettingsProvider) — mock its SharedPreferences
    // store (Task-13 precedent).
    SharedPreferences.setMockInitialValues(<String, Object>{});
    db = await createSeededDatabase();
  });

  tearDown(() async {
    await db.close();
  });

  /// Pumps [SearchScreen] over an `UncontrolledProviderScope` whose
  /// container carries the [repository] override. When [preWarmQueries] is
  /// set, those provider keys are resolved for real inside
  /// `tester.runAsync` BEFORE pumping (Task 11/12 harness — the keys under
  /// test land in the family cache, so the widget phase reads `AsyncData`
  /// synchronously; see the file header for why live typing cannot use
  /// this). With [preWarmSlugs], per-slug providers are resolved the same
  /// way (needed when [router] lands on the saint detail screen). With
  /// [router], the screen is reached through that router (initial location
  /// must be a route in [appRoutes]) so real navigation can be observed,
  /// mirroring the Task-12 chip-push harness.
  Future<ProviderContainer> pumpSearchScreen(
    WidgetTester tester, {
    required SaintRepository repository,
    List<(String, SaintCategory?)> preWarmQueries =
        const <(String, SaintCategory?)>[],
    List<String> preWarmSlugs = const <String>[],
    GoRouter? router,
  }) async {
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        saintRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);
    if (preWarmQueries.isNotEmpty || preWarmSlugs.isNotEmpty) {
      await tester.runAsync(() async {
        await Future.wait(<Future<dynamic>>[
          for (final (String, SaintCategory?) searchKey in preWarmQueries)
            container.read(saintSearchProvider(searchKey).future),
          for (final String slug in preWarmSlugs)
            container.read(saintBySlugProvider(slug).future),
        ]);
      });
    }
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: router == null
            ? const MaterialApp(home: SearchScreen())
            : MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets(
    'empty field shows the prompt and the 11 category chips with no results surface',
    (WidgetTester tester) async {
      await pumpSearchScreen(
        tester,
        repository: SaintRepository.forDatabase(db),
      );

      expect(find.byKey(_searchFieldKey), findsOneWidget);
      expect(find.byType(ChoiceChip), findsNWidgets(11)); // 'all' + 10
      expect(find.byKey(const Key('search_category_chip_all')), findsOneWidget);
      expect(
        find.byKey(const Key('search_category_chip_military')),
        findsOneWidget,
      );
      final ChoiceChip allChip = tester.widget<ChoiceChip>(
        find.byKey(const Key('search_category_chip_all')),
      );
      expect(allChip.selected, isTrue);

      // Idle (blank query): the prompt shows and NO live state renders —
      // the pinned empty state is for NO RESULTS, not for no query yet.
      expect(find.text('Search the saints.'), findsOneWidget);
      expect(find.byKey(const Key('search_loading_state')), findsNothing);
      expect(find.byKey(const Key('search_error_state')), findsNothing);
      expect(find.byKey(const Key('search_empty_state')), findsNothing);
      expect(find.byKey(_rationaleBadgeKey), findsNothing);
    },
  );

  testWidgets(
    'typing "lost keys" searches live and renders Anthony with a patronage rationale badge',
    (WidgetTester tester) async {
      await pumpSearchScreen(
        tester,
        repository: SaintRepository.forDatabase(db),
        preWarmQueries: const <(String, SaintCategory?)>[('lost keys', null)],
      );

      // enterText fires onChanged once with the full string; the screen
      // searches live on change (no submit keystroke involved).
      await tester.enterText(find.byKey(_searchFieldKey), 'lost keys');
      await tester.pump();

      // Real repository tiered results: Anthony at the patronage tier
      // ('lost items'), Joan joining via the bio tier ('lost battles').
      expect(
        find.byKey(const Key('search_result_anthony-of-padua')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('search_result_joan-of-arc')),
        findsOneWidget,
      );
      expect(find.text('St. Anthony of Padua'), findsOneWidget);

      // The pinned rationale badge: keyed, with the tier value as its text.
      expect(
        find.descendant(
          of: find.byKey(const Key('search_result_anthony-of-padua')),
          matching: find.byKey(_rationaleBadgeKey),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('search_result_anthony-of-padua')),
          matching: find.text('patronage'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('search_result_joan-of-arc')),
          matching: find.text('bio'),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('a query with no matches renders the search_empty_state', (
    WidgetTester tester,
  ) async {
    await pumpSearchScreen(
      tester,
      repository: SaintRepository.forDatabase(db),
      preWarmQueries: const <(String, SaintCategory?)>[('zzz nothing', null)],
    );

    await tester.enterText(find.byKey(_searchFieldKey), 'zzz nothing');
    await tester.pump();

    expect(find.byKey(const Key('search_empty_state')), findsOneWidget);
    expect(find.text('No saints found.'), findsOneWidget);
    // No tiles or badges render through the empty state.
    expect(
      find.byKey(const Key('search_result_anthony-of-padua')),
      findsNothing,
    );
    expect(find.byKey(_rationaleBadgeKey), findsNothing);
  });

  testWidgets(
    'patronage chip push through the production routes prefills the query and searches immediately',
    (WidgetTester tester) async {
      // Task-12 chip-push harness, now landing on the REAL search screen:
      // navigate through the production route table from the saint detail
      // screen (whose PatronageChip pushes '/search' with extra: need) and
      // observe the destination content + matched location.
      final GoRouter router = GoRouter(
        routes: appRoutes,
        initialLocation: '/saints/anthony-of-padua',
      );
      await pumpSearchScreen(
        tester,
        repository: SaintRepository.forDatabase(db),
        preWarmQueries: const <(String, SaintCategory?)>[('lost items', null)],
        preWarmSlugs: const <String>['anthony-of-padua'],
        router: router,
      );
      expect(
        router.routerDelegate.currentConfiguration.last.matchedLocation,
        '/saints/anthony-of-padua',
      );

      // The chip sits below the fold of the detail screen's scroll view —
      // bring it into view so the tap lands on it.
      await tester.ensureVisible(
        find.byKey(const Key('patronage_chip_lost_items')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('patronage_chip_lost_items')));
      await tester.pumpAndSettle();

      // The route forwarded the string extra as the initial query (the
      // preflight ruling wired into routes.dart): the field is prefilled
      // with the chip's need text.
      final TextField field = tester.widget<TextField>(
        find.byKey(_searchFieldKey),
      );
      expect(field.controller?.text, 'lost items');
      final RouteMatchList currentStack =
          router.routerDelegate.currentConfiguration;
      // detail -> pushed search: the top of the stack is the real /search
      // route (not a re-push of the detail route).
      expect(currentStack.last.matchedLocation, '/search');

      // The prefill searched immediately (watch runs on the first build):
      // Anthony renders with his patronage badge.
      expect(
        find.byKey(const Key('search_result_anthony-of-padua')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('search_result_anthony-of-padua')),
          matching: find.text('patronage'),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('submit keeps the results and clearing returns to the prompt', (
    WidgetTester tester,
  ) async {
    await pumpSearchScreen(
      tester,
      repository: SaintRepository.forDatabase(db),
      preWarmQueries: const <(String, SaintCategory?)>[('lost items', null)],
    );

    await tester.enterText(find.byKey(_searchFieldKey), 'lost items');
    await tester.pump();
    expect(
      find.byKey(const Key('search_result_anthony-of-padua')),
      findsOneWidget,
    );

    // Submit (keyboard action) must not reset the field or the results.
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(
      find.byKey(const Key('search_result_anthony-of-padua')),
      findsOneWidget,
    );

    // Clear: back to the idle prompt — results gone, and NOT the no-results
    // empty state (blank query is not a search).
    await tester.enterText(find.byKey(_searchFieldKey), '');
    await tester.pump();
    expect(find.text('Search the saints.'), findsOneWidget);
    expect(
      find.byKey(const Key('search_result_anthony-of-padua')),
      findsNothing,
    );
    expect(find.byKey(_rationaleBadgeKey), findsNothing);
    expect(find.byKey(const Key('search_empty_state')), findsNothing);
  });

  testWidgets('results update on every change with no debounce', (
    WidgetTester tester,
  ) async {
    // Two zero-duration pumps after each change: a debounce timer would
    // NOT have fired under them, so results appearing here pins the
    // immediate (no-debounce) search the brief pins.
    final _FakeSearchRepository repository = _FakeSearchRepository(
      resultsFor: _typingResults,
    );
    await pumpSearchScreen(tester, repository: repository);

    await tester.enterText(find.byKey(_searchFieldKey), 'lost');
    await tester.pump();
    await tester.pump();

    expect(
      find.byKey(const Key('search_result_anthony-of-padua')),
      findsOneWidget,
    );
    expect(repository.calls, contains(('lost', null)));

    // Keep typing (a different query): the state flips live to the empty
    // state — the same on-change path re-watched with the new provider key.
    await tester.enterText(find.byKey(_searchFieldKey), 'zzz nothing');
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const Key('search_empty_state')), findsOneWidget);
    expect(find.text('St. Anthony of Padua'), findsNothing);
    expect(repository.calls.last, ('zzz nothing', null));
  });

  testWidgets(
    'tapping the military chip switches the provider key and narrows the results',
    (WidgetTester tester) async {
      final _FakeSearchRepository repository = _FakeSearchRepository(
        resultsFor: _narrowingResults,
      );
      await pumpSearchScreen(tester, repository: repository);

      await tester.enterText(find.byKey(_searchFieldKey), 'lost keys');
      await tester.pump();
      await tester.pump();

      // Unfiltered: both fake saints, each with its tier badge.
      expect(
        find.byKey(const Key('search_result_anthony-of-padua')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('search_result_joan-of-arc')),
        findsOneWidget,
      );
      expect(find.text('patronage'), findsOneWidget);
      expect(find.text('name'), findsOneWidget);
      expect(repository.calls.single, ('lost keys', null));

      // The filter row scrolls horizontally; bring the military chip into
      // view so the tap lands on it.
      await tester.ensureVisible(
        find.byKey(const Key('search_category_chip_military')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('search_category_chip_military')));
      await tester.pump();
      await tester.pump();

      // Narrowed: Joan only — and the fake recorded the KEY SWITCH
      // (same query, military category).
      expect(
        find.byKey(const Key('search_result_anthony-of-padua')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('search_result_joan-of-arc')),
        findsOneWidget,
      );
      expect(find.text('name'), findsNothing);
      expect(repository.calls, hasLength(2));
      expect(repository.calls.last, ('lost keys', SaintCategory.military));
      final ChoiceChip militaryChip = tester.widget<ChoiceChip>(
        find.byKey(const Key('search_category_chip_military')),
      );
      expect(militaryChip.selected, isTrue);

      // Back to all: the ('lost keys', null) provider already lives in the
      // keepAlive family cache (Task-10 carry-forward), so the cached
      // results re-render WITHOUT a new repository call — calls stays at 2,
      // last still the military key.
      await tester.ensureVisible(
        find.byKey(const Key('search_category_chip_all')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('search_category_chip_all')));
      await tester.pump();
      await tester.pump();

      expect(
        find.byKey(const Key('search_result_anthony-of-padua')),
        findsOneWidget,
      );
      expect(repository.calls, hasLength(2));
      expect(repository.calls.last, ('lost keys', SaintCategory.military));
    },
  );

  testWidgets(
    'search failures render search_error_state with a retry affordance',
    (WidgetTester tester) async {
      final _FakeSearchRepository repository = _FakeSearchRepository(
        resultsFor: _typingResults,
        failSearch: true,
      );
      await pumpSearchScreen(tester, repository: repository);

      await tester.enterText(find.byKey(_searchFieldKey), 'lost keys');
      await tester.pump();
      await tester.pump();

      expect(find.byKey(const Key('search_error_state')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('search_error_state')),
          matching: find.text('Retry'),
        ),
        findsOneWidget,
      );
      expect(find.byKey(_rationaleBadgeKey), findsNothing);

      // Retry invalidates the failing provider; the error surface persists
      // while the fake keeps failing.
      await tester.tap(find.text('Retry'));
      await tester.pump();
      await tester.pump();

      expect(find.byKey(const Key('search_error_state')), findsOneWidget);
    },
  );
}
