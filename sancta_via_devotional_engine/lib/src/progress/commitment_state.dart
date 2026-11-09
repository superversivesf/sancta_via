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
  /// spanned, gap or not, continuing across gaps (permissive). The
  /// evaluation walk stops once [count] is reached, so this never exceeds
  /// the program's size.
  final int fulfilledOrdinals;

  /// The number of fulfillments the evaluated program asks for, copied
  /// from [ConsecutiveCommitmentSpec.count]; [isComplete] weighs
  /// [fulfilledOrdinals] against it.
  final int count;

  /// The most recently fulfilled anchor date in the evaluation span
  /// (independent of policy), or null when no anchor in the span counts as
  /// fulfilled.
  final DateTime? lastFulfilledAnchor;

  /// One label per walked anchor position that was NOT fulfilled
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

  /// Whether the evaluated program is fulfilled: [fulfilledOrdinals] has
  /// reached [count] under the capped walk. A completed program is stable:
  /// anchor dates beyond it — met, missed, or never reached — can neither
  /// extend it nor void it.
  bool get isComplete => fulfilledOrdinals >= count;

  /// Creates a [CommitmentState].
  const CommitmentState({
    required this.fulfilledOrdinals,
    required this.count,
    this.lastFulfilledAnchor,
    this.labels = const <String>[],
    this.nextOrdinal,
  });

  /// Evaluates [spec] against the completion dates [completedAnchorDates]
  /// as of [today].
  ///
  /// The anchor dates the devotion recurs on are walked out of
  /// [spec.anchor] itself — every date on which it resolves as due between
  /// the earliest completed date and [today] (both bounds inclusive;
  /// completions dated after `today` are ignored, so a future-dated
  /// completion can never admit an earlier in-span anchor through a grace
  /// window). Consecutiveness is judged as the walk runs, so a missed
  /// anchor position is detected as such and can never be silently rolled
  /// forward:
  ///
  /// * an anchor counts as fulfilled when its date is in the completions,
  ///   or when any of [ConsecutiveCommitmentSpec.windows] admits the anchor
  ///   against one of the completion dates;
  /// * a gap (an unfulfilled anchor) applies the spec's
  ///   [RestartPolicy]: [RestartPolicy.strict] counts only from the last
  ///   gap (the series restarts), [RestartPolicy.permissive] continues
  ///   across it;
  /// * every unfulfilled anchor is reported in [labels] under either
  ///   policy;
  /// * the walk stops once [ConsecutiveCommitmentSpec.count] positions are
  ///   fulfilled under the policy — strict by its current series' length,
  ///   permissive by its span total — so a fulfilled program
  ///   ([isComplete]) reads as complete and stable: anchors beyond it can
  ///   neither extend it nor void it.
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
    // Completions dated after today are ignored at the normalize step, so
    // a future-dated completion can never admit an earlier in-span anchor
    // through a grace window.
    final Set<DateTime> completed = <DateTime>{
      for (final DateTime d in completedAnchorDates)
        if (!_dateOnly(d).isAfter(t)) _dateOnly(d),
    };

    // The anchor dates the devotion recurs on are walked day by day from
    // the earliest completion through today inclusive, so recurrence —
    // monthly, weekly, or otherwise — is the anchor spec's own judgment,
    // not a month-arithmetic re-derivation here. Each anchor is classified
    // as it is met, and the walk stops once the program's ordinals are
    // fulfilled under the spec's policy: anchors beyond a fulfilled
    // program are beyond the program — they can neither extend it nor
    // void it.
    final List<DateTime> missed = <DateTime>[];
    DateTime? lastFulfilledAnchor;
    int ordinals = 0;
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
        if (!spec.anchor.resolve(d, context).due) {
          continue;
        }
        if (_fulfilled(d, completed, spec.windows)) {
          ordinals++;
          lastFulfilledAnchor = d;
        } else {
          missed.add(d);
          if (spec.policy == RestartPolicy.strict) {
            ordinals = 0;
          }
        }
        if (ordinals >= spec.count) {
          break;
        }
      }
    }

    final List<String> labels = <String>[
      for (final DateTime missedOn in missed) 'gap: ${_stamp(missedOn)}',
    ];
    final int? nextOrdinal = spec.anchor.resolve(t, const ScheduleContext()).due
        ? ordinals + 1
        : null;

    return CommitmentState(
      fulfilledOrdinals: ordinals,
      count: spec.count,
      lastFulfilledAnchor: lastFulfilledAnchor,
      labels: labels,
      nextOrdinal: nextOrdinal,
    );
  }

  @override
  String toString() =>
      'CommitmentState(fulfilledOrdinals: $fulfilledOrdinals, '
      'count: $count, lastFulfilledAnchor: $lastFulfilledAnchor, '
      'labels: $labels, nextOrdinal: $nextOrdinal)';
}
