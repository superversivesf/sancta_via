// The Progress tab's screen (Plan 2, Task 16).
//
// One section per enrolled program — the position chip, the series phase
// banner, the commitment projection line, the missed-day verdict (with the
// ruled Apply affordance) and the dated badges — under one lifetime header,
// with the intentions editor and the indulgence explainer. Everything renders
// from the assembled data of `progressAssemblyProvider` (see its library
// docs): the engine's projections and verdicts, the packs' own variant
// phases, the persisted progress. No per-pack special cases.
//
// The shell branch already points at `/progress` (Task 14's four-branch
// shell); this screen replaces the Task-1 placeholder at the same file path.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sancta_via_devotional_engine/sancta_via_devotional_engine.dart'
    show BadgeRecord, MissedDayVerdict, PackFamily;
import 'package:sancta_via_devotional_engine_riverpod/sancta_via_devotional_engine_riverpod.dart'
    show enrolledProgramsProvider, programDetailProvider;

import '../../database/devotionals_database.dart' show IntentionRow;
import '../../providers/content_providers.dart'
    show appProgramRepositoryProvider, intentionsProvider;
import '../../providers/progress_providers.dart'
    show ProgressAssembly, ProgressEntry, progressAssemblyProvider;
import '../../repositories/program_repository.dart'
    show SqliteProgramRepository;
import '../../services/progress_service.dart' show ProgressService;
import '../../utils/logger.dart';
import '../../widgets/progress/badge_list.dart';
import '../../widgets/progress/indulgence_sheet.dart' as indulgence_sheet;
import '../../widgets/progress/phase_banner.dart';
import '../../widgets/today/today_section_card.dart';

/// The month abbreviations of the projection line (`next: Dec 5, Jan 2, …`).
const List<String> _monthAbbreviations = <String>[
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// The short label of a projected anchor date (`Dec 5`).
String _shortDate(DateTime d) => '${_monthAbbreviations[d.month - 1]} ${d.day}';

/// The projected anchor dates, listed after `next: ` (the
/// `Projection.remainingDates` line; the engine guarantees a completed
/// commitment's empty list, so the whole line disappears on completion).
String _projectionLine(List<DateTime> dates) =>
    'next: ${dates.map(_shortDate).join(', ')}';

/// The family icon of a program row (the Today tile's own mapping).
IconData _familyIcon(PackFamily family) => switch (family) {
  PackFamily.commitment => Icons.flag,
  PackFamily.novena => Icons.event_repeat,
  PackFamily.office => Icons.menu_book,
  PackFamily.routine => Icons.schedule,
  PackFamily.chaplet => Icons.blur_circular,
};

/// The app's Progress tab.
class ProgressScreen extends ConsumerWidget {
  /// Creates the screen.
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<ProgressAssembly> assembly = ref.watch(
      progressAssemblyProvider,
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Progress')),
      body: assembly.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object error, StackTrace stack) {
          AppLogger.error('Progress tab failed', error, stack, 'PROGRESS');
          return const Center(
            child: Text(
              'Progress could not be loaded. Try reopening the app.',
              textAlign: TextAlign.center,
            ),
          );
        },
        data: (ProgressAssembly data) => _ProgressBody(assembly: data),
      ),
    );
  }
}

/// The body behind the resolved assembly: the lifetime header, the programs'
/// cards, and the intentions editor.
class _ProgressBody extends ConsumerStatefulWidget {
  const _ProgressBody({required this.assembly});

  final ProgressAssembly assembly;

  @override
  ConsumerState<_ProgressBody> createState() => _ProgressBodyState();
}

class _ProgressBodyState extends ConsumerState<_ProgressBody> {
  /// Applies the surfaced missed-day verdict for [packId] through Task 9's
  /// service — the ruled affordance: applying a strict gap clears the
  /// streak COUNT (the badge history and the schedule stay). The affected
  /// reads then re-resolve (the wrapper's progress list, the pack's
  /// projection, and this tab's assembly).
  Future<void> _applyMissedDay(String packId) async {
    final SqliteProgramRepository repository = ref.read(
      appProgramRepositoryProvider,
    );
    try {
      await ProgressService(
        repository: repository,
      ).applyMissedDay(packId: packId, verdict: MissedDayVerdict.reset);
    } catch (e, stackTrace) {
      AppLogger.error(
        'Failed to apply the missed-day reset for "$packId"',
        e,
        stackTrace,
        'PROGRESS',
      );
      return;
    }
    if (!mounted) {
      return;
    }
    ref.invalidate(enrolledProgramsProvider);
    ref.invalidate(programDetailProvider(packId));
    ref.invalidate(progressAssemblyProvider);
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: <Widget>[
        _LifetimeHeader(assembly: widget.assembly),
        if (widget.assembly.entries.isEmpty)
          const _EmptyState()
        else
          for (final ProgressEntry entry in widget.assembly.entries)
            _ProgramCard(entry: entry, onApplyMissedDay: _applyMissedDay),
        const _IntentionsSection(),
      ],
    );
  }
}

/// The tab's header: the lifetime completions count (the documented badge
/// total) and the indulgence explainer trigger.
class _LifetimeHeader extends StatelessWidget {
  const _LifetimeHeader({required this.assembly});

  final ProgressAssembly assembly;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Card(
      key: const Key('lifetime_header'),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
        child: Row(
          children: <Widget>[
            Icon(
              Icons.workspace_premium_outlined,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Text(
              '${assembly.lifetimeBadges}',
              key: const Key('lifetime_count'),
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 6),
            Text('lifetime completions', style: theme.textTheme.bodyMedium),
            const Spacer(),
            TextButton.icon(
              key: const Key('indulgence_info'),
              onPressed: () => indulgence_sheet.showIndulgenceSheet(context),
              icon: const Icon(Icons.church_outlined, size: 18),
              label: const Text('Indulgences'),
            ),
          ],
        ),
      ),
    );
  }
}

/// The honest empty state: nothing is enrolled, so there is no progress —
/// the copy points at the Practice tab (the enrollment home) instead of
/// claiming the catalog is empty.
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
      child: Column(
        children: <Widget>[
          Text(
            'No programs to track yet.',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Enroll in a devotion from the Practice tab — your progress, '
            'phases and badges will appear here.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// One enrolled program's card: the position chip, the series phase banner,
/// the projection line, the missed-day verdict, and the dated badges.
class _ProgramCard extends StatelessWidget {
  const _ProgramCard({required this.entry, required this.onApplyMissedDay});

  final ProgressEntry entry;

  /// Applies the entry's surfaced missed-day verdict (the body owns the
  /// write and the re-resolution).
  final Future<void> Function(String packId) onApplyMissedDay;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String? chip = entry.positionLabel;
    return TodaySectionCard(
      key: Key('program_card_${entry.pack.id}'),
      title: entry.pack.title,
      icon: Icon(_familyIcon(entry.pack.family)),
      children: <Widget>[
        if (chip != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Chip(
                key: Key('position_chip_${entry.pack.id}'),
                avatar: Icon(
                  entry.isComplete ? Icons.verified_outlined : Icons.north_east,
                  size: 18,
                ),
                label: Text(chip),
                labelStyle: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        if (entry.seriesPhase != null && entry.seriesDayIndex != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: PhaseBanner(
              key: Key('phase_banner_${entry.pack.id}'),
              phase: entry.seriesPhase!,
              dayIndex: entry.seriesDayIndex!,
              lengthDays: entry.seriesLengthDays!,
            ),
          ),
        if (entry.remainingDates.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: <Widget>[
                Icon(
                  Icons.event_outlined,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _projectionLine(entry.remainingDates),
                    key: Key('projection_line_${entry.pack.id}'),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        if (entry.anchorsCredited case final int credited)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: <Widget>[
                Icon(
                  Icons.fact_check_outlined,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    credited == 1
                        ? '1 anchor day credited'
                        : '$credited anchor days credited',
                    key: Key('anchors_credited_${entry.pack.id}'),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        if (entry.missedVerdict != null)
          _MissedDayCard(entry: entry, onApplyMissedDay: onApplyMissedDay),
        BadgeList(badges: entry.progress?.badges ?? const <BadgeRecord>[]),
      ],
    );
  }
}

/// The missed-day verdict card, in the verdict's own variant (fix round 1):
/// the `reset` state — the strict gap — says exactly what applying does
/// (the streak COUNT clears; badge history and schedule stay) and carries
/// the ruled Apply affordance; the `askUser`-with-ordinals state — a
/// progress claim counted without a completion date — surfaces read-only
/// (the service refuses to apply an `askUser` verdict; nothing to apply).
class _MissedDayCard extends StatelessWidget {
  const _MissedDayCard({required this.entry, required this.onApplyMissedDay});

  final ProgressEntry entry;

  final Future<void> Function(String packId) onApplyMissedDay;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    // The entry carries only surfacable verdicts: reset, and askUser with
    // fulfilled ordinals (the un-anchored claim; see progress_providers).
    final bool isReset = entry.missedVerdict == MissedDayVerdict.reset;
    final Color contentColor = isReset
        ? theme.colorScheme.onErrorContainer
        : theme.colorScheme.onSurfaceVariant;
    return Container(
      key: Key(
        isReset
            ? 'missed_day_${entry.pack.id}'
            : 'unanchored_progress_${entry.pack.id}',
      ),
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isReset
            ? theme.colorScheme.errorContainer
            : theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                isReset ? Icons.event_busy : Icons.anchor_outlined,
                size: 18,
                color: contentColor,
              ),
              const SizedBox(width: 8),
              Text(
                isReset ? 'Missed days' : 'Un-anchored progress',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: contentColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            isReset
                ? 'A due day was missed, and this program\'s missed-day '
                      'policy is strict. Applying clears your streak count — '
                      'your badge history stays.'
                : 'This program\'s progress claim is un-anchored: it counts '
                      'completed days without a recorded last-completed date. '
                      'Complete the next due day to anchor your streak.',
            style: theme.textTheme.bodyMedium?.copyWith(color: contentColor),
          ),
          if (isReset) ...<Widget>[
            const SizedBox(height: 8),
            FilledButton(
              key: Key('apply_missed_day_${entry.pack.id}'),
              onPressed: () => onApplyMissedDay(entry.pack.id),
              child: const Text('Apply reset'),
            ),
          ],
        ],
      ),
    );
  }
}

/// The intentions editor: the list of the user's prayer intentions and
/// departed souls, with add and remove (the Task-4 table's UI — the session
/// player's readout gains add/delete through the same wrapper later).
class _IntentionsSection extends ConsumerStatefulWidget {
  const _IntentionsSection();

  @override
  ConsumerState<_IntentionsSection> createState() => _IntentionsSectionState();
}

class _IntentionsSectionState extends ConsumerState<_IntentionsSection> {
  final TextEditingController _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  /// Adds one entry of [kind] (`'intention'` | `'soul'`) through the
  /// repository wrapper and re-reads the list. A blank field does nothing.
  Future<void> _add(String kind) async {
    final String value = _text.text.trim();
    if (value.isEmpty) {
      return;
    }
    final SqliteProgramRepository repository = ref.read(
      appProgramRepositoryProvider,
    );
    try {
      await repository.database.intentions.add(kind: kind, text: value);
      if (!mounted) {
        return;
      }
      _text.clear();
      ref.invalidate(intentionsProvider);
    } catch (e, stackTrace) {
      AppLogger.error('Failed to add an intention', e, stackTrace, 'PROGRESS');
    }
  }

  /// Removes one entry and re-reads the list.
  Future<void> _remove(String id) async {
    final SqliteProgramRepository repository = ref.read(
      appProgramRepositoryProvider,
    );
    try {
      await repository.database.intentions.remove(id);
      if (!mounted) {
        return;
      }
      ref.invalidate(intentionsProvider);
    } catch (e, stackTrace) {
      AppLogger.error(
        'Failed to remove the intention "$id"',
        e,
        stackTrace,
        'PROGRESS',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<IntentionRow>> intentions = ref.watch(
      intentionsProvider,
    );
    return TodaySectionCard(
      key: const Key('intentions_section'),
      title: 'Intentions',
      icon: const Icon(Icons.volunteer_activism_outlined),
      children: <Widget>[
        intentions.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: SizedBox(
              height: 24,
              width: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
          error: (Object error, StackTrace stack) {
            AppLogger.error('Intentions list failed', error, stack, 'PROGRESS');
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('Intentions are unavailable right now.'),
            );
          },
          data: (List<IntentionRow> rows) => rows.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 4),
                  child: Text('No intentions yet — add one below.'),
                )
              : Column(
                  children: <Widget>[
                    for (final IntentionRow row in rows)
                      ListTile(
                        key: ValueKey<String>('intention_row_${row.id}'),
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          row.kind == 'soul'
                              ? Icons.people_outline
                              : Icons.favorite_outline,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        title: Text(row.text),
                        subtitle: Text(
                          row.kind == 'soul' ? 'Soul' : 'Intention',
                        ),
                        trailing: IconButton(
                          key: Key('remove_intention_${row.id}'),
                          icon: const Icon(Icons.delete_outline),
                          tooltip: 'Remove',
                          onPressed: () => _remove(row.id),
                        ),
                      ),
                  ],
                ),
        ),
        TextField(
          key: const Key('intention_text'),
          controller: _text,
          decoration: const InputDecoration(
            hintText: 'Add an intention or a soul…',
            isDense: true,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: <Widget>[
            FilledButton(
              key: const Key('add_intention'),
              onPressed: () => _add('intention'),
              child: const Text('Add intention'),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              key: const Key('add_soul'),
              onPressed: () => _add('soul'),
              child: const Text('Add a soul'),
            ),
          ],
        ),
      ],
    );
  }
}
