class RosarySession {
  const RosarySession({
    required this.id,
    required this.mysteryType,
    required this.startTime,
    this.endTime,
    required this.completedBeads,
    required this.isComplete,
    this.notes,
  });

  final String id;
  final String mysteryType;
  final DateTime startTime;
  final DateTime? endTime;
  final int completedBeads;
  final bool isComplete;
  final String? notes;

  double get progressPercentage => (completedBeads / 53 * 100).roundToDouble();
  int get estimatedDurationMinutes {
    final end = endTime ?? DateTime.now();
    return end.difference(startTime).inMinutes;
  }

  bool get isInProgress => !isComplete && completedBeads > 0;
  bool get isFinished => isComplete || completedBeads >= 53;

  RosarySession copyWith({
    String? id,
    String? mysteryType,
    DateTime? startTime,
    DateTime? endTime,
    int? completedBeads,
    bool? isComplete,
    String? notes,
  }) {
    return RosarySession(
      id: id ?? this.id,
      mysteryType: mysteryType ?? this.mysteryType,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      completedBeads: completedBeads ?? this.completedBeads,
      isComplete: isComplete ?? this.isComplete,
      notes: notes ?? this.notes,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RosarySession &&
        other.id == id &&
        other.mysteryType == mysteryType &&
        other.startTime == startTime &&
        other.endTime == endTime &&
        other.completedBeads == completedBeads &&
        other.isComplete == isComplete &&
        other.notes == notes;
  }

  @override
  int get hashCode =>
      id.hashCode ^
      mysteryType.hashCode ^
      startTime.hashCode ^
      endTime.hashCode ^
      completedBeads.hashCode ^
      isComplete.hashCode ^
      notes.hashCode;
}
