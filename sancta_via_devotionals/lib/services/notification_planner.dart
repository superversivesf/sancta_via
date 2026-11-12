// The 60-day notification planner (Plan 2, Task 17).
//
// The pure half of the notification stack: the planner decides WHICH
// notifications exist and WHEN they fire, and Task 18 wires the answer into
// `flutter_local_notifications`. Nothing here imports a plugin: the user's
// zone name arrives as a string (Task 18 reads it from `flutter_timezone`),
// the time-zone data is `package:timezone` (pure Dart), and the liturgical
// calendar arrives as data ([LiturgicalDayData] entries) instead of being
// read from a provider or the clock.
//
// ## What is planned
//
// * **Anchors** — every enrolled pack carrying a [TimeOfDaySpec] anchor
//   contributes one notification per day of the horizon, at the day's local
//   wall-clock time as a [tz.TZDateTime] in [timeZoneName]. Constructing the
//   instant from the calendar date and the clock time (never by adding 24h to
//   the previous day) is what keeps a 07:00 anchor at 07:00 across a DST
//   spring-forward: the zone offset moves, the wall clock does not.
//   The anchor clock mirrors the Today assembly (`today_providers.dart`): the
//   settings' anchor times drive the shipped hours (6, 12, 18 Angelus; 15 Hour
//   of Mercy) and any other anchor keeps its spec's own time.
// * **Sessions** — every enrolled pack WITHOUT a [TimeOfDaySpec] (commitments,
//   novenas, series) contributes one `'morningOf'` reminder per due session in
//   the horizon, at 07:00 local that morning. The body carries the pack's own
//   day ordinal (`'Day 6 of 9'` for a nine-day novena), a grace-window note
//   when the pack has a [GraceWindow] (e.g. the First Saturdays confession's
//   ±8 days), and the day's celebration name when the injected calendar seam
//   supplies that day with a NON-FERIAL celebration — a weekday-rank day in
//   the list is never appended, so a caller that feeds every horizon day (a
//   per-day calendar list) does not garnish every body with a ferial title.
//
// ## Settings gating (the Task 12 ruling: notification-only)
//
// The anchor toggles are the user's consent to be pinged, so they gate the
// planner's items (visibility on the Today screen is a separate, Task 13
// decision):
//
// * `enableAngelusAnchors` → the Angelus pack (id `angelus`, or an anchor
//   whose label/variants are `angelus` / `regina_caeli`), i.e. its three daily
//   anchors;
// * `enableMercyHourAnchor` → the Hour of Mercy (id `mercy_hour`, the
//   `mercy_hour` label, or the 15:00 convention the Today assembly also uses);
// * `nightItemsEnabled` (default OFF) → night items: an anchor at 20:00 or
//   later, before 04:00, or labelled `…night…`. A night item is gated by this
//   toggle ALONE, so enabling night items is the one explicit consent it
//   needs (the settings screen carries the off-by-default warning for it);
// * `morningReminderEnabled` / `eveningReminderEnabled` → the remaining
//   routine anchors, by the section they serve: before 17:00 (the Morning
//   Offering / morning routine) needs the morning reminder, from 17:00 on
//   (Examen / night prayers that are not night items) needs the evening one.
//   The Angelus and Mercy anchors are NOT re-gated by these: they have their
//   own toggles and are on by default.
//
// ## Rotation (Review Focus 1 + 3; the iOS ~64-pending cap)
//
// The candidate list is pruned to [maxPending] (60): the ids already scheduled
// on the device are PRESERVED (they stay in the plan even when they are beyond
// the nearest 60 candidates — cancelling and re-adding them would burn plugin
// writes for nothing), and the remaining slots go to the nearest upcoming
// candidates. The returned list is sorted by fire time (ties by id).
//
// ## Ids — deterministic, replace-not-duplicate
//
// An id names the LOGICAL notification, not the run:
//
// * anchors: `<packId>:anchor:<yyyy-MM-dd>T<HH:mm>` (the local wall clock in
//   [timeZoneName]);
// * sessions: `<packId>:session:<yyyy-MM-dd>`.
//
// The same inputs therefore produce byte-identical ids on every refresh point,
// which is what lets Task 18 diff pending → plan and write only the changes
// (an unchanged id means "already scheduled"; the same id with a changed fire
// time, body or title means "replace"). A notification whose fire DATE changes
// (the user moved an anchor time, a series start moved) legitimately gets a new
// id: it is a different occurrence, and the old id is dropped from the plan so
// the wiring cancels it.
//
// ## Inputs this planner deliberately does not read
//
// * The clock: [now] is the caller's frozen instant, read in [timeZoneName].
// * Progress: the pinned signature carries no `ProgressState`, so a
//   commitment's ordinal within its streak is not known here — the reminder
//   says "due today" plus the pack's grace-window note rather than inventing
//   a position. The Today screen (which has progress) shows the ordinal. And
//   a completed consecutive commitment STILL RESOLVES DUE (its
//   [ConsecutiveCommitmentSpec.resolve] is progress-free): the planner cannot
//   see the completion, so the caller must filter completed commitments out
//   of [packs] before calling [plan] — a Task 18 wiring requirement.
// * Per-day seasons: [upcomingFeasts] is the calendar seam, and only the days
//   it carries have a season key; on those days a season variant label
//   (`regina_caeli` in Eastertide) shapes the anchor body. A full per-day
//   season feed is a wiring decision (Task 18/24), not part of this signature.
library;

import 'package:sancta_via_devotional_engine/sancta_via_devotional_engine.dart';
import 'package:sancta_via_liturgical_calendar/sancta_via_liturgical_calendar.dart';
import 'package:timezone/timezone.dart' as tz;

import '../models/app_settings.dart';

/// One notification the planner wants scheduled.
///
/// [fireAt] is a `tz.TZDateTime` in the caller's zone (it satisfies
/// `DateTime`), so its `hour`/`minute` are the user's wall clock and its
/// `timeZoneOffset` is that date's offset — the DST-safe pair the plugin
/// schedules with. [packId] is the pack the item belongs to (always set: every
/// planned item names the program it serves).
class PlannedNotification {
  /// Creates a planned notification.
  const PlannedNotification({
    required this.id,
    required this.fireAt,
    required this.title,
    required this.body,
    required this.deepLink,
    required this.packId,
  });

  /// The deterministic logical id (see the library docs on the id scheme).
  final String id;

  /// The local instant to fire at, as a `tz.TZDateTime` of the caller's zone.
  final DateTime fireAt;

  /// The notification title (the pack's title).
  final String title;

  /// The notification body (the ordinal, grace-window note, celebration name).
  final String body;

  /// The route the tap opens (`/session/<packId>?forDate=yyyy-MM-dd`).
  final String deepLink;

  /// The pack the item belongs to.
  final String packId;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is PlannedNotification &&
            other.id == id &&
            other.fireAt.isAtSameMomentAs(fireAt) &&
            other.title == title &&
            other.body == body &&
            other.deepLink == deepLink &&
            other.packId == packId;
  }

  @override
  int get hashCode => Object.hash(
    id,
    fireAt.microsecondsSinceEpoch,
    title,
    body,
    deepLink,
    packId,
  );

  @override
  String toString() => 'PlannedNotification($id at $fireAt: $title — $body)';
}

/// The pure 60-day notification planner (see the library docs).
class NotificationPlanner {
  /// Creates a planner. The class is stateless, so a `const` instance serves
  /// every call.
  const NotificationPlanner();

  /// The iOS pending-notification budget the plan rotates through.
  static const int _maxPending = 60;

  /// The planning horizon, in days, from the caller's `now` (inclusive).
  static const int _horizonDays = 60;

  /// The `'morningOf'` session reminder hour (local).
  static const int _morningOfHour = 7;

  /// The most notifications one plan may carry (the rotation cap).
  int get maxPending => _maxPending;

  /// Plans the notifications for [now], in [timeZoneName], for the enrolled
  /// packs.
  ///
  /// * [now] — the caller's clock instant, read in [timeZoneName] to fix the
  ///   plan's first day. Candidates at or before it are dropped.
  /// * [timeZoneName] — an IANA zone name (`'America/New_York'`); the time-zone
  ///   database must be initialized by the caller (`initializeTimeZones`),
  ///   which the pure planner deliberately does not do behind the caller's back.
  /// * [packs] — the catalog (or any superset); ONLY packs present in
  ///   [enrollments] are planned.
  /// * [enrollments] — pack id → stored enrollment params. The params are not
  ///   read: a derived pack already carries its patched schedule (the Task 15
  ///   convention), so enrollment presence is the whole signal.
  /// * [upcomingFeasts] — the calendar seam: the days within the horizon whose
  ///   non-ferial celebration names belong in a body (a weekday-rank day in
  ///   the list never appends its name) and whose season key resolves
  ///   season-aware anchor labels on that day.
  /// * [settings] — the anchor times and the consent toggles (see the library
  ///   docs on gating).
  /// * [alreadyPending] — the ids currently scheduled on the device; ids that
  ///   survive the re-plan are preserved through the rotation cap.
  ///
  /// The result is unmodifiable, sorted by fire time (ties by id), and never
  /// longer than [maxPending]. Two calls with the same inputs return equal
  /// plans — the property Task 18's idempotent diff depends on.
  List<PlannedNotification> plan({
    required DateTime now,
    required String timeZoneName,
    required List<ContentPack> packs,
    required Map<String, Map<String, dynamic>> enrollments,
    required List<LiturgicalDayData> upcomingFeasts,
    required DevotionsAppSettings settings,
    required List<PlannedNotification> alreadyPending,
  }) {
    final tz.Location zone = tz.getLocation(timeZoneName);
    final tz.TZDateTime localNow = tz.TZDateTime.from(now, zone);
    // The plan's first calendar day, as date-only components. The UTC
    // scaffold is pure calendar arithmetic (never a zone rendering): adding
    // days here must not be able to skip or repeat one across a DST edge.
    final DateTime firstDay = DateTime.utc(
      localNow.year,
      localNow.month,
      localNow.day,
    );

    // The calendar seam, keyed by the local `yyyy-MM-dd` day it describes
    // (a DateTime would compare instants, and the seam's dates are
    // calendar dates).
    final Map<String, LiturgicalDayData> feastsByDay =
        <String, LiturgicalDayData>{
          for (final LiturgicalDayData day in upcomingFeasts)
            _stamp(_dateOnly(day.dateTime)): day,
        };

    final List<PlannedNotification> candidates = <PlannedNotification>[];

    for (final ContentPack pack in packs) {
      if (!enrollments.containsKey(pack.id)) {
        continue;
      }
      final bool isAnchorPack = pack.schedules.any(
        (ScheduleSpec spec) => spec is TimeOfDaySpec,
      );
      for (int offset = 0; offset < _horizonDays; offset++) {
        final DateTime day = DateTime.utc(
          firstDay.year,
          firstDay.month,
          firstDay.day + offset,
        );
        final LiturgicalDayData? feast = feastsByDay[_stamp(day)];
        final ScheduleContext context = ScheduleContext(
          seasonKeyValue: feast?.seasonKey,
        );

        if (!isAnchorPack) {
          // One reminder per pack per due day: the pack's FIRST due schedule
          // wins (the Today assembly's convention), so a pack with several
          // non-anchor schedules cannot produce two reminders an hour apart.
          for (final ScheduleSpec spec in pack.schedules) {
            final ScheduleResult resolution = spec.resolve(day, context);
            if (!resolution.due) {
              continue;
            }
            final tz.TZDateTime fireAt = tz.TZDateTime(
              zone,
              day.year,
              day.month,
              day.day,
              _morningOfHour,
              0,
            );
            if (fireAt.isAfter(now)) {
              candidates.add(
                PlannedNotification(
                  id: '${pack.id}:session:${_stamp(day)}',
                  fireAt: fireAt,
                  title: pack.title,
                  body: _sessionBody(
                    spec: spec,
                    resolution: resolution,
                    feast: feast,
                  ),
                  deepLink: _sessionLink(pack.id, day),
                  packId: pack.id,
                ),
              );
            }
            break;
          }
          continue;
        }

        for (final ScheduleSpec spec in pack.schedules) {
          if (spec is! TimeOfDaySpec) {
            continue;
          }
          if (!_anchorEnabled(pack: pack, spec: spec, settings: settings)) {
            continue;
          }
          final ScheduleResult resolution = spec.resolve(day, context);
          final ({int hour, int minute}) clock = _anchorClock(spec, settings);
          final tz.TZDateTime fireAt = tz.TZDateTime(
            zone,
            day.year,
            day.month,
            day.day,
            clock.hour,
            clock.minute,
          );
          if (!fireAt.isAfter(now)) {
            continue;
          }
          candidates.add(
            PlannedNotification(
              id:
                  '${pack.id}:anchor:${_stamp(day)}T'
                  '${_clockKey(clock.hour, clock.minute)}',
              fireAt: fireAt,
              title: pack.title,
              body: _anchorBody(pack, resolution),
              deepLink: _sessionLink(pack.id, day),
              packId: pack.id,
            ),
          );
        }
      }
    }

    return _rotate(candidates, alreadyPending);
  }

  /// Prunes [candidates] to the pending budget, preserving the ids already
  /// scheduled on the device (see the library docs on rotation).
  List<PlannedNotification> _rotate(
    List<PlannedNotification> candidates,
    List<PlannedNotification> alreadyPending,
  ) {
    final Map<String, PlannedNotification> unique =
        <String, PlannedNotification>{};
    for (final PlannedNotification candidate in candidates) {
      unique.putIfAbsent(candidate.id, () => candidate);
    }
    final List<PlannedNotification> sorted = unique.values.toList()
      ..sort(_byFireTime);

    final Set<String> pendingIds = <String>{
      for (final PlannedNotification pending in alreadyPending) pending.id,
    };
    final List<PlannedNotification> kept = <PlannedNotification>[];
    final List<PlannedNotification> fresh = <PlannedNotification>[];
    for (final PlannedNotification candidate in sorted) {
      if (pendingIds.contains(candidate.id)) {
        kept.add(candidate);
      } else {
        fresh.add(candidate);
      }
    }

    final int keptCount = kept.length < _maxPending ? kept.length : _maxPending;
    final int room = _maxPending - keptCount;
    final List<PlannedNotification> plan = <PlannedNotification>[
      ...kept.take(keptCount),
      ...fresh.take(room < 0 ? 0 : room),
    ]..sort(_byFireTime);
    return List<PlannedNotification>.unmodifiable(plan);
  }

  /// The plan's ordering: fire time first, then the deterministic id.
  static int _byFireTime(PlannedNotification a, PlannedNotification b) {
    final int byTime = a.fireAt.compareTo(b.fireAt);
    return byTime != 0 ? byTime : a.id.compareTo(b.id);
  }

  /// Whether [spec]'s anchor reminders are enabled for [pack] under
  /// [settings] (see the library docs on the gate map).
  static bool _anchorEnabled({
    required ContentPack pack,
    required TimeOfDaySpec spec,
    required DevotionsAppSettings settings,
  }) {
    final String? label = spec.baseLabel;
    final bool angelus =
        pack.id == 'angelus' ||
        label == 'angelus' ||
        spec.variants.any(
          (SeasonVariant variant) =>
              variant.variantId == 'angelus' ||
              variant.variantId == 'regina_caeli',
        );
    if (angelus) {
      return settings.enableAngelusAnchors;
    }
    final bool mercy =
        pack.id == 'mercy_hour' || label == 'mercy_hour' || spec.hour == 15;
    if (mercy) {
      return settings.enableMercyHourAnchor;
    }
    final bool night =
        spec.hour >= 20 ||
        spec.hour < 4 ||
        (label != null && label.contains('night'));
    if (night) {
      return settings.nightItemsEnabled;
    }
    return spec.hour < 17
        ? settings.morningReminderEnabled
        : settings.eveningReminderEnabled;
  }

  /// The anchor's local wall clock: the settings' time for the shipped anchor
  /// hours (6/12/18 Angelus, 15 Mercy — the Today assembly's own mapping),
  /// else the spec's authored time.
  static ({int hour, int minute}) _anchorClock(
    TimeOfDaySpec spec,
    DevotionsAppSettings settings,
  ) {
    switch (spec.hour) {
      case 6:
        return (
          hour: settings.angelusMorning.hour,
          minute: settings.angelusMorning.minute,
        );
      case 12:
        return (
          hour: settings.angelusNoon.hour,
          minute: settings.angelusNoon.minute,
        );
      case 15:
        return (
          hour: settings.mercyHour.hour,
          minute: settings.mercyHour.minute,
        );
      case 18:
        return (
          hour: settings.angelusEvening.hour,
          minute: settings.angelusEvening.minute,
        );
      default:
        return (hour: spec.hour, minute: spec.minute);
    }
  }

  /// The anchor body: the day's resolved label (season-aware when the calendar
  /// seam supplies the day), humanized — `'Regina Caeli'`, `'Mercy Hour'` —
  /// else the pack's title (the label is the pack's own authored vocabulary,
  /// never invented copy).
  static String _anchorBody(ContentPack pack, ScheduleResult resolution) {
    final List<String> labels = resolution.labels;
    if (labels.isEmpty || labels.first.isEmpty) {
      return pack.title;
    }
    return _humanizeLabel(labels.first);
  }

  /// The session body: the pack's day ordinal, then the pack's grace-window
  /// note and the day's celebration, joined with `' · '`.
  static String _sessionBody({
    required ScheduleSpec spec,
    required ScheduleResult resolution,
    required LiturgicalDayData? feast,
  }) {
    final String main = _positionLabel(spec, resolution) ?? 'Due today';
    final List<String> notes = <String>[];
    if (spec is ConsecutiveCommitmentSpec) {
      for (final GraceWindow window in spec.windows) {
        notes.add(_windowNote(window));
      }
    }
    if (feast != null && !feast.isWeekday) {
      notes.add(feast.displayName);
    }
    if (notes.isEmpty) {
      return main;
    }
    return '$main · ${notes.join(' · ')}';
  }

  /// `'Day 6 of 9'` for a dated session's resolved position, `'Day 6'` when
  /// the spec carries no length, or null when the resolution has no position
  /// (commitments and weekly loops — see the library docs).
  static String? _positionLabel(ScheduleSpec spec, ScheduleResult resolution) {
    final int? day = resolution.dayIndex;
    if (day == null) {
      return null;
    }
    final int? total = _seriesLength(spec);
    if (total == null || total <= 1) {
      return 'Day $day';
    }
    return 'Day $day of $total';
  }

  /// How many dated sessions [spec]'s window holds, when it says so.
  static int? _seriesLength(ScheduleSpec spec) {
    switch (spec) {
      case SessionSeriesSpec(:final int lengthDays):
        return lengthDays;
      case EasterOffsetSpec(:final int lengthDays):
        return lengthDays;
      case FixedDateSpec(
        :final int month,
        :final int day,
        :final int? untilMonth,
        :final int? untilDay,
      ):
        if (untilDay == null) {
          return null;
        }
        // Pure calendar arithmetic on a leap-year scaffold: the spec's own
        // windows never cross a year (the constructor refuses that).
        final DateTime start = DateTime.utc(2000, month, day);
        final DateTime end = DateTime.utc(2000, untilMonth ?? month, untilDay);
        return end.difference(start).inDays + 1;
      default:
        return null;
    }
  }

  /// The grace-window note of one [window], e.g. the First Saturdays
  /// confession: `'Confession may be made within 8 days before or after'`.
  static String _windowNote(GraceWindow window) {
    final String item = _capitalize(window.item);
    if (window.beforeDays == 0 && window.afterDays == 0) {
      return '$item is due that day';
    }
    if (window.beforeDays == window.afterDays) {
      return '$item may be made within ${_days(window.beforeDays)} before or '
          'after';
    }
    return '$item may be made from ${_days(window.beforeDays)} before to '
        '${_days(window.afterDays)} after';
  }

  /// `'1 day'` / `'8 days'`.
  static String _days(int count) => count == 1 ? '1 day' : '$count days';

  /// The first character of [text] upper-cased (`'confession'` →
  /// `'Confession'`).
  static String _capitalize(String text) {
    if (text.isEmpty) {
      return text;
    }
    return '${text[0].toUpperCase()}${text.substring(1)}';
  }

  /// Humanizes an authored label: underscores/hyphens become word breaks and
  /// each word is capitalized (`'regina_caeli'` → `'Regina Caeli'`).
  static String _humanizeLabel(String label) {
    final List<String> words = label
        .split(RegExp(r'[_\-]+'))
        .where((String word) => word.isNotEmpty)
        .toList();
    if (words.isEmpty) {
      return label;
    }
    return words.map(_capitalize).join(' ');
  }

  /// The session route the Today screen's tiles also carry.
  static String _sessionLink(String packId, DateTime day) =>
      '/session/$packId?forDate=${_stamp(day)}';

  /// Reduces [d] to its calendar date (local midnight construction).
  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  /// The zero-padded `yyyy-MM-dd` rendering of a calendar date.
  static String _stamp(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  /// The zero-padded `HH:mm` rendering of a wall clock.
  static String _clockKey(int hour, int minute) =>
      '${hour.toString().padLeft(2, '0')}:'
      '${minute.toString().padLeft(2, '0')}';
}
