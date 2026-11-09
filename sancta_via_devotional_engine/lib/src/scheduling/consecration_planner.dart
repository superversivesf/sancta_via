/// Consecration-day planning: the start date of a 33-day preparation ended
/// by a consecration day.
///
/// The classic Marian consecration programs prepare with 33 days of
/// sessions and crown them on day 34, the consecration day itself: day 1
/// is [ConsecrationPlanner.startFor]'s result, 33 calendar days before the
/// consecration day, and day 34 is the consecration day. The planner is
/// pinned to the engine's date-only discipline: it reads only the local
/// calendar components of its input — never string parsing, never UTC
/// components — and returns a local midnight date.
library;

/// Reduces [d] to a local midnight date (a `DateTime(year, month, day)`
/// construction), preserving the local calendar components.
DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Computes the start of a 33-day preparation before a consecration day.
class ConsecrationPlanner {
  /// Day 1 of the preparation ending on [consecrationDay]: 33 calendar
  /// days before it (day 34, the consecration day, is [consecrationDay]
  /// itself).
  ///
  /// Only the local calendar components of [consecrationDay] participate;
  /// the day arithmetic is done in calendar components (the `DateTime`
  /// constructor normalizes the rolled-over day, e.g. `day − 33` landing
  /// in the previous month) rather than on instants, so a DST transition
  /// inside the 33-day span can never displace the intended calendar day,
  /// and the result is a local midnight date.
  static DateTime startFor(DateTime consecrationDay) {
    final DateTime d = _dateOnly(consecrationDay);
    return DateTime(d.year, d.month, d.day - 33);
  }
}
