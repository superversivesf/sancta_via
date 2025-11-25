import 'dart:async';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import '../../../utils/logger.dart';

/// Database service for managing novena data in SQLite
class NovenaDatabaseService {
  static final NovenaDatabaseService _instance =
      NovenaDatabaseService._internal();
  factory NovenaDatabaseService() => _instance;
  NovenaDatabaseService._internal();

  static Database? _database;
  static const String _databaseName = 'novena_companion.db';
  static const int _databaseVersion = 1;

  /// Get database instance (singleton pattern)
  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  /// Initialize the database
  Future<Database> _initDatabase() async {
    try {
      AppLogger.debug('Initializing novena database...', 'DATABASE');

      final documentsDirectory = await getApplicationDocumentsDirectory();
      final path = '${documentsDirectory.path}/novena_companion.db';

      AppLogger.debug('Database path: $path', 'DATABASE');

      return await openDatabase(
        path,
        version: _databaseVersion,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
        onOpen: _onOpen,
      );
    } catch (e, stackTrace) {
      AppLogger.error(
        'Failed to initialize database',
        e,
        stackTrace,
        'DATABASE',
      );
      rethrow;
    }
  }

  /// Create database schema
  Future<void> _onCreate(Database db, int version) async {
    try {
      AppLogger.info(
        'Creating novena database schema version $version',
        'DATABASE',
      );

      // Create novenas table
      await db.execute('''
        CREATE TABLE novenas (
          id TEXT PRIMARY KEY,
          title TEXT NOT NULL,
          description TEXT NOT NULL,
          saint TEXT NOT NULL,
          feast_day TEXT NOT NULL,
          intention_category TEXT NOT NULL,
          difficulty TEXT NOT NULL,
          duration_minutes INTEGER NOT NULL,
          intention TEXT NOT NULL,
          instructions TEXT NOT NULL,
          background_info TEXT,
          source TEXT NOT NULL,
          notes TEXT,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL
        )
      ''');

      // Create novena_days table
      await db.execute('''
        CREATE TABLE novena_days (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          novena_id TEXT NOT NULL,
          day INTEGER NOT NULL,
          title TEXT NOT NULL,
          opening_prayer TEXT NOT NULL,
          daily_prayer TEXT NOT NULL,
          closing_prayer TEXT NOT NULL,
          reflection TEXT NOT NULL,
          intention_prayer TEXT NOT NULL,
          scripture TEXT,
          FOREIGN KEY (novena_id) REFERENCES novenas (id) ON DELETE CASCADE,
          UNIQUE(novena_id, day)
        )
      ''');

      // Create indexes for performance
      await db.execute(
        'CREATE INDEX idx_novenas_category ON novenas(intention_category)',
      );
      await db.execute(
        'CREATE INDEX idx_novenas_difficulty ON novenas(difficulty)',
      );
      await db.execute('CREATE INDEX idx_novenas_saint ON novenas(saint)');
      await db.execute(
        'CREATE INDEX idx_novena_days_lookup ON novena_days(novena_id, day)',
      );

      AppLogger.info('Database schema created successfully', 'DATABASE');
    } catch (e, stackTrace) {
      AppLogger.error(
        'Failed to create database schema',
        e,
        stackTrace,
        'DATABASE',
      );
      rethrow;
    }
  }

  /// Handle database upgrades
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    AppLogger.info(
      'Upgrading database from version $oldVersion to $newVersion',
      'DATABASE',
    );

    // Future database migrations would go here
    // For now, we only have version 1
  }

  /// Called when database is opened
  Future<void> _onOpen(Database db) async {
    AppLogger.debug('Database opened successfully', 'DATABASE');

    // Enable foreign key constraints
    await db.execute('PRAGMA foreign_keys = ON');
  }

  /// Insert a complete novena (metadata + all days)
  Future<void> insertNovena(Map<String, dynamic> novenaData) async {
    final db = await database;

    try {
      await db.transaction((txn) async {
        // Insert novena metadata
        final now = DateTime.now().toIso8601String();
        final novenaMetadata = Map<String, dynamic>.from(novenaData);
        novenaMetadata['created_at'] = now;
        novenaMetadata['updated_at'] = now;

        // Remove days from metadata before insertion
        final days = novenaMetadata.remove('days') as List<dynamic>;

        await txn.insert('novenas', novenaMetadata);
        AppLogger.debug(
          'Inserted novena metadata: ${novenaData['id']}',
          'DATABASE',
        );

        // Insert all days
        for (final dayData in days) {
          final dayMap = Map<String, dynamic>.from(
            dayData as Map<String, dynamic>,
          );
          dayMap['novena_id'] = novenaData['id'];
          await txn.insert('novena_days', dayMap);
        }

        AppLogger.debug(
          'Inserted ${days.length} days for novena: ${novenaData['id']}',
          'DATABASE',
        );
      });
    } catch (e, stackTrace) {
      AppLogger.error(
        'Failed to insert novena: ${novenaData['id']}',
        e,
        stackTrace,
        'DATABASE',
      );
      rethrow;
    }
  }

  /// Get all novena metadata (for lists/browsing)
  Future<List<Map<String, dynamic>>> getAllNovenaMetadata() async {
    final db = await database;

    try {
      final results = await db.query('novenas', orderBy: 'title ASC');

      AppLogger.debug(
        'Retrieved ${results.length} novena metadata records',
        'DATABASE',
      );
      return results;
    } catch (e, stackTrace) {
      AppLogger.error(
        'Failed to get novena metadata',
        e,
        stackTrace,
        'DATABASE',
      );
      rethrow;
    }
  }

  /// Get complete novena by ID (metadata + all days)
  Future<Map<String, dynamic>?> getNovenaById(String id) async {
    final db = await database;

    try {
      // Get novena metadata
      final novenaResults = await db.query(
        'novenas',
        where: 'id = ?',
        whereArgs: [id],
      );

      if (novenaResults.isEmpty) {
        AppLogger.warning('Novena not found: $id', 'DATABASE');
        return null;
      }

      final novena = Map<String, dynamic>.from(novenaResults.first);

      // Get all days for this novena
      final dayResults = await db.query(
        'novena_days',
        where: 'novena_id = ?',
        whereArgs: [id],
        orderBy: 'day ASC',
      );

      // Add days to novena data
      novena['days'] = dayResults.map((day) {
        final dayMap = Map<String, dynamic>.from(day);
        dayMap.remove('id'); // Remove auto-increment ID
        dayMap.remove('novena_id'); // Remove foreign key
        return dayMap;
      }).toList();

      AppLogger.debug(
        'Retrieved complete novena: $id with ${dayResults.length} days',
        'DATABASE',
      );
      return novena;
    } catch (e, stackTrace) {
      AppLogger.error('Failed to get novena: $id', e, stackTrace, 'DATABASE');
      rethrow;
    }
  }

  /// Get novenas by category
  Future<List<Map<String, dynamic>>> getNovenasByCategory(
    String category,
  ) async {
    final db = await database;

    try {
      final results = await db.query(
        'novenas',
        where: 'intention_category = ?',
        whereArgs: [category],
        orderBy: 'title ASC',
      );

      AppLogger.debug(
        'Retrieved ${results.length} novenas for category: $category',
        'DATABASE',
      );
      return results;
    } catch (e, stackTrace) {
      AppLogger.error(
        'Failed to get novenas by category: $category',
        e,
        stackTrace,
        'DATABASE',
      );
      rethrow;
    }
  }

  /// Get novenas by difficulty
  Future<List<Map<String, dynamic>>> getNovenasByDifficulty(
    String difficulty,
  ) async {
    final db = await database;

    try {
      final results = await db.query(
        'novenas',
        where: 'difficulty = ?',
        whereArgs: [difficulty],
        orderBy: 'title ASC',
      );

      AppLogger.debug(
        'Retrieved ${results.length} novenas for difficulty: $difficulty',
        'DATABASE',
      );
      return results;
    } catch (e, stackTrace) {
      AppLogger.error(
        'Failed to get novenas by difficulty: $difficulty',
        e,
        stackTrace,
        'DATABASE',
      );
      rethrow;
    }
  }

  /// Search novenas by text (title, saint, description)
  Future<List<Map<String, dynamic>>> searchNovenas(String searchTerm) async {
    final db = await database;

    try {
      final results = await db.query(
        'novenas',
        where: 'title LIKE ? OR saint LIKE ? OR description LIKE ?',
        whereArgs: ['%$searchTerm%', '%$searchTerm%', '%$searchTerm%'],
        orderBy: 'title ASC',
      );

      AppLogger.debug(
        'Found ${results.length} novenas matching: $searchTerm',
        'DATABASE',
      );
      return results;
    } catch (e, stackTrace) {
      AppLogger.error(
        'Failed to search novenas: $searchTerm',
        e,
        stackTrace,
        'DATABASE',
      );
      rethrow;
    }
  }

  /// Get all unique categories
  Future<List<String>> getAllCategories() async {
    final db = await database;

    try {
      final results = await db.query(
        'novenas',
        columns: ['DISTINCT intention_category'],
        orderBy: 'intention_category ASC',
      );

      final categories = results
          .map((row) => row['intention_category'] as String)
          .toList();

      AppLogger.debug(
        'Retrieved ${categories.length} unique categories',
        'DATABASE',
      );
      return categories;
    } catch (e, stackTrace) {
      AppLogger.error('Failed to get categories', e, stackTrace, 'DATABASE');
      rethrow;
    }
  }

  /// Get all unique difficulties
  Future<List<String>> getAllDifficulties() async {
    final db = await database;

    try {
      final results = await db.query(
        'novenas',
        columns: ['DISTINCT difficulty'],
        orderBy: 'difficulty ASC',
      );

      final difficulties = results
          .map((row) => row['difficulty'] as String)
          .toList();

      AppLogger.debug(
        'Retrieved ${difficulties.length} unique difficulties',
        'DATABASE',
      );
      return difficulties;
    } catch (e, stackTrace) {
      AppLogger.error('Failed to get difficulties', e, stackTrace, 'DATABASE');
      rethrow;
    }
  }

  /// Delete a novena and all its days
  Future<void> deleteNovena(String id) async {
    final db = await database;

    try {
      await db.transaction((txn) async {
        // Delete days first (foreign key will handle this with CASCADE, but being explicit)
        await txn.delete(
          'novena_days',
          where: 'novena_id = ?',
          whereArgs: [id],
        );

        // Delete novena metadata
        final deletedCount = await txn.delete(
          'novenas',
          where: 'id = ?',
          whereArgs: [id],
        );

        if (deletedCount == 0) {
          throw Exception('Novena not found: $id');
        }
      });

      AppLogger.info('Deleted novena: $id', 'DATABASE');
    } catch (e, stackTrace) {
      AppLogger.error(
        'Failed to delete novena: $id',
        e,
        stackTrace,
        'DATABASE',
      );
      rethrow;
    }
  }

  /// Check if database is empty
  Future<bool> isDatabaseEmpty() async {
    final db = await database;

    try {
      final result = await db.rawQuery('SELECT COUNT(*) as count FROM novenas');
      final count = result.first['count'] as int;

      AppLogger.debug('Database contains $count novenas', 'DATABASE');
      return count == 0;
    } catch (e, stackTrace) {
      AppLogger.error(
        'Failed to check if database is empty',
        e,
        stackTrace,
        'DATABASE',
      );
      rethrow;
    }
  }

  /// Clear all novena data (for fresh installations or testing)
  Future<void> clearAllData() async {
    final db = await database;

    try {
      await db.transaction((txn) async {
        await txn.delete('novena_days');
        await txn.delete('novenas');
      });

      AppLogger.warning('Cleared all novena data from database', 'DATABASE');
    } catch (e, stackTrace) {
      AppLogger.error('Failed to clear database', e, stackTrace, 'DATABASE');
      rethrow;
    }
  }

  /// Get database statistics
  Future<Map<String, int>> getDatabaseStats() async {
    final db = await database;

    try {
      final novenaCount = await db.rawQuery(
        'SELECT COUNT(*) as count FROM novenas',
      );
      final dayCount = await db.rawQuery(
        'SELECT COUNT(*) as count FROM novena_days',
      );

      final stats = {
        'novenas': novenaCount.first['count'] as int,
        'days': dayCount.first['count'] as int,
      };

      AppLogger.debug('Database stats: $stats', 'DATABASE');
      return stats;
    } catch (e, stackTrace) {
      AppLogger.error(
        'Failed to get database stats',
        e,
        stackTrace,
        'DATABASE',
      );
      rethrow;
    }
  }

  /// Close database connection
  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
      AppLogger.debug('Database connection closed', 'DATABASE');
    }
  }
}
