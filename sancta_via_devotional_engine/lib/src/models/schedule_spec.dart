/// Schedule specifications: declarative rules deciding when a devotional
/// session is due.
///
/// A schedule specification resolves against a calendar date and a
/// [ScheduleContext], producing a [ScheduleResult]. Resolution follows a
/// pinned date-only discipline: the date's LOCAL calendar components are the
/// only meaningful date information, obtained through `DateTime(year, month,
/// day)` construction — never by parsing strings and never through UTC
/// components (see [ScheduleSpec._dateOnly]).
///
/// Because the base class is `sealed`, the spec implementations live in this
/// same library; Dart requires subclasses of a sealed class to share its
/// library.
library;

import '../scheduling/computus.dart';
import 'schedule_context.dart';
import 'schedule_result.dart';

/// Counts whole calendar days between local midnight date-only values,
/// immune to DST shifts.
///
/// Local instants spanning a DST transition are not exact multiples of 24
/// hours apart, so `Duration.inDays` on their difference truncates to the
/// wrong day count (e.g. a 8-calendar-day window across one "spring
/// forward".) The two calendar dates are re-anchored to UTC midnights purely
/// as a DST-free difference backbone; the calendar values themselves remain
/// the local year/month/day of the inputs, never UTC components.
int _wholeCalendarDays(DateTime start, DateTime end) {
  return DateTime.utc(
    end.year,
    end.month,
    end.day,
  ).difference(DateTime.utc(start.year, start.month, start.day)).inDays;
}

/// Base class for devotional schedule specifications.
///
/// A [ScheduleSpec] is resolved against a calendar date and a
/// [ScheduleContext]; resolution answers with a [ScheduleResult] recording
/// whether a session is due that day and, if relevant, the position of the
/// day within the spec's window.
sealed class ScheduleSpec {
  /// Creates a [ScheduleSpec].
  const ScheduleSpec();

  /// Resolves this specification against [date] with [context].
  ///
  /// Only the local calendar components of [date] participate in
  /// resolution: [date] must carry, and resolution must read, the date in
  /// the caller's local calendar — never its UTC rendering.
  ScheduleResult resolve(DateTime date, ScheduleContext context);

  /// Normalizes [d] to a local midnight date (a `DateTime(year, month, day)`
  /// construction), preserving the local calendar components.
  ///
  /// This is the single entry point through which resolution reads a date:
  /// it never parses strings and never derives the calendar from UTC
  /// components, so a UTC-midnight-constructed input resolves as its
  /// local-shifted calendar self rather than as the UTC-rendered day.
  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
}

/// A schedule due on one fixed calendar date each year, or on every day of a
/// fixed inclusive date window each year.
///
/// Single-date form: [month] and [day] only — e.g.
/// `FixedDateSpec(12, 17)` is due every December 17.
///
/// Window form: additionally an inclusive end, given as [untilMonth] and
/// [untilDay] together (e.g. `FixedDateSpec(11, 1, untilMonth: 11,
/// untilDay: 8)`), or as [untilDay] alone for a same-month window (e.g.
/// `FixedDateSpec(11, 1, untilDay: 8)`). On a due date the resolution
/// carries the window's 1-based [ScheduleResult.dayIndex].
class FixedDateSpec extends ScheduleSpec {
  /// The starting month of the feast or window (1 through 12).
  final int month;

  /// The starting day of the feast or window.
  final int day;

  /// The ending month of the window, or null for a single-date spec. When
  /// null while [untilDay] is set, the window ends within [month] itself.
  final int? untilMonth;

  /// The ending day of the window (inclusive), or null for a single-date
  /// spec.
  final int? untilDay;

  /// Creates a [FixedDateSpec].
  ///
  /// Throws an [ArgumentError] when [month] or [day] is outside the
  /// calendar, when exactly one of [untilMonth] and [untilDay] is provided
  /// (a window is defined by both, or by [untilDay] alone), when the window
  /// end precedes the window start, or when the end would cross into a
  /// different year (cross-year windows are not supported; anchor moving
  /// windows with [EasterOffsetSpec] instead).
  FixedDateSpec(this.month, this.day, {this.untilMonth, this.untilDay}) {
    final List<String> problems = <String>[];
    final int? endMonth = untilMonth;
    final int? endDay = untilDay;
    if (month < 1 || month > 12) {
      problems.add('month must be between 1 and 12');
    }
    if (day < 1 || day > 31) {
      problems.add('day must be between 1 and 31');
    }
    if (endMonth != null && endDay == null) {
      problems.add('untilDay must be provided when untilMonth is given');
    }
    if (endMonth != null && (endMonth < 1 || endMonth > 12)) {
      problems.add('untilMonth must be between 1 and 12');
    }
    if (endDay != null && (endDay < 1 || endDay > 31)) {
      problems.add('untilDay must be between 1 and 31');
    }
    if (problems.isEmpty && endMonth != null) {
      // The window end must fall on or after the start within the same
      // year, so the spec stays a recurring same-year feast or window.
      final DateTime scaffoldStart = DateTime(2000, month, day);
      final DateTime scaffoldEnd = DateTime(2000, endMonth, endDay ?? day);
      if (scaffoldEnd.isBefore(scaffoldStart)) {
        problems.add(
          'window end must not precede the window start '
          '(cross-year windows are not supported)',
        );
      }
    }
    if (problems.isNotEmpty) {
      throw ArgumentError(
        'FixedDateSpec($month, $day) failed validation: '
        '${problems.join('; ')}',
      );
    }
  }

  @override
  ScheduleResult resolve(DateTime date, ScheduleContext context) {
    final DateTime d = ScheduleSpec._dateOnly(date);
    final int? endDay = untilDay;
    if (endDay == null) {
      return ScheduleResult(due: d.month == month && d.day == day);
    }
    final DateTime start = DateTime(d.year, month, day);
    final DateTime end = DateTime(d.year, untilMonth ?? month, endDay);
    if (d.isBefore(start) || d.isAfter(end)) {
      return const ScheduleResult(due: false);
    }
    return ScheduleResult(
      due: true,
      dayIndex: _wholeCalendarDays(start, d) + 1,
    );
  }

  @override
  String toString() =>
      'FixedDateSpec(month: $month, day: $day, untilMonth: $untilMonth, '
      'untilDay: $untilDay)';
}

/// A schedule due on every day of an inclusive window anchored to Easter
/// Sunday of the resolved date's own year.
///
/// The window starts [startOffset] whole calendar days after Easter Sunday
/// (negative offsets start before Easter) and runs [lengthDays] days: due
/// dates are Easter + startOffset through Easter + startOffset +
/// lengthDays - 1, inclusive. E.g. `EasterOffsetSpec(-2, 9)` — the Divine
/// Mercy Novena — is due from Good Friday through the ninth day; it spans
/// years only at that two-day edge, which never crosses a year boundary,
/// so resolution always uses Easter of the date's own year.
class EasterOffsetSpec extends ScheduleSpec {
  /// Whole calendar days between Easter Sunday and the window's start
  /// (negative for days before Easter).
  final int startOffset;

  /// The number of due days in the window (at least 1).
  final int lengthDays;

  /// Creates an [EasterOffsetSpec].
  ///
  /// Throws an [ArgumentError] when [lengthDays] is less than 1.
  EasterOffsetSpec(this.startOffset, this.lengthDays) {
    if (lengthDays < 1) {
      throw ArgumentError.value(lengthDays, 'lengthDays', 'must be at least 1');
    }
  }

  @override
  ScheduleResult resolve(DateTime date, ScheduleContext context) {
    final DateTime d = ScheduleSpec._dateOnly(date);
    final DateTime easter = easterSundayFor(d.year);
    // The DateTime constructor normalizes rolled-over components (e.g. a
    // startOffset carrying the window start past a month boundary), keeping
    // every value a local midnight date.
    final DateTime start = DateTime(
      easter.year,
      easter.month,
      easter.day + startOffset,
    );
    final DateTime end = DateTime(
      easter.year,
      easter.month,
      easter.day + startOffset + lengthDays - 1,
    );
    if (d.isBefore(start) || d.isAfter(end)) {
      return const ScheduleResult(due: false);
    }
    return ScheduleResult(
      due: true,
      dayIndex: _wholeCalendarDays(start, d) + 1,
    );
  }

  @override
  String toString() =>
      'EasterOffsetSpec(startOffset: $startOffset, lengthDays: $lengthDays)';
}

/// A schedule due on the [nth] occurrence of [weekday] within the calendar
/// month of each resolved date, recurring in every month.
///
/// [weekday] is numbered as `DateTime` numbers weekdays:
/// [DateTime.monday] = 1 through [DateTime.sunday] = 7. Resolution computes
/// the due day by starting at the month's first day, advancing to the first
/// occurrence of [weekday], and adding (nth − 1) whole weeks; the resulting
/// day must still fall inside the month. When the month holds fewer than
/// [nth] occurrences — e.g. a four-week February 2026 has no fifth Sunday —
/// the spec is simply not due that month: the occurrence is never rolled
/// into the following month, nor invented.
class NthWeekdayOfMonthSpec extends ScheduleSpec {
  /// The weekday of the due occurrence, numbered as `DateTime` numbers
  /// weekdays: [DateTime.monday] = 1 through [DateTime.sunday] = 7.
  final int weekday;

  /// The 1-based occurrence of [weekday] within the month (e.g. 2 for the
  /// second Saturday).
  final int nth;

  /// Creates a [NthWeekdayOfMonthSpec].
  ///
  /// Throws an [ArgumentError] when [weekday] is outside 1 (Monday)
  /// through 7 (Sunday) or when [nth] is less than 1.
  NthWeekdayOfMonthSpec(this.weekday, this.nth) {
    final List<String> problems = <String>[];
    if (weekday < DateTime.monday || weekday > DateTime.sunday) {
      problems.add('weekday must be between 1 (Monday) and 7 (Sunday)');
    }
    if (nth < 1) {
      problems.add('nth must be at least 1');
    }
    if (problems.isNotEmpty) {
      throw ArgumentError(
        'NthWeekdayOfMonthSpec($weekday, $nth) failed validation: '
        '${problems.join('; ')}',
      );
    }
  }

  @override
  ScheduleResult resolve(DateTime date, ScheduleContext context) {
    final DateTime d = ScheduleSpec._dateOnly(date);
    // The weekday of the month's first day (DateTime.monday..sunday);
    // Dart's % on a possibly negative left operand is non-negative, so the
    // offset lands in 0..6.
    final int firstWeekday = DateTime(d.year, d.month, 1).weekday;
    final int offsetToFirst = (weekday - firstWeekday) % 7;
    final int targetDay = 1 + offsetToFirst + (nth - 1) * 7;
    // Day 0 of the following month rolls back to this month's last day.
    final int daysInMonth = DateTime(d.year, d.month + 1, 0).day;
    if (targetDay > daysInMonth) {
      return const ScheduleResult(due: false);
    }
    return ScheduleResult(due: d.day == targetDay);
  }

  @override
  String toString() => 'NthWeekdayOfMonthSpec(weekday: $weekday, nth: $nth)';
}

/// A schedule due every week on each of the listed weekdays, recurring in
/// every month, with optional whole-month suppression.
///
/// [weekday]s are numbered as `DateTime` numbers weekdays:
/// [DateTime.monday] = 1 through [DateTime.sunday] = 7. The spec is due when
/// the resolved date's own weekday appears in [weekdays] — e.g.
/// `WeeklyLoopSpec(weekdays: {DateTime.tuesday})` is due every Tuesday.
///
/// When [skipMonths] is provided and non-empty, the resolved date's month
/// appearing in it suppresses the spec for that entire month: even a listed
/// weekday in a skipped month resolves as not due. Suppression is
/// deliberately month-scoped only; finer-grained displacements in v1 — such
/// as a solemnity displacing a weekday devotional — are the caller's
/// concern (driven by the [ScheduleContext.seasonKeyValue] label outside
/// the engine), which is why [resolve] does not consult the context.
class WeeklyLoopSpec extends ScheduleSpec {
  /// The weekdays on which the loop is due, numbered as `DateTime` numbers
  /// weekdays: [DateTime.monday] = 1 through [DateTime.sunday] = 7.
  final Set<int> weekdays;

  /// The months (1 through 12) in which the loop is suppressed for the
  /// whole month, or null / empty for no suppression.
  final List<int>? skipMonths;

  /// Creates a [WeeklyLoopSpec].
  ///
  /// Throws an [ArgumentError] when [weekdays] is empty or holds a value
  /// outside 1 (Monday) through 7 (Sunday), or when [skipMonths] holds a
  /// value outside 1 through 12. [skipMonths] itself may be null or empty.
  WeeklyLoopSpec({required this.weekdays, this.skipMonths}) {
    final List<String> problems = <String>[];
    if (weekdays.isEmpty) {
      problems.add('weekdays must not be empty');
    }
    if (weekdays.any(
      (int weekday) => weekday < DateTime.monday || weekday > DateTime.sunday,
    )) {
      problems.add('weekdays must each be between 1 (Monday) and 7 (Sunday)');
    }
    final List<int>? skip = skipMonths;
    if (skip != null && skip.any((int month) => month < 1 || month > 12)) {
      problems.add('skipMonths must each be between 1 and 12');
    }
    if (problems.isNotEmpty) {
      throw ArgumentError(
        'WeeklyLoopSpec(weekdays: $weekdays, skipMonths: $skipMonths) '
        'failed validation: ${problems.join('; ')}',
      );
    }
  }

  @override
  ScheduleResult resolve(DateTime date, ScheduleContext context) {
    final DateTime d = ScheduleSpec._dateOnly(date);
    final List<int>? skip = skipMonths;
    if (skip != null && skip.contains(d.month)) {
      return const ScheduleResult(due: false);
    }
    return ScheduleResult(due: weekdays.contains(d.weekday));
  }

  @override
  String toString() =>
      'WeeklyLoopSpec(weekdays: $weekdays, skipMonths: $skipMonths)';
}

/// A schedule due every day at a fixed local wall-clock time, carrying a
/// display label that season variants can re-shape.
///
/// The spec is due on every resolved date ([hour] 0 through 23, [minute] 0
/// through 59 — resolution reads only the local calendar of the date, never
/// a time-zone rendering; the caller schedules the wall-clock reminder).
///
/// The resolution's label is, in order of preference:
///
/// 1. The `variantId` of the first [variants] entry matching the
///    resolution — matching either by month or by season.
/// 2. [baseLabel], when provided.
/// 3. The zero-padded `HH:mm` rendering of [hour] and [minute] (e.g.
///    `TimeOfDaySpec(15, 0)` labels itself `'15:00'`, `TimeOfDaySpec(6, 0)`
///    labels itself `'06:00'`).
///
/// E.g. the Angelus devotional can carry
/// `TimeOfDaySpec(6, 0, baseLabel: 'angelus', variants: [SeasonVariant(
/// months: [4, 5], seasons: {'eastertide'}, variantId: 'regina_caeli')])`,
/// resolving as `regina_caeli` during Eastertide and `angelus` elsewhere.
class TimeOfDaySpec extends ScheduleSpec {
  /// The hour of the fixed local wall-clock time (0 through 23).
  final int hour;

  /// The minute of the fixed local wall-clock time (0 through 59).
  final int minute;

  /// The label used when no [SeasonVariant] in [variants] matches the
  /// resolution, or null to fall through to the `HH:mm` rendering.
  final String? baseLabel;

  /// Season-scoped label variants, tried in order; the first match wins.
  final List<SeasonVariant> variants;

  /// Creates a [TimeOfDaySpec].
  ///
  /// Throws an [ArgumentError] when [hour] is outside 0 through 23 or
  /// [minute] is outside 0 through 59.
  TimeOfDaySpec(
    this.hour,
    this.minute, {
    this.baseLabel,
    this.variants = const <SeasonVariant>[],
  }) {
    final List<String> problems = <String>[];
    if (hour < 0 || hour > 23) {
      problems.add('hour must be between 0 and 23');
    }
    if (minute < 0 || minute > 59) {
      problems.add('minute must be between 0 and 59');
    }
    if (problems.isNotEmpty) {
      throw ArgumentError(
        'TimeOfDaySpec($hour, $minute) failed validation: '
        '${problems.join('; ')}',
      );
    }
  }

  @override
  ScheduleResult resolve(DateTime date, ScheduleContext context) {
    final DateTime d = ScheduleSpec._dateOnly(date);
    return ScheduleResult(due: true, labels: <String>[_labelFor(d, context)]);
  }

  /// The label carried by a resolution of the date-only [d]: the
  /// `variantId` of the first matching [variants] entry, else [baseLabel],
  /// else the `HH:mm` rendering of this spec's time.
  String _labelFor(DateTime d, ScheduleContext context) {
    final String? seasonKey = context.seasonKeyValue;
    for (final SeasonVariant variant in variants) {
      if (variant.months.contains(d.month)) {
        return variant.variantId;
      }
      final Set<String>? seasons = variant.seasons;
      if (seasons != null &&
          seasonKey != null &&
          seasonKey.isNotEmpty &&
          seasons.any(
            (String season) => season.toLowerCase() == seasonKey.toLowerCase(),
          )) {
        return variant.variantId;
      }
    }
    return baseLabel ?? _clockLabel(hour, minute);
  }

  /// Zero-pads the time into a stable `HH:mm` label.
  static String _clockLabel(int hour, int minute) =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  @override
  String toString() =>
      'TimeOfDaySpec(hour: $hour, minute: $minute, baseLabel: $baseLabel, '
      'variants: $variants)';
}

/// A season-scoped display variant of a [TimeOfDaySpec].
///
/// A variant matches a resolution when its [months] include the resolved
/// date's local month OR its [seasons] contain the resolution's
/// [ScheduleContext.seasonKeyValue] (compared case-insensitively on both
/// sides). A [TimeOfDaySpec] tries its variants in order and the first
/// match's `variantId` becomes the resolution's label.
///
/// At least one match source must exist: [months] non-empty or [seasons]
/// non-empty and non-null — a variant with neither could never match.
class SeasonVariant {
  /// The months (1 through 12) in which the variant may apply, by the
  /// resolved date's local month. May be empty when the variant is keyed
  /// purely by [seasons].
  final List<int> months;

  /// The season keys under which the variant applies, or null when the
  /// variant is keyed purely by [months]. Compared case-insensitively
  /// against the resolution's season key.
  final Set<String>? seasons;

  /// The label this variant substitutes into the resolution when it
  /// matches.
  final String variantId;

  /// Creates a [SeasonVariant].
  ///
  /// Throws an [ArgumentError] when [months] holds a value outside 1
  /// through 12, when [variantId] is empty, or when both [months] and
  /// [seasons] are empty (the variant could never match).
  SeasonVariant({required this.months, this.seasons, required this.variantId}) {
    final List<String> problems = <String>[];
    if (months.any((int month) => month < 1 || month > 12)) {
      problems.add('months must each be between 1 and 12');
    }
    final Set<String>? variantSeasons = seasons;
    if (months.isEmpty && (variantSeasons == null || variantSeasons.isEmpty)) {
      problems.add(
        'at least one month or one season key must be provided '
        '(otherwise the variant can never match)',
      );
    }
    if (variantId.isEmpty) {
      problems.add('variantId must not be empty');
    }
    if (problems.isNotEmpty) {
      throw ArgumentError(
        'SeasonVariant(months: $months, variantId: $variantId) '
        'failed validation: ${problems.join('; ')}',
      );
    }
  }

  @override
  String toString() =>
      'SeasonVariant(months: $months, seasons: $seasons, '
      'variantId: $variantId)';
}

/// How a consecutive commitment's fulfilled ordinals react to a gap: an
/// anchor position in the series that was not completed.
enum RestartPolicy {
  /// A gap voids the series: the fulfilled ordinals count only from the
  /// last gap onward — e.g. a skipped First Saturday unbinds every First
  /// Saturday completed before it, and the series visibly restarts (the
  /// missed anchor itself is labelled in the evaluated state either way).
  strict,

  /// Ordinals continue across a gap (e.g. a program restarted after a
  /// lapse without voiding earlier completions); the gap itself is never
  /// swallowed — the evaluated `CommitmentState` labels every missed
  /// anchor.
  permissive,
}

/// Item-level grace for a consecutive commitment: a permission for one
/// item of the devotion to be completed within a whole-calendar-day window
/// around an anchor date and still count for that anchor.
///
/// The classic case is the First Saturday devotion's confession, which may
/// be made within 8 days before or after the First Saturday:
/// `GraceWindow(item: 'confession', beforeDays: 8, afterDays: 8)`.
///
/// The window is date-diff based and reads only local calendar dates: it
/// compares whole calendar days between the two dates (see
/// [_wholeCalendarDays]), so it is immune to DST shifts and never consults
/// a time-zone rendering.
class GraceWindow {
  /// The devotion item the window grants grace for (e.g. `'confession'`).
  ///
  /// The engine's progress evaluation compares completion dates only; the
  /// item key documents which item's completions the window governs.
  final String item;

  /// How many whole calendar days before the anchor date the window opens
  /// (inclusive; 0 admits the anchor day itself on the before side).
  final int beforeDays;

  /// How many whole calendar days after the anchor date the window closes
  /// (inclusive; 0 admits the anchor day itself on the after side).
  final int afterDays;

  /// Creates a [GraceWindow].
  ///
  /// Throws an [ArgumentError] when [item] is empty or when [beforeDays]
  /// or [afterDays] is negative.
  GraceWindow({
    required this.item,
    required this.beforeDays,
    required this.afterDays,
  }) {
    final List<String> problems = <String>[];
    if (item.isEmpty) {
      problems.add('item must not be empty');
    }
    if (beforeDays < 0) {
      problems.add('beforeDays must not be negative');
    }
    if (afterDays < 0) {
      problems.add('afterDays must not be negative');
    }
    if (problems.isNotEmpty) {
      throw ArgumentError(
        'GraceWindow(item: $item, beforeDays: $beforeDays, '
        'afterDays: $afterDays) failed validation: '
        '${problems.join('; ')}',
      );
    }
  }

  /// Whether a completion dated [completed] admits the anchor dated
  /// [anchor]: true when [completed] lies within [beforeDays] days before
  /// through [afterDays] days after [anchor], both edges inclusive.
  ///
  /// Only the local calendar components of the two dates participate: the
  /// difference is taken in whole calendar days between date-only values,
  /// never from time-of-day or UTC renderings.
  bool admits(DateTime anchor, DateTime completed) {
    final int days = _wholeCalendarDays(anchor, completed);
    return days >= -beforeDays && days <= afterDays;
  }

  @override
  String toString() =>
      'GraceWindow(item: $item, beforeDays: $beforeDays, '
      'afterDays: $afterDays)';
}

/// A consecutive commitment: a program of [count] fulfillments of the same
/// recurring [anchor] spec (e.g. the Five First Saturdays, anchored to
/// `NthWeekdayOfMonthSpec(DateTime.saturday, 1)`), evaluated against a
/// person's completion dates by the `CommitmentState` evaluator in
/// `src/progress/commitment_state.dart`.
///
/// Resolution of the commitment is the anchor's own resolution: the
/// commitment is due wherever its anchor is due. Completion-aware state —
/// the fulfilled ordinals, series restarts, gap labels, and the next
/// fulfillment position — is the `CommitmentState.evaluate` concern, and
/// the [policy] decides how a missed anchor (a gap) affects the ordinals:
/// [RestartPolicy.strict] restarts the series at the last gap,
/// [RestartPolicy.permissive] continues across it with the gap labelled.
/// Either way, a missed anchor never silently rolls the ordinals forward.
class ConsecutiveCommitmentSpec extends ScheduleSpec {
  /// The per-position spec the program recurs on (e.g. the First Saturday
  /// of every month).
  final ScheduleSpec anchor;

  /// The number of fulfillments the program asks for (e.g. 5 or 9).
  ///
  /// Evaluation does not stop at [count] — callers compare
  /// `CommitmentState.fulfilledOrdinals` with it.
  final int count;

  /// How fulfilled ordinals react to a gap in the series.
  final RestartPolicy policy;

  /// Item-level grace windows admitting completions made near an anchor
  /// date (e.g. a confession within 8 days of the First Saturday), or
  /// empty for exact-anchor-date completion only.
  final List<GraceWindow> windows;

  /// Creates a [ConsecutiveCommitmentSpec].
  ///
  /// Throws an [ArgumentError] when [count] is below 1.
  ConsecutiveCommitmentSpec({
    required this.anchor,
    required this.count,
    required this.policy,
    this.windows = const <GraceWindow>[],
  }) {
    if (count < 1) {
      throw ArgumentError(
        'ConsecutiveCommitmentSpec(count: $count) failed validation: '
        'count must be at least 1',
      );
    }
  }

  @override
  ScheduleResult resolve(DateTime date, ScheduleContext context) {
    return anchor.resolve(date, context);
  }

  @override
  String toString() =>
      'ConsecutiveCommitmentSpec(anchor: $anchor, count: $count, '
      'policy: $policy, windows: $windows)';
}
