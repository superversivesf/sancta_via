import 'package:flutter/foundation.dart';

import 'prayer_type.dart';

/// Represents a prayer used in the Holy Rosary
///
/// Includes all standard rosary prayers:
/// - Apostles' Creed
/// - Our Father
/// - Hail Mary (full and partial for decades)
/// - Glory Be
/// - Fatima Prayer (O My Jesus)
/// - Hail Holy Queen
@immutable
class RosaryPrayer {
  /// Unique identifier for this prayer
  final String id;

  /// Display title for the prayer
  final String title;

  /// The full text of the prayer
  final String text;

  /// Type of prayer (opening, mystery, closing, etc.)
  final PrayerType type;

  /// Optional short description or instructions
  final String? description;

  /// For partial prayers (like Hail Marys in a decade),
  /// this is the first part to show before the repeated portion
  final String? partialStart;

  /// For partial prayers, this is the repeated portion
  /// (e.g., "Holy Mary, Mother of God...")
  final String? partialRepeat;

  /// For partial prayers, this is the ending to show after all repetitions
  final String? partialEnd;

  /// Number of times to repeat the partialRepeat (e.g., 10 for Hail Marys)
  final int? repeatCount;

  /// Optional order/position in the rosary sequence
  /// (e.g., 1 for Sign of the Cross, 2 for Apostles' Creed, etc.)
  final int? sequenceOrder;

  const RosaryPrayer({
    required this.id,
    required this.title,
    required this.text,
    required this.type,
    this.description,
    this.partialStart,
    this.partialRepeat,
    this.partialEnd,
    this.repeatCount,
    this.sequenceOrder,
  });

  /// Create from JSON for persistence
  factory RosaryPrayer.fromJson(Map<String, dynamic> json) {
    return RosaryPrayer(
      id: json['id'] as String,
      title: json['title'] as String,
      text: json['text'] as String,
      type: PrayerType.fromString(json['type'] as String?),
      description: json['description'] as String?,
      partialStart: json['partialStart'] as String?,
      partialRepeat: json['partialRepeat'] as String?,
      partialEnd: json['partialEnd'] as String?,
      repeatCount: json['repeatCount'] as int?,
      sequenceOrder: json['sequenceOrder'] as int?,
    );
  }

  /// Convert to JSON for persistence
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'text': text,
      'type': type.toStringValue(),
      'description': description,
      'partialStart': partialStart,
      'partialRepeat': partialRepeat,
      'partialEnd': partialEnd,
      'repeatCount': repeatCount,
      'sequenceOrder': sequenceOrder,
    };
  }

  /// Create a copy with updated fields
  RosaryPrayer copyWith({
    String? id,
    String? title,
    String? text,
    PrayerType? type,
    String? description,
    String? partialStart,
    String? partialRepeat,
    String? partialEnd,
    int? repeatCount,
    int? sequenceOrder,
  }) {
    return RosaryPrayer(
      id: id ?? this.id,
      title: title ?? this.title,
      text: text ?? this.text,
      type: type ?? this.type,
      description: description ?? this.description,
      partialStart: partialStart ?? this.partialStart,
      partialRepeat: partialRepeat ?? this.partialRepeat,
      partialEnd: partialEnd ?? this.partialEnd,
      repeatCount: repeatCount ?? this.repeatCount,
      sequenceOrder: sequenceOrder ?? this.sequenceOrder,
    );
  }

  /// Get the full text formatted for display
  /// For partial prayers, includes the complete structure
  String get formattedText {
    if (partialRepeat == null || repeatCount == null) {
      return text;
    }

    final buffer = StringBuffer();

    if (partialStart != null && partialStart!.isNotEmpty) {
      buffer.writeln(partialStart);
      buffer.writeln();
    }

    for (var i = 0; i < repeatCount!; i++) {
      buffer.writeln('${i + 1}. $partialRepeat');
    }

    if (partialEnd != null && partialEnd!.isNotEmpty) {
      buffer.writeln();
      buffer.writeln(partialEnd);
    }

    return buffer.toString();
  }

  /// Whether this prayer uses partial/repeated structure
  bool get isPartial => partialRepeat != null && repeatCount != null;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RosaryPrayer && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'RosaryPrayer(id: $id, title: $title, type: ${type.name})';
  }
}
