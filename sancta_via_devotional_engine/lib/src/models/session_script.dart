/// Session scripts: the ordered steps a devotional session walks through.
///
/// A [SessionScript] is a sequence of [SessionStep]s; running it is the
/// `SessionRunner`'s concern (see `src/session/session_runner.dart`), which
/// advances a `SessionState` through the steps. The step hierarchy is
/// `sealed`: Dart requires subclasses of a sealed class to share its library,
/// so every step type lives in this file.
library;

import 'prayer_text.dart';

/// One step of a devotional session.
///
/// A [SessionStep] is data, not behavior: it describes what the session
/// runner displays or asks of the person at that position of the script.
/// Every step carries a stable [id] and an optional display [title].
sealed class SessionStep {
  /// The stable identifier of the step within its script.
  final String id;

  /// An optional display title for the step.
  final String? title;

  /// Creates a [SessionStep].
  const SessionStep({required this.id, this.title});
}

/// A step displaying one [PrayerText].
class PrayerStep extends SessionStep {
  /// The prayer the step displays.
  final PrayerText text;

  /// Creates a [PrayerStep].
  const PrayerStep({required super.id, super.title, required this.text});
}

/// A step with a call-and-response pair of lines, optionally closed by a
/// prayer.
class VerseStep extends SessionStep {
  /// The versicle — the line the leader says.
  final String versicle;

  /// The response — the line the assembly answers.
  final String response;

  /// An optional [PrayerText] closing the verse exchange.
  final PrayerText? closing;

  /// Creates a [VerseStep].
  const VerseStep({
    required super.id,
    super.title,
    required this.versicle,
    required this.response,
    this.closing,
  });
}

/// A step of silent reflection for a fixed [duration], with optional reading
/// text.
class ReflectionStep extends SessionStep {
  /// Optional reading text shown before the silence.
  final PrayerText? text;

  /// How long the reflection lasts.
  final Duration duration;

  /// Creates a [ReflectionStep].
  const ReflectionStep({
    required super.id,
    super.title,
    this.text,
    required this.duration,
  });
}

/// A step recording that one concrete item of the devotion was done.
class CheckpointStep extends SessionStep {
  /// The devotion item this checkpoint records (e.g. `'confession'`).
  final String item;

  /// Whether the session cannot complete without this checkpoint recorded.
  ///
  /// Gating/skip semantics are an app-layer (Plan 2) contract; the engine
  /// itself treats every step as walked-to-completion.
  final bool requiredForCompletion;

  /// Creates a [CheckpointStep].
  const CheckpointStep({
    required super.id,
    super.title,
    required this.item,
    required this.requiredForCompletion,
  });
}

/// A step showing a prompt for intercessions (intentions of one's own).
class IntercessionStep extends SessionStep {
  /// The prompt shown before the free-form intercessions.
  final String prompt;

  /// Creates an [IntercessionStep].
  const IntercessionStep({
    required super.id,
    super.title,
    required this.prompt,
  });
}

/// A counted group of beads, typically one decade of the Rosary.
///
/// The step carries a counted target: [SessionRunner.completeCurrent] (with
/// the script supplied) is only allowed once the step's recorded count has
/// reached [hailMaryCount]. The optional Fatima prayer that concludes a
/// decade belongs to this same step — [includeFatimaPrayer] is metadata for
/// the app layer, and the engine keeps no state machinery for it.
class BeadGroupStep extends SessionStep {
  /// The title of the mystery meditated on during the beads (e.g.
  /// `'The Annunciation'`), or null when the beads stand alone.
  final String? mysteryTitle;

  /// The spiritual fruit of the mystery (e.g. `'Humility'`), or null when
  /// the beads stand alone.
  final String? mysteryFruit;

  /// How many counted bead prayers the step asks for, one per bead. One
  /// decade of the Rosary is ten; chaplet groups use other counts.
  final int hailMaryCount;

  /// Whether an optional Fatima prayer follows the beads. Presentation
  /// metadata only: the prayer is part of this step.
  final bool includeFatimaPrayer;

  /// Creates a [BeadGroupStep].
  ///
  /// Throws an [ArgumentError] when [hailMaryCount] is below 1.
  BeadGroupStep({
    required super.id,
    super.title,
    this.mysteryTitle,
    this.mysteryFruit,
    required this.hailMaryCount,
    required this.includeFatimaPrayer,
  }) {
    if (hailMaryCount < 1) {
      throw ArgumentError(
        'BeadGroupStep(id: $id) failed validation: '
        'hailMaryCount must be at least 1',
      );
    }
  }
}

/// A step displaying one [PrayerText] to be repeated [count] times.
///
/// The step carries a counted target: [SessionRunner.completeCurrent] (with
/// the script supplied) is only allowed once the step's recorded count has
/// reached [count].
class RepetitionStep extends SessionStep {
  /// The prayer the step repeats.
  final PrayerText text;

  /// How many repetitions the step asks for.
  final int count;

  /// Creates a [RepetitionStep].
  ///
  /// Throws an [ArgumentError] when [count] is below 1.
  RepetitionStep({
    required super.id,
    super.title,
    required this.text,
    required this.count,
  }) {
    if (count < 1) {
      throw ArgumentError(
        'RepetitionStep(id: $id) failed validation: '
        'count must be at least 1',
      );
    }
  }
}

/// A step of call-and-response invocations in litany form.
///
/// Each line of [invocations] is answered with the same [response]. The
/// step completes in a single completion action — its invocation count is
/// presentation data, not a recorded target, unlike [RepetitionStep].
/// [groupedResponse] describes how the app layer presents the responses
/// and carries no state.
class LitanyStep extends SessionStep {
  /// The invocations of the litany, each answered with [response].
  final List<String> invocations;

  /// The response spoken for every invocation.
  final String response;

  /// Whether the app layer renders the responses as one grouped passage.
  final bool groupedResponse;

  /// Creates a [LitanyStep].
  ///
  /// Throws an [ArgumentError] when [invocations] is empty.
  LitanyStep({
    required super.id,
    super.title,
    required List<String> invocations,
    required this.response,
    required this.groupedResponse,
  }) : invocations = List<String>.unmodifiable(invocations) {
    if (this.invocations.isEmpty) {
      throw ArgumentError(
        'LitanyStep(id: $id) failed validation: '
        'invocations must not be empty',
      );
    }
  }
}

/// An ordered sequence of [SessionStep]s forming one devotional session.
class SessionScript {
  /// The stable identifier of the script.
  final String id;

  /// The steps of the session, in walk order; never empty.
  final List<SessionStep> steps;

  /// Creates a [SessionScript].
  ///
  /// Throws an [ArgumentError] when [steps] is empty.
  SessionScript({required this.id, required List<SessionStep> steps})
    : steps = List<SessionStep>.unmodifiable(steps) {
    if (this.steps.isEmpty) {
      throw ArgumentError(
        'SessionScript(id: $id) failed validation: '
        'steps must not be empty',
      );
    }
  }

  @override
  String toString() => 'SessionScript(id: $id, steps: ${steps.length})';
}
