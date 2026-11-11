import '../models/scripture_reference.dart';
import 'book_mapping.dart';

/// Utility class for parsing scripture references from text
class ReferenceParser {
  /// Parse a scripture reference from text with enhanced error handling
  static ScriptureReference parse(String referenceText) {
    final trimmed = referenceText.trim();

    if (trimmed.isEmpty) {
      throw ArgumentError('Reference text cannot be empty');
    }

    try {
      return ScriptureReference.parse(trimmed);
    } catch (e) {
      // Try enhanced parsing for common formats
      return _enhancedParse(trimmed);
    }
  }

  /// Enhanced parsing for various reference formats
  static ScriptureReference _enhancedParse(String referenceText) {
    // Remove common prefixes and suffixes
    String cleaned = referenceText
        .replaceAll(
          RegExp(r'^(cf\.|see\s+|compare\s+)', caseSensitive: false),
          '',
        )
        .replaceAll(RegExp(r'\s*\([^)]*\)$'), '') // Remove trailing parentheses
        .trim();

    // Try different parsing strategies

    // Strategy 1: Handle books with numbers at the start
    final numberBookMatch = RegExp(
      r'^(\d+)\s+([a-zA-Z\s]+)\s+(\d+(?::\d+(?:-\d+)?)?)',
    ).firstMatch(cleaned);
    if (numberBookMatch != null) {
      final bookNumber = numberBookMatch.group(1)!;
      final bookName = numberBookMatch.group(2)!.trim();
      final chapterVerse = numberBookMatch.group(3)!;

      final fullBookName = '$bookNumber $bookName';
      return _parseWithBookAndChapterVerse(
        fullBookName,
        chapterVerse,
        referenceText,
      );
    }

    // Strategy 2: Split on last numeric part
    final parts = cleaned.split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      for (int i = parts.length - 1; i >= 1; i--) {
        if (RegExp(r'^\d+').hasMatch(parts[i])) {
          final book = parts.take(i).join(' ');
          final chapterVerse = parts[i];

          // Validate book name
          if (BibleBookMapping.findBook(book) != null) {
            return _parseWithBookAndChapterVerse(
              book,
              chapterVerse,
              referenceText,
            );
          }
        }
      }
    }

    // Strategy 3: Common abbreviations
    final abbrevMatch = RegExp(
      r'^([a-zA-Z]{2,6}\.?)\s+(\d+(?::\d+(?:-\d+)?)?)',
    ).firstMatch(cleaned);
    if (abbrevMatch != null) {
      final abbrev = abbrevMatch.group(1)!.replaceAll('.', '');
      final chapterVerse = abbrevMatch.group(2)!;

      final metadata = BibleBookMapping.getByAbbreviation(abbrev);
      if (metadata != null) {
        return _parseWithBookAndChapterVerse(
          metadata.name,
          chapterVerse,
          referenceText,
        );
      }
    }

    throw ArgumentError('Unable to parse scripture reference: $referenceText');
  }

  /// Parse when we have separated book and chapter:verse
  static ScriptureReference _parseWithBookAndChapterVerse(
    String book,
    String chapterVerse,
    String originalText,
  ) {
    final colonParts = chapterVerse.split(':');
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
      displayText: originalText,
    );
  }

  /// Try to parse multiple references from a single string
  static List<ScriptureReference> parseMultiple(String text) {
    final references = <ScriptureReference>[];

    // Common patterns for multiple references
    final patterns = [
      // Semicolon separated: "John 3:16; Romans 6:23"
      RegExp(r'([^;]+)'),
      // Comma separated: "Matthew 5:3, Luke 6:20"
      RegExp(r'([^,]+)'),
    ];

    for (final pattern in patterns) {
      final matches = pattern.allMatches(text);
      if (matches.length > 1) {
        for (final match in matches) {
          final refText = match.group(1)?.trim();
          if (refText != null && refText.isNotEmpty) {
            try {
              references.add(parse(refText));
            } catch (e) {
              // Skip invalid references
            }
          }
        }
        if (references.isNotEmpty) break;
      }
    }

    // If no multiple references found, try single reference
    if (references.isEmpty) {
      try {
        references.add(parse(text));
      } catch (e) {
        // Return empty list if nothing can be parsed
      }
    }

    return references;
  }

  /// Validate that a reference string could be valid
  static bool isValidReference(String referenceText) {
    try {
      parse(referenceText);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Extract book name from reference text
  static String? extractBookName(String referenceText) {
    try {
      final ref = parse(referenceText);
      return ref.book;
    } catch (e) {
      return null;
    }
  }

  /// Normalize reference text to a standard format
  static String? normalize(String referenceText) {
    try {
      final ref = parse(referenceText);

      // Use canonical book name if available
      final metadata =
          BibleBookMapping.getByName(ref.book) ??
          BibleBookMapping.getByAbbreviation(ref.book) ??
          BibleBookMapping.getById(ref.book);
      final bookName = metadata?.name ?? ref.book;

      if (ref.startVerse != null) {
        if (ref.isSingleVerse) {
          return '$bookName ${ref.chapter}:${ref.startVerse}';
        } else {
          return '$bookName ${ref.chapter}:${ref.startVerse}-${ref.endVerse}';
        }
      } else {
        return '$bookName ${ref.chapter}';
      }
    } catch (e) {
      return null;
    }
  }
}
