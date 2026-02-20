import 'package:meta/meta.dart';

/// Book metadata for mapping book names to IDs and other information
@immutable
class BookMetadata {
  /// Unique book identifier (e.g., 'gen', 'exo', 'mat')
  final String id;

  /// Full book name (e.g., 'Genesis', 'Exodus', 'Matthew')
  final String name;

  /// Common abbreviation (e.g., 'Gen', 'Ex', 'Mt')
  final String abbreviation;

  /// Order in the Catholic Bible (1-73)
  final int order;

  /// Whether this is an Old Testament book
  final bool isOldTestament;

  const BookMetadata({
    required this.id,
    required this.name,
    required this.abbreviation,
    required this.order,
    required this.isOldTestament,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BookMetadata &&
        other.id == id &&
        other.name == name &&
        other.abbreviation == abbreviation &&
        other.order == order &&
        other.isOldTestament == isOldTestament;
  }

  @override
  int get hashCode =>
      Object.hash(id, name, abbreviation, order, isOldTestament);

  @override
  String toString() => 'BookMetadata(id: $id, name: $name, order: $order)';
}

/// Static book metadata mapping for consistent book identification
class BibleBookMapping {
  static const List<BookMetadata> _bookMetadata = [
    // Old Testament
    BookMetadata(
        id: 'gen',
        name: 'Genesis',
        abbreviation: 'Gen',
        order: 1,
        isOldTestament: true),
    BookMetadata(
        id: 'exo',
        name: 'Exodus',
        abbreviation: 'Ex',
        order: 2,
        isOldTestament: true),
    BookMetadata(
        id: 'lev',
        name: 'Leviticus',
        abbreviation: 'Lev',
        order: 3,
        isOldTestament: true),
    BookMetadata(
        id: 'num',
        name: 'Numbers',
        abbreviation: 'Num',
        order: 4,
        isOldTestament: true),
    BookMetadata(
        id: 'deu',
        name: 'Deuteronomy',
        abbreviation: 'Deut',
        order: 5,
        isOldTestament: true),
    BookMetadata(
        id: 'jos',
        name: 'Joshua',
        abbreviation: 'Josh',
        order: 6,
        isOldTestament: true),
    BookMetadata(
        id: 'jdg',
        name: 'Judges',
        abbreviation: 'Judg',
        order: 7,
        isOldTestament: true),
    BookMetadata(
        id: 'rut',
        name: 'Ruth',
        abbreviation: 'Ruth',
        order: 8,
        isOldTestament: true),
    BookMetadata(
        id: '1sa',
        name: '1 Samuel',
        abbreviation: '1 Sam',
        order: 9,
        isOldTestament: true),
    BookMetadata(
        id: '2sa',
        name: '2 Samuel',
        abbreviation: '2 Sam',
        order: 10,
        isOldTestament: true),
    BookMetadata(
        id: '1ki',
        name: '1 Kings',
        abbreviation: '1 Kgs',
        order: 11,
        isOldTestament: true),
    BookMetadata(
        id: '2ki',
        name: '2 Kings',
        abbreviation: '2 Kgs',
        order: 12,
        isOldTestament: true),
    BookMetadata(
        id: '1ch',
        name: '1 Chronicles',
        abbreviation: '1 Chr',
        order: 13,
        isOldTestament: true),
    BookMetadata(
        id: '2ch',
        name: '2 Chronicles',
        abbreviation: '2 Chr',
        order: 14,
        isOldTestament: true),
    BookMetadata(
        id: 'ezr',
        name: 'Ezra',
        abbreviation: 'Ezra',
        order: 15,
        isOldTestament: true),
    BookMetadata(
        id: 'neh',
        name: 'Nehemiah',
        abbreviation: 'Neh',
        order: 16,
        isOldTestament: true),
    BookMetadata(
        id: 'est',
        name: 'Esther',
        abbreviation: 'Esth',
        order: 17,
        isOldTestament: true),
    BookMetadata(
        id: 'job',
        name: 'Job',
        abbreviation: 'Job',
        order: 18,
        isOldTestament: true),
    BookMetadata(
        id: 'psa',
        name: 'Psalms',
        abbreviation: 'Ps',
        order: 19,
        isOldTestament: true),
    BookMetadata(
        id: 'pro',
        name: 'Proverbs',
        abbreviation: 'Prov',
        order: 20,
        isOldTestament: true),
    BookMetadata(
        id: 'ecc',
        name: 'Ecclesiastes',
        abbreviation: 'Eccl',
        order: 21,
        isOldTestament: true),
    BookMetadata(
        id: 'sng',
        name: 'Song of Solomon',
        abbreviation: 'Song',
        order: 22,
        isOldTestament: true),
    BookMetadata(
        id: 'isa',
        name: 'Isaiah',
        abbreviation: 'Is',
        order: 23,
        isOldTestament: true),
    BookMetadata(
        id: 'jer',
        name: 'Jeremiah',
        abbreviation: 'Jer',
        order: 24,
        isOldTestament: true),
    BookMetadata(
        id: 'lam',
        name: 'Lamentations',
        abbreviation: 'Lam',
        order: 25,
        isOldTestament: true),
    BookMetadata(
        id: 'eze',
        name: 'Ezekiel',
        abbreviation: 'Ezek',
        order: 26,
        isOldTestament: true),
    BookMetadata(
        id: 'dan',
        name: 'Daniel',
        abbreviation: 'Dan',
        order: 27,
        isOldTestament: true),
    BookMetadata(
        id: 'hos',
        name: 'Hosea',
        abbreviation: 'Hos',
        order: 28,
        isOldTestament: true),
    BookMetadata(
        id: 'joe',
        name: 'Joel',
        abbreviation: 'Joel',
        order: 29,
        isOldTestament: true),
    BookMetadata(
        id: 'amo',
        name: 'Amos',
        abbreviation: 'Amos',
        order: 30,
        isOldTestament: true),
    BookMetadata(
        id: 'oba',
        name: 'Obadiah',
        abbreviation: 'Obad',
        order: 31,
        isOldTestament: true),
    BookMetadata(
        id: 'jon',
        name: 'Jonah',
        abbreviation: 'Jonah',
        order: 32,
        isOldTestament: true),
    BookMetadata(
        id: 'mic',
        name: 'Micah',
        abbreviation: 'Mic',
        order: 33,
        isOldTestament: true),
    BookMetadata(
        id: 'nah',
        name: 'Nahum',
        abbreviation: 'Nah',
        order: 34,
        isOldTestament: true),
    BookMetadata(
        id: 'hab',
        name: 'Habakkuk',
        abbreviation: 'Hab',
        order: 35,
        isOldTestament: true),
    BookMetadata(
        id: 'zep',
        name: 'Zephaniah',
        abbreviation: 'Zeph',
        order: 36,
        isOldTestament: true),
    BookMetadata(
        id: 'hag',
        name: 'Haggai',
        abbreviation: 'Hag',
        order: 37,
        isOldTestament: true),
    BookMetadata(
        id: 'zec',
        name: 'Zechariah',
        abbreviation: 'Zech',
        order: 38,
        isOldTestament: true),
    BookMetadata(
        id: 'mal',
        name: 'Malachi',
        abbreviation: 'Mal',
        order: 39,
        isOldTestament: true),

    // Deuterocanonical Books (Catholic)
    BookMetadata(
        id: 'tob',
        name: 'Tobit',
        abbreviation: 'Tob',
        order: 40,
        isOldTestament: true),
    BookMetadata(
        id: 'jdt',
        name: 'Judith',
        abbreviation: 'Jdt',
        order: 41,
        isOldTestament: true),
    BookMetadata(
        id: '1ma',
        name: '1 Maccabees',
        abbreviation: '1 Mac',
        order: 42,
        isOldTestament: true),
    BookMetadata(
        id: '2ma',
        name: '2 Maccabees',
        abbreviation: '2 Mac',
        order: 43,
        isOldTestament: true),
    BookMetadata(
        id: 'wis',
        name: 'Wisdom',
        abbreviation: 'Wis',
        order: 44,
        isOldTestament: true),
    BookMetadata(
        id: 'sir',
        name: 'Sirach',
        abbreviation: 'Sir',
        order: 45,
        isOldTestament: true),
    BookMetadata(
        id: 'bar',
        name: 'Baruch',
        abbreviation: 'Bar',
        order: 46,
        isOldTestament: true),

    // New Testament
    BookMetadata(
        id: 'mat',
        name: 'Matthew',
        abbreviation: 'Mt',
        order: 47,
        isOldTestament: false),
    BookMetadata(
        id: 'mrk',
        name: 'Mark',
        abbreviation: 'Mk',
        order: 48,
        isOldTestament: false),
    BookMetadata(
        id: 'luk',
        name: 'Luke',
        abbreviation: 'Lk',
        order: 49,
        isOldTestament: false),
    BookMetadata(
        id: 'joh',
        name: 'John',
        abbreviation: 'Jn',
        order: 50,
        isOldTestament: false),
    BookMetadata(
        id: 'act',
        name: 'Acts',
        abbreviation: 'Acts',
        order: 51,
        isOldTestament: false),
    BookMetadata(
        id: 'rom',
        name: 'Romans',
        abbreviation: 'Rom',
        order: 52,
        isOldTestament: false),
    BookMetadata(
        id: '1co',
        name: '1 Corinthians',
        abbreviation: '1 Cor',
        order: 53,
        isOldTestament: false),
    BookMetadata(
        id: '2co',
        name: '2 Corinthians',
        abbreviation: '2 Cor',
        order: 54,
        isOldTestament: false),
    BookMetadata(
        id: 'gal',
        name: 'Galatians',
        abbreviation: 'Gal',
        order: 55,
        isOldTestament: false),
    BookMetadata(
        id: 'eph',
        name: 'Ephesians',
        abbreviation: 'Eph',
        order: 56,
        isOldTestament: false),
    BookMetadata(
        id: 'phi',
        name: 'Philippians',
        abbreviation: 'Phil',
        order: 57,
        isOldTestament: false),
    BookMetadata(
        id: 'col',
        name: 'Colossians',
        abbreviation: 'Col',
        order: 58,
        isOldTestament: false),
    BookMetadata(
        id: '1th',
        name: '1 Thessalonians',
        abbreviation: '1 Thess',
        order: 59,
        isOldTestament: false),
    BookMetadata(
        id: '2th',
        name: '2 Thessalonians',
        abbreviation: '2 Thess',
        order: 60,
        isOldTestament: false),
    BookMetadata(
        id: '1ti',
        name: '1 Timothy',
        abbreviation: '1 Tim',
        order: 61,
        isOldTestament: false),
    BookMetadata(
        id: '2ti',
        name: '2 Timothy',
        abbreviation: '2 Tim',
        order: 62,
        isOldTestament: false),
    BookMetadata(
        id: 'tit',
        name: 'Titus',
        abbreviation: 'Titus',
        order: 63,
        isOldTestament: false),
    BookMetadata(
        id: 'phm',
        name: 'Philemon',
        abbreviation: 'Phlm',
        order: 64,
        isOldTestament: false),
    BookMetadata(
        id: 'heb',
        name: 'Hebrews',
        abbreviation: 'Heb',
        order: 65,
        isOldTestament: false),
    BookMetadata(
        id: 'jas',
        name: 'James',
        abbreviation: 'Jas',
        order: 66,
        isOldTestament: false),
    BookMetadata(
        id: '1pe',
        name: '1 Peter',
        abbreviation: '1 Pet',
        order: 67,
        isOldTestament: false),
    BookMetadata(
        id: '2pe',
        name: '2 Peter',
        abbreviation: '2 Pet',
        order: 68,
        isOldTestament: false),
    BookMetadata(
        id: '1jo',
        name: '1 John',
        abbreviation: '1 Jn',
        order: 69,
        isOldTestament: false),
    BookMetadata(
        id: '2jo',
        name: '2 John',
        abbreviation: '2 Jn',
        order: 70,
        isOldTestament: false),
    BookMetadata(
        id: '3jo',
        name: '3 John',
        abbreviation: '3 Jn',
        order: 71,
        isOldTestament: false),
    BookMetadata(
        id: 'jud',
        name: 'Jude',
        abbreviation: 'Jude',
        order: 72,
        isOldTestament: false),
    BookMetadata(
        id: 'rev',
        name: 'Revelation',
        abbreviation: 'Rev',
        order: 73,
        isOldTestament: false),
  ];

  /// Get all available book metadata
  static List<BookMetadata> get allBooks => List.unmodifiable(_bookMetadata);

  /// Get Old Testament books only
  static List<BookMetadata> get oldTestamentBooks =>
      _bookMetadata.where((book) => book.isOldTestament).toList();

  /// Get New Testament books only
  static List<BookMetadata> get newTestamentBooks =>
      _bookMetadata.where((book) => !book.isOldTestament).toList();

  /// Get book metadata by name (case insensitive)
  static BookMetadata? getByName(String name) {
    final lowerName = name.toLowerCase();
    try {
      return _bookMetadata.firstWhere(
        (book) => book.name.toLowerCase() == lowerName,
      );
    } catch (e) {
      // Try with Roman/Arabic numeral conversion
      final convertedName = _convertRomanArabicNumerals(name);
      if (convertedName != name) {
        try {
          return _bookMetadata.firstWhere(
            (book) => book.name.toLowerCase() == convertedName.toLowerCase(),
          );
        } catch (e) {
          // Still no match
        }
      }
      return null;
    }
  }

  /// Get book metadata by ID (case insensitive)
  static BookMetadata? getById(String id) {
    final lowerId = id.toLowerCase();
    try {
      return _bookMetadata.firstWhere(
        (book) => book.id.toLowerCase() == lowerId,
      );
    } catch (e) {
      return null;
    }
  }

  /// Get book metadata by abbreviation (case insensitive)
  static BookMetadata? getByAbbreviation(String abbreviation) {
    final lowerAbbr = abbreviation.toLowerCase();
    try {
      return _bookMetadata.firstWhere(
        (book) => book.abbreviation.toLowerCase() == lowerAbbr,
      );
    } catch (e) {
      return null;
    }
  }

  /// Find book by any identifier (name, ID, or abbreviation)
  static BookMetadata? findBook(String identifier) {
    // Try each method in order
    return getByName(identifier) ??
        getById(identifier) ??
        getByAbbreviation(identifier);
  }

  /// Generate ID from book name for unknown books
  static String generateId(String name) {
    final cleaned = name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    return cleaned.substring(0, cleaned.length > 6 ? 6 : cleaned.length);
  }

  /// Convert between Roman numerals (I, II, III) and Arabic numerals (1, 2, 3)
  static String _convertRomanArabicNumerals(String bookName) {
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

  /// Get books by testament
  static List<BookMetadata> getBooksByTestament(bool isOldTestament) {
    return _bookMetadata
        .where((book) => book.isOldTestament == isOldTestament)
        .toList();
  }

  /// Check if a book name is valid
  static bool isValidBookName(String name) {
    return getByName(name) != null;
  }

  /// Get book order number by name
  static int? getBookOrder(String name) {
    return getByName(name)?.order;
  }

  /// Determine if a book is in the Old Testament based on its order number.
  ///
  /// The Catholic Bible has 46 Old Testament books (order 1-46) and
  /// 27 New Testament books (order 47-73).
  ///
  /// Note: Deuterocanonical books (Tobit, Judith, 1-2 Maccabees, Wisdom,
  /// Sirach, Baruch - orders 40-46) are included in the Old Testament.
  static bool isOldTestamentByOrder(int bookOrder) {
    return bookOrder <= _kOldTestamentBookCount;
  }

  /// Determine if a book is in the Old Testament based on its zero-based index.
  ///
  /// This is equivalent to [isOldTestamentByOrder] but takes an index
  /// (0-72) instead of an order (1-73). Book at index 45 is the last OT book.
  static bool isOldTestamentByIndex(int bookIndex) {
    return bookIndex < _kOldTestamentBookCount;
  }

  /// Number of books in the Old Testament (Catholic canon includes Deuterocanonical)
  static const int _kOldTestamentBookCount = 46;

  /// Number of books in the New Testament
  static const int kNewTestamentBookCount = 27;

  /// Total number of books in the Catholic Bible
  static const int kTotalBookCount =
      _kOldTestamentBookCount + kNewTestamentBookCount; // 73
}
