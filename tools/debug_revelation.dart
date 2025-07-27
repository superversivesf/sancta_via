#!/usr/bin/env dart

import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Debug script to investigate the Revelation book issue
void main() async {
  print('🔍 Debugging Revelation book issue...');
  
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  
  final dbPath = 'assets/bibles.db';
  // ignore: avoid_slow_async_io
  if (!await File(dbPath).exists()) {
    print('❌ Database not found at $dbPath');
    print('🔧 You may need to run: dart tools/build_bible_database.dart');
    return;
  }
  
  // Also check source files
  await _checkSourceFiles();
  
  final database = await openDatabase(dbPath);
  
  try {
    await _checkDatabaseContent(database);
    await _checkRevelationInBooks(database);
    await _checkRevelationInVerses(database);
    await _checkLastBooksInOrder(database);
    await _checkRevelationVariations(database);
    
  } finally {
    await database.close();
  }
}

/// Check if source files exist and what type they are
Future<void> _checkSourceFiles() async {
  print('
📁 Checking source Bible files...');
  
  final assetsDir = Directory('assets/bibles');
  if (!await assetsDir.exists()) {
    print('❌ assets/bibles directory not found');
    return;
  }
  
  final files = await assetsDir.list().toList();
  print('Found ${files.length} files in assets/bibles:');
  
  for (final file in files) {
    if (file is File) {
      // ignore: avoid_slow_async_io
      final stats = await file.stat();
      final sizeMB = (stats.size / (1024 * 1024)).toStringAsFixed(1);
      print('  • ${file.path.split('/').last} (${sizeMB}MB)');
    }
  }
}

/// Check basic database content
Future<void> _checkDatabaseContent(Database db) async {
  print('
📊 Checking database content...');
  
  try {
    // Check if tables exist
    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table';"
    );
    print('Tables in database:');
    for (final table in tables) {
      print('  • ${table['name']}');
    }
    
    // Check row counts
    final translationCount = await db.rawQuery('SELECT COUNT(*) as count FROM translations');
    final bookCount = await db.rawQuery('SELECT COUNT(*) as count FROM books');
    final verseCount = await db.rawQuery('SELECT COUNT(*) as count FROM verses');
    
    print('
Row counts:');
    print('  • Translations: ${translationCount.first['count']}');
    print('  • Books: ${bookCount.first['count']}');
    print('  • Verses: ${verseCount.first['count']}');
    
    if (translationCount.first['count'] == 0) {
      print('  ⚠️  No translations found! Database may be empty.');
      print('  🔧 Run: dart tools/build_bible_database.dart');
    }
    
  } catch (e) {
    print('❌ Error checking database content: $e');
  }
}

/// Check what's in the books table for Revelation
Future<void> _checkRevelationInBooks(Database db) async {
  print('\n📚 Checking books table for Revelation...');
  
  // Look for exact match
  final exactMatch = await db.query(
    'books', 
    where: 'book_name = ?', 
    whereArgs: ['Revelation']
  );
  
  if (exactMatch.isNotEmpty) {
    print('✅ Found exact "Revelation" match:');
    for (final book in exactMatch) {
      print('   • Translation: ${book['translation_id']}');
      print('   • Name: "${book['book_name']}"');
      print('   • Order: ${book['book_order']}');
      print('   • Chapters: ${book['chapter_count']}');
      print('   • Verses: ${book['verse_count']}');
    }
  } else {
    print('❌ No exact "Revelation" match found');
  }
  
  // Look for partial matches
  final partialMatches = await db.query(
    'books', 
    where: 'book_name LIKE ?', 
    whereArgs: ['%Revelation%']
  );
  
  if (partialMatches.isNotEmpty) {
    print('\n🔍 Found partial "Revelation" matches:');
    for (final book in partialMatches) {
      print('   • Translation: ${book['translation_id']}');
      print('   • Name: "${book['book_name']}"');
      print('   • Order: ${book['book_order']}');
      print('   • Chapters: ${book['chapter_count']}');
      print('   • Verses: ${book['verse_count']}');
    }
  } else {
    print('❌ No partial "Revelation" matches found');
  }
}

/// Check what's in the verses table for Revelation
Future<void> _checkRevelationInVerses(Database db) async {
  print('\n📝 Checking verses table for Revelation...');
  
  // Look for exact match
  final exactVerses = await db.query(
    'verses', 
    where: 'book_name = ?', 
    whereArgs: ['Revelation'],
    limit: 5
  );
  
  if (exactVerses.isNotEmpty) {
    print('✅ Found verses for exact "Revelation" match:');
    for (final verse in exactVerses) {
      print('   • ${verse['translation_id']} ${verse['book_name']} ${verse['chapter_number']}:${verse['verse_number']}');
    }
    
    // Count total verses
    final countResult = await db.rawQuery(
      'SELECT COUNT(*) as count FROM verses WHERE book_name = ?', 
      ['Revelation']
    );
    final count = countResult.first['count'] as int;
    print('   📊 Total verses: $count');
    
    // Check chapter range
    final chapterRange = await db.rawQuery(
      'SELECT MIN(chapter_number) as min_ch, MAX(chapter_number) as max_ch FROM verses WHERE book_name = ?', 
      ['Revelation']
    );
    final minCh = chapterRange.first['min_ch'] as int?;
    final maxCh = chapterRange.first['max_ch'] as int?;
    print('   📖 Chapter range: $minCh - $maxCh');
    
  } else {
    print('❌ No verses found for exact "Revelation" match');
  }
  
  // Look for partial matches
  final partialVerses = await db.query(
    'verses', 
    where: 'book_name LIKE ?', 
    whereArgs: ['%Revelation%'],
    limit: 5
  );
  
  if (partialVerses.isNotEmpty) {
    print('\n🔍 Found verses for partial "Revelation" matches:');
    for (final verse in partialVerses) {
      print('   • ${verse['translation_id']} "${verse['book_name']}" ${verse['chapter_number']}:${verse['verse_number']}');
    }
  }
}

/// Check the last few books in order to see what comes after
Future<void> _checkLastBooksInOrder(Database db) async {
  print('\n📋 Checking last books in order...');
  
  final lastBooks = await db.query(
    'books', 
    orderBy: 'book_order DESC',
    limit: 10
  );
  
  print('Last 10 books by order:');
  for (final book in lastBooks) {
    print('   • Order ${book['book_order']}: "${book['book_name']}" (${book['chapter_count']} chapters)');
  }
}

/// Check for common variations of Revelation name
Future<void> _checkRevelationVariations(Database db) async {
  print('\n🔍 Checking for Revelation name variations...');
  
  final variations = [
    'Revelation',
    'Revelations', 
    'The Revelation',
    'The Book of Revelation',
    'Apocalypse',
    'Rev'
  ];
  
  for (final variation in variations) {
    final matches = await db.query(
      'books', 
      where: 'book_name LIKE ?', 
      whereArgs: ['%$variation%']
    );
    
    if (matches.isNotEmpty) {
      print('✅ Found matches for "$variation":');
      for (final book in matches) {
        print('   • "${book['book_name']}" (${book['chapter_count']} chapters)');
      }
    } else {
      print('❌ No matches for "$variation"');
    }
  }
}
