// The Plan 2 end-to-end integration pin (Task 25).
//
// ONE frozen ordinary first-Saturday (2026-12-05) runs the whole shipped
// chain, with nothing stubbed but the platform notification plugin and the
// clock:
//
//   seeded real catalog (content pipeline) → EnrollmentService enrolls the
//   Five First Saturdays and the 54-day Rosary Novena → the Today assembler
//   runs ONCE → Task 18's notification service runs ONE app-open refresh
//   (real planner → diff → `notification_index` rows) → the REAL app widget
//   renders the day.
//
// Pinned:
//
// 1. Today assembly — the three Angelus anchor tiles (6/12/18), the 3pm
//    Hour of Mercy, both enrolled commitments (the First Saturday with its
//    `ordinal 1`, the novena on day 26) and the coming feasts;
// 2. `notification_index` — rows exists for the anchors and both due
//    sessions, with the zoned `fire_at` at the user's local wall clock
//    (`-0500`, Eastern Standard). Every plan row the 60-slot budget holds
//    is `scheduled` and every anchor's stored local clock matches its id;
// 3. the full widget tree — `SanctaViaDevotionalsApp` (the production root:
//    MaterialApp.router + onboarding gate + nav shell) pumps over the same
//    container and draws the Today sections.
//
// Depth choice (recorded for the task report): the app widget is pumped, not
// merely the screen, because the harness already runs the real provider
// chain and the production root's only extra work is the tap listener plus
// the app-open refresh, whose future this test has ALREADY resolved once
// through the real `notificationRefreshProvider` (the provider caches it, so
// the widget's read is free). The clock and the platform plugin are the two
// seams; everything else is production code.
//
// DST: 2026-12-05 + the 60-day horizon ends in early February, entirely
// inside EST — the spring-forward edge (a 07:00 wall clock surviving the
// 2027-03-14 transition) is pinned by `test/services/notification_planner_
// test.dart`, not duplicated here. What this test pins is the integration
// seam that produces the rows: the zoned instant, its local clock and offset.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sancta_via_devotional_engine/sancta_via_devotional_engine.dart';
import 'package:sancta_via_devotionals/config/routes.dart' show buildAppRouter;
import 'package:sancta_via_devotionals/database/devotionals_database.dart'
    show DevotionalsDatabase, NotificationRow;
import 'package:sancta_via_devotionals/main.dart' show SanctaViaDevotionalsApp;
import 'package:sancta_via_devotionals/models/app_settings.dart'
    show DevotionsAppSettings;
import 'package:sancta_via_devotionals/providers/app_settings_provider.dart'
    show DevotionsSettingsNotifier, devotionsSettingsProvider;
import 'package:sancta_via_devotionals/providers/content_providers.dart';
import 'package:sancta_via_devotionals/providers/today_providers.dart'
    show
        notificationRefreshProvider,
        notificationServiceProvider,
        TodayAssembly,
        TodayItem,
        todayAssemblyProvider;
import 'package:sancta_via_devotionals/repositories/program_repository.dart'
    show SqliteProgramRepository;
import 'package:sancta_via_devotionals/services/enrollment_service.dart';
import 'package:sancta_via_devotionals/services/notification_service.dart'
    show
        NotificationPluginAdapter,
        NotificationPluginInit,
        NotificationService,
        PendingNotification;
import 'package:sancta_via_liturgical_calendar_riverpod/sancta_via_liturgical_calendar_riverpod.dart'
    show currentDateProvider;
import 'package:sancta_via_shared_ui/sancta_via_shared_ui.dart'
    show BaseSettingsModel;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:timezone/data/latest.dart' as tzdata;

/// A fresh in-memory FFI store open factory.
Future<Database> _openInMemory() =>
    openDatabase(inMemoryDatabasePath, singleInstance: false);

/// The app's frozen calendar day (the date providers' seam).
final DateTime _frozenDay = DateTime(2026, 12, 5);

/// The frozen instant the planner reads: 04:00 Eastern on the frozen day
/// (EST = UTC-5), before all three Angelus anchors, so the plan's first day
/// carries 06:00, 12:00 and 18:00 rows.
final DateTime _frozenNow = DateTime.utc(2026, 12, 5, 9);

/// The zone the fake device reports — the planner receives it as data.
const String _zoneName = 'America/New_York';

/// Persisted settings: onboarding complete (the app opens on Today) and the
/// SHARED notification master gate OPEN (reminders are a plan input; the
/// shared store, not the app snapshot, is authoritative for the gate).
void _setMockSettings() {
  final BaseSettingsModel base = BaseSettingsModel.defaults().copyWith(
    notificationsEnabled: true,
  );
  final DevotionsAppSettings settings = DevotionsAppSettings(
    baseSettings: base,
    onboardingComplete: true,
  );
  SharedPreferences.setMockInitialValues(<String, Object>{
    DevotionsSettingsNotifier.storageKey: jsonEncode(settings.toJson()),
    'sancta_via_base_settings': jsonEncode(base.toJson()),
  });
}

/// The recording plugin adapter: the pending set behaves like a device's
/// (schedule adds, cancel removes), so the service's diff sees real state.
class _FakeNotificationPluginAdapter implements NotificationPluginAdapter {
  final List<DateTime> scheduledAt = <DateTime>[];
  final List<int> cancelled = <int>[];
  final Map<int, PendingNotification> pending = <int, PendingNotification>{};
  int initializeCalls = 0;

  @override
  Future<NotificationPluginInit> initialize({
    required Future<void> Function(String payload) onTap,
  }) async {
    initializeCalls++;
    return const NotificationPluginInit(timeZoneName: _zoneName);
  }

  @override
  Future<List<PendingNotification>> pendingNotifications() async =>
      pending.values.toList();

  @override
  Future<void> schedule({
    required int platformId,
    required String title,
    required String body,
    required String payload,
    required DateTime fireAt,
  }) async {
    scheduledAt.add(fireAt);
    pending[platformId] = PendingNotification(
      platformId: platformId,
      payload: payload,
    );
  }

  @override
  Future<void> cancel(int platformId) async {
    cancelled.add(platformId);
    pending.remove(platformId);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(tzdata.initializeTimeZones);

  testWidgets(
    'frozen 2026-12-05: seeded packs, EnrollmentService commitments, one '
    'planner refresh, Today sections + notification rows, and the app tree',
    (WidgetTester tester) async {
      _setMockSettings();
      final DevotionalsDatabase database = DevotionalsDatabase(
        open: _openInMemory,
      );
      final SqliteProgramRepository repository = SqliteProgramRepository(
        database: database,
      );
      final _FakeNotificationPluginAdapter adapter =
          _FakeNotificationPluginAdapter();

      late final ProviderContainer container;
      container = ProviderContainer(
        overrides: <Override>[
          // main.dart's root wiring: the wrapper's catalog flows through the
          // same SQLite repository the content pipeline seeds.
          appProgramRepositoryProvider.overrideWithValue(repository),
          programRepositoryOverride,
          currentDateProvider.overrideWith(
            (Ref ref) => Stream<DateTime>.value(_frozenDay),
          ),
          // Task 18's service with only the platform plugin faked.
          notificationServiceProvider.overrideWithValue(
            NotificationService(
              database: database,
              repository: repository,
              settings: () => container.read(devotionsSettingsProvider),
              adapter: adapter,
              clock: () => _frozenNow,
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(() async {
        await container.read(notificationServiceProvider).dispose();
        await database.close();
      });

      late TodayAssembly assembly;
      late List<NotificationRow> rows;

      // The async chain runs outside the fake-async widget zone (the ruled
      // screen-harness discipline): settings load, content seed, enrollment,
      // ONE Today read, ONE planner refresh.
      await tester.runAsync(() async {
        container.read(devotionsSettingsProvider.notifier);
        await Future<void>.delayed(const Duration(milliseconds: 20));

        // 1. The real content pipeline seeds the shipped 33-pack catalog.
        await container.read(contentLoadedProvider.future);

        // 2. Enroll through the production derive-and-enroll service.
        final List<ContentPack> packs = await repository.loadPacks();
        ContentPack pack(String id) =>
            packs.firstWhere((ContentPack p) => p.id == id);
        final EnrollmentService enrollments = EnrollmentService(
          repository: repository,
        );
        await enrollments.enroll(
          pack: pack('five_first_saturdays'),
          params: <String, dynamic>{},
        );
        await enrollments.enroll(
          pack: pack('novena_54_day'),
          params: <String, dynamic>{
            'startDate': '2026-11-10',
            'restartPolicy': 'permissive',
          },
        );
        // The anchor packs enroll as-is (their reminders are the day's
        // Morning / Angelus Times / 3pm / Evening sections).
        await repository.enroll('angelus', <String, dynamic>{});
        await repository.enroll('mercy_hour', <String, dynamic>{});

        // 3. ONE Today assembly read, then ONE app-open notification pass
        //    (initialise + plan + diff + write).
        assembly = await container.read(todayAssemblyProvider.future);
        await container.read(notificationRefreshProvider.future);
        rows = await database.getAllNotifications();
      });

      // ── Today assembly ──────────────────────────────────────────────────
      expect(assembly.date, _frozenDay);
      expect(
        assembly.morning.single.pack!.id,
        'angelus',
        reason: 'the 06:00 Angelus opens the Morning section',
      );
      expect(assembly.morning.single.anchor, DateTime(2026, 12, 5, 6));
      expect(
        <String?>[for (final item in assembly.anchors) item.pack!.id],
        <String>['angelus', 'mercy_hour'],
        reason: 'noon Angelus then the 3pm Hour of Mercy (pack id order)',
      );
      expect(assembly.anchors.first.anchor, DateTime(2026, 12, 5, 12));
      expect(assembly.anchors.last.anchor, DateTime(2026, 12, 5, 15));
      expect(assembly.evening.single.pack!.id, 'angelus');
      expect(assembly.evening.single.anchor, DateTime(2026, 12, 5, 18));

      final Set<String> commitmentIds = <String>{
        for (final item in assembly.commitments) item.pack!.id,
      };
      expect(
        commitmentIds,
        containsAll(<String>['five_first_saturdays', 'novena_54_day']),
        reason:
            'both EnrollmentService enrollments are due this First '
            'Saturday',
      );
      final TodayItem firstSaturday = assembly.commitments.firstWhere(
        (TodayItem item) => item.pack!.id == 'five_first_saturdays',
      );
      expect(firstSaturday.ordinalLabel, 'ordinal 1');
      final TodayItem novena = assembly.commitments.firstWhere(
        (TodayItem item) => item.pack!.id == 'novena_54_day',
      );
      expect(
        novena.resolution!.dayIndex,
        26,
        reason: '2026-11-10 (day 1) + 25 days = its 26th petition day',
      );
      expect(
        <String>[for (final item in assembly.feastsComing) item.title],
        contains('Immaculate Conception'),
        reason: 'the 14-day feast window after 2026-12-05 includes 12-08',
      );

      // ── notification_index rows ────────────────────────────────────────
      expect(rows, hasLength(60), reason: 'the plan fills the iOS 60-slot cap');
      expect(
        rows.every((NotificationRow row) => row.status == 'scheduled'),
        isTrue,
      );
      expect(
        adapter.scheduledAt,
        hasLength(60),
        reason: 'every planned row reached the (fake) plugin once',
      );
      expect(adapter.cancelled, isEmpty);
      final Map<String, NotificationRow> byId = <String, NotificationRow>{
        for (final NotificationRow row in rows) row.id: row,
      };

      // The three Angelus anchors and the mercy hour, at their local wall
      // clocks in the fake device's zone (Eastern Standard on 2026-12-05).
      expect(
        byId['angelus:anchor:2026-12-05T06:00']!.fireAt,
        '2026-12-05T06:00:00.000-0500',
      );
      expect(
        byId['angelus:anchor:2026-12-05T12:00']!.fireAt,
        '2026-12-05T12:00:00.000-0500',
      );
      expect(
        byId['angelus:anchor:2026-12-05T18:00']!.fireAt,
        '2026-12-05T18:00:00.000-0500',
      );
      expect(
        byId['mercy_hour:anchor:2026-12-05T15:00']!.fireAt,
        '2026-12-05T15:00:00.000-0500',
      );
      // One 07:00 session reminder per due commitment, with the pack's own
      // deep link.
      expect(
        byId['five_first_saturdays:session:2026-12-05']!.fireAt,
        '2026-12-05T07:00:00.000-0500',
      );
      expect(
        byId['novena_54_day:session:2026-12-05']!.fireAt,
        '2026-12-05T07:00:00.000-0500',
      );
      expect(
        byId['five_first_saturdays:session:2026-12-05']!.deepLink,
        '/session/five_first_saturdays?forDate=2026-12-05',
      );

      // DST-safe seam: every anchor row's stored local clock is the wall
      // clock in its id, and the whole horizon sits at the EST offset (the
      // spring-forward edge is the planner's own pinned test).
      final RegExp anchorClock = RegExp(r'T(\d{2}):(\d{2})$');
      for (final NotificationRow row in rows) {
        expect(row.fireAt.endsWith('-0500'), isTrue);
        if (row.id.contains(':anchor:')) {
          final String localClock = row.fireAt.substring(11, 16);
          expect(
            localClock,
            anchorClock.firstMatch(row.id)!.group(0)!.substring(1),
          );
        }
      }

      // ── the full app tree renders the same day ─────────────────────────
      final router = buildAppRouter(initialLocation: '/');
      tester.view.physicalSize = const Size(600, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: SanctaViaDevotionalsApp(router: router),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('Morning'), findsOneWidget);
      expect(find.text('Angelus Times'), findsOneWidget);
      expect(find.text('3pm'), findsOneWidget);
      expect(find.text('Evening'), findsOneWidget);
      expect(find.text('Commitments'), findsOneWidget);
      expect(find.text('Upcoming Feasts'), findsOneWidget);
      expect(
        find.text('The Angelus (Regina Caeli in Eastertide)'),
        findsNWidgets(3),
      );
      expect(find.text('The Hour of Mercy'), findsOneWidget);
      expect(find.text('Five First Saturdays of Our Lady'), findsOneWidget);
      expect(find.text('ordinal 1'), findsOneWidget);
      expect(find.text('The 54-Day Rosary Novena'), findsOneWidget);
      expect(find.text('Immaculate Conception'), findsOneWidget);
    },
  );
}
