import 'prayer_category.dart';
import 'prayer_category_group.dart';

/// Complete metadata structure wrapper for parsing prayers_metadata.json
class FullPrayerMetadata {
  final String version;
  final String generatedAt;
  final List<PrayerCategoryGroup> categoryGroups;
  final List<PrayerCategory> categories;
  final List<PrayerMetadata> prayers;

  FullPrayerMetadata({
    required this.version,
    required this.generatedAt,
    required this.categoryGroups,
    required this.categories,
    required this.prayers,
  });

  factory FullPrayerMetadata.fromJson(Map<String, dynamic> json) {
    return FullPrayerMetadata(
      version: json['version'] ?? '',
      generatedAt: json['generatedAt'] ?? '',
      categoryGroups: (json['categoryGroups'] as List<dynamic>?)
          ?.map((item) => PrayerCategoryGroup.fromJson(item))
          .toList() ?? [],
      categories: (json['categories'] as List<dynamic>?)
          ?.map((item) => PrayerCategory.fromJson(item))
          .toList() ?? [],
      prayers: (json['prayers'] as List<dynamic>?)
          ?.map((item) => PrayerMetadata.fromJson(item))
          .toList() ?? [],
    );
  }
}

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
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      categories: List<String>.from(json['categories'] ?? []),
      description: json['description'] ?? '',
      tags: List<String>.from(json['tags'] ?? []),
      fileName: json['fileName'] ?? '',
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
