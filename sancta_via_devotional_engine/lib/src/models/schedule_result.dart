/// The outcome of resolving a devotional schedule for a calendar date.
///
/// A [ScheduleResult] records whether a session is due ([due]) and, when
/// relevant, the position of that date within the program it belongs to.
library;

/// The outcome of resolving a devotional schedule for a calendar date.
class ScheduleResult {
  /// Whether a devotional session is due on the resolved date.
  final bool due;

  /// The 1-based position of the resolved date within a series or window
  /// (e.g. day 3 of a November 1-8 novena), or null when the resolution
  /// carries no window position.
  final int? dayIndex;

  /// The 1-based ordinal of the fulfilled commitment within the program
  /// (e.g. the 7th of a 9-day novena), or null when no commitment has been
  /// fulfilled.
  final int? ordinal;

  /// Free-form display labels attached to the resolved session.
  final List<String> labels;

  /// Creates a [ScheduleResult].
  const ScheduleResult({
    required this.due,
    this.dayIndex,
    this.ordinal,
    this.labels = const [],
  });

  @override
  String toString() =>
      'ScheduleResult(due: $due, dayIndex: $dayIndex, ordinal: $ordinal, '
      'labels: $labels)';
}
