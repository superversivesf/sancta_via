import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/encouragement.dart';
import '../models/fast_type.dart';
import 'fasting_database.dart';

/// Service to handle one-time migration from JSON assets to SQLite
///
/// Checks if the database needs initial population and migrates
/// fast types and encouragements from JSON files to the database.
class DatabaseMigrationService {
  final FastingDatabase _database;

  DatabaseMigrationService(this._database);

  /// Check if migration is needed
  ///
  /// Migration is needed if the fast_types table is empty
  Future<bool> isMigrationNeeded() async {
    final fastTypes = await _database.getAllFastTypes();
    return fastTypes.isEmpty;
  }

  /// Perform initial migration from JSON to database
  ///
  /// Loads fast types and encouragements from asset JSON files
  /// and populates the database tables
  Future<void> performMigration() async {
    await _migrateFastTypes();
    await _migrateEncouragements();
  }

  /// Migrate fast types from JSON to database
  Future<void> _migrateFastTypes() async {
    try {
      final jsonString = await rootBundle.loadString(
        'assets/data/fast_types.json',
      );
      final List<dynamic> jsonData = json.decode(jsonString) as List<dynamic>;

      for (final item in jsonData) {
        final fastType = FastType.fromJson(item as Map<String, dynamic>);
        await _database.insertFastType(fastType);
      }
    } catch (e) {
      // If JSON file doesn't exist, that's okay for initial setup
      // The repository will create default fast types
      rethrow;
    }
  }

  /// Migrate encouragements from JSON to database
  Future<void> _migrateEncouragements() async {
    try {
      final jsonString = await rootBundle.loadString(
        'assets/data/encouragements.json',
      );
      final List<dynamic> jsonData = json.decode(jsonString) as List<dynamic>;

      for (final item in jsonData) {
        final encouragement =
            Encouragement.fromJson(item as Map<String, dynamic>);
        await _database.insertEncouragement(encouragement);
      }
    } catch (e) {
      // If JSON file doesn't exist, that's okay for initial setup
      // The repository will create default encouragements
      rethrow;
    }
  }

  /// Force migration (clear and re-import data)
  ///
  /// Useful for development when JSON data changes
  Future<void> forceMigration() async {
    await _database.clearAllData();
    await performMigration();
  }
}
