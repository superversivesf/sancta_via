import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as path;
import 'package:flutter/services.dart' show rootBundle;

import '../models/bible.dart';
import '../models/bible_translation.dart';
import '../models/bible_book.dart';
import '../models/bible_chapter.dart';
import '../models/bible_verse.dart';
import 'bible_loader.dart';

/// Debug logging utility
void _debugLog(String message, [String? tag]) {
  final timestamp = DateTime.now().toIso8601String();
  print('[$timestamp] ${tag != null ? '[$tag] ' : ''}$message');
}

/// High-performance Bible loader using SQLite database
///
/// Provides lightning-fast Bible loading and translation switching
/// by using a pre-built SQLite database instead of parsing JSON files.
class SqliteBibleLoader implements BibleLoader {
  static Database? _database;
  static final Map<BibleTranslation, Bible> _cache = {};

  final String databaseAssetPath;

  /// Create SQLite loader
  /// [databaseAssetPath] - Path to the SQLite database in assets (e.g., 'assets/bibles.db')
  SqliteBibleLoader({
    this.databaseAssetPath = 'assets/bibles.db',
  });

  /// Initialize the database connection
  Future<Database> _getDatabase() async {
    if (_database != null) {
      return _database!;
    }

    try {
      // Get the application documents directory
      final documentsPath = await getDatabasesPath();
      final dbPath = path.join(documentsPath, 'bibles.db');

      // Check if database already exists
      final dbFile = File(dbPath);
      final dbExists = await dbFile.exists();

      if (!dbExists) {
        // Copy database from assets
        _debugLog('Copying database from assets to $dbPath', 'SQLITE_LOADER');
        final data = await rootBundle.load(databaseAssetPath);
        final bytes =
            data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);

        // Ensure the directory exists
        await dbFile.parent.create(recursive: true);

        // Write the database file
        await dbFile.writeAsBytes(bytes, flush: true);

        // Set file permissions to be writable (important for SQLite metadata)
        if (Platform.isIOS ||
            Platform.isAndroid ||
            Platform.isMacOS ||
            Platform.isLinux) {
          try {
            // Make file readable and writable by owner
            await Process.run('chmod', ['644', dbPath]);
          } catch (e) {
            _debugLog(
                'Warning: Could not set file permissions: $e', 'SQLITE_LOADER');
            // Continue anyway - might still work
          }
        }

        _debugLog('Database copied successfully', 'SQLITE_LOADER');
      }

      // Open database without read-only restriction
      // SQLite needs to write some metadata even for read operations
      _database = await openDatabase(
        dbPath,
        version: 1,
        // Don't set readOnly: true - SQLite needs to write metadata
        onCreate: (db, version) {
          // Database already exists and is populated, no need to create
          _debugLog(
              'Database opened (onCreate called but ignored)', 'SQLITE_LOADER');
        },
        onOpen: (db) {
          _debugLog('Database opened successfully', 'SQLITE_LOADER');
        },
      );

      return _database!;
    } catch (e) {
      _debugLog('Error initializing database: $e', 'SQLITE_LOADER');

      // If there's a permission error, try to delete and recreate
      if (e.toString().contains('readonly') ||
          e.toString().contains('permission')) {
        _debugLog('Attempting to recreate database due to permission error...',
            'SQLITE_LOADER');
        try {
          final documentsPath = await getDatabasesPath();
          final dbPath = path.join(documentsPath, 'bibles.db');
          final dbFile = File(dbPath);

          if (await dbFile.exists()) {
            await dbFile.delete();
            _debugLog('Deleted corrupted database file', 'SQLITE_LOADER');
          }

          // Reset static variable to force recreation
          _database = null;

          // Try again recursively (but only once)
          return await _getDatabase();
        } catch (retryError) {
          _debugLog('Retry failed: $retryError', 'SQLITE_LOADER');
          rethrow;
        }
      }

      rethrow;
    }
  }

  @override
  Future<Bible> loadBible(BibleTranslation translation) async {
    _debugLog('Loading Bible: ${translation.name} (${translation.id})',
        'SQLITE_LOADER');

    // Check cache first
    if (_cache.containsKey(translation)) {
      _debugLog('Found ${translation.name} in cache', 'SQLITE_LOADER');
      return _cache[translation]!;
    }

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
      _debugLog(
          'Loaded translation metadata: ${metadata['name']}', 'SQLITE_LOADER');

      // Load all books for this translation
      final books = await _loadBooks(db, translation);
      _debugLog('Loaded ${books.length} books for ${translation.name}',
          'SQLITE_LOADER');

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
      _debugLog('Bible cached for ${translation.name}', 'SQLITE_LOADER');

      return bible;
    } catch (e) {
      _debugLog('Error loading ${translation.name}: $e', 'SQLITE_LOADER');
      rethrow;
    }
  }

  /// Load all books for a translation with optimized loading
  Future<List<BibleBook>> _loadBooks(
      Database db, BibleTranslation translation) async {
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
        isOldTestament: bookOrder <= 46, // Standard Catholic Bible OT/NT split
        chapters: chapters,
      );

      books.add(book);
    }

    return books;
  }

  /// Load all chapters for a book in one efficient query
  Future<List<BibleChapter>> _loadAllChapters(
      Database db, BibleTranslation translation, String bookName) async {
    _debugLog('Loading all chapters for: $bookName from ${translation.id}',
        'SQLITE_LOADER');

    try {
      // Load all verses for this book in one query, ordered by chapter and verse
      final versesData = await db.query(
        'verses',
        where: 'translation_id = ? AND book_name = ?',
        whereArgs: [translation.id, bookName],
        orderBy: 'chapter_number, verse_number',
      );

      if (versesData.isEmpty) {
        _debugLog('No verses found for $bookName', 'SQLITE_LOADER');
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

        final chapter = BibleChapter(
          number: chapterNumber,
          verses: verses,
        );

        chapters.add(chapter);
      }

      _debugLog(
          'Loaded ${chapters.length} chapters for $bookName (${versesData.length} total verses)',
          'SQLITE_LOADER');
      return chapters;
    } catch (e) {
      _debugLog('Error loading chapters for $bookName: $e', 'SQLITE_LOADER');
      return [];
    }
  }

  /// Generate book ID from name (simplified)
  String _generateBookId(String bookName) {
    return bookName
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]'), '')
        .substring(0, bookName.length < 3 ? bookName.length : 3);
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
      _debugLog('Translation ${translation.id} availability: $available',
          'SQLITE_LOADER');
      return available;
    } catch (e) {
      _debugLog('Error checking availability for ${translation.id}: $e',
          'SQLITE_LOADER');
      return false;
    }
  }

  @override
  Future<List<BibleTranslation>> getAvailableTranslations() async {
    _debugLog(
        'Getting available translations from database...', 'SQLITE_LOADER');

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
          _debugLog(
              '✓ Found translation: ${translation.name}', 'SQLITE_LOADER');
        } catch (e) {
          _debugLog(
              '✗ Unknown translation ID in database: $id', 'SQLITE_LOADER');
        }
      }

      _debugLog(
          'Total available translations: ${available.length}', 'SQLITE_LOADER');
      return available;
    } catch (e) {
      _debugLog('Error getting available translations: $e', 'SQLITE_LOADER');
      return [];
    }
  }

  /// Clear all caches
  static void clearCache() {
    _cache.clear();
  }

  /// Close database connection
  static Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
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
        print('✅ Database reset successfully');
      }

      // Clear cache
      clearCache();
    } catch (e) {
      print('❌ Error resetting database: $e');
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
