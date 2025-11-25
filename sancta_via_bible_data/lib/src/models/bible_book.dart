import 'package:meta/meta.dart';
import 'bible_chapter.dart';
import '../utils/book_mapping.dart';

/// Represents a Bible book containing chapters
@immutable
class BibleBook {
  /// Unique book identifier (e.g., "gen", "exo", "mat", "mrk")
  final String id;

  /// Full book name (e.g., "Genesis", "Exodus", "Matthew", "Mark")
  final String name;

  /// Common abbreviation (e.g., "Gen", "Ex", "Mt", "Mk")
  final String abbreviation;

  /// Order in the Bible (1-73 for Catholic Bible)
  final int order;

  /// Whether this is an Old Testament book
  final bool isOldTestament;

  /// List of chapters in this book
  final List<BibleChapter> chapters;

  const BibleBook({
    required this.id,
    required this.name,
    required this.abbreviation,
    required this.order,
    required this.isOldTestament,
    required this.chapters,
  });

  /// Create a BibleBook from JSON data
  factory BibleBook.fromJson(Map<String, dynamic> json) {
    // Handle both old and new formats
    final nameValue = json['name'];
    final chaptersValue = json['chapters'];

    if (nameValue == null) {
      throw FormatException('BibleBook name is null in JSON: $json');
    }
    if (chaptersValue == null) {
      throw FormatException('BibleBook chapters is null in JSON: $json');
    }

    final bookName = nameValue.toString();

    // Try to get metadata from mapping, or generate defaults
    final metadata = BibleBookMapping.getByName(bookName);

    String bookId;
    String abbreviation;
    int order;
    bool isOldTestament;

    if (metadata != null) {
      bookId = metadata.id;
      abbreviation = metadata.abbreviation;
      order = metadata.order;
      isOldTestament = metadata.isOldTestament;
    } else {
      // Generate defaults for unknown books
      try {
        bookId =
            json['id']?.toString() ?? BibleBookMapping.generateId(bookName);
      } catch (e) {
        throw FormatException('Error generating ID for book "$bookName": $e');
      }
      abbreviation = json['abbreviation']?.toString() ?? bookName;
      order = json['order'] as int? ?? 999; // Put unknown books at the end
      isOldTestament = json['isOldTestament'] as bool? ?? true; // Default to OT
    }

    try {
      return BibleBook(
        id: bookId,
        name: bookName,
        abbreviation: abbreviation,
        order: order,
        isOldTestament: isOldTestament,
        chapters: (chaptersValue as List<dynamic>).map((chapter) {
          try {
            return BibleChapter.fromJson(chapter as Map<String, dynamic>);
          } catch (e) {
            throw FormatException(
                'Error parsing chapter in book $bookName: $e');
          }
        }).toList(),
      );
    } catch (e) {
      throw FormatException(
          'Error parsing BibleBook "$bookName": $e, JSON keys: ${json.keys.toList()}');
    }
  }

  /// Convert to JSON representation
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'abbreviation': abbreviation,
      'order': order,
      'isOldTestament': isOldTestament,
      'chapters': chapters.map((chapter) => chapter.toJson()).toList(),
    };
  }

  /// Get chapter by number
  BibleChapter? getChapter(int chapterNumber) {
    try {
      return chapters.firstWhere((chapter) => chapter.number == chapterNumber);
    } catch (e) {
      return null;
    }
  }

  /// Get all chapter numbers in this book
  List<int> get chapterNumbers => chapters.map((c) => c.number).toList();

  /// Get the maximum chapter number in this book
  int get maxChapterNumber => chapters.isEmpty
      ? 0
      : chapters.map((c) => c.number).reduce((a, b) => a > b ? a : b);

  /// Check if a chapter number exists in this book
  bool hasChapter(int chapterNumber) =>
      chapters.any((c) => c.number == chapterNumber);

  /// Get verse count for a specific chapter
  int getChapterVerseCount(int chapterNumber) {
    final chapter = getChapter(chapterNumber);
    return chapter?.verses.length ?? 0;
  }

  /// Get total verse count in this book
  int get totalVerseCount =>
      chapters.fold(0, (sum, chapter) => sum + chapter.verses.length);

  /// Get a verse by chapter and verse number
  String? getVerseText(int chapterNumber, int verseNumber) {
    final chapter = getChapter(chapterNumber);
    return chapter?.getVerseText(verseNumber);
  }

  /// Search for text within this book
  List<String> searchText(String query) {
    final results = <String>[];
    final lowerQuery = query.toLowerCase();

    for (final chapter in chapters) {
      for (final verse in chapter.verses) {
        if (verse.text.toLowerCase().contains(lowerQuery)) {
          results
              .add('${name} ${chapter.number}:${verse.number} - ${verse.text}');
        }
      }
    }

    return results;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BibleBook &&
        other.id == id &&
        other.name == name &&
        other.abbreviation == abbreviation &&
        other.order == order &&
        other.isOldTestament == isOldTestament &&
        _listEquals(other.chapters, chapters);
  }

  @override
  int get hashCode => Object.hash(
      id, name, abbreviation, order, isOldTestament, Object.hashAll(chapters));

  @override
  String toString() =>
      'BibleBook(id: $id, name: $name, chapterCount: ${chapters.length})';

  /// Create a copy with modified values
  BibleBook copyWith({
    String? id,
    String? name,
    String? abbreviation,
    int? order,
    bool? isOldTestament,
    List<BibleChapter>? chapters,
  }) {
    return BibleBook(
      id: id ?? this.id,
      name: name ?? this.name,
      abbreviation: abbreviation ?? this.abbreviation,
      order: order ?? this.order,
      isOldTestament: isOldTestament ?? this.isOldTestament,
      chapters: chapters ?? this.chapters,
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
