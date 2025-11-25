// User preferences for examination of conscience
class ExaminationPreferences {
  final List<String> favoriteExaminationIds;
  final String? defaultExaminationId;

  ExaminationPreferences({
    this.favoriteExaminationIds = const [],
    this.defaultExaminationId,
  });

  // Factory method to create from JSON
  factory ExaminationPreferences.fromJson(Map<String, dynamic> json) {
    return ExaminationPreferences(
      favoriteExaminationIds: List<String>.from(
        json['favoriteExaminationIds'] ?? [],
      ),
      defaultExaminationId: json['defaultExaminationId'],
    );
  }

  // Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'favoriteExaminationIds': favoriteExaminationIds,
      'defaultExaminationId': defaultExaminationId,
    };
  }

  // Create a copy with updated fields
  ExaminationPreferences copyWith({
    List<String>? favoriteExaminationIds,
    String? defaultExaminationId,
  }) {
    return ExaminationPreferences(
      favoriteExaminationIds:
          favoriteExaminationIds ?? this.favoriteExaminationIds,
      defaultExaminationId: defaultExaminationId ?? this.defaultExaminationId,
    );
  }
}
