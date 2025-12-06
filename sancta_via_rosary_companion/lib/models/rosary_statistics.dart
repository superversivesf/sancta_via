class RosaryStatistics {
  const RosaryStatistics({
    required this.id,
    required this.date,
    required this.completedRosaries,
    required this.completedDecades,
    required this.mysteryType,
    required this.totalPrayerTimeMinutes,
  });

  final String id;
  final DateTime date;
  final int completedRosaries;
  final int completedDecades;
  final String mysteryType;
  final int totalPrayerTimeMinutes;

  int get totalSessions => completedRosaries + completedDecades;
  double get averageTimePerSession {
    if (totalSessions == 0) return 0.0;
    return totalPrayerTimeMinutes / totalSessions;
  }

  double get averageTimePerDecade {
    final totalDecades = completedRosaries * 5 + completedDecades;
    if (totalDecades == 0) return 0.0;
    return totalPrayerTimeMinutes / totalDecades;
  }

  RosaryStatistics copyWith({
    String? id,
    DateTime? date,
    int? completedRosaries,
    int? completedDecades,
    String? mysteryType,
    int? totalPrayerTimeMinutes,
  }) {
    return RosaryStatistics(
      id: id ?? this.id,
      date: date ?? this.date,
      completedRosaries: completedRosaries ?? this.completedRosaries,
      completedDecades: completedDecades ?? this.completedDecades,
      mysteryType: mysteryType ?? this.mysteryType,
      totalPrayerTimeMinutes:
          totalPrayerTimeMinutes ?? this.totalPrayerTimeMinutes,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RosaryStatistics &&
        other.id == id &&
        other.date == date &&
        other.completedRosaries == completedRosaries &&
        other.completedDecades == completedDecades &&
        other.mysteryType == mysteryType &&
        other.totalPrayerTimeMinutes == totalPrayerTimeMinutes;
  }

  @override
  int get hashCode =>
      id.hashCode ^
      date.hashCode ^
      completedRosaries.hashCode ^
      completedDecades.hashCode ^
      mysteryType.hashCode ^
      totalPrayerTimeMinutes.hashCode;
}
