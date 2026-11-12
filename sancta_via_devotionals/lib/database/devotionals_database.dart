// SQLite store for the devotionals app (Task 4).
//
// App-local, runtime-created database (no asset copy): the default open
// resolves `devotionals.db` under `getDatabasesPath()` and sqflite's
// onCreate runs the pinned six-table DDL, with the migration service
// stamping `meta.schema_version` (belt and braces — `open()` also calls
// `DatabaseMigrationService.ensureSchema`, which heals an unstamped store).
//
// The JSON-heavy columns (`packs.json`, `enrollments.params_json`,
// `progress.state_json`) pass through raw: this layer is deliberately dumb
// about their payloads — engine typing over those documents is Task 5's
// seam. Rows come back as small typed wrappers; timestamps are ISO-8601
// strings owned by callers. Value sets (notification `status`, intention
// `kind`) are validated here on write with ArgumentError, since the pinned
// DDL ships without CHECK constraints.
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

import 'database_migration_service.dart';

/// Allowed `notification_index.status` value set.
const Set<String> notificationStatuses = <String>{
  'scheduled',
  'fired',
  'cancelled',
};

/// Allowed `intentions.kind` value set.
const Set<String> intentionKinds = <String>{'intention', 'soul'};

void _requireValueSet(Set<String> allowed, String fieldName, String candidate) {
  if (!allowed.contains(candidate)) {
    throw ArgumentError.value(
      candidate,
      fieldName,
      'must be one of: ${allowed.toList()..sort()}',
    );
  }
}

/// A `packs` row: the raw embedded pack JSON plus its bookkeeping.
class PackRow {
  const PackRow({
    required this.id,
    required this.json,
    required this.packVersion,
    required this.embeddedAt,
  });

  factory PackRow.fromRow(Map<String, Object?> row) {
    return PackRow(
      id: row['id'] as String,
      json: row['json'] as String,
      packVersion: row['pack_version'] as String,
      embeddedAt: row['embedded_at'] as String,
    );
  }

  final String id;

  /// Raw pack document (engine typing is Task 5's seam).
  final String json;
  final String packVersion;
  final String embeddedAt;
}

/// An `enrollments` row: stored params + when the user enrolled.
class EnrollmentRow {
  const EnrollmentRow({
    required this.packId,
    required this.paramsJson,
    required this.enrolledAt,
  });

  factory EnrollmentRow.fromRow(Map<String, Object?> row) {
    return EnrollmentRow(
      packId: row['pack_id'] as String,
      paramsJson: row['params_json'] as String,
      enrolledAt: row['enrolled_at'] as String,
    );
  }

  final String packId;

  /// Raw enrollment params (engine typing is Task 5's seam).
  final String paramsJson;
  final String enrolledAt;
}

/// A `progress` row: stored state + when it was last written.
class ProgressRow {
  const ProgressRow({
    required this.packId,
    required this.stateJson,
    required this.updatedAt,
  });

  factory ProgressRow.fromRow(Map<String, Object?> row) {
    return ProgressRow(
      packId: row['pack_id'] as String,
      stateJson: row['state_json'] as String,
      updatedAt: row['updated_at'] as String,
    );
  }

  final String packId;

  /// Raw progress state (engine typing is Task 5's seam).
  final String stateJson;
  final String updatedAt;
}

/// A `notification_index` row. `packId` is nullable per the pinned DDL
/// (app-level notifications are not attached to any pack).
class NotificationRow {
  const NotificationRow({
    required this.id,
    required this.packId,
    required this.fireAt,
    required this.title,
    required this.body,
    required this.deepLink,
    required this.status,
  });

  factory NotificationRow.fromRow(Map<String, Object?> row) {
    return NotificationRow(
      id: row['id'] as String,
      packId: row['pack_id'] as String?,
      fireAt: row['fire_at'] as String,
      title: row['title'] as String,
      body: row['body'] as String,
      deepLink: row['deep_link'] as String,
      status: row['status'] as String,
    );
  }

  final String id;
  final String? packId;
  final String fireAt;
  final String title;
  final String body;
  final String deepLink;

  /// One of [notificationStatuses] (validated when written through the
  /// CRUD helpers below).
  final String status;
}

/// An `intentions` row. `kind` is one of [intentionKinds] (validated when
/// written through the CRUD helpers below).
class IntentionRow {
  const IntentionRow({
    required this.id,
    required this.kind,
    required this.text,
    required this.createdAt,
  });

  factory IntentionRow.fromRow(Map<String, Object?> row) {
    return IntentionRow(
      id: row['id'] as String,
      kind: row['kind'] as String,
      text: row['text'] as String,
      createdAt: row['created_at'] as String,
    );
  }

  final String id;
  final String kind;
  final String text;
  final String createdAt;
}

/// Opens the runtime devotionals database file (the default open used by
/// `DevotionalsDatabase.instance`).
///
/// sqflite's onCreate runs the pinned DDL + version stamp; onUpgrade
/// delegates to the migration service's upgrade chain, which fails loudly
/// on unknown versions. Tests inject their own factory instead and never
/// touch this resolution.
Future<Database> openDevotionalsDatabase() async {
  final String databasesPath = await getDatabasesPath();
  final String dbPath = path.join(
    databasesPath,
    DevotionalsDatabase.databaseName,
  );
  final Database db = await openDatabase(
    dbPath,
    version: devotionalsSchemaVersion,
    onCreate: (Database db, int version) async {
      await DatabaseMigrationService.createAllTables(db);
      await DatabaseMigrationService.stampSchemaVersion(db);
    },
    onUpgrade: (Database db, int oldVersion, int newVersion) async {
      await DatabaseMigrationService.migrate(
        db,
        from: oldVersion,
        to: newVersion,
      );
    },
  );
  return db;
}

/// SQLite store with per-table CRUD helpers for the devotionals app.
///
/// The singleton [instance] opens the real file-backed database; tests
/// construct their own wrapper with an injected `open` factory (typically a
/// `sqflite_common_ffi` in-memory database), which is why the factory is the
/// constructor's only seam. Every write validates the table's value set
/// (`status`/`kind`) before touching the database, since the pinned DDL has
/// no CHECK constraints; upserts replace on the primary key rather than
/// throwing on duplicates.
class DevotionalsDatabase {
  static const String databaseName = 'devotionals.db';

  static DevotionalsDatabase? _instance;

  /// The app-wide wrapper, backed by [openDevotionalsDatabase]. Tests use
  /// their own injected instances instead of this singleton.
  static DevotionalsDatabase get instance {
    _instance ??= DevotionalsDatabase();
    return _instance!;
  }

  final Future<Database> Function() _openDatabase;

  Database? _database;

  /// [open] overrides how the backing database handle is produced. Defaults
  /// to the runtime file-backed resolution.
  DevotionalsDatabase({Future<Database> Function()? open})
    : _openDatabase = open ?? openDevotionalsDatabase;

  /// Opens (once per wrapper) and returns the backing database.
  ///
  /// After opening, the schema is verified/stamped idempotently via
  /// `DatabaseMigrationService.ensureSchema` — the heal layer for stores
  /// created outside this version-stamp scheme.
  Future<Database> open() async {
    final Database? existing = _database;
    if (existing != null && existing.isOpen) {
      return existing;
    }
    final Database db = await _openDatabase();
    await DatabaseMigrationService.ensureSchema(db);
    _database = db;
    return db;
  }

  /// Closes the backing database (no-op when never opened) so the wrapper
  /// can reopen afterwards.
  Future<void> close() async {
    final Database? db = _database;
    _database = null;
    if (db != null && db.isOpen) {
      await db.close();
    }
  }

  // ---------------------------------------------------------------------------
  // packs

  /// Inserts or replaces a `packs` row (upsert on `packs.id`).
  Future<void> upsertPack({
    required String id,
    required String json,
    required String packVersion,
    required String embeddedAt,
  }) async {
    final Database db = await open();
    await db.insert('packs', <String, Object?>{
      'id': id,
      'json': json,
      'pack_version': packVersion,
      'embedded_at': embeddedAt,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Reads one `packs` row by id, or `null` when absent.
  Future<PackRow?> getPack(String id) async {
    final Database db = await open();
    final List<Map<String, Object?>> rows = await db.query(
      'packs',
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
    return rows.isEmpty ? null : PackRow.fromRow(rows.first);
  }

  /// Reads every `packs` row ordered by id.
  Future<List<PackRow>> getAllPacks() async {
    final Database db = await open();
    final List<Map<String, Object?>> rows = await db.query(
      'packs',
      orderBy: 'id ASC',
    );
    return <PackRow>[
      for (final Map<String, Object?> row in rows) PackRow.fromRow(row),
    ];
  }

  /// Deletes one `packs` row; returns whether one was removed.
  Future<bool> deletePack(String id) async {
    final Database db = await open();
    final int deleted = await db.delete(
      'packs',
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
    return deleted > 0;
  }

  // ---------------------------------------------------------------------------
  // enrollments

  /// Inserts or replaces an `enrollments` row (upsert on `enrollments.pack_id`).
  Future<void> upsertEnrollment({
    required String packId,
    required String paramsJson,
    required String enrolledAt,
  }) async {
    final Database db = await open();
    await db.insert('enrollments', <String, Object?>{
      'pack_id': packId,
      'params_json': paramsJson,
      'enrolled_at': enrolledAt,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Reads one `enrollments` row by pack id, or `null` when absent.
  Future<EnrollmentRow?> getEnrollment(String packId) async {
    final Database db = await open();
    final List<Map<String, Object?>> rows = await db.query(
      'enrollments',
      where: 'pack_id = ?',
      whereArgs: <Object?>[packId],
    );
    return rows.isEmpty ? null : EnrollmentRow.fromRow(rows.first);
  }

  /// Reads every `enrollments` row ordered by enrollment time.
  Future<List<EnrollmentRow>> getAllEnrollments() async {
    final Database db = await open();
    final List<Map<String, Object?>> rows = await db.query(
      'enrollments',
      orderBy: 'enrolled_at ASC',
    );
    return <EnrollmentRow>[
      for (final Map<String, Object?> row in rows) EnrollmentRow.fromRow(row),
    ];
  }

  /// Deletes one `enrollments` row; returns whether one was removed.
  Future<bool> deleteEnrollment(String packId) async {
    final Database db = await open();
    final int deleted = await db.delete(
      'enrollments',
      where: 'pack_id = ?',
      whereArgs: <Object?>[packId],
    );
    return deleted > 0;
  }

  // ---------------------------------------------------------------------------
  // progress

  /// Inserts or replaces a `progress` row (upsert on `progress.pack_id`).
  Future<void> saveProgress({
    required String packId,
    required String stateJson,
    required String updatedAt,
  }) async {
    final Database db = await open();
    await db.insert('progress', <String, Object?>{
      'pack_id': packId,
      'state_json': stateJson,
      'updated_at': updatedAt,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Reads one `progress` row by pack id, or `null` when absent.
  Future<ProgressRow?> getProgress(String packId) async {
    final Database db = await open();
    final List<Map<String, Object?>> rows = await db.query(
      'progress',
      where: 'pack_id = ?',
      whereArgs: <Object?>[packId],
    );
    return rows.isEmpty ? null : ProgressRow.fromRow(rows.first);
  }

  /// Reads every `progress` row ordered by last update.
  Future<List<ProgressRow>> getAllProgress() async {
    final Database db = await open();
    final List<Map<String, Object?>> rows = await db.query(
      'progress',
      orderBy: 'updated_at ASC',
    );
    return <ProgressRow>[
      for (final Map<String, Object?> row in rows) ProgressRow.fromRow(row),
    ];
  }

  /// Deletes one `progress` row; returns whether one was removed.
  Future<bool> deleteProgress(String packId) async {
    final Database db = await open();
    final int deleted = await db.delete(
      'progress',
      where: 'pack_id = ?',
      whereArgs: <Object?>[packId],
    );
    return deleted > 0;
  }

  // ---------------------------------------------------------------------------
  // notification_index

  /// Inserts or replaces a `notification_index` row (upsert on
  /// `notification_index.id`). [status] must be in [notificationStatuses].
  Future<void> upsertNotification({
    required String id,
    required String fireAt,
    required String title,
    required String body,
    required String deepLink,
    required String status,
    String? packId,
  }) async {
    _requireValueSet(notificationStatuses, 'status', status);
    final Database db = await open();
    await db.insert('notification_index', <String, Object?>{
      'id': id,
      'pack_id': packId,
      'fire_at': fireAt,
      'title': title,
      'body': body,
      'deep_link': deepLink,
      'status': status,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Reads one `notification_index` row by id, or `null` when absent.
  Future<NotificationRow?> getNotification(String id) async {
    final Database db = await open();
    final List<Map<String, Object?>> rows = await db.query(
      'notification_index',
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
    return rows.isEmpty ? null : NotificationRow.fromRow(rows.first);
  }

  /// Reads every `notification_index` row for [packId], ordered by fire time.
  Future<List<NotificationRow>> getNotificationsForPack(String packId) async {
    final Database db = await open();
    final List<Map<String, Object?>> rows = await db.query(
      'notification_index',
      where: 'pack_id = ?',
      whereArgs: <Object?>[packId],
      orderBy: 'fire_at ASC',
    );
    return <NotificationRow>[
      for (final Map<String, Object?> row in rows) NotificationRow.fromRow(row),
    ];
  }

  /// Reads `scheduled` notifications whose `fire_at` is at or before
  /// [beforeIso] (ISO-8601 string compare), oldest fire time first.
  Future<List<NotificationRow>> notificationsDue({
    required String beforeIso,
  }) async {
    final Database db = await open();
    final List<Map<String, Object?>> rows = await db.query(
      'notification_index',
      where: "status = 'scheduled' AND fire_at <= ?",
      whereArgs: <Object?>[beforeIso],
      orderBy: 'fire_at ASC',
    );
    return <NotificationRow>[
      for (final Map<String, Object?> row in rows) NotificationRow.fromRow(row),
    ];
  }

  /// Updates a notification's `status` (must be in [notificationStatuses]);
  /// returns whether a row matched.
  Future<bool> setNotificationStatus({
    required String id,
    required String status,
  }) async {
    _requireValueSet(notificationStatuses, 'status', status);
    final Database db = await open();
    final int updated = await db.update(
      'notification_index',
      <String, Object?>{'status': status},
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
    return updated > 0;
  }

  /// Deletes one `notification_index` row; returns whether one was removed.
  Future<bool> deleteNotification(String id) async {
    final Database db = await open();
    final int deleted = await db.delete(
      'notification_index',
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
    return deleted > 0;
  }

  /// Deletes every `notification_index` row for [packId]; returns how many
  /// rows were removed.
  Future<int> deleteNotificationsForPack(String packId) async {
    final Database db = await open();
    return db.delete(
      'notification_index',
      where: 'pack_id = ?',
      whereArgs: <Object?>[packId],
    );
  }

  // ---------------------------------------------------------------------------
  // intentions

  /// Inserts or replaces an `intentions` row (upsert on `intentions.id`).
  /// [kind] must be in [intentionKinds].
  Future<void> insertIntention({
    required String id,
    required String kind,
    required String text,
    required String createdAt,
  }) async {
    _requireValueSet(intentionKinds, 'kind', kind);
    final Database db = await open();
    await db.insert('intentions', <String, Object?>{
      'id': id,
      'kind': kind,
      'text': text,
      'created_at': createdAt,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Reads one `intentions` row by id, or `null` when absent.
  Future<IntentionRow?> getIntention(String id) async {
    final Database db = await open();
    final List<Map<String, Object?>> rows = await db.query(
      'intentions',
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
    return rows.isEmpty ? null : IntentionRow.fromRow(rows.first);
  }

  /// Reads `intentions` rows oldest-first, optionally filtered by [kind]
  /// (validated against [intentionKinds] when provided).
  Future<List<IntentionRow>> getAllIntentions({String? kind}) async {
    if (kind != null) {
      _requireValueSet(intentionKinds, 'kind', kind);
    }
    final Database db = await open();
    final List<Map<String, Object?>> rows = await db.query(
      'intentions',
      where: kind != null ? 'kind = ?' : null,
      whereArgs: kind != null ? <Object?>[kind] : null,
      orderBy: 'created_at ASC',
    );
    return <IntentionRow>[
      for (final Map<String, Object?> row in rows) IntentionRow.fromRow(row),
    ];
  }

  /// Deletes one `intentions` row; returns whether one was removed.
  Future<bool> deleteIntention(String id) async {
    final Database db = await open();
    final int deleted = await db.delete(
      'intentions',
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
    return deleted > 0;
  }

  // ---------------------------------------------------------------------------
  // meta

  /// Reads one `meta` value by key, or `null` when absent.
  Future<String?> getMeta(String key) async {
    final Database db = await open();
    final List<Map<String, Object?>> rows = await db.query(
      'meta',
      where: 'key = ?',
      whereArgs: <Object?>[key],
    );
    return rows.isEmpty ? null : rows.first['value'] as String?;
  }

  /// Writes one `meta` value (upsert on `meta.key`).
  Future<void> setMeta(String key, String value) async {
    final Database db = await open();
    await db.insert('meta', <String, Object?>{
      'key': key,
      'value': value,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Deletes one `meta` row; returns whether one was removed.
  Future<bool> deleteMeta(String key) async {
    final Database db = await open();
    final int deleted = await db.delete(
      'meta',
      where: 'key = ?',
      whereArgs: <Object?>[key],
    );
    return deleted > 0;
  }

  /// Convenience over the [DatabaseMigrationService.schemaVersionMetaKey]
  /// stamp: the store's schema version, or `null` when unstamped.
  Future<int?> schemaVersion() async {
    final Database db = await open();
    return DatabaseMigrationService.readSchemaVersion(db);
  }
}
