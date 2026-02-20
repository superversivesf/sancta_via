import 'liturgical_celebration.dart';
import 'liturgical_cycle.dart';
import 'liturgical_year_info.dart';

/// Complete liturgical information for a specific date
class LiturgicalDayData {
  final String date;
  final String season;
  final String seasonKey;
  final LiturgicalCelebration celebration;
  final LiturgicalYearInfo liturgicalYear;
  final PsalterWeek psalterWeek;

  const LiturgicalDayData({
    required this.date,
    required this.season,
    required this.seasonKey,
    required this.celebration,
    required this.liturgicalYear,
    required this.psalterWeek,
  });

  factory LiturgicalDayData.fromJson(Map<String, dynamic> json) {
    return LiturgicalDayData(
      date: json['date'] ?? '',
      season: json['season'] ?? '',
      seasonKey: json['seasonKey'] ?? '',
      celebration: LiturgicalCelebration.fromJson(json['celebration'] ?? {}),
      liturgicalYear: LiturgicalYearInfo.fromJson(json['liturgicalYear'] ?? {}),
      psalterWeek: PsalterWeek.fromJson(json['psalterWeek'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'date': date,
      'season': season,
      'seasonKey': seasonKey,
      'celebration': celebration.toJson(),
      'liturgicalYear': liturgicalYear.toJson(),
      'psalterWeek': psalterWeek.toJson(),
    };
  }

  /// Parse the date string to a DateTime object
  DateTime get dateTime => DateTime.parse(date);

  /// Check if this day has a prioritized celebration
  bool get hasPrioritizedCelebration => celebration.prioritized;

  /// Check if this is a specific rank of celebration
  /// These delegate to the LiturgicalCelebration helper methods
  bool get isSolemnity => celebration.isSolemnity;
  bool get isFeast => celebration.isFeast;
  bool get isMemorial => celebration.isMemorial;
  bool get isOptionalMemorial => celebration.isOptionalMemorial;
  bool get isWeekday => celebration.isWeekday;

  /// Get a short description for display
  String get displayName {
    if (celebration.name.isNotEmpty && celebration.name != season) {
      return celebration.name;
    }
    return season;
  }

  @override
  String toString() {
    return 'LiturgicalDayData(date: $date, season: $season, celebration: ${celebration.name})';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is LiturgicalDayData &&
            runtimeType == other.runtimeType &&
            date == other.date &&
            season == other.season &&
            celebration == other.celebration;
  }

  @override
  int get hashCode => date.hashCode ^ season.hashCode ^ celebration.hashCode;
}
