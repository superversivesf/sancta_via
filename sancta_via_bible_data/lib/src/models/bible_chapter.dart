import 'package:meta/meta.dart';
import 'bible_verse.dart';

/// Represents a Bible chapter containing verses
@immutable
class BibleChapter {
  /// The chapter number (0 for prologues/introductions)
  final int number;

  /// List of verses in this chapter
  final List<BibleVerse> verses;

  const BibleChapter({required this.number, required this.verses});

  /// Create a BibleChapter from JSON data
  factory BibleChapter.fromJson(Map<String, dynamic> json) {
    // Handle both old and new formats
    final numberValue = json['number'] ?? json['chapter'];
    final versesValue = json['verses'];

    if (versesValue == null) {
      throw FormatException('BibleChapter verses is null in JSON: $json');
    }

    // Handle null chapter numbers (prologues, introductions, etc.)
    int chapterNumber;
    if (numberValue == null) {
      chapterNumber = 0;
    } else if (numberValue is int) {
      chapterNumber = numberValue;
    } else {
      chapterNumber = int.parse(numberValue.toString());
    }

    try {
      return BibleChapter(
        number: chapterNumber,
        verses: (versesValue as List<dynamic>).map((verse) {
          try {
            return BibleVerse.fromJson(verse as Map<String, dynamic>);
          } catch (e) {
            throw FormatException(
              'Error parsing verse in chapter $chapterNumber: $e',
            );
          }
        }).toList(),
      );
    } catch (e) {
      throw FormatException('Error parsing BibleChapter: $e, JSON: $json');
    }
  }

  /// Convert to JSON representation
  Map<String, dynamic> toJson() {
    return {
      'number': number,
      'verses': verses.map((verse) => verse.toJson()).toList(),
    };
  }

  /// Get verse text by verse number
  String? getVerseText(int verseNumber) {
    try {
      return verses.firstWhere((verse) => verse.number == verseNumber).text;
    } catch (e) {
      return null;
    }
  }

  /// Get a specific verse by number
  BibleVerse? getVerse(int verseNumber) {
    try {
      return verses.firstWhere((verse) => verse.number == verseNumber);
    } catch (e) {
      return null;
    }
  }

  /// Get verses in a range (e.g., verses 1-5)
  List<BibleVerse> getVerseRange(int startVerse, int endVerse) {
    return verses
        .where(
          (verse) => verse.number >= startVerse && verse.number <= endVerse,
        )
        .toList();
  }

  /// Get all verse numbers in this chapter
  List<int> get verseNumbers => verses.map((v) => v.number).toList();

  /// Get the maximum verse number in this chapter
  int get maxVerseNumber => verses.isEmpty
      ? 0
      : verses.map((v) => v.number).reduce((a, b) => a > b ? a : b);

  /// Check if a verse number exists in this chapter
  bool hasVerse(int verseNumber) => verses.any((v) => v.number == verseNumber);

  /// Get the full text of the chapter with verse numbers
  String get fullText =>
      verses.map((verse) => '${verse.number} ${verse.text}').join(' ');

  /// Get the full text of the chapter without verse numbers
  String get textOnly => verses.map((verse) => verse.text).join(' ');

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BibleChapter &&
        other.number == number &&
        _listEquals(other.verses, verses);
  }

  @override
  int get hashCode => Object.hash(number, Object.hashAll(verses));

  @override
  String toString() =>
      'BibleChapter(number: $number, verseCount: ${verses.length})';

  /// Create a copy with modified values
  BibleChapter copyWith({int? number, List<BibleVerse>? verses}) {
    return BibleChapter(
      number: number ?? this.number,
      verses: verses ?? this.verses,
    );
  }

  // Helper method for list equality
  bool _listEquals<T>(List<T> a, List<T> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
