import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/fast_session.dart';
import '../../providers/fast_session_providers.dart';
import '../../providers/fast_type_providers.dart';
import '../../repositories/fasting_repository.dart';
import '../../services/encouragement_service.dart';
import '../../services/timer_service.dart';

class ActiveFastScreen extends ConsumerStatefulWidget {
  const ActiveFastScreen({super.key});

  @override
  ConsumerState<ActiveFastScreen> createState() => _ActiveFastScreenState();
}

class _ActiveFastScreenState extends ConsumerState<ActiveFastScreen> {
  @override
  void initState() {
    super.initState();
    // Sync timer service with active session
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(timerServiceProvider).syncWithActiveSession();
    });
  }

  @override
  Widget build(BuildContext context) {
    final activeSessionAsync = ref.watch(activeFastSessionProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Active Fast'),
        actions: [
          IconButton(
            icon: const Icon(Icons.favorite_outline),
            onPressed: () {
              // TODO: Show encouragement dialog
              _showEncouragementDialog(context);
            },
            tooltip: 'Get Encouragement',
          ),
        ],
      ),
      body: activeSessionAsync.when(
        data: (session) {
          if (session == null) {
            return _NoActiveFastView();
          }
          return _ActiveFastView(session: session);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => _ErrorView(error: error),
      ),
    );
  }

  Future<void> _showEncouragementDialog(BuildContext context) async {
    final encouragementService = ref.read(encouragementServiceProvider);
    final encouragement = await encouragementService.checkForAutoEncouragement();

    if (!mounted) return;

    if (encouragement != null) {
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(encouragement.attribution ?? 'Encouragement'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(encouragement.content),
                if (encouragement.relatedScripture != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    encouragement.relatedScripture!,
                    style: const TextStyle(
                      fontStyle: FontStyle.italic,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      }
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Keep going! You are doing great!'),
          ),
        );
      }
    }
  }
}

class _ActiveFastView extends ConsumerWidget {
  final FastSession session;

  const _ActiveFastView({required this.session});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timerService = ref.watch(timerServiceProvider);

    // Watch timer tick to trigger rebuilds every second
    ref.watch(timerTickProvider);

    final elapsed = timerService.getElapsedTime(session);
    final remaining = timerService.getRemainingTime(session);
    final progress = timerService.getProgress(session);
    final hasReached = timerService.hasReachedTarget(session);

    // Check if this is an open-ended fast
    final isOpenEnded = session.fastTypeId == 'open_ended';

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(activeFastSessionProvider);
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Timer Display Card
          Card(
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // Large elapsed time display
                  Text(
                    isOpenEnded ? 'Time Fasting' : 'Elapsed Time',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    timerService.formatDuration(elapsed),
                    style: Theme.of(context).textTheme.displayLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontFeatures: [const FontFeature.tabularFigures()],
                        ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    timerService.formatDurationHuman(elapsed),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                  const SizedBox(height: 24),

                  if (!isOpenEnded) ...[
                    // Progress bar (only for timed fasts)
                    LinearProgressIndicator(
                      value: progress,
                      minHeight: 12,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${(progress * 100).toStringAsFixed(1)}% Complete',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 24),

                    // Remaining time
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Column(
                          children: [
                            Text(
                              'Remaining',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              timerService.formatDurationHuman(remaining),
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        Column(
                          children: [
                            Text(
                              'Target',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              timerService.formatDurationHuman(
                                Duration(minutes: session.targetDurationMinutes),
                              ),
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    if (hasReached) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green[50],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check_circle, color: Colors.green[700]),
                            const SizedBox(width: 8),
                            Text(
                              'Target Reached!',
                              style: TextStyle(
                                color: Colors.green[700],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ] else ...[
                    // Open-ended fast info
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.trending_up,
                            color: Theme.of(context).colorScheme.onSecondaryContainer,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Open-ended fast - finish when you\'re ready',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSecondaryContainer,
                                fontWeight: FontWeight.w500,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Fast Details Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Fast Details',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 16),
                  _DetailRow(
                    icon: Icons.category,
                    label: 'Type',
                    value: session.fastTypeId.replaceAll('_', ' ').toUpperCase(),
                  ),
                  const SizedBox(height: 12),
                  _DetailRow(
                    icon: Icons.schedule,
                    label: 'Started',
                    value: _formatDateTime(session.startTime),
                  ),
                  if (!isOpenEnded) ...[
                    const SizedBox(height: 12),
                    _DetailRow(
                      icon: Icons.event,
                      label: 'Expected End',
                      value: _formatDateTime(
                        session.startTime.add(
                          Duration(minutes: session.targetDurationMinutes),
                        ),
                      ),
                    ),
                  ],
                  if (session.notes != null && session.notes!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Divider(),
                    const SizedBox(height: 12),
                    Text(
                      'Notes',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(session.notes!),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showBreakFastDialog(context, ref, session),
                  icon: const Icon(Icons.cancel),
                  label: const Text('Break Fast'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.orange,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _showCompleteFastDialog(context, ref, session),
                  icon: const Icon(Icons.check_circle),
                  label: const Text('Complete'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.month}/${dateTime.day}/${dateTime.year} ${_formatTime(dateTime)}';
  }

  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour > 12 ? dateTime.hour - 12 : dateTime.hour;
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final period = dateTime.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  void _showBreakFastDialog(
    BuildContext context,
    WidgetRef ref,
    FastSession session,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Break Fast?'),
        content: const Text(
          'Are you sure you want to break this fast? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              final notifier = ref.read(activeFastSessionProvider.notifier);
              await notifier.breakFast(notes: 'Broken by user');
              if (context.mounted) {
                Navigator.of(context).pop(); // Return to home
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Fast has been broken')),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
            ),
            child: const Text('Break Fast'),
          ),
        ],
      ),
    );
  }

  void _showCompleteFastDialog(
    BuildContext context,
    WidgetRef ref,
    FastSession session,
  ) {
    final isOpenEnded = session.fastTypeId == 'open_ended';

    if (isOpenEnded) {
      _showOpenEndedCompleteFastDialog(context, ref, session);
    } else {
      _showStandardCompleteFastDialog(context, ref, session);
    }
  }

  void _showStandardCompleteFastDialog(
    BuildContext context,
    WidgetRef ref,
    FastSession session,
  ) {
    final notesController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Complete Fast?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Congratulations on completing your fast!'),
            const SizedBox(height: 16),
            TextField(
              controller: notesController,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                hintText: 'How did it go?',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              final notifier = ref.read(activeFastSessionProvider.notifier);
              await notifier.completeFast(
                notes: notesController.text.isEmpty ? null : notesController.text,
              );
              if (context.mounted) {
                Navigator.of(context).pop(); // Return to home
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Fast completed! Great job!')),
                );
              }
            },
            child: const Text('Complete'),
          ),
        ],
      ),
    );
  }

  void _showOpenEndedCompleteFastDialog(
    BuildContext context,
    WidgetRef ref,
    FastSession session,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) => _OpenEndedCompleteDialog(
        session: session,
        ref: ref,
      ),
    );
  }
}

class _OpenEndedCompleteDialog extends ConsumerStatefulWidget {
  final FastSession session;
  final WidgetRef ref;

  const _OpenEndedCompleteDialog({
    required this.session,
    required this.ref,
  });

  @override
  ConsumerState<_OpenEndedCompleteDialog> createState() =>
      _OpenEndedCompleteDialogState();
}

class _OpenEndedCompleteDialogState
    extends ConsumerState<_OpenEndedCompleteDialog> {
  String? _selectedFastTypeId;
  final _notesController = TextEditingController();

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final timerService = ref.watch(timerServiceProvider);
    final elapsed = timerService.getElapsedTime(widget.session);
    final elapsedHours = elapsed.inMinutes / 60;

    final allFastTypesAsync = ref.watch(allFastTypesProvider);

    return AlertDialog(
      title: const Text('Complete Open-Ended Fast'),
      content: allFastTypesAsync.when(
        data: (fastTypes) {
          // Filter out the open_ended type and suggest based on duration
          final categorizableTypes = fastTypes
              .where((ft) => ft.id != 'open_ended' && ft.targetDurationHours != null)
              .toList();

          // Sort by how close the duration is to the elapsed time
          categorizableTypes.sort((a, b) {
            final aDiff = (a.targetDurationHours! - elapsedHours).abs();
            final bDiff = (b.targetDurationHours! - elapsedHours).abs();
            return aDiff.compareTo(bDiff);
          });

          // Take top 5 suggestions
          final suggestions = categorizableTypes.take(5).toList();

          return SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'You fasted for ${timerService.formatDurationHuman(elapsed)}!',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                ),
                const SizedBox(height: 16),
                const Text('How would you like to categorize this fast?'),
                const SizedBox(height: 16),

                // Keep as Open-Ended option
                RadioListTile<String>(
                  value: 'open_ended',
                  groupValue: _selectedFastTypeId ?? 'open_ended',
                  onChanged: (value) {
                    setState(() {
                      _selectedFastTypeId = value;
                    });
                  },
                  title: const Text('Keep as Open-Ended Fast'),
                  subtitle: const Text('Don\'t categorize this fast'),
                ),

                const Divider(),
                const SizedBox(height: 8),
                Text(
                  'Suggested Categories',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),

                // Suggested fast types
                ...suggestions.map((ft) {
                  final isRecommended = suggestions.indexOf(ft) == 0;
                  return RadioListTile<String>(
                    value: ft.id,
                    groupValue: _selectedFastTypeId ?? 'open_ended',
                    onChanged: (value) {
                      setState(() {
                        _selectedFastTypeId = value;
                      });
                    },
                    title: Row(
                      children: [
                        Expanded(child: Text(ft.name)),
                        if (isRecommended)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'BEST MATCH',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                    subtitle: Text(
                      '${ft.targetDurationHours} hours',
                      style: const TextStyle(fontSize: 12),
                    ),
                  );
                }),

                const SizedBox(height: 16),
                TextField(
                  controller: _notesController,
                  decoration: const InputDecoration(
                    labelText: 'Notes (optional)',
                    hintText: 'How did it go?',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
              ],
            ),
          );
        },
        loading: () => const Center(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: CircularProgressIndicator(),
          ),
        ),
        error: (error, stack) => Text('Error loading fast types: $error'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () async {
            Navigator.of(context).pop();

            // Update the session's fast type if user selected a different one
            final finalFastTypeId = _selectedFastTypeId ?? 'open_ended';

            if (finalFastTypeId != 'open_ended') {
              // Update the fast type in the database before completing
              await FastingRepository.instance.updateFastSessionType(
                widget.session.id,
                finalFastTypeId,
              );
            }

            // Complete the fast
            final notifier =
                widget.ref.read(activeFastSessionProvider.notifier);
            await notifier.completeFast(
              notes: _notesController.text.isEmpty ? null : _notesController.text,
            );

            if (context.mounted) {
              Navigator.of(context).pop(); // Return to home
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    finalFastTypeId == 'open_ended'
                        ? 'Fast completed!'
                        : 'Fast completed and categorized!',
                  ),
                  backgroundColor: Colors.green,
                ),
              );
            }
          },
          child: const Text('Complete'),
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _NoActiveFastView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.restaurant_menu,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 24),
          Text(
            'No Active Fast',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Start a new fast to begin tracking',
            style: TextStyle(color: Colors.grey[600]),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
            },
            icon: const Icon(Icons.arrow_back),
            label: const Text('Go Back'),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final Object error;

  const _ErrorView({required this.error});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text(
            'Error',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              error.toString(),
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back),
            label: const Text('Go Back'),
          ),
        ],
      ),
    );
  }
}
