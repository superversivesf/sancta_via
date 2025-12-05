import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/statistics_data.dart';
import '../../providers/achievement_providers.dart';
import '../../providers/statistics_providers.dart';

class StatisticsScreen extends ConsumerStatefulWidget {
  const StatisticsScreen({super.key});

  @override
  ConsumerState<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends ConsumerState<StatisticsScreen> {
  StatisticsPeriod _selectedPeriod = StatisticsPeriod.month;

  @override
  Widget build(BuildContext context) {
    final dashboardStats = ref.watch(dashboardStatisticsProvider);
    final totalPoints = ref.watch(totalAchievementPointsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Statistics'),
        actions: [
          // Period selector dropdown
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: DropdownButton<StatisticsPeriod>(
              value: _selectedPeriod,
              underline: const SizedBox.shrink(),
              icon: const Icon(Icons.arrow_drop_down),
              items: StatisticsPeriod.values.map((period) {
                return DropdownMenuItem(
                  value: period,
                  child: Text(period.displayName),
                );
              }).toList(),
              onChanged: (period) {
                if (period != null) {
                  setState(() {
                    _selectedPeriod = period;
                  });
                }
              },
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(dashboardStatisticsProvider);
          ref.invalidate(fastingActivityDataProvider);
          ref.invalidate(durationDistributionProvider);
          ref.invalidate(fastTypeDistributionProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Key Statistics Cards
            dashboardStats.when(
              data: (stats) => KeyStatisticsGrid(stats: stats),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => ErrorCard(error: error),
            ),

            const SizedBox(height: 24),

            // Achievement Points
            totalPoints.when(
              data: (points) => AchievementPointsCard(points: points),
              loading: () => const SizedBox.shrink(),
              error: (error, stack) => const SizedBox.shrink(),
            ),

            const SizedBox(height: 24),

            // Activity Over Time Chart
            SectionHeader(title: 'Activity Over Time (${_selectedPeriod.displayName})'),
            const SizedBox(height: 12),
            ActivityChart(period: _selectedPeriod),

            const SizedBox(height: 24),

            // Duration Distribution Chart
            const SectionHeader(title: 'Fast Duration Distribution'),
            const SizedBox(height: 12),
            const DurationDistributionChart(),

            const SizedBox(height: 24),

            // Fast Type Distribution
            const SectionHeader(title: 'Fast Types'),
            const SizedBox(height: 12),
            const FastTypeDistribution(),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  final String title;

  const SectionHeader({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
    );
  }
}

class KeyStatisticsGrid extends StatelessWidget {
  final DashboardStatistics stats;

  const KeyStatisticsGrid({super.key, required this.stats});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: [
        StatCard(
          icon: Icons.check_circle,
          label: 'Completed',
          value: stats.completedFastsCount.toString(),
          color: Colors.green,
        ),
        StatCard(
          icon: Icons.schedule,
          label: 'Total Hours',
          value: stats.totalHoursFasted.toStringAsFixed(1),
          color: Colors.blue,
        ),
        StatCard(
          icon: Icons.local_fire_department,
          label: 'Current Streak',
          value: '${stats.currentStreak} days',
          color: Colors.orange,
        ),
        StatCard(
          icon: Icons.star,
          label: 'Longest Streak',
          value: '${stats.longestStreak} days',
          color: Colors.amber,
        ),
        StatCard(
          icon: Icons.percent,
          label: 'Success Rate',
          value: '${stats.completionRate.toStringAsFixed(0)}%',
          color: Colors.purple,
        ),
        StatCard(
          icon: Icons.timer,
          label: 'Avg Duration',
          value: '${stats.averageDuration.toStringAsFixed(1)}h',
          color: Colors.teal,
        ),
      ],
    );
  }
}

class StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const StatCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class AchievementPointsCard extends StatelessWidget {
  final int points;

  const AchievementPointsCard({super.key, required this.points});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.emoji_events,
              color: Colors.amber[700],
              size: 32,
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Achievement Points',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                Text(
                  points.toString(),
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.amber[700],
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

class ActivityChart extends ConsumerWidget {
  final StatisticsPeriod period;

  const ActivityChart({super.key, required this.period});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activityData = ref.watch(fastingActivityDataProvider(period));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: activityData.when(
          data: (data) {
            if (data.isEmpty) {
              return SizedBox(
                height: 200,
                child: Center(
                  child: Text(
                    'No fasting activity in this period',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ),
              );
            }

            return SizedBox(
              height: 250,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: 1,
                    getDrawingHorizontalLine: (value) {
                      return FlLine(
                        color: Colors.grey[300]!,
                        strokeWidth: 1,
                      );
                    },
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            value.toInt().toString(),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        interval: data.length > 10 ? data.length / 5 : 1,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index < 0 || index >= data.length) {
                            return const SizedBox.shrink();
                          }
                          final date = data[index].date;
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              DateFormat('M/d').format(date),
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey[600],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  borderData: FlBorderData(
                    show: true,
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  lineBarsData: [
                    // Hours line
                    LineChartBarData(
                      spots: data.asMap().entries.map((entry) {
                        return FlSpot(
                          entry.key.toDouble(),
                          entry.value.totalHours,
                        );
                      }).toList(),
                      isCurved: true,
                      color: Theme.of(context).colorScheme.primary,
                      barWidth: 3,
                      dotData: const FlDotData(show: true),
                      belowBarData: BarAreaData(
                        show: true,
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withValues(alpha: 0.1),
                      ),
                    ),
                  ],
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipItems: (touchedSpots) {
                        return touchedSpots.map((spot) {
                          final index = spot.x.toInt();
                          if (index < 0 || index >= data.length) {
                            return null;
                          }
                          final dataPoint = data[index];
                          return LineTooltipItem(
                            '${DateFormat('MMM d').format(dataPoint.date)}\n${dataPoint.totalHours.toStringAsFixed(1)}h (${dataPoint.fastsCount} fasts)',
                            const TextStyle(color: Colors.white),
                          );
                        }).toList();
                      },
                    ),
                  ),
                ),
              ),
            );
          },
          loading: () => const SizedBox(
            height: 250,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, _) => SizedBox(
            height: 250,
            child: Center(
              child: Text(
                'Error loading chart',
                style: TextStyle(color: Colors.red[700]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class DurationDistributionChart extends ConsumerWidget {
  const DurationDistributionChart({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final distributionData = ref.watch(durationDistributionProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: distributionData.when(
          data: (data) {
            if (data.isEmpty) {
              return SizedBox(
                height: 200,
                child: Center(
                  child: Text(
                    'No duration data available',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ),
              );
            }

            return SizedBox(
              height: 250,
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: PieChart(
                      PieChartData(
                        sections: data.asMap().entries.map((entry) {
                          final index = entry.key;
                          final item = entry.value;
                          final colors = [
                            Colors.blue,
                            Colors.green,
                            Colors.orange,
                            Colors.purple,
                            Colors.red,
                            Colors.teal,
                          ];
                          return PieChartSectionData(
                            value: item.count.toDouble(),
                            title: '${item.count}',
                            color: colors[index % colors.length],
                            radius: 60,
                            titleStyle: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          );
                        }).toList(),
                        sectionsSpace: 2,
                        centerSpaceRadius: 40,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: data.asMap().entries.map((entry) {
                        final index = entry.key;
                        final item = entry.value;
                        final colors = [
                          Colors.blue,
                          Colors.green,
                          Colors.orange,
                          Colors.purple,
                          Colors.red,
                          Colors.teal,
                        ];
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Container(
                                width: 16,
                                height: 16,
                                decoration: BoxDecoration(
                                  color: colors[index % colors.length],
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                item.range,
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            );
          },
          loading: () => const SizedBox(
            height: 250,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, _) => SizedBox(
            height: 250,
            child: Center(
              child: Text(
                'Error loading distribution',
                style: TextStyle(color: Colors.red[700]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class FastTypeDistribution extends ConsumerWidget {
  const FastTypeDistribution({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final typeDistribution = ref.watch(fastTypeDistributionProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: typeDistribution.when(
          data: (data) {
            if (data.isEmpty) {
              return SizedBox(
                height: 100,
                child: Center(
                  child: Text(
                    'No fast type data available',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ),
              );
            }

            return Column(
              children: data.map((item) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              item.fastTypeName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          Text(
                            '${item.count} (${item.percentage.toStringAsFixed(1)}%)',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      LinearProgressIndicator(
                        value: item.percentage / 100,
                        minHeight: 8,
                        borderRadius: BorderRadius.circular(4),
                        backgroundColor: Colors.grey[200],
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ],
                  ),
                );
              }).toList(),
            );
          },
          loading: () => const SizedBox(
            height: 100,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, _) => SizedBox(
            height: 100,
            child: Center(
              child: Text(
                'Error loading fast types',
                style: TextStyle(color: Colors.red[700]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ErrorCard extends StatelessWidget {
  final Object error;

  const ErrorCard({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.red[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 8),
            Text(
              'Error loading statistics',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.red[700],
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              error.toString(),
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
