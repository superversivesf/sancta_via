class PrayerCategoryGroup {
  final String id;
  final String title;
  final String description;
  final String icon;
  final int order;

  PrayerCategoryGroup({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.order,
  });

  factory PrayerCategoryGroup.fromJson(Map<String, dynamic> json) {
    return PrayerCategoryGroup(
      id: json['id'],
      title: json['title'],
      description: json['description'],
      icon: json['icon'],
      order: json['order'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'icon': icon,
      'order': order,
    };
  }
}
