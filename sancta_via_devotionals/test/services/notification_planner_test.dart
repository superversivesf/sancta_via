// Notification planner tests (Plan 2, Task 17).
//
// Pins the pure planning contract Task 18's wiring consumes:
//
// - anchor items repeat DAILY as `TZDateTime` at the user's local offset, so
//   a 07:00 anchor stays 07:00 across a DST spring-forward (the plan is built
//   from a zone name whose data is initialized by the caller — `now` is an
//   instant the planner reads in that zone);
// - the per-anchor settings toggles gate their own items (`enableAngelusAnchors`
//   → the Angelus' three anchors, `enableMercyHourAnchor` → the 15:00 Hour of
//   Mercy, `nightItemsEnabled` → the off-by-default night items, and the
//   morning/evening reminder toggles gate the remaining routine anchors of
//   their section);
// - commitment/novena/series packs get one 'morningOf' (07:00 local) reminder
//   per due session in the 60-day horizon, with the day ordinal and the pack's
//   grace-window note;
// - rotation prunes to the 60 nearest upcoming candidates while PRESERVING the
//   ids already scheduled on the device, and ids are deterministic so two
//   plan() calls on the same inputs are identical (the wiring's diff empties).
import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_test/flutter_test.dart';
import 'package:sancta_via_devotional_engine/sancta_via_devotional_engine.dart';
import 'package:sancta_via_devotionals/models/app_settings.dart';
import 'package:sancta_via_devotionals/services/notification_planner.dart';
import 'package:sancta_via_liturgical_calendar/sancta_via_liturgical_calendar.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// The zone name under test (the planner receives it as a plain string, the
/// way Task 18 passes `flutter_timezone`'s answer).
const String _zoneName = 'America/New_York';

late tz.Location _zone;

/// A plain, session-free pack: the planner never walks a session, so the
/// script only has to satisfy the engine's own construction rules.
ContentPack _pack({
  required String id,
  required String title,
  required PackFamily family,
  required List<ScheduleSpec> schedules,
  Map<String, dynamic> reminders = const <String, dynamic>{},
}) {
  return ContentPack(
    id: id,
    title: title,
    family: family,
    schedules: schedules,
    session: SessionScript(
      id: '$id-session',
      steps: <SessionStep>[
        IntercessionStep(id: '$id-intercession', prompt: 'Pray.'),
      ],
    ),
    reminders: reminders,
  );
}

/// The Angelus' three daily anchors (the Task 24 contract: 6/12/18 with the
/// season-aware `regina_caeli` variant).
ContentPack _angelusPack() {
  return _pack(
    id: 'angelus',
    title: 'The Angelus',
    family: PackFamily.routine,
    schedules: <ScheduleSpec>[
      TimeOfDaySpec(
        6,
        0,
        baseLabel: 'angelus',
        variants: <SeasonVariant>[
          SeasonVariant(
            months: const <int>[],
            seasons: const <String>{'Easter', 'Eastertide', 'Pentecost'},
            variantId: 'regina_caeli',
          ),
        ],
      ),
      TimeOfDaySpec(
        12,
        0,
        baseLabel: 'angelus',
        variants: <SeasonVariant>[
          SeasonVariant(
            months: const <int>[],
            seasons: const <String>{'Easter', 'Eastertide', 'Pentecost'},
            variantId: 'regina_caeli',
          ),
        ],
      ),
      TimeOfDaySpec(
        18,
        0,
        baseLabel: 'angelus',
        variants: <SeasonVariant>[
          SeasonVariant(
            months: const <int>[],
            seasons: const <String>{'Easter', 'Eastertide', 'Pentecost'},
            variantId: 'regina_caeli',
          ),
        ],
      ),
    ],
  );
}

ContentPack _mercyHourPack() {
  return _pack(
    id: 'mercy_hour',
    title: 'Hour of Mercy',
    family: PackFamily.routine,
    schedules: <ScheduleSpec>[TimeOfDaySpec(15, 0, baseLabel: 'mercy_hour')],
  );
}

/// The Five First Saturdays shape: a monthly commitment with the pack's own
/// ±8-day confession grace window.
ContentPack _firstSaturdaysPack() {
  return _pack(
    id: 'five_first_saturdays',
    title: 'Five First Saturdays',
    family: PackFamily.commitment,
    schedules: <ScheduleSpec>[
      ConsecutiveCommitmentSpec(
        anchor: NthWeekdayOfMonthSpec(DateTime.saturday, 1),
        count: 5,
        policy: RestartPolicy.strict,
        windows: <GraceWindow>[
          GraceWindow(item: 'confession', beforeDays: 8, afterDays: 8),
        ],
      ),
    ],
  );
}

/// A bounded series anchored to [startDate] (a novena/consecration shape).
ContentPack _seriesPack({
  required String id,
  required String title,
  required DateTime startDate,
  required int lengthDays,
}) {
  return _pack(
    id: id,
    title: title,
    family: PackFamily.novena,
    schedules: <ScheduleSpec>[
      SessionSeriesSpec(startDate: startDate, lengthDays: lengthDays),
    ],
  );
}

/// The zero-padded `yyyy-mm-dd` stamp the planner's ids use.
String _stamp(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// `TZDateTime` at the zone's local [hour] on the calendar day [day].
DateTime _at(DateTime day, int hour, [int minute = 0]) =>
    tz.TZDateTime(_zone, day.year, day.month, day.day, hour, minute);

/// The enrollment map whose presence marks a pack as enrolled (the pinned
/// seam: the planner plans ONLY packs the user is enrolled in).
Map<String, Map<String, dynamic>> _enroll(List<ContentPack> packs) {
  return <String, Map<String, dynamic>>{
    for (final ContentPack pack in packs) pack.id: <String, dynamic>{},
  };
}

/// The planned notifications for one calendar day.
List<PlannedNotification> _onDay(List<PlannedNotification> plan, DateTime day) {
  return <PlannedNotification>[
    for (final PlannedNotification notification in plan)
      if (notification.fireAt.year == day.year &&
          notification.fireAt.month == day.month &&
          notification.fireAt.day == day.day)
        notification,
  ];
}

void main() {
  setUpAll(() {
    tzdata.initializeTimeZones();
    _zone = tz.getLocation(_zoneName);
  });

  group('anchor items (daily TZDateTime, settings-gated)', () {
    test('the Angelus fires three times a day (6, 12, 18) when enabled', () {
      // Given the Angelus pack, the default settings (the anchor toggles are
      // ON by default) and a plan from local midnight.
      final List<PlannedNotification> plan = const NotificationPlanner().plan(
        now: tz.TZDateTime(_zone, 2026, 12, 1),
        timeZoneName: _zoneName,
        packs: <ContentPack>[_angelusPack()],
        enrollments: _enroll(<ContentPack>[_angelusPack()]),
        upcomingFeasts: const <LiturgicalDayData>[],
        settings: DevotionsAppSettings.defaults(),
        alreadyPending: const <PlannedNotification>[],
      );

      // Then the first day carries exactly the three anchors, each at its
      // configured local time.
      final List<PlannedNotification> firstDay = _onDay(
        plan,
        DateTime(2026, 12, 1),
      );
      expect(firstDay, hasLength(3));
      expect(
        <int>[for (final PlannedNotification n in firstDay) n.fireAt.hour],
        <int>[6, 12, 18],
      );
      expect(
        <int>[for (final PlannedNotification n in firstDay) n.fireAt.minute],
        <int>[0, 0, 0],
      );
      expect(firstDay.first.body, 'Angelus');
      expect(firstDay.first.title, 'The Angelus');
      expect(
        <String>[for (final PlannedNotification n in firstDay) n.packId],
        <String>['angelus', 'angelus', 'angelus'],
      );
      expect(firstDay.first.deepLink, '/session/angelus?forDate=2026-12-01');
      // The custom anchor times drive the fire times.
      final int morningHour = firstDay.first.fireAt.hour;
      expect(morningHour, 6);
    });

    test('anchor times follow the settings time-picker values', () {
      final DevotionsAppSettings settings = DevotionsAppSettings.defaults()
          .copyWith(
            angelusMorning: const TimeOfDay(hour: 7, minute: 15),
            angelusNoon: const TimeOfDay(hour: 12, minute: 30),
            angelusEvening: const TimeOfDay(hour: 20, minute: 45),
            eveningReminderEnabled: false,
          );

      final List<PlannedNotification> plan = const NotificationPlanner().plan(
        now: tz.TZDateTime(_zone, 2026, 12, 1),
        timeZoneName: _zoneName,
        packs: <ContentPack>[_angelusPack()],
        enrollments: _enroll(<ContentPack>[_angelusPack()]),
        upcomingFeasts: const <LiturgicalDayData>[],
        settings: settings,
        alreadyPending: const <PlannedNotification>[],
      );

      final List<PlannedNotification> firstDay = _onDay(
        plan,
        DateTime(2026, 12, 1),
      );
      expect(
        <String>[
          for (final PlannedNotification n in firstDay)
            '${n.fireAt.hour}:${n.fireAt.minute.toString().padLeft(2, '0')}',
        ],
        <String>['7:15', '12:30', '20:45'],
      );
    });

    test('disabling the Angelus anchors removes them', () {
      final List<PlannedNotification> plan = const NotificationPlanner().plan(
        now: tz.TZDateTime(_zone, 2026, 12, 1),
        timeZoneName: _zoneName,
        packs: <ContentPack>[_angelusPack()],
        enrollments: _enroll(<ContentPack>[_angelusPack()]),
        upcomingFeasts: const <LiturgicalDayData>[],
        settings: DevotionsAppSettings.defaults().copyWith(
          enableAngelusAnchors: false,
        ),
        alreadyPending: const <PlannedNotification>[],
      );

      expect(plan, isEmpty);
    });

    test('the Hour of Mercy fires at 15:00 when enabled', () {
      final ContentPack mercy = _mercyHourPack();
      final List<PlannedNotification> plan = const NotificationPlanner().plan(
        now: tz.TZDateTime(_zone, 2026, 12, 1),
        timeZoneName: _zoneName,
        packs: <ContentPack>[mercy],
        enrollments: _enroll(<ContentPack>[mercy]),
        upcomingFeasts: const <LiturgicalDayData>[],
        settings: DevotionsAppSettings.defaults(),
        alreadyPending: const <PlannedNotification>[],
      );

      final List<PlannedNotification> firstDay = _onDay(
        plan,
        DateTime(2026, 12, 1),
      );
      expect(firstDay, hasLength(1));
      expect(firstDay.single.fireAt.hour, 15);
      expect(firstDay.single.fireAt.minute, 0);
      expect(firstDay.single.body, 'Mercy Hour');
      expect(
        firstDay.single.deepLink,
        '/session/mercy_hour?forDate=2026-12-01',
      );
    });

    test('disabling the mercy anchor removes it', () {
      final ContentPack mercy = _mercyHourPack();
      final List<PlannedNotification> plan = const NotificationPlanner().plan(
        now: tz.TZDateTime(_zone, 2026, 12, 1),
        timeZoneName: _zoneName,
        packs: <ContentPack>[mercy],
        enrollments: _enroll(<ContentPack>[mercy]),
        upcomingFeasts: const <LiturgicalDayData>[],
        settings: DevotionsAppSettings.defaults().copyWith(
          enableMercyHourAnchor: false,
        ),
        alreadyPending: const <PlannedNotification>[],
      );

      expect(plan, isEmpty);
    });

    test('night items are excluded by default and included when enabled', () {
      final ContentPack night = _pack(
        id: 'meal_night_prayers',
        title: 'Night Prayers',
        family: PackFamily.routine,
        schedules: <ScheduleSpec>[
          TimeOfDaySpec(21, 0, baseLabel: 'night_prayers'),
        ],
      );

      final List<PlannedNotification> excluded = const NotificationPlanner()
          .plan(
            now: tz.TZDateTime(_zone, 2026, 12, 1),
            timeZoneName: _zoneName,
            packs: <ContentPack>[night],
            enrollments: _enroll(<ContentPack>[night]),
            upcomingFeasts: const <LiturgicalDayData>[],
            settings: DevotionsAppSettings.defaults(),
            alreadyPending: const <PlannedNotification>[],
          );
      expect(excluded, isEmpty);

      final List<PlannedNotification> included = const NotificationPlanner()
          .plan(
            now: tz.TZDateTime(_zone, 2026, 12, 1),
            timeZoneName: _zoneName,
            packs: <ContentPack>[night],
            enrollments: _enroll(<ContentPack>[night]),
            upcomingFeasts: const <LiturgicalDayData>[],
            settings: DevotionsAppSettings.defaults().copyWith(
              nightItemsEnabled: true,
            ),
            alreadyPending: const <PlannedNotification>[],
          );
      expect(included, hasLength(60));
      expect(
        included.every((PlannedNotification n) => n.fireAt.hour == 21),
        isTrue,
      );
    });

    test('a routine morning anchor needs the morning reminder toggle', () {
      final ContentPack morningOffering = _pack(
        id: 'morning_offering',
        title: 'Morning Offering',
        family: PackFamily.routine,
        schedules: <ScheduleSpec>[
          TimeOfDaySpec(7, 30, baseLabel: 'morning_offering'),
        ],
      );

      final List<PlannedNotification> off = const NotificationPlanner().plan(
        now: tz.TZDateTime(_zone, 2026, 12, 1),
        timeZoneName: _zoneName,
        packs: <ContentPack>[morningOffering],
        enrollments: _enroll(<ContentPack>[morningOffering]),
        upcomingFeasts: const <LiturgicalDayData>[],
        settings: DevotionsAppSettings.defaults(),
        alreadyPending: const <PlannedNotification>[],
      );
      expect(off, isEmpty);

      final List<PlannedNotification> on = const NotificationPlanner().plan(
        now: tz.TZDateTime(_zone, 2026, 12, 1),
        timeZoneName: _zoneName,
        packs: <ContentPack>[morningOffering],
        enrollments: _enroll(<ContentPack>[morningOffering]),
        upcomingFeasts: const <LiturgicalDayData>[],
        settings: DevotionsAppSettings.defaults().copyWith(
          morningReminderEnabled: true,
        ),
        alreadyPending: const <PlannedNotification>[],
      );
      expect(on, hasLength(60));
      expect(
        on.every(
          (PlannedNotification n) =>
              n.fireAt.hour == 7 && n.fireAt.minute == 30,
        ),
        isTrue,
      );
    });

    test('only enrolled packs are planned', () {
      final List<PlannedNotification> plan = const NotificationPlanner().plan(
        now: tz.TZDateTime(_zone, 2026, 12, 1),
        timeZoneName: _zoneName,
        packs: <ContentPack>[_angelusPack()],
        enrollments: const <String, Map<String, dynamic>>{},
        upcomingFeasts: const <LiturgicalDayData>[],
        settings: DevotionsAppSettings.defaults(),
        alreadyPending: const <PlannedNotification>[],
      );

      expect(plan, isEmpty);
    });
  });

  group('session reminders (morningOf at 07:00)', () {
    test('a series session fires at 07:00 with its day ordinal', () {
      // Day 6 of a nine-day novena is today (day 1 was five days ago).
      final DateTime today = DateTime(2026, 12, 1);
      final ContentPack novena = _seriesPack(
        id: 'divine_mercy_novena',
        title: 'Divine Mercy Novena',
        startDate: DateTime(2026, 11, 26),
        lengthDays: 9,
      );

      final List<PlannedNotification> plan = const NotificationPlanner().plan(
        now: tz.TZDateTime(_zone, 2026, 12, 1),
        timeZoneName: _zoneName,
        packs: <ContentPack>[novena],
        enrollments: _enroll(<ContentPack>[novena]),
        upcomingFeasts: const <LiturgicalDayData>[],
        settings: DevotionsAppSettings.defaults(),
        alreadyPending: const <PlannedNotification>[],
      );

      // Only the remaining four sessions of the series are still upcoming.
      expect(plan, hasLength(4));
      final PlannedNotification first = plan.first;
      expect(first.fireAt.hour, 7);
      expect(first.fireAt.minute, 0);
      expect(first.fireAt.isAtSameMomentAs(_at(today, 7)), isTrue);
      expect(first.title, 'Divine Mercy Novena');
      expect(first.body, 'Day 6 of 9');
      expect(first.packId, 'divine_mercy_novena');
      expect(first.deepLink, '/session/divine_mercy_novena?forDate=2026-12-01');
      // …and the series' own ordinal advances day by day.
      expect(
        <String>[for (final PlannedNotification n in plan) n.body],
        <String>['Day 6 of 9', 'Day 7 of 9', 'Day 8 of 9', 'Day 9 of 9'],
      );
    });

    test('a commitment reminder carries the grace-window note', () {
      final ContentPack pack = _firstSaturdaysPack();
      final List<PlannedNotification> plan = const NotificationPlanner().plan(
        now: tz.TZDateTime(_zone, 2026, 12, 1),
        timeZoneName: _zoneName,
        packs: <ContentPack>[pack],
        enrollments: _enroll(<ContentPack>[pack]),
        upcomingFeasts: const <LiturgicalDayData>[],
        settings: DevotionsAppSettings.defaults(),
        alreadyPending: const <PlannedNotification>[],
      );

      final PlannedNotification firstSaturday = plan.first;
      expect(
        firstSaturday.fireAt.isAtSameMomentAs(_at(DateTime(2026, 12, 5), 7)),
        isTrue,
      );
      expect(firstSaturday.title, 'Five First Saturdays');
      expect(firstSaturday.body, contains('Due today'));
      expect(
        firstSaturday.body,
        contains('Confession may be made within 8 days before or after'),
      );
      expect(
        firstSaturday.id,
        'five_first_saturdays:session:${_stamp(DateTime(2026, 12, 5))}',
      );
    });

    test('a feast on the reminder day is named in the body', () {
      // Day 8 of ten is 2026-12-08 (the Immaculate Conception).
      final ContentPack series = _seriesPack(
        id: 'advent_series',
        title: 'Advent Series',
        startDate: DateTime(2026, 12, 1),
        lengthDays: 10,
      );
      final List<LiturgicalDayData> feasts =
          LiturgicalCalendarService.getUpcomingFeasts(
            fromDate: DateTime(2026, 12, 1),
            daysAhead: 60,
          );

      final List<PlannedNotification> plan = const NotificationPlanner().plan(
        now: tz.TZDateTime(_zone, 2026, 12, 1),
        timeZoneName: _zoneName,
        packs: <ContentPack>[series],
        enrollments: _enroll(<ContentPack>[series]),
        upcomingFeasts: feasts,
        settings: DevotionsAppSettings.defaults(),
        alreadyPending: const <PlannedNotification>[],
      );

      final PlannedNotification immaculateConception = plan.firstWhere(
        (PlannedNotification n) =>
            n.fireAt.year == 2026 && n.fireAt.month == 12 && n.fireAt.day == 8,
      );
      expect(immaculateConception.body, startsWith('Day 8 of 10'));
      expect(immaculateConception.body, contains('Immaculate Conception'));
    });

    test('ids are deterministic across two plans of the same inputs', () {
      final ContentPack novena = _seriesPack(
        id: 'novena_54_day',
        title: '54-Day Rosary Novena',
        startDate: DateTime(2026, 12, 1),
        lengthDays: 54,
      );
      final ContentPack pack = _angelusPack();
      final List<ContentPack> packs = <ContentPack>[novena, pack];
      final Map<String, Map<String, dynamic>> enrollments = _enroll(packs);
      const NotificationPlanner planner = NotificationPlanner();

      final List<PlannedNotification> first = planner.plan(
        now: tz.TZDateTime(_zone, 2026, 12, 1),
        timeZoneName: _zoneName,
        packs: packs,
        enrollments: enrollments,
        upcomingFeasts: const <LiturgicalDayData>[],
        settings: DevotionsAppSettings.defaults(),
        alreadyPending: const <PlannedNotification>[],
      );
      final List<PlannedNotification> second = planner.plan(
        now: tz.TZDateTime(_zone, 2026, 12, 1),
        timeZoneName: _zoneName,
        packs: packs,
        enrollments: enrollments,
        upcomingFeasts: const <LiturgicalDayData>[],
        settings: DevotionsAppSettings.defaults(),
        alreadyPending: first,
      );

      expect(second, first);
      final Set<String> ids = <String>{
        for (final PlannedNotification n in first) n.id,
      };
      expect(ids, hasLength(first.length));
    });

    test('the plan is capped at the planner\'s maxPending and sorted', () {
      final ContentPack pack = _firstSaturdaysPack();
      final List<PlannedNotification> plan = const NotificationPlanner().plan(
        now: tz.TZDateTime(_zone, 2026, 12, 1),
        timeZoneName: _zoneName,
        packs: <ContentPack>[pack],
        enrollments: _enroll(<ContentPack>[pack]),
        upcomingFeasts: const <LiturgicalDayData>[],
        settings: DevotionsAppSettings.defaults(),
        alreadyPending: const <PlannedNotification>[],
      );

      expect(const NotificationPlanner().maxPending, 60);
      expect(plan.length, lessThanOrEqualTo(60));
      for (int i = 1; i < plan.length; i++) {
        expect(
          plan[i - 1].fireAt.isAfter(plan[i].fireAt),
          isFalse,
          reason: 'the plan is ordered by fire time',
        );
      }
    });
  });

  group('60-day rotation', () {
    test('100 candidates prune to the 60 nearest, nearest first', () {
      final DateTime start = DateTime(2026, 12, 1);
      final ContentPack a = _seriesPack(
        id: 'pack_a',
        title: 'Pack A',
        startDate: start,
        lengthDays: 60,
      );
      final ContentPack b = _seriesPack(
        id: 'pack_b',
        title: 'Pack B',
        startDate: start,
        lengthDays: 60,
      );
      final List<ContentPack> packs = <ContentPack>[a, b];

      final List<PlannedNotification> plan = const NotificationPlanner().plan(
        now: tz.TZDateTime(_zone, 2026, 12, 1),
        timeZoneName: _zoneName,
        packs: packs,
        enrollments: _enroll(packs),
        upcomingFeasts: const <LiturgicalDayData>[],
        settings: DevotionsAppSettings.defaults(),
        alreadyPending: const <PlannedNotification>[],
      );

      // 60 days × 2 packs = 120 candidates; the nearest 60 are the first 30
      // days, in fire-time order.
      final List<String> expectedIds = <String>[
        for (int offset = 0; offset < 30; offset++)
          for (final String packId in <String>['pack_a', 'pack_b'])
            '$packId:session:${_stamp(DateTime(2026, 12, 1 + offset))}',
      ];
      expect(plan, hasLength(60));
      expect(<String>[
        for (final PlannedNotification n in plan) n.id,
      ], expectedIds);
    });

    test('already-scheduled ids are preserved beyond the nearest 60', () {
      final DateTime start = DateTime(2026, 12, 1);
      final ContentPack a = _seriesPack(
        id: 'pack_a',
        title: 'Pack A',
        startDate: start,
        lengthDays: 60,
      );
      final ContentPack b = _seriesPack(
        id: 'pack_b',
        title: 'Pack B',
        startDate: start,
        lengthDays: 60,
      );
      final List<ContentPack> packs = <ContentPack>[a, b];

      // Five FAR ids are already on the device (days 55-59 of pack A) — they
      // are outside the nearest 60, and the prune must keep them anyway.
      final List<String> pendingIds = <String>[
        for (int offset = 55; offset < 60; offset++)
          'pack_a:session:${_stamp(DateTime(2026, 12, 1 + offset))}',
      ];
      final List<PlannedNotification> alreadyPending = <PlannedNotification>[
        for (final String id in pendingIds)
          PlannedNotification(
            id: id,
            fireAt: _at(DateTime(2026, 12, 1), 7),
            title: 'stale',
            body: 'stale',
            deepLink: '/',
            packId: 'pack_a',
          ),
      ];

      final List<PlannedNotification> plan = const NotificationPlanner().plan(
        now: tz.TZDateTime(_zone, 2026, 12, 1),
        timeZoneName: _zoneName,
        packs: packs,
        enrollments: _enroll(packs),
        upcomingFeasts: const <LiturgicalDayData>[],
        settings: DevotionsAppSettings.defaults(),
        alreadyPending: alreadyPending,
      );

      expect(plan, hasLength(60));
      final Set<String> planIds = <String>{
        for (final PlannedNotification n in plan) n.id,
      };
      expect(planIds.containsAll(pendingIds), isTrue);
      // The kept entries are freshly computed (never the stale payload).
      final PlannedNotification keptFar = plan.firstWhere(
        (PlannedNotification n) => n.id == pendingIds.first,
      );
      expect(keptFar.title, 'Pack A');
      expect(keptFar.fireAt.hour, 7);

      // The remaining 55 slots are the nearest not-yet-scheduled candidates.
      final List<(DateTime, String)> all = <(DateTime, String)>[
        for (int offset = 0; offset < 60; offset++)
          for (final String packId in <String>['pack_a', 'pack_b'])
            (
              _at(DateTime(2026, 12, 1 + offset), 7),
              '$packId:session:${_stamp(DateTime(2026, 12, 1 + offset))}',
            ),
      ];
      all.sort(((DateTime, String) x, (DateTime, String) y) {
        final int byTime = x.$1.compareTo(y.$1);
        return byTime != 0 ? byTime : x.$2.compareTo(y.$2);
      });
      final List<String> expectedNearest = <String>[
        for (final (DateTime, String) entry in all)
          if (!pendingIds.contains(entry.$2)) entry.$2,
      ].take(55).toList();
      final List<String> plannedNew = <String>[
        for (final PlannedNotification n in plan)
          if (!pendingIds.contains(n.id)) n.id,
      ];
      expect(plannedNew, expectedNearest);
    });
  });

  group('DST-safe anchors', () {
    test('a 07:00 anchor stays 07:00 across the 2027-03-14 spring-forward', () {
      // A single-anchor routine (the Angelus' morning anchor) at 07:00.
      final ContentPack pack = _pack(
        id: 'angelus',
        title: 'The Angelus',
        family: PackFamily.routine,
        schedules: <ScheduleSpec>[TimeOfDaySpec(6, 0, baseLabel: 'angelus')],
      );
      final DevotionsAppSettings settings = DevotionsAppSettings.defaults()
          .copyWith(angelusMorning: const TimeOfDay(hour: 7, minute: 0));

      final List<PlannedNotification> plan = const NotificationPlanner().plan(
        // The 60-day horizon opens 2027-02-01, so it spans 2027-03-14.
        now: tz.TZDateTime(_zone, 2027, 2, 1),
        timeZoneName: _zoneName,
        packs: <ContentPack>[pack],
        enrollments: _enroll(<ContentPack>[pack]),
        upcomingFeasts: const <LiturgicalDayData>[],
        settings: settings,
        alreadyPending: const <PlannedNotification>[],
      );

      expect(plan, hasLength(60));
      final DateTime transition = tz.TZDateTime(_zone, 2027, 3, 14);
      final List<PlannedNotification> before = <PlannedNotification>[
        for (final PlannedNotification n in plan)
          if (n.fireAt.isBefore(transition)) n,
      ];
      final List<PlannedNotification> after = <PlannedNotification>[
        for (final PlannedNotification n in plan)
          if (!n.fireAt.isBefore(transition)) n,
      ];
      expect(before, isNotEmpty);
      expect(after, isNotEmpty);
      // Every planned anchor keeps the user's wall clock…
      expect(
        plan.every(
          (PlannedNotification n) => n.fireAt.hour == 7 && n.fireAt.minute == 0,
        ),
        isTrue,
      );
      // …while the zone's offset legitimately moves from EST to EDT.
      expect(
        before.every(
          (PlannedNotification n) =>
              n.fireAt.timeZoneOffset == const Duration(hours: -5),
        ),
        isTrue,
      );
      expect(
        after.every(
          (PlannedNotification n) =>
              n.fireAt.timeZoneOffset == const Duration(hours: -4),
        ),
        isTrue,
      );
    });

    test('a 07:00 session reminder stays 07:00 across the spring-forward', () {
      final ContentPack series = _seriesPack(
        id: 'lenten_series',
        title: 'Lenten Series',
        startDate: DateTime(2027, 2, 1),
        lengthDays: 60,
      );

      final List<PlannedNotification> plan = const NotificationPlanner().plan(
        now: tz.TZDateTime(_zone, 2027, 2, 1),
        timeZoneName: _zoneName,
        packs: <ContentPack>[series],
        enrollments: _enroll(<ContentPack>[series]),
        upcomingFeasts: const <LiturgicalDayData>[],
        settings: DevotionsAppSettings.defaults(),
        alreadyPending: const <PlannedNotification>[],
      );

      expect(plan, hasLength(60));
      final DateTime transition = tz.TZDateTime(_zone, 2027, 3, 14);
      final List<PlannedNotification> after = <PlannedNotification>[
        for (final PlannedNotification n in plan)
          if (!n.fireAt.isBefore(transition)) n,
      ];
      expect(after, isNotEmpty);
      expect(
        plan.every(
          (PlannedNotification n) => n.fireAt.hour == 7 && n.fireAt.minute == 0,
        ),
        isTrue,
      );
      expect(
        after.every(
          (PlannedNotification n) =>
              n.fireAt.timeZoneOffset == const Duration(hours: -4),
        ),
        isTrue,
      );
    });
  });
}
