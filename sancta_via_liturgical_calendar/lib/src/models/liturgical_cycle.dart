/// Represents the liturgical cycle (Year A, B, C for Sundays)
class LiturgicalCycle {
  final int key;
  final String value;

  const LiturgicalCycle({
    required this.key,
    required this.value,
  });

  factory LiturgicalCycle.fromJson(Map<String, dynamic> json) {
    return LiturgicalCycle(
      key: json['key'] ?? 0,
      value: json['value'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'key': key,
      'value': value,
    };
  }

  @override
  String toString() => 'LiturgicalCycle(key: $key, value: $value)';

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is LiturgicalCycle &&
            runtimeType == other.runtimeType &&
            key == other.key &&
            value == other.value;
  }

  @override
  int get hashCode => key.hashCode ^ value.hashCode;
}

/// Represents the psalter week (Week I, II, III, IV)
class PsalterWeek {
  final int key;
  final String value;

  const PsalterWeek({
    required this.key,
    required this.value,
  });

  factory PsalterWeek.fromJson(Map<String, dynamic> json) {
    return PsalterWeek(
      key: json['key'] ?? 0,
      value: json['value'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'key': key,
      'value': value,
    };
  }

  @override
  String toString() => 'PsalterWeek(key: $key, value: $value)';

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is PsalterWeek &&
            runtimeType == other.runtimeType &&
            key == other.key &&
            value == other.value;
  }

  @override
  int get hashCode => key.hashCode ^ value.hashCode;
}