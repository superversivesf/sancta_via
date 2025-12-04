import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/fast_session.dart';
import '../../models/fast_status.dart';
import '../../providers/encouragement_providers.dart';
import '../../providers/fast_type_providers.dart';
import '../../services/timer_service.dart';

class FastDetailScreen extends ConsumerStatefulWidget {
  final String sessionId;

  const FastDetailScreen({
    required this.sessionId,
    super.key,
  });

  @override
  ConsumerState<FastDetailScreen> createState() => _FastDetailScreenState();
}

class _FastDetailScreenState extends ConsumerState<FastDetailScreen> {
  final _notesController = TextEditingController();
  bool _isEditingNotes = false;
  bool _isSaving = false;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<FastSession?> _loadSession() async {
    final repository = ref.read(fastingRepositoryProvider);
    final history = await repository.getFastHistory();
    return history.firstWhere(
      (session) => session.id == widget.sessionId,
      orElse: () => throw Exception('Session not found'),
    );
  }

  Future<void> _saveNotes(FastSession session) async {
    setState(() => _isSaving = true);

    try {
      final repository = ref.read(fastingRepositoryProvider);
      final updated = session.copyWith(notes: _notesController.text);
      await repository.updateFastSession(updated);

      if (mounted) {
        setState(() {
          _isEditingNotes = false;
          _isSaving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Notes saved')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving notes: $e')),
        );
      }
    }
  }

  Future<void> _deleteSession() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Fast Session?'),
        content: const Text(
          'This will permanently delete this fast session. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        final repository = ref.read(fastingRepositoryProvider);
        await repository.deleteFastSession(widget.sessionId);

        if (mounted) {
          context.pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Fast session deleted')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting session: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fast Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: _deleteSession,
            tooltip: 'Delete Fast',
          ),
        ],
      ),
      body: FutureBuilder<FastSession?>(
        future: _loadSession(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading session',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(snapshot.error.toString()),
                ],
              ),
            );
          }

          final session = snapshot.data;
          if (session == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.search_off, size: 64),
                  const SizedBox(height: 16),
                  Text(
                    'Session not found',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ],
              ),
            );
          }

          // Initialize notes controller with session notes
          if (_notesController.text.isEmpty && session.notes != null) {
            _notesController.text = session.notes!;
          }

          return _buildContent(session);
        },
      ),
    );
  }

  Widget _buildContent(FastSession session) {
    final timerService = ref.watch(timerServiceProvider);
    final allFastTypesAsync = ref.watch(allFastTypesProvider);

    final duration = session.endTime != null
        ? session.endTime!.difference(session.startTime)
        : Duration.zero;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Status Badge
        _buildStatusBadge(session.status),
        const SizedBox(height: 24),

        // Fast Type Information
        allFastTypesAsync.when(
          data: (fastTypes) {
            final fastType = fastTypes.firstWhere(
              (ft) => ft.id == session.fastTypeId,
              orElse: () => fastTypes.first,
            );
            return _buildFastTypeCard(fastType.name, fastType.description);
          },
          loading: () => const SizedBox.shrink(),
          error: (error, stack) => const SizedBox.shrink(),
        ),

        const SizedBox(height: 16),

        // Timeline Card
        _buildTimelineCard(session, duration, timerService),

        const SizedBox(height: 16),

        // Statistics Card
        _buildStatisticsCard(session, duration, timerService),

        const SizedBox(height: 16),

        // Notes Card
        _buildNotesCard(session),

        const SizedBox(height: 16),

        // Encouragements Card
        if (session.encouragementsShown.isNotEmpty)
          _buildEncouragementsCard(session),

        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildStatusBadge(FastStatus status) {
    Color color;
    IconData icon;
    String text;

    switch (status) {
      case FastStatus.completed:
        color = Colors.green;
        icon = Icons.check_circle;
        text = 'Completed';
        break;
      case FastStatus.broken:
        color = Colors.orange;
        icon = Icons.cancel;
        text = 'Broken';
        break;
      case FastStatus.active:
        color = Colors.blue;
        icon = Icons.play_circle;
        text = 'Active';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color, width: 2),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 12),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFastTypeCard(String name, String? description) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.category,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Fast Type',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              name,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (description != null) ...[
              const SizedBox(height: 8),
              Text(
                description,
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineCard(
    FastSession session,
    Duration duration,
    TimerService timerService,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.timeline,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Timeline',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Start Time
            _buildTimelineRow(
              Icons.play_arrow,
              'Started',
              _formatDateTime(session.startTime),
            ),
            const SizedBox(height: 12),

            // End Time
            if (session.endTime != null)
              _buildTimelineRow(
                Icons.stop,
                'Ended',
                _formatDateTime(session.endTime!),
              ),
            if (session.endTime != null) const SizedBox(height: 12),

            // Duration
            _buildTimelineRow(
              Icons.timer,
              'Duration',
              timerService.formatDurationHuman(duration),
            ),
            const SizedBox(height: 12),

            // Target Duration
            _buildTimelineRow(
              Icons.flag,
              'Target',
              '${(session.targetDurationMinutes / 60).toStringAsFixed(1)} hours',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 12),
        Text(
          '$label:',
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Widget _buildStatisticsCard(
    FastSession session,
    Duration duration,
    TimerService timerService,
  ) {
    final progress = session.progressPercentage;
    final hasReached = session.hasReachedTarget;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.analytics,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Statistics',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Progress Percentage
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Progress:',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                Text(
                  '${(progress * 100).toStringAsFixed(1)}%',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 16),

            // Target Reached
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Target Reached:',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                Row(
                  children: [
                    Icon(
                      hasReached ? Icons.check_circle : Icons.cancel,
                      color: hasReached ? Colors.green : Colors.grey,
                      size: 20,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      hasReached ? 'Yes' : 'No',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: hasReached ? Colors.green : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Hours Fasted
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Hours Fasted:',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                Text(
                  duration.inHours.toString(),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotesCard(FastSession session) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.note,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Notes',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
                if (!_isEditingNotes)
                  IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () => setState(() => _isEditingNotes = true),
                    tooltip: 'Edit Notes',
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (_isEditingNotes)
              Column(
                children: [
                  TextField(
                    controller: _notesController,
                    decoration: const InputDecoration(
                      hintText: 'Add notes about this fast...',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 5,
                    enabled: !_isSaving,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: _isSaving
                            ? null
                            : () {
                                setState(() {
                                  _isEditingNotes = false;
                                  _notesController.text = session.notes ?? '';
                                });
                              },
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _isSaving ? null : () => _saveNotes(session),
                        child: _isSaving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Save'),
                      ),
                    ],
                  ),
                ],
              )
            else
              Text(
                session.notes?.isNotEmpty == true
                    ? session.notes!
                    : 'No notes added',
                style: TextStyle(
                  color: session.notes?.isNotEmpty == true
                      ? null
                      : Colors.grey[600],
                  fontStyle: session.notes?.isNotEmpty == true
                      ? null
                      : FontStyle.italic,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEncouragementsCard(FastSession session) {
    final encouragementsAsync = ref.watch(allEncouragementsProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.favorite,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Encouragements Received',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            encouragementsAsync.when(
              data: (allEncouragements) {
                final shownEncouragements = allEncouragements
                    .where((e) => session.encouragementsShown.contains(e.id))
                    .toList();

                if (shownEncouragements.isEmpty) {
                  return const Text(
                    'No encouragements were shown during this fast',
                    style: TextStyle(
                      fontStyle: FontStyle.italic,
                      color: Colors.grey,
                    ),
                  );
                }

                return Column(
                  children: shownEncouragements.map((encouragement) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .primaryContainer
                            .withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                _getEncouragementIcon(encouragement.category.toString()),
                                size: 16,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _formatCategoryName(encouragement.category.toString()),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            encouragement.content,
                            style: const TextStyle(fontSize: 14),
                          ),
                          if (encouragement.attribution != null) ...[
                            const SizedBox(height: 6),
                            Text(
                              '— ${encouragement.attribution}',
                              style: TextStyle(
                                fontSize: 12,
                                fontStyle: FontStyle.italic,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (error, stack) => Text(
                'Error loading encouragements',
                style: TextStyle(color: Colors.red[700]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getEncouragementIcon(String category) {
    if (category.contains('scripture')) return Icons.menu_book;
    if (category.contains('saint')) return Icons.person;
    if (category.contains('prayer')) return Icons.church;
    return Icons.favorite;
  }

  String _formatCategoryName(String category) {
    return category
        .replaceAll('EncouragementCategory.', '')
        .replaceAll('_', ' ')
        .split(' ')
        .map((word) => word.isEmpty ? '' : word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.month}/${dateTime.day}/${dateTime.year} at ${_formatTime(dateTime)}';
  }

  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour > 12 ? dateTime.hour - 12 : dateTime.hour;
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final period = dateTime.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }
}
