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
    };
  }
}
