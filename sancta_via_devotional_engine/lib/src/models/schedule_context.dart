/// Resolution context supplied by the caller of a schedule resolution.
///
/// This is a dependency-free stand-in for liturgical-calendar context:
/// [ScheduleContext.seasonKeyValue] carries the key of the liturgical season
/// of the date being resolved (e.g. `'lent'`). When the devotional engine's
/// foundation plan wires the sibling calendar package (Task 8), this value
/// maps to `LiturgicalDayData.seasonKey` from
/// `sancta_via_liturgical_calendar`; until then the engine remains free of
/// package dependencies.
library;

/// Resolution context describing, minimally, the liturgical season of the
/// date being resolved.
class ScheduleContext {
  /// The key of the liturgical season of the resolved date, or null when the
  /// caller has no liturgical-calendar data for that date.
  final String? seasonKeyValue;

  /// Creates a [ScheduleContext].
  const ScheduleContext({this.seasonKeyValue});

  @override
  String toString() => 'ScheduleContext(seasonKeyValue: $seasonKeyValue)';
}
