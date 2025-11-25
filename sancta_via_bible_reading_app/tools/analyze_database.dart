#!/usr/bin/env dart

import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Analyze and optimize the Bible database
void main() async {
  print('🔍 Analyzing Bible database...');

  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  final dbPath = 'assets/bibles.db';
  // ignore: avoid_slow_async_io
  if (!await File(dbPath).exists()) {
    print('❌ Database not found at $dbPath');
    return;
  }

  final database = await openDatabase(dbPath);

  try {
    await _analyzeDatabase(database);
    await _optimizeDatabase(database);
  } finally {
    await database.close();
  }
}

Future<void> _analyzeDatabase(Database db) async {
  print('\n📊 Database Analysis:');

  // Check table sizes
  final tables = ['translations', 'books', 'verses'];

  for (final table in tables) {
    final countResult = await db.rawQuery(
      'SELECT COUNT(*) as count FROM $table',
    );
    final count = countResult.first['count'] as int;
    print('   📝 $table: $count rows');
  }

  // Check for duplicates in verses
  final duplicateCheck = await db.rawQuery('''
    SELECT translation_id, book_name, chapter_number, verse_number, COUNT(*) as count
    FROM verses 
    GROUP BY translation_id, book_name, chapter_number, verse_number
    HAVING COUNT(*) > 1
    LIMIT 10
  ''');

  if (duplicateCheck.isNotEmpty) {
    print('\n⚠️  Found duplicate verses:');
    for (final row in duplicateCheck) {
      print(
        '   • ${row['translation_id']} ${row['book_name']} ${row['chapter_number']}:${row['verse_number']} (${row['count']} times)',
      );
    }
  } else {
    print('\n✅ No duplicate verses found');
  }

  // Check verse text lengths
  final textStats = await db.rawQuery('''
    SELECT 
      AVG(LENGTH(text)) as avg_length,
      MAX(LENGTH(text)) as max_length,
      MIN(LENGTH(text)) as min_length
    FROM verses
  ''');

  if (textStats.isNotEmpty) {
    final stats = textStats.first;
    print('\n📏 Verse text statistics:');
    print(
      '   • Average length: ${(stats['avg_length'] as double).toStringAsFixed(1)} characters',
    );
    print('   • Max length: ${stats['max_length']} characters');
    print('   • Min length: ${stats['min_length']} characters');
  }

  // Check database size and page info
  final pragmaResults = await db.rawQuery('PRAGMA page_size');
  final pageSize = pragmaResults.first['page_size'] as int;

  final pageCounts = await db.rawQuery('PRAGMA page_count');
  final pageCount = pageCounts.first['page_count'] as int;

  final calculatedSize = (pageSize * pageCount) / (1024 * 1024);
  print('\n💾 Database internals:');
  print('   • Page size: $pageSize bytes');
  print('   • Page count: $pageCount');
  print('   • Calculated size: ${calculatedSize.toStringAsFixed(1)} MB');
}

Future<void> _optimizeDatabase(Database db) async {
  print('\n🔧 Optimizing database...');

  // Analyze tables for query planner
  print('   📊 Analyzing tables...');
  await db.rawQuery('ANALYZE');

  // Vacuum to reclaim space
  print('   🗜️  Vacuuming database...');
  await db.rawQuery('VACUUM');

  print('✅ Database optimization complete!');

  // Check size after optimization
  final file = File('assets/bibles.db');
  // ignore: avoid_slow_async_io
  final stats = await file.stat();
  final sizeMB = (stats.size / (1024 * 1024)).toStringAsFixed(1);
  print('   📦 Final size: ${sizeMB}MB');
}
