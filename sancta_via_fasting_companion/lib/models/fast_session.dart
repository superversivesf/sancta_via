import 'fast_status.dart';

/// A fasting session instance
///
/// Represents an active or completed fast with timing, status, and metadata.
/// Tracks when the fast started, target duration, current status, and
/// encouragements shown to the user.
class FastSession {
  /// Unique identifier for this fast session
  final String id;

  /// ID of the FastType this session uses
  final String fastTypeId;

  /// When the fast started
  final DateTime startTime;

  /// When the fast ended (null if still active)
  final DateTime? endTime;

  /// Target duration in minutes
  final int targetDurationMinutes;

  /// Current status (active, completed, broken)
  final FastStatus status;

  /// Optional user notes/intentions
  final String? notes;

  /// List of encouragement IDs shown during this fast
  final List<String> encouragementsShown;

  const FastSession({
    required this.id,
    required this.fastTypeId,
    required this.startTime,
    this.endTime,
    required this.targetDurationMinutes,
    required this.status,
    this.notes,
    this.encouragementsShown = const [],
  });

  /// Create FastSession from JSON
  factory FastSession.fromJson(Map<String, dynamic> json) {
    return FastSession(
      id: json['id'] as String,
      fastTypeId: json['fastTypeId'] as String,
      startTime: DateTime.parse(json['startTime'] as String),
      endTime: json['endTime'] != null
          ? DateTime.parse(json['endTime'] as String)
          : null,
      targetDurationMinutes: json['targetDurationMinutes'] as int,
      status: FastStatus.fromJson(json['status'] as String),
      notes: json['notes'] as String?,
      encouragementsShown: (json['encouragementsShown'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
    );
  }

  /// Convert FastSession to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fastTypeId': fastTypeId,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
      'targetDurationMinutes': targetDurationMinutes,
      'status': status.toJson(),
      'notes': notes,
      'encouragementsShown': encouragementsShown,
    };
  }

  /// Create a copy with modified fields
  FastSession copyWith({
    String? id,
    String? fastTypeId,
    DateTime? startTime,
    DateTime? endTime,
    int? targetDurationMinutes,
    FastStatus? status,
    String? notes,
    List<String>? encouragementsShown,
  }) {
    return FastSession(
      id: id ?? this.id,
      fastTypeId: fastTypeId ?? this.fastTypeId,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      targetDurationMinutes: targetDurationMinutes ?? this.targetDurationMinutes,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      encouragementsShown: encouragementsShown ?? this.encouragementsShown,
    );
  }

  /// Calculate elapsed duration from start time
  Duration get elapsedDuration {
    final end = endTime ?? DateTime.now();
    return end.difference(startTime);
  }

  /// Get elapsed duration in minutes
  int get elapsedMinutes => elapsedDuration.inMinutes;

  /// Get elapsed duration in hours (rounded down)
  int get elapsedHours => elapsedDuration.inHours;

  /// Calculate target end time based on start + duration
  DateTime get targetEndTime {
    return startTime.add(Duration(minutes: targetDurationMinutes));
  }

  /// Calculate remaining time until target
  Duration get remainingDuration {
    final now = DateTime.now();
    final remaining = targetEndTime.difference(now);
    return remaining.isNegative ? Duration.zero : remaining;
  }

  /// Get remaining duration in minutes
  int get remainingMinutes => remainingDuration.inMinutes;

  /// Calculate progress percentage (0.0 to 1.0)
  double get progressPercentage {
    if (targetDurationMinutes == 0) return 0.0;
    final progress = elapsedMinutes / targetDurationMinutes;
    return progress.clamp(0.0, 1.0);
  }

  /// Whether the fast has reached its target duration
  bool get hasReachedTarget {
    return elapsedMinutes >= targetDurationMinutes;
  }

  /// Whether this encouragement has been shown
  bool hasShownEncouragement(String encouragementId) {
    return encouragementsShown.contains(encouragementId);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is FastSession &&
        other.id == id &&
        other.fastTypeId == fastTypeId &&
        other.startTime == startTime &&
        other.endTime == endTime &&
        other.targetDurationMinutes == targetDurationMinutes &&
        other.status == status &&
        other.notes == notes &&
        _listEquals(other.encouragementsShown, encouragementsShown);
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      fastTypeId,
      startTime,
      endTime,
      targetDurationMinutes,
      status,
      notes,
      Object.hashAll(encouragementsShown),
    );
  }

  @override
  String toString() {
    return 'FastSession(id: $id, fastTypeId: $fastTypeId, startTime: $startTime, endTime: $endTime, targetDurationMinutes: $targetDurationMinutes, status: $status, notes: $notes, encouragementsShown: $encouragementsShown)';
  }

  // Helper method for list equality
  bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
