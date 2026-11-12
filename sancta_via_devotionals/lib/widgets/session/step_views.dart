// Per-step renderers for the session player (Plan 2, Task 11).
//
// One card per engine step type, dispatched through a sealed switch so a
// new step class fails compilation here instead of rendering blank. Every
// card walks through [sessionStepView], which applies the Review Focus 4
// render guard FIRST: a step whose renderable strings still carry `{{`
// renders a token-leak error card naming the unresolved token(s) — logged
// through [AppLogger], never silently shown raw. The controller's
// substitution gate (`requireFullySubstituted` at start/resume) is the
// first line; this check is the widget-layer defense in depth, a pure text
// check over the state it is handed.
//
// Interactions:
// * verse and prayer cards advance by tap (the Angelus walk's contract);
// * counted steps (repetition ring, bead dots) record one per tap and gate
//   their `Continue` control until the engine's target is reached;
// * the reflection card runs the countdown LOCALLY and routes the deadline
//   through the controller's `tickReflection` (the engine drives timing —
//   the card keeps only what the ring shows), entering the deadline once
//   (so a mid-countdown resume persists it) and clearing it at zero;
// * the intercession card reads current intentions through
//   `intentionsProvider` (Task 11's placeholder seam);
// * a prayer card exposes the Latin toggle when `PrayerText.latin` is
//   present (the authored parallel), initialized from
//   `latinDisplayProvider`.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sancta_via_devotional_engine/sancta_via_devotional_engine.dart';

import '../../database/devotionals_database.dart' show IntentionRow;
import '../../providers/app_settings_provider.dart';
import '../../providers/content_providers.dart';
import '../../providers/session_player_provider.dart';
import '../../utils/logger.dart';

/// The step actions the screen hands down: the controller's own transitions.
class SessionStepActions {
  /// Creates the action bundle.
  const SessionStepActions({
    required this.onAdvance,
    required this.onRecord,
    required this.onToggleCheckpoint,
    required this.onTickReflection,
  });

  /// Completes the current step (the controller's `completeStep`).
  final Future<void> Function() onAdvance;

  /// Records [count] repetitions into the current step (`record`).
  final Future<void> Function(int count) onRecord;

  /// Toggles the checkpoint [item] (`toggleCheckpoint`).
  final Future<void> Function(String item) onToggleCheckpoint;

  /// Records the running reflection's [remaining] deadline
  /// (`tickReflection`).
  final Future<void> Function(Duration remaining) onTickReflection;
}

/// The token placeholder pattern a leaked text carries.
final RegExp _tokenPattern = RegExp(r'\{\{\s*([^}]*?)\s*\}\}');

/// Builds the card of [state]'s step at [stepIndex].
///
/// The render guard runs before any renderer: leaked tokens short-circuit
/// into the error card, so a raw placeholder can never reach the screen.
Widget sessionStepView({
  required BuildContext context,
  required WidgetRef ref,
  required SessionPlayerState state,
  required int stepIndex,
  required SessionStepActions actions,
}) {
  final SessionStep step = state.script.steps[stepIndex];
  final List<String> leaked = leakedStepTokens(step);
  if (leaked.isNotEmpty) {
    AppLogger.error(
      'Step "${step.id}" still carries unresolved placeholder(s) — '
          'rendering the leak error card: ${leaked.join(', ')}',
      null,
      null,
      'SESSION',
    );
    return _TokenLeakCard(stepId: step.id, tokens: leaked);
  }
  final int recorded = state.session.recordedCounts[stepIndex] ?? 0;
  return switch (step) {
    PrayerStep() => _PrayerStepCard(step: step, actions: actions),
    VerseStep() => _VerseStepCard(step: step, actions: actions),
    ReflectionStep() => _ReflectionStepCard(
      step: step,
      reflectionEndsAt: state.reflectionEndsAt,
      actions: actions,
    ),
    CheckpointStep() => _CheckpointStepCard(
      step: step,
      recorded: state.checkpoints[step.item] ?? false,
      actions: actions,
    ),
    IntercessionStep() => _IntercessionStepCard(step: step, actions: actions),
    BeadGroupStep() => _BeadGroupStepCard(
      step: step,
      recorded: recorded,
      actions: actions,
    ),
    RepetitionStep() => _RepetitionStepCard(
      step: step,
      recorded: recorded,
      actions: actions,
    ),
    LitanyStep() => _LitanyStepCard(step: step, actions: actions),
  };
}

/// Every renderable string of [step] that could still carry a token.
List<String?> _candidateTexts(SessionStep step) {
  return switch (step) {
    PrayerStep(:final String? title, :final PrayerText text) => <String?>[
      title,
      text.text,
      text.latin,
    ],
    VerseStep(
      :final String? title,
      :final String versicle,
      :final String response,
      :final PrayerText? closing,
    ) =>
      <String?>[title, versicle, response, closing?.text, closing?.latin],
    ReflectionStep(:final String? title, :final PrayerText? text) => <String?>[
      title,
      text?.text,
      text?.latin,
    ],
    CheckpointStep(:final String? title, :final String item) => <String?>[
      title,
      item,
    ],
    IntercessionStep(:final String? title, :final String prompt) => <String?>[
      title,
      prompt,
    ],
    BeadGroupStep(
      :final String? title,
      :final String? mysteryTitle,
      :final String? mysteryFruit,
    ) =>
      <String?>[title, mysteryTitle, mysteryFruit],
    RepetitionStep(:final String? title, :final PrayerText text) => <String?>[
      title,
      text.text,
      text.latin,
    ],
    LitanyStep(
      :final String? title,
      :final List<String> invocations,
      :final String response,
    ) =>
      <String?>[title, ...invocations, response],
  };
}

/// The unresolved token names inside [step]'s renderable strings, sorted and
/// de-duplicated — the render guard's namesake list (empty = clean).
List<String> leakedStepTokens(SessionStep step) {
  final Set<String> tokens = <String>{};
  for (final String? candidate in _candidateTexts(step)) {
    if (candidate == null) {
      continue;
    }
    for (final RegExpMatch match in _tokenPattern.allMatches(candidate)) {
      final String? name = match.group(1);
      tokens.add(name == null || name.isEmpty ? '(unnamed)' : name);
    }
  }
  return tokens.toList()..sort();
}

/// The Fatima prayer that closes a flagged bead group: app-shipped
/// presentation text (the engine step carries only the flag).
const String _fatimaPrayerText =
    'O my Jesus, forgive us our sins, lead all souls to heaven, '
    'especially those most in need of Thy mercy.';

/// The `n of m` label shared by the counted renderers.
String _countLabel(int recorded, int target) => '$recorded of $target';

/// The `Continue` control every button-advance card carries; [enabled] is
/// the card's own gate (a counted step's target, a reflection's silence).
Widget _continueButton({
  required bool enabled,
  required Future<void> Function() onAdvance,
}) {
  return ElevatedButton(
    onPressed: enabled
        ? () {
            onAdvance();
          }
        : null,
    child: const Text('Continue'),
  );
}

/// The small attribution line under a rendered prayer text: its source and
/// license (the attribution sheet lists the same metadata).
class _AttributionLine extends StatelessWidget {
  const _AttributionLine({required this.text});

  final PrayerText text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        '${text.source} · ${text.license}',
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
      ),
    );
  }
}

/// A step's header: its optional title in the card's H6 slot.
class _StepHeader extends StatelessWidget {
  const _StepHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(title, style: Theme.of(context).textTheme.titleLarge),
    );
  }
}

/// The card scaffold: one rounded Card with consistent padding.
class _StepCard extends StatelessWidget {
  const _StepCard({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    );
  }
}

/// A step card whose body advances the walk by tap (verse and prayer
/// steps' V./R. — and collect — contract).
class _TapAdvanceCard extends StatelessWidget {
  const _TapAdvanceCard({required this.onTap, required this.child, super.key});

  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: const EdgeInsets.all(16), child: child),
      ),
    );
  }
}

/// A step card's optional title header.
Widget? _stepHeader(String? title) {
  if (title == null || title.isEmpty) {
    return null;
  }
  return _StepHeader(title: title);
}

/// The PrayerStep card: title, scrollable body text (the screen supplies the
/// scrollable), the Latin toggle block when the text carries a parallel, and
/// the attribution line.
class _PrayerStepCard extends ConsumerStatefulWidget {
  const _PrayerStepCard({required this.step, required this.actions});

  final PrayerStep step;
  final SessionStepActions actions;

  @override
  ConsumerState<_PrayerStepCard> createState() => _PrayerStepCardState();
}

class _PrayerStepCardState extends ConsumerState<_PrayerStepCard> {
  late bool _showLatin;

  @override
  void initState() {
    super.initState();
    _showLatin = ref.read(latinDisplayProvider);
  }

  @override
  Widget build(BuildContext context) {
    final PrayerText text = widget.step.text;
    return _StepCard(
      key: Key('session_step_${widget.step.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // The tap-to-advance surface wraps the whole prayed text (title
          // included), so the Latin toggle below it can never advance the
          // walk by accident.
          InkWell(
            onTap: () {
              widget.actions.onAdvance();
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                ?_stepHeader(widget.step.title),
                Text(text.text),
                if (_showLatin && text.latin != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      text.latin!,
                      style: const TextStyle(fontStyle: FontStyle.italic),
                    ),
                  ),
              ],
            ),
          ),
          if (text.latin != null)
            SwitchListTile(
              key: Key('session_latin_toggle_${widget.step.id}'),
              value: _showLatin,
              onChanged: (bool value) => setState(() => _showLatin = value),
              title: const Text('Latin'),
              secondary: const Icon(Icons.translate),
              dense: true,
              contentPadding: EdgeInsets.zero,
            ),
          _AttributionLine(text: text),
        ],
      ),
    );
  }
}

/// The VerseStep card: the V./R. pair, tap-to-advance over the whole card,
/// and the closing prayer when one closes the exchange.
class _VerseStepCard extends StatelessWidget {
  const _VerseStepCard({required this.step, required this.actions});

  final VerseStep step;
  final SessionStepActions actions;

  @override
  Widget build(BuildContext context) {
    return _TapAdvanceCard(
      key: Key('session_step_${step.id}'),
      onTap: () {
        actions.onAdvance();
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ?_stepHeader(step.title),
          Text('V. ${step.versicle}'),
          const SizedBox(height: 4),
          Text('R. ${step.response}'),
          if (step.closing != null) ...<Widget>[
            const Divider(height: 24),
            Text(step.closing!.text),
            _AttributionLine(text: step.closing!),
          ],
        ],
      ),
    );
  }
}

/// The BeadGroupStep card: mystery header, the decade dots (one filled dot
/// per recorded bead — one tap anywhere on the row records one), the Fatima
/// toggle when flagged, and the target-gated Continue.
class _BeadGroupStepCard extends StatefulWidget {
  const _BeadGroupStepCard({
    required this.step,
    required this.recorded,
    required this.actions,
  });

  final BeadGroupStep step;
  final int recorded;
  final SessionStepActions actions;

  @override
  State<_BeadGroupStepCard> createState() => _BeadGroupStepCardState();
}

class _BeadGroupStepCardState extends State<_BeadGroupStepCard> {
  bool _fatimaShown = false;

  @override
  Widget build(BuildContext context) {
    final BeadGroupStep step = widget.step;
    final int recorded = widget.recorded;
    return _StepCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ?_stepHeader(step.title ?? step.mysteryTitle),
          if (step.mysteryTitle != null)
            Text(
              step.mysteryTitle!,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          if (step.mysteryFruit != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                step.mysteryFruit!,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          const SizedBox(height: 12),
          GestureDetector(
            key: Key('session_bead_dots_${step.id}'),
            behavior: HitTestBehavior.opaque,
            onTap: () {
              if (recorded < step.hailMaryCount) {
                widget.actions.onRecord(1);
              }
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Wrap(
                spacing: 6,
                children: <Widget>[
                  for (int i = 0; i < step.hailMaryCount; i++)
                    Icon(
                      i < recorded ? Icons.circle : Icons.circle_outlined,
                      size: 18,
                    ),
                ],
              ),
            ),
          ),
          Text(_countLabel(recorded, step.hailMaryCount)),
          if (step.includeFatimaPrayer)
            SwitchListTile(
              key: Key('session_fatima_toggle_${step.id}'),
              value: _fatimaShown,
              onChanged: (bool value) => setState(() => _fatimaShown = value),
              title: const Text('Fatima Prayer'),
              dense: true,
              contentPadding: EdgeInsets.zero,
            ),
          if (step.includeFatimaPrayer && _fatimaShown)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(_fatimaPrayerText),
            ),
          _continueButton(
            enabled: recorded >= step.hailMaryCount,
            onAdvance: widget.actions.onAdvance,
          ),
        ],
      ),
    );
  }
}

/// The RepetitionStep card: the ring counter (one tap records one), the
/// repeated prayer text, and the target-gated Continue.
class _RepetitionStepCard extends StatelessWidget {
  const _RepetitionStepCard({
    required this.step,
    required this.recorded,
    required this.actions,
  });

  final RepetitionStep step;
  final int recorded;
  final SessionStepActions actions;

  @override
  Widget build(BuildContext context) {
    return _StepCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ?_stepHeader(step.title),
          Text(step.text.text),
          const SizedBox(height: 12),
          Center(
            child: GestureDetector(
              key: Key('session_count_ring_${step.id}'),
              behavior: HitTestBehavior.opaque,
              onTap: () {
                if (recorded < step.count) {
                  actions.onRecord(1);
                }
              },
              child: SizedBox(
                width: 96,
                height: 96,
                child: Stack(
                  alignment: Alignment.center,
                  children: <Widget>[
                    SizedBox(
                      width: 96,
                      height: 96,
                      child: CircularProgressIndicator(
                        value: step.count <= 0
                            ? 0
                            : (recorded / step.count).clamp(0.0, 1.0),
                      ),
                    ),
                    Text(_countLabel(recorded, step.count)),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: _continueButton(
              enabled: recorded >= step.count,
              onAdvance: actions.onAdvance,
            ),
          ),
        ],
      ),
    );
  }
}

/// The ReflectionStep card: the countdown ring with the reading text; the
/// deadline flows through `tickReflection` (entered once — so a
/// mid-countdown resume persists it — and cleared at zero).
class _ReflectionStepCard extends StatefulWidget {
  const _ReflectionStepCard({
    required this.step,
    required this.reflectionEndsAt,
    required this.actions,
  });

  final ReflectionStep step;
  final DateTime? reflectionEndsAt;
  final SessionStepActions actions;

  @override
  State<_ReflectionStepCard> createState() => _ReflectionStepCardState();
}

class _ReflectionStepCardState extends State<_ReflectionStepCard> {
  late Duration _remaining;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _remaining = _remainingFromDeadline();
    _timer = Timer.periodic(const Duration(seconds: 1), (Timer _) {
      if (!mounted) {
        return;
      }
      setState(() => _remaining -= const Duration(seconds: 1));
      if (_remaining <= Duration.zero) {
        _timer?.cancel();
        widget.actions.onTickReflection(Duration.zero);
      }
    });
    // Publish the deadline AFTER the frame lands (a state write during the
    // build phase would fight the tree it is building), so the controller
    // persists it for a mid-countdown resume.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        widget.actions.onTickReflection(_remaining);
      }
    });
  }

  @override
  void didUpdateWidget(_ReflectionStepCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The same step keeps its local countdown: the controller's deadline
    // publish re-renders the card but must not re-enter (or restart) the
    // silence. A genuinely different step resets it.
    if (oldWidget.step.id != widget.step.id) {
      _remaining = _remainingFromDeadline();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// The remaining silence of THIS card's entry: a resumed deadline
  /// (absolute) measured against now, else the step's whole duration.
  Duration _remainingFromDeadline() {
    final DateTime? endsAt = widget.reflectionEndsAt;
    if (endsAt == null) {
      return widget.step.duration;
    }
    final Duration left = endsAt.difference(DateTime.now());
    return left.isNegative ? Duration.zero : left;
  }

  /// The `m:ss` rendering of the remaining silence.
  String get _remainingLabel =>
      '${_remaining.inMinutes}'
      ':${(_remaining.inSeconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final Duration total = widget.step.duration;
    return _StepCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ?_stepHeader(widget.step.title),
          if (widget.step.text != null) Text(widget.step.text!.text),
          const SizedBox(height: 12),
          Center(
            child: SizedBox(
              width: 120,
              height: 120,
              child: Stack(
                alignment: Alignment.center,
                children: <Widget>[
                  SizedBox(
                    width: 120,
                    height: 120,
                    child: CircularProgressIndicator(
                      value: total <= Duration.zero
                          ? 1
                          : (1 - _remaining.inSeconds / total.inSeconds).clamp(
                              0.0,
                              1.0,
                            ),
                    ),
                  ),
                  Text(_remainingLabel),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: _continueButton(
              enabled: _remaining <= Duration.zero,
              onAdvance: widget.actions.onAdvance,
            ),
          ),
        ],
      ),
    );
  }
}

/// The CheckpointStep card: the checkbox tile (list title = the step's
/// title, falling back to the item) and its gating flag.
class _CheckpointStepCard extends StatelessWidget {
  const _CheckpointStepCard({
    required this.step,
    required this.recorded,
    required this.actions,
  });

  final CheckpointStep step;
  final bool recorded;
  final SessionStepActions actions;

  @override
  Widget build(BuildContext context) {
    return _StepCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          CheckboxListTile(
            key: Key('session_checkpoint_${step.item}'),
            value: recorded,
            onChanged: (bool? _) {
              actions.onToggleCheckpoint(step.item);
            },
            title: Text(step.title ?? step.item),
            subtitle: Text(step.item),
            secondary: step.requiredForCompletion
                ? const Icon(Icons.flag_outlined)
                : const Icon(Icons.check_circle_outline),
          ),
          if (step.requiredForCompletion) const Text('Required for completion'),
          const SizedBox(height: 8),
          _continueButton(enabled: true, onAdvance: actions.onAdvance),
        ],
      ),
    );
  }
}

/// The IntercessionStep card: the substituted prompt plus the current
/// intentions readout through `intentionsProvider`.
class _IntercessionStepCard extends ConsumerWidget {
  const _IntercessionStepCard({required this.step, required this.actions});

  final IntercessionStep step;
  final SessionStepActions actions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<IntentionRow>> intentions = ref.watch(
      intentionsProvider,
    );
    return _StepCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ?_stepHeader(step.title),
          Text(step.prompt),
          const SizedBox(height: 12),
          Text(
            'Current intentions',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          switch (intentions) {
            AsyncData<List<IntentionRow>>(:final List<IntentionRow>? value) =>
              value == null || value.isEmpty
                  ? const Text('No intentions recorded yet.')
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        for (final IntentionRow row in value) Text(row.text),
                      ],
                    ),
            AsyncError<List<IntentionRow>>() => const Text(
              'Intentions are unavailable right now.',
            ),
            _ => const Center(child: CircularProgressIndicator()),
          },
          const SizedBox(height: 12),
          _continueButton(enabled: true, onAdvance: actions.onAdvance),
        ],
      ),
    );
  }
}

/// The LitanyStep card: the invocation list with its response — one grouped
/// passage at the end when `groupedResponse`, the response after each
/// invocation otherwise.
class _LitanyStepCard extends StatelessWidget {
  const _LitanyStepCard({required this.step, required this.actions});

  final LitanyStep step;
  final SessionStepActions actions;

  @override
  Widget build(BuildContext context) {
    return _StepCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ?_stepHeader(step.title),
          if (step.groupedResponse) ...<Widget>[
            for (final String invocation in step.invocations)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(invocation),
              ),
            const Divider(height: 24),
            Text('All: ${step.response}'),
          ] else ...<Widget>[
            for (final String invocation in step.invocations) ...<Widget>[
              Text(invocation),
              Text(
                step.response,
                style: const TextStyle(fontStyle: FontStyle.italic),
              ),
              const SizedBox(height: 6),
            ],
          ],
          const SizedBox(height: 12),
          _continueButton(enabled: true, onAdvance: actions.onAdvance),
        ],
      ),
    );
  }
}

/// The token-leak error card: names the unresolved token(s) instead of
/// rendering raw `{{…}}` text (the render guard's pinned placeholder).
class _TokenLeakCard extends StatelessWidget {
  const _TokenLeakCard({required this.stepId, required this.tokens});

  final String stepId;
  final List<String> tokens;

  @override
  Widget build(BuildContext context) {
    return _StepCard(
      key: Key('session_token_leak_$stepId'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Row(
            children: <Widget>[
              Icon(Icons.error_outline, color: Colors.red),
              SizedBox(width: 8),
              Text('This step\'s text could not be resolved'),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            tokens.length == 1
                ? 'Unresolved token: ${tokens.first}'
                : 'Unresolved tokens: ${tokens.join(', ')}',
          ),
        ],
      ),
    );
  }
}
