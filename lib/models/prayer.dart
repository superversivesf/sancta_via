class Prayer {
  final String id;
  final String title;
  final String text;
  final Map<String, String>? translations;
  final String? attribution;
  final String? notes;
  
  // Metadata fields from prayers_metadata.json (required parameters come first)
  final List<String> categories;
  final String description;
  final List<String> tags;
  final bool isLiturgical;
  final int liturgicalPriority;
  final String? liturgicalSeason;
  
  // Time of day categorization for time-appropriate prayer selection
  final String timeOfDay;

  Prayer({
    required this.id,
    required this.title,
    required this.text,
    required this.categories,
    required this.description,
    required this.tags,
    this.translations,
    this.attribution,
    this.notes,
    this.isLiturgical = false,
    this.liturgicalPriority = 0,
    this.liturgicalSeason,
    this.timeOfDay = 'anytime',
  });

  factory Prayer.fromJson(Map<String, dynamic> json) {
    Map<String, String>? translationsMap;

    if (json['translation'] != null) {
      translationsMap = Map<String, String>.from(json['translation']);
    }

    return Prayer(
      id: json['id'],
      title: json['title'],
      text: json['text'],
      translations: translationsMap,
      attribution: json['attribution'],
      notes: json['notes'],
      categories: List<String>.from(json['categories'] ?? []),
      description: json['description'] ?? '',
      tags: List<String>.from(json['tags'] ?? []),
      isLiturgical: json['isLiturgical'] ?? false,
      liturgicalPriority: json['liturgicalPriority'] ?? 0,
      liturgicalSeason: json['liturgicalSeason'],
      timeOfDay: json['timeOfDay'] ?? 'anytime',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'text': text,
      'translation': translations,
      'attribution': attribution,
      'notes': notes,
      'categories': categories,
      'description': description,
      'tags': tags,
      'isLiturgical': isLiturgical,
      'liturgicalPriority': liturgicalPriority,
      'liturgicalSeason': liturgicalSeason,
      'timeOfDay': timeOfDay,
    };
  }

  /// Create a copy of this prayer with updated fields
  Prayer copyWith({
    String? id,
    String? title,
    String? text,
    Map<String, String>? translations,
    String? attribution,
    String? notes,
    List<String>? categories,
    String? description,
    List<String>? tags,
    bool? isLiturgical,
    int? liturgicalPriority,
    String? liturgicalSeason,
    String? timeOfDay,
  }) {
    return Prayer(
      id: id ?? this.id,
      title: title ?? this.title,
      text: text ?? this.text,
      translations: translations ?? this.translations,
      attribution: attribution ?? this.attribution,
      notes: notes ?? this.notes,
      categories: categories ?? this.categories,
      description: description ?? this.description,
      tags: tags ?? this.tags,
      isLiturgical: isLiturgical ?? this.isLiturgical,
      liturgicalPriority: liturgicalPriority ?? this.liturgicalPriority,
      liturgicalSeason: liturgicalSeason ?? this.liturgicalSeason,
      timeOfDay: timeOfDay ?? this.timeOfDay,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Prayer && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
