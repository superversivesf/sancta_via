import 'mystery_type.dart';

class RosaryMystery {
  const RosaryMystery({
    required this.id,
    required this.type,
    required this.mysteryNumber,
    required this.title,
    required this.description,
    required this.scriptureText,
    required this.meditationText,
  });

  final String id;
  final MysteryType type;
  final int mysteryNumber;
  final String title;
  final String description;
  final String scriptureText;
  final String meditationText;

  bool get isFirstMystery => mysteryNumber == 1;
  bool get isLastMystery => mysteryNumber == 5;

  String get typeDisplayName => type.displayName;
  String get mysteryDisplayTitle => '$mysteryNumber. $title';

  RosaryMystery copyWith({
    String? id,
    MysteryType? type,
    int? mysteryNumber,
    String? title,
    String? description,
    String? scriptureText,
    String? meditationText,
  }) {
    return RosaryMystery(
      id: id ?? this.id,
      type: type ?? this.type,
      mysteryNumber: mysteryNumber ?? this.mysteryNumber,
      title: title ?? this.title,
      description: description ?? this.description,
      scriptureText: scriptureText ?? this.scriptureText,
      meditationText: meditationText ?? this.meditationText,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RosaryMystery &&
        other.id == id &&
        other.type == type &&
        other.mysteryNumber == mysteryNumber;
  }

  @override
  int get hashCode => id.hashCode ^ type.hashCode ^ mysteryNumber.hashCode;
}
