import 'package:flutter/foundation.dart';

import 'mystery_set.dart';

/// Represents one of the 20 Mysteries of the Holy Rosary
///
/// There are 5 mysteries in each of the 4 sets:
/// - Joyful Mysteries (Mon, Sat): Annunciation, Visitation, Nativity, Presentation, Finding
/// - Sorrowful Mysteries (Tue, Fri): Agony, Scourging, Crowning, Carrying Cross, Crucifixion
/// - Glorious Mysteries (Wed, Sun): Resurrection, Ascension, Pentecost, Assumption, Coronation
/// - Luminous Mysteries (Thu): Baptism, Cana, Kingdom, Transfiguration, Eucharist
@immutable
class Mystery {
  /// Unique identifier (e.g., 'joyful-1', 'sorrowful-3')
  final String id;

  /// Display name of the mystery
  final String name;

  /// Which set this mystery belongs to
  final MysterySet mysterySet;

  /// Number within the set (1-5)
  final int number;

  /// The spiritual fruit associated with this mystery
  /// e.g., "Humility", "Love of neighbor", "Poverty of spirit"
  final String fruit;

  /// Scripture reference(s) for meditation
  /// e.g., "Luke 1:26-38" for the Annunciation
  final String scripture;

  /// Brief meditation text describing the mystery
  final String description;

  /// Extended meditation text for deeper reflection (optional)
  final String? extendedMeditation;

  /// URL or path to an image representing this mystery (optional)
  final String? imagePath;

  /// Optional icon identifier for UI representation
  final String? iconName;

  const Mystery({
    required this.id,
    required this.name,
    required this.mysterySet,
    required this.number,
    required this.fruit,
    required this.scripture,
    required this.description,
    this.extendedMeditation,
    this.imagePath,
    this.iconName,
  }) : assert(
         number >= 1 && number <= 5,
         'Mystery number must be between 1 and 5',
       );

  /// Create from JSON for persistence
  factory Mystery.fromJson(Map<String, dynamic> json) {
    return Mystery(
      id: json['id'] as String,
      name: json['name'] as String,
      mysterySet: MysterySet.fromString(json['mysterySet'] as String?),
      number: json['number'] as int,
      fruit: json['fruit'] as String,
      scripture: json['scripture'] as String,
      description: json['description'] as String,
      extendedMeditation: json['extendedMeditation'] as String?,
      imagePath: json['imagePath'] as String?,
      iconName: json['iconName'] as String?,
    );
  }

  /// Convert to JSON for persistence
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'mysterySet': mysterySet.toStringValue(),
      'number': number,
      'fruit': fruit,
      'scripture': scripture,
      'description': description,
      'extendedMeditation': extendedMeditation,
      'imagePath': imagePath,
      'iconName': iconName,
    };
  }

  /// Create a copy with updated fields
  Mystery copyWith({
    String? id,
    String? name,
    MysterySet? mysterySet,
    int? number,
    String? fruit,
    String? scripture,
    String? description,
    String? extendedMeditation,
    String? imagePath,
    String? iconName,
  }) {
    return Mystery(
      id: id ?? this.id,
      name: name ?? this.name,
      mysterySet: mysterySet ?? this.mysterySet,
      number: number ?? this.number,
      fruit: fruit ?? this.fruit,
      scripture: scripture ?? this.scripture,
      description: description ?? this.description,
      extendedMeditation: extendedMeditation ?? this.extendedMeditation,
      imagePath: imagePath ?? this.imagePath,
      iconName: iconName ?? this.iconName,
    );
  }

  /// Get the full title including the set name
  String get fullTitle => '${mysterySet.shortName}: $name';

  /// Get a formatted scripture reference for display
  String get formattedScripture => 'Scripture: $scripture';

  /// Get a formatted fruit for display
  String get formattedFruit => 'Fruit: $fruit';

  /// Get the display order number (1-20 across all sets)
  int get globalOrder {
    final setOffset = switch (mysterySet) {
      MysterySet.joyful => 0,
      MysterySet.sorrowful => 5,
      MysterySet.glorious => 10,
      MysterySet.luminous => 15,
    };
    return setOffset + number;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Mystery && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'Mystery(id: $id, name: $name, set: ${mysterySet.name}, number: $number)';
  }
}
