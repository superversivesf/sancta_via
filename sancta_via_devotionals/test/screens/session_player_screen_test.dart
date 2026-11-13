// Session player screen widget tests (Plan 2, Task 11).
//
// Pins the five briefing cases plus the minimal UI edges, against the REAL
// shipped pack assets and the REAL Task-10 controller. The harness mirrors
// the Task 10 test techniques (a `_FakeProgramRepository` carrying the
// packs, an isolated in-memory FFI `meta` store) with the screen-harness
// addition the ruled Task 12/13 patterns use: every async load (the
// controller's session start, the intentions readout) is resolved for real
// inside `tester.runAsync` BEFORE the widget phase, so the pump sees settled
// provider state and no frame races a SQLite write.
//
// 1. the Angelus deep link (`/session/angelus?forDate=…`) walks by tap —
//    verse V./R. tap-to-advance, the collect prayer, the completion summary
//    (ordinal + badge callout) — and "Back to Today" returns to `/`;
// 2. the attribution sheet lists the viewed text's source/license;
// 3. the repetition ring records one bead per tap and blocks "Continue"
//    until the step's count is reached (the rosary's Three Hail Marys), and
//    the next bead-group card renders its mystery header, decade dots, and
//    Fatima-prayer toggle;
// 4. the reflection countdown gates "Continue" behind fake-async time, with
//    the deadline ticking through the controller's `tickReflection`;
// 5. the checkpoint gate: the walk completing without the required
//    checkpoint keeps the session open with a missing-items banner whose
//    item taps finalize the completion (Task 9's gate, surfaced);
// 6. a step still carrying `{{` renders the token-leak error card NAMING
//    the token — never raw tokens on screen (the widget-layer defense in
//    depth behind the controller's substitution gate);
// 7. the intercession card renders the current intentions readout through
//    `intentionsProvider` (Task-11 placeholder seam) and the day-variant
//    title as the day label;
// 8. the total-consecration player shows the Latin toggle block on a
//    parallel-carrying prayer and lands on the phase-banner summary;
// 9. `parseSessionForDate` accepts only strict `yyyy-MM-dd` query values.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sancta_via_devotional_engine/sancta_via_devotional_engine.dart';
import 'package:sancta_via_devotional_engine_riverpod/sancta_via_devotional_engine_riverpod.dart'
    show ProgramRepository;
import 'package:sancta_via_devotionals/config/routes.dart';
import 'package:sancta_via_devotionals/database/devotionals_database.dart';
import 'package:sancta_via_devotionals/providers/app_settings_provider.dart'
    show latinDisplayProvider;
import 'package:sancta_via_devotionals/providers/content_providers.dart'
    show intentionsProvider;
import 'package:sancta_via_devotionals/providers/session_player_provider.dart';
import 'package:sancta_via_devotionals/screens/session/session_player_screen.dart';
import 'package:sancta_via_devotionals/widgets/session/attribution_sheet.dart';
import 'package:sancta_via_devotionals/screens/home/today_screen.dart';
import 'package:sancta_via_liturgical_calendar_riverpod/sancta_via_liturgical_calendar_riverpod.dart'
    show currentDateProvider;

/// A repository double carrying the packs under test and recording writes/// (Task 10's seam — `loadPacks` also backs the screen's pack-title header
/// and the summary's completion read).
class _FakeProgramRepository implements ProgramRepository {
  _FakeProgramRepository({required this.packs});

  final List<ContentPack> packs;
  final Map<String, ProgressState> progress = <String, ProgressState>{};
  final List<ProgressState> saves = <ProgressState>[];

  @override
  Future<List<ContentPack>> loadPacks() async => packs;

  @override
  Future<ProgressState?> progressFor(String packId) async => progress[packId];

  @override
  Future<void> enroll(String packId, Map<String, dynamic> params) async {}

  @override
  Future<void> saveProgress(ProgressState s) async {
    progress[s.packId] = s;
    saves.add(s);
  }
}

/// The shipped pack asset with [id] — the real content the player renders.
ContentPack _assetPack(String id) {
  final String raw = File('assets/content/packs/$id.json').readAsStringSync();
  return PackLoader.loadFromJsonString(raw);
}

/// The isolated `meta` store for the harness: the ONLY [`DevotionalsDatabase`]
/// surface the session player controller consumes is `getMeta`/`setMeta`/
/// `deleteMeta` (its active-session snapshot), so this light in-memory
/// double stands in for the FFI store. It matters for the widget phase: the
/// real sqflite-ffi futures created inside the fake-async widget zone never
/// resume there on their own (the ruled screen-harness note), while these
/// pure-Dart futures complete in any zone — so tap-driven controller
/// chains settle with ordinary pumps. The REAL store's behavior (DDL,
/// round-trips, value validation) stays covered by the Task 4/10 test
/// suites; this double adds the harness determinism the ruled pattern
/// asks for.
class _FakeMetaStore extends DevotionalsDatabase {
  _FakeMetaStore() : super(open: () => throw UnimplementedError());

  final Map<String, String> _meta = <String, String>{};

  @override
  Future<String?> getMeta(String key) async => _meta[key];

  @override
  Future<void> setMeta(String key, String value) async {
    _meta[key] = value;
  }

  @override
  Future<bool> deleteMeta(String key) async => _meta.remove(key) != null;
}

/// The harness result: the container (provider reads), the controller
/// (engine-side asserts), and the repository double (progress asserts).
class _PlayerHarness {
  _PlayerHarness(this.container, this.controller, this.repository);

  final ProviderContainer container;
  final SessionPlayerController controller;
  final _FakeProgramRepository repository;
}

/// Pumps the session player for [packId].
///
/// The controller is constructed OUTSIDE the provider (so the test owns its
/// clock and its in-memory store), started for [startForDate] inside
/// `tester.runAsync` (draining every SQLite write before the widget phase —
/// the prewarm discipline the ruled screen harness uses), and handed to the
/// screen through the overridden `sessionPlayerControllerProvider`. When
/// [useRouter] is set the screen mounts through the REAL `buildAppRouter()`
/// and is navigated to with [openWithForDate] as the deep link's `forDate`
/// query parameter; otherwise a router-less `MaterialApp(home:)` carries the
/// same constructor arguments.
Future<_PlayerHarness> _pumpPlayer(
  WidgetTester tester, {
  required String packId,
  required List<ContentPack> packs,
  DateTime? startForDate,
  DateTime? openWithForDate,
  bool useRouter = false,
  List<IntentionRow> intentions = const <IntentionRow>[],
  List<Override> extraOverrides = const <Override>[],
}) async {
  final _FakeProgramRepository repository = _FakeProgramRepository(
    packs: packs,
  );
  final _FakeMetaStore database = _FakeMetaStore();
  final SessionPlayerController controller = SessionPlayerController(
    repository: repository,
    database: database,
  );
  final ProviderContainer container = ProviderContainer(
    overrides: <Override>[
      sessionPlayerControllerProvider.overrideWith(
        (Ref ref, String arg) => controller,
      ),
      intentionsProvider.overrideWith((Ref ref) async => intentions),
      latinDisplayProvider.overrideWithValue(false),
      // Task 13: "Back to Today" now mounts the real TodayScreen, whose
      // calendar provider keeps `currentDateProvider`'s periodic midnight
      // timer alive — pending forever in a widget test. The ruled harness
      // pattern freezes it on a fixed day.
      currentDateProvider.overrideWith(
        (Ref ref) => Stream<DateTime>.value(DateTime(2026, 12, 5)),
      ),
      ...extraOverrides,
    ],
  );
  addTearDown(container.dispose);

  if (startForDate != null) {
    // The prewarm: the controller's async load (and every persisted write)
    // runs for real before the widget phase, so the pump sees the active
    // state.
    await tester.runAsync(
      () => controller.startSession(packId, forDate: startForDate),
    );
  }
  // The intentions readout prewarms the same way (the ruled pattern).
  await tester.runAsync(() => container.read(intentionsProvider.future));

  Widget child = MaterialApp(
    home: SessionPlayerScreen(packId: packId, forDate: openWithForDate),
  );
  if (useRouter) {
    child = MaterialApp.router(routerConfig: buildAppRouter());
  }
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: child),
  );
  if (useRouter) {
    // Navigate exactly the way Task 13's Today deep link will.
    final BuildContext todayContext = tester.element(find.byType(TodayScreen));
    final String query = openWithForDate == null
        ? ''
        : '?forDate=${openWithForDate.year.toString().padLeft(4, '0')}-'
              '${openWithForDate.month.toString().padLeft(2, '0')}-'
              '${openWithForDate.day.toString().padLeft(2, '0')}';
    todayContext.go('/session/$packId$query');
    // The pump mounts the session route (and schedules the screen's
    // post-frame restart) before the real-time drains below.
    await tester.pump();
  }
  if (openWithForDate != null) {
    // The screen's post-frame `startSession` (the forDate deep link) runs
    // the controller's real-time SQLite reads — those never resume under
    // fake-async (the ruled screen-harness note), so give them a real-time
    // drain between the frame pumps that settle the navigation.
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 60));
    });
    await tester.pump(const Duration(milliseconds: 10));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 60));
    });
  }
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump();
  return _PlayerHarness(container, controller, repository);
}

/// Taps [finder] and flushes the frame plus one `runAsync` round for the
/// tapped transition's first await layer. With [scrollTo], the target is
/// first scrolled into view (tall cards push their controls below the
/// fold).
Future<void> _tap(
  WidgetTester tester,
  Finder finder, {
  bool scrollTo = false,
}) async {
  if (scrollTo) {
    await tester.ensureVisible(finder.last);
    await tester.pump(const Duration(milliseconds: 10));
  }
  await tester.tap(finder.last);
  await tester.runAsync(() async {});
  await tester.pump(const Duration(milliseconds: 10));
}

/// Taps [finder] [times] times, flushing one frame — plus one `runAsync`
/// round per record — so each record's write layer is drained before the
/// next (the fake-async microtask queue only clears through such windows;
/// leaving them queued would strand the later finalize behind the pile).
Future<void> _tapRepeatedly(
  WidgetTester tester,
  Finder finder,
  int times,
) async {
  for (int i = 0; i < times; i++) {
    await tester.tap(finder.last, warnIfMissed: false);
    await tester.runAsync(() async {});
    await tester.pump(const Duration(milliseconds: 10));
  }
}

/// Flushes the controller's await-chain behind a just-tapped transition:
/// the fake-async zone's queued microtasks are drained by a `runAsync`
/// window (one layer per window), so completing a walk needs a couple of
/// rounds before the finalize branch and the persist chain have landed.
Future<void> _drain(WidgetTester tester) async {
  for (int round = 0; round < 3; round++) {
    await tester.runAsync(() async {});
    await tester.pump(const Duration(milliseconds: 20));
  }
}

/// Scrolls the step card (via its title) fully into view and taps it.
Future<void> _tapStep(
  WidgetTester tester, {
  required String title,
  String? stepId,
}) async {
  if (stepId != null) {
    await tester.ensureVisible(find.byKey(Key('session_step_$stepId')));
  }
  await tester.ensureVisible(find.text(title));
  await tester.tap(find.text(title), warnIfMissed: false);
  await tester.pump(const Duration(milliseconds: 10));
}

/// Taps the current step's "Continue" control [times] times.
Future<void> _continue(WidgetTester tester, {int times = 1}) =>
    _tapRepeatedly(tester, find.text('Continue'), times);

/// Whether the current step's "Continue" control is enabled.
bool _continueEnabled(WidgetTester tester) {
  final ElevatedButton button = tester.widget<ElevatedButton>(
    find
        .ancestor(
          of: find.text('Continue'),
          matching: find.byType(ElevatedButton),
        )
        .last,
  );
  return button.onPressed != null;
}

void main() {
  test('parseSessionForDate accepts strict yyyy-MM-dd query values', () {
    expect(parseSessionForDate('2026-12-05'), DateTime(2026, 12, 5));
    expect(parseSessionForDate(null), isNull);
    expect(parseSessionForDate(''), isNull);
    expect(parseSessionForDate('garbage'), isNull);
    expect(parseSessionForDate('2026-13-05'), isNull);
    expect(parseSessionForDate('2026-12-05T10:00:00'), isNull);
    expect(parseSessionForDate('12/05/2026'), isNull);
  });

  testWidgets(
    'an angelus deep-link tap-through completes to the summary and back to Today',
    (WidgetTester tester) async {
      await _pumpPlayer(
        tester,
        packId: 'angelus',
        packs: <ContentPack>[_assetPack('angelus')],
        startForDate: DateTime(2026, 12, 5),
        openWithForDate: DateTime(2026, 12, 5),
        useRouter: true,
      );

      // The deep link rendered the active player: progress header, pack
      // title, the forDate day label, and the first V./R. verse.
      expect(find.text('Step 1 of 4'), findsOneWidget);
      expect(
        find.text('The Angelus (Regina Caeli in Eastertide)'),
        findsOneWidget,
      );
      expect(find.text('December 5, 2026'), findsOneWidget);
      expect(
        find.text('V. The Angel of the Lord declared unto Mary.'),
        findsOneWidget,
      );
      expect(
        find.text('R. And she conceived of the Holy Spirit.'),
        findsOneWidget,
      );

      // Verse steps advance by tapping the card (V./R. tap-to-advance).
      for (int i = 0; i < 3; i++) {
        await _tap(tester, find.byKey(Key('session_step_angelus-v${i + 1}')));
        expect(
          find.text('Step ${i + 2} of 4'),
          findsOneWidget,
          reason: 'verse tap ${i + 1} advanced the walk',
        );
      }

      // The collect prayer completes the walk by tap as well; the finalize
      // window settles onto the summary: ordinal (the fake store's first)
      // and the badge callout.
      await _tap(tester, find.byKey(const Key('session_step_angelus-collect')));
      await _drain(tester);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('session_completion_summary')),
        findsOneWidget,
      );
      expect(find.text('Completion 1'), findsOneWidget);
      expect(find.textContaining('Badge earned: The Angelus'), findsOneWidget);
      expect(find.text('Back to Today'), findsOneWidget);

      // Back to Today returns to the root route — which now mounts the REAL
      // TodayScreen (Task 13). Fixed pumps, not `pumpAndSettle`: that
      // screen's loading state is a spinner `pumpAndSettle` can never
      // settle, and this smoke container's provider chain intentionally
      // carries no repository overrides.
      await tester.tap(find.text('Back to Today'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(TodayScreen), findsOneWidget);
    },
  );

  testWidgets(
    'the attribution sheet lists the viewed text source and license',
    (WidgetTester tester) async {
      await _pumpPlayer(
        tester,
        packId: 'angelus',
        packs: <ContentPack>[_assetPack('angelus')],
        startForDate: DateTime(2026, 12, 5),
        openWithForDate: DateTime(2026, 12, 5),
      );

      // Before any attributed text was viewed (the verses carry none), the
      // sheet says so honestly.
      await _tap(tester, find.byKey(const Key('session_attribution_action')));
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        find.text('No attributed prayer text has been viewed yet.'),
        findsOneWidget,
      );
      await _tap(tester, find.byKey(const Key('session_attribution_close')));
      await tester.pump(const Duration(milliseconds: 300));

      // Walk onto the collect prayer (steps 1-3 by tap), then the sheet
      // lists exactly the viewed text's attribution.
      for (int i = 0; i < 3; i++) {
        await _tap(tester, find.byKey(Key('session_step_angelus-v${i + 1}')));
      }
      expect(
        find.byKey(const Key('session_step_angelus-collect')),
        findsOneWidget,
      );
      await _tap(tester, find.byKey(const Key('session_attribution_action')));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('angelus_collect'), findsOneWidget);
      expect(find.text('Traditional Roman devotion'), findsOneWidget);
      expect(find.text('public-domain'), findsOneWidget);
    },
  );

  testWidgets(
    'a litany session\'s attribution sheet shows the litany text\'s pack-level source and license',
    (WidgetTester tester) async {
      final ContentPack pack = _assetPack('litany_loreto');
      final Map<String, dynamic> note =
          pack.reminders['schedule_note']! as Map<String, dynamic>;
      await _pumpPlayer(
        tester,
        packId: 'litany_loreto',
        packs: <ContentPack>[pack],
        startForDate: DateTime(2026, 12, 5),
        openWithForDate: DateTime(2026, 12, 5),
      );

      // Nothing attributed yet: the opening versicles carry no attribution.
      Finder packEntry() => find.text(pack.id);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.ensureVisible(
        find.byKey(const Key('session_step_sign-of-the-cross')),
      );
      await _tap(tester, find.byKey(const Key('session_attribution_action')));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('litany_loreto'), findsNothing);
      await _tap(tester, find.byKey(const Key('session_attribution_close')));
      await tester.pump(const Duration(milliseconds: 300));

      // Walk onto the first LitanyStep (the Godhead block) through the
      // verses: the viewed set now includes a litany step, so the sheet
      // carries ONE pack-level provenance row (id, source, license).
      await _tap(
        tester,
        find.byKey(const Key('session_step_sign-of-the-cross')),
      );
      await _tap(tester, find.byKey(const Key('session_step_kyrie')));
      await _tap(tester, find.byKey(const Key('session_step_christe')));
      // The litany card itself carries no session_step key; the attribution
      // action lives in the app bar and needs no card visibility.
      await _tap(tester, find.byKey(const Key('session_attribution_action')));
      await tester.pump(const Duration(milliseconds: 300));
      expect(packEntry(), findsOneWidget);
      expect(find.text(note['invocation_source']! as String), findsOneWidget);
      expect(find.text(note['invocation_license']! as String), findsOneWidget);
      expect(
        note['invocation_source']! as String,
        contains('Sixtus V'),
        reason: 'the pack-level litany provenance names the tradition',
      );
      await _tap(tester, find.byKey(const Key('session_attribution_close')));
      await tester.pump(const Duration(milliseconds: 300));

      // Onto the second litany step — the same pack-level row, still once
      // (de-duplicated across litany steps of the walk).
      await _tap(tester, find.text('Continue'));
      await _tap(tester, find.byKey(const Key('session_attribution_action')));
      await tester.pump(const Duration(milliseconds: 300));
      expect(packEntry(), findsOneWidget);
      expect(find.text(note['invocation_source']! as String), findsOneWidget);
      await _tap(tester, find.byKey(const Key('session_attribution_close')));
      await tester.pump(const Duration(milliseconds: 300));
    },
  );

  test('attributionEntriesFor: the pack-level litany row is litany-only '
      'and de-duplicated', () {
    final ContentPack litanyPack = _assetPack('litany_loreto');
    final SessionScript litanyScript = litanyPack.session;
    // Before any litany step: verses only — no entry, even with the pack.
    expect(attributionEntriesFor(litanyScript, 0, pack: litanyPack), isEmpty);
    // From the first litany step on: exactly one entry, keyed to the pack.
    final List<AttributionEntry> atTrinity = attributionEntriesFor(
      litanyScript,
      3,
      pack: litanyPack,
    );
    expect(atTrinity, hasLength(1));
    expect(atTrinity.single.prayerId, litanyPack.id);
    expect(atTrinity.single.source, isNotEmpty);
    expect(atTrinity.single.license, startsWith('public-domain'));
    // AttributionEntry carries no == (rows are distinct per call), so the
    // dedupe pins compare the rows' fields: a second litany step adds no
    // row, and the whole walk (an out-of-bounds through index) stays one.
    List<String> rowOf(List<AttributionEntry> entries) => <String>[
      for (final AttributionEntry e in entries) e.prayerId,
    ];
    expect(
      rowOf(attributionEntriesFor(litanyScript, 4, pack: litanyPack)),
      rowOf(atTrinity),
    );
    // The completed walk also views the collect prayer: the litany row
    // keeps its first-appearance position, the collect follows.
    expect(
      rowOf(attributionEntriesFor(litanyScript, 99, pack: litanyPack)),
      <String>[litanyPack.id, 'loreto_collect'],
    );
    // A non-litany pack (the Angelus) gains nothing from the pack pass.
    // (Entry lists hold distinct-by-construction rows, so compare ids.)
    final ContentPack angelus = _assetPack('angelus');
    final List<String> ids = <String>[
      for (final AttributionEntry entry in attributionEntriesFor(
        angelus.session,
        99,
        pack: angelus,
      ))
        entry.prayerId,
    ];
    final List<String> packlessIds = <String>[
      for (final AttributionEntry entry in attributionEntriesFor(
        angelus.session,
        99,
      ))
        entry.prayerId,
    ];
    expect(ids, packlessIds);
    expect(ids.every((String id) => id != angelus.id), true);
    // And the old two-argument spelling still works (the player's
    // pack-less degradation).
    expect(attributionEntriesFor(litanyScript, 3), isEmpty);
  });

  testWidgets(
    'the repetition ring blocks continue until its count is recorded, and the next beads render',
    (WidgetTester tester) async {
      final _PlayerHarness harness = await _pumpPlayer(
        tester,
        packId: 'rosary',
        packs: <ContentPack>[_assetPack('rosary')],
        startForDate: DateTime(2026, 12, 14), // a Monday: the joyful set
        openWithForDate: DateTime(2026, 12, 14),
      );

      // Steps 0-2 (verse, creed, Our Father) advance by tap...
      await _tap(
        tester,
        find.byKey(const Key('session_step_rosary-sign-of-cross')),
      );
      await _tap(tester, find.byKey(const Key('session_step_rosary-creed')));
      await _tap(
        tester,
        find.byKey(const Key('session_step_rosary-our-father')),
      );
      // ...landing on the Three Hail Marys repetition step: 0 of 3, ring
      // present, and Continue gated.
      const Key ring = Key('session_count_ring_rosary-hail-marys');
      expect(find.byKey(ring), findsOneWidget);
      expect(find.text('0 of 3'), findsOneWidget);
      expect(_continueEnabled(tester), isFalse);

      // Tapping Continue before the target must NOT advance the walk.
      await _tap(tester, find.text('Continue'));
      expect(find.byKey(ring), findsOneWidget);
      expect(
        find.text('Three Hail Marys (on the first beads)'),
        findsOneWidget,
      );

      // Each ring tap records one repetition.
      await _tapRepeatedly(tester, find.byKey(ring), 1);
      expect(find.text('1 of 3'), findsOneWidget);
      await _tapRepeatedly(tester, find.byKey(ring), 2);
      expect(find.text('3 of 3'), findsOneWidget);
      expect(_continueEnabled(tester), isTrue);

      // Continue advances through the Glory Be (a prayer card) onto the
      // first decade card: mystery header (substituted from the day's
      // cycle), decade dots, Fatima toggle.
      await _tap(tester, find.text('Continue'));
      expect(find.text('Glory Be'), findsOneWidget);
      await _tap(tester, find.byKey(const Key('session_step_rosary-glory-be')));
      expect(find.text('First Decade'), findsOneWidget);
      expect(find.text('The Annunciation'), findsOneWidget);
      expect(find.text('Humility'), findsOneWidget);
      const Key dots = Key('session_bead_dots_rosary-decade-1');
      expect(find.byKey(dots), findsOneWidget);
      expect(find.text('0 of 10'), findsOneWidget);
      expect(_continueEnabled(tester), isFalse);

      // The Fatima toggle reveals the decade's closing prayer.
      await _tap(
        tester,
        find.byKey(const Key('session_fatima_toggle_rosary-decade-1')),
      );
      await tester.pump(const Duration(milliseconds: 50));
      expect(
        find.textContaining('O my Jesus, forgive us our sins'),
        findsOneWidget,
      );

      // (engine cross-check: the walk recorded the counts)
      expect(
        harness.controller.state.session.recordedCounts,
        containsPair(3, 3),
      );
    },
  );

  testWidgets(
    'the reflection countdown gates continue behind fake-async time',
    (WidgetTester tester) async {
      // The fifteen-minute meditation: countdown running, deadline ticked
      // through the controller, Continue gated.
      final _PlayerHarness harness = await _pumpPlayer(
        tester,
        packId: 'five_first_saturdays',
        packs: <ContentPack>[_assetPack('five_first_saturdays')],
        startForDate: DateTime(2026, 12, 5),
        openWithForDate: DateTime(2026, 12, 5),
      );
      // Walk the two checkpoint steps...
      await _continue(tester, times: 2);
      // ...and record five decades (10 dots each).
      for (int decade = 1; decade <= 5; decade++) {
        await _tapRepeatedly(
          tester,
          find.byKey(Key('session_bead_dots_ffs-decade-$decade')),
          10,
        );
        await _continue(tester);
      }

      expect(find.text('Fifteen Minutes of Meditation'), findsOneWidget);
      expect(find.text('15:00'), findsOneWidget);
      expect(_continueEnabled(tester), isFalse);
      // The meditation's attributed Fatima-request text carries its
      // attribution line on the reflection card (fix round 1, finding 2).
      expect(find.textContaining('Fatima 1917 request'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 30));
      expect(harness.controller.state.reflectionEndsAt, isNotNull);

      // Advance the fake clock past the whole countdown.
      await tester.pump(const Duration(minutes: 16));
      expect(find.text('0:00'), findsOneWidget);
      expect(_continueEnabled(tester), isTrue);
      expect(harness.controller.state.reflectionEndsAt, isNull);

      // Complete the walk through the gated Continue: the tap's transition
      // settles through the pure-Dart persist chain, and the gate holds the
      // session open.
      await _tap(tester, find.text('Continue'), scrollTo: true);
      await _drain(tester);
      expect(find.byKey(const Key('session_missing_banner')), findsOneWidget);
      expect(find.textContaining('communion'), findsOneWidget);
    },
  );

  testWidgets(
    'the checkpoint gate finalizes only when the required checkpoint is toggled',
    (WidgetTester tester) async {
      final _PlayerHarness harness = await _pumpPlayer(
        tester,
        packId: 'five_first_saturdays',
        packs: <ContentPack>[_assetPack('five_first_saturdays')],
        startForDate: DateTime(2026, 12, 5),
        openWithForDate: DateTime(2026, 12, 5),
      );

      // The confession checkpoint (not required) is recordable in its own
      // card before the walk passes it.
      const Key confession = Key('session_checkpoint_confession');
      expect(find.byKey(confession), findsOneWidget);
      expect(find.text('Sacramental Confession'), findsOneWidget);
      await _tap(tester, find.byKey(confession));
      expect(harness.controller.state.checkpoints['confession'], isTrue);

      // Walk both checkpoint steps (record ≠ walked: Task 9's gate is the
      // session-completion contract, not a step-completion contract) and
      // the rest of the script — decade records through the dot row taps,
      // every step through its gated Continue.
      await _tap(tester, find.text('Continue'));
      await _tap(tester, find.text('Continue'));
      for (int decade = 1; decade <= 5; decade++) {
        await _tapRepeatedly(
          tester,
          find.byKey(Key('session_bead_dots_ffs-decade-$decade')),
          10,
        );
        await _continue(tester);
      }
      await tester.pump(const Duration(minutes: 16));
      await _tap(tester, find.text('Continue'), scrollTo: true);
      await _drain(tester);

      // The walk is finished; only the REQUIRED checkpoint is missing.
      expect(find.byKey(const Key('session_missing_banner')), findsOneWidget);
      expect(
        find.byKey(const Key('session_missing_item_communion')),
        findsOneWidget,
      );
      expect(find.textContaining('confession'), findsNothing);
      expect(find.byKey(const Key('session_completion_summary')), findsNothing);
      expect(harness.repository.progress['five_first_saturdays'], isNull);

      // Tapping the missing item records the checkpoint and retries the
      // finalization: the summary lands.
      await _tap(
        tester,
        find.byKey(const Key('session_missing_item_communion')),
      );
      await _drain(tester);
      expect(harness.controller.state.status, SessionPlayerStatus.finalized);
      expect(
        find.byKey(const Key('session_completion_summary')),
        findsOneWidget,
      );
      expect(harness.repository.progress['five_first_saturdays'], isNotNull);
    },
  );

  testWidgets(
    'the repetition card carries its attributed text\'s attribution line',
    (WidgetTester tester) async {
      await _pumpPlayer(
        tester,
        packId: 'mercy_hour',
        packs: <ContentPack>[_assetPack('mercy_hour')],
        startForDate: DateTime(2026, 12, 4),
        openWithForDate: DateTime(2026, 12, 4),
      );

      // The Hour of Mercy prayer, then the short-phrase Diary repetition.
      await _tap(
        tester,
        find.byKey(const Key('session_step_mercy-hour-prayer')),
      );
      expect(find.text('O Blood and Water'), findsOneWidget);
      // Fix round 1 (finding 2): the repetition's attributed Diary text
      // renders its attribution line, as the prayer/verse cards already do.
      expect(find.textContaining('Diary of St. Faustina'), findsOneWidget);
    },
  );

  testWidgets(
    'the no-forDate open renders the state\'s started day as the day label',
    (WidgetTester tester) async {
      // Fix round 1 (finding 3): deep links without forDate still show a
      // meaningful day label — SessionPlayerState.day (the session's own
      // calendar day), formatted the same way the deep link's forDate is.
      await _pumpPlayer(
        tester,
        packId: 'angelus',
        packs: <ContentPack>[_assetPack('angelus')],
        // The prewarmed session's day: 2026-12-05 local midnight.
        startForDate: DateTime(2026, 12, 5),
      );
      expect(find.text('December 5, 2026'), findsOneWidget);
    },
  );

  testWidgets(
    'a {{leak}} step renders the error card naming the token, never the raw token',
    (WidgetTester tester) async {
      // A synthesized leaky pack (the shipped assets never leak): its prayer
      // text still carries an unresolved token.
      final ContentPack pack = ContentPack(
        id: 'leaky',
        title: 'Leaky pack',
        family: PackFamily.routine,
        schedule: TimeOfDaySpec(6, 0),
        session: SessionScript(
          id: 'leaky-session',
          steps: <SessionStep>[
            PrayerStep(
              id: 'lk-prayer',
              text: PrayerText(
                id: 'lk-text',
                text: 'color of the roses: {{leak}}',
                source: 'test',
                license: 'test',
              ),
            ),
          ],
        ),
      );
      final _PlayerHarness harness = await _pumpPlayer(
        tester,
        packId: pack.id,
        packs: <ContentPack>[pack],
        startForDate: DateTime(2026, 12, 5),
      );

      // The controller's substitution gate is the FIRST line: a direct
      // startSession refuses to publish the leaky script at all.
      expect(harness.controller.state.status, SessionPlayerStatus.error);
      harness.controller.state = SessionPlayerState(
        session: SessionRunner.forState(pack.session),
        script: pack.session,
        status: SessionPlayerStatus.active,
      );
      await tester.pump(const Duration(milliseconds: 20));

      // The error card names the token; the raw `{{` never renders.
      expect(
        find.byKey(const Key('session_token_leak_lk-prayer')),
        findsOneWidget,
      );
      expect(find.textContaining('leak'), findsAtLeastNWidgets(1));
      expect(find.textContaining('{{'), findsNothing);
    },
  );

  testWidgets(
    'the intercession card renders the prompt and the current intentions readout',
    (WidgetTester tester) async {
      await _pumpPlayer(
        tester,
        packId: 'divine_mercy_novena',
        packs: <ContentPack>[_assetPack('divine_mercy_novena')],
        startForDate: DateTime(
          2026,
          4,
          5,
        ), // Easter Sunday: day 3 of the novena
        openWithForDate: DateTime(2026, 4, 5),
        intentions: <IntentionRow>[
          const IntentionRow(
            id: 'i1',
            kind: 'intention',
            text: 'For my family',
            createdAt: '2026-01-01T00:00:00.000Z',
          ),
        ],
      );

      // The day-variant title is the day label; the prompt is substituted.
      expect(find.text('Day 3'), findsOneWidget);
      expect(
        find.textContaining('3 of the Divine Mercy Novena'),
        findsOneWidget,
      );
      expect(find.text('For my family'), findsOneWidget);

      // Continue advances onto the sign-of-cross verse.
      await _tap(tester, find.text('Continue'));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('Step 2 of 25'), findsOneWidget);
      expect(find.textContaining('Offer today'), findsNothing);
    },
  );

  testWidgets(
    'the latin toggle reveals the parallel block, and the phase banner lands on the summary',
    (WidgetTester tester) async {
      await _pumpPlayer(
        tester,
        packId: 'total_consecration',
        packs: <ContentPack>[_assetPack('total_consecration')],
        startForDate: DateTime(2027, 2, 21), // day 2 of the series: 'emptying'
        openWithForDate: DateTime(2027, 2, 21),
      );

      // The Come Holy Spirit prayer carries a Latin parallel: the toggle is
      // off (settings default), so the Latin block is absent.
      const Key toggle = Key('session_latin_toggle_tc-come-holy-spirit');
      expect(find.byKey(toggle), findsOneWidget);
      expect(find.textContaining('Veni, Sancte Spiritus'), findsNothing);
      await _tap(tester, find.byKey(toggle));
      await tester.pump(const Duration(milliseconds: 20));
      expect(find.textContaining('Veni, Sancte Spiritus'), findsOneWidget);
      // The attribution line names the viewed text's source and license.
      expect(find.textContaining('Traditional'), findsOneWidget);

      // Walk the seven steps: six prayers by title tap (ensuring the tall
      // cards scroll their tap surface into view), the reading reflection
      // by clock.
      await _tapStep(tester, title: 'Come, Holy Spirit');
      for (final String stepTitle in <String>[
        'Veni Creator Spiritus',
        'Ave Maris Stella',
        'Magnificat',
      ]) {
        await _tapStep(tester, title: stepTitle);
      }
      expect(find.text('Daily Reading and Meditation'), findsOneWidget);
      expect(find.text('10:00'), findsOneWidget);
      await tester.pump(const Duration(minutes: 11));
      await _tap(tester, find.text('Continue'), scrollTo: true);
      await _tapStep(tester, title: 'Daily Renewal of Consecration');
      await _tapStep(tester, title: 'Act of Consecration (consecration day)');

      // The summary lands with the day's phase banner, ordinal, and badge.
      await _drain(tester);
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        find.byKey(const Key('session_completion_summary')),
        findsOneWidget,
      );
      expect(find.textContaining('emptying'), findsOneWidget);
      expect(find.text('Completion 1'), findsOneWidget);
      expect(find.textContaining('Badge earned:'), findsOneWidget);
    },
  );
}
