/// Utility for normalizing Bible book names between different formats
///
/// Handles conversion between Roman numerals (I, II, III) and Arabic numerals (1, 2, 3)
/// in Bible book names to ensure consistent database queries.
class BookNameNormalizer {
  /// Map from Arabic to Roman numerals
  static const Map<String, String> _arabicToRoman = {
    '1': 'I',
    '2': 'II',
    '3': 'III',
  };

  /// Map from Roman to Arabic numerals
  static const Map<String, String> _romanToArabic = {
    'I': '1',
    'II': '2',
    'III': '3',
  };

  /// Common book name variations that need normalization
  static const Map<String, String> _bookNameVariations = {
    // Ensure consistent naming
    // 'Revelation of John': 'Revelation', // Removed - database uses full name
    // 'The Revelation of John': 'Revelation', // Removed - database uses full name
    // Add more variations as needed
  };

  /// Convert book name from Arabic numerals to Roman numerals (for database queries)
  ///
  /// Examples:
  /// - "1 Samuel" → "I Samuel"
  /// - "2 Corinthians" → "II Corinthians"
  /// - "3 John" → "III John"
  static String toRomanNumerals(String bookName) {
    String normalized = bookName.trim();

    // Handle book name variations first
    if (_bookNameVariations.containsKey(normalized)) {
      normalized = _bookNameVariations[normalized]!;
    }

    // Convert Arabic numerals to Roman numerals at the start of book names
    for (final entry in _arabicToRoman.entries) {
      final arabicPrefix = '${entry.key} ';
      final romanPrefix = '${entry.value} ';

      if (normalized.startsWith(arabicPrefix)) {
        return normalized.replaceFirst(arabicPrefix, romanPrefix);
      }
    }

    return normalized;
  }

  /// Convert book name from Roman numerals to Arabic numerals (for user display)
  ///
  /// Examples:
  /// - "I Samuel" → "1 Samuel"
  /// - "II Corinthians" → "2 Corinthians"
  /// - "III John" → "3 John"
  static String toArabicNumerals(String bookName) {
    String normalized = bookName.trim();

    // Convert Roman numerals to Arabic numerals at the start of book names
    for (final entry in _romanToArabic.entries) {
      final romanPrefix = '${entry.key} ';
      final arabicPrefix = '${entry.value} ';

      if (normalized.startsWith(romanPrefix)) {
        return normalized.replaceFirst(romanPrefix, arabicPrefix);
      }
    }

    return normalized;
  }

  /// Get all possible variations of a book name for fuzzy matching
  static List<String> getAllVariations(String bookName) {
    final variations = <String>{};

    // Add original name
    variations.add(bookName.trim());

    // Add Roman numeral version
    variations.add(toRomanNumerals(bookName));

    // Add Arabic numeral version
    variations.add(toArabicNumerals(bookName));

    // Add common variations
    for (final entry in _bookNameVariations.entries) {
      if (entry.value == bookName || entry.key == bookName) {
        variations.add(entry.key);
        variations.add(entry.value);
      }
    }

    // Remove duplicates and empty strings
    return variations.where((name) => name.isNotEmpty).toSet().toList();
  }

  /// Find the database-compatible book name (Roman numerals)
  /// This is what should be used in SQL queries
  static String toDatabaseFormat(String bookName) {
    return toRomanNumerals(bookName);
  }

  /// Find the user-friendly book name (Arabic numerals)
  /// This is what should be displayed to users
  static String toDisplayFormat(String bookName) {
    return toArabicNumerals(bookName);
  }

  /// Check if two book names refer to the same book (ignoring numeral format)
  static bool areEquivalent(String bookName1, String bookName2) {
    final normalized1 = toRomanNumerals(bookName1.trim()).toLowerCase();
    final normalized2 = toRomanNumerals(bookName2.trim()).toLowerCase();
    return normalized1 == normalized2;
  }

  /// Get debug info about book name normalization
  static Map<String, String> getDebugInfo(String bookName) {
    return {
      'original': bookName,
      'roman': toRomanNumerals(bookName),
      'arabic': toArabicNumerals(bookName),
      'database_format': toDatabaseFormat(bookName),
      'display_format': toDisplayFormat(bookName),
    };
  }
}
