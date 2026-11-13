// Settings screen widget tests (Plan 2, Task 20).
//
// The harness mirrors Task 13/16/19's real-chain recipe: the REAL app
// repository over an isolated in-memory FFI store, the REAL seeded catalog,
// the REAL `DevotionsSettingsNotifier` over mock SharedPreferences (so a
// policy write lands in the store the same key production persists under),
// and Task 18's notification service over the recording plugin adapter —
// whose `pendingNotifications()` count IS the re-plan count (one call per
// refresh pass), so a change event's refresh shows up as exactly one more
// increment without any enrollment state at all.
//
// Pinned cases (the brief's three steps, plus the composition pins):
// 1. the app section renders the pinned controls with their stored values;
// 2. a schedule-relevant toggle (anchor toggles, night items) updates the
//    settings and triggers exactly ONE planner refresh per change event;
// 3. an anchor time changed through the picker updates the settings, the
//    rendered time, and triggers one refresh;
// 4. the missed-day policy selector persists the chosen value (and a
//    non-schedule change never triggers a refresh);
// 5. an unknown stored policy value is refused — neither row presents it as
//    chosen, the not-recognized note renders, and picking a known value is
//    the fix path (the Task-2 vocabulary: only 'strict' | 'permissive');
// 6. base-settings controls delegate to the shared providers: the
//    notifications gate to `baseSettingsProvider`, language likewise (and
//    the app snapshot syncs it one-way), theme mode to the shared
//    `themeModeProvider`;
// 7. the settings branch mounts the real screen (the Task-14 stub's copy is
//    gone and `SettingsScreen` no longer exists).
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sancta_via_devotionals/config/routes.dart' show buildAppRouter;
import 'package:sancta_via_devotionals/database/devotionals_database.dart';
import 'package:sancta_via_devotionals/models/app_settings.dart'
    show DevotionsAppSettings;
import 'package:sancta_via_devotionals/providers/app_settings_provider.dart'
    show DevotionsSettingsNotifier, devotionsSettingsProvider;
import 'package:sancta_via_devotionals/providers/content_providers.dart'
    show
        appProgramRepositoryProvider,
        contentLoadedProvider,
        programRepositoryOverride;
import 'package:sancta_via_devotionals/providers/today_providers.dart'
    show notificationServiceProvider;
import 'package:sancta_via_devotionals/repositories/program_repository.dart'
    show SqliteProgramRepository;
import 'package:sancta_via_devotionals/screens/settings/devotionals_settings_screen.dart'
    show DevotionalsSettingsScreen;
import 'package:sancta_via_devotionals/services/notification_service.dart'
    show
        NotificationPluginAdapter,
        NotificationPluginInit,
        NotificationService,
        PendingNotification;
import 'package:sancta_via_liturgical_calendar/sancta_via_liturgical_calendar.dart'
    show LiturgicalDayData;
import 'package:sancta_via_shared_ui/sancta_via_shared_ui.dart'
    show baseSettingsProvider, themeModeProvider;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:timezone/data/latest.dart' as tzdata;

/// A fresh, isolated in-memory store open factory.
Future<Database> _openInMemory() =>
    openDatabase(inMemoryDatabasePath, singleInstance: false);

/// The harness's clock: an ordinary December day in the planner's horizon.
final DateTime _frozenToday = DateTime(2026, 12, 5);

/// A store whose persisted settings carry an unrecognized missed-day policy
/// (e.g. written by a version that allowed an unguarded string) — the
/// selector must refuse it rather than present it as chosen.
Map<String, Object> _storeWithUnknownPolicy() {
  final Map<String, dynamic> defaults = Map<String, dynamic>.from(
    DevotionsAppSettings.defaults().toJson(),
  );
  defaults['missedDayDefaultPolicy'] = 'bogus';
  return <String, Object>{
    DevotionsSettingsNotifier.storageKey: jsonEncode(defaults),
  };
}

/// The recording plugin adapter (Task 18's seam): counts the service's calls
/// and stubs the device answers. `pendingNotifications()` is called exactly
/// once per refresh pass, so this count IS the re-plan count.
class _RecordingAdapter implements NotificationPluginAdapter {
  /// How many times the plugin was initialized (one per refresh pass at
  /// most — the service memorizes its first success).
  int initializeCalls = 0;

  /// How many refresh passes ran.
  int refreshes = 0;

  /// How many notifications were scheduled or cancelled (expected 0 in
  /// these tests: nothing is enrolled, so the plan is empty).
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
class _SettingsHarness {
  const _SettingsHarness(this.container, this.repository, this.adapter);

  final ProviderContainer container;
  final SqliteProgramRepository repository;
  final _RecordingAdapter adapter;

  /// The raw SharedPreferences store the real settings provider persists to.
  Future<Map<String, dynamic>> storedSettings() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? raw = prefs.getString(DevotionsSettingsNotifier.storageKey);
    if (raw == null) {
      return const <String, dynamic>{};
    }
    return jsonDecode(raw) as Map<String, dynamic>;
  }
}

/// Pumps the REAL settings screen over the production provider chain,
/// settled before the widget phase.
///
/// [stored] is the initial SharedPreferences store (default: empty — a fresh
/// install). With [routed] the screen is pumped through the app router's
/// `'/' + '/settings'` branch instead of a bare `MaterialApp(home:)`, so the
/// route-repoint test exercises the shell's settings branch builder.
Future<_SettingsHarness> _pumpSettings(
  WidgetTester tester, {
  Map<String, Object> stored = const <String, Object>{},
  bool routed = false,
  Size viewport = const Size(600, 2400),
}) async {
  SharedPreferences.setMockInitialValues(stored);
  final DevotionalsDatabase database = DevotionalsDatabase(open: _openInMemory);
  final SqliteProgramRepository repository = SqliteProgramRepository(
    database: database,
  );
  final _RecordingAdapter adapter = _RecordingAdapter();

  // The provider that owns the notification service is overridden with a
  // service wired to the recording adapter; its settings getter reads the
  // container lazily (assigned below, invoked only during a refresh pass).
  late final ProviderContainer container;
  final NotificationService service = NotificationService(
    database: repository.database,
    repository: repository,
    settings: () => container.read(devotionsSettingsProvider),
    adapter: adapter,
    clock: () => _frozenToday,
    upcomingFeasts: (DateTime _) => const <LiturgicalDayData>[],
  );
  container = ProviderContainer(
    overrides: <Override>[
      appProgramRepositoryProvider.overrideWithValue(repository),
      programRepositoryOverride,
      notificationServiceProvider.overrideWithValue(service),
    ],
  );
  addTearDown(container.dispose);

  // Settle the settings load (mock store resolves within the window) and
  // seed the catalog so the harness's first widget frame renders real data.
  await tester.runAsync(() async {
    container.read(devotionsSettingsProvider.notifier);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await container.read(contentLoadedProvider.future);
  });

  tester.view.physicalSize = viewport;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: routed
          ? MaterialApp.router(
              routerConfig: buildAppRouter(initialLocation: '/settings'),
            )
          : const MaterialApp(home: DevotionalsSettingsScreen()),
    ),
  );
  await tester.pump(const Duration(milliseconds: 50));
  return _SettingsHarness(container, repository, adapter);
}

/// Flushes a tap's await chain (the Task 15/16 recipe, budget widened by
/// Task 21; re-run against 33 packs since the Task-22 novena and Task-23
/// chaplet/litany packs joined the catalog): the fake-async zone's queued
/// microtasks clear one layer per real-time window, and the planner-refresh
/// chain's SQLite round trips scale with the shipped pack count, so the
/// rounds must cover the widest chain a settings change triggers.
Future<void> _drain(WidgetTester tester) async {
  for (int round = 0; round < 40; round++) {
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
  setUpAll(tzdata.initializeTimeZones);

  group('the app section', () {
    testWidgets('renders the pinned controls with their stored values', (
      WidgetTester tester,
    ) async {
      final _SettingsHarness harness = await _pumpSettings(tester);
      final DevotionsAppSettings settings = harness.container.read(
        devotionsSettingsProvider,
      );

      // The pinned section exists with its toggle values at the defaults:
      // anchors on, night items off (explicitly), latin + luminous on.
      expect(
        find.byKey(const Key('devotions_settings_section')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('toggle_angelus_anchors')), findsOneWidget);
      expect(find.byKey(const Key('toggle_mercy_anchor')), findsOneWidget);
      expect(find.byKey(const Key('toggle_night_items')), findsOneWidget);
      expect(find.byKey(const Key('night_items_warning')), findsOneWidget);
      expect(find.textContaining('off by default'), findsAtLeastNWidgets(1));
      expect(find.byKey(const Key('toggle_latin_display')), findsOneWidget);
      expect(find.byKey(const Key('toggle_luminous_set')), findsOneWidget);
      expect(find.byKey(const Key('policy_strict')), findsOneWidget);
      expect(find.byKey(const Key('policy_permissive')), findsOneWidget);
      expect(settings.enableAngelusAnchors, isTrue);
      expect(settings.enableMercyHourAnchor, isTrue);
      expect(settings.nightItemsEnabled, isFalse);
      expect(settings.latinDisplayEnabled, isTrue);
      expect(settings.luminousSetEnabled, isTrue);
      expect(settings.missedDayDefaultPolicy, 'permissive');

      // The four anchor time rows render with their formatted defaults.
      expect(
        find.byKey(const Key('anchor_time_angelus_morning')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('anchor_time_angelus_noon')), findsOneWidget);
      expect(
        find.byKey(const Key('anchor_time_angelus_evening')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('anchor_time_mercy')), findsOneWidget);
    });

    testWidgets(
      'a schedule-relevant toggle updates settings and triggers exactly one '
      'planner refresh per change event',
      (WidgetTester tester) async {
        final _SettingsHarness harness = await _pumpSettings(tester);

        expect(harness.adapter.refreshes, 0);

        await _tapAndDrain(
          tester,
          find.byKey(const Key('toggle_angelus_anchors')),
        );
        expect(
          harness.container
              .read(devotionsSettingsProvider)
              .enableAngelusAnchors,
          isFalse,
        );
        expect(harness.adapter.refreshes, 1);

        await _tapAndDrain(
          tester,
          find.byKey(const Key('toggle_mercy_anchor')),
        );
        expect(
          harness.container
              .read(devotionsSettingsProvider)
              .enableMercyHourAnchor,
          isFalse,
        );
        expect(harness.adapter.refreshes, 2);

        // The night-items toggle is schedule-relevant too (the planner
        // gates the meal & night anchors on it).
        await _tapAndDrain(tester, find.byKey(const Key('toggle_night_items')));
        expect(
          harness.container.read(devotionsSettingsProvider).nightItemsEnabled,
          isTrue,
        );
        expect(harness.adapter.refreshes, 3);
      },
    );

    testWidgets(
      'the morning and evening reminder toggles update settings and trigger '
      'one refresh per change, off and on',
      (WidgetTester tester) async {
        final _SettingsHarness harness = await _pumpSettings(tester);

        // The defaults are OFF (Task 3's pinned defaults; onboarding is
        // where the consents are first taken — the settings screen is the
        // post-onboarding surface).
        expect(
          harness.container
              .read(devotionsSettingsProvider)
              .morningReminderEnabled,
          isFalse,
        );
        expect(
          harness.container
              .read(devotionsSettingsProvider)
              .eveningReminderEnabled,
          isFalse,
        );
        expect(harness.adapter.refreshes, 0);

        // Morning ON: settings update + exactly one refresh (both are plan
        // inputs for the routine anchors, wired like the anchor toggles).
        await _tapAndDrain(
          tester,
          find.byKey(const Key('toggle_morning_reminder')),
        );
        expect(
          harness.container
              .read(devotionsSettingsProvider)
              .morningReminderEnabled,
          isTrue,
        );
        expect(harness.adapter.refreshes, 1);

        // Evening ON: one more refresh.
        await _tapAndDrain(
          tester,
          find.byKey(const Key('toggle_evening_reminder')),
        );
        expect(
          harness.container
              .read(devotionsSettingsProvider)
              .eveningReminderEnabled,
          isTrue,
        );
        expect(harness.adapter.refreshes, 2);

        // The off direction refreshes too.
        await _tapAndDrain(
          tester,
          find.byKey(const Key('toggle_morning_reminder')),
        );
        expect(
          harness.container
              .read(devotionsSettingsProvider)
              .morningReminderEnabled,
          isFalse,
        );
        expect(harness.adapter.refreshes, 3);
      },
    );

    testWidgets(
      'changing an anchor time through the picker updates the settings, the '
      'rendered time, and triggers one refresh; cancelling changes nothing',
      (WidgetTester tester) async {
        final _SettingsHarness harness = await _pumpSettings(tester);

        // Open the morning picker.
        await _tapAndDrain(
          tester,
          find.byKey(const Key('anchor_time_angelus_morning')),
        );
        expect(find.byType(TimePickerDialog), findsOneWidget);

        // Cancel first: no change, no refresh.
        await tester.tap(find.text('Cancel'));
        await tester.pump(const Duration(milliseconds: 50));
        expect(
          harness.container.read(devotionsSettingsProvider).angelusMorning,
          const TimeOfDay(hour: 6, minute: 0),
        );
        expect(harness.adapter.refreshes, 0);

        // Reopen the picker. The dial's labels are painted (not Text
        // widgets), so switch the dialog to its input mode and type the
        // time — the same showTimePicker seam the dial confirm goes through.
        await _tapAndDrain(
          tester,
          find.byKey(const Key('anchor_time_angelus_morning')),
        );
        expect(find.byType(TimePickerDialog), findsOneWidget);
        expect(find.byIcon(Icons.keyboard_outlined), findsOneWidget);
        await tester.tap(find.byIcon(Icons.keyboard_outlined));
        await tester.pump(const Duration(milliseconds: 50));

        // Type 07 into the hour field, commit with `next`; type 30 into the
        // minute field, commit with `done`.
        await tester.enterText(find.byType(TextField).first, '07');
        await tester.testTextInput.receiveAction(TextInputAction.next);
        await tester.pump(const Duration(milliseconds: 50));
        await tester.enterText(find.byType(TextField).last, '30');
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pump(const Duration(milliseconds: 50));

        // Confirm the dialog.
        await tester.tap(find.text('OK'));
        await _drain(tester);

        final DevotionsAppSettings settings = harness.container.read(
          devotionsSettingsProvider,
        );
        expect(settings.angelusMorning, const TimeOfDay(hour: 7, minute: 30));
        expect(harness.adapter.refreshes, 1);
        // The row's rendered label follows the settings.
        expect(find.textContaining('7:30'), findsAtLeastNWidgets(1));
      },
    );

    testWidgets(
      'a duplicate Angelus anchor time is refused — settings unchanged, no '
      'refresh, explicit reason (the planner id collision guard)',
      (WidgetTester tester) async {
        final _SettingsHarness harness = await _pumpSettings(tester);

        // The noon row starts at 12:00 PM; entering 06:00 keeps the PM
        // period, i.e. 18:00 — the evening row's time. Both would plan the
        // same `angelus:anchor:<date>T18:00` id, so the duplicate must be
        // refused before it persists.
        await _tapAndDrain(
          tester,
          find.byKey(const Key('anchor_time_angelus_noon')),
        );
        expect(find.byType(TimePickerDialog), findsOneWidget);
        await tester.tap(find.byIcon(Icons.keyboard_outlined));
        await tester.pump(const Duration(milliseconds: 50));
        await tester.enterText(find.byType(TextField).first, '06');
        await tester.testTextInput.receiveAction(TextInputAction.next);
        await tester.pump(const Duration(milliseconds: 50));
        await tester.enterText(find.byType(TextField).last, '00');
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pump(const Duration(milliseconds: 50));
        await tester.tap(find.text('OK'));
        await _drain(tester);

        expect(
          harness.container.read(devotionsSettingsProvider).angelusNoon,
          const TimeOfDay(hour: 12, minute: 0),
          reason: 'a colliding Angelus time is never persisted',
        );
        expect(
          harness.adapter.refreshes,
          0,
          reason: 'a refused pick is not a change event',
        );
        expect(
          find.byKey(const Key('anchor_time_duplicate')),
          findsOneWidget,
          reason: 'the user sees why the pick was refused',
        );
      },
    );

    testWidgets(
      'the missed-day policy persists and a non-schedule change never '
      'triggers a refresh',
      (WidgetTester tester) async {
        final _SettingsHarness harness = await _pumpSettings(tester);

        await _tapAndDrain(tester, find.byKey(const Key('policy_strict')));
        expect(
          harness.container
              .read(devotionsSettingsProvider)
              .missedDayDefaultPolicy,
          'strict',
        );
        // The write lands in the real store under the production key.
        final DevotionsAppSettings stored = DevotionsAppSettings.fromJson(
          await harness.storedSettings(),
        );
        expect(stored.missedDayDefaultPolicy, 'strict');

        // Latin + Luminous are display/content toggles: settings change,
        // the planner is NOT re-asked.
        await _tapAndDrain(
          tester,
          find.byKey(const Key('toggle_latin_display')),
        );
        await _tapAndDrain(
          tester,
          find.byKey(const Key('toggle_luminous_set')),
        );
        expect(
          harness.container.read(devotionsSettingsProvider).latinDisplayEnabled,
          isFalse,
        );
        expect(
          harness.container.read(devotionsSettingsProvider).luminousSetEnabled,
          isFalse,
        );
        expect(harness.adapter.refreshes, 0);
      },
    );

    testWidgets(
      'an unknown stored policy value is refused: neither row presents it '
      'as chosen and the note points to the known fix',
      (WidgetTester tester) async {
        final _SettingsHarness harness = await _pumpSettings(
          tester,
          stored: _storeWithUnknownPolicy(),
        );

        expect(
          harness.container
              .read(devotionsSettingsProvider)
              .missedDayDefaultPolicy,
          'bogus',
        );
        expect(find.byKey(const Key('policy_unknown_note')), findsOneWidget);

        // Pick a known value: the fix path persists over the unknown one.
        await _tapAndDrain(tester, find.byKey(const Key('policy_permissive')));
        expect(
          harness.container
              .read(devotionsSettingsProvider)
              .missedDayDefaultPolicy,
          'permissive',
        );
        expect(find.byKey(const Key('policy_unknown_note')), findsNothing);
      },
    );
  });

  group('the shared composition', () {
    testWidgets('base-settings controls delegate to the shared providers', (
      WidgetTester tester,
    ) async {
      final _SettingsHarness harness = await _pumpSettings(tester);

      expect(
        harness.container.read(baseSettingsProvider).notificationsEnabled,
        isFalse,
      );

      // The shared notifications gate (NotificationsSettings' main
      // switch) delegates to baseSettingsProvider — and it IS a
      // schedule-relevant change (fix round 1: the master gate is a plan
      // input), so the screen fires exactly one refresh for it.
      await _tapAndDrain(
        tester,
        find.widgetWithText(SwitchListTile, 'Notifications'),
      );
      expect(
        harness.container.read(baseSettingsProvider).notificationsEnabled,
        isTrue,
      );
      expect(harness.adapter.refreshes, 1);

      // The shared language selector delegates to baseSettingsProvider —
      // and the app settings snapshot syncs it one-way.
      await tapDropdownEntry(
        tester,
        fromText: 'English',
        pickText: 'Latin',
        scrollDelta: 300,
      );
      expect(
        harness.container.read(baseSettingsProvider).defaultLanguage.code,
        'la',
      );
      expect(
        harness.container
            .read(devotionsSettingsProvider)
            .baseSettings
            .defaultLanguage
            .code,
        'la',
      );

      // The shared theme-mode selector delegates to the shared
      // themeModeProvider (the dark-mode seam the app's MaterialApp
      // wires). The Appearance section sits above the scrolled-down
      // position: scroll back UP to it. `find.text('System')` alone
      // matches twice (the ListTile subtitle AND the dropdown's value
      // label are both the mode name), so the trailing dropdown is
      // targeted by type.
      final Finder themeModeDropdown = find.byWidgetPredicate(
        (Widget widget) => widget is DropdownButton<ThemeMode>,
      );
      await tester.scrollUntilVisible(
        themeModeDropdown,
        -2500,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump(const Duration(milliseconds: 10));
      await tester.tap(themeModeDropdown);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('Light').last);
      await _drain(tester);
      expect(harness.container.read(themeModeProvider), ThemeMode.light);
    });

    testWidgets(
      'the settings branch mounts the real screen (the Task-14 stub is gone)',
      (WidgetTester tester) async {
        await _pumpSettings(tester, routed: true);

        expect(find.byType(DevotionalsSettingsScreen), findsOneWidget);
        // The stub's honest placeholder copy no longer renders.
        expect(
          find.text('Settings arrive with the next update.'),
          findsNothing,
        );
        // The unified screen's own app bar over the shell's navigation bar.
        expect(find.byType(NavigationBar), findsOneWidget);
      },
    );
  });
}

/// Opens the dropdown whose current value renders as [fromText] and picks
/// the menu entry labelled [pickText].
///
/// [scrollDelta] reaches the control in the lazy ListView: a positive value
/// scrolls DOWN toward it, a negative one scrolls back UP (the picker's
/// standard swipe convention).
Future<void> tapDropdownEntry(
  WidgetTester tester, {
  required String fromText,
  required String pickText,
  required double scrollDelta,
}) async {
  final Finder scrollable = find.byType(Scrollable).first;
  await tester.scrollUntilVisible(
    find.text(fromText),
    scrollDelta,
    scrollable: scrollable,
  );
  await tester.pump(const Duration(milliseconds: 10));
  await tester.tap(find.text(fromText).last);
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 100));
  await tester.tap(find.text(pickText).last);
  await _drain(tester);
}
