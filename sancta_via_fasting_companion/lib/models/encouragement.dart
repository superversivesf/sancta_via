import 'encouragement_category.dart';

/// An encouragement message shown during fasting
///
/// Contains scriptural passages, saint quotes, or prayers to support
/// the user during their fast. Encouragements are triggered at specific
/// points (start, hourly, milestone, completion, difficulty).
class Encouragement {
  /// Unique identifier for this encouragement
  final String id;

  /// Category of encouragement (scripture, saint quote, prayer)
  final EncouragementCategory category;

  /// When to show this encouragement (start, hourly, milestone, completion, difficulty)
  final String triggerPoint;

  /// Liturgical season this applies to (null for any season)
  final String? liturgicalSeason;

  /// The encouragement text content
  final String content;

  /// Attribution (author, saint name, or biblical reference)
  final String? attribution;

  /// Related scripture reference (if applicable)
  final String? relatedScripture;

  /// Category hint for selection (suffering, perseverance, victory, etc.)
  final String? categoryHint;

  const Encouragement({
    required this.id,
    required this.category,
    required this.triggerPoint,
    this.liturgicalSeason,
    required this.content,
    this.attribution,
    this.relatedScripture,
    this.categoryHint,
  });

  /// Create Encouragement from JSON
  factory Encouragement.fromJson(Map<String, dynamic> json) {
    return Encouragement(
      id: json['id'] as String,
      category: EncouragementCategory.fromJson(json['category'] as String),
      triggerPoint: json['triggerPoint'] as String,
      liturgicalSeason: json['liturgicalSeason'] as String?,
      content: json['content'] as String,
      attribution: json['attribution'] as String?,
      relatedScripture: json['relatedScripture'] as String?,
      categoryHint: json['categoryHint'] as String?,
    );
  }

  /// Convert Encouragement to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'category': category.toJson(),
      'triggerPoint': triggerPoint,
      'liturgicalSeason': liturgicalSeason,
      'content': content,
      'attribution': attribution,
      'relatedScripture': relatedScripture,
      'categoryHint': categoryHint,
    };
  }

  /// Create a copy with modified fields
  Encouragement copyWith({
    String? id,
    EncouragementCategory? category,
    String? triggerPoint,
    String? liturgicalSeason,
    String? content,
    String? attribution,
    String? relatedScripture,
    String? categoryHint,
  }) {
    return Encouragement(
      id: id ?? this.id,
      category: category ?? this.category,
      triggerPoint: triggerPoint ?? this.triggerPoint,
      liturgicalSeason: liturgicalSeason ?? this.liturgicalSeason,
      content: content ?? this.content,
      attribution: attribution ?? this.attribution,
      relatedScripture: relatedScripture ?? this.relatedScripture,
      categoryHint: categoryHint ?? this.categoryHint,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is Encouragement &&
        other.id == id &&
        other.category == category &&
        other.triggerPoint == triggerPoint &&
        other.liturgicalSeason == liturgicalSeason &&
        other.content == content &&
        other.attribution == attribution &&
        other.relatedScripture == relatedScripture &&
        other.categoryHint == categoryHint;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      category,
      triggerPoint,
      liturgicalSeason,
      content,
      attribution,
      relatedScripture,
      categoryHint,
    );
  }

  @override
  String toString() {
    return 'Encouragement(id: $id, category: $category, triggerPoint: $triggerPoint, liturgicalSeason: $liturgicalSeason, content: $content, attribution: $attribution, relatedScripture: $relatedScripture, categoryHint: $categoryHint)';
  }
}
