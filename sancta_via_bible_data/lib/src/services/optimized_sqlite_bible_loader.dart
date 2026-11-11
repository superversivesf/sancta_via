import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as path;
import 'package:flutter/services.dart' show rootBundle;

import '../models/bible.dart';
import '../models/bible_translation.dart';
import '../models/bible_book.dart';
import '../models/bible_chapter.dart';
import '../models/bible_verse.dart';
import '../utils/book_name_normalizer.dart';
import '../utils/book_mapping.dart';
import '../utils/logger.dart';
import 'bible_loader.dart';

/// Cached chapter data for fast access
class CachedChapter {
  final BibleChapter chapter;
  final DateTime accessTime;

  CachedChapter(this.chapter) : accessTime = DateTime.now();
}

/// Optimized Bible loader that queries chapters on-demand instead of loading entire Bibles
///
/// This provides much faster app startup times by:
/// - Keeping SQLite database persistent between app restarts
/// - Loading individual chapters on demand
/// - Caching recently accessed chapters in memory
/// - Avoiding loading entire Bibles into memory
class OptimizedSqliteBibleLoader implements BibleLoader {
  static Database? _database;
  static final Map<String, CachedChapter> _chapterCache = {};
  static const int _maxCacheSize = 50; // Keep last 50 accessed chapters

  final String databaseAssetPath;

  /// Create optimized SQLite loader
  OptimizedSqliteBibleLoader({this.databaseAssetPath = 'assets/bibles.db'});

  /// Initialize the database connection (same as before - this works well)
  Future<Database> _getDatabase() async {
    if (_database != null) {
      return _database!;
    }

    try {
      final documentsPath = await getDatabasesPath();
      final dbPath = path.join(documentsPath, 'bibles.db');

      final dbFile = File(dbPath);
      final dbExists = await dbFile.exists();

      if (!dbExists) {
        AppLogger.loader(
          'Copying database from assets to $dbPath',
          'OPTIMIZED_LOADER',
        );
        final data = await rootBundle.load(databaseAssetPath);
        final bytes = data.buffer.asUint8List(
          data.offsetInBytes,
          data.lengthInBytes,
        );

        await dbFile.parent.create(recursive: true);
        await dbFile.writeAsBytes(bytes, flush: true);

        if (Platform.isIOS ||
            Platform.isAndroid ||
            Platform.isMacOS ||
            Platform.isLinux) {
          try {
            await Process.run('chmod', ['644', dbPath]);
          } catch (e) {
            AppLogger.loader(
              'Warning: Could not set file permissions: $e',
              'OPTIMIZED_LOADER',
            );
          }
        }

        AppLogger.loader('Database copied successfully', 'OPTIMIZED_LOADER');
      } else {
        AppLogger.loader(
          'Using existing database at $dbPath',
          'OPTIMIZED_LOADER',
        );
      }

      _database = await openDatabase(
        dbPath,
        version: 1,
        onOpen: (db) {
          AppLogger.loader(
            'Database opened successfully (optimized loader)',
            'OPTIMIZED_LOADER',
          );
        },
      );

      return _database!;
    } catch (e) {
      AppLogger.loader('Error initializing database: $e', 'OPTIMIZED_LOADER');
      rethrow;
    }
  }

  /// Get a specific chapter directly from database (fast!)
  Future<BibleChapter?> getChapter(
    BibleTranslation translation,
    String bookName,
    int chapterNumber,
  ) async {
    // Convert book name to database format (Roman numerals)
    final dbBookName = BookNameNormalizer.toDatabaseFormat(bookName);
    final cacheKey = '${translation.id}:$bookName:$chapterNumber';

    // Check memory cache first
    if (_chapterCache.containsKey(cacheKey)) {
      AppLogger.loader('Found chapter in cache: $cacheKey', 'OPTIMIZED_LOADER');
      final cached = _chapterCache[cacheKey]!;
      // Update access time
      _chapterCache[cacheKey] = CachedChapter(cached.chapter);
      return cached.chapter;
    }

    try {
      AppLogger.loader(
        'Loading chapter from database: $cacheKey (db format: $dbBookName)',
        'OPTIMIZED_LOADER',
      );
      final db = await _getDatabase();

      // Load verses for this specific chapter using database book name format
      final versesData = await db.query(
        'verses',
        where: 'translation_id = ? AND book_name = ? AND chapter_number = ?',
        whereArgs: [translation.id, dbBookName, chapterNumber],
        orderBy: 'verse_number',
      );

      if (versesData.isEmpty) {
        AppLogger.loader('No verses found for $cacheKey', 'OPTIMIZED_LOADER');
        return null;
      }

      // Create verses
      final verses = versesData
          .map(
            (verseData) => BibleVerse(
              number: verseData['verse_number'] as int,
              text: verseData['text'] as String,
            ),
          )
          .toList();

      // Create chapter
      final chapter = BibleChapter(number: chapterNumber, verses: verses);

      // Cache the chapter
      _cacheChapter(cacheKey, chapter);

      AppLogger.loader(
        'Loaded chapter $cacheKey with ${verses.length} verses',
        'OPTIMIZED_LOADER',
      );
      return chapter;
    } catch (e) {
      AppLogger.loader(
        'Error loading chapter $cacheKey: $e',
        'OPTIMIZED_LOADER',
      );
      return null;
    }
  }

  /// Get book metadata (book names, chapter counts) without loading full content
  Future<List<String>> getBookNames(BibleTranslation translation) async {
    try {
      final db = await _getDatabase();

      final booksData = await db.query(
        'books',
        columns: ['book_name'],
        where: 'translation_id = ?',
        whereArgs: [translation.id],
        orderBy: 'book_order',
      );

      // Convert book names from database format (Roman) to display format (Arabic)
      return booksData.map((row) {
        final dbBookName = row['book_name'] as String;
        return BookNameNormalizer.toDisplayFormat(dbBookName);
      }).toList();
    } catch (e) {
      AppLogger.loader(
        'Error getting book names for ${translation.id}: $e',
        'OPTIMIZED_LOADER',
      );
      return [];
    }
  }

  /// Get chapter count for a specific book
  Future<int> getChapterCount(
    BibleTranslation translation,
    String bookName,
  ) async {
    try {
      // Convert book name to database format (Roman numerals)
      final dbBookName = BookNameNormalizer.toDatabaseFormat(bookName);
      final db = await _getDatabase();

      AppLogger.loader(
        'Getting chapter count for: $bookName (db format: $dbBookName)',
        'OPTIMIZED_LOADER',
      );

      final result = await db.rawQuery(
        'SELECT MAX(chapter_number) as max_chapter FROM verses WHERE translation_id = ? AND book_name = ?',
        [translation.id, dbBookName],
      );

      final chapterCount = result.isNotEmpty
          ? (result.first['max_chapter'] as int?) ?? 0
          : 0;
      AppLogger.loader(
        'Chapter count for $bookName: $chapterCount',
        'OPTIMIZED_LOADER',
      );
      return chapterCount;
    } catch (e) {
      AppLogger.loader(
        'Error getting chapter count for $bookName: $e',
        'OPTIMIZED_LOADER',
      );
      return 0;
    }
  }

  /// Cache chapter with LRU eviction
  void _cacheChapter(String cacheKey, BibleChapter chapter) {
    _chapterCache[cacheKey] = CachedChapter(chapter);

    // Evict oldest entries if cache is too large
    if (_chapterCache.length > _maxCacheSize) {
      final sortedEntries = _chapterCache.entries.toList()
        ..sort((a, b) => a.value.accessTime.compareTo(b.value.accessTime));

      // Remove oldest 25% of entries
      final toRemove = (sortedEntries.length * 0.25).round();
      for (int i = 0; i < toRemove; i++) {
        _chapterCache.remove(sortedEntries[i].key);
      }

      AppLogger.loader(
        'Evicted $toRemove old chapters from cache',
        'OPTIMIZED_LOADER',
      );
    }
  }

  @override
  Future<Bible> loadBible(BibleTranslation translation) async {
    // For compatibility with the existing interface, create a minimal Bible object
    // that doesn't preload all content
    AppLogger.loader(
      'Creating minimal Bible object for ${translation.name}',
      'OPTIMIZED_LOADER',
    );

    try {
      final db = await _getDatabase();

      // Load translation metadata
      final translationData = await db.query(
        'translations',
        where: 'id = ?',
        whereArgs: [translation.id],
        limit: 1,
      );

      if (translationData.isEmpty) {
        throw Exception('Translation ${translation.id} not found in database');
      }

      final metadata = translationData.first;

      // Get book names (fast - no content loading)
      final bookNames = await getBookNames(translation);

      // Create minimal book objects without preloading chapters
      final books = <BibleBook>[];

      for (int i = 0; i < bookNames.length; i++) {
        final bookName = bookNames[i];
        final book = BibleBook(
          id: _generateBookId(bookName),
          name: bookName,
          abbreviation: _generateAbbreviation(bookName),
          order: i + 1,
          isOldTestament: BibleBookMapping.isOldTestamentByIndex(i),
          chapters: [], // Empty - will be loaded on demand
        );
        books.add(book);
      }

      final bible = Bible(
        translation: translation,
        books: books,
        metadata: {
          'name': metadata['name'] as String,
          'abbreviation': metadata['abbreviation'] as String,
          'language': metadata['language'] as String? ?? 'en',
          'book_count': metadata['book_count'] as int? ?? books.length,
          'verse_count': metadata['verse_count'] as int? ?? 0,
        },
      );

      AppLogger.loader(
        'Created minimal Bible for ${translation.name} with ${books.length} books (no chapters preloaded)',
        'OPTIMIZED_LOADER',
      );
      return bible;
    } catch (e) {
      AppLogger.loader(
        'Error creating minimal Bible for ${translation.name}: $e',
        'OPTIMIZED_LOADER',
      );
      rethrow;
    }
  }

  @override
  Future<bool> isTranslationAvailable(BibleTranslation translation) async {
    try {
      final db = await _getDatabase();
      final result = await db.query(
        'translations',
        where: 'id = ?',
        whereArgs: [translation.id],
        limit: 1,
      );

      return result.isNotEmpty;
    } catch (e) {
      AppLogger.loader(
        'Error checking availability for ${translation.id}: $e',
        'OPTIMIZED_LOADER',
      );
      return false;
    }
  }

  @override
  Future<List<BibleTranslation>> getAvailableTranslations() async {
    AppLogger.loader(
      'Getting available translations (optimized - fast)',
      'OPTIMIZED_LOADER',
    );

    try {
      final db = await _getDatabase();
      final translations = await db.query('translations', orderBy: 'name');

      final available = <BibleTranslation>[];

      for (final translationData in translations) {
        final id = translationData['id'] as String;

        try {
          final translation = BibleTranslation.fromId(id);
          available.add(translation);
        } catch (e) {
          AppLogger.loader(
            'Unknown translation ID in database: $id',
            'OPTIMIZED_LOADER',
          );
        }
      }

      AppLogger.loader(
        'Available translations (fast): ${available.map((t) => t.id).join(', ')}',
        'OPTIMIZED_LOADER',
      );
      return available;
    } catch (e) {
      AppLogger.loader(
        'Error getting available translations: $e',
        'OPTIMIZED_LOADER',
      );
      return [];
    }
  }

  /// Generate book ID from name (simplified)
  String _generateBookId(String bookName) {
    final cleaned = bookName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    return cleaned.length < 3 ? cleaned : cleaned.substring(0, 3);
  }

  /// Generate abbreviation from name (simplified)
  String _generateAbbreviation(String bookName) {
    if (bookName.length <= 4) return bookName;

    final words = bookName.split(' ');
    if (words.length > 1) {
      return words.map((w) => w.isNotEmpty ? w[0] : '').join('');
    }

    return bookName.substring(0, bookName.length < 4 ? bookName.length : 4);
  }

  /// Clear chapter cache
  static void clearCache() {
    _chapterCache.clear();
    AppLogger.loader('Chapter cache cleared', 'OPTIMIZED_LOADER');
  }

  /// Get cache statistics
  static Map<String, int> getCacheStats() {
    return {
      'cached_chapters': _chapterCache.length,
      'database_open': _database != null ? 1 : 0,
    };
  }

  /// Close database connection
  static Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }

  /// Check if book exists
  Future<bool> hasBook(String bookName, BibleTranslation translation) async {
    try {
      // Convert book name to database format for direct database query (faster)
      final dbBookName = BookNameNormalizer.toDatabaseFormat(bookName);
      final db = await _getDatabase();

      final result = await db.query(
        'books',
        columns: ['book_name'],
        where: 'translation_id = ? AND book_name = ?',
        whereArgs: [translation.id, dbBookName],
        limit: 1,
      );

      final exists = result.isNotEmpty;
      AppLogger.loader(
        'Book exists check for $bookName (db: $dbBookName): $exists',
        'OPTIMIZED_LOADER',
      );
      return exists;
    } catch (e) {
      AppLogger.loader(
        'Error checking if book exists $bookName: $e',
        'OPTIMIZED_LOADER',
      );
      return false;
    }
  }
}
