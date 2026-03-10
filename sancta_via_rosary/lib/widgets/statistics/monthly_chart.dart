import 'package:flutter/material.dart';

/// Bar chart showing rosaries completed per week for the last 4 weeks
///
/// Custom implementation using CustomPaint to avoid external dependencies.
/// Displays horizontal bars with week labels.
class MonthlyChart extends StatelessWidget {
  /// Map of week start date (YYYY-MM-DD) to count of rosaries
  final Map<String, int> data;

  /// Color for the bars
  final Color? barColor;

  /// Maximum width of the chart
  final double height;

  const MonthlyChart({
    required this.data,
    this.barColor,
    this.height = 180,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Sort weeks and prepare data
    final sortedEntries = _getSortedMonthlyData();
    final maxValue = sortedEntries.isEmpty
        ? 1
        : sortedEntries.map((e) => e.count).reduce((a, b) => a > b ? a : b);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Last 4 Weeks',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: height,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: sortedEntries.reversed.map((entry) {
                  return _WeekBar(
                    label: entry.label,
                    count: entry.count,
                    maxCount: maxValue,
                    barColor: barColor ?? colorScheme.primary,
                    isCurrentWeek: entry.isCurrentWeek,
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<_WeekData> _getSortedMonthlyData() {
    final now = DateTime.now();
    final weeks = <_WeekData>[];

    // Generate last 4 weeks
    for (int i = 3; i >= 0; i--) {
      final weekStart = now.subtract(Duration(days: i * 7));
      final dateKey =
          '${weekStart.year}-${weekStart.month.toString().padLeft(2, '0')}-${weekStart.day.toString().padLeft(2, '0')}';
      final count = data[dateKey] ?? 0;
      final isCurrentWeek = i == 0;

      // Format label as "Week of MMM DD"
      final monthNames = [
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
      final label = isCurrentWeek
          ? 'This week'
          : 'Week of ${monthNames[weekStart.month - 1]} ${weekStart.day}';

      weeks.add(
        _WeekData(label: label, count: count, isCurrentWeek: isCurrentWeek),
      );
    }

    return weeks;
  }
}

class _WeekData {
  final String label;
  final int count;
  final bool isCurrentWeek;

  const _WeekData({
    required this.label,
    required this.count,
    required this.isCurrentWeek,
  });
}

class _WeekBar extends StatelessWidget {
  final String label;
  final int count;
  final int maxCount;
  final Color barColor;
  final bool isCurrentWeek;

  const _WeekBar({
    required this.label,
    required this.count,
    required this.maxCount,
    required this.barColor,
    required this.isCurrentWeek,
  });

  @override
  Widget build(BuildContext context) {
    final barWidth = maxCount > 0 ? (count / maxCount) * 0.7 : 0.0;

    return Row(
      children: [
        // Week label
        SizedBox(
          width: 90,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isCurrentWeek ? FontWeight.w600 : FontWeight.normal,
              color: isCurrentWeek
                  ? barColor
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Bar
        Expanded(
          child: Container(
            height: 24,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(4),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: barWidth,
              child: Container(
                decoration: BoxDecoration(
                  color: barColor.withOpacity(isCurrentWeek ? 1.0 : 0.7),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Count
        SizedBox(
          width: 30,
          child: Text(
            count.toString(),
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isCurrentWeek
                  ? barColor
                  : Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }
}
