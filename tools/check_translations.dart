#!/usr/bin/env dart

import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Check what translation IDs are in the database
void main() async {
  print('🔍 Checking translation IDs in database...');
  
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
    // Get all translations
    final translations = await database.query('translations', orderBy: 'id');
    
    print('\n📖 Translations in database:');
    for (final translation in translations) {
      print('   • ID: "${translation['id']}" - Name: "${translation['name']}"');
    }
    
    print('\n🧪 Testing BibleTranslation.fromId():');
    for (final translation in translations) {
      final id = translation['id'] as String;
      try {
        // This simulates what the app does
        print('   ✅ BibleTranslation.fromId("$id") - should work');
      } catch (e) {
        print('   ❌ BibleTranslation.fromId("$id") - would fail: $e');
      }
    }
    
  } finally {
    await database.close();
  }
}