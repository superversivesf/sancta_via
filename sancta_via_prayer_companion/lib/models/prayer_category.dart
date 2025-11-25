class PrayerCategory {
  final String id;
  final String title;
  final String description;
  final String groupId; // Added to link to category group

  PrayerCategory({
    required this.id,
    required this.title,
    required this.description,
    required this.groupId,
  });

  factory PrayerCategory.fromJson(Map<String, dynamic> json) {
    return PrayerCategory(
      id: json['id'],
      title: json['title'],
      description: json['description'],
      groupId: json['groupId'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'groupId': groupId,
    };
  }
}
