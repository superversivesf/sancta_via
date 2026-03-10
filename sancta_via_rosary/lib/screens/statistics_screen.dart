import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/rosary_stats_provider.dart';
import '../services/rosary_statistics_service.dart';
import '../widgets/statistics/empty_statistics.dart';
import '../widgets/statistics/monthly_chart.dart';
import '../widgets/statistics/recent_sessions_list.dart';
import '../widgets/statistics/stat_card.dart';
import '../widgets/statistics/weekly_chart.dart';

/// Statistics screen displaying rosary prayer progress and analytics
///
/// Shows:
/// - Total rosaries completed
/// - Current streak and longest streak
/// - Total time spent praying
/// - Favorite mystery set
/// - Weekly chart (last 7 days)
/// - Monthly chart (last 4 weeks)
/// - Recent sessions list
class StatisticsScreen extends ConsumerWidget {
  const StatisticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(rosaryStatisticsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Statistics'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.read(statisticsRefreshProvider.notifier).refresh();
            },
            tooltip: 'Refresh statistics',
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(rosaryStatisticsProvider);
          },
          child: statsAsync.when(
            data: (stats) {
              if (!stats.hasData) {
                return EmptyStatistics(
                  onStartPraying: () {
                    // Navigate to rosary screen
                    Navigator.of(context).pushNamed('/rosary');
                  },
                );
              }
              return _StatisticsContent(stats: stats);
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => _ErrorView(
              error: error,
              onRetry: () => ref.invalidate(rosaryStatisticsProvider),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatisticsContent extends StatelessWidget {
  final RosaryStatistics stats;

  const _StatisticsContent({required this.stats});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        // Stats Grid
        _buildStatsGrid(context, colorScheme),
        const SizedBox(height: 24),
        // Favorite Mystery
        if (stats.favoriteMysterySet != null) ...[
          StatCard(
            icon: Icons.favorite,
            title: 'Favorite Mystery Set',
            value: stats.favoriteMysterySet!.shortName,
            subtitle:
                '${stats.mysterySetCounts[stats.favoriteMysterySet] ?? 0} rosaries',
            iconColor: _getMysteryColor(
              stats.favoriteMysterySet!,
            ).withOpacity(0.2),
            iconForegroundColor: _getMysteryColor(stats.favoriteMysterySet!),
          ),
          const SizedBox(height: 24),
        ],
        // Weekly Chart
        Text(
          'Weekly Progress',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        WeeklyChart(data: stats.weeklyCounts, barColor: colorScheme.primary),
        const SizedBox(height: 24),
        // Monthly Chart
        Text(
          'Monthly Overview',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        MonthlyChart(data: stats.monthlyCounts, barColor: colorScheme.tertiary),
        const SizedBox(height: 24),
        // Recent Sessions
        if (stats.recentSessions.isNotEmpty) ...[
          Card(
            child: RecentSessionsList(
              sessions: stats.recentSessions.take(10).toList(),
              onSessionTap: (session) {
                // Could show session details
              },
            ),
          ),
          const SizedBox(height: 16),
        ],
      ],
    );
  }

  Widget _buildStatsGrid(BuildContext context, ColorScheme colorScheme) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.2,
      children: [
        CompactStatCard(
          icon: Icons.check_circle_outline,
          title: 'Completed',
          value: stats.totalRosariesCompleted.toString(),
          iconColor: colorScheme.primary,
        ),
        CompactStatCard(
          icon: Icons.local_fire_department,
          title: 'Current Streak',
          value: '${stats.currentStreak} days',
          iconColor: Colors.orange,
        ),
        CompactStatCard(
          icon: Icons.emoji_events,
          title: 'Longest Streak',
          value: '${stats.longestStreak} days',
          iconColor: Colors.amber,
        ),
        CompactStatCard(
          icon: Icons.timer,
          title: 'Time Prayed',
          value: stats.totalTimeFormatted,
          iconColor: colorScheme.secondary,
        ),
      ],
    );
  }

  Color _getMysteryColor(dynamic mysterySet) {
    switch (mysterySet.toString()) {
      case 'MysterySet.joyful':
        return Colors.green;
      case 'MysterySet.sorrowful':
        return Colors.purple;
      case 'MysterySet.glorious':
        return Colors.amber;
      case 'MysterySet.luminous':
        return Colors.blue;
      default:
        return Colors.red;
    }
  }
}

class _ErrorView extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;

  const _ErrorView({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: colorScheme.error),
            const SizedBox(height: 16),
            Text(
              'Failed to load statistics',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error.toString(),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }
}
