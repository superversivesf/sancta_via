import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as path;

import '../models/bible.dart';
import '../models/bible_translation.dart';
import '../models/bible_book.dart';
import '../models/bible_chapter.dart';
import '../models/bible_verse.dart';
import 'bible_loader.dart';
import 'database_asset_cache.dart';
import '../utils/book_mapping.dart';
import '../utils/logger.dart';
import '../utils/async_lock.dart';

/// High-performance Bible loader using SQLite database
///
/// Provides lightning-fast Bible loading and translation switching
/// by using a pre-built SQLite database instead of parsing JSON files.
class SqliteBibleLoader implements BibleLoader {
  static Database? _database;
  static final Map<BibleTranslation, Bible> _cache = {};
  static final AsyncLock _cacheLock = AsyncLock();
  static final AsyncLock _dbLock = AsyncLock();

  final String databaseAssetPath;
  final DatabaseAssetCache _assetCache;

  /// Create SQLite loader
  ///
  /// [databaseAssetPath] - Path to the SQLite database in assets (e.g., 'assets/bibles.db')
  ///
  /// [assetLoader] overrides how the bundled database asset's bytes are
  /// loaded; production uses rootBundle.
  SqliteBibleLoader({
    this.databaseAssetPath = 'assets/bibles.db',
    AssetBytesLoader? assetLoader,
  }) : _assetCache = DatabaseAssetCache(
         databaseAssetPath: databaseAssetPath,
         assetLoader: assetLoader,
       );

  /// Initialize the database connection (thread-safe)
  Future<Database> _getDatabase() async {
    if (_database != null) {
      return _database!;
    }

    return _dbLock.synchronized(() async {
      // Double-check after acquiring lock
      if (_database != null) {
        return _database!;
      }

      try {
        // Get the application documents directory
        final documentsPath = await getDatabasesPath();
        final dbPath = path.join(documentsPath, 'bibles.db');

        // Make sure the on-device copy matches the bundled asset: the loader
        // re-copies (overwrites) the database when the stamp of the shipped
        // asset differs from the stored stamp, so devices that ran a prior
        // build cannot keep serving an outdated database.
        await _assetCache.ensureFresh(dbPath: dbPath, tag: 'SQLITE_LOADER');

        // Open database without read-only restriction
        // SQLite needs to write some metadata even for read operations
        _database = await openDatabase(
          dbPath,
          version: 1,
          // Don't set readOnly: true - SQLite needs to write metadata
          onCreate: (db, version) {
            // Database already exists and is populated, no need to create
            AppLogger.loader(
              'Database opened (onCreate called but ignored)',
              'SQLITE_LOADER',
            );
          },
          onOpen: (db) {
            AppLogger.loader('Database opened successfully', 'SQLITE_LOADER');
          },
        );

        return _database!;
      } catch (e) {
        AppLogger.loader('Error initializing database: $e', 'SQLITE_LOADER');

        // If there's a permission error, try to delete and recreate
        if (e.toString().contains('readonly') ||
            e.toString().contains('permission')) {
          AppLogger.loader(
            'Attempting to recreate database due to permission error...',
            'SQLITE_LOADER',
          );
          try {
            final documentsPath = await getDatabasesPath();
            final dbPath = path.join(documentsPath, 'bibles.db');
            final dbFile = File(dbPath);

            if (await dbFile.exists()) {
              await dbFile.delete();
              AppLogger.loader(
                'Deleted corrupted database file',
                'SQLITE_LOADER',
              );
            }

            // Reset static variable to force recreation
            _database = null;

            // Release lock and retry
          } catch (retryError) {
            AppLogger.loader('Retry failed: $retryError', 'SQLITE_LOADER');
            rethrow;
          }
        }

        rethrow;
      }
    });
  }

  @override
  Future<Bible> loadBible(BibleTranslation translation) async {
    AppLogger.loader(
      'Loading Bible: ${translation.name} (${translation.id})',
      'SQLITE_LOADER',
    );

    // Check cache first with synchronization for thread safety
    return _cacheLock.synchronized(() async {
      if (_cache.containsKey(translation)) {
        AppLogger.loader('Found ${translation.name} in cache', 'SQLITE_LOADER');
        return _cache[translation]!;
      }

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
      AppLogger.loader(
        'Loaded translation metadata: ${metadata['name']}',
        'SQLITE_LOADER',
      );

      // Load all books for this translation
      final books = await _loadBooks(db, translation);
      AppLogger.loader(
        'Loaded ${books.length} books for ${translation.name}',
        'SQLITE_LOADER',
      );

      // Create Bible object
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

      // Cache the loaded bible
      _cache[translation] = bible;
      AppLogger.loader('Bible cached for ${translation.name}', 'SQLITE_LOADER');

      return bible;
    });
  }

  /// Load all books for a translation with optimized loading
  Future<List<BibleBook>> _loadBooks(
    Database db,
    BibleTranslation translation,
  ) async {
    // Get book metadata
    final bookData = await db.query(
      'books',
      where: 'translation_id = ?',
      whereArgs: [translation.id],
      orderBy: 'book_order',
    );

    final books = <BibleBook>[];

    for (final bookMeta in bookData) {
      final bookName = bookMeta['book_name'] as String;
      final bookOrder = bookMeta['book_order'] as int;

      // Load all chapters for this book efficiently
      final chapters = await _loadAllChapters(db, translation, bookName);

      // Create book with the loaded chapters
      final book = BibleBook(
        id: _generateBookId(bookName),
        name: bookName,
        abbreviation: _generateAbbreviation(bookName),
        order: bookOrder,
        isOldTestament: BibleBookMapping.isOldTestamentByOrder(bookOrder),
        chapters: chapters,
      );

      books.add(book);
    }

    return books;
  }

  /// Load all chapters for a book in one efficient query
  Future<List<BibleChapter>> _loadAllChapters(
    Database db,
    BibleTranslation translation,
    String bookName,
  ) async {
    AppLogger.loader(
      'Loading all chapters for: $bookName from ${translation.id}',
      'SQLITE_LOADER',
    );

    try {
      // Load all verses for this book in one query, ordered by chapter and verse
      final versesData = await db.query(
        'verses',
        where: 'translation_id = ? AND book_name = ?',
        whereArgs: [translation.id, bookName],
        orderBy: 'chapter_number, verse_number',
      );

      if (versesData.isEmpty) {
        AppLogger.loader('No verses found for $bookName', 'SQLITE_LOADER');
        return [];
      }

      // Group verses by chapter
      final chapterMap = <int, List<BibleVerse>>{};

      for (final verseData in versesData) {
        final chapterNumber = verseData['chapter_number'] as int;
        final verse = BibleVerse(
          number: verseData['verse_number'] as int,
          text: verseData['text'] as String,
        );

        chapterMap.putIfAbsent(chapterNumber, () => []).add(verse);
      }

      // Convert to BibleChapter objects
      final chapters = <BibleChapter>[];
      for (final chapterNumber in chapterMap.keys.toList()..sort()) {
        final verses = chapterMap[chapterNumber]!;

        final chapter = BibleChapter(number: chapterNumber, verses: verses);

        chapters.add(chapter);
      }

      AppLogger.loader(
        'Loaded ${chapters.length} chapters for $bookName (${versesData.length} total verses)',
        'SQLITE_LOADER',
      );
      return chapters;
    } catch (e) {
      AppLogger.loader(
        'Error loading chapters for $bookName: $e',
        'SQLITE_LOADER',
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

    // For multi-word books, use first letters
    final words = bookName.split(' ');
    if (words.length > 1) {
      return words.map((w) => w.isNotEmpty ? w[0] : '').join('');
    }

    // For single word, use first 3-4 characters
    return bookName.substring(0, bookName.length < 4 ? bookName.length : 4);
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

      final available = result.isNotEmpty;
      AppLogger.loader(
        'Translation ${translation.id} availability: $available',
        'SQLITE_LOADER',
      );
      return available;
    } catch (e) {
      AppLogger.loader(
        'Error checking availability for ${translation.id}: $e',
        'SQLITE_LOADER',
      );
      return false;
    }
  }

  @override
  Future<List<BibleTranslation>> getAvailableTranslations() async {
    AppLogger.loader(
      'Getting available translations from database...',
      'SQLITE_LOADER',
    );

    try {
      final db = await _getDatabase();
      final translations = await db.query('translations', orderBy: 'name');

      final available = <BibleTranslation>[];

      for (final translationData in translations) {
        final id = translationData['id'] as String;

        // Find matching BibleTranslation enum value
        try {
          final translation = BibleTranslation.fromId(id);
          available.add(translation);
          AppLogger.loader(
            '✓ Found translation: ${translation.name}',
            'SQLITE_LOADER',
          );
        } catch (e) {
          AppLogger.loader(
            '✗ Unknown translation ID in database: $id',
            'SQLITE_LOADER',
          );
        }
      }

      AppLogger.loader(
        'Total available translations: ${available.length}',
        'SQLITE_LOADER',
      );
      return available;
    } catch (e) {
      AppLogger.loader(
        'Error getting available translations: $e',
        'SQLITE_LOADER',
      );
      return [];
    }
  }

  /// Clear all caches
  static void clearCache() {
    _cache.clear();
  }

  /// Close database connection (thread-safe)
  static Future<void> close() async {
    await _dbLock.synchronized(() async {
      if (_database != null) {
        await _database!.close();
        _database = null;
      }
    });
  }

  /// Reset database (delete local copy to force recreation)
  static Future<void> resetDatabase() async {
    try {
      // Close existing connection
      await close();

      // Delete the local database file
      final documentsPath = await getDatabasesPath();
      final dbPath = path.join(documentsPath, 'bibles.db');
      final dbFile = File(dbPath);

      if (await dbFile.exists()) {
        await dbFile.delete();
        AppLogger.loader('✅ Database reset successfully');
      }

      // Clear cache
      clearCache();
    } catch (e) {
      AppLogger.error('Error resetting database', e, null, 'SQLITE_LOADER');
    }
  }

  /// Get cache statistics
  static Map<String, int> getCacheStats() {
    return {
      'loaded_bibles': _cache.length,
      'database_open': _database != null ? 1 : 0,
    };
  }
}
