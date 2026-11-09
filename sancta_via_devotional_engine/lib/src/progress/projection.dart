/// Projection of the remaining anchor dates of a consecutive commitment.
///
/// [Projection.remainingDates] enumerates, forward from a given date, the
/// anchor dates a [ConsecutiveCommitmentSpec]'s remaining fulfillments can
/// fall on. It is pinned to the same date-only discipline as evaluation
/// (`CommitmentState.evaluate`): `from` and the projected dates are
/// reduced to local midnight calendar dates (`DateTime(year, month, day)`),
/// anchor dates are derived by walking the calendar day by day out of the
/// spec's own anchor, and every comparison reads local calendar components
/// — never a UTC rendering.
library;

import '../models/schedule_context.dart';
import '../models/schedule_spec.dart';

/// Reduces [d] to a local midnight date (a `DateTime(year, month, day)`
/// construction), preserving the local calendar components.
DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Projects a [ConsecutiveCommitmentSpec]'s remaining anchor dates.
class Projection {
  /// The anchor dates the program's remaining fulfillments fall on:
  /// walking [spec]'s anchor dates forward from [from] (inclusive), the
  /// next `count − fulfilledOrdinals` of them.
  ///
  /// [fulfilledOrdinals] is the progress already made — e.g. the
  /// `fulfilledOrdinals` of the `CommitmentState.evaluate` state as of the
  /// caller's today. The fulfilled anchor dates lie before the walk
  /// opens, and the projection enumerates the positions the remaining
  /// fulfillments can take. An anchor falling on [from] itself is a
  /// remaining position (it is still completable that day; pass the day
  /// after a fulfilled anchor date to exclude it).
  ///
  /// The list is empty once [fulfilledOrdinals] has reached
  /// [ConsecutiveCommitmentSpec.count]: the program is complete and
  /// stable, and nothing remains.
  ///
  /// Only the local calendar components of [from] participate
  /// ([_dateOnly]); time-of-day never leaks into the projection, and the
  /// projected dates are local midnight dates. The internal walk consults
  /// a default [ScheduleContext] (anchor due-ness does not depend on the
  /// season), matching the anchor-spec derivation `CommitmentState.evaluate`
  /// applies.
  static List<DateTime> remainingDates(
    ConsecutiveCommitmentSpec spec,
    int fulfilledOrdinals,
    DateTime from,
  ) {
    if (fulfilledOrdinals >= spec.count) {
      return const <DateTime>[];
    }
    final int remaining = spec.count - fulfilledOrdinals;
    final List<DateTime> dates = <DateTime>[];
    const ScheduleContext context = ScheduleContext();
    for (
      DateTime d = _dateOnly(from);
      dates.length < remaining;
      d = DateTime(d.year, d.month, d.day + 1)
    ) {
      if (spec.anchor.resolve(d, context).due) {
        dates.add(d);
      }
    }
    return dates;
  }
}
