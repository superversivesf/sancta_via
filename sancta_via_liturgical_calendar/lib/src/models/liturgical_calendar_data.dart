import 'liturgical_day_data.dart';

/// Metadata about a liturgical year
class LiturgicalMetadata {
  final int year;
  final int totalDays;
  final Map<String, int> seasons;
  final Map<String, int> colors;
  final Map<String, int> types;
  final int prioritizedCelebrations;
  final String generatedAt;
  final String dataVersion;
  final String romcalVersion;

  const LiturgicalMetadata({
    required this.year,
    required this.totalDays,
    required this.seasons,
    required this.colors,
    required this.types,
    required this.prioritizedCelebrations,
    required this.generatedAt,
    required this.dataVersion,
    required this.romcalVersion,
  });

  factory LiturgicalMetadata.fromJson(Map<String, dynamic> json) {
    return LiturgicalMetadata(
      year: json['year'] ?? 0,
      totalDays: json['totalDays'] ?? 0,
      seasons: Map<String, int>.from(json['seasons'] ?? {}),
      colors: Map<String, int>.from(json['colors'] ?? {}),
      types: Map<String, int>.from(json['types'] ?? {}),
      prioritizedCelebrations: json['prioritizedCelebrations'] ?? 0,
      generatedAt: json['generatedAt'] ?? '',
      dataVersion: json['dataVersion'] ?? '',
      romcalVersion: json['romcalVersion'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'year': year,
      'totalDays': totalDays,
      'seasons': seasons,
      'colors': colors,
      'types': types,
      'prioritizedCelebrations': prioritizedCelebrations,
      'generatedAt': generatedAt,
      'dataVersion': dataVersion,
      'romcalVersion': romcalVersion,
    };
  }

  @override
  String toString() {
    return 'LiturgicalMetadata(year: $year, totalDays: $totalDays, romcalVersion: $romcalVersion)';
  }
}

/// Complete liturgical calendar data for a year
class LiturgicalCalendarData {
  final LiturgicalMetadata metadata;
  final Map<String, LiturgicalDayData> calendar;

  const LiturgicalCalendarData({
    required this.metadata,
    required this.calendar,
  });

  factory LiturgicalCalendarData.fromJson(Map<String, dynamic> json) {
    final calendarJson = json['calendar'] as Map<String, dynamic>;
    final calendar = <String, LiturgicalDayData>{};

    for (final entry in calendarJson.entries) {
      calendar[entry.key] = LiturgicalDayData.fromJson(entry.value);
    }

    return LiturgicalCalendarData(
      metadata: LiturgicalMetadata.fromJson(json['metadata'] ?? {}),
      calendar: calendar,
    );
  }

  Map<String, dynamic> toJson() {
    final calendarJson = <String, dynamic>{};
    for (final entry in calendar.entries) {
      calendarJson[entry.key] = entry.value.toJson();
    }

    return {'metadata': metadata.toJson(), 'calendar': calendarJson};
  }

  /// Get liturgical day for a specific date
  LiturgicalDayData? getDayForDate(DateTime date) {
    final dateKey =
        '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
    return calendar[dateKey];
  }

  /// Get all days in a date range
  List<LiturgicalDayData> getDaysInRange(DateTime start, DateTime end) {
    final days = <LiturgicalDayData>[];

    for (
      var date = start;
      date.isBefore(end.add(const Duration(days: 1)));
      date = date.add(const Duration(days: 1))
    ) {
      final day = getDayForDate(date);
      if (day != null) {
        days.add(day);
      }
    }

    return days;
  }

  /// Get upcoming feasts and solemnities
  List<LiturgicalDayData> getUpcomingFeasts({
    int daysAhead = 30,
    DateTime? fromDate,
  }) {
    final start = fromDate ?? DateTime.now();
    final end = start.add(Duration(days: daysAhead));

    final days = getDaysInRange(start, end);

    return days
        .where(
          (day) =>
              day.celebration.prioritized ||
              day.celebration.isSolemnity ||
              day.celebration.isFeast ||
              day.celebration.isMemorial,
        )
        .toList();
  }

  @override
  String toString() {
    return 'LiturgicalCalendarData(year: ${metadata.year}, totalDays: ${metadata.totalDays})';
  }
}
