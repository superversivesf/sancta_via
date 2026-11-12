// Notification wiring (Plan 2, Task 18): the plugin-facing half of the
// notification stack.
//
// Task 17's [NotificationPlanner] is pure — it decides WHICH notifications
// exist and WHEN they fire without touching a plugin. This service adds the
// device side and keeps it honest:
//
// ## The pinned contract
//
// ```dart
// class NotificationService {
//   Future<void> initialize();
//   Future<void> refresh();
//   Stream<String> get taps;
// }
// ```
//
// * [initialize] initializes the plugin (the Android `devotionals` channel,
//   iOS provisional authorization, the timezone database plus the device's
//   IANA zone name), wires the tap callback, and drains the cold-start
//   launch payload (a tap that started the app) into [taps].
// * [refresh] is the only writer. It reads the current enrollment/progress
//   state, the persisted `notification_index` rows and the plugin's pending
//   snapshot, asks the planner for the new plan, diffs it against what the
//   device and the store already have, and writes only the difference:
//   new ids are scheduled, changed payloads are cancelled and replaced,
//   dropped ids are cancelled. The store rows carry the planner's OWN ids
//   (`id`, pack id, `fire_at` ISO, title, body, `deep_link`, status
//   `scheduled`). A second refresh on unchanged inputs performs ZERO plugin
//   writes — the idempotency property the diff exists for.
// * The SHARED base settings' `notificationsEnabled` is the master gate
//   over the whole stack (fix round 1): with the gate closed the plan is
//   empty and every scheduled row/device notification is cancelled by the
//   same diff path a settings toggle-off takes. The gate is read from the
//   app settings' synced `baseSettings` snapshot (Task 3's one-way sync
//   from `baseSettingsProvider`) on every pass.
// * [taps] yields the `deep_link` of a tapped notification (`/session/…`);
//   the app shell routes it through the router. The tap handler also marks
//   the row `fired` and runs a refresh (a spec §9 refresh point).
//
// ## Refresh points (spec §9 — no background polling)
//
// App open (after `ensureContentLoaded`, `main.dart`), every session
// completion (`SessionPlayerController._finalize`), and a notification tap
// (this service). Nothing here polls or subscribes to settings changes.
//
// ## Inputs the wiring must shape for the planner (Task 17's binding notes)
//
// 1. **Completed commitments are filtered OUT before planning.** A
//    [ConsecutiveCommitmentSpec]'s `resolve` is progress-free, so a finished
//    Five First Saturdays still resolves due on every First Saturday forever;
//    this service reads each enrolled pack's persisted progress and excludes a
//    pack whose commitment is complete (`fulfilledOrdinals >= count`), the
//    same exclusion the wrapper's `todayProgramsProvider` applies.
// 2. **The calendar seam is the FEAST-ONLY list** —
//    `LiturgicalCalendarService.getUpcomingFeasts(daysAhead: 60)` (prioritized
//    / solemnity / feast / memorial days), not a per-day feed. Bodies stay
//    unpolluted and anchors still pick up a season variant on the days the
//    list carries. The per-day upgrade path (every horizon day from
//    `getDayForDate`, which the planner's ferial guard already keeps from
//    garnishing weekday bodies — at the cost of a Sunday/commemoration's
//    rank-parse gap) is deliberately deferred until a task owns that feed.
// 3. One Angelus anchor: the shipped pack carries a single 06:00
//    [TimeOfDaySpec] until Task 24's three-anchor pack, and the planner maps
//    each authored spec — nothing here invents the missing hours.
//
// ## Test seam: [NotificationPluginAdapter]
//
// The plugin surface is wrapped in the small [NotificationPluginAdapter]
// interface because `flutter_local_notifications` is process-global
// (`FlutterLocalNotificationsPlugin()` is a factory over one singleton whose
// platform half resolves at construction), and its scheduling API speaks
// `tz.TZDateTime` + `NotificationDetails`. Unit tests substitute the adapter
// (a recording fake) and pin the diff/idempotency/tap behavior on the real
// service, the real planner, and a real in-memory SQLite store. The
// production adapter is [FlutterNotificationPluginAdapter]; `flutter_timezone`
// lives behind the same seam so no test touches a method channel.
//
// ## Payload and platform ids
//
// The plugin's notification ids are `int`s, while the planner's ids are the
// stable strings in the store. [NotificationService.platformIdFor] hashes a
// planner id into a stable 31-bit int (FNV-1a) for the plugin, and each
// notification's payload carries the planner id beside the deep link as a
// small JSON envelope (`{"id": …, "link": …}`) so the pending snapshot maps
// back to the planner's ids exactly. A payload that is not that envelope is
// left alone (never cancelled) — it is not one of ours.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:sancta_via_devotional_engine/sancta_via_devotional_engine.dart';
import 'package:sancta_via_liturgical_calendar/sancta_via_liturgical_calendar.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../database/devotionals_database.dart';
import '../models/app_settings.dart';
import '../repositories/program_repository.dart';
import '../utils/logger.dart';
import 'notification_planner.dart';

/// The planning horizon the calendar seam covers (the planner's own 60 days).
const int notificationHorizonDays = 60;

/// One notification the platform currently holds pending.
///
/// [platformId] is the plugin's int id; [payload] is the raw payload the
/// notification was scheduled with (see the library docs on the envelope).
class PendingNotification {
  /// Creates a pending-notification snapshot entry.
  const PendingNotification({required this.platformId, required this.payload});

  /// The plugin's notification id.
  final int platformId;

  /// The payload the notification carries, or null.
  final String? payload;

  @override
  String toString() =>
      'PendingNotification(platformId: $platformId, payload: $payload)';
}

/// What [NotificationPluginAdapter.initialize] resolved: the device's IANA
/// zone name (handed to the planner as data) and, when a notification tap
/// launched the app, that tap's payload.
class NotificationPluginInit {
  /// Creates an initialization result.
  const NotificationPluginInit({
    required this.timeZoneName,
    this.launchPayload,
  });

  /// The device's IANA time-zone name (`'America/New_York'`).
  final String timeZoneName;

  /// The payload of the notification that launched the app, when one did.
  final String? launchPayload;
}

/// The thin seam over `flutter_local_notifications` + `flutter_timezone`
/// (see the library docs on why it exists).
///
/// Implementations own the platform details; the service owns every
/// decision (what to schedule, cancel, or persist).
abstract interface class NotificationPluginAdapter {
  /// Initializes the platform plugin and the timezone database, registers
  /// [onTap] for notification taps, and returns the device's zone name plus
  /// any cold-start launch payload.
  ///
  /// The callback is `Future`-returning so a test fake can await the service's
  /// tap handling; the production callback simply does not await it (the
  /// plugin's handler is fire-and-forget by design).
  Future<NotificationPluginInit> initialize({
    required Future<void> Function(String payload) onTap,
  });

  /// Every notification the platform currently holds pending.
  Future<List<PendingNotification>> pendingNotifications();

  /// Schedules (or replaces) one notification.
  ///
  /// [fireAt] is the planner's `tz.TZDateTime` (it carries the zone the
  /// notification fires in); the adapter refuses a plain `DateTime`.
  Future<void> schedule({
    required int platformId,
    required String title,
    required String body,
    required String payload,
    required DateTime fireAt,
  });

  /// Cancels one notification by its plugin id. Cancelling an id the
  /// platform does not hold is a no-op.
  Future<void> cancel(int platformId);
}

/// The production [NotificationPluginAdapter] over
/// `flutter_local_notifications` and `flutter_timezone`.
///
/// Android: channel `devotionals`, inexact-while-idle scheduling (no
/// `SCHEDULE_EXACT_ALARM` requirement for a devotional reminder) and the
/// Android 13 notification-permission request. iOS/macOS: provisional
/// authorization (`requestProvisionalPermission`), so reminders are delivered
/// quietly until the user promotes them — never a permission prompt on first
/// launch.
class FlutterNotificationPluginAdapter implements NotificationPluginAdapter {
  /// Creates the adapter over [plugin] (defaults to the plugin singleton).
  FlutterNotificationPluginAdapter({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  /// The Android channel id the reminders share.
  static const String channelId = 'devotionals';

  /// The Android channel's user-visible name.
  static const String channelName = 'Devotionals';

  final FlutterLocalNotificationsPlugin _plugin;

  @override
  Future<NotificationPluginInit> initialize({
    required Future<void> Function(String payload) onTap,
  }) async {
    tzdata.initializeTimeZones();
    final String timeZoneName = await FlutterTimezone.getLocalTimezone();

    await _plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          // Provisional authorization: no prompt on first launch (see the
          // class docs). The app asks for full authorization when the user
          // enables a reminder toggle in onboarding/settings.
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
          requestProvisionalPermission: true,
        ),
        macOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
          requestProvisionalPermission: true,
        ),
      ),
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        final String? payload = response.payload;
        if (payload != null && payload.isNotEmpty) {
          unawaited(onTap(payload));
        }
      },
    );

    final AndroidFlutterLocalNotificationsPlugin? android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android != null) {
      await android.createNotificationChannel(
        const AndroidNotificationChannel(
          channelId,
          channelName,
          description: 'Daily devotional reminders',
          importance: Importance.defaultImportance,
        ),
      );
      await android.requestNotificationsPermission();
    }

    String? launchPayload;
    final NotificationAppLaunchDetails? launch = await _plugin
        .getNotificationAppLaunchDetails();
    if (launch != null && launch.didNotificationLaunchApp) {
      launchPayload = launch.notificationResponse?.payload;
    }
    return NotificationPluginInit(
      timeZoneName: timeZoneName,
      launchPayload: launchPayload,
    );
  }

  @override
  Future<List<PendingNotification>> pendingNotifications() async {
    final List<PendingNotificationRequest> pending = await _plugin
        .pendingNotificationRequests();
    return <PendingNotification>[
      for (final PendingNotificationRequest request in pending)
        PendingNotification(platformId: request.id, payload: request.payload),
    ];
  }

  @override
  Future<void> schedule({
    required int platformId,
    required String title,
    required String body,
    required String payload,
    required DateTime fireAt,
  }) async {
    if (fireAt is! tz.TZDateTime) {
      throw ArgumentError.value(
        fireAt,
        'fireAt',
        'a zoned schedule needs the planner\'s tz.TZDateTime',
      );
    }
    await _plugin.zonedSchedule(
      platformId,
      title,
      body,
      fireAt,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelName,
          channelDescription: 'Daily devotional reminders',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
        iOS: DarwinNotificationDetails(),
        macOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: payload,
    );
  }

  @override
  Future<void> cancel(int platformId) => _plugin.cancel(platformId);
}

/// The decoded payload envelope a notification carries (see the library docs).
class _Payload {
  const _Payload({this.id, this.link});

  /// The planner id the notification was scheduled for, when it is ours.
  final String? id;

  /// The deep link the tap should open, when the payload carries one.
  final String? link;
}

/// The notification wiring service (see the library docs for the full
/// contract).
class NotificationService {
  /// Creates the service over [database] (the `notification_index` store),
  /// [repository] (packs, enrollments, progress) and [settings] (a getter —
  /// the CURRENT settings are read at each [refresh] call).
  ///
  /// [upcomingFeasts] is the calendar seam: it defaults to the feast-only
  /// `LiturgicalCalendarService.getUpcomingFeasts` over the 60-day horizon.
  /// [adapter] defaults to the real plugin adapter; tests inject a fake.
  NotificationService({
    required DevotionalsDatabase database,
    required SqliteProgramRepository repository,
    required DevotionsAppSettings Function() settings,
    NotificationPluginAdapter? adapter,
    NotificationPlanner planner = const NotificationPlanner(),
    DateTime Function()? clock,
    List<LiturgicalDayData> Function(DateTime from)? upcomingFeasts,
  }) : _database = database,
       _repository = repository,
       _settings = settings,
       _adapter = adapter ?? FlutterNotificationPluginAdapter(),
       _planner = planner,
       _clock = clock ?? DateTime.now,
       _upcomingFeasts = upcomingFeasts ?? _defaultUpcomingFeasts;

  /// The store the planner's rows are persisted in and diffed against.
  final DevotionalsDatabase _database;

  /// The content/progress source the planner inputs are read from.
  final SqliteProgramRepository _repository;

  /// The current-settings getter (re-read on every refresh).
  final DevotionsAppSettings Function() _settings;

  final NotificationPluginAdapter _adapter;
  final NotificationPlanner _planner;
  final DateTime Function() _clock;
  final List<LiturgicalDayData> Function(DateTime from) _upcomingFeasts;

  /// The tap stream: one `deep_link` per tapped notification (`/session/…`).
  final StreamController<String> _taps = StreamController<String>.broadcast();

  /// In-flight/settled initialization, or null when it never succeeded.
  Future<void>? _initialize;

  /// Tail of the serialized refresh chain (a refresh point can race another).
  Future<void>? _refreshQueue;

  String? _timeZoneName;

  /// The device's IANA zone name (null until a successful [initialize]).
  String? get timeZoneName => _timeZoneName;

  /// The tap stream (see the library docs). Broadcast: every listener sees
  /// each tap, and no listener means the event is dropped (the router
  /// listener in `main.dart` attaches before initialization).
  Stream<String> get taps => _taps.stream;

  /// The platform id a planner [id] is scheduled under (see the library docs
  /// on ids). Deterministic across runs and platforms: an FNV-1a 32-bit hash
  /// masked into the plugin's positive-int id space.
  static int platformIdFor(String id) {
    int hash = 0x811c9dc5;
    for (final int unit in id.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return hash & 0x7FFFFFFF;
  }

  /// Initializes the plugin, the timezone database, and the device zone name
  /// (see the library docs). Safe to call repeatedly: the first successful
  /// attempt is kept; a failed attempt is retried by the next call, and every
  /// failure is logged rather than thrown (a missing notification plugin must
  /// never take the prayer app down).
  Future<void> initialize() {
    final Future<void>? existing = _initialize;
    if (existing != null) {
      return existing;
    }
    final Future<void> attempt = _initializeOnce();
    _initialize = attempt;
    return attempt;
  }

  Future<void> _initializeOnce() async {
    try {
      final NotificationPluginInit init = await _adapter.initialize(
        onTap: _handleTap,
      );
      _timeZoneName = init.timeZoneName;
      AppLogger.info(
        'Notification service initialized (zone: ${init.timeZoneName})',
        'NOTIF',
      );
      final String? launchPayload = init.launchPayload;
      if (launchPayload != null && launchPayload.isNotEmpty) {
        // NOT awaited: the tap handler runs a refresh, and refresh() awaits
        // initialize() — awaiting it from inside initialization would wait on
        // the very future that is running.
        unawaited(_drainLaunchTap(launchPayload));
      }
    } catch (e, stackTrace) {
      _timeZoneName = null;
      _initialize = null;
      AppLogger.error(
        'Notification initialization failed — reminders stay off until a '
            'later attempt succeeds',
        e,
        stackTrace,
        'NOTIF',
      );
    }
  }

  /// Handles the cold-start launch payload fire-and-forget (see
  /// [_initializeOnce]); a failure is logged and never poisons startup.
  Future<void> _drainLaunchTap(String payload) async {
    try {
      await _handleTap(payload);
    } catch (e, stackTrace) {
      AppLogger.error(
        'Failed to handle the notification launch tap',
        e,
        stackTrace,
        'NOTIF',
      );
    }
  }

  /// Re-plans the notifications and writes only the difference (see the
  /// library docs).
  ///
  /// Refreshes are serialized through one queue, so two refresh points that
  /// land together diff against each other's writes instead of racing. The
  /// returned future completes when this refresh settled; failures are logged
  /// and swallowed (a hook is fire-and-forget by design).
  Future<void> refresh() {
    final Future<void> preceding = _refreshQueue ?? Future<void>.value();
    final Future<void> next = preceding.then((_) => _refreshOnce());
    _refreshQueue = next;
    return next;
  }

  Future<void> _refreshOnce() async {
    // The whole pass is guarded: refresh is a fire-and-forget hook at three
    // call sites, so it must never throw into a caller (and never poison the
    // serialization queue with an errored tail).
    try {
      await initialize();
      final String? zoneName = _timeZoneName;
      if (zoneName == null) {
        AppLogger.debug(
          'Notification refresh skipped: the service never initialized',
          'NOTIF',
        );
        return;
      }
      await _planAndApply(zoneName);
    } catch (e, stackTrace) {
      AppLogger.error(
        'Notification refresh failed — the previous schedule stays in place',
        e,
        stackTrace,
        'NOTIF',
      );
    }
  }

  /// The plan → diff → write pass (the body of [refresh]).
  Future<void> _planAndApply(String zoneName) async {
    final DateTime now = _clock();
    final DevotionsAppSettings settings = _settings();

    // The enrolled set, with completed commitments filtered out (binding
    // note 1: the planner's schedule resolution is progress-free).
    final List<ContentPack> packs = await _repository.loadPacks();
    final Map<String, Map<String, dynamic>> enrollments =
        <String, Map<String, dynamic>>{};
    final List<ContentPack> plannedPacks = <ContentPack>[];
    for (final ContentPack pack in packs) {
      final Map<String, dynamic>? params = await _repository
          .enrollmentParamsFor(pack.id);
      if (params == null) {
        continue;
      }
      enrollments[pack.id] = params;
      final ProgressState? progress = await _repository.progressFor(pack.id);
      if (_isCompleteCommitment(pack, progress)) {
        AppLogger.debug(
          'Skipping completed commitment "${pack.id}" '
              '(${progress?.fulfilledOrdinals ?? 0} fulfilled) — its '
              'reminders are done',
          'NOTIF',
        );
        continue;
      }
      plannedPacks.add(pack);
    }

    final List<NotificationRow> rows = await _database.getAllNotifications();
    final Map<String, NotificationRow> rowsById = <String, NotificationRow>{
      for (final NotificationRow row in rows) row.id: row,
    };
    final List<PlannedNotification> alreadyPending = <PlannedNotification>[
      for (final NotificationRow row in rows)
        if (row.status == 'scheduled') _plannedFromRow(row),
    ];

    // The master gate (fix round 1): the SHARED base settings'
    // `notificationsEnabled` is the kill switch over ALL of this app's
    // reminders. With the gate closed the plan is EMPTY and the diff below
    // cancels every scheduled row and device notification — the same code
    // path as a settings toggle-off (the ruling pinned: `refresh` still
    // runs the full diff, never a bare early return). The read goes through
    // the app settings' synced `baseSettings` snapshot, which
    // `DevotionsSettingsNotifier` replaces on every `baseSettingsProvider`
    // change (Task 3's pinned one-way sync), so a gate flip on the settings
    // screen takes effect at the very next refresh pass.
    final bool reminderGateOpen = settings.baseSettings.notificationsEnabled;
    final List<PlannedNotification> plan = reminderGateOpen
        ? _planner.plan(
            now: now,
            timeZoneName: zoneName,
            packs: plannedPacks,
            enrollments: enrollments,
            // Binding note 2: the FEAST-ONLY seam (see the library docs).
            upcomingFeasts: _upcomingFeasts(now),
            settings: settings,
            alreadyPending: alreadyPending,
          )
        : <PlannedNotification>[];
    if (!reminderGateOpen) {
      AppLogger.debug(
        'Notification gate closed — every reminder suppressed',
        'NOTIF',
      );
    }

    // The device's pending snapshot, keyed by the planner id in its payload.
    final Map<String, PendingNotification> pendingById =
        <String, PendingNotification>{};
    for (final PendingNotification pending
        in await _adapter.pendingNotifications()) {
      final _Payload decoded = _decodePayload(pending.payload);
      final String? id = decoded.id;
      if (id == null) {
        // Not one of ours (or a legacy bare-link payload): never cancel it.
        continue;
      }
      pendingById[id] = pending;
    }

    int scheduled = 0;
    int replaced = 0;
    int cancelled = 0;
    int unchanged = 0;

    // 1. Write the plan: schedule new ids, cancel+replace changed payloads,
    //    leave an unchanged id untouched (the zero-write property).
    for (final PlannedNotification planned in plan) {
      final NotificationRow? row = rowsById[planned.id];
      if (row != null && row.status == 'fired') {
        // A tapped notification's id is terminal: the id names one
        // occurrence, and that occurrence was already delivered.
        continue;
      }
      final PendingNotification? pending = pendingById[planned.id];
      final bool unchangedPayload = row != null && _rowMatches(row, planned);
      final bool samePlatformId =
          pending != null && pending.platformId == platformIdFor(planned.id);
      if (unchangedPayload && samePlatformId) {
        unchanged++;
        continue;
      }
      if (pending != null) {
        await _adapter.cancel(pending.platformId);
        if (unchangedPayload) {
          // Same payload under a drifted platform id: the id is corrected,
          // the row is not rewritten below.
          replaced++;
          await _schedule(planned);
          continue;
        }
        replaced++;
      } else {
        scheduled++;
      }
      await _schedule(planned);
      await _database.upsertNotification(
        id: planned.id,
        packId: planned.packId,
        fireAt: _iso(planned.fireAt),
        title: planned.title,
        body: planned.body,
        deepLink: planned.deepLink,
        status: 'scheduled',
      );
    }

    // 2. Cancel device notifications the plan no longer wants (settings
    //    switched off, a commitment completed, the horizon moved on).
    for (final MapEntry<String, PendingNotification> entry
        in pendingById.entries) {
      if (plan.any((PlannedNotification p) => p.id == entry.key)) {
        continue;
      }
      final NotificationRow? row = rowsById[entry.key];
      if (row != null && row.status == 'fired') {
        continue;
      }
      await _adapter.cancel(entry.value.platformId);
      cancelled++;
      if (row != null && row.status == 'scheduled') {
        await _database.setNotificationStatus(
          id: entry.key,
          status: 'cancelled',
        );
      }
    }

    // 3. Heal store drift: a `scheduled` row the plan dropped and the device
    //    no longer holds (stale store id) is marked cancelled. A row that is
    //    on the device was already handled above.
    for (final NotificationRow row in rows) {
      if (row.status != 'scheduled') {
        continue;
      }
      if (plan.any((PlannedNotification p) => p.id == row.id)) {
        continue;
      }
      if (pendingById.containsKey(row.id)) {
        continue;
      }
      await _database.setNotificationStatus(id: row.id, status: 'cancelled');
      cancelled++;
    }

    AppLogger.info(
      'Notification refresh: ${plan.length} planned — $scheduled scheduled, '
          '$replaced replaced, $cancelled cancelled, $unchanged unchanged',
      'NOTIF',
    );
  }

  /// Schedules one planned notification under its platform id and payload.
  Future<void> _schedule(PlannedNotification planned) {
    return _adapter.schedule(
      platformId: platformIdFor(planned.id),
      title: planned.title,
      body: planned.body,
      fireAt: planned.fireAt,
      payload: _encodePayload(planned),
    );
  }

  /// Handles one notification tap (the plugin callback and the cold-start
  /// launch payload): emits the deep link, marks the row `fired`, and runs a
  /// refresh (a spec §9 refresh point).
  Future<void> _handleTap(String payload) async {
    final _Payload decoded = _decodePayload(payload);
    final String link = decoded.link ?? '/';
    _taps.add(link);
    final String? id = decoded.id;
    if (id != null) {
      try {
        final bool marked = await _database.setNotificationStatus(
          id: id,
          status: 'fired',
        );
        if (!marked) {
          AppLogger.debug(
            'Tapped notification "$id" has no store row — nothing to mark',
            'NOTIF',
          );
        }
      } catch (e, stackTrace) {
        AppLogger.error(
          'Failed to mark notification "$id" as fired',
          e,
          stackTrace,
          'NOTIF',
        );
      }
    }
    AppLogger.info('Notification tapped → $link', 'NOTIF');
    await refresh();
  }

  /// Closes the tap stream (the provider's dispose hook).
  Future<void> dispose() => _taps.close();

  /// Whether [pack]'s commitment is complete under [progress] — the
  /// completed-commitment exclusion (binding note 1).
  ///
  /// A pack whose commitment schedule is complete is excluded WHOLESALE, the
  /// same semantic the wrapper's `todayProgramsProvider` applies (it stops at
  /// the completed schedule), so a completed program cannot be resurrected
  /// into the plan by another schedule of the same pack.
  static bool _isCompleteCommitment(ContentPack pack, ProgressState? progress) {
    final int fulfilled = progress?.fulfilledOrdinals ?? 0;
    for (final ScheduleSpec spec in pack.schedules) {
      if (spec is ConsecutiveCommitmentSpec && fulfilled >= spec.count) {
        return true;
      }
    }
    return false;
  }

  /// The store row as the planner's pending shape (only its id is read by the
  /// planner; the payload fields keep the value honest for logging).
  static PlannedNotification _plannedFromRow(NotificationRow row) {
    return PlannedNotification(
      id: row.id,
      fireAt: DateTime.parse(row.fireAt),
      title: row.title,
      body: row.body,
      deepLink: row.deepLink,
      packId: row.packId ?? '',
    );
  }

  /// Whether [row] already carries exactly [planned]'s payload.
  static bool _rowMatches(NotificationRow row, PlannedNotification planned) {
    return row.status == 'scheduled' &&
        row.fireAt == _iso(planned.fireAt) &&
        row.title == planned.title &&
        row.body == planned.body &&
        row.deepLink == planned.deepLink &&
        row.packId == planned.packId;
  }

  /// The store's `fire_at` rendering: the zoned instant's own ISO-8601 form
  /// (local wall clock plus that date's offset, e.g.
  /// `2026-12-01T06:00:00.000-0500` — `toIso8601String` renders the offset
  /// WITHOUT a colon), so reading a row back keeps the
  /// instant and the offset that produced it.
  static String _iso(DateTime fireAt) => fireAt.toIso8601String();

  /// The payload envelope of one planned notification.
  static String _encodePayload(PlannedNotification planned) =>
      jsonEncode(<String, String>{'id': planned.id, 'link': planned.deepLink});

  /// Decodes a payload envelope; a non-envelope payload is tolerated (a bare
  /// deep link is still surfaced to [taps], and never cancelled).
  static _Payload _decodePayload(String? payload) {
    if (payload == null || payload.isEmpty) {
      return const _Payload();
    }
    try {
      final Object? decoded = jsonDecode(payload);
      if (decoded is Map<String, dynamic>) {
        final Object? id = decoded['id'];
        final Object? link = decoded['link'];
        return _Payload(
          id: id is String ? id : null,
          link: link is String ? link : null,
        );
      }
    } on FormatException {
      // Not JSON: fall through to the bare-link reading.
    }
    return _Payload(link: payload.startsWith('/') ? payload : null);
  }

  /// The default calendar seam: the feast-only upcoming list over the 60-day
  /// horizon (binding note 2).
  static List<LiturgicalDayData> _defaultUpcomingFeasts(DateTime from) {
    return LiturgicalCalendarService.getUpcomingFeasts(
      daysAhead: notificationHorizonDays,
      fromDate: from,
    );
  }
}
