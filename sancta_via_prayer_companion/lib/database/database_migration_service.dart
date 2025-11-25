import 'dart:convert';

import 'package:flutter/services.dart';

import '../database/prayer_database.dart';
import '../models/prayer.dart';
import '../models/prayer_metadata.dart';
import '../utils/logger.dart';

/// Service to migrate prayer data from JSON files to SQLite database
class DatabaseMigrationService {
  static const String _metadataPath = 'assets/prayers/prayers_metadata.json';

  /// Migrate all prayer data from JSON files to database
  static Future<void> migrateJsonToDatabase() async {
    try {
      AppLogger.info(
        'Starting database migration from JSON files...',
        'MIGRATION',
      );

      final db = PrayerDatabase.instance;

      // Check if database is already populated
      if (await db.isDatabasePopulated()) {
        AppLogger.info(
          'Database already populated, skipping migration',
          'MIGRATION',
        );
        return;
      }

      // Load and parse metadata
      final metadataJson = await rootBundle.loadString(_metadataPath);
      final metadata = FullPrayerMetadata.fromJson(json.decode(metadataJson));

      // Migrate category groups
      AppLogger.info(
        'Migrating ${metadata.categoryGroups.length} category groups...',
        'MIGRATION',
      );
      for (final group in metadata.categoryGroups) {
        await db.insertCategoryGroup(group);
      }

      // Migrate categories
      AppLogger.info(
        'Migrating ${metadata.categories.length} categories...',
        'MIGRATION',
      );
      for (final category in metadata.categories) {
        await db.insertCategory(category);
      }

      // Migrate prayers
      AppLogger.info(
        'Migrating ${metadata.prayers.length} prayers...',
        'MIGRATION',
      );
      int successCount = 0;
      int errorCount = 0;

      for (final prayerMeta in metadata.prayers) {
        try {
          final prayer = await _loadPrayerFromFile(prayerMeta.fileName);
          if (prayer != null) {
            await db.insertPrayer(prayer);
            successCount++;
          } else {
            AppLogger.warning(
              'Failed to load prayer file: ${prayerMeta.fileName}',
              'MIGRATION',
            );
            errorCount++;
          }
        } catch (e) {
          AppLogger.error(
            'Error migrating prayer ${prayerMeta.id}',
            e,
            null,
            'MIGRATION',
          );
          errorCount++;
        }
      }

      AppLogger.info('Database migration completed successfully!', 'MIGRATION');
      AppLogger.info(
        'Migrated: $successCount prayers, Errors: $errorCount',
        'MIGRATION',
      );
    } catch (e) {
      AppLogger.error('Database migration failed', e, null, 'MIGRATION');
      rethrow;
    }
  }

  /// Load a single prayer from its JSON file
  static Future<Prayer?> _loadPrayerFromFile(String fileName) async {
    try {
      final filePath = 'assets/prayers/$fileName';
      final jsonString = await rootBundle.loadString(filePath);
      final jsonData = json.decode(jsonString);
      return Prayer.fromJson(jsonData);
    } catch (e) {
      AppLogger.error(
        'Error loading prayer file $fileName',
        e,
        null,
        'MIGRATION',
      );
      return null;
    }
  }

  /// Force re-migration (clear database and migrate again)
  static Future<void> forceMigration() async {
    AppLogger.info(
      'Force migration requested - clearing database...',
      'MIGRATION',
    );
    final db = PrayerDatabase.instance;
    await db.clearDatabase();
    await migrateJsonToDatabase();
  }

  /// Check if migration is needed
  static Future<bool> isMigrationNeeded() async {
    final db = PrayerDatabase.instance;
    return !(await db.isDatabasePopulated());
  }

  /// Get migration status information
  static Future<Map<String, dynamic>> getMigrationStatus() async {
    final db = PrayerDatabase.instance;
    final isPopulated = await db.isDatabasePopulated();

    if (!isPopulated) {
      return {'isComplete': false, 'message': 'Database migration needed'};
    }

    // Get counts for status
    final prayers = await db.getAllPrayers();
    final categories = await db.getCategories();
    final categoryGroups = await db.getCategoryGroups();

    return {
      'isComplete': true,
      'message': 'Database migration complete',
      'prayerCount': prayers.length,
      'categoryCount': categories.length,
      'categoryGroupCount': categoryGroups.length,
    };
  }
}
