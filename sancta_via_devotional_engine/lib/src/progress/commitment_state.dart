/// Progress of a consecutive commitment against a person's completion
/// dates: the fulfilled ordinals, the last fulfilled anchor, gap labels,
/// and the next fulfillment position.
///
/// Evaluation ([CommitmentState.evaluate]) is pinned to the same date-only
/// discipline as resolution: completion dates and `today` are reduced to
/// local midnight calendar dates (`DateTime(year, month, day)`), anchor
/// dates are derived by walking the calendar day by day, and every
/// comparison reads local calendar components — never a UTC rendering.
library;

import '../models/schedule_context.dart';
import '../models/schedule_spec.dart';

/// Reduces [d] to a local midnight date (a `DateTime(year, month, day)`
/// construction), preserving the local calendar components.
DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// The zero-padded `yyyy-mm-dd` rendering of a local date, for gap labels.
String _stamp(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// Whether the anchor dated [anchor] counts as fulfilled against the
/// completions in [completed]: the anchor date itself completed, or some
/// completion date one of [windows] admits (item-level grace, e.g. a
/// confession made within 8 days of the First Saturday).
bool _fulfilled(
  DateTime anchor,
  Set<DateTime> completed,
  List<GraceWindow> windows,
) {
  if (completed.contains(anchor)) {
    return true;
  }
  for (final GraceWindow window in windows) {
    for (final DateTime completedOn in completed) {
      if (window.admits(anchor, completedOn)) {
        return true;
      }
    }
  }
  return false;
}

/// The progress of a [ConsecutiveCommitmentSpec] against a person's
/// completion dates.
class CommitmentState {
  /// How many consecutive positions of the program have been fulfilled,
  /// under the spec's [RestartPolicy]: the count of the current series
  /// since the last gap (strict), or the count of every fulfilled anchor
  /// spanned, gap or not, continuing across gaps (permissive).
  final int fulfilledOrdinals;

  /// The most recently fulfilled anchor date in the evaluation span
  /// (independent of policy), or null when no anchor in the span counts as
  /// fulfilled.
  final DateTime? lastFulfilledAnchor;

  /// One label per anchor position in the span that was NOT fulfilled
  /// (e.g. `'gap: 2026-12-05'`), under either policy — a missed anchor is
  /// never silently rolled forward: strict reflects it by restarting the
  /// ordinals, permissive by continuing across it, and both label it.
  final List<String> labels;

  /// The next fulfillment position — `fulfilledOrdinals + 1` — when today
  /// is an anchor date of the spec, or null when it is not. Carries into
  /// `ScheduleResult.ordinal` on an anchor date's resolution: it names the
  /// position the next completion takes (today's own position when today's
  /// anchor is unfulfilled, otherwise the next anchor's).
  final int? nextOrdinal;

  /// Creates a [CommitmentState].
  const CommitmentState({
    required this.fulfilledOrdinals,
    this.lastFulfilledAnchor,
    this.labels = const <String>[],
    this.nextOrdinal,
  });

  /// Evaluates [spec] against the completion dates [completedAnchorDates]
  /// as of [today].
  ///
  /// The anchor dates the devotion recurs on are derived from
  /// [spec.anchor] itself — every date on which it resolves as due between
  /// the earliest completed date and [today] (both bounds inclusive;
  /// completions dated after `today` are ignored). Consecutiveness is then
  /// judged on that derived list, so a missed anchor position is detected
  /// as such and can never be silently rolled forward:
  ///
  /// * an anchor counts as fulfilled when its date is in the completions,
  ///   or when any of [ConsecutiveCommitmentSpec.windows] admits the anchor
  ///   against one of the completion dates;
  /// * a gap (an unfulfilled anchor) applies the spec's
  ///   [RestartPolicy]: [RestartPolicy.strict] counts only from the last
  ///   gap (the series restarts), [RestartPolicy.permissive] continues
  ///   across it;
  /// * every unfulfilled anchor is reported in [labels] under either
  ///   policy.
  ///
  /// The evaluation span opens at the earliest completed date; anchors
  /// before it are not the commitment's history. When the span holds no
  /// anchor dates at all, the state is zero with [labels] empty — while
  /// `today` being an anchor date still yields a [nextOrdinal] of 1.
  ///
  /// Only the local calendar components of the completion dates and of
  /// [today] participate ([_dateOnly]); time-of-day never leaks into the
  /// comparison. The internal resolution consults a default
  /// [ScheduleContext] (anchor due-ness does not depend on the season).
  static CommitmentState evaluate(
    ConsecutiveCommitmentSpec spec,
    Set<DateTime> completedAnchorDates,
    DateTime today,
  ) {
    final DateTime t = _dateOnly(today);
    final Set<DateTime> completed = <DateTime>{
      for (final DateTime d in completedAnchorDates) _dateOnly(d),
    };

    // The anchor dates the devotion recurs on across the evaluation span,
    // earliest completed date through today inclusive, walked day by day
    // so recurrence — monthly, weekly, or otherwise — is the anchor spec's
    // own judgment, not a month-arithmetic re-derivation here.
    final List<DateTime> anchors = <DateTime>[];
    if (completed.isNotEmpty) {
      final DateTime firstCompleted = completed.reduce(
        (DateTime a, DateTime b) => a.isBefore(b) ? a : b,
      );
      const ScheduleContext context = ScheduleContext();
      for (
        DateTime d = firstCompleted;
        !d.isAfter(t);
        d = DateTime(d.year, d.month, d.day + 1)
      ) {
        if (spec.anchor.resolve(d, context).due) {
          anchors.add(d);
        }
      }
    }

    final List<int> missedIndexes = <int>[];
    DateTime? lastFulfilledAnchor;
    for (int i = 0; i < anchors.length; i++) {
      if (_fulfilled(anchors[i], completed, spec.windows)) {
        lastFulfilledAnchor = anchors[i];
      } else {
        missedIndexes.add(i);
      }
    }

    // Permissive counts every fulfilled anchor; strict counts only the
    // anchors after the last gap (before it, the series was voided). With
    // no gap both are the whole run.
    final int permissiveCount = anchors.length - missedIndexes.length;
    final int strictCount =
        anchors.length - (missedIndexes.isEmpty ? 0 : missedIndexes.last + 1);
    final int counts = spec.policy == RestartPolicy.strict
        ? strictCount
        : permissiveCount;
    final List<String> labels = <String>[
      for (final int i in missedIndexes) 'gap: ${_stamp(anchors[i])}',
    ];
    final int? nextOrdinal = spec.anchor.resolve(t, const ScheduleContext()).due
        ? counts + 1
        : null;

    return CommitmentState(
      fulfilledOrdinals: counts,
      lastFulfilledAnchor: lastFulfilledAnchor,
      labels: labels,
      nextOrdinal: nextOrdinal,
    );
  }

  @override
  String toString() =>
      'CommitmentState(fulfilledOrdinals: $fulfilledOrdinals, '
      'lastFulfilledAnchor: $lastFulfilledAnchor, labels: $labels, '
      'nextOrdinal: $nextOrdinal)';
}
