// Schema management for the devotionals SQLite store (Task 4).
//
// The six-table DDL below is the PINNED contract consumed by the program
// repository, content assets, substitution, credit, and missed-day layers
// (Tasks 5-9); the DDL is version-stamped in `meta.schema_version` so later
// schema changes can ship a real upgrade path. The database itself is
// runtime-created (empty at install, then populated from app assets by the
// content-pipeline task) — there is no asset-copy step here.
//
// Value sets (notification `status`, intention `kind`) are NOT enforced with
// SQL CHECK constraints — the pinned DDL is exactly as specified — so the
// CRUD helpers in `devotionals_database.dart` validate on write instead.
import 'package:sqflite/sqflite.dart';

/// Current schema version of the devotionals database. Bump this AND add the
/// matching entry to `DatabaseMigrationService._upgrades` with every schema
/// change; never downgrade an existing store (that fails loudly instead).
const int devotionalsSchemaVersion = 1;

/// The pinned table DDL, exactly as specified by the plan: six tables,
/// no CHECK constraints, no extra columns or indexes. Executed verbatim by
/// [DatabaseMigrationService.createAllTables].
const List<String> devotionalsTableDdl = <String>[
  'CREATE TABLE packs (id TEXT PRIMARY KEY, json TEXT NOT NULL, '
      'pack_version TEXT NOT NULL, embedded_at TEXT NOT NULL)',
  'CREATE TABLE enrollments (pack_id TEXT PRIMARY KEY, '
      'params_json TEXT NOT NULL, enrolled_at TEXT NOT NULL)',
  'CREATE TABLE progress (pack_id TEXT PRIMARY KEY, '
      'state_json TEXT NOT NULL, updated_at TEXT NOT NULL)',
  'CREATE TABLE notification_index (id TEXT PRIMARY KEY, '
      'pack_id TEXT, fire_at TEXT NOT NULL, title TEXT NOT NULL, '
      'body TEXT NOT NULL, deep_link TEXT NOT NULL, status TEXT NOT NULL)',
  'CREATE TABLE intentions (id TEXT PRIMARY KEY, kind TEXT NOT NULL, '
      'text TEXT NOT NULL, created_at TEXT NOT NULL)',
  'CREATE TABLE meta (key TEXT PRIMARY KEY, value TEXT NOT NULL)',
];

/// Schema management for the devotionals database: table creation, the
/// `meta.schema_version` stamp, and the upgrade path.
///
/// Every method takes the [Database] handle so the service can be exercised
/// against any store (the wrapper's injected in-memory open in tests, the
/// runtime file-backed open in the app).
class DatabaseMigrationService {
  /// `meta` key for the schema version stamp (`'schema_version'`).
  static const String schemaVersionMetaKey = 'schema_version';

  /// `meta` key for the bundled-content version (`'content_version'`), set by
  /// the content pipeline when app assets are embedded into `packs`.
  static const String contentVersionMetaKey = 'content_version';

  /// The six pinned tables this service owns.
  static const Set<String> schemaTables = <String>{
    'packs',
    'enrollments',
    'progress',
    'notification_index',
    'intentions',
    'meta',
  };

  /// Upgrade steps by source schema version: `_upgrades[n]` migrates a store
  /// stamped `n` to `n + 1`, where each entry is a raw SQL statement.
  ///
  /// Empty at version 1 (the first release, so every store is created fresh
  /// at the current version). The first schema change bumps
  /// [devotionalsSchemaVersion] to 2 and adds `_upgrades: {1: [...]}`; a
  /// store stamped at an unknown version fails loudly in [migrate] rather
  /// than opening against a mismatched schema.
  static const Map<int, List<String>> _upgrades = <int, List<String>>{};

  /// Runs all six pinned DDL statements against an open database.
  ///
  /// Only callsite for fresh stores ([ensureSchema]/onCreate); a schema that
  /// already has any pinned table is never re-created here (see
  /// [ensureSchema]'s loud partial-schema guard).
  static Future<void> createAllTables(Database db) async {
    for (final String statement in devotionalsTableDdl) {
      await db.execute(statement);
    }
  }

  /// Whether [name] exists as a table in the open database.
  static Future<bool> hasTable(Database db, String name) async {
    final List<Map<String, Object?>> rows = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name = ?",
      <Object?>[name],
    );
    return rows.isNotEmpty;
  }

  /// Reads the `meta.schema_version` stamp, or `null` when the store has no
  /// `meta` table yet or the stamp row is absent (an unstamped store).
  ///
  /// A `meta` row that does not parse as an integer is a corrupt stamp and
  /// fails loudly — never silently treated as unstamped.
  static Future<int?> readSchemaVersion(Database db) async {
    if (!await hasTable(db, 'meta')) {
      return null;
    }
    final List<Map<String, Object?>> rows = await db.query(
      'meta',
      where: 'key = ?',
      whereArgs: <Object?>[schemaVersionMetaKey],
    );
    if (rows.isEmpty) {
      return null;
    }
    final Object? value = rows.first['value'];
    final int? version = value is String
        ? int.tryParse(value)
        : (value is int ? value : null);
    if (version == null) {
      throw StateError(
        'Devotionals database: corrupt $schemaVersionMetaKey stamp '
        '(expected an integer, got: $value)',
      );
    }
    return version;
  }

  /// Writes the `meta.schema_version` stamp (upsert).
  static Future<void> stampSchemaVersion(
    Database db, {
    int version = devotionalsSchemaVersion,
  }) async {
    await db.insert('meta', <String, Object?>{
      'key': schemaVersionMetaKey,
      'value': version.toString(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Names of the pinned tables that already exist in [db].
  static Future<Set<String>> presentSchemaTables(Database db) async {
    final List<Map<String, Object?>> rows = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table' "
      "AND name NOT LIKE 'sqlite_%'",
    );
    return <String>{
      for (final Map<String, Object?> row in rows)
        if (schemaTables.contains(row['name'])) row['name']! as String,
    };
  }

  /// Brings an open database to [devotionalsSchemaVersion], idempotently.
  ///
  /// - No pinned tables yet → create all six and stamp the current version
  ///   (the fresh-store path, matching sqflite's own onCreate).
  /// - All tables present but the stamp missing → heal by stamping (a store
  ///   created outside this service, or a wiped meta row).
  /// - Stamped older → run the upgrade path ([migrate]).
  /// - Stamped newer → loud failure: this app build cannot know the newer
  ///   schema, and opening it would corrupt reads; never downgrade.
  /// - Partially created (some pinned tables, not all) → loud failure: the
  ///   store is neither fresh nor current and must not be guessed at.
  static Future<void> ensureSchema(Database db) async {
    final Set<String> present = await presentSchemaTables(db);
    if (present.isEmpty) {
      await createAllTables(db);
      await stampSchemaVersion(db);
      return;
    }
    if (present.length != schemaTables.length) {
      throw StateError(
        'Devotionals database: partially created schema '
        '(${present.length} of ${schemaTables.length} pinned tables: '
        '${present.toList()..sort()}); refusing to open',
      );
    }
    final int? version = await readSchemaVersion(db);
    if (version == null) {
      await stampSchemaVersion(db);
      return;
    }
    if (version > devotionalsSchemaVersion) {
      throw StateError(
        'Devotionals database: schema version $version is newer than this '
        'app build ($devotionalsSchemaVersion); refusing to open (a '
        'downgrade would corrupt data)',
      );
    }
    if (version < devotionalsSchemaVersion) {
      await migrate(db, from: version, to: devotionalsSchemaVersion);
    }
  }

  /// Migrates [db] from schema version [from] to [to] via the `_upgrades`
  /// chain, then re-stamps `meta.schema_version` at [to].
  ///
  /// Unknown versions fail loudly with the full chain in the message — the
  /// bump mechanism for later schema changes is an entry in `_upgrades`, not
  /// a silent pass-through. Same-version calls are a no-op; a request to
  /// move backwards fails loudly (downgrades are not supported).
  static Future<void> migrate(
    Database db, {
    required int from,
    required int to,
  }) async {
    if (from == to) {
      return;
    }
    if (from > to) {
      throw StateError(
        'Devotionals database: cannot migrate schema version $from down '
        'to $to; downgrades are not supported',
      );
    }
    int current = from;
    while (current < to) {
      final List<String>? statements = _upgrades[current];
      if (statements == null) {
        throw StateError(
          'Devotionals database: no upgrade path defined from schema '
          'version $from to $to (unknown version $current). Bump '
          '`devotionalsSchemaVersion` and add the `_upgrades[$current]` '
          'entry when intentionally changing the schema',
        );
      }
      for (final String statement in statements) {
        await db.execute(statement);
      }
      current++;
    }
    await stampSchemaVersion(db, version: to);
  }
}
