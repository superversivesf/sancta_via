import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sancta_via_liturgical_calendar_riverpod/sancta_via_liturgical_calendar_riverpod.dart';

import '../../providers/fast_session_providers.dart';
import '../../providers/statistics_providers.dart';
import '../../services/timer_service.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeSessionAsync = ref.watch(activeFastSessionProvider);
    final statsAsync = ref.watch(dashboardStatisticsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sancta Via Fasting'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              context.push('/settings');
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(activeFastSessionProvider);
          ref.invalidate(dashboardStatisticsProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Liturgical Day Card
            _LiturgicalDayCard(),

            const SizedBox(height: 24),

            // Active Fast Section
            activeSessionAsync.when(
              data: (session) {
                if (session != null) {
                  return _ActiveFastCard(session: session);
                } else {
                  return _NoActiveFastCard();
                }
              },
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (error, stack) => _ErrorCard(error: error),
            ),

            const SizedBox(height: 24),

            // Quick Stats Section
            statsAsync.when(
              data: (stats) => _QuickStatsSection(stats: stats),
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (error, stack) => _ErrorCard(error: error),
            ),

            const SizedBox(height: 24),

            // Recent History Preview
            const Text(
              'Recent Fasts',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _RecentHistoryPreview(),
          ],
        ),
      ),
      floatingActionButton: activeSessionAsync.when(
        data: (session) {
          if (session == null) {
            return FloatingActionButton.extended(
              onPressed: () {
                context.push('/start-fast');
              },
              icon: const Icon(Icons.add),
              label: const Text('Start Fast'),
            );
          }
          return null;
        },
        loading: () => null,
        error: (error, stack) => null,
      ),
    );
  }
}

/// Show confirmation dialog before completing a fast
void _showCompleteConfirmation(BuildContext context, WidgetRef ref) {
  showDialog(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Complete Fast?'),
      content: const Text(
        'Are you sure you want to complete this fast? This action cannot be undone.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () async {
            Navigator.of(dialogContext).pop();

            final notifier = ref.read(
              activeFastSessionProvider.notifier,
            );
            await notifier.completeFast(
              notes: 'Completed from home screen',
            );

            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Fast completed successfully!'),
                  backgroundColor: Colors.green,
                ),
              );
            }
          },
          child: const Text('Complete'),
        ),
      ],
    ),
  );
}

class _ActiveFastCard extends ConsumerWidget {
  final dynamic session;

  const _ActiveFastCard({required this.session});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timerService = ref.watch(timerServiceProvider);

    // Watch timer tick to trigger rebuilds every second
    ref.watch(timerTickProvider);

    final elapsed = timerService.getElapsedTime(session);
    final progress = timerService.getProgress(session);
    final remaining = timerService.getRemainingTime(session);

    // Check if this is an open-ended fast
    final isOpenEnded = session.fastTypeId == 'open_ended';

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isOpenEnded ? Icons.trending_up : Icons.timer,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  isOpenEnded ? 'Open-Ended Fast' : 'Active Fast',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (!isOpenEnded) ...[
              LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                borderRadius: BorderRadius.circular(4),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Elapsed',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                      Text(
                        timerService.formatDurationHuman(elapsed),
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text(
                        'Remaining',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                      Text(
                        timerService.formatDurationHuman(remaining),
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ] else ...[
              // Open-ended fast display
              Column(
                children: [
                  const Text(
                    'Time Fasting',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    timerService.formatDurationHuman(elapsed),
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      'No set target',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSecondaryContainer,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      context.push('/active-fast');
                    },
                    icon: const Icon(Icons.visibility),
                    label: const Text('View'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _showCompleteConfirmation(context, ref),
                    icon: const Icon(Icons.check),
                    label: const Text('Complete'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _NoActiveFastCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(
              Icons.restaurant_menu,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No Active Fast',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Start a new fast to begin tracking',
              style: TextStyle(
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickStatsSection extends StatelessWidget {
  final dynamic stats;

  const _QuickStatsSection({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Stats',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                icon: Icons.check_circle,
                label: 'Completed',
                value: stats.completedFastsCount.toString(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                icon: Icons.access_time,
                label: 'Total Hours',
                value: stats.totalHoursFasted.toStringAsFixed(1),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                icon: Icons.local_fire_department,
                label: 'Current Streak',
                value: stats.currentStreak.toString(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                icon: Icons.emoji_events,
                label: 'Longest Streak',
                value: stats.longestStreak.toString(),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentHistoryPreview extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(fastHistoryProvider);

    return historyAsync.when(
      data: (history) {
        if (history.isEmpty) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text(
                  'No fast history yet',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ),
            ),
          );
        }

        final recentFasts = history.take(3).toList();
        return Column(
          children: [
            ...recentFasts.map((fast) => _HistoryTile(fast: fast)),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                context.push('/history');
              },
              child: const Text('View All History'),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => _ErrorCard(error: error),
    );
  }
}

class _HistoryTile extends ConsumerWidget {
  final dynamic fast;

  const _HistoryTile({required this.fast});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timerService = ref.watch(timerServiceProvider);
    final duration = fast.endTime != null
        ? fast.endTime!.difference(fast.startTime)
        : Duration.zero;

    return Card(
      child: ListTile(
        leading: Icon(
          fast.status.toString().contains('completed')
              ? Icons.check_circle
              : Icons.cancel,
          color: fast.status.toString().contains('completed')
              ? Colors.green
              : Colors.orange,
        ),
        title: Text(fast.fastTypeId),
        subtitle: Text(
          '${timerService.formatDurationHuman(duration)} • ${_formatDate(fast.startTime)}',
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          context.push('/fast-detail/${fast.id}');
        },
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year}';
  }
}

class _LiturgicalDayCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentDay = ref.watch(currentLiturgicalDayProvider);
    final liturgicalColor = ref.watch(liturgicalColorProvider);
    final seasonIcon = ref.watch(seasonIconProvider);

    if (currentDay == null) {
      return const SizedBox.shrink();
    }

    return Card(
      elevation: 2,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [
              liturgicalColor.withAlpha(25),
              liturgicalColor.withAlpha(10),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(
            color: liturgicalColor.withAlpha(80),
            width: 2,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: liturgicalColor.withAlpha(50),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  seasonIcon,
                  color: liturgicalColor,
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            currentDay.celebration.name,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: liturgicalColor,
                                ),
                          ),
                        ),
                        if (currentDay.celebration.prioritized)
                          Icon(
                            Icons.star,
                            color: Colors.amber,
                            size: 20,
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      currentDay.season,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                    if (currentDay.celebration.rank != 'Ordinary') ...[
                      const SizedBox(height: 4),
                      Text(
                        currentDay.celebration.rank,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[500],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final Object error;

  const _ErrorCard({required this.error});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.red[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.red),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Error: ${error.toString()}',
                style: const TextStyle(color: Colors.red),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
