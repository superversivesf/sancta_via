import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
                    onPressed: () async {
                      final notifier = ref.read(
                        activeFastSessionProvider.notifier,
                      );
                      await notifier.completeFast(
                        notes: 'Completed from home screen',
                      );
                    },
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
          // TODO: Navigate to fast detail screen
        },
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year}';
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
