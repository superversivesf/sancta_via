/// Status of a fasting session
enum FastStatus {
  /// Fast is currently active
  active,

  /// Fast was completed successfully
  completed,

  /// Fast was broken before completion
  broken;

  /// Convert status to JSON string
  String toJson() => name;

  /// Create status from JSON string
  static FastStatus fromJson(String json) {
    return FastStatus.values.firstWhere(
      (status) => status.name == json,
      orElse: () => FastStatus.active,
    );
  }

  /// Human-readable display name
  String get displayName {
    switch (this) {
      case FastStatus.active:
        return 'Active';
      case FastStatus.completed:
        return 'Completed';
      case FastStatus.broken:
        return 'Broken';
    }
  }

  /// Whether this status indicates the fast is still ongoing
  bool get isOngoing => this == FastStatus.active;

  /// Whether this status indicates the fast has ended
  bool get isEnded => this == FastStatus.completed || this == FastStatus.broken;
}
