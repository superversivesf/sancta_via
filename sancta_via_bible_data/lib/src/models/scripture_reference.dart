import 'package:meta/meta.dart';

/// Represents a scripture reference (e.g., "Genesis 1:1-5", "Psalm 23")
@immutable
class ScriptureReference {
  /// Book name (e.g., "Genesis", "Psalms", "Matthew")
  final String book;

  /// Chapter number
  final int chapter;

  /// Starting verse number (null for entire chapter)
  final int? startVerse;

  /// Ending verse number (null for single verse or entire chapter)
  final int? endVerse;

  /// Full reference text for display (e.g., "Genesis 1:1-5")
  final String displayText;

  const ScriptureReference({
    required this.book,
    required this.chapter,
    this.startVerse,
    this.endVerse,
    required this.displayText,
  });

  /// Create a ScriptureReference from JSON data
  factory ScriptureReference.fromJson(Map<String, dynamic> json) {
    return ScriptureReference(
      book: json['book'] as String,
      chapter: json['chapter'] as int,
      startVerse: json['startVerse'] as int?,
      endVerse: json['endVerse'] as int?,
      displayText: json['displayText'] as String,
    );
  }

  /// Convert to JSON representation
  Map<String, dynamic> toJson() {
    return {
      'book': book,
      'chapter': chapter,
      'startVerse': startVerse,
      'endVerse': endVerse,
      'displayText': displayText,
    };
  }

  /// Parse a reference string like "Genesis 1:1-5" or "Psalm 23"
  static ScriptureReference parse(String referenceText) {
    final trimmed = referenceText.trim();

    // Handle cases like "1 Corinthians 12:4-11" or "2 Samuel 7:1-17"
    final parts = trimmed.split(' ');
    if (parts.length < 2) {
      throw ArgumentError('Invalid scripture reference: $referenceText');
    }

    String book;
    String chapterAndVerse;

    // Find the last part that contains numbers (chapter:verse)
    int chapterVerseIndex = -1;
    for (int i = parts.length - 1; i >= 0; i--) {
      if (RegExp(r'\d').hasMatch(parts[i])) {
        chapterVerseIndex = i;
        break;
      }
    }

    if (chapterVerseIndex == -1) {
      throw ArgumentError(
        'No chapter/verse found in reference: $referenceText',
      );
    }

    book = parts.take(chapterVerseIndex).join(' ');
    chapterAndVerse = parts[chapterVerseIndex];

    // Handle cases where there might be more parts after the chapter:verse
    if (chapterVerseIndex < parts.length - 1) {
      // This could be something like "Psalm 23 (traditional)" - ignore extra parts
      // Just use what we found
    }

    final colonParts = chapterAndVerse.split(':');
    final chapter = int.parse(colonParts[0]);

    int? startVerse;
    int? endVerse;

    if (colonParts.length > 1) {
      final verseParts = colonParts[1].split('-');
      startVerse = int.parse(verseParts[0]);
      if (verseParts.length > 1) {
        endVerse = int.parse(verseParts[1]);
      } else {
        endVerse = startVerse;
      }
    }

    return ScriptureReference(
      book: book,
      chapter: chapter,
      startVerse: startVerse,
      endVerse: endVerse,
      displayText: trimmed,
    );
  }

  /// Create a reference for an entire chapter
  factory ScriptureReference.chapter(String book, int chapter) {
    return ScriptureReference(
      book: book,
      chapter: chapter,
      startVerse: null,
      endVerse: null,
      displayText: '$book $chapter',
    );
  }

  /// Create a reference for a single verse
  factory ScriptureReference.verse(String book, int chapter, int verse) {
    return ScriptureReference(
      book: book,
      chapter: chapter,
      startVerse: verse,
      endVerse: verse,
      displayText: '$book $chapter:$verse',
    );
  }

  /// Create a reference for a verse range
  factory ScriptureReference.range(
    String book,
    int chapter,
    int startVerse,
    int endVerse,
  ) {
    return ScriptureReference(
      book: book,
      chapter: chapter,
      startVerse: startVerse,
      endVerse: endVerse,
      displayText: '$book $chapter:$startVerse-$endVerse',
    );
  }

  /// Create a unique key for caching
  String get cacheKey =>
      '${book.toLowerCase()}_${chapter}_${startVerse}_$endVerse';

  /// Check if this reference is for an entire chapter
  bool get isEntireChapter => startVerse == null && endVerse == null;

  /// Check if this reference is for a single verse
  bool get isSingleVerse => startVerse != null && startVerse == endVerse;

  /// Check if this reference is for a verse range
  bool get isVerseRange =>
      startVerse != null && endVerse != null && startVerse != endVerse;

  /// Get the number of verses in this reference (1 for single verse, null for entire chapter)
  int? get verseCount {
    if (startVerse == null || endVerse == null) return null;
    return endVerse! - startVerse! + 1;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ScriptureReference &&
        other.book == book &&
        other.chapter == chapter &&
        other.startVerse == startVerse &&
        other.endVerse == endVerse &&
        other.displayText == displayText;
  }

  @override
  int get hashCode =>
      Object.hash(book, chapter, startVerse, endVerse, displayText);

  @override
  String toString() => 'ScriptureReference($displayText)';

  /// Create a copy with modified values
  ScriptureReference copyWith({
    String? book,
    int? chapter,
    int? startVerse,
    int? endVerse,
    String? displayText,
  }) {
    return ScriptureReference(
      book: book ?? this.book,
      chapter: chapter ?? this.chapter,
      startVerse: startVerse ?? this.startVerse,
      endVerse: endVerse ?? this.endVerse,
      displayText: displayText ?? this.displayText,
    );
  }
}
