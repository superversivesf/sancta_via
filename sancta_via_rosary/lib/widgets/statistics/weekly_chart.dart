import 'package:flutter/material.dart';

/// Simple bar chart showing rosaries completed per day for the last 7 days
///
/// Custom implementation using CustomPaint to avoid external dependencies.
/// Displays bars with weekday labels below.
class WeeklyChart extends StatelessWidget {
  /// Map of date (YYYY-MM-DD) to count of rosaries
  final Map<String, int> data;

  /// Color for the bars
  final Color? barColor;

  /// Maximum height of the chart
  final double height;

  const WeeklyChart({
    required this.data,
    this.barColor,
    this.height = 150,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Sort dates and prepare data
    final sortedEntries = _getSortedWeeklyData();
    final maxValue = sortedEntries
        .map((e) => e.count)
        .reduce((a, b) => a > b ? a : b);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This Week',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: height,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: sortedEntries.map((entry) {
                  return _DayBar(
                    label: entry.label,
                    count: entry.count,
                    maxCount: maxValue,
                    barColor: barColor ?? colorScheme.primary,
                    dayColor: entry.isToday
                        ? colorScheme.primary
                        : colorScheme.onSurfaceVariant,
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<_DayData> _getSortedWeeklyData() {
    final now = DateTime.now();
    final days = <_DayData>[];

    // Generate last 7 days
    for (int i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final dateKey =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      final count = data[dateKey] ?? 0;
      final isToday = i == 0;

      days.add(
        _DayData(
          label: _getDayLabel(date.weekday),
          count: count,
          isToday: isToday,
        ),
      );
    }

    return days;
  }

  String _getDayLabel(int weekday) {
    // Dart weekday: 1=Monday, 7=Sunday
    const labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return labels[weekday - 1];
  }
}

class _DayData {
  final String label;
  final int count;
  final bool isToday;

  const _DayData({
    required this.label,
    required this.count,
    required this.isToday,
  });
}

class _DayBar extends StatelessWidget {
  final String label;
  final int count;
  final int maxCount;
  final Color barColor;
  final Color dayColor;

  const _DayBar({
    required this.label,
    required this.count,
    required this.maxCount,
    required this.barColor,
    required this.dayColor,
  });

  @override
  Widget build(BuildContext context) {
    final barHeight = maxCount > 0 ? (count / maxCount) * 100.0 : 0.0;

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        // Count label above bar
        Text(
          count.toString(),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: barColor,
          ),
        ),
        const SizedBox(height: 4),
        // Bar
        Container(
          width: 24,
          height: barHeight.clamp(4.0, 100.0),
          decoration: BoxDecoration(
            color: barColor.withOpacity(0.8),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          ),
        ),
        const SizedBox(height: 8),
        // Day label
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: dayColor.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: dayColor,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
