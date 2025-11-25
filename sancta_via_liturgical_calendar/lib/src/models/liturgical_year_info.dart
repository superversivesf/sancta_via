import 'liturgical_cycle.dart';

/// Information about the liturgical year for a specific date
class LiturgicalYearInfo {
  final int year;
  final LiturgicalCycle cycle;
  final int week;
  final int day;
  final int weekOfSeason;

  const LiturgicalYearInfo({
    required this.year,
    required this.cycle,
    required this.week,
    required this.day,
    required this.weekOfSeason,
  });

  factory LiturgicalYearInfo.fromJson(Map<String, dynamic> json) {
    return LiturgicalYearInfo(
      year: json['year'] ?? 0,
      cycle: LiturgicalCycle.fromJson(json['cycle'] ?? {}),
      week: json['week'] ?? 0,
      day: json['day'] ?? 0,
      weekOfSeason: json['weekOfSeason'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'year': year,
      'cycle': cycle.toJson(),
      'week': week,
      'day': day,
      'weekOfSeason': weekOfSeason,
    };
  }

  @override
  String toString() {
    return 'LiturgicalYearInfo(year: $year, cycle: ${cycle.value}, week: $week)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is LiturgicalYearInfo &&
            runtimeType == other.runtimeType &&
            year == other.year &&
            cycle == other.cycle &&
            week == other.week &&
            day == other.day &&
            weekOfSeason == other.weekOfSeason;
  }

  @override
  int get hashCode {
    return year.hashCode ^
        cycle.hashCode ^
        week.hashCode ^
        day.hashCode ^
        weekOfSeason.hashCode;
  }
}
