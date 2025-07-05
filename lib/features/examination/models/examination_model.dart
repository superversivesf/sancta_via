import 'package:uuid/uuid.dart';

// Model for different types of examination of conscience
class ExaminationModel {
  final String id;
  final String title;
  final String description;
  final String source; // E.g., "Based on Ten Commandments", "St. Francis de Sales", etc.
  final String targetAudience; // E.g., "Adults", "Children", "Teens", etc.
  final List<ExaminationCategory> categories;

  ExaminationModel({
    String? id,
    required this.title,
    required this.description,
    required this.source,
    required this.targetAudience,
    required this.categories,
  }) : id = id ?? const Uuid().v4();

  // Factory method to create from JSON
  factory ExaminationModel.fromJson(Map<String, dynamic> json) {
    return ExaminationModel(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      source: json['source'] as String,
      targetAudience: json['target_audience'] as String,
      categories: (json['categories'] as List)
          .map((category) => ExaminationCategory.fromJson(category))
          .toList(),
    );
  }

  // Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'source': source,
      'targetAudience': targetAudience,
      'categories': categories.map((category) => category.toJson()).toList(),
    };
  }

  // Number of total items across all categories
  int get totalItems {
    return categories.fold(0, (sum, category) => sum + category.items.length);
  }
}

// Category within an examination (e.g., "First Commandment", "Charity", etc.)
class ExaminationCategory {
  final String id;
  final String title;
  final String? description;
  final List<ExaminationItem> items;

  ExaminationCategory({
    String? id,
    required this.title,
    this.description,
    required this.items,
  }) : id = id ?? const Uuid().v4();

  // Factory method to create from JSON
  factory ExaminationCategory.fromJson(Map<String, dynamic> json) {
    return ExaminationCategory(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      items: (json['items'] as List)
          .map((item) => ExaminationItem.fromJson(item))
          .toList(),
    );
  }

  // Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'items': items.map((item) => item.toJson()).toList(),
    };
  }
}

// Individual examination question/item
class ExaminationItem {
  final String id;
  final String text;
  final String? clarification; // Optional additional explanation

  ExaminationItem({
    String? id,
    required this.text,
    this.clarification,
  }) : id = id ?? const Uuid().v4();

  // Factory method to create from JSON
  factory ExaminationItem.fromJson(Map<String, dynamic> json) {
    return ExaminationItem(
      id: json['id'] as String,
      text: json['text'] as String,
      clarification: json['clarification'] as String?,
    );
  }

  // Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'clarification': clarification,
    };
  }
}
