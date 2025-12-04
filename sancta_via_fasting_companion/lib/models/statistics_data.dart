/// Data point for charting fasting activity over time
class FastingActivityData {
  final DateTime date;
  final int fastsCount;
  final double totalHours;

  const FastingActivityData({
    required this.date,
    required this.fastsCount,
    required this.totalHours,
  });
}

/// Data point for fast duration distribution
class DurationDistribution {
  final String range; // e.g., "0-6h", "6-12h", "12-18h"
  final int count;

  const DurationDistribution({
    required this.range,
    required this.count,
  });
}

/// Data point for fast type distribution
class FastTypeDistribution {
  final String fastTypeName;
  final int count;
  final double percentage;

  const FastTypeDistribution({
    required this.fastTypeName,
    required this.count,
    required this.percentage,
  });
}

/// Time period for statistics filtering
enum StatisticsPeriod {
  week,
  month,
  threeMonths,
  year,
  all,
}

extension StatisticsPeriodExtension on StatisticsPeriod {
  String get displayName {
    switch (this) {
      case StatisticsPeriod.week:
        return 'Week';
      case StatisticsPeriod.month:
        return 'Month';
      case StatisticsPeriod.threeMonths:
        return '3 Months';
      case StatisticsPeriod.year:
        return 'Year';
      case StatisticsPeriod.all:
        return 'All Time';
    }
  }

  DateTime get startDate {
    final now = DateTime.now();
    switch (this) {
      case StatisticsPeriod.week:
        return now.subtract(const Duration(days: 7));
      case StatisticsPeriod.month:
        return DateTime(now.year, now.month - 1, now.day);
      case StatisticsPeriod.threeMonths:
        return DateTime(now.year, now.month - 3, now.day);
      case StatisticsPeriod.year:
        return DateTime(now.year - 1, now.month, now.day);
      case StatisticsPeriod.all:
        return DateTime(2000, 1, 1); // Far enough in the past
    }
  }
}
