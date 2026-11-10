/// Running a session script: an immutable `SessionState` cursor walked by
/// the `SessionRunner` state-machine methods.
///
/// Every [SessionRunner] transition returns a NEW [SessionState]; no
/// transition mutates the state it is given. [SessionState] persists as JSON
/// (`toJson`/`fromJson`) so a half-finished session can be resumed.
library;

import '../models/session_script.dart';

/// The cursor of one run of a [SessionScript]: which step is current, which
/// steps carry completion timestamps, and how many counted repetitions each
/// step has recorded so far.
///
/// A [SessionState] is immutable and carries its script's step count, so
/// [SessionState.isComplete] can be judged from the state alone — without
/// the script — after a JSON resume.
class SessionState {
  /// The [SessionScript.id] of the script this state runs.
  final String scriptId;

  /// The 0-based index of the current step, or the script's step count when
  /// the session has walked every step ([isComplete]).
  final int stepIndex;

  /// How many steps the run's script holds; the fixed bound [stepIndex]
  /// walks toward and past.
  final int stepCount;

  /// A per-step counter of counted repetitions (reflection or repetition
  /// progress), keyed by step index.
  final Map<int, int> recordedCounts;

  /// The completion timestamp of each finished step, keyed by step index,
  /// captured at the moment the step was completed.
  final Map<int, DateTime> completedAt;

  /// Whether every step of the script has been completed:
  /// [stepIndex] has reached [stepCount].
  ///
  /// Purely positional: [CheckpointStep.requiredForCompletion] gating is
  /// an app-layer (Plan 2) contract, and the engine treats every step as
  /// walked-to-completion.
  bool get isComplete => stepIndex >= stepCount;

  /// Creates a [SessionState] with unmodifiable copies of the maps.
  SessionState._({
    required this.scriptId,
    required this.stepIndex,
    required this.stepCount,
    required Map<int, int> recordedCounts,
    required Map<int, DateTime> completedAt,
  }) : recordedCounts = Map<int, int>.unmodifiable(recordedCounts),
       completedAt = Map<int, DateTime>.unmodifiable(completedAt);

  /// Serializes this state to a JSON-compatible map.
  ///
  /// Map keys are step indices, which JSON renders as strings.
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'scriptId': scriptId,
      'stepIndex': stepIndex,
      'stepCount': stepCount,
      'recordedCounts': <String, int>{
        for (final MapEntry<int, int> entry in recordedCounts.entries)
          '${entry.key}': entry.value,
      },
      'completedAt': <String, dynamic>{
        for (final MapEntry<int, DateTime> entry in completedAt.entries)
          '${entry.key}': entry.value.toIso8601String(),
      },
    };
  }

  /// Reconstructs a [SessionState] from its JSON representation.
  ///
  /// Counter and timestamp keys are parsed back to step indices; timestamps
  /// are parsed as ISO 8601 instants.
  factory SessionState.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> countsJson =
        json['recordedCounts'] as Map<String, dynamic>;
    final Map<String, dynamic> completedJson =
        json['completedAt'] as Map<String, dynamic>;
    return SessionState._(
      scriptId: json['scriptId'] as String,
      stepIndex: json['stepIndex'] as int,
      stepCount: json['stepCount'] as int,
      recordedCounts: <int, int>{
        for (final MapEntry<String, dynamic> entry in countsJson.entries)
          int.parse(entry.key): entry.value as int,
      },
      completedAt: <int, DateTime>{
        for (final MapEntry<String, dynamic> entry in completedJson.entries)
          int.parse(entry.key): DateTime.parse(entry.value as String),
      },
    );
  }

  @override
  String toString() =>
      'SessionState(scriptId: $scriptId, stepIndex: $stepIndex, '
      'stepCount: $stepCount, isComplete: $isComplete, '
      'recordedCounts: $recordedCounts, completedAt: $completedAt)';
}

/// The state machine of a session run: fresh state for a script, completing
/// the current step, and recording counted repetitions.
///
/// All methods are static and pure: each returns a new [SessionState] and
/// leaves its argument untouched. Completing ([completeCurrent]) and
/// recording ([record]) act only while the session still has a current
/// step — a complete session answers both with a [StateError].
class SessionRunner {
  /// The fresh state starting [script] at its first step.
  static SessionState forState(SessionScript script) {
    return SessionState._(
      scriptId: script.id,
      stepIndex: 0,
      stepCount: script.steps.length,
      recordedCounts: const <int, int>{},
      completedAt: const <int, DateTime>{},
    );
  }

  /// Completes the current step (recording its completion timestamp) and
  /// advances to the next one.
  ///
  /// [script] supplies the script being run so counted steps can enforce
  /// their target: completing a [RepetitionStep] requires the step's
  /// recorded counts to have reached [RepetitionStep.count], and completing
  /// a [BeadGroupStep] requires reaching [BeadGroupStep.hailMaryCount];
  /// otherwise a [StateError] is thrown. Every other step type completes
  /// directly — a [LitanyStep] in one completion action, with no recorded
  /// counts needed. Without a script the target check is best-effort: no
  /// target is known, so completion is allowed whatever the recorded counts
  /// hold.
  ///
  /// Completing the last step leaves [SessionState.stepIndex] at the
  /// script's step count with [SessionState.isComplete] true. Throws a
  /// [StateError] when the state is already complete — there is no current
  /// step left to complete.
  ///
  /// The completion timestamp is `DateTime.now()`, captured at the moment
  /// of completion.
  static SessionState completeCurrent(
    SessionState state, {
    SessionScript? script,
  }) {
    if (state.isComplete) {
      throw StateError(_noCurrentStepMessage(state, 'complete'));
    }
    _assertCountTargetReached(state, script);
    return SessionState._(
      scriptId: state.scriptId,
      stepIndex: state.stepIndex + 1,
      stepCount: state.stepCount,
      recordedCounts: state.recordedCounts,
      completedAt: <int, DateTime>{
        ...state.completedAt,
        state.stepIndex: DateTime.now(),
      },
    );
  }

  /// Accumulates [count] into the current step's counter.
  ///
  /// The counter of a step accumulates across successive records; other
  /// steps' counters and every completion timestamp are preserved. Throws a
  /// [StateError] when the state is already complete — there is no current
  /// step to record into.
  static SessionState record(SessionState state, int count) {
    if (state.isComplete) {
      throw StateError(_noCurrentStepMessage(state, 'record into'));
    }
    return SessionState._(
      scriptId: state.scriptId,
      stepIndex: state.stepIndex,
      stepCount: state.stepCount,
      recordedCounts: <int, int>{
        ...state.recordedCounts,
        state.stepIndex: (state.recordedCounts[state.stepIndex] ?? 0) + count,
      },
      completedAt: state.completedAt,
    );
  }

  /// The error message describing why a complete session has no current
  /// step to [action].
  static String _noCurrentStepMessage(SessionState state, String action) {
    return 'Cannot $action a step: session of script ${state.scriptId} is '
        'complete (stepIndex ${state.stepIndex} of '
        '${state.stepCount} steps)';
  }

  /// The [StateError] guard for counted steps, consulted by
  /// [completeCurrent] when the running [script] is available.
  ///
  /// A [RepetitionStep] targets [RepetitionStep.count] and a
  /// [BeadGroupStep] targets [BeadGroupStep.hailMaryCount]; every other
  /// step type carries no target. States whose step index falls outside
  /// [script]'s steps (a mismatched script) are treated as best-effort too.
  static void _assertCountTargetReached(
    SessionState state,
    SessionScript? script,
  ) {
    if (script == null || state.stepIndex >= script.steps.length) {
      return;
    }
    final SessionStep step = script.steps[state.stepIndex];
    final int? requiredCount;
    if (step is RepetitionStep) {
      requiredCount = step.count;
    } else if (step is BeadGroupStep) {
      requiredCount = step.hailMaryCount;
    } else {
      return;
    }
    final int recorded = state.recordedCounts[state.stepIndex] ?? 0;
    if (recorded < requiredCount) {
      throw StateError(
        _stepTargetNotReachedMessage(state, step, requiredCount, recorded),
      );
    }
  }

  /// The error message describing why a step with a recorded target
  /// ([RepetitionStep], [BeadGroupStep]) cannot complete yet.
  static String _stepTargetNotReachedMessage(
    SessionState state,
    SessionStep step,
    int requiredCount,
    int recorded,
  ) {
    return 'Cannot complete step ${state.stepIndex} of script '
        '${state.scriptId}: ${step.runtimeType} target not reached '
        '(recorded $recorded of $requiredCount)';
  }
}
