// Onboarding screen widget tests (Plan 2, Task 19).
//
// The harness mirrors Task 13/15's real-chain pattern: the REAL app
// repository over an isolated in-memory FFI store, the REAL seeded catalog,
// the wrapper's `programRepositoryOverride` chain, `currentDateProvider`
// frozen with the workspace's `Stream.value` pattern, and the REAL settings
// provider over a mock SharedPreferences store — pumped into the REAL
// `OnboardingScreen` through the app router. The only fake is the plugin
// adapter (Task 18's seam), so the "requests permission once" pin reads the
// service as production runs it.
//
// Pinned cases from the brief:
// 1. a full walk (welcome → claim → routine → reminders → done) sets
//    `onboardingComplete` in settings AND in the persisted store, and lands
//    on Today; with nothing claimed or toggled, nothing is enrolled;
// 2. claiming `five_first_saturdays` at 3 with the clock frozen at
//    2026-11-10 persists `fulfilledOrdinals: 3` + `lastFulfilled`
//    2026-11-07 (the last First Saturday BEFORE the frozen day), with NO
//    completion records and NO badges (badges are earned by completion),
//    and the composed next due date is 2026-12-05 (the engine's projection
//    over the claimed ordinals);
// 3. the same claim math on `nine_first_fridays` (claim 1 at the frozen
//    day): lastFulfilled 2026-11-06, next due 2026-12-04;
// 4. the routine step's toggles enroll the catalog's routine packs (the
//    seeded Angelus / Hour of Mercy / Holy Rosary) and the meal & night
//    anchors toggle writes the `nightItemsEnabled` setting;
// 5. enabling a reminder toggle requests permission ONCE across every
//    enable (Task 18's initialize seam, idempotent), and the toggle writes
//    through to settings.
//
// The router's onboarding gate (the cold-start rule main.dart wires):
// 6. unwired (every existing harness) disables the redirect entirely —
//    Task 13's CTA and tile navigations keep working;
// 7. wired to false, any location that is not `/onboarding` redirects there
//    (the walkthrough owns an un-onboarded app);
// 8. wired to true, no redirect fires and `/onboarding` stays open (the
//    re-entry CTA on Today serves a completed install);
// 9. the persisted onboarding flag reads true / false / corrupt-store-safe,
//    so main.dart can pick the cold-start initial location once.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sancta_via_devotional_engine/sancta_via_devotional_engine.dart'
    show
        BadgeRecord,
        ConsecutiveCommitmentSpec,
        ContentPack,
        Projection,
        ProgressState;
import 'package:sancta_via_devotionals/config/routes.dart';
import 'package:sancta_via_devotionals/database/devotionals_database.dart';
import 'package:sancta_via_devotionals/main.dart' show SanctaViaDevotionalsApp;
import 'package:sancta_via_devotionals/models/app_settings.dart'
    show DevotionsAppSettings;
import 'package:sancta_via_devotionals/providers/app_settings_provider.dart'
    show
        DevotionsSettingsNotifier,
        devotionsSettingsProvider,
        onboardingCompleteProvider,
        readPersistedOnboardingComplete;
import 'package:sancta_via_devotionals/providers/content_providers.dart'
    show
        appProgramRepositoryProvider,
        contentLoadedProvider,
        programRepositoryOverride;
import 'package:sancta_via_devotionals/providers/today_providers.dart'
    show notificationServiceProvider;
import 'package:sancta_via_devotionals/repositories/program_repository.dart'
    show SqliteProgramRepository;
import 'package:sancta_via_devotionals/screens/home/today_screen.dart'
    show TodayScreen;
import 'package:sancta_via_devotionals/screens/onboarding/onboarding_screen.dart'
    show OnboardingScreen;
import 'package:sancta_via_devotionals/services/notification_service.dart'
    show
        NotificationPluginAdapter,
        NotificationPluginInit,
        NotificationService,
        PendingNotification;
import 'package:sancta_via_liturgical_calendar/sancta_via_liturgical_calendar.dart'
    show LiturgicalDayData;
import 'package:sancta_via_liturgical_calendar_riverpod/sancta_via_liturgical_calendar_riverpod.dart'
    show currentDateProvider;
import 'package:sancta_via_shared_ui/sancta_via_shared_ui.dart'
    show BaseSettingsModel, baseSettingsProvider;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:timezone/data/latest.dart' as tzdata;

/// A fresh FFI in-memory store open factory (isolated per call).
Future<Database> _openInMemory() =>
    openDatabase(inMemoryDatabasePath, singleInstance: false);

/// The frozen walkthrough clock (the brief's claim-math day).
final DateTime _frozenToday = DateTime(2026, 11, 10);

/// What the [DevotionsSettingsNotifier]'s SharedPreferences store carries:
/// the REAL settings provider loads from here (no override in these tests),
/// with `baseSettings` left at its defaults so the load overlay is a no-op.
void _setMockSettings({bool onboardingComplete = false}) {
  final DevotionsAppSettings settings = DevotionsAppSettings(
    baseSettings: BaseSettingsModel.defaults(),
    onboardingComplete: onboardingComplete,
  );
  SharedPreferences.setMockInitialValues(<String, Object>{
    DevotionsSettingsNotifier.storageKey: jsonEncode(settings.toJson()),
  });
}

/// The recording plugin adapter (Task 18's seam): counts the calls the app
/// makes and stubs the device answers.
class _RecordingAdapter implements NotificationPluginAdapter {
  /// How many times the app touched plugin initialization — the
  /// provisional-auth request lives inside, so this count IS the
  /// permission-request count.
  int initializeCalls = 0;

  /// How many times a re-plan was asked for.
  int refreshes = 0;

  /// How many notifications were scheduled or cancelled (never expected
  /// from the walkthrough itself — the toggles gate anchors that are not
  /// enrolled yet).
  int schedules = 0;
  int cancels = 0;

  @override
  Future<NotificationPluginInit> initialize({
    required Future<void> Function(String payload) onTap,
  }) async {
    initializeCalls++;
    return const NotificationPluginInit(timeZoneName: 'America/New_York');
  }

  @override
  Future<List<PendingNotification>> pendingNotifications() async {
    // Exactly one of these per refresh pass (the diff reads the device
    // snapshot once), so this count IS the re-plan count.
    refreshes++;
    return const <PendingNotification>[];
  }

  @override
  Future<void> schedule({
    required int platformId,
    required String title,
    required String body,
    required String payload,
    required DateTime fireAt,
  }) async {
    schedules++;
  }

  @override
  Future<void> cancel(int platformId) async {
    cancels++;
  }
}

/// The harness a test pumps against.
class _OnboardingHarness {
  const _OnboardingHarness(
    this.container,
    this.repository,
    this.router,
    this.adapter,
  );

  final ProviderContainer container;
  final SqliteProgramRepository repository;
  final GoRouter router;
  final _RecordingAdapter adapter;

  /// The route the router sits on, as a location string.
  String get location => router.routeInformationProvider.value.uri.toString();

  /// The raw SharedPreferences store the real settings provider persists to.
  Future<Map<String, dynamic>> storedSettings() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? raw = prefs.getString(DevotionsSettingsNotifier.storageKey);
    if (raw == null) {
      return const <String, dynamic>{};
    }
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  /// The raw SharedPreferences store the SHARED base-settings notifier
  /// persists to (its storage key lives in shared_ui's
  /// `base_settings_provider.dart` — a private constant).
  Future<Map<String, dynamic>> storedBaseSettings() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? raw = prefs.getString('sancta_via_base_settings');
    if (raw == null) {
      return const <String, dynamic>{};
    }
    return jsonDecode(raw) as Map<String, dynamic>;
  }
}

/// Pumps the REAL onboarding walkthrough through the app router over the
/// production provider chain (catalog prewarmed; settings over the mock
/// store; notification service on a recording adapter).
///
/// [seed] runs INSIDE the prewarm (after the catalog is seeded, before the
/// widget phase), so a test can plant pre-existing enrollment/progress the
/// walkthrough's own store-seeding pass then reads — the re-entry shape.
Future<_OnboardingHarness> _pumpOnboarding(
  WidgetTester tester, {
  required DateTime today,
  bool onboardingComplete = false,
  Future<void> Function(SqliteProgramRepository repository)? seed,
}) async {
  _setMockSettings(onboardingComplete: onboardingComplete);
  final DevotionalsDatabase database = DevotionalsDatabase(open: _openInMemory);
  final SqliteProgramRepository repository = SqliteProgramRepository(
    database: database,
  );
  final GoRouter router = buildAppRouter(initialLocation: '/onboarding');
  final _RecordingAdapter adapter = _RecordingAdapter();

  // The provider that owns the notification service is overridden with a
  // service wired to the recording adapter; its settings getter reads the
  // container lazily (assigned below, invoked only during the walkthrough).
  late final ProviderContainer container;
  final NotificationService service = NotificationService(
    database: repository.database,
    repository: repository,
    settings: () => container.read(devotionsSettingsProvider),
    adapter: adapter,
    clock: () => today,
    upcomingFeasts: (DateTime _) => const <LiturgicalDayData>[],
  );
  final ProviderContainer built = ProviderContainer(
    overrides: <Override>[
      appProgramRepositoryProvider.overrideWithValue(repository),
      programRepositoryOverride,
      currentDateProvider.overrideWith(
        (Ref ref) => Stream<DateTime>.value(today),
      ),
      notificationServiceProvider.overrideWithValue(service),
    ],
  );
  // The late-final handoff: assign through the closure's captured variable.
  container = built;
  addTearDown(container.dispose);

  await tester.runAsync(() async {
    container.read(devotionsSettingsProvider.notifier);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await container.read(contentLoadedProvider.future);
    if (seed != null) {
      await seed(repository);
    }
  });

  tester.view.physicalSize = const Size(600, 1800);
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
  return _OnboardingHarness(container, repository, router, adapter);
}

/// Flushes a tap's await chain (the enroll-screen harness's drained rounds;
/// Task 21 widened the budget, Task 23 again): the fake-async zone's queued
/// microtasks clear one layer per real-time window and the
/// refresh/recompute depth scales with the shipped pack count (each SQLite
/// round trip is a layer — 33 packs since the Task-21 routine, Task-22
/// novena, and Task-23 chaplet/litany packs joined the catalog; under full
/// suite load the walkthrough chains need the wider settle budget), so the
/// rounds must cover the widest chain the taps trigger.
Future<void> _drain(WidgetTester tester) async {
  for (int round = 0; round < 80; round++) {
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 15));
    });
    await tester.pump(const Duration(milliseconds: 15));
  }
}

/// Taps [finder] and drains the async chain behind it.
Future<void> _tapAndDrain(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder.last);
  await tester.pump(const Duration(milliseconds: 10));
  await tester.tap(finder.last);
  await _drain(tester);
}

/// Walks the stepper to [value] on the claim step.
Future<void> _claimTo(WidgetTester tester, String packId, int value) async {
  final Finder plus = find.byKey(Key('claim_plus_$packId'));
  for (int i = 0; i < value; i++) {
    await tester.tap(plus);
    await tester.pump(const Duration(milliseconds: 20));
  }
}

/// The integer the claim stepper currently shows for [packId].
int _claimValue(WidgetTester tester, String packId) {
  final Text text = tester.widget<Text>(find.byKey(Key('claim_value_$packId')));
  return int.parse(text.data!);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(tzdata.initializeTimeZones);

  // The gate is a process-wide hook: every test restores the unwired state
  // (Task 13's harnesses rely on the redirect never firing).
  tearDown(() {
    appOnboardingGate = null;
  });

  group('the walkthrough flow', () {
    testWidgets('a full walk sets onboardingComplete and lands on Today', (
      WidgetTester tester,
    ) async {
      final _OnboardingHarness harness = await _pumpOnboarding(
        tester,
        today: _frozenToday,
      );

      // The welcome step opens: the value statement and the free/offline
      // note, with the walkthrough's first Next.
      expect(find.byKey(const Key('onboarding_welcome')), findsOneWidget);
      expect(find.byKey(const Key('onboarding_next')), findsOneWidget);
      expect(find.textContaining('free'), findsAtLeastNWidgets(1));

      // Walk claim → routine → reminders with nothing changed; the claim
      // steppers sit at 0 and every routine switch is off.
      await _tapAndDrain(tester, find.byKey(const Key('onboarding_next')));
      expect(find.byKey(const Key('claim_step')), findsOneWidget);
      await _tapAndDrain(tester, find.byKey(const Key('onboarding_next')));
      expect(find.byKey(const Key('routine_step')), findsOneWidget);
      expect(find.byKey(const Key('routine_toggle_angelus')), findsOneWidget);
      expect(
        find.byKey(const Key('routine_toggle_mercy_hour')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('routine_toggle_rosary')), findsOneWidget);
      expect(
        find.byKey(const Key('routine_toggle_night_items')),
        findsOneWidget,
      );
      // The round-1 minor: the routine card says switching off never removes
      // an already-enrolled program.
      expect(find.textContaining('never remove'), findsOneWidget);
      await _tapAndDrain(tester, find.byKey(const Key('onboarding_next')));
      expect(find.byKey(const Key('reminders_step')), findsOneWidget);
      expect(find.byKey(const Key('reminder_toggle_morning')), findsOneWidget);
      expect(find.byKey(const Key('reminder_toggle_evening')), findsOneWidget);

      // Done: the setting flips, the store carries it, and Today opens.
      await _tapAndDrain(tester, find.byKey(const Key('onboarding_next')));
      expect(find.byKey(const Key('done_step')), findsOneWidget);
      await _tapAndDrain(tester, find.byKey(const Key('onboarding_done')));

      expect(harness.container.read(onboardingCompleteProvider), isTrue);
      expect((await harness.storedSettings())['onboardingComplete'], isTrue);
      expect(harness.location, '/');
      // The route transition runs ~300ms: let the old walkthrough page leave
      // the tree before asserting on what remains.
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.byType(TodayScreen), findsOneWidget);
      expect(find.byType(OnboardingScreen), findsNothing);

      // Nothing claimed or toggled: the walkthrough wrote nothing.
      for (final String packId in <String>[
        'five_first_saturdays',
        'nine_first_fridays',
        'angelus',
        'mercy_hour',
        'rosary',
      ]) {
        expect(
          await tester.runAsync(
            () => harness.repository.enrollmentParamsFor(packId),
          ),
          isNull,
        );
      }
      expect(
        await tester.runAsync(
          () => harness.repository.progressFor('five_first_saturdays'),
        ),
        isNull,
      );
    });

    testWidgets(
      'claiming 3 First Saturdays at the frozen 2026-11-10 persists the '
      'records-free ordinals and the last anchor before today',
      (WidgetTester tester) async {
        final _OnboardingHarness harness = await _pumpOnboarding(
          tester,
          today: _frozenToday,
        );
        await _tapAndDrain(tester, find.byKey(const Key('onboarding_next')));

        // The commitment pack's stepper: 0..5, starting at 0.
        expect(_claimValue(tester, 'five_first_saturdays'), 0);
        await _claimTo(tester, 'five_first_saturdays', 3);
        expect(_claimValue(tester, 'five_first_saturdays'), 3);

        // Step past the stepper's cap and floor: the buttons clamp 0..count.
        await tester.tap(
          find.byKey(const Key('claim_plus_five_first_saturdays')),
        );
        await tester.tap(
          find.byKey(const Key('claim_plus_five_first_saturdays')),
        );
        await tester.pump(const Duration(milliseconds: 20));
        expect(_claimValue(tester, 'five_first_saturdays'), 5);
        for (int i = 0; i < 3; i++) {
          await tester.tap(
            find.byKey(const Key('claim_minus_five_first_saturdays')),
          );
        }
        await tester.pump(const Duration(milliseconds: 20));
        expect(_claimValue(tester, 'five_first_saturdays'), 2);
        // One more step brings the claim back to 3.
        await tester.tap(
          find.byKey(const Key('claim_plus_five_first_saturdays')),
        );
        await tester.pump(const Duration(milliseconds: 20));
        expect(_claimValue(tester, 'five_first_saturdays'), 3);

        await _tapAndDrain(tester, find.byKey(const Key('onboarding_next')));
        await _tapAndDrain(tester, find.byKey(const Key('onboarding_next')));
        await _tapAndDrain(tester, find.byKey(const Key('onboarding_next')));
        await _tapAndDrain(tester, find.byKey(const Key('onboarding_done')));

        // Persisted through the real repository: the claimed ordinals, the
        // last First Saturday BEFORE the frozen day (2026-11-07), and the
        // records-free composition — no completion records, no badges.
        final ProgressState? progress = await tester.runAsync<ProgressState?>(
          () => harness.repository.progressFor('five_first_saturdays'),
        );
        expect(progress, isNotNull);
        expect(progress!.fulfilledOrdinals, 3);
        expect(progress.lastFulfilled, DateTime(2026, 11, 7));
        expect(progress.completedItemsByDay, isEmpty);
        expect(progress.badges, isEmpty);
        expect(
          await tester.runAsync(
            () =>
                harness.repository.enrollmentParamsFor('five_first_saturdays'),
          ),
          isNotNull,
          reason: 'a claim enrolls the pack it writes progress for',
        );

        // The composed position: the engine's projection over the claimed
        // ordinals resolves 2026-12-05 as the next due First Saturday.
        final List<ContentPack> packs = (await tester.runAsync(
          () => harness.repository.loadPacks(),
        ))!;
        final ContentPack pack = packs.firstWhere(
          (ContentPack candidate) => candidate.id == 'five_first_saturdays',
        );
        final List<DateTime> remaining = Projection.remainingDates(
          pack.schedule as ConsecutiveCommitmentSpec,
          3,
          _frozenToday,
        );
        expect(remaining.first, DateTime(2026, 12, 5));
      },
    );

    testWidgets(
      'claiming 1 First Friday at the frozen day anchors 2026-11-06, next '
      'due 2026-12-04',
      (WidgetTester tester) async {
        final _OnboardingHarness harness = await _pumpOnboarding(
          tester,
          today: _frozenToday,
        );
        await _tapAndDrain(tester, find.byKey(const Key('onboarding_next')));

        await _claimTo(tester, 'nine_first_fridays', 1);
        await _tapAndDrain(tester, find.byKey(const Key('onboarding_next')));
        await _tapAndDrain(tester, find.byKey(const Key('onboarding_next')));
        await _tapAndDrain(tester, find.byKey(const Key('onboarding_next')));
        await _tapAndDrain(tester, find.byKey(const Key('onboarding_done')));

        final ProgressState? progress = await tester.runAsync<ProgressState?>(
          () => harness.repository.progressFor('nine_first_fridays'),
        );
        expect(progress!.fulfilledOrdinals, 1);
        expect(progress.lastFulfilled, DateTime(2026, 11, 6));
        final List<ContentPack> packs = (await tester.runAsync(
          () => harness.repository.loadPacks(),
        ))!;
        final ContentPack pack = packs.firstWhere(
          (ContentPack candidate) => candidate.id == 'nine_first_fridays',
        );
        final List<DateTime> remaining = Projection.remainingDates(
          pack.schedule as ConsecutiveCommitmentSpec,
          1,
          _frozenToday,
        );
        expect(remaining.first, DateTime(2026, 12, 4));
      },
    );

    testWidgets('a claim can be taken back before finishing', (
      WidgetTester tester,
    ) async {
      final _OnboardingHarness harness = await _pumpOnboarding(
        tester,
        today: _frozenToday,
      );
      await _tapAndDrain(tester, find.byKey(const Key('onboarding_next')));

      // Claim, advance, come back, and step it to zero: the walkthrough
      // owns the claim it made this run, so nothing stays behind.
      await _claimTo(tester, 'five_first_saturdays', 2);
      await _tapAndDrain(tester, find.byKey(const Key('onboarding_next')));
      await _tapAndDrain(tester, find.byKey(const Key('onboarding_back')));
      await tester.tap(
        find.byKey(const Key('claim_minus_five_first_saturdays')),
      );
      await tester.tap(
        find.byKey(const Key('claim_minus_five_first_saturdays')),
      );
      await tester.pump(const Duration(milliseconds: 20));
      await _tapAndDrain(tester, find.byKey(const Key('onboarding_next')));
      await _tapAndDrain(tester, find.byKey(const Key('onboarding_next')));
      await _tapAndDrain(tester, find.byKey(const Key('onboarding_next')));
      await _tapAndDrain(tester, find.byKey(const Key('onboarding_done')));

      expect(
        await tester.runAsync(
          () => harness.repository.enrollmentParamsFor('five_first_saturdays'),
        ),
        isNull,
      );
      expect(
        await tester.runAsync(
          () => harness.repository.progressFor('five_first_saturdays'),
        ),
        isNull,
      );
    });

    // ---------------------------------------------------------------------
    // Fix round 1: the claim step never rewrites what it did not change, and
    // the take-back / routine switch-off paths never destroy history.
    // ---------------------------------------------------------------------

    testWidgets(
      'advancing the claim step unchanged never rewrites a lapsed prior '
      'state (no fabricated lastFulfilled, no repetitions reset)',
      (WidgetTester tester) async {
        final _OnboardingHarness harness = await _pumpOnboarding(
          tester,
          today: _frozenToday,
          // A re-entry user whose claim lapsed months ago: the missed-day
          // gap is measured from this lastFulfilled, and the day's
          // repetitions are part of the persisted state.
          seed: (SqliteProgramRepository repository) async {
            await repository.enroll(
              'five_first_saturdays',
              <String, dynamic>{},
            );
            await repository.saveProgress(
              ProgressState(
                packId: 'five_first_saturdays',
                fulfilledOrdinals: 3,
                lastFulfilled: DateTime(2026, 9, 10),
                repetitionsToday: 2,
              ),
            );
          },
        );
        await _tapAndDrain(tester, find.byKey(const Key('onboarding_next')));

        // The stepper seeds from the persisted claim…
        expect(_claimValue(tester, 'five_first_saturdays'), 3);

        // …and advancing WITHOUT touching it must be a pure no-op: the
        // step's own copy promises nothing is backdated, so the persisted
        // lastFulfilled must NOT be recomputed to the last anchor before
        // today (that would fabricate a recent fulfillment and erase the
        // lapse), and repetitionsToday must survive.
        await _tapAndDrain(tester, find.byKey(const Key('onboarding_next')));
        await _tapAndDrain(tester, find.byKey(const Key('onboarding_next')));
        await _tapAndDrain(tester, find.byKey(const Key('onboarding_next')));
        await _tapAndDrain(tester, find.byKey(const Key('onboarding_done')));

        final ProgressState? progress = await tester.runAsync<ProgressState?>(
          () => harness.repository.progressFor('five_first_saturdays'),
        );
        expect(progress, isNotNull);
        expect(progress!.fulfilledOrdinals, 3);
        expect(
          progress.lastFulfilled,
          DateTime(2026, 9, 10),
          reason: 'an unchanged claim never fabricates a recent fulfillment',
        );
        expect(
          progress.repetitionsToday,
          2,
          reason: 'an unchanged claim never resets the day\'s repetitions',
        );
      },
    );

    testWidgets(
      'a take-back restores the pre-run state: earned badges and records '
      'survive a 3→0 claim withdrawal',
      (WidgetTester tester) async {
        final _OnboardingHarness harness = await _pumpOnboarding(
          tester,
          today: _frozenToday,
          // A re-entry user with earned history: one prior fulfillment and
          // two badges (badges are dated completions, not streak state).
          seed: (SqliteProgramRepository repository) async {
            await repository.enroll(
              'five_first_saturdays',
              <String, dynamic>{},
            );
            await repository.saveProgress(
              ProgressState(
                packId: 'five_first_saturdays',
                fulfilledOrdinals: 1,
                lastFulfilled: DateTime(2026, 10, 3),
                completedItemsByDay: const <String, String>{
                  'communion:2026-10-03': '2026-10-03',
                },
                badges: <BadgeRecord>[
                  BadgeRecord(
                    title: 'Five First Saturdays of Our Lady',
                    date: DateTime(2026, 8, 1),
                  ),
                  BadgeRecord(
                    title: 'Five First Saturdays of Our Lady',
                    date: DateTime(2026, 10, 3),
                  ),
                ],
              ),
            );
          },
        );
        await _tapAndDrain(tester, find.byKey(const Key('onboarding_next')));
        expect(_claimValue(tester, 'five_first_saturdays'), 1);

        // Claim 3, advance, come back, and withdraw the claim entirely.
        await _claimTo(tester, 'five_first_saturdays', 2);
        expect(_claimValue(tester, 'five_first_saturdays'), 3);
        await _tapAndDrain(tester, find.byKey(const Key('onboarding_next')));
        await _tapAndDrain(tester, find.byKey(const Key('onboarding_back')));
        for (int i = 0; i < 3; i++) {
          await tester.tap(
            find.byKey(const Key('claim_minus_five_first_saturdays')),
          );
        }
        await tester.pump(const Duration(milliseconds: 20));
        expect(_claimValue(tester, 'five_first_saturdays'), 0);
        await _tapAndDrain(tester, find.byKey(const Key('onboarding_next')));
        await _tapAndDrain(tester, find.byKey(const Key('onboarding_next')));
        await _tapAndDrain(tester, find.byKey(const Key('onboarding_next')));
        await _tapAndDrain(tester, find.byKey(const Key('onboarding_done')));

        // RULING (a): the take-back restores the prior state — the
        // enrollment and the earned history both survive.
        expect(
          await tester.runAsync(
            () =>
                harness.repository.enrollmentParamsFor('five_first_saturdays'),
          ),
          isNotNull,
          reason: 'a take-back never unenrolls a pre-existing program',
        );
        final ProgressState? progress = await tester.runAsync<ProgressState?>(
          () => harness.repository.progressFor('five_first_saturdays'),
        );
        expect(progress, isNotNull);
        expect(progress!.fulfilledOrdinals, 1);
        expect(progress.lastFulfilled, DateTime(2026, 10, 3));
        expect(progress.badges.length, 2, reason: 'earned badges survive');
        expect(progress.completedItemsByDay, <String, String>{
          'communion:2026-10-03': '2026-10-03',
        });
      },
    );

    testWidgets(
      'a routine switch-off never destroys a pre-existing enrollment (only '
      'programs this run enrolled are un-enrolled)',
      (WidgetTester tester) async {
        final _OnboardingHarness harness = await _pumpOnboarding(
          tester,
          today: _frozenToday,
          seed: (SqliteProgramRepository repository) async {
            await repository.enroll('rosary', <String, dynamic>{
              'via': 'practice',
            });
            await repository.saveProgress(
              ProgressState(packId: 'rosary', fulfilledOrdinals: 4),
            );
          },
        );
        await _tapAndDrain(tester, find.byKey(const Key('onboarding_next')));
        await _tapAndDrain(tester, find.byKey(const Key('onboarding_next')));

        // The rosary seeds ON from the store; switching it off is a LOCAL UI
        // choice this run — onboarding only ADDS toggles, and it never
        // destroys an enrollment (or its progress) it did not create.
        await _tapAndDrain(
          tester,
          find.byKey(const Key('routine_toggle_rosary')),
        );
        // A pack this run enrolled and switched back off IS taken back.
        await _tapAndDrain(
          tester,
          find.byKey(const Key('routine_toggle_angelus')),
        );
        await _tapAndDrain(
          tester,
          find.byKey(const Key('routine_toggle_angelus')),
        );
        await _tapAndDrain(tester, find.byKey(const Key('onboarding_next')));
        await _tapAndDrain(tester, find.byKey(const Key('onboarding_next')));
        await _tapAndDrain(tester, find.byKey(const Key('onboarding_done')));

        expect(
          await tester.runAsync(
            () => harness.repository.enrollmentParamsFor('rosary'),
          ),
          isNotNull,
          reason: 'a pre-existing enrollment persists through a switch-off',
        );
        expect(
          await tester.runAsync<ProgressState?>(
            () => harness.repository.progressFor('rosary'),
          ),
          isNotNull,
          reason: 'and so does its persisted progress',
        );
        expect(
          await tester.runAsync(
            () => harness.repository.enrollmentParamsFor('angelus'),
          ),
          isNull,
          reason: 'a program enrolled only by this run is taken back',
        );
      },
    );

    testWidgets(
      'the routine step toggles the catalog routine packs and the night '
      'anchors setting through',
      (WidgetTester tester) async {
        final _OnboardingHarness harness = await _pumpOnboarding(
          tester,
          today: _frozenToday,
        );
        await _tapAndDrain(tester, find.byKey(const Key('onboarding_next')));
        await _tapAndDrain(tester, find.byKey(const Key('onboarding_next')));

        // The catalog's routine family packs (seeded: Angelus, Hour of
        // Mercy, Holy Rosary), each with a toggle; nothing is hard-coded.
        expect(
          find.text('The Angelus (Regina Caeli in Eastertide)'),
          findsOneWidget,
        );
        expect(find.text('The Hour of Mercy'), findsOneWidget);
        expect(find.text('The Holy Rosary'), findsOneWidget);

        // Angelus + mercy on; rosary stays off; the meal & night anchors
        // toggle writes the off-by-default setting.
        await _tapAndDrain(
          tester,
          find.byKey(const Key('routine_toggle_angelus')),
        );
        await _tapAndDrain(
          tester,
          find.byKey(const Key('routine_toggle_mercy_hour')),
        );
        await _tapAndDrain(
          tester,
          find.byKey(const Key('routine_toggle_night_items')),
        );
        await _tapAndDrain(tester, find.byKey(const Key('onboarding_next')));
        await _tapAndDrain(tester, find.byKey(const Key('onboarding_next')));
        await _tapAndDrain(tester, find.byKey(const Key('onboarding_done')));

        expect(
          await tester.runAsync(
            () => harness.repository.enrollmentParamsFor('angelus'),
          ),
          isNotNull,
        );
        expect(
          await tester.runAsync(
            () => harness.repository.enrollmentParamsFor('mercy_hour'),
          ),
          isNotNull,
        );
        expect(
          await tester.runAsync(
            () => harness.repository.enrollmentParamsFor('rosary'),
          ),
          isNull,
        );
        expect(
          harness.container.read(devotionsSettingsProvider).nightItemsEnabled,
          isTrue,
        );
        expect((await harness.storedSettings())['nightItemsEnabled'], isTrue);
      },
    );

    testWidgets(
      'enabling reminders requests permission once and writes the toggles — '
      'and opens the shared master gate so consents plan rows',
      (WidgetTester tester) async {
        final _OnboardingHarness harness = await _pumpOnboarding(
          tester,
          today: _frozenToday,
        );
        await _tapAndDrain(tester, find.byKey(const Key('onboarding_next')));
        // The routine step enrolls the Angelus first: the reminder consent's
        // own refresh pass then has a plan input to schedule (the gate-open
        // fix round 2 pin below is about the PLANNER's output, not just the
        // flag).
        await _tapAndDrain(tester, find.byKey(const Key('onboarding_next')));
        await _tapAndDrain(
          tester,
          find.byKey(const Key('routine_toggle_angelus')),
        );
        await _tapAndDrain(tester, find.byKey(const Key('onboarding_next')));

        // Both reminder enables share ONE plugin initialization: the
        // service's initialize is the permission request, and it is
        // idempotent (first successful attempt kept).
        await _tapAndDrain(
          tester,
          find.byKey(const Key('reminder_toggle_morning')),
        );
        await _tapAndDrain(
          tester,
          find.byKey(const Key('reminder_toggle_evening')),
        );
        expect(harness.adapter.initializeCalls, 1);
        expect(harness.adapter.refreshes, greaterThanOrEqualTo(1));
        expect(
          harness.container
              .read(devotionsSettingsProvider)
              .morningReminderEnabled,
          isTrue,
        );
        expect(
          harness.container
              .read(devotionsSettingsProvider)
              .eveningReminderEnabled,
          isTrue,
        );
        expect(
          (await harness.storedSettings())['morningReminderEnabled'],
          isTrue,
        );
        expect(
          (await harness.storedSettings())['eveningReminderEnabled'],
          isTrue,
        );

        // Fix round 2: a consent given in onboarding opens the SHARED
        // master gate in the same step — the walkthrough's promise is that
        // the reminders actually arrive (the gate closes the plan; a taken
        // consent must never schedule nothing).
        expect(
          harness.container.read(baseSettingsProvider).notificationsEnabled,
          isTrue,
        );
        // The base settings store the shared notifier persists to (its
        // storage key lives in shared_ui's base_settings_provider.dart).
        expect(
          (await harness.storedBaseSettings())['notificationsEnabled'],
          isTrue,
        );
        // The one-way sync carried the gate into the app settings snapshot.
        expect(
          ((await harness.storedSettings())['baseSettings']
              as Map<String, dynamic>)['notificationsEnabled'],
          isTrue,
        );
        // And the consent's own refresh pass PLANNED: the enrolled
        // Angelus's anchor reminders exist on the device and in the index —
        // the invariant pinned end-to-end.
        expect(harness.adapter.schedules, greaterThan(0));
        final List<NotificationRow> plannedRows =
            await tester.runAsync(
              () => harness.repository.database.getAllNotifications(),
            ) ??
            const <NotificationRow>[];
        expect(
          plannedRows.where(
            (NotificationRow row) =>
                row.status == 'scheduled' &&
                row.id.startsWith('angelus:anchor:'),
          ),
          isNotEmpty,
        );

        await _tapAndDrain(tester, find.byKey(const Key('onboarding_next')));
        await _tapAndDrain(tester, find.byKey(const Key('onboarding_done')));
        expect(harness.container.read(onboardingCompleteProvider), isTrue);
        expect(harness.adapter.initializeCalls, 1);
        // The done step landed on Today with enrollments in place: the
        // Today branch's assembly re-resolve runs REAL SQLite futures that
        // the fake-async pumps cannot complete — settle them so no sqflite
        // transaction-lock timer outlives the test (the recipe's real-time
        // drain rounds).
        await _drain(tester);
      },
    );
  });

  group('the cold-start rule', () {
    test('an unresolved settings load keeps the persisted entry route', () {
      // Fresh install: the store opened the walkthrough, and the pre-load
      // live default (`onboardingComplete: false`) agrees.
      expect(
        decideColdStartRoute(
          isLoaded: false,
          onboardingComplete: false,
          persistedEntry: '/onboarding',
        ),
        '/onboarding',
      );
      // Returning user: the pre-load live default is STILL `false`, but the
      // persisted entry wins — the app must never bounce into the walkthrough
      // before the store is read.
      expect(
        decideColdStartRoute(
          isLoaded: false,
          onboardingComplete: false,
          persistedEntry: '/',
        ),
        '/',
      );
      // The branch itself: while un-loaded even a live "complete" cannot move
      // the app off the persisted entry. Deleting the `!isLoaded` guard flips
      // this to '/' and the pin fails (the red-able mechanism).
      expect(
        decideColdStartRoute(
          isLoaded: false,
          onboardingComplete: true,
          persistedEntry: '/onboarding',
        ),
        '/onboarding',
      );
    });

    test('once loaded, the live flag decides the entry route', () {
      expect(
        decideColdStartRoute(
          isLoaded: true,
          onboardingComplete: false,
          persistedEntry: '/',
        ),
        '/onboarding',
      );
      expect(
        decideColdStartRoute(
          isLoaded: true,
          onboardingComplete: true,
          persistedEntry: '/onboarding',
        ),
        '/',
      );
    });
  });

  group("the app router's onboarding gate", () {
    // A settled production chain under every gate probe: the screens the
    // router renders (Today, onboarding, settings) all consume providers.
    Future<GoRouter> pumpGateRouter(WidgetTester tester) async {
      _setMockSettings();
      final DevotionalsDatabase database = DevotionalsDatabase(
        open: _openInMemory,
      );
      final SqliteProgramRepository repository = SqliteProgramRepository(
        database: database,
      );
      final GoRouter router = buildAppRouter();
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          appProgramRepositoryProvider.overrideWithValue(repository),
          programRepositoryOverride,
          currentDateProvider.overrideWith(
            (Ref ref) => Stream<DateTime>.value(_frozenToday),
          ),
        ],
      );
      addTearDown(container.dispose);
      await tester.runAsync(() async {
        container.read(devotionsSettingsProvider.notifier);
        await Future<void>.delayed(const Duration(milliseconds: 20));
        await container.read(contentLoadedProvider.future);
      });
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));
      return router;
    }

    tearDown(() {
      // The gate is a process-wide hook: every test restores the unwired
      // state (Task 13's harnesses rely on the redirect never firing).
      appOnboardingGate = null;
    });

    testWidgets('unwired, the router never redirects', (tester) async {
      final GoRouter router = await pumpGateRouter(tester);
      expect(
        router.routeInformationProvider.value.uri.toString(),
        '/',
        reason: 'the unwired router keeps Task 13’s behaviors untouched',
      );
    });

    testWidgets('wired-false, everything off /onboarding redirects there', (
      tester,
    ) async {
      appOnboardingGate = () => false;
      final GoRouter router = await pumpGateRouter(tester);
      expect(
        router.routeInformationProvider.value.uri.toString(),
        '/onboarding',
        reason: 'an un-onboarded app cold-starts into the walkthrough',
      );
      router.go('/settings');
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 50));
      expect(
        router.routeInformationProvider.value.uri.toString(),
        '/onboarding',
      );
    });

    testWidgets('wired-true, no redirect fires and re-entry stays open', (
      tester,
    ) async {
      appOnboardingGate = () => true;
      final GoRouter router = await pumpGateRouter(tester);
      expect(router.routeInformationProvider.value.uri.toString(), '/');
      router.go('/onboarding');
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 50));
      expect(
        router.routeInformationProvider.value.uri.toString(),
        '/onboarding',
      );
      expect(find.byType(OnboardingScreen), findsOneWidget);
    });

    test(
      'the persisted flag reads true, false, and corrupt-store-safe',
      () async {
        _setMockSettings(onboardingComplete: true);
        expect(await readPersistedOnboardingComplete(), isTrue);

        _setMockSettings(onboardingComplete: false);
        expect(await readPersistedOnboardingComplete(), isFalse);

        // No store at all: a fresh install has not onboarded.
        SharedPreferences.setMockInitialValues(<String, Object>{});
        expect(await readPersistedOnboardingComplete(), isFalse);

        // A corrupt store reads as "not onboarding complete": the entry route
        // decision must never crash the cold start.
        SharedPreferences.setMockInitialValues(<String, Object>{
          DevotionsSettingsNotifier.storageKey: 'not json',
        });
        expect(await readPersistedOnboardingComplete(), isFalse);
      },
    );
  });

  group('main.dart cold-start wiring', () {
    testWidgets('the app boots into onboarding until it completes', (
      tester,
    ) async {
      // The production app wiring under the same frozen chain: the settings
      // store says onboarding is not complete, and the app's onboarding gate
      // (wired in initState) owns the redirect rules.
      _setMockSettings(onboardingComplete: false);
      final DevotionalsDatabase database = DevotionalsDatabase(
        open: _openInMemory,
      );
      final SqliteProgramRepository repository = SqliteProgramRepository(
        database: database,
      );
      final GoRouter router = buildAppRouter(initialLocation: '/');
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          appProgramRepositoryProvider.overrideWithValue(repository),
          programRepositoryOverride,
          currentDateProvider.overrideWith(
            (Ref ref) => Stream<DateTime>.value(_frozenToday),
          ),
        ],
      );
      addTearDown(container.dispose);
      await tester.runAsync(() async {
        container.read(devotionsSettingsProvider.notifier);
        await Future<void>.delayed(const Duration(milliseconds: 20));
        await container.read(contentLoadedProvider.future);
      });
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: SanctaViaDevotionalsApp(router: router),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));
      expect(
        router.routeInformationProvider.value.uri.toString(),
        '/onboarding',
        reason: 'the app widget wires the gate over its live settings',
      );
      expect(find.byType(OnboardingScreen), findsOneWidget);
    });

    // Fix round 1: the cold-start race the `isLoaded` guard exists for — the
    // gate must treat an UNRESOLVED settings load as "complete" (a returning
    // user's entry route was already decided from the store in `main`), so a
    // pre-load default `onboardingComplete: false` never bounces the router
    // into the walkthrough.
    testWidgets('an unresolved settings load never bounces the router into the '
        'walkthrough', (WidgetTester tester) async {
      // The store DOES say complete — the shape a returning user has.
      _setMockSettings(onboardingComplete: true);
      final DevotionalsDatabase database = DevotionalsDatabase(
        open: _openInMemory,
      );
      final SqliteProgramRepository repository = SqliteProgramRepository(
        database: database,
      );
      final GoRouter router = buildAppRouter(initialLocation: '/');
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          appProgramRepositoryProvider.overrideWithValue(repository),
          programRepositoryOverride,
          currentDateProvider.overrideWith(
            (Ref ref) => Stream<DateTime>.value(_frozenToday),
          ),
        ],
      );
      addTearDown(container.dispose);

      // The catalog prewarm (asset loads need `runAsync`); the settings
      // load is deliberately NOT touched yet — it is the thing under test.
      await tester.runAsync(() async {
        await container.read(contentLoadedProvider.future);
      });

      // The notifier's async load is in flight at construction: the
      // in-memory state is the defaults (`onboardingComplete: false`) and
      // `isLoaded` is false. The PURE cold-start rule (the one production's
      // gate calls) keeps the persisted entry — no guesswork bounce.
      final DevotionsSettingsNotifier notifier = container.read(
        devotionsSettingsProvider.notifier,
      );
      expect(notifier.isLoaded, isFalse);
      expect(notifier.state.onboardingComplete, isFalse);
      expect(
        decideColdStartRoute(
          isLoaded: notifier.isLoaded,
          onboardingComplete: notifier.state.onboardingComplete,
          persistedEntry: '/',
        ),
        '/',
        reason: 'an unresolved load must never be held in the walkthrough',
      );

      // The app boots on the store's entry route ('/') with the load still
      // unresolved: the first frame must NOT bounce.
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: SanctaViaDevotionalsApp(router: router),
        ),
      );
      expect(router.routeInformationProvider.value.uri.toString(), '/');

      // Let the load resolve: the store says complete, so still no bounce.
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      });
      await tester.pump(const Duration(milliseconds: 50));
      expect(
        container.read(devotionsSettingsProvider.notifier).isLoaded,
        isTrue,
      );
      expect(
        container.read(onboardingCompleteProvider),
        isTrue,
        reason: 'the store\'s completed flag lands with the load',
      );
      expect(router.routeInformationProvider.value.uri.toString(), '/');
    });
  });
}
