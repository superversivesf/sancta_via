class Prayer {
  final String id;
  final String title;
  final String text;
  final Map<String, String>? translations;
  final String? attribution;
  final String? notes;

  Prayer({
    required this.id,
    required this.title,
    required this.text,
    this.translations,
    this.attribution,
    this.notes,
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
    };
  }
}