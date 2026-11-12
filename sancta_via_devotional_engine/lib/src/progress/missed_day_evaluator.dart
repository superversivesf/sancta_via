/// The missed-day decision for a devotion the user has left uncompleted
/// on a due date: whether the app silently resumes the program, resets
/// it back to its first commitment position, or leaves the choice to the
/// user.
///
/// The decision ([MissedDayEvaluator.evaluate]) is pinned to the same
/// date-only discipline as resolution: the dates are reduced to local
/// midnight calendar dates (`DateTime(year, month, day)`) and compared
/// through their local calendar components — never a UTC rendering.
///
/// The evaluator is scoped to daily-cadence programs (consecutive
/// positions on adjacent calendar days — see
/// [MissedDayEvaluator.evaluate] for the cadence scope):
/// anchor-recurring commitments are driven by
/// `CommitmentState.evaluate` with the spec's restart policy, not by
/// this evaluator.
library;

import '../models/progress_state.dart';
import '../models/schedule_spec.dart';

/// Reduces [d] to a local midnight date (a `DateTime(year, month, day)`
/// construction), preserving the local calendar components.
DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// What an app should do when a devotion's next due date has arrived and
/// the user's progress has a decision to carry.
enum MissedDayVerdict {
  /// Continue the program from where it stands — the streak survives.
  resume,

  /// Restart the program from its first position — the streak is void,
  /// the strict reading of a consecutive commitment after a skipped
  /// span.
  reset,

  /// Leave the decision to the user — the state holds no fulfilled
  /// ordinals yet (`fulfilledOrdinals == 0`: nothing to reset), so the
  /// user starts afresh.
  askUser,
}

/// Decides the [MissedDayVerdict] for a devotion on its next due date.
class MissedDayEvaluator {
  const MissedDayEvaluator._();

  /// Decides what should happen when [nextDue] arrives for the devotion
  /// the user last completed on [lastFulfilled], given the [state]'s
  /// progress and the pack's missed-day [policy] (`'strict'` or
  /// `'permissive'`).
  ///
  /// * an unknown [policy] throws an [ArgumentError];
  /// * `askUser` when `ProgressState.fulfilledOrdinals` is zero (the
  ///   rule itself): there is no streak to continue or reset, so the
  ///   user must choose afresh;
  /// * otherwise the policy passes through: the `'strict'` policy yields
  ///   `reset` when a gap lies between [lastFulfilled] and [nextDue], and
  ///   the `'permissive'` policy always yields `resume`. A [nextDue] on
  ///   or before [lastFulfilled] is never a gap — under either policy
  ///   such a pair resolves to `resume`.
  ///
  /// A gap is at least one calendar day lying strictly between the two
  /// dates: an evaluator without the anchor schedule takes a span wider
  /// than one day as standing in for the anchor position between the
  /// last fulfilled anchor and the next due one that went unfulfilled
  /// (adjacent dates — or [nextDue] itself being the very next day —
  /// carry no such position). Only the local calendar components of the
  /// dates participate ([_dateOnly]); time-of-day never leaks into the
  /// decision.
  ///
  /// **Cadence scope.** The calendar-day rule is exact only for
  /// consecutive positions on ADJACENT calendar days — daily programs
  /// such as the 54-day novena. For anchor-recurring commitments
  /// (monthly weekdays etc.) use `CommitmentState.evaluate` with the
  /// spec's `RestartPolicy` — this evaluator must not drive those:
  /// their spans are always wide, so the rule degenerates to `strict`
  /// reading `reset` even when every consecutive position was kept (a
  /// kept First Saturday followed by the next due one reads the same as
  /// a skipped one — pinned by the cadence guard tests in
  /// `test/progress/missed_day_test.dart`).
  ///
  /// The [state]'s own [ProgressState.lastFulfilled] does not decide;
  /// the [lastFulfilled] argument does (an app passes the date the
  /// program actually stands at).
  static MissedDayVerdict evaluate(
    String policy,
    ProgressState state,
    DateTime lastFulfilled,
    DateTime nextDue,
  ) {
    final bool strict = switch (policy) {
      'strict' => true,
      'permissive' => false,
      _ => throw ArgumentError(
        'unknown missed-day policy "$policy" (expected: strict, permissive)',
      ),
    };
    if (state.fulfilledOrdinals == 0) {
      return MissedDayVerdict.askUser;
    }

    final DateTime from = _dateOnly(lastFulfilled);
    final DateTime to = _dateOnly(nextDue);
    // A gap: at least one calendar day strictly between from and to —
    // equivalently, from advanced by two days reaches to or beyond.
    // Calendar arithmetic (DateTime(year, month, day + n)) walks the
    // local calendar, so month and year boundaries never need special
    // cases.
    final bool gap =
        to.isAfter(from) &&
        !DateTime(from.year, from.month, from.day + 2).isAfter(to);
    if (strict && gap) {
      return MissedDayVerdict.reset;
    }
    return MissedDayVerdict.resume;
  }

  /// Decides the [MissedDayVerdict] exactly as [evaluate] does, with the
  /// pack's missed-day policy given as a [RestartPolicy] instead of its
  /// string form.
  ///
  /// A thin delegate: [RestartPolicy.strict] maps to `'strict'` and
  /// [RestartPolicy.permissive] to `'permissive'`, and the decision
  /// itself is [evaluate]'s — one source of truth, no separately
  /// maintained rule. The string-call contract above (the askUser rule,
  /// the gap rule, the date-only discipline, the cadence scope) applies
  /// unchanged; [evaluate] remains the public default.
  static MissedDayVerdict evaluateTyped({
    required RestartPolicy policy,
    required ProgressState state,
    required DateTime lastFulfilled,
    required DateTime nextDue,
  }) {
    final String label = switch (policy) {
      RestartPolicy.strict => 'strict',
      RestartPolicy.permissive => 'permissive',
    };
    return evaluate(label, state, lastFulfilled, nextDue);
  }
}
