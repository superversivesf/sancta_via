import 'dart:async';

import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/prayer.dart';
import '../models/prayer_category.dart';
import '../models/prayer_category_group.dart';
import '../utils/logger.dart';

/// SQLite database helper for the prayer companion app
class PrayerDatabase {
  static const String _databaseName = 'prayers.db';
  static const int _databaseVersion = 2; // Bumped for time_of_day field

  // Singleton pattern
  static PrayerDatabase? _instance;
  static Database? _database;

  PrayerDatabase._();

  static PrayerDatabase get instance {
    _instance ??= PrayerDatabase._();
    return _instance!;
  }

  /// Get the database instance, creating it if necessary
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  /// Initialize the database
  Future<Database> _initDatabase() async {
    final documentsDirectory = await getDatabasesPath();
    final path = join(documentsDirectory, _databaseName);

    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  /// Create database tables
  Future<void> _onCreate(Database db, int version) async {
    await _createTables(db);
  }

  /// Handle database upgrades
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Handle database migrations here when needed
    // For now, we'll recreate all tables (data will be re-migrated from JSON)
    await _dropTables(db);
    await _createTables(db);
  }

  /// Create all database tables
  Future<void> _createTables(Database db) async {
    // Category Groups table
    await db.execute('''
      CREATE TABLE category_groups (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        description TEXT NOT NULL,
        icon TEXT NOT NULL,
        order_index INTEGER NOT NULL
      )
    ''');

    // Categories table
    await db.execute('''
      CREATE TABLE categories (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        description TEXT NOT NULL,
        group_id TEXT NOT NULL,
        FOREIGN KEY (group_id) REFERENCES category_groups (id)
      )
    ''');

    // Prayers table (with time_of_day field)
    await db.execute('''
      CREATE TABLE prayers (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        text TEXT NOT NULL,
        attribution TEXT,
        notes TEXT,
        description TEXT NOT NULL,
        is_liturgical INTEGER NOT NULL DEFAULT 0,
        liturgical_priority INTEGER NOT NULL DEFAULT 0,
        liturgical_season TEXT,
        time_of_day TEXT NOT NULL DEFAULT 'anytime'
      )
    ''');

    // Prayer Categories junction table (many-to-many)
    await db.execute('''
      CREATE TABLE prayer_categories (
        prayer_id TEXT NOT NULL,
        category_id TEXT NOT NULL,
        PRIMARY KEY (prayer_id, category_id),
        FOREIGN KEY (prayer_id) REFERENCES prayers (id) ON DELETE CASCADE,
        FOREIGN KEY (category_id) REFERENCES categories (id) ON DELETE CASCADE
      )
    ''');

    // Prayer Tags table
    await db.execute('''
      CREATE TABLE prayer_tags (
        prayer_id TEXT NOT NULL,
        tag TEXT NOT NULL,
        PRIMARY KEY (prayer_id, tag),
        FOREIGN KEY (prayer_id) REFERENCES prayers (id) ON DELETE CASCADE
      )
    ''');

    // Prayer Translations table
    await db.execute('''
      CREATE TABLE prayer_translations (
        prayer_id TEXT NOT NULL,
        language TEXT NOT NULL,
        text TEXT NOT NULL,
        PRIMARY KEY (prayer_id, language),
        FOREIGN KEY (prayer_id) REFERENCES prayers (id) ON DELETE CASCADE
      )
    ''');

    // Create indexes for better performance
    await db.execute(
      'CREATE INDEX idx_prayers_liturgical ON prayers (is_liturgical, liturgical_priority)',
    );
    await db.execute(
      'CREATE INDEX idx_prayers_season ON prayers (liturgical_season)',
    );
    await db.execute(
      'CREATE INDEX idx_prayers_time_of_day ON prayers (time_of_day)',
    );
    await db.execute(
      'CREATE INDEX idx_prayer_categories_prayer ON prayer_categories (prayer_id)',
    );
    await db.execute(
      'CREATE INDEX idx_prayer_categories_category ON prayer_categories (category_id)',
    );
    await db.execute(
      'CREATE INDEX idx_prayer_tags_prayer ON prayer_tags (prayer_id)',
    );
    await db.execute('CREATE INDEX idx_prayer_tags_tag ON prayer_tags (tag)');

    AppLogger.info('Database tables created successfully', 'DB');
  }

  /// Drop all tables (used for migrations)
  Future<void> _dropTables(Database db) async {
    await db.execute('DROP TABLE IF EXISTS prayer_translations');
    await db.execute('DROP TABLE IF EXISTS prayer_tags');
    await db.execute('DROP TABLE IF EXISTS prayer_categories');
    await db.execute('DROP TABLE IF EXISTS prayers');
    await db.execute('DROP TABLE IF EXISTS categories');
    await db.execute('DROP TABLE IF EXISTS category_groups');
  }

  /// Insert or update category group
  Future<void> insertCategoryGroup(PrayerCategoryGroup group) async {
    final db = await database;
    await db.insert('category_groups', {
      'id': group.id,
      'title': group.title,
      'description': group.description,
      'icon': group.icon,
      'order_index': group.order,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Insert or update category
  Future<void> insertCategory(PrayerCategory category) async {
    final db = await database;
    await db.insert('categories', {
      'id': category.id,
      'title': category.title,
      'description': category.description,
      'group_id': category.groupId,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Insert or update prayer
  Future<void> insertPrayer(Prayer prayer) async {
    final db = await database;

    // Start transaction for data consistency
    await db.transaction((txn) async {
      // Insert main prayer record
      await txn.insert('prayers', {
        'id': prayer.id,
        'title': prayer.title,
        'text': prayer.text,
        'attribution': prayer.attribution,
        'notes': prayer.notes,
        'description': prayer.description,
        'is_liturgical': prayer.isLiturgical ? 1 : 0,
        'liturgical_priority': prayer.liturgicalPriority,
        'liturgical_season': prayer.liturgicalSeason,
        'time_of_day': prayer.timeOfDay,
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      // Delete existing related records to avoid duplicates
      await txn.delete(
        'prayer_categories',
        where: 'prayer_id = ?',
        whereArgs: [prayer.id],
      );
      await txn.delete(
        'prayer_tags',
        where: 'prayer_id = ?',
        whereArgs: [prayer.id],
      );
      await txn.delete(
        'prayer_translations',
        where: 'prayer_id = ?',
        whereArgs: [prayer.id],
      );

      // Insert categories
      for (final categoryId in prayer.categories) {
        await txn.insert('prayer_categories', {
          'prayer_id': prayer.id,
          'category_id': categoryId,
        });
      }

      // Insert tags
      for (final tag in prayer.tags) {
        await txn.insert('prayer_tags', {'prayer_id': prayer.id, 'tag': tag});
      }

      // Insert translations
      if (prayer.translations != null) {
        for (final entry in prayer.translations!.entries) {
          await txn.insert('prayer_translations', {
            'prayer_id': prayer.id,
            'language': entry.key,
            'text': entry.value,
          });
        }
      }
    });
  }

  /// Get all category groups
  Future<List<PrayerCategoryGroup>> getCategoryGroups() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'category_groups',
      orderBy: 'order_index ASC',
    );

    return List.generate(maps.length, (i) {
      return PrayerCategoryGroup(
        id: maps[i]['id'],
        title: maps[i]['title'],
        description: maps[i]['description'],
        icon: maps[i]['icon'],
        order: maps[i]['order_index'],
      );
    });
  }

  /// Get all categories
  Future<List<PrayerCategory>> getCategories() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('categories');

    return List.generate(maps.length, (i) {
      return PrayerCategory(
        id: maps[i]['id'],
        title: maps[i]['title'],
        description: maps[i]['description'],
        groupId: maps[i]['group_id'],
      );
    });
  }

  /// Get categories by group ID
  Future<List<PrayerCategory>> getCategoriesByGroup(String groupId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'categories',
      where: 'group_id = ?',
      whereArgs: [groupId],
    );

    return List.generate(maps.length, (i) {
      return PrayerCategory(
        id: maps[i]['id'],
        title: maps[i]['title'],
        description: maps[i]['description'],
        groupId: maps[i]['group_id'],
      );
    });
  }

  /// Get all prayers with complete data
  Future<List<Prayer>> getAllPrayers() async {
    final db = await database;

    // Get basic prayer data
    final List<Map<String, dynamic>> prayerMaps = await db.query('prayers');

    final List<Prayer> prayers = [];

    for (final prayerMap in prayerMaps) {
      final prayerId = prayerMap['id'] as String;

      // Get categories for this prayer
      final categoriesMaps = await db.query(
        'prayer_categories',
        where: 'prayer_id = ?',
        whereArgs: [prayerId],
      );
      final categories = categoriesMaps
          .map((m) => m['category_id'] as String)
          .toList();

      // Get tags for this prayer
      final tagsMaps = await db.query(
        'prayer_tags',
        where: 'prayer_id = ?',
        whereArgs: [prayerId],
      );
      final tags = tagsMaps.map((m) => m['tag'] as String).toList();

      // Get translations for this prayer
      final translationsMaps = await db.query(
        'prayer_translations',
        where: 'prayer_id = ?',
        whereArgs: [prayerId],
      );
      final translations = <String, String>{};
      for (final translationMap in translationsMaps) {
        translations[translationMap['language'] as String] =
            translationMap['text'] as String;
      }

      prayers.add(
        Prayer(
          id: prayerMap['id'],
          title: prayerMap['title'],
          text: prayerMap['text'],
          attribution: prayerMap['attribution'],
          notes: prayerMap['notes'],
          categories: categories,
          description: prayerMap['description'],
          tags: tags,
          translations: translations.isEmpty ? null : translations,
          isLiturgical: prayerMap['is_liturgical'] == 1,
          liturgicalPriority: prayerMap['liturgical_priority'],
          liturgicalSeason: prayerMap['liturgical_season'],
          timeOfDay: prayerMap['time_of_day'] ?? 'anytime',
        ),
      );
    }

    return prayers;
  }

  /// Get prayer by ID
  Future<Prayer?> getPrayerById(String id) async {
    final db = await database;

    // Get basic prayer data
    final List<Map<String, dynamic>> prayerMaps = await db.query(
      'prayers',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (prayerMaps.isEmpty) return null;

    final prayerMap = prayerMaps.first;

    // Get categories for this prayer
    final categoriesMaps = await db.query(
      'prayer_categories',
      where: 'prayer_id = ?',
      whereArgs: [id],
    );
    final categories = categoriesMaps
        .map((m) => m['category_id'] as String)
        .toList();

    // Get tags for this prayer
    final tagsMaps = await db.query(
      'prayer_tags',
      where: 'prayer_id = ?',
      whereArgs: [id],
    );
    final tags = tagsMaps.map((m) => m['tag'] as String).toList();

    // Get translations for this prayer
    final translationsMaps = await db.query(
      'prayer_translations',
      where: 'prayer_id = ?',
      whereArgs: [id],
    );
    final translations = <String, String>{};
    for (final translationMap in translationsMaps) {
      translations[translationMap['language'] as String] =
          translationMap['text'] as String;
    }

    return Prayer(
      id: prayerMap['id'],
      title: prayerMap['title'],
      text: prayerMap['text'],
      attribution: prayerMap['attribution'],
      notes: prayerMap['notes'],
      categories: categories,
      description: prayerMap['description'],
      tags: tags,
      translations: translations.isEmpty ? null : translations,
      isLiturgical: prayerMap['is_liturgical'] == 1,
      liturgicalPriority: prayerMap['liturgical_priority'],
      liturgicalSeason: prayerMap['liturgical_season'],
      timeOfDay: prayerMap['time_of_day'] ?? 'anytime',
    );
  }

  /// Get prayers by category
  Future<List<Prayer>> getPrayersByCategory(String categoryId) async {
    final db = await database;

    final List<Map<String, dynamic>> maps = await db.rawQuery(
      '''
      SELECT p.* FROM prayers p
      INNER JOIN prayer_categories pc ON p.id = pc.prayer_id
      WHERE pc.category_id = ?
      ORDER BY p.title
    ''',
      [categoryId],
    );

    final List<Prayer> prayers = [];

    for (final prayerMap in maps) {
      final prayerId = prayerMap['id'] as String;

      // Get categories, tags, and translations for each prayer
      final prayer = await getPrayerById(prayerId);
      if (prayer != null) prayers.add(prayer);
    }

    return prayers;
  }

  /// Get prayers by time of day
  /// Returns prayers that match the specified time OR are marked as 'anytime'
  Future<List<Prayer>> getPrayersByTimeOfDay(String timeOfDay) async {
    final db = await database;

    final List<Map<String, dynamic>> maps = await db.query(
      'prayers',
      where: 'time_of_day = ? OR time_of_day = ?',
      whereArgs: [timeOfDay, 'anytime'],
      orderBy: 'title',
    );

    final List<Prayer> prayers = [];

    for (final prayerMap in maps) {
      final prayerId = prayerMap['id'] as String;
      final prayer = await getPrayerById(prayerId);
      if (prayer != null) prayers.add(prayer);
    }

    return prayers;
  }

  /// Get prayers for a specific time of day only (not including 'anytime')
  Future<List<Prayer>> getPrayersForExactTimeOfDay(String timeOfDay) async {
    final db = await database;

    final List<Map<String, dynamic>> maps = await db.query(
      'prayers',
      where: 'time_of_day = ?',
      whereArgs: [timeOfDay],
      orderBy: 'title',
    );

    final List<Prayer> prayers = [];

    for (final prayerMap in maps) {
      final prayerId = prayerMap['id'] as String;
      final prayer = await getPrayerById(prayerId);
      if (prayer != null) prayers.add(prayer);
    }

    return prayers;
  }

  /// Search prayers by title or text
  Future<List<Prayer>> searchPrayers(String query) async {
    final db = await database;

    final List<Map<String, dynamic>> maps = await db.query(
      'prayers',
      where: 'title LIKE ? OR text LIKE ? OR description LIKE ?',
      whereArgs: ['%$query%', '%$query%', '%$query%'],
      orderBy: 'title',
    );

    final List<Prayer> prayers = [];

    for (final prayerMap in maps) {
      final prayerId = prayerMap['id'] as String;
      final prayer = await getPrayerById(prayerId);
      if (prayer != null) prayers.add(prayer);
    }

    return prayers;
  }

  /// Get liturgical prayers ordered by priority
  Future<List<Prayer>> getLiturgicalPrayers({String? season}) async {
    final db = await database;

    String whereClause = 'is_liturgical = 1';
    final List<dynamic> whereArgs = [];

    if (season != null) {
      whereClause +=
          ' AND (liturgical_season = ? OR liturgical_season IS NULL)';
      whereArgs.add(season);
    }

    final List<Map<String, dynamic>> maps = await db.query(
      'prayers',
      where: whereClause,
      whereArgs: whereArgs.isEmpty ? null : whereArgs,
      orderBy: 'liturgical_priority DESC, title',
    );

    final List<Prayer> prayers = [];

    for (final prayerMap in maps) {
      final prayerId = prayerMap['id'] as String;
      final prayer = await getPrayerById(prayerId);
      if (prayer != null) prayers.add(prayer);
    }

    return prayers;
  }

  /// Check if database has been populated
  Future<bool> isDatabasePopulated() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM prayers');
    final count = result.first['count'] as int;
    return count > 0;
  }

  /// Clear all data from database
  Future<void> clearDatabase() async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('prayer_translations');
      await txn.delete('prayer_tags');
      await txn.delete('prayer_categories');
      await txn.delete('prayers');
      await txn.delete('categories');
      await txn.delete('category_groups');
    });
    AppLogger.info('Database cleared', 'DB');
  }

  /// Close database connection
  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}
