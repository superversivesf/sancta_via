// SQLite database tests for the devotionals app (Task 4).
//
// These run against in-memory databases via `sqflite_common_ffi` (the
// `DevotionalsDatabase` open-factory seam) and pin:
// - the six-table DDL contract (exact tables/columns),
// - a round trip of one row per table,
// - the `meta.schema_version = 1` stamp on first open plus the heal/upgrade
//   stub behavior of `DatabaseMigrationService`,
// - the value-set validation on write (status/kind → ArgumentError),
// - the default production open (`openDevotionalsDatabase`: sqflite
//   onCreate/onUpgrade wiring) against a temp databases path, including a
//   close→reopen that must not re-create, re-stamp, or conflict.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sancta_via_devotionals/database/database_migration_service.dart';
import 'package:sancta_via_devotionals/database/devotionals_database.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Opens a fresh, isolated in-memory database backed by the FFI factory.
Future<Database> _openInMemory() {
  return openDatabase(inMemoryDatabasePath, singleInstance: false);
}

/// Opens a wrapper whose backing store is a fresh in-memory database.
DevotionalsDatabase _inMemoryWrapper() {
  return DevotionalsDatabase(open: _openInMemory);
}

const Map<String, List<String>> _pinnedColumns = <String, List<String>>{
  'packs': <String>['id', 'json', 'pack_version', 'embedded_at'],
  'enrollments': <String>['pack_id', 'params_json', 'enrolled_at'],
  'progress': <String>['pack_id', 'state_json', 'updated_at'],
  'notification_index': <String>[
    'id',
    'pack_id',
    'fire_at',
    'title',
    'body',
    'deep_link',
    'status',
  ],
  'intentions': <String>['id', 'kind', 'text', 'created_at'],
  'meta': <String>['key', 'value'],
};

void main() {
  group('schema creation', () {
    test('creates all six pinned tables with the exact columns', () async {
      final DevotionalsDatabase wrapper = _inMemoryWrapper();

      final Database db = await wrapper.open();

      for (final MapEntry<String, List<String>> pinned
          in _pinnedColumns.entries) {
        final List<Map<String, Object?>> columns = await db.rawQuery(
          'PRAGMA table_info(${pinned.key})',
        );
        expect(
          <String>[
            for (final Map<String, Object?> c in columns) c['name']! as String,
          ],
          pinned.value,
          reason: 'Table ${pinned.key} must match the pinned DDL',
        );
      }

      expect(devotionalsSchemaVersion, 1);
      await wrapper.close();
    });

    test('creates no tables beyond the six pinned ones', () async {
      final DevotionalsDatabase wrapper = _inMemoryWrapper();

      final Database db = await wrapper.open();
      final List<Map<String, Object?>> tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'table' "
        "AND name NOT LIKE 'sqlite_%'",
      );
      expect(
        <String>[
          for (final Map<String, Object?> t in tables) t['name']! as String,
        ]..sort(),
        _pinnedColumns.keys.toList()..sort(),
      );

      await wrapper.close();
    });
  });

  group('round trips (one row per table)', () {
    test('pack row round trips through the json column', () async {
      final DevotionalsDatabase wrapper = _inMemoryWrapper();
      await wrapper.open();

      await wrapper.upsertPack(
        id: 'lumen-christi',
        json: '{"id":"lumen-christi","pack_version":"1.0.0"}',
        packVersion: '1.0.0',
        embeddedAt: '2026-11-11T00:00:00Z',
      );

      final PackRow? row = await wrapper.getPack('lumen-christi');
      expect(row, isNotNull);
      expect(row!.id, 'lumen-christi');
      expect(row.json, '{"id":"lumen-christi","pack_version":"1.0.0"}');
      expect(row.packVersion, '1.0.0');
      expect(row.embeddedAt, '2026-11-11T00:00:00Z');

      final List<PackRow> all = await wrapper.getAllPacks();
      expect(all, hasLength(1));

      // Upsert replaces on the same id rather than duplicating.
      await wrapper.upsertPack(
        id: 'lumen-christi',
        json: '{"id":"lumen-christi","pack_version":"1.1.0"}',
        packVersion: '1.1.0',
        embeddedAt: '2026-11-12T00:00:00Z',
      );
      expect(await wrapper.getPack('lumen-christi'), isNotNull);
      expect((await wrapper.getPack('lumen-christi'))!.packVersion, '1.1.0');
      expect(await wrapper.getAllPacks(), hasLength(1));

      await wrapper.deletePack('lumen-christi');
      expect(await wrapper.getPack('lumen-christi'), isNull);
      await wrapper.close();
    });

    test('enrollment row round trips through params_json', () async {
      final DevotionalsDatabase wrapper = _inMemoryWrapper();
      await wrapper.open();

      await wrapper.upsertEnrollment(
        packId: 'nine-days',
        paramsJson: '{"target":"guardian-angel"}',
        enrolledAt: '2026-11-11T08:00:00Z',
      );

      final EnrollmentRow? row = await wrapper.getEnrollment('nine-days');
      expect(row!.packId, 'nine-days');
      expect(row.paramsJson, '{"target":"guardian-angel"}');
      expect(row.enrolledAt, '2026-11-11T08:00:00Z');

      await wrapper.deleteEnrollment('nine-days');
      expect(await wrapper.getEnrollment('nine-days'), isNull);
      await wrapper.close();
    });

    test('progress row round trips through state_json', () async {
      final DevotionalsDatabase wrapper = _inMemoryWrapper();
      await wrapper.open();

      await wrapper.saveProgress(
        packId: 'nine-days',
        stateJson: '{"completions":{"2026-11-10":true}}',
        updatedAt: '2026-11-10T21:00:00Z',
      );

      final ProgressRow? row = await wrapper.getProgress('nine-days');
      expect(row!.packId, 'nine-days');
      expect(row.stateJson, '{"completions":{"2026-11-10":true}}');
      expect(row.updatedAt, '2026-11-10T21:00:00Z');

      await wrapper.deleteProgress('nine-days');
      expect(await wrapper.getProgress('nine-days'), isNull);
      await wrapper.close();
    });

    test('notification row round trips and validates status', () async {
      final DevotionalsDatabase wrapper = _inMemoryWrapper();
      await wrapper.open();

      await wrapper.upsertNotification(
        id: 'n1',
        packId: 'nine-days',
        fireAt: '2026-11-12T06:30:00Z',
        title: 'Today',
        body: 'Day 3 is ready',
        deepLink: '/today',
        status: 'scheduled',
      );
      // The nullable pack_id column must round trip as null.
      await wrapper.upsertNotification(
        id: 'n2',
        fireAt: '2026-11-12T18:00:00Z',
        title: 'Angelus',
        body: 'Noon anchor',
        deepLink: '/anchors/noon',
        status: 'scheduled',
      );

      expect((await wrapper.getNotification('n1'))!.status, 'scheduled');
      expect(await wrapper.getNotification('n2'), isNotNull);
      expect((await wrapper.getNotification('n2'))!.packId, isNull);

      final List<NotificationRow> forPack = await wrapper
          .getNotificationsForPack('nine-days');
      expect(forPack, hasLength(1));

      // Due filter: scheduled + fire_at <= the cutoff, ordered by fire_at.
      final List<NotificationRow> due = await wrapper.notificationsDue(
        beforeIso: '2026-11-12T23:59:59Z',
      );
      expect(
        <String>[for (final NotificationRow n in due) n.id],
        <String>['n1', 'n2'],
      );

      // A fired notification leaves the due set.
      await wrapper.setNotificationStatus(id: 'n1', status: 'fired');
      expect((await wrapper.getNotification('n1'))!.status, 'fired');
      expect(
        <String>[
          for (final NotificationRow n in await wrapper.notificationsDue(
            beforeIso: '2026-11-12T23:59:59Z',
          ))
            n.id,
        ],
        <String>['n2'],
      );

      await wrapper.deleteNotification('n1');
      expect(await wrapper.getNotification('n1'), isNull);

      // Value-set validation on write, for upserts and status updates.
      expect(
        () => wrapper.upsertNotification(
          id: 'n3',
          fireAt: '2026-11-12T00:00:00Z',
          title: 'x',
          body: 'y',
          deepLink: '/z',
          status: 'expired',
        ),
        throwsArgumentError,
      );
      expect(
        () => wrapper.setNotificationStatus(id: 'n1', status: 'expired'),
        throwsArgumentError,
      );
      await wrapper.close();
    });

    test('intention row round trips with kind validation', () async {
      final DevotionalsDatabase wrapper = _inMemoryWrapper();
      await wrapper.open();

      await wrapper.insertIntention(
        id: 'i1',
        kind: 'intention',
        text: 'For my godson',
        createdAt: '2026-11-11T09:00:00Z',
      );
      await wrapper.insertIntention(
        id: 'i2',
        kind: 'soul',
        text: 'For a soul in purgatory',
        createdAt: '2026-11-11T09:05:00Z',
      );

      final IntentionRow? row = await wrapper.getIntention('i2');
      expect(row!.kind, 'soul');
      expect(row.text, 'For a soul in purgatory');

      expect((await wrapper.getAllIntentions()), hasLength(2));
      expect(
        <String>[
          for (final IntentionRow i in await wrapper.getAllIntentions(
            kind: 'soul',
          ))
            i.id,
        ],
        <String>['i2'],
      );

      await wrapper.deleteIntention('i1');
      expect(await wrapper.getIntention('i1'), isNull);

      expect(
        () => wrapper.insertIntention(
          id: 'i3',
          kind: 'petition',
          text: 'bad kind',
          createdAt: '2026-11-11T09:06:00Z',
        ),
        throwsArgumentError,
      );
      expect(
        () => wrapper.getAllIntentions(kind: 'petition'),
        throwsArgumentError,
      );
      await wrapper.close();
    });
  });

  group('meta CRUD and version stamping', () {
    test('schema_version is stamped to 1 on first open', () async {
      final DevotionalsDatabase wrapper = _inMemoryWrapper();
      await wrapper.open();

      expect(await wrapper.getMeta('schema_version'), '1');
      expect(await wrapper.schemaVersion(), 1);

      await wrapper.close();
    });

    test('content_version round trips via generic meta helpers', () async {
      final DevotionalsDatabase wrapper = _inMemoryWrapper();
      await wrapper.open();

      expect(await wrapper.getMeta('content_version'), isNull);
      await wrapper.setMeta('content_version', '42');
      expect(await wrapper.getMeta('content_version'), '42');
      await wrapper.deleteMeta('content_version');
      expect(await wrapper.getMeta('content_version'), isNull);

      await wrapper.close();
    });

    test(
      'ensureSchema stamps a healable missing version and is idempotent',
      () async {
        final Database db = await _openInMemory();
        await DatabaseMigrationService.createAllTables(db);
        // Schema present but the stamp row wiped: must be healed.
        await DatabaseMigrationService.stampSchemaVersion(db);
        await db.delete(
          'meta',
          where: 'key = ?',
          whereArgs: <Object?>[DatabaseMigrationService.schemaVersionMetaKey],
        );

        await DatabaseMigrationService.ensureSchema(db);
        expect(await DatabaseMigrationService.readSchemaVersion(db), 1);

        // Idempotent: re-running on a stamped schema preserves data.
        await db.insert('packs', <String, Object?>{
          'id': 'p1',
          'json': '{}',
          'pack_version': '1.0.0',
          'embedded_at': '2026-11-11T00:00:00Z',
        });
        await DatabaseMigrationService.ensureSchema(db);
        expect(await db.query('packs'), hasLength(1));
        expect(await DatabaseMigrationService.readSchemaVersion(db), 1);

        await db.close();
      },
    );

    test('readSchemaVersion is null before the schema exists', () async {
      final Database db = await _openInMemory();
      expect(await DatabaseMigrationService.readSchemaVersion(db), isNull);
      await db.close();
    });

    test('a newer stored schema version fails loudly (no downgrade)', () async {
      final Database db = await _openInMemory();
      await DatabaseMigrationService.createAllTables(db);
      await DatabaseMigrationService.stampSchemaVersion(db, version: 2);

      await expectLater(
        DatabaseMigrationService.ensureSchema(db),
        throwsStateError,
      );
      await db.close();
    });

    test('the upgrade stub throws loudly on unknown versions', () async {
      final Database db = await _openInMemory();
      await DatabaseMigrationService.createAllTables(db);
      // Version 9 has no defined migration path: bump loudly, fail loudly.
      await expectLater(
        DatabaseMigrationService.migrate(db, from: 1, to: 9),
        throwsStateError,
      );
      // Same version is a no-op.
      await DatabaseMigrationService.migrate(db, from: 1, to: 1);
      await db.close();
    });

    test('a corrupt stamp value fails loudly', () async {
      final Database db = await _openInMemory();
      await DatabaseMigrationService.createAllTables(db);
      await db.insert('meta', <String, Object?>{
        'key': DatabaseMigrationService.schemaVersionMetaKey,
        'value': 'not-a-number',
      });
      await expectLater(
        DatabaseMigrationService.readSchemaVersion(db),
        throwsStateError,
      );
      await db.close();
    });

    test('a partially created schema fails loudly', () async {
      final Database db = await _openInMemory();
      // Exactly one table of the six: neither fresh nor complete.
      await db.execute(
        'CREATE TABLE meta (key TEXT PRIMARY KEY, value TEXT NOT NULL)',
      );
      await expectLater(
        DatabaseMigrationService.ensureSchema(db),
        throwsStateError,
      );
      await db.close();
    });
  });

  group('singleton and default path resolution', () {
    test('instance returns the same wrapper every time', () {
      expect(
        identical(DevotionalsDatabase.instance, DevotionalsDatabase.instance),
        isTrue,
      );
    });

    test('default open targets the pinned database file name', () async {
      expect(DevotionalsDatabase.databaseName, 'devotionals.db');
      // The injected factory is honored over the default path resolution.
      final DevotionalsDatabase wrapper = _inMemoryWrapper();
      final Database db = await wrapper.open();
      expect(await DatabaseMigrationService.readSchemaVersion(db), 1);
      await wrapper.close();
    });
  });

  group('pinned DDL contract surface', () {
    test('the exported DDL list matches the brief statement-for-statement', () {
      expect(devotionalsTableDdl, hasLength(6));
      expect(devotionalsTableDdl, <String>[
        'CREATE TABLE packs (id TEXT PRIMARY KEY, json TEXT NOT NULL, '
            'pack_version TEXT NOT NULL, embedded_at TEXT NOT NULL)',
        'CREATE TABLE enrollments (pack_id TEXT PRIMARY KEY, '
            'params_json TEXT NOT NULL, enrolled_at TEXT NOT NULL)',
        'CREATE TABLE progress (pack_id TEXT PRIMARY KEY, '
            'state_json TEXT NOT NULL, updated_at TEXT NOT NULL)',
        'CREATE TABLE notification_index (id TEXT PRIMARY KEY, '
            'pack_id TEXT, fire_at TEXT NOT NULL, title TEXT NOT NULL, '
            'body TEXT NOT NULL, deep_link TEXT NOT NULL, '
            'status TEXT NOT NULL)',
        'CREATE TABLE intentions (id TEXT PRIMARY KEY, kind TEXT NOT NULL, '
            'text TEXT NOT NULL, created_at TEXT NOT NULL)',
        'CREATE TABLE meta (key TEXT PRIMARY KEY, value TEXT NOT NULL)',
      ]);
    });

    test('value sets match the brief exactly', () {
      expect(notificationStatuses, <String>{'scheduled', 'fired', 'cancelled'});
      expect(intentionKinds, <String>{'intention', 'soul'});
    });
  });

  group('default production open (sqflite onCreate/onUpgrade wiring)', () {
    // The real default open resolves `getDatabasesPath()` + `'devotionals.db'`
    // through the global factory (FFI-initialized in flutter_test_config).
    // Pointing the factory at a temp directory makes that file-backed path
    // hermetic; the other groups in this file use in-memory databases, which
    // bypass the databases path entirely, so this never leaks into them.
    late Directory databasesDir;
    late DevotionalsDatabase wrapper;

    setUpAll(() async {
      databasesDir = await Directory.systemTemp.createTemp('devotionals_ffi_');
      await databaseFactory.setDatabasesPath(databasesDir.path);
      wrapper = DevotionalsDatabase();
    });

    tearDownAll(() async {
      await wrapper.close();
      if (databasesDir.existsSync()) {
        await databasesDir.delete(recursive: true);
      }
    });

    test('first open stamps schema 1 over all six tables, and a close→reopen '
        'reuses the file without re-creation, re-stamping, or error', () async {
      // First open = the production path: sqflite onCreate runs the pinned
      // DDL + version stamp; wrapper.open() then re-verifies via
      // ensureSchema (idempotent here).
      final Database first = await wrapper.open();

      for (final String table in DatabaseMigrationService.schemaTables) {
        expect(
          await first.rawQuery('PRAGMA table_info($table)'),
          isNotEmpty,
          reason: 'Table $table must exist after the production onCreate',
        );
      }
      expect(await wrapper.getMeta('schema_version'), '1');
      // Fresh store: the version stamp is the only meta row.
      expect(await first.query('meta'), hasLength(1));

      // Seed a row to prove the reopen reuses (not recreates) the store.
      await wrapper.upsertPack(
        id: 'reopen-pack',
        json: '{}',
        packVersion: '1.0.0',
        embeddedAt: '2026-11-12T00:00:00Z',
      );
      await wrapper.close();

      // Second open of the same file through the same resolution:
      // onCreate must not re-run (a re-issued CREATE TABLE would fail
      // loudly), onUpgrade/from==1→to==1 is a no-op, the stamp is
      // unchanged, and no rows are duplicated.
      final Database second = await wrapper.open();

      expect(await DatabaseMigrationService.readSchemaVersion(second), 1);
      expect(await wrapper.getMeta('schema_version'), '1');
      expect(await second.query('meta'), hasLength(1));
      expect(await wrapper.getAllPacks(), hasLength(1));

      await wrapper.close();
    });
  });
}
