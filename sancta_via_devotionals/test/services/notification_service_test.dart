// Notification wiring tests (Plan 2, Task 18).
//
// The real service, the real planner, and a real in-memory SQLite store are
// exercised against a recording [NotificationPluginAdapter]: the plugin
// surface (flutter_local_notifications + flutter_timezone) is the only thing
// faked, so these pins cover the wiring the app actually runs.
//
// Pinned here:
//
// 1. a refresh schedules the planner's items and writes the matching
//    `notification_index` rows (status `scheduled`) — with the shipped
//    Angelus asset's ONE 06:00 anchor (Task 24 adds the other two), the
//    zoned `fire_at` ISO carrying the local offset and the pack's deep link;
// 2. a SECOND refresh with unchanged inputs performs ZERO plugin writes and
//    zero row rewrites (the idempotent diff), and initialize stays a one-shot;
// 3. a tap yields its `deep_link` on the stream, marks the row `fired`, and
//    a cold-start launch payload is drained the same way;
// 4. turning an anchor's setting off cancels that anchor's rows and device
//    notifications on the next refresh (settings are read at call time);
// 5. a completed commitment produces no reminders (progress-aware filter —
//    the planner alone would plan a finished program forever);
// 6. a changed payload replaces the notification (cancel + schedule the same
//    id) and a stale store id is cancelled (planned-vs-store drift).
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sancta_via_devotional_engine/sancta_via_devotional_engine.dart';
import 'package:sancta_via_devotionals/database/devotionals_database.dart';
import 'package:sancta_via_devotionals/models/app_settings.dart';
import 'package:sancta_via_devotionals/repositories/program_repository.dart';
import 'package:sancta_via_devotionals/services/notification_service.dart';
import 'package:sancta_via_liturgical_calendar/sancta_via_liturgical_calendar.dart'
    show LiturgicalDayData;
import 'package:sancta_via_shared_ui/sancta_via_shared_ui.dart'
    show BaseSettingsModel;
import 'package:sqflite/sqflite.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// The fake's zone — the planner receives it as data, so the frozen clock
/// below is machine-independent.
const String _zoneName = 'America/New_York';

/// 2026-12-01 03:00 in New York (08:00Z): the plan's first day is 12-01 and
/// the 06:00 Angelus anchor on that day is still ahead.
final DateTime _frozenNow = DateTime.utc(2026, 12, 1, 8);

/// One recorded schedule call.
class _Scheduled {
  const _Scheduled({
    required this.platformId,
    required this.title,
    required this.body,
    required this.payload,
    required this.fireAt,
  });

  final int platformId;
  final String title;
  final String body;
  final String payload;
  final DateTime fireAt;
}

/// The recording plugin adapter: the pending set behaves like the device's
/// (a schedule adds, a cancel removes), so a second refresh sees the first
/// refresh's writes exactly as a real device would.
class _FakeNotificationPluginAdapter implements NotificationPluginAdapter {
  _FakeNotificationPluginAdapter({this.launchPayload});

  /// The zone the fake's "device" reports (see [_zoneName]).
  final String timeZoneName = _zoneName;

  final String? launchPayload;

  Future<void> Function(String payload)? onTap;

  final List<_Scheduled> scheduled = <_Scheduled>[];

  final List<int> cancelled = <int>[];

  final Map<int, PendingNotification> pending = <int, PendingNotification>{};

  int initializeCalls = 0;

  @override
  Future<NotificationPluginInit> initialize({
    required Future<void> Function(String payload) onTap,
  }) async {
    initializeCalls++;
    this.onTap = onTap;
    return NotificationPluginInit(
      timeZoneName: timeZoneName,
      launchPayload: launchPayload,
    );
  }

  @override
  Future<List<PendingNotification>> pendingNotifications() async {
    return pending.values.toList();
  }

  @override
  Future<void> schedule({
    required int platformId,
    required String title,
    required String body,
    required String payload,
    required DateTime fireAt,
  }) async {
    scheduled.add(
      _Scheduled(
        platformId: platformId,
        title: title,
        body: body,
        payload: payload,
        fireAt: fireAt,
      ),
    );
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

  Future<void> tap(String payload) async {
    await onTap!(payload);
  }
}

/// Loads one shipped pack asset through the engine's own loader (the real
/// catalog shape, not a hand-built stand-in).
ContentPack _assetPack(String name) {
  final String json = File(
    'assets/content/packs/$name.json',
  ).readAsStringSync();
  return PackLoader.loadFromJsonString(json);
}

/// The plan row ids of [rows], in store order.
List<String> _ids(List<NotificationRow> rows) {
  return <String>[for (final NotificationRow row in rows) row.id];
}

void main() {
  setUpAll(tzdata.initializeTimeZones);

  late DevotionalsDatabase database;
  late SqliteProgramRepository repository;
  late _FakeNotificationPluginAdapter adapter;
  late NotificationService service;
  late DevotionsAppSettings settings;

  setUp(() {
    database = DevotionalsDatabase(
      open: () => openDatabase(inMemoryDatabasePath, singleInstance: false),
    );
    repository = SqliteProgramRepository(database: database);
    adapter = _FakeNotificationPluginAdapter();
    // These tests pin PLAN CONTENT (which anchors are planned, at which
    // times); the shared master gate is a plan input too, so the fixture
    // opens it explicitly. The gate's own behavior is pinned by the
    // gate-on/off test below.
    settings = DevotionsAppSettings(
      baseSettings: BaseSettingsModel.defaults().copyWith(
        notificationsEnabled: true,
      ),
    );
    service = NotificationService(
      database: database,
      repository: repository,
      settings: () => settings,
      adapter: adapter,
      clock: () => _frozenNow,
      // The calendar seam is injected as data: the wiring under test is the
      // plan/diff/write pass, not the calendar package's own contents.
      upcomingFeasts: (DateTime _) => const <LiturgicalDayData>[],
    );
  });

  tearDown(() async {
    await service.dispose();
    await database.close();
  });

  group('refresh', () {
    test('schedules the plan and writes its notification_index rows', () async {
      await repository.seedPacks(<ContentPack>[
        _assetPack('angelus'),
      ], packVersion: 'test-1');
      await repository.enroll('angelus', <String, dynamic>{});

      await service.refresh();

      final List<NotificationRow> rows = await database.getAllNotifications();
      // The 60-day horizon from 2026-12-01, one 06:00 anchor per day (the
      // shipped Angelus pack carries a single anchor until Task 24).
      expect(rows, hasLength(60));
      expect(
        rows.every((NotificationRow row) => row.status == 'scheduled'),
        isTrue,
      );
      expect(rows.first.id, 'angelus:anchor:2026-12-01T06:00');
      expect(rows.last.id, 'angelus:anchor:2027-01-29T06:00');
      expect(rows.first.fireAt, '2026-12-01T06:00:00.000-0500');
      expect(rows.first.title, 'The Angelus (Regina Caeli in Eastertide)');
      expect(rows.first.packId, 'angelus');
      expect(rows.first.deepLink, '/session/angelus?forDate=2026-12-01');
      expect(
        <String>{
          for (final NotificationRow row in rows)
            RegExp(r'T(\d{2}):\d{2}$').firstMatch(row.id)!.group(1)!,
        },
        <String>{'06'},
        reason: 'the shipped pack carries ONE 06:00 anchor, never three',
      );

      expect(adapter.scheduled, hasLength(60));
      expect(
        adapter.scheduled.first.fireAt,
        isA<tz.TZDateTime>(),
        reason: 'the plugin must receive the planner\'s zoned instant',
      );
      expect(adapter.scheduled.first.fireAt.hour, 6);
      expect(
        adapter.scheduled.first.payload,
        '{"id":"angelus:anchor:2026-12-01T06:00",'
        '"link":"/session/angelus?forDate=2026-12-01"}',
      );
      expect(adapter.cancelled, isEmpty);
    });

    test('a second refresh on unchanged inputs writes nothing', () async {
      await repository.seedPacks(<ContentPack>[
        _assetPack('angelus'),
      ], packVersion: 'test-1');
      await repository.enroll('angelus', <String, dynamic>{});

      await service.refresh();
      final List<String> idsAfterFirst = _ids(
        await database.getAllNotifications(),
      );
      expect(adapter.scheduled, hasLength(60));

      await service.refresh();

      expect(
        adapter.scheduled,
        hasLength(60),
        reason: 'an unchanged plan must perform zero plugin writes',
      );
      expect(adapter.cancelled, isEmpty);
      expect(_ids(await database.getAllNotifications()), idsAfterFirst);
      expect(
        adapter.initializeCalls,
        1,
        reason: 'initialization is a one-shot, not a per-refresh call',
      );
    });

    test('turning the Angelus anchors off cancels those rows', () async {
      await repository.seedPacks(<ContentPack>[
        _assetPack('angelus'),
      ], packVersion: 'test-1');
      await repository.enroll('angelus', <String, dynamic>{});
      await service.refresh();
      expect(adapter.pending, hasLength(60));

      // Settings are read at CALL time: no listener, no extra refresh point.
      settings = settings.copyWith(enableAngelusAnchors: false);
      await service.refresh();

      final List<NotificationRow> rows = await database.getAllNotifications();
      expect(rows, hasLength(60));
      expect(
        rows.every((NotificationRow row) => row.status == 'cancelled'),
        isTrue,
      );
      expect(adapter.pending, isEmpty);
      expect(adapter.cancelled, hasLength(60));
    });

    test(
      'the master notifications gate off plans nothing — everything cancels',
      () async {
        await repository.seedPacks(<ContentPack>[
          _assetPack('angelus'),
        ], packVersion: 'test-1');
        await repository.enroll('angelus', <String, dynamic>{});

        // Gate open (the fixture): 60 anchors scheduled.
        await service.refresh();
        expect(adapter.pending, hasLength(60));

        // The SHARED base-settings master gate closes: the plan is empty and
        // the diff cancels every scheduled row and device notification, the
        // same code path as a settings toggle-off.
        settings = settings.copyWith(
          baseSettings: settings.baseSettings.copyWith(
            notificationsEnabled: false,
          ),
        );
        await service.refresh();

        final List<NotificationRow> rows = await database.getAllNotifications();
        expect(rows, hasLength(60));
        expect(
          rows.every((NotificationRow row) => row.status == 'cancelled'),
          isTrue,
        );
        expect(adapter.pending, isEmpty);
        expect(adapter.cancelled, hasLength(60));

        // And a later refresh with the gate back open re-schedules the same
        // ids (closed ids are not terminal — the ruling's toggle symmetry).
        settings = settings.copyWith(
          baseSettings: settings.baseSettings.copyWith(
            notificationsEnabled: true,
          ),
        );
        await service.refresh();
        final List<NotificationRow> rescheduled = await database
            .getAllNotifications();
        expect(rescheduled, hasLength(60));
        expect(
          rescheduled.every((NotificationRow row) => row.status == 'scheduled'),
          isTrue,
        );
        expect(adapter.pending, hasLength(60));
      },
    );

    test('a completed commitment produces no reminders', () async {
      await repository.seedPacks(<ContentPack>[
        _assetPack('five_first_saturdays'),
      ], packVersion: 'test-1');
      await repository.enroll('five_first_saturdays', <String, dynamic>{});

      // In progress: the First Saturdays inside the horizon are reminders.
      await service.refresh();
      final List<NotificationRow> planned = await database
          .getAllNotifications();
      expect(planned, isNotEmpty);
      expect(
        planned.every(
          (NotificationRow row) =>
              row.id.startsWith('five_first_saturdays:session:'),
        ),
        isTrue,
      );

      // Complete (`count: 5`): the planner's progress-free resolution would
      // keep resolving due forever, so the wiring excludes the pack.
      await repository.saveProgress(
        ProgressState(packId: 'five_first_saturdays', fulfilledOrdinals: 5),
      );
      await service.refresh();

      final List<NotificationRow> rows = await database.getAllNotifications();
      expect(
        rows.where((NotificationRow row) => row.status == 'scheduled'),
        isEmpty,
        reason: 'a finished commitment is never planned again',
      );
      expect(adapter.pending, isEmpty);
    });
  });

  group('taps', () {
    test('a tap yields its deep link, marks fired, and refreshes', () async {
      await repository.seedPacks(<ContentPack>[
        _assetPack('angelus'),
      ], packVersion: 'test-1');
      await repository.enroll('angelus', <String, dynamic>{});
      await service.refresh();

      const String id = 'angelus:anchor:2026-12-02T06:00';
      final String link = '/session/angelus?forDate=2026-12-02';
      final Future<String> tapped = service.taps.first;
      final int scheduledBeforeTap = adapter.scheduled.length;

      await adapter.tap(jsonEncode(<String, String>{'id': id, 'link': link}));

      expect(await tapped, link);
      expect(
        (await database.getNotification(id))!.status,
        'fired',
        reason: 'a tapped occurrence is marked fired, not rescheduled',
      );
      expect(
        adapter.scheduled,
        hasLength(scheduledBeforeTap),
        reason: 'the tap refresh never reschedules a fired occurrence',
      );
      expect(adapter.cancelled, isEmpty);
    });

    test(
      'a cold-start launch payload is drained into the tap stream',
      () async {
        const String link = '/session/angelus?forDate=2026-12-01';
        final _FakeNotificationPluginAdapter launching =
            _FakeNotificationPluginAdapter(
              launchPayload: jsonEncode(<String, String>{
                'id': 'angelus:anchor:2026-12-01T06:00',
                'link': link,
              }),
            );
        final NotificationService launchingService = NotificationService(
          database: database,
          repository: repository,
          settings: () => settings,
          adapter: launching,
          clock: () => _frozenNow,
          upcomingFeasts: (DateTime _) => const <LiturgicalDayData>[],
        );
        addTearDown(launchingService.dispose);

        final Future<String> tapped = launchingService.taps.first;
        await launchingService.initialize();

        expect(await tapped, link);
      },
    );
  });

  group('diff edges', () {
    test('a changed payload replaces the same id', () async {
      await repository.seedPacks(<ContentPack>[
        _assetPack('angelus'),
      ], packVersion: 'test-1');
      await repository.enroll('angelus', <String, dynamic>{});
      await service.refresh();

      const String id = 'angelus:anchor:2026-12-01T06:00';
      final NotificationRow row = (await database.getNotification(id))!;
      // Drift the stored body under the same id: the plan's payload is the
      // stale row's replacement (cancel + schedule the same id), not a
      // duplicate.
      await database.upsertNotification(
        id: row.id,
        packId: row.packId,
        fireAt: row.fireAt,
        title: row.title,
        body: 'stale body',
        deepLink: row.deepLink,
        status: 'scheduled',
      );
      final int scheduledBefore = adapter.scheduled.length;

      await service.refresh();

      expect(adapter.cancelled, <int>[NotificationService.platformIdFor(id)]);
      expect(adapter.scheduled, hasLength(scheduledBefore + 1));
      expect((await database.getNotification(id))!.body, row.body);
      expect((await database.getNotification(id))!.status, 'scheduled');
    });

    test('a stale store id is cancelled (planned-vs-store drift)', () async {
      await repository.seedPacks(<ContentPack>[
        _assetPack('angelus'),
      ], packVersion: 'test-1');
      await repository.enroll('angelus', <String, dynamic>{});
      await service.refresh();

      // A row the plan never produces and the device never held.
      const String ghost = 'ghost:anchor:2026-12-30T06:00';
      await database.upsertNotification(
        id: ghost,
        packId: 'ghost',
        fireAt: '2026-12-30T06:00:00.000-0500',
        title: 'Ghost',
        body: 'Ghost',
        deepLink: '/session/ghost?forDate=2026-12-30',
        status: 'scheduled',
      );
      // A device notification whose id the plan dropped.
      adapter.pending[4242] = const PendingNotification(
        platformId: 4242,
        payload:
            '{"id":"phantom:session:2026-12-03",'
            '"link":"/session/phantom?forDate=2026-12-03"}',
      );

      await service.refresh();

      expect((await database.getNotification(ghost))!.status, 'cancelled');
      expect(adapter.cancelled, contains(4242));
      expect(adapter.pending.containsKey(4242), isFalse);
    });
  });
}
