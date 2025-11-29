import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/encouragement.dart';
import '../models/fast_session.dart';
import '../models/fast_status.dart';
import '../models/fast_type.dart';
import '../models/fast_type_category.dart';

/// SQLite database for fasting companion app
///
/// Manages schema creation, migrations, and CRUD operations for:
/// - Fast types (intermittent, 24-hour, multi-day, liturgical)
/// - Fast sessions (active and historical)
/// - Encouragements (scripture, saint quotes, prayers)
/// - Encouragement history (tracking shown encouragements)
class FastingDatabase {
  static const String _databaseName = 'fasting_companion.db';
  static const int _databaseVersion = 1;

  // Table names
  static const String tableFastTypes = 'fast_types';
  static const String tableFastSessions = 'fast_sessions';
  static const String tableEncouragements = 'encouragements';
  static const String tableEncouragementHistory = 'encouragement_history';

  Database? _database;
  final String? _testDatabaseName;

  /// Constructor with optional test database name for testing
  FastingDatabase({String? testDatabaseName})
      : _testDatabaseName = testDatabaseName;

  /// Get database instance (singleton pattern)
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  /// Initialize database
  Future<Database> _initDatabase() async {
    final databasesPath = await getDatabasesPath();
    final dbName = _testDatabaseName ?? _databaseName;
    final path = join(databasesPath, dbName);

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
    // Future schema migrations will go here
  }

  /// Create all database tables
  Future<void> _createTables(Database db) async {
    // Fast Types table
    await db.execute('''
      CREATE TABLE $tableFastTypes (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT NOT NULL,
        category TEXT NOT NULL,
        target_duration_hours INTEGER,
        milestones TEXT,
        prayers TEXT
      )
    ''');

    // Fast Sessions table
    await db.execute('''
      CREATE TABLE $tableFastSessions (
        id TEXT PRIMARY KEY,
        type_id TEXT NOT NULL,
        start_time INTEGER NOT NULL,
        end_time INTEGER,
        target_duration_minutes INTEGER NOT NULL,
        status TEXT NOT NULL,
        notes TEXT,
        encouragements_shown TEXT,
        FOREIGN KEY (type_id) REFERENCES $tableFastTypes (id)
      )
    ''');

    // Create index on status for active fast queries
    await db.execute('''
      CREATE INDEX idx_fast_sessions_status
      ON $tableFastSessions (status)
    ''');

    // Create index on start_time for history queries
    await db.execute('''
      CREATE INDEX idx_fast_sessions_start_time
      ON $tableFastSessions (start_time DESC)
    ''');

    // Encouragements table
    await db.execute('''
      CREATE TABLE $tableEncouragements (
        id TEXT PRIMARY KEY,
        category TEXT NOT NULL,
        trigger_point TEXT NOT NULL,
        liturgical_season TEXT,
        content TEXT NOT NULL,
        attribution TEXT,
        related_scripture TEXT,
        category_hint TEXT
      )
    ''');

    // Create index on trigger_point for quick lookup
    await db.execute('''
      CREATE INDEX idx_encouragements_trigger
      ON $tableEncouragements (trigger_point)
    ''');

    // Create index on liturgical_season
    await db.execute('''
      CREATE INDEX idx_encouragements_season
      ON $tableEncouragements (liturgical_season)
    ''');

    // Encouragement History table
    await db.execute('''
      CREATE TABLE $tableEncouragementHistory (
        id TEXT PRIMARY KEY,
        fast_session_id TEXT,
        encouragement_id TEXT,
        shown_at INTEGER NOT NULL,
        FOREIGN KEY (fast_session_id) REFERENCES $tableFastSessions (id),
        FOREIGN KEY (encouragement_id) REFERENCES $tableEncouragements (id)
      )
    ''');

    // Create index on fast_session_id for session queries
    await db.execute('''
      CREATE INDEX idx_encouragement_history_session
      ON $tableEncouragementHistory (fast_session_id)
    ''');
  }

  // ==================== FastType CRUD ====================

  /// Insert a fast type
  Future<void> insertFastType(FastType fastType) async {
    final db = await database;
    await db.insert(
      tableFastTypes,
      _fastTypeToMap(fastType),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Get all fast types
  Future<List<FastType>> getAllFastTypes() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(tableFastTypes);
    return List.generate(maps.length, (i) => _fastTypeFromMap(maps[i]));
  }

  /// Get fast types by category
  Future<List<FastType>> getFastTypesByCategory(
    FastTypeCategory category,
  ) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      tableFastTypes,
      where: 'category = ?',
      whereArgs: [category.toJson()],
    );
    return List.generate(maps.length, (i) => _fastTypeFromMap(maps[i]));
  }

  /// Get fast type by ID
  Future<FastType?> getFastTypeById(String id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      tableFastTypes,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return _fastTypeFromMap(maps.first);
  }

  /// Delete a fast type
  Future<void> deleteFastType(String id) async {
    final db = await database;
    await db.delete(
      tableFastTypes,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ==================== FastSession CRUD ====================

  /// Insert a fast session
  Future<void> insertFastSession(FastSession session) async {
    final db = await database;
    await db.insert(
      tableFastSessions,
      _fastSessionToMap(session),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Update a fast session
  Future<void> updateFastSession(FastSession session) async {
    final db = await database;
    await db.update(
      tableFastSessions,
      _fastSessionToMap(session),
      where: 'id = ?',
      whereArgs: [session.id],
    );
  }

  /// Get active fast session (if any)
  Future<FastSession?> getActiveFastSession() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      tableFastSessions,
      where: 'status = ?',
      whereArgs: [FastStatus.active.toJson()],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return _fastSessionFromMap(maps.first);
  }

  /// Get fast session by ID
  Future<FastSession?> getFastSessionById(String id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      tableFastSessions,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return _fastSessionFromMap(maps.first);
  }

  /// Get fast sessions (history)
  Future<List<FastSession>> getFastSessions({
    int? limit,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final db = await database;
    String? whereClause;
    List<dynamic>? whereArgs;

    if (startDate != null && endDate != null) {
      whereClause = 'start_time BETWEEN ? AND ?';
      whereArgs = [
        startDate.millisecondsSinceEpoch,
        endDate.millisecondsSinceEpoch,
      ];
    } else if (startDate != null) {
      whereClause = 'start_time >= ?';
      whereArgs = [startDate.millisecondsSinceEpoch];
    }

    final List<Map<String, dynamic>> maps = await db.query(
      tableFastSessions,
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'start_time DESC',
      limit: limit,
    );
    return List.generate(maps.length, (i) => _fastSessionFromMap(maps[i]));
  }

  /// Get completed fasts count
  Future<int> getCompletedFastsCount() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM $tableFastSessions WHERE status = ?',
      [FastStatus.completed.toJson()],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Delete a fast session
  Future<void> deleteFastSession(String id) async {
    final db = await database;
    await db.delete(
      tableFastSessions,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ==================== Encouragement CRUD ====================

  /// Insert an encouragement
  Future<void> insertEncouragement(Encouragement encouragement) async {
    final db = await database;
    await db.insert(
      tableEncouragements,
      _encouragementToMap(encouragement),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Get all encouragements
  Future<List<Encouragement>> getAllEncouragements() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(tableEncouragements);
    return List.generate(maps.length, (i) => _encouragementFromMap(maps[i]));
  }

  /// Get encouragements by trigger point
  Future<List<Encouragement>> getEncouragementsByTrigger(
    String triggerPoint,
  ) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      tableEncouragements,
      where: 'trigger_point = ?',
      whereArgs: [triggerPoint],
    );
    return List.generate(maps.length, (i) => _encouragementFromMap(maps[i]));
  }

  /// Get encouragements by trigger and season
  Future<List<Encouragement>> getEncouragementsByTriggerAndSeason(
    String triggerPoint,
    String? liturgicalSeason,
  ) async {
    final db = await database;
    String whereClause = 'trigger_point = ?';
    List<dynamic> whereArgs = [triggerPoint];

    if (liturgicalSeason != null) {
      whereClause += ' AND (liturgical_season = ? OR liturgical_season IS NULL)';
      whereArgs.add(liturgicalSeason);
    }

    final List<Map<String, dynamic>> maps = await db.query(
      tableEncouragements,
      where: whereClause,
      whereArgs: whereArgs,
    );
    return List.generate(maps.length, (i) => _encouragementFromMap(maps[i]));
  }

  /// Delete an encouragement
  Future<void> deleteEncouragement(String id) async {
    final db = await database;
    await db.delete(
      tableEncouragements,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ==================== Encouragement History ====================

  /// Record that an encouragement was shown
  Future<void> recordEncouragementShown(
    String fastSessionId,
    String encouragementId,
  ) async {
    final db = await database;
    await db.insert(
      tableEncouragementHistory,
      {
        'id': '${fastSessionId}_${encouragementId}_${DateTime.now().millisecondsSinceEpoch}',
        'fast_session_id': fastSessionId,
        'encouragement_id': encouragementId,
        'shown_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Get encouragements shown for a session
  Future<List<String>> getShownEncouragementIds(String fastSessionId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      tableEncouragementHistory,
      columns: ['encouragement_id'],
      where: 'fast_session_id = ?',
      whereArgs: [fastSessionId],
    );
    return maps.map((m) => m['encouragement_id'] as String).toList();
  }

  // ==================== Utility Methods ====================

  /// Clear all data from database (for testing)
  Future<void> clearAllData() async {
    final db = await database;
    await db.delete(tableEncouragementHistory);
    await db.delete(tableFastSessions);
    await db.delete(tableEncouragements);
    await db.delete(tableFastTypes);
  }

  /// Close database connection
  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }

  // ==================== Mapping Methods ====================

  Map<String, dynamic> _fastTypeToMap(FastType fastType) {
    final json = fastType.toJson();
    return {
      'id': json['id'],
      'name': json['name'],
      'description': json['description'],
      'category': json['category'],
      'target_duration_hours': json['targetDurationHours'],
      'milestones': json['milestoneMessages'] != null
          ? _encodeJson(json['milestoneMessages'])
          : null,
      'prayers': json['associatedPrayers'] != null
          ? _encodeJson(json['associatedPrayers'])
          : null,
    };
  }

  FastType _fastTypeFromMap(Map<String, dynamic> map) {
    return FastType.fromJson({
      'id': map['id'],
      'name': map['name'],
      'description': map['description'],
      'category': map['category'],
      'targetDurationHours': map['target_duration_hours'],
      'milestoneMessages': map['milestones'] != null
          ? _decodeJson(map['milestones'])
          : {},
      'associatedPrayers': map['prayers'] != null
          ? _decodeJson(map['prayers'])
          : [],
    });
  }

  Map<String, dynamic> _fastSessionToMap(FastSession session) {
    final json = session.toJson();
    return {
      'id': json['id'],
      'type_id': json['fastTypeId'],
      'start_time': DateTime.parse(json['startTime'] as String)
          .millisecondsSinceEpoch,
      'end_time': json['endTime'] != null
          ? DateTime.parse(json['endTime'] as String).millisecondsSinceEpoch
          : null,
      'target_duration_minutes': json['targetDurationMinutes'],
      'status': json['status'],
      'notes': json['notes'],
      'encouragements_shown': json['encouragementsShown'] != null
          ? _encodeJson(json['encouragementsShown'])
          : null,
    };
  }

  FastSession _fastSessionFromMap(Map<String, dynamic> map) {
    return FastSession.fromJson({
      'id': map['id'],
      'fastTypeId': map['type_id'],
      'startTime': DateTime.fromMillisecondsSinceEpoch(
        map['start_time'] as int,
      ).toIso8601String(),
      'endTime': map['end_time'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              map['end_time'] as int,
            ).toIso8601String()
          : null,
      'targetDurationMinutes': map['target_duration_minutes'],
      'status': map['status'],
      'notes': map['notes'],
      'encouragementsShown': map['encouragements_shown'] != null
          ? _decodeJson(map['encouragements_shown'])
          : [],
    });
  }

  Map<String, dynamic> _encouragementToMap(Encouragement encouragement) {
    final json = encouragement.toJson();
    return {
      'id': json['id'],
      'category': json['category'],
      'trigger_point': json['triggerPoint'],
      'liturgical_season': json['liturgicalSeason'],
      'content': json['content'],
      'attribution': json['attribution'],
      'related_scripture': json['relatedScripture'],
      'category_hint': json['categoryHint'],
    };
  }

  Encouragement _encouragementFromMap(Map<String, dynamic> map) {
    return Encouragement.fromJson({
      'id': map['id'],
      'category': map['category'],
      'triggerPoint': map['trigger_point'],
      'liturgicalSeason': map['liturgical_season'],
      'content': map['content'],
      'attribution': map['attribution'],
      'relatedScripture': map['related_scripture'],
      'categoryHint': map['category_hint'],
    });
  }

  // JSON encoding/decoding helpers
  String _encodeJson(dynamic data) {
    return data.toString().replaceAll("'", '"');
  }

  dynamic _decodeJson(String jsonString) {
    // Simple JSON parsing for our use case
    if (jsonString.startsWith('[')) {
      // List
      final content = jsonString.substring(1, jsonString.length - 1);
      if (content.isEmpty) return [];
      return content
          .split(',')
          .map((s) => s.trim().replaceAll('"', ''))
          .toList();
    } else if (jsonString.startsWith('{')) {
      // Map
      final content = jsonString.substring(1, jsonString.length - 1);
      if (content.isEmpty) return {};
      final Map<String, String> result = {};
      final pairs = content.split(',');
      for (final pair in pairs) {
        final keyValue = pair.split(':');
        if (keyValue.length == 2) {
          result[keyValue[0].trim().replaceAll('"', '')] =
              keyValue[1].trim().replaceAll('"', '');
        }
      }
      return result;
    }
    return jsonString;
  }
}
