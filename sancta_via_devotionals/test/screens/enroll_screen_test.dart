// Enrollment screen widget tests (Plan 2, Task 15).
//
// The harness mirrors Task 14's detail harness: the REAL app repository over
// an isolated in-memory FFI store, the REAL seeded catalog (the content
// pipeline's first-launch migration), the wrapper's `programRepositoryOverride`
// chain, and `currentDateProvider` frozen with the workspace's `Stream.value`
// pattern. The enrollment route is deep-linked directly (a top-level page, no
// tab bar) and every async load is drained inside `tester.runAsync` BEFORE the
// widget phase; the enroll tap itself is drained through short real-time
// windows (the ruled screen-harness recipe for fake-async SQLite futures).
//
// Pinned cases:
// 1. the consecration screen offers the feast picker listing the pack's
//    `feastAnchor` entry, previews Day 1 / Day 34 through
//    `ConsecrationPlanner.startFor`, and the enroll button writes the derived
//    pack + params through the service (the enrolled signal flips);
// 2. the 54-day screen shows the phase explainer and the strict/permissive
//    policy choice defaulting from settings, and the enroll button writes the
//    user-picked start date + policy through the service;
// 3. a commitment enrolls as-is with empty params and fresh progress.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sancta_via_devotional_engine/sancta_via_devotional_engine.dart';
import 'package:sancta_via_devotionals/config/routes.dart';
import 'package:sancta_via_devotionals/database/devotionals_database.dart';
import 'package:sancta_via_devotionals/providers/app_settings_provider.dart'
    show missedDayDefaultPolicyProvider;
import 'package:sancta_via_devotionals/providers/content_providers.dart'
    show
        appProgramRepositoryProvider,
        contentLoadedProvider,
        programEnrolledProvider,
        programRepositoryOverride;
import 'package:sancta_via_devotionals/repositories/program_repository.dart';
import 'package:sancta_via_liturgical_calendar_riverpod/sancta_via_liturgical_calendar_riverpod.dart'
    show currentDateProvider;
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Opens a fresh, isolated in-memory database backed by the FFI factory.
Future<Database> _openInMemory() =>
    openDatabase(inMemoryDatabasePath, singleInstance: false);

/// The real shipped pack asset with [name] (the file stem).
ContentPack _assetPack(String name) {
  return PackLoader.loadFromJsonString(
    File('assets/content/packs/$name.json').readAsStringSync(),
  );
}

/// The harness a test pumps against: the provider container (provider-level
/// asserts) and the app router (location/stack capture).
class _EnrollHarness {
  const _EnrollHarness(this.container, this.repository, this.router);

  final ProviderContainer container;
  final SqliteProgramRepository repository;
  final GoRouter router;
}

/// Pumps the REAL enrollment flow for [packId] through the app router over the
/// production provider chain, settled before the widget phase.
Future<_EnrollHarness> _pumpEnroll(
  WidgetTester tester, {
  required String packId,
  required DateTime today,
  String policy = 'permissive',
}) async {
  final DevotionalsDatabase database = DevotionalsDatabase(open: _openInMemory);
  final SqliteProgramRepository repository = SqliteProgramRepository(
    database: database,
  );
  final GoRouter router = buildAppRouter(
    initialLocation: '/program/$packId/enroll',
  );
  final ProviderContainer container = ProviderContainer(
    overrides: <Override>[
      appProgramRepositoryProvider.overrideWithValue(repository),
      programRepositoryOverride,
      currentDateProvider.overrideWith(
        (Ref ref) => Stream<DateTime>.value(today),
      ),
      // The policy default is a settings read in production; the harness pins
      // it directly so the widget test is independent of SharedPreferences.
      missedDayDefaultPolicyProvider.overrideWithValue(policy),
    ],
  );
  addTearDown(container.dispose);

  await tester.runAsync(() async {
    await container.read(contentLoadedProvider.future);
    await container.read(currentDateProvider.future);
    await container.read(programEnrolledProvider(packId).future);
  });

  tester.view.physicalSize = const Size(700, 2200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pump(const Duration(milliseconds: 50));
  return _EnrollHarness(container, repository, router);
}

/// Flushes a tap's await chain: the fake-async zone's queued microtasks clear
/// one layer per real-time window, so a few rounds settle the service's
/// reads/writes and the post-enroll provider invalidations.
Future<void> _drain(WidgetTester tester) async {
  for (int round = 0; round < 10; round++) {
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 15));
    });
    await tester.pump(const Duration(milliseconds: 15));
  }
}

/// Taps [finder] (after scrolling it into view) and drains the async chain.
Future<void> _tapAndDrain(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder.last);
  await tester.pump(const Duration(milliseconds: 10));
  await tester.tap(finder.last);
  await _drain(tester);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'the consecration flow lists the feastAnchor entry, previews the planner '
    'dates, and enrolls the derived pack + params',
    (WidgetTester tester) async {
      final _EnrollHarness harness = await _pumpEnroll(
        tester,
        packId: 'total_consecration',
        today: DateTime(2026, 11, 10),
      );

      // The feast picker lists the pack's own feastAnchor entry (the
      // Annunciation on March 25) — nothing hardcodes the feast.
      expect(find.byKey(const Key('feast_picker')), findsOneWidget);
      expect(
        find.byKey(const Key('feast_option_annunciation')),
        findsOneWidget,
      );
      expect(find.text('Annunciation'), findsOneWidget);
      expect(find.text('March 25'), findsOneWidget);

      // The next occurrence of the feast is 2027-03-25; the 33-day
      // preparation starts 2027-02-20 (ConsecrationPlanner.startFor).
      expect(find.byKey(const Key('feast_year')), findsOneWidget);
      expect(
        find.byKey(const Key('consecration_start_preview')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('consecration_day34_preview')),
        findsOneWidget,
      );
      expect(find.text('2027-02-20'), findsOneWidget);
      expect(find.text('2027-03-25'), findsOneWidget);

      await _tapAndDrain(tester, find.byKey(const Key('enroll_button')));

      // The flow lands on its success state and offers the day-34 milestone.
      expect(find.byKey(const Key('enroll_success')), findsOneWidget);
      expect(find.byKey(const Key('day34_milestone')), findsOneWidget);
      expect(find.textContaining('Day 34'), findsOneWidget);

      // Written through the real service into the real store: params carry
      // ISO date strings and the derived pack carries the planner's Day 1.
      final Map<String, dynamic>? params = await tester
          .runAsync<Map<String, dynamic>?>(
            () => harness.repository.enrollmentParamsFor('total_consecration'),
          );
      expect(params, <String, dynamic>{
        'feast': '2027-03-25',
        'startDate': '2027-02-20',
        'day34': '2027-03-25',
      });

      final List<ContentPack> packs = (await tester.runAsync(
        () => harness.repository.loadPacks(),
      ))!;
      final ContentPack stored = packs.firstWhere(
        (ContentPack pack) => pack.id == 'total_consecration',
      );
      expect(
        (stored.schedule as SessionSeriesSpec).startDate,
        DateTime(2027, 2, 20),
      );
      expect(
        jsonEncode(stored.reminders),
        jsonEncode(_assetPack('total_consecration').reminders),
      );

      // The Task 14 carry pin: the enrolled provider flips after the write.
      final bool? enrolled = await tester.runAsync(
        () => harness.container.read(
          programEnrolledProvider('total_consecration').future,
        ),
      );
      expect(enrolled, isTrue);
      expect(
        await tester.runAsync<ProgressState?>(
          () => harness.repository.progressFor('total_consecration'),
        ),
        isNull,
        reason: 'a fresh enrollment starts with no persisted progress',
      );
    },
  );

  testWidgets(
    'the 54-day flow shows the two-phase explainer and the policy choice '
    '(default from settings), then enrolls the picked start date + policy',
    (WidgetTester tester) async {
      final _EnrollHarness harness = await _pumpEnroll(
        tester,
        packId: 'novena_54_day',
        today: DateTime(2026, 11, 10),
        // The app setting default is strict in this scenario; the screen must
        // preselect it without hardcoding permissive.
        policy: 'strict',
      );

      // Phase explainer: one paragraph plus the pack's phase rows.
      expect(find.textContaining('Days 1–27'), findsOneWidget);
      expect(find.textContaining('Days 28–54'), findsOneWidget);
      expect(find.textContaining('mysteries'), findsOneWidget);
      expect(find.text('Petition'), findsOneWidget);
      expect(find.text('Thanksgiving'), findsOneWidget);

      // The policy choice defaults from settings (strict here) and both rows
      // carry the pack's own notes.
      final RadioGroup<String> policyGroup = tester.widget<RadioGroup<String>>(
        find.byKey(const Key('policy_radio_group')),
      );
      expect(policyGroup.groupValue, 'strict');
      expect(find.byKey(const Key('policy_option_strict')), findsOneWidget);
      expect(find.byKey(const Key('policy_option_permissive')), findsOneWidget);
      expect(
        find.textContaining('missed day voids the streak'),
        findsOneWidget,
      );
      expect(
        find.textContaining('series resumes where it stands'),
        findsOneWidget,
      );

      // The day-1 date field is user-pickable (it opens the date picker).
      expect(find.byKey(const Key('start_date_field')), findsOneWidget);
      expect(find.text('2026-11-10'), findsOneWidget);
      await tester.tap(find.byKey(const Key('start_date_field')));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byType(DatePickerDialog), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pump(const Duration(milliseconds: 50));

      await _tapAndDrain(
        tester,
        find.byKey(const Key('policy_option_permissive')),
      );
      expect(
        tester
            .widget<RadioGroup<String>>(
              find.byKey(const Key('policy_radio_group')),
            )
            .groupValue,
        'permissive',
      );

      await _tapAndDrain(tester, find.byKey(const Key('enroll_button')));

      expect(find.byKey(const Key('enroll_success')), findsOneWidget);
      expect(find.byKey(const Key('day34_milestone')), findsNothing);

      final Map<String, dynamic>? params = await tester
          .runAsync<Map<String, dynamic>?>(
            () => harness.repository.enrollmentParamsFor('novena_54_day'),
          );
      expect(params, <String, dynamic>{
        'startDate': '2026-11-10',
        'restartPolicy': 'permissive',
      });

      final List<ContentPack> packs = (await tester.runAsync(
        () => harness.repository.loadPacks(),
      ))!;
      final ContentPack stored = packs.firstWhere(
        (ContentPack pack) => pack.id == 'novena_54_day',
      );
      expect(
        (stored.schedule as SessionSeriesSpec).startDate,
        DateTime(2026, 11, 10),
      );
      expect(
        jsonEncode(stored.reminders),
        jsonEncode(_assetPack('novena_54_day').reminders),
      );
      final bool? enrolled = await tester.runAsync(
        () => harness.container.read(
          programEnrolledProvider('novena_54_day').future,
        ),
      );
      expect(enrolled, isTrue);
    },
  );

  testWidgets('a commitment enrolls as-is with empty params and no progress', (
    WidgetTester tester,
  ) async {
    final _EnrollHarness harness = await _pumpEnroll(
      tester,
      packId: 'five_first_saturdays',
      today: DateTime(2026, 12, 5),
    );

    expect(find.textContaining('5 fulfillments'), findsOneWidget);
    expect(find.textContaining('next occurrence'), findsOneWidget);

    await _tapAndDrain(tester, find.byKey(const Key('enroll_button')));

    expect(find.byKey(const Key('enroll_success')), findsOneWidget);
    expect(
      await tester.runAsync(
        () => harness.repository.enrollmentParamsFor('five_first_saturdays'),
      ),
      isEmpty,
    );
    expect(
      await tester.runAsync<ProgressState?>(
        () => harness.repository.progressFor('five_first_saturdays'),
      ),
      isNull,
    );
    final bool? enrolled = await tester.runAsync(
      () => harness.container.read(
        programEnrolledProvider('five_first_saturdays').future,
      ),
    );
    expect(enrolled, isTrue);
  });
}
