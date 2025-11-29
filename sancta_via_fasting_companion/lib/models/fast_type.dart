import 'fast_type_category.dart';

/// Defines a type of fast (e.g., 16:8 intermittent, 24-hour, Lenten)
///
/// FastType describes the characteristics of a fasting protocol including
/// duration, category, milestone messages, and associated prayers.
class FastType {
  /// Unique identifier for this fast type
  final String id;

  /// Display name (e.g., "16:8 Intermittent", "Ash Wednesday")
  final String name;

  /// Description of this fast type
  final String description;

  /// Category of this fast type
  final FastTypeCategory category;

  /// Target duration in hours (null for multi-day fasts)
  final int? targetDurationHours;

  /// Milestone messages: hour mark -> message key
  /// Example: {4: "Quarter way there!", 8: "Halfway complete!"}
  final Map<int, String> milestoneMessages;

  /// List of associated prayer IDs from prayer database
  final List<String> associatedPrayers;

  const FastType({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    this.targetDurationHours,
    this.milestoneMessages = const {},
    this.associatedPrayers = const [],
  });

  /// Create FastType from JSON
  factory FastType.fromJson(Map<String, dynamic> json) {
    // Parse milestone messages from JSON
    final Map<int, String> milestones = {};
    if (json['milestoneMessages'] != null) {
      final dynamic milestonesRaw = json['milestoneMessages'];
      if (milestonesRaw is Map) {
        milestonesRaw.forEach((key, value) {
          milestones[int.parse(key.toString())] = value.toString();
        });
      }
    }

    return FastType(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      category: FastTypeCategory.fromJson(json['category'] as String),
      targetDurationHours: json['targetDurationHours'] as int?,
      milestoneMessages: milestones,
      associatedPrayers: (json['associatedPrayers'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
    );
  }

  /// Convert FastType to JSON
  Map<String, dynamic> toJson() {
    // Convert milestone messages to JSON-compatible map
    final Map<String, String> milestonesJson = {};
    milestoneMessages.forEach((key, value) {
      milestonesJson[key.toString()] = value;
    });

    return {
      'id': id,
      'name': name,
      'description': description,
      'category': category.toJson(),
      'targetDurationHours': targetDurationHours,
      'milestoneMessages': milestonesJson,
      'associatedPrayers': associatedPrayers,
    };
  }

  /// Create a copy with modified fields
  FastType copyWith({
    String? id,
    String? name,
    String? description,
    FastTypeCategory? category,
    int? targetDurationHours,
    Map<int, String>? milestoneMessages,
    List<String>? associatedPrayers,
  }) {
    return FastType(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      category: category ?? this.category,
      targetDurationHours: targetDurationHours ?? this.targetDurationHours,
      milestoneMessages: milestoneMessages ?? this.milestoneMessages,
      associatedPrayers: associatedPrayers ?? this.associatedPrayers,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is FastType &&
        other.id == id &&
        other.name == name &&
        other.description == description &&
        other.category == category &&
        other.targetDurationHours == targetDurationHours &&
        _mapEquals(other.milestoneMessages, milestoneMessages) &&
        _listEquals(other.associatedPrayers, associatedPrayers);
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      name,
      description,
      category,
      targetDurationHours,
      Object.hashAll(milestoneMessages.entries),
      Object.hashAll(associatedPrayers),
    );
  }

  @override
  String toString() {
    return 'FastType(id: $id, name: $name, description: $description, category: $category, targetDurationHours: $targetDurationHours, milestoneMessages: $milestoneMessages, associatedPrayers: $associatedPrayers)';
  }

  // Helper methods for equality comparison
  bool _mapEquals(Map<int, String> a, Map<int, String> b) {
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (!b.containsKey(key) || a[key] != b[key]) return false;
    }
    return true;
  }

  bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
