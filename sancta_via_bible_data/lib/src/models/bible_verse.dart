import 'package:meta/meta.dart';

/// Represents a single Bible verse with its number and text content
@immutable
class BibleVerse {
  /// The verse number within the chapter
  final int number;

  /// The text content of the verse
  final String text;

  const BibleVerse({
    required this.number,
    required this.text,
  });

  /// Create a BibleVerse from JSON data
  factory BibleVerse.fromJson(Map<String, dynamic> json) {
    // Handle both old and new formats
    final numberValue = json['number'] ?? json['verse'];
    final textValue = json['text'];

    if (numberValue == null) {
      throw FormatException('BibleVerse number/verse is null in JSON: $json');
    }
    if (textValue == null) {
      throw FormatException('BibleVerse text is null in JSON: $json');
    }

    return BibleVerse(
      number:
          numberValue is int ? numberValue : int.parse(numberValue.toString()),
      text: textValue.toString().trim(), // Trim whitespace from text
    );
  }

  /// Convert to JSON representation
  Map<String, dynamic> toJson() {
    return {
      'number': number,
      'text': text,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BibleVerse && other.number == number && other.text == text;
  }

  @override
  int get hashCode => Object.hash(number, text);

  @override
  String toString() =>
      'BibleVerse(number: $number, text: ${text.substring(0, text.length > 50 ? 50 : text.length)}...)';

  /// Create a copy with modified values
  BibleVerse copyWith({
    int? number,
    String? text,
  }) {
    return BibleVerse(
      number: number ?? this.number,
      text: text ?? this.text,
    );
  }
}
