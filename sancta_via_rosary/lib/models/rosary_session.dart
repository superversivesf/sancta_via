import 'package:flutter/foundation.dart';

import 'mystery_set.dart';

/// Tracks a complete or partial rosary prayer session
///
/// Used to:
/// - Track prayer progress
/// - Resume interrupted sessions
/// - Record completed rosaries for statistics
/// - Support partial rosaries (e.g., just one decade)
@immutable
class RosarySession {
  /// Unique identifier for this session
  final String id;

  /// When the session started
  final DateTime startTime;

  /// When the session ended (null if in progress)
  final DateTime? endTime;

  /// Which mystery set was selected for this session
  final MysterySet mysterySet;

  /// List of mystery numbers (1-5) that were completed in this session
  final List<int> mysteriesCompleted;

  /// Whether this session is complete
  final bool completed;

  /// Current position in the rosary (if interrupted)
  /// 0 = start, 1 = after Creed, 2 = after 1st Hail Mary, etc.
  final int? currentPosition;

  /// Which specific mystery (1-5) is currently being prayed (if in progress)
  final int? currentMysteryNumber;

  /// Which Hail Mary within the current decade (1-10)
  final int? currentHailMary;

  /// Notes or intentions recorded for this session
  final String? notes;

  /// Duration in minutes (calculated from start/end times)
  int? get durationMinutes {
    if (endTime == null) return null;
    return endTime!.difference(startTime).inMinutes;
  }

  const RosarySession({
    required this.id,
    required this.startTime,
    required this.mysterySet,
    this.endTime,
    this.mysteriesCompleted = const [],
    this.completed = false,
    this.currentPosition,
    this.currentMysteryNumber,
    this.currentHailMary,
    this.notes,
  });

  /// Create a new session for today with the recommended mystery set
  factory RosarySession.createToday({MysterySet? mysterySet, String? id}) {
    return RosarySession(
      id: id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      startTime: DateTime.now(),
      mysterySet: mysterySet ?? MysterySet.forToday(),
    );
  }

  /// Create from JSON for persistence
  factory RosarySession.fromJson(Map<String, dynamic> json) {
    return RosarySession(
      id: json['id'] as String,
      startTime: DateTime.parse(json['startTime'] as String),
      endTime: json['endTime'] != null
          ? DateTime.parse(json['endTime'] as String)
          : null,
      mysterySet: MysterySet.fromString(json['mysterySet'] as String?),
      mysteriesCompleted:
          (json['mysteriesCompleted'] as List<dynamic>?)
              ?.map((e) => e as int)
              .toList() ??
          [],
      completed: json['completed'] as bool? ?? false,
      currentPosition: json['currentPosition'] as int?,
      currentMysteryNumber: json['currentMysteryNumber'] as int?,
      currentHailMary: json['currentHailMary'] as int?,
      notes: json['notes'] as String?,
    );
  }

  /// Convert to JSON for persistence
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
      'mysterySet': mysterySet.toStringValue(),
      'mysteriesCompleted': mysteriesCompleted,
      'completed': completed,
      'currentPosition': currentPosition,
      'currentMysteryNumber': currentMysteryNumber,
      'currentHailMary': currentHailMary,
      'notes': notes,
    };
  }

  /// Create a copy with updated fields
  RosarySession copyWith({
    String? id,
    DateTime? startTime,
    DateTime? endTime,
    MysterySet? mysterySet,
    List<int>? mysteriesCompleted,
    bool? completed,
    int? currentPosition,
    int? currentMysteryNumber,
    int? currentHailMary,
    String? notes,
  }) {
    return RosarySession(
      id: id ?? this.id,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      mysterySet: mysterySet ?? this.mysterySet,
      mysteriesCompleted: mysteriesCompleted ?? this.mysteriesCompleted,
      completed: completed ?? this.completed,
      currentPosition: currentPosition ?? this.currentPosition,
      currentMysteryNumber: currentMysteryNumber ?? this.currentMysteryNumber,
      currentHailMary: currentHailMary ?? this.currentHailMary,
      notes: notes ?? this.notes,
    );
  }

  /// Mark a mystery as completed
  RosarySession completeMystery(int mysteryNumber) {
    if (mysteryNumber < 1 || mysteryNumber > 5) {
      throw ArgumentError('Mystery number must be between 1 and 5');
    }

    final updatedCompleted = List<int>.from(mysteriesCompleted);
    if (!updatedCompleted.contains(mysteryNumber)) {
      updatedCompleted.add(mysteryNumber);
    }

    return copyWith(
      mysteriesCompleted: updatedCompleted..sort(),
      currentMysteryNumber: null,
      currentHailMary: null,
    );
  }

  /// Mark the session as complete
  RosarySession finish() {
    return copyWith(
      endTime: DateTime.now(),
      completed: true,
      currentPosition: null,
      currentMysteryNumber: null,
      currentHailMary: null,
    );
  }

  /// Update current progress position
  RosarySession updatePosition({
    required int position,
    int? mysteryNumber,
    int? hailMary,
  }) {
    return copyWith(
      currentPosition: position,
      currentMysteryNumber: mysteryNumber,
      currentHailMary: hailMary,
    );
  }

  /// Whether all 5 mysteries are completed
  bool get isComplete => mysteriesCompleted.length >= 5;

  /// Number of mysteries completed
  int get completedCount => mysteriesCompleted.length;

  /// Progress as a percentage (0-100)
  int get progressPercent => (completedCount / 5 * 100).round();

  /// Whether the session is currently in progress
  bool get isInProgress => !completed && endTime == null;

  /// Whether the session has been abandoned (not completed, has end time)
  bool get isAbandoned => !completed && endTime != null;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RosarySession && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'RosarySession(id: $id, set: ${mysterySet.name}, '
        'completed: $completedCount/5, done: $completed)';
  }
}
