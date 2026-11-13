// The full-screen session player (Plan 2, Task 11).
//
// The screen renders Task 10's `SessionPlayerState` — progress header (x of
// N steps, pack title, day label), the per-step card of the current step
// (see `widgets/session/step_views.dart`), and the missing-items banner
// when the walk is finished but Task 9's checkpoint gate holds. The
// completion lands on a summary (title, the day variant's phase banner when
// present, ordinal and badge callout read from the REAL persisted progress)
// whose "Back to Today" returns to the root route — the Today deep link
// this screen is reached from.
//
// Opening with a `forDate` (the route's optional `?forDate=yyyy-MM-dd`
// query parameter, Task 13's deep-link shape) re-runs `startSession` for
// exactly that calendar day after the construction-time resume settles; the
// controller's resume rules decide resumed-vs-fresh.
//
// The screen is deliberately presentational: every transition, record,
// checkpoint toggle, reflection tick, and finalization goes through the
// controller; the render guard (token-leak error card) lives with the
// per-step renderers.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sancta_via_devotional_engine/sancta_via_devotional_engine.dart';
import 'package:sancta_via_devotional_engine_riverpod/sancta_via_devotional_engine_riverpod.dart'
    show ProgramRepository;

import '../../providers/session_player_provider.dart';
import '../../utils/logger.dart';
import '../../widgets/session/attribution_sheet.dart';
import '../../widgets/session/step_views.dart';

/// The month names of the `MMMM d, yyyy` day-label rendering.
const List<String> _monthNames = <String>[
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

/// The session player screen for [packId], optionally opened for a fixed
/// [forDate].
class SessionPlayerScreen extends ConsumerStatefulWidget {
  /// Creates the player screen.
  const SessionPlayerScreen({required this.packId, super.key, this.forDate});

  /// The pack whose session the player renders.
  final String packId;

  /// The calendar day the session belongs to (the deep link's `forDate`);
  /// null opens on the construction-time resume's day (the clock's day for
  /// a fresh pack).
  final DateTime? forDate;

  @override
  ConsumerState<SessionPlayerScreen> createState() =>
      _SessionPlayerScreenState();
}

class _SessionPlayerScreenState extends ConsumerState<SessionPlayerScreen> {
  /// The pack's display title, resolved once through the repository; null
  /// until loaded (the AppBar falls back to the generic "Session").
  String? _packTitle;

  /// The resolved pack (the attribution sheet's litany-provenance pass:
  /// a litany step's invocation text is licensed at the pack level).
  ContentPack? _pack;

  @override
  void initState() {
    super.initState();
    // Post-frame: both tasks below drive controller state, which must not
    // fight the tree being built (the controller publishes on every
    // transition).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _bootstrap();
    });
  }

  /// The screen-level bootstrap: honor the deep link's `forDate` by
  /// (re-)starting the session for that day, then resolve the pack title.
  Future<void> _bootstrap() async {
    if (widget.forDate != null) {
      await _restartForDay();
    }
    if (!mounted) {
      return;
    }
    await _loadPackTitle();
  }

  /// The deep link's `forDate` re-opens (or resumes) the pack's session for
  /// exactly that calendar day — the controller's resume rules decide
  /// resumed-vs-fresh, so a stale snapshot for a different day turns into a
  /// fresh start.
  Future<void> _restartForDay() async {
    final SessionPlayerController controller = _controller;
    await controller.ready;
    if (!mounted) {
      return;
    }
    await controller.startSession(widget.packId, forDate: widget.forDate);
  }

  /// Resolves the pack title through the controller's repository (the real
  /// catalog the player renders from), keeping the pack itself for the
  /// attribution sheet's pack-level pass.
  Future<void> _loadPackTitle() async {
    final SessionPlayerController controller = _controller;
    try {
      final List<ContentPack> packs = await controller.repository.loadPacks();
      if (!mounted) {
        return;
      }
      ContentPack? resolved;
      for (final ContentPack pack in packs) {
        if (pack.id == widget.packId) {
          resolved = pack;
        }
      }
      setState(() {
        _pack = resolved;
        _packTitle = resolved?.title;
      });
    } catch (e, stackTrace) {
      AppLogger.error(
        'Failed to resolve the pack title for "${widget.packId}"',
        e,
        stackTrace,
        'SESSION',
      );
    }
  }

  /// The controller of this screen's pack (read-only use outside build).
  SessionPlayerController get _controller =>
      ref.read(sessionPlayerControllerProvider(widget.packId).notifier);

  /// The step actions the renderers consume: the controller's transitions.
  SessionStepActions _buildActions() {
    final SessionPlayerController controller = _controller;
    return SessionStepActions(
      onAdvance: controller.completeStep,
      onRecord: controller.record,
      onToggleCheckpoint: controller.toggleCheckpoint,
      onTickReflection: controller.tickReflection,
    );
  }

  /// The header's day label: the day variant's own title (the novena
  /// variants carry theirs), else the day token, else the session's started
  /// day (the deep link's `forDate` when given, the additive
  /// `SessionPlayerState.day` otherwise).
  String? _dayLabel(SessionPlayerState state) {
    final Object? variantTitle = state.variant['title'];
    if (variantTitle is String && variantTitle.isNotEmpty) {
      return variantTitle;
    }
    final String? dayToken = state.tokens['day'];
    if (dayToken != null && dayToken.isNotEmpty) {
      return 'Day $dayToken';
    }
    final DateTime? sessionDay = state.day ?? widget.forDate;
    if (sessionDay != null) {
      return _formatSessionDay(sessionDay);
    }
    return null;
  }

  /// The `MMMM d, yyyy` rendering of a local-midnight session day.
  String _formatSessionDay(DateTime forDate) {
    final DateTime day = DateTime(forDate.year, forDate.month, forDate.day);
    return '${_monthNames[day.month - 1]} ${day.day}, ${day.year}';
  }

  /// The player's app bar with the attribution action for viewed text.
  PreferredSizeWidget _buildAppBar(SessionPlayerState state) {
    final bool showAttribution = state.status == SessionPlayerStatus.active;
    return AppBar(
      title: Text(_packTitle ?? 'Session'),
      actions: <Widget>[
        if (showAttribution)
          IconButton(
            key: const Key('session_attribution_action'),
            tooltip: 'Attribution',
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              final int through = state.session.isComplete
                  ? state.script.steps.length - 1
                  : state.session.stepIndex;
              showAttributionSheet(
                context,
                attributionEntriesFor(state.script, through, pack: _pack),
              );
            },
          ),
      ],
    );
  }

  /// "Back to Today": the root route — the Today deep link this screen is
  /// reached from. (Fix round 1, review finding 4: go_router 15 does not
  /// throw on a missing router above a widget-test host — its assert fires
  /// instead — so there is no catch-and-pop fallback to keep; every
  /// production install carries the app router.)
  void _backToToday() {
    context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final SessionPlayerState state = ref.watch(
      sessionPlayerControllerProvider(widget.packId),
    );
    return Scaffold(
      appBar: _buildAppBar(state),
      body: switch (state.status) {
        SessionPlayerStatus.idle || SessionPlayerStatus.loading => const Center(
          child: CircularProgressIndicator(),
        ),
        SessionPlayerStatus.error => _ErrorCard(
          message: state.errorMessage ?? 'The session could not be opened.',
          onRetry: () {
            _controller.startSession(widget.packId);
          },
        ),
        SessionPlayerStatus.finalized => _CompletionSummary(
          state: state,
          packId: widget.packId,
          repository: _controller.repository,
          onBackToToday: _backToToday,
        ),
        SessionPlayerStatus.active => _activeBody(state),
      },
    );
  }

  /// The active player body: progress header, the missing-items banner when
  /// the gate holds, and the current step's card.
  Widget _activeBody(SessionPlayerState state) {
    final SessionPlayerController controller = _controller;
    final int stepCount = state.session.stepCount;
    final int stepIndex = state.session.stepIndex;
    final SessionStep? currentStep = state.currentStep;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                state.session.isComplete
                    ? 'Complete'
                    : 'Step ${stepIndex + 1} of $stepCount',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              if (_dayLabel(state) case final String label?)
                Text(label, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: stepCount <= 0
                    ? 0
                    : (stepIndex / stepCount).clamp(0.0, 1.0),
              ),
            ],
          ),
        ),
        if (state.session.isComplete && !state.isFinalizable)
          _MissingItemsBanner(
            items: state.missingRequiredItems,
            onToggle: (String item) {
              controller.toggleCheckpoint(item);
            },
          ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: switch (currentStep) {
              null when state.session.isComplete => const Center(
                // The finalize write is in flight (a transient window) — a
                // plain label, NOT a spinning indeterminate indicator, so
                // pump-and-settle hosts never hang on it.
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('Finalizing…'),
                ),
              ),
              null => const SizedBox.shrink(),
              _ => sessionStepView(
                context: context,
                ref: ref,
                state: state,
                stepIndex: state.session.stepIndex,
                actions: _buildActions(),
              ),
            },
          ),
        ),
      ],
    );
  }
}

/// The "walk finished but the gate holds" banner: the required items still
/// missing, each one tappable to record it (which retries finalization).
class _MissingItemsBanner extends StatelessWidget {
  const _MissingItemsBanner({required this.items, required this.onToggle});

  final List<String> items;
  final void Function(String item) onToggle;

  @override
  Widget build(BuildContext context) {
    return Card(
      key: const Key('session_missing_banner'),
      color: Theme.of(context).colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'This devotion cannot complete without the following — tap one '
              'to record it:',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: <Widget>[
                for (final String item in items)
                  ActionChip(
                    key: Key('session_missing_item_$item'),
                    label: Text(item),
                    onPressed: () => onToggle(item),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The error card for a failed load (unknown pack, substitution leak):
/// the message plus a retry through the controller.
class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(Icons.error_outline, size: 48),
              const SizedBox(height: 12),
              const Text('Could not open this session'),
              const SizedBox(height: 8),
              Text(message),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: onRetry,
                child: const Text('Try again'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The completion summary: pack/family title, the day variant's phase
/// banner when present, the ordinal and badge callout read from the REAL
/// persisted progress, and "Back to Today".
class _CompletionSummary extends StatefulWidget {
  const _CompletionSummary({
    required this.state,
    required this.packId,
    required this.repository,
    required this.onBackToToday,
  });

  final SessionPlayerState state;
  final String packId;
  final ProgramRepository repository;
  final VoidCallback onBackToToday;

  @override
  State<_CompletionSummary> createState() => _CompletionSummaryState();
}

class _CompletionSummaryState extends State<_CompletionSummary> {
  /// The persisted progress the (already-landed) completion wrote; read
  /// once for the ordinal and the badge callout.
  ProgressState? _progress;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadProgress();
    });
  }

  Future<void> _loadProgress() async {
    try {
      final ProgressState? progress = await widget.repository.progressFor(
        widget.packId,
      );
      if (!mounted) {
        return;
      }
      setState(() => _progress = progress);
    } catch (e, stackTrace) {
      AppLogger.error(
        'Failed to read the persisted completion of "${widget.packId}"',
        e,
        stackTrace,
        'SESSION',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final Object? phase = widget.state.variant['phase'];
    final List<BadgeRecord> badges = _progress?.badges ?? const <BadgeRecord>[];
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Card(
          key: const Key('session_completion_summary'),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Icon(Icons.emoji_events_outlined, size: 48),
                const SizedBox(height: 12),
                Text(
                  'Session complete',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                if (phase is String && phase.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Phase: $phase',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ),
                if (_progress != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Completion ${_progress!.fulfilledOrdinals}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                if (badges.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Badge earned: ${badges.last.title}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: widget.onBackToToday,
                  child: const Text('Back to Today'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
