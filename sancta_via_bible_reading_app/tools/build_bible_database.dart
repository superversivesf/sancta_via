#!/usr/bin/env dart

import 'dart:convert';
import 'dart:io';
// import 'package:archive/archive.dart'; // Development tool only - not shipped with app
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Build script to convert Bible JSON files to SQLite database
///
/// Usage: dart tools/build_bible_database.dart
///
/// This script:
/// 1. Reads JSON files from assets/bibles/
/// 2. Creates a SQLite database at assets/bibles.db
/// 3. Optimizes for fast chapter lookups and translation switching

void main() async {
  print('🏗️  Building Bible SQLite database...');

  // Initialize SQLite for desktop/CLI usage
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  // Define paths
  final assetsDir = Directory('assets/bibles');
  final dbPath = 'assets/bibles.db';

  // Clean up old database
  final dbFile = File(dbPath);
  if (dbFile.existsSync()) {
    await dbFile.delete();
    print('🗑️  Removed existing database');
  }

  // Create database
  final database = await openDatabase(dbPath);
  print('📄 Created database at $dbPath');

  try {
    await _createSchema(database);
    print('📊 Created database schema');

    await _convertJsonFiles(assetsDir, database);
    print('✅ Conversion completed successfully!');

    await _createIndexes(database);
    print('⚡ Created performance indexes');

    await _printStatistics(database);
  } finally {
    await database.close();
  }

  // Show final file size
  final dbStats = await dbFile.stat();
  final dbSizeMB = (dbStats.size / (1024 * 1024)).toStringAsFixed(1);
  print('💾 Final database size: ${dbSizeMB}MB');
  print('🎉 Bible database build complete!');
}

/// Create the database schema optimized for Bible lookups
Future<void> _createSchema(Database db) async {
  // Translations table
  await db.execute('''
    CREATE TABLE translations (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      abbreviation TEXT NOT NULL,
      language TEXT DEFAULT 'en',
      book_count INTEGER DEFAULT 0,
      verse_count INTEGER DEFAULT 0,
      metadata TEXT,
      created_at TEXT DEFAULT CURRENT_TIMESTAMP
    )
  ''');

  // Optimized verses table (denormalized for performance)
  await db.execute('''
    CREATE TABLE verses (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      translation_id TEXT NOT NULL,
      book_name TEXT NOT NULL,
      book_order INTEGER NOT NULL,
      chapter_number INTEGER NOT NULL,
      verse_number INTEGER NOT NULL,
      text TEXT NOT NULL,
      FOREIGN KEY (translation_id) REFERENCES translations(id),
      UNIQUE(translation_id, book_name, chapter_number, verse_number)
    )
  ''');

  // Books summary table for quick metadata lookups
  await db.execute('''
    CREATE TABLE books (
      translation_id TEXT NOT NULL,
      book_name TEXT NOT NULL,
      book_order INTEGER NOT NULL,
      chapter_count INTEGER NOT NULL,
      verse_count INTEGER NOT NULL,
      PRIMARY KEY (translation_id, book_name),
      FOREIGN KEY (translation_id) REFERENCES translations(id)
    )
  ''');
}

/// Create indexes for optimal query performance
Future<void> _createIndexes(Database db) async {
  // Primary lookup index: translation + book + chapter
  await db.execute('''
    CREATE INDEX idx_verses_lookup 
    ON verses(translation_id, book_name, chapter_number)
  ''');

  // Verse-specific lookups
  await db.execute('''
    CREATE INDEX idx_verses_specific 
    ON verses(translation_id, book_name, chapter_number, verse_number)
  ''');

  // Book order for navigation
  await db.execute('''
    CREATE INDEX idx_verses_book_order 
    ON verses(translation_id, book_order, chapter_number)
  ''');

  // Full-text search preparation (for future search features)
  await db.execute('''
    CREATE INDEX idx_verses_text 
    ON verses(translation_id, text)
  ''');
}

/// Convert JSON files to database records
Future<void> _convertJsonFiles(Directory assetsDir, Database db) async {
  final jsonFiles = await assetsDir
      .list()
      .where(
        (entity) =>
            entity is File &&
            (entity.path.endsWith('.json') || entity.path.endsWith('.json.gz')),
      )
      .cast<File>()
      .toList();

  if (jsonFiles.isEmpty) {
    throw Exception('No JSON files found in ${assetsDir.path}');
  }

  print('📖 Found ${jsonFiles.length} Bible translation files');

  for (final file in jsonFiles) {
    final translationId = _getTranslationId(file.path);
    print('🔄 Processing $translationId...');

    // Handle both .json and .json.gz files
    String jsonContent;
    if (file.path.endsWith('.gz')) {
      // Compression support disabled - development tool limitation
      throw Exception(
        'Compressed files not supported in this build tool. Use uncompressed .json files.',
      );
    } else {
      jsonContent = await file.readAsString();
    }

    final bibleData = json.decode(jsonContent) as Map<String, dynamic>;

    await _insertTranslation(db, translationId, bibleData);
    await _insertBooks(db, translationId, bibleData);
    await _insertVerses(db, translationId, bibleData);

    print('✅ Processed $translationId');
  }
}

/// Extract translation ID from file path
String _getTranslationId(String filePath) {
  return filePath
      .split('/')
      .last
      .replaceAll('.json.gz', '')
      .replaceAll('.json', '');
}

/// Insert translation metadata
Future<void> _insertTranslation(
  Database db,
  String translationId,
  Map<String, dynamic> bibleData,
) async {
  final metadata = bibleData['metadata'] as Map<String, dynamic>?;

  await db.insert('translations', {
    'id': translationId,
    'name': bibleData['translation'] ?? translationId.toUpperCase(),
    'abbreviation': metadata?['abbreviation'] ?? translationId.toUpperCase(),
    'language': 'en', // All current translations are English
    'book_count': metadata?['books'] ?? 0,
    'verse_count': metadata?['verses'] ?? 0,
    'metadata': json.encode(metadata ?? {}),
  });
}

/// Insert book metadata for quick lookups
Future<void> _insertBooks(
  Database db,
  String translationId,
  Map<String, dynamic> bibleData,
) async {
  final books = bibleData['books'] as List<dynamic>;

  for (int bookIndex = 0; bookIndex < books.length; bookIndex++) {
    final book = books[bookIndex] as Map<String, dynamic>;
    final bookName = book['name'] as String;
    final chapters = book['chapters'] as List<dynamic>;

    // Count total verses in this book
    int totalVerses = 0;
    for (final chapter in chapters) {
      final verses =
          (chapter as Map<String, dynamic>)['verses'] as List<dynamic>;
      totalVerses += verses.length;
    }

    await db.insert('books', {
      'translation_id': translationId,
      'book_name': bookName,
      'book_order': bookIndex + 1,
      'chapter_count': chapters.length,
      'verse_count': totalVerses,
    });
  }
}

/// Insert all verses with optimized structure
Future<void> _insertVerses(
  Database db,
  String translationId,
  Map<String, dynamic> bibleData,
) async {
  final books = bibleData['books'] as List<dynamic>;

  // Use batch insert for performance
  final batch = db.batch();
  int batchCount = 0;

  for (int bookIndex = 0; bookIndex < books.length; bookIndex++) {
    final book = books[bookIndex] as Map<String, dynamic>;
    final bookName = book['name'] as String;
    final chapters = book['chapters'] as List<dynamic>;

    for (final chapter in chapters) {
      final chapterData = chapter as Map<String, dynamic>;
      final chapterNumber = chapterData['chapter'] as int;
      final verses = chapterData['verses'] as List<dynamic>;

      for (final verse in verses) {
        final verseData = verse as Map<String, dynamic>;
        final verseNumber = verseData['verse'] as int;
        final text = (verseData['text'] as String).trim();

        batch.insert('verses', {
          'translation_id': translationId,
          'book_name': bookName,
          'book_order': bookIndex + 1,
          'chapter_number': chapterNumber,
          'verse_number': verseNumber,
          'text': text,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);

        batchCount++;

        // Commit batch every 1000 verses for memory efficiency
        if (batchCount % 1000 == 0) {
          await batch.commit(noResult: true);
          print('  📝 Inserted $batchCount verses...');
        }
      }
    }
  }

  // Commit any remaining verses
  if (batchCount % 1000 != 0) {
    await batch.commit(noResult: true);
  }

  print('  ✅ Inserted $batchCount total verses for $translationId');
}

/// Print database statistics
Future<void> _printStatistics(Database db) async {
  print('\n📊 Database Statistics:');

  // Translation count
  final translationResult = await db.rawQuery(
    'SELECT COUNT(*) as count FROM translations',
  );
  final translationCount = translationResult.first['count'] as int;
  print('   📖 Translations: $translationCount');

  // Total verses
  final verseResult = await db.rawQuery('SELECT COUNT(*) as count FROM verses');
  final verseCount = verseResult.first['count'] as int;
  print('   📝 Total verses: $verseCount');

  // Verses per translation
  final versesByTranslation = await db.rawQuery('''
    SELECT translation_id, COUNT(*) as verse_count 
    FROM verses 
    GROUP BY translation_id 
    ORDER BY translation_id
  ''');

  for (final row in versesByTranslation) {
    print('   • ${row['translation_id']}: ${row['verse_count']} verses');
  }

  // Book count
  final bookResult = await db.rawQuery(
    'SELECT COUNT(DISTINCT book_name) as count FROM books WHERE translation_id = ?',
    [versesByTranslation.first['translation_id']],
  );
  final bookCount = bookResult.first['count'] as int;
  print('   📚 Books per translation: $bookCount');
}
