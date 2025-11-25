import 'package:meta/meta.dart';
import 'bible_translation.dart';
import 'bible_book.dart';

/// Complete Bible translation with all books
@immutable
class Bible {
  /// The translation type
  final BibleTranslation translation;

  /// List of all books in this Bible
  final List<BibleBook> books;

  /// Additional metadata about this Bible
  final Map<String, dynamic> metadata;

  const Bible({
    required this.translation,
    required this.books,
    required this.metadata,
  });

  /// Create a Bible from JSON data
  factory Bible.fromJson(Map<String, dynamic> json) {
    final booksValue = json['books'];

    if (booksValue == null) {
      throw FormatException('Bible books is null in JSON');
    }

    // Extract translation info from metadata or top-level
    final metadataMap = Map<String, dynamic>.from(json['metadata'] ?? {});
    final translationName = json['translation']?.toString() ??
        metadataMap['name']?.toString() ??
        'Unknown Translation';

    // Map translation names to enum values
    BibleTranslation translation;
    switch (translationName.toLowerCase()) {
      case 'catholic public domain version':
      case 'cpdv':
        translation = BibleTranslation.cpdv;
        break;
      case 'douay-rheims 1899':
      case 'douay-rheims':
      case 'drc':
        translation = BibleTranslation.drc;
        break;
      case 'world english bible catholic':
      case 'world english bible':
      case 'web':
      case 'engwebc':
        translation = BibleTranslation.engwebc;
        break;
      default:
        // Try to match by abbreviation if available
        final abbreviation =
            metadataMap['abbreviation']?.toString().toLowerCase() ?? '';
        switch (abbreviation) {
          case 'drc':
            translation = BibleTranslation.drc;
            break;
          case 'web':
          case 'web-c':
          case 'webc':
            translation = BibleTranslation.engwebc;
            break;
          case 'cpdv':
          default:
            translation = BibleTranslation.cpdv; // Default fallback
        }
    }

    try {
      return Bible(
        translation: translation,
        books: (booksValue as List<dynamic>).asMap().entries.map((entry) {
          try {
            return BibleBook.fromJson(entry.value as Map<String, dynamic>);
          } catch (e) {
            final bookData = entry.value as Map<String, dynamic>;
            final bookName = bookData['name'] ?? 'Unknown';
            throw FormatException(
                'Error parsing book at index ${entry.key} ("$bookName"): $e');
          }
        }).toList(),
        metadata: metadataMap,
      );
    } catch (e) {
      throw FormatException('Error parsing Bible: $e');
    }
  }

  /// Convert to JSON representation
  Map<String, dynamic> toJson() {
    return {
      'translation': translation.id,
      'books': books.map((book) => book.toJson()).toList(),
      'metadata': metadata,
    };
  }

  /// Get book by ID (case insensitive)
  BibleBook? getBook(String bookId) {
    try {
      return books
          .firstWhere((book) => book.id.toLowerCase() == bookId.toLowerCase());
    } catch (e) {
      return null;
    }
  }

  /// Get book by name, ID, or abbreviation
  BibleBook? findBook(String bookIdentifier) {
    final lowerId = bookIdentifier.toLowerCase();

    // First try exact matching
    try {
      return books.firstWhere((book) =>
          book.id.toLowerCase() == lowerId ||
          book.name.toLowerCase() == lowerId ||
          book.abbreviation.toLowerCase() == lowerId);
    } catch (e) {
      // If no exact match, try with Roman/Arabic numeral conversion
      final convertedId = _convertRomanArabicNumerals(bookIdentifier);
      if (convertedId != bookIdentifier) {
        try {
          final convertedLowerId = convertedId.toLowerCase();
          return books.firstWhere((book) =>
              book.id.toLowerCase() == convertedLowerId ||
              book.name.toLowerCase() == convertedLowerId ||
              book.abbreviation.toLowerCase() == convertedLowerId);
        } catch (e) {
          // Still no match
        }
      }
      return null;
    }
  }

  /// Get all Old Testament books
  List<BibleBook> get oldTestamentBooks =>
      books.where((book) => book.isOldTestament).toList();

  /// Get all New Testament books
  List<BibleBook> get newTestamentBooks =>
      books.where((book) => !book.isOldTestament).toList();

  /// Get total number of books
  int get bookCount => books.length;

  /// Get total number of chapters across all books
  int get totalChapterCount =>
      books.fold(0, (sum, book) => sum + book.chapters.length);

  /// Get total number of verses across all books
  int get totalVerseCount =>
      books.fold(0, (sum, book) => sum + book.totalVerseCount);

  /// Search for text across all books
  List<String> searchText(String query) {
    final results = <String>[];
    for (final book in books) {
      results.addAll(book.searchText(query));
    }
    return results;
  }

  /// Get verse text by reference
  String? getVerseText(String bookName, int chapter, int verse) {
    final book = findBook(bookName);
    return book?.getVerseText(chapter, verse);
  }

  /// Get chapter text by reference
  String? getChapterText(String bookName, int chapter) {
    final book = findBook(bookName);
    final chapterObj = book?.getChapter(chapter);
    return chapterObj?.fullText;
  }

  /// Get verse range text
  String? getVerseRangeText(
      String bookName, int chapter, int startVerse, int endVerse) {
    final book = findBook(bookName);
    final chapterObj = book?.getChapter(chapter);
    if (chapterObj == null) return null;

    final verses = chapterObj.getVerseRange(startVerse, endVerse);
    return verses.map((verse) => '${verse.number} ${verse.text}').join(' ');
  }

  /// Get books sorted by canonical order
  List<BibleBook> get booksInOrder {
    final sortedBooks = List<BibleBook>.from(books);
    sortedBooks.sort((a, b) => a.order.compareTo(b.order));
    return sortedBooks;
  }

  /// Check if a book exists in this Bible
  bool hasBook(String bookIdentifier) => findBook(bookIdentifier) != null;

  /// Get book names (useful for autocomplete)
  List<String> get bookNames => books.map((book) => book.name).toList();

  /// Get book abbreviations (useful for autocomplete)
  List<String> get bookAbbreviations =>
      books.map((book) => book.abbreviation).toList();

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Bible &&
        other.translation == translation &&
        _listEquals(other.books, books) &&
        _mapEquals(other.metadata, metadata);
  }

  @override
  int get hashCode => Object.hash(
      translation, Object.hashAll(books), Object.hashAll(metadata.entries));

  @override
  String toString() => 'Bible(${translation.name}, ${books.length} books)';

  /// Create a copy with modified values
  Bible copyWith({
    BibleTranslation? translation,
    List<BibleBook>? books,
    Map<String, dynamic>? metadata,
  }) {
    return Bible(
      translation: translation ?? this.translation,
      books: books ?? this.books,
      metadata: metadata ?? this.metadata,
    );
  }

  /// Convert between Roman numerals (I, II, III) and Arabic numerals (1, 2, 3)
  String _convertRomanArabicNumerals(String bookName) {
    // Map of conversions in both directions
    final conversions = {
      // Roman to Arabic
      r'^I ': '1 ',
      r'^II ': '2 ',
      r'^III ': '3 ',
      r'^IV ': '4 ',
      // Arabic to Roman
      r'^1 ': 'I ',
      r'^2 ': 'II ',
      r'^3 ': 'III ',
      r'^4 ': 'IV ',
    };

    for (final entry in conversions.entries) {
      if (RegExp(entry.key).hasMatch(bookName)) {
        return bookName.replaceFirst(RegExp(entry.key), entry.value);
      }
    }

    return bookName; // No conversion needed
  }

  // Helper methods for equality checks
  bool _listEquals<T>(List<T> a, List<T> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  bool _mapEquals<K, V>(Map<K, V> a, Map<K, V> b) {
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (!b.containsKey(key) || a[key] != b[key]) return false;
    }
    return true;
  }
}
