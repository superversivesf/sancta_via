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
