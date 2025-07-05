class PrayerMetadata {
  final String id;
  final String title;
  final List<String> categories;
  final String description;
  final List<String> tags;
  final String fileName;
  final bool isLiturgical;
  final int liturgicalPriority;
  final String? liturgicalSeason;

  PrayerMetadata({
    required this.id,
    required this.title,
    required this.categories,
    required this.description,
    required this.tags,
    required this.fileName,
    this.isLiturgical = false,
    this.liturgicalPriority = 0,
    this.liturgicalSeason,
  });

  factory PrayerMetadata.fromJson(Map<String, dynamic> json) {
    return PrayerMetadata(
      id: json['id'],
      title: json['title'],
      categories: List<String>.from(json['categories'] ?? []),
      description: json['description'],
      tags: List<String>.from(json['tags'] ?? []),
      fileName: json['fileName'],
      isLiturgical: json['isLiturgical'] ?? false,
      liturgicalPriority: json['liturgicalPriority'] ?? 0,
      liturgicalSeason: json['liturgicalSeason'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'categories': categories,
      'description': description,
      'tags': tags,
      'fileName': fileName,
      'isLiturgical': isLiturgical,
      'liturgicalPriority': liturgicalPriority,
      'liturgicalSeason': liturgicalSeason,
    };
  }
}