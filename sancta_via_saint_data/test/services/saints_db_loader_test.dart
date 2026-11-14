// Saints DB loader tests (Task 7).
//
// Covers the version-stamp asset cache (mirroring the hardened
// sqlite-bible-loader pattern, re-implemented locally because cross-package
// imports are forbidden), the pure `needsAssetRecopy` version comparison,
// and the full `openSaintsDatabase` flow against the real committed
// `assets/saints.db` served by the Flutter test asset bundle.
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:saint_data/src/db/saints_schema.dart';
import 'package:saint_data/src/services/saints_db_loader.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Reads the committed asset bytes; used as the injected asset loader so
/// the stamp/refresh tests run without the Flutter asset channel.
final SaintsAssetBytesLoader _loadCommittedAsset = (String assetPath) =>
    File('${Directory.current.path}/assets/saints.db').readAsBytes();

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  // Needed so openSaintsDatabase's default rootBundle asset loader works.
  TestWidgetsFlutterBinding.ensureInitialized();

  group('computeAssetStamp', () {
    test('produces the v1:<length>:<fnv1a-32> format deterministically', () {
      final Uint8List bytes = Uint8List.fromList(<int>[1, 2, 3, 4, 5]);
      final String stamp = computeAssetStamp(bytes);
      expect(stamp, matches(RegExp(r'^v1:[0-9]+:[0-9a-f]{8}$')));
      expect(
        stamp,
        computeAssetStamp(Uint8List.fromList(<int>[1, 2, 3, 4, 5])),
      );
    });

    test('distinguishes different byte lengths', () {
      final Uint8List short = Uint8List.fromList(<int>[1, 2, 3, 4, 5]);
      final Uint8List long = Uint8List.fromList(<int>[1, 2, 3, 4, 5, 6]);
      expect(computeAssetStamp(short), isNot(computeAssetStamp(long)));
    });

    test('distinguishes content changes at the middle and the tail', () {
      final Uint8List original = Uint8List.fromList(
        List<int>.generate(50, (int i) => i),
      );
      final Uint8List middleChanged = Uint8List.fromList(
        List<int>.generate(50, (int i) => i),
      );
      middleChanged[25] = middleChanged[25] + 1;
      final Uint8List tailChanged = Uint8List.fromList(
        List<int>.generate(50, (int i) => i),
      );
      tailChanged[49] = tailChanged[49] + 1;
      final String originalStamp = computeAssetStamp(original);
      expect(computeAssetStamp(middleChanged), isNot(originalStamp));
      expect(computeAssetStamp(tailChanged), isNot(originalStamp));
    });
  });

  group('refreshSaintsDatabaseAsset (stamp + user_version refresh)', () {
    late Directory tempDir;
    late String dbPath;
    late Uint8List assetBytes;

    setUpAll(() async {
      assetBytes = await _loadCommittedAsset('assets/saints.db');
    });

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('saints_loader_test_');
      dbPath = '${tempDir.path}/saints.db';
    });

    tearDown(() async {
      await tempDir.delete(recursive: true);
    });

    Future<String> dbPathOf() async => dbPath;

    test(
      'copies the bundled asset when the database file is missing',
      () async {
        final String unusedPath = await dbPathOf();
        expect(File(unusedPath).existsSync(), isFalse);

        await refreshSaintsDatabaseAsset(
          dbPath: dbPath,
          databaseAssetPath: 'assets/saints.db',
          assetLoader: _loadCommittedAsset,
        );

        expect(File(dbPath).existsSync(), isTrue);
        expect(await File(dbPath).readAsBytes(), assetBytes);
        expect(
          File('$dbPath.stamp').existsSync(),
          isTrue,
          reason: 'the sidecar stamp must be written beside the database',
        );
        expect(
          await File('$dbPath.stamp').readAsString(),
          computeAssetStamp(assetBytes),
        );
      },
    );

    test('does not re-copy when the stored stamp matches the asset', () async {
      await refreshSaintsDatabaseAsset(
        dbPath: dbPath,
        databaseAssetPath: 'assets/saints.db',
        assetLoader: _loadCommittedAsset,
      );
      // Simulate a drifted on-disk copy that stays a VALID database at the
      // current schema version (garbage bytes would be healed by the
      // user_version belt instead — see the unreadable-file test). With
      // the stamp still matching, the stamp layer trusts the copy and
      // leaves it alone.
      final Database drifted = await openDatabase(
        dbPath,
        singleInstance: false,
      );
      await drifted.execute('CREATE TABLE _drift_marker (id INTEGER)');
      await drifted.close();

      await refreshSaintsDatabaseAsset(
        dbPath: dbPath,
        databaseAssetPath: 'assets/saints.db',
        assetLoader: _loadCommittedAsset,
      );

      final Database after = await openDatabase(dbPath, singleInstance: false);
      final List<Map<String, Object?>> markers = await after.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'table' "
        "AND name = '_drift_marker'",
      );
      expect(
        markers,
        isNotEmpty,
        reason:
            'a matching stamp must not trigger a re-copy (the drift '
            'marker would have vanished)',
      );
      await after.close();
    });

    test('re-copies when the stored stamp is missing', () async {
      await refreshSaintsDatabaseAsset(
        dbPath: dbPath,
        databaseAssetPath: 'assets/saints.db',
        assetLoader: _loadCommittedAsset,
      );
      await File('$dbPath.stamp').delete();
      // A prior-build copy without a stamp must be refreshed even though
      // the bytes happen to be byte-identical.
      await File(dbPath).writeAsBytes(<int>[1, 2, 3]);

      await refreshSaintsDatabaseAsset(
        dbPath: dbPath,
        databaseAssetPath: 'assets/saints.db',
        assetLoader: _loadCommittedAsset,
      );

      expect(await File(dbPath).readAsBytes(), assetBytes);
    });

    test('re-copies when the stored stamp mismatches the asset', () async {
      await refreshSaintsDatabaseAsset(
        dbPath: dbPath,
        databaseAssetPath: 'assets/saints.db',
        assetLoader: _loadCommittedAsset,
      );
      await File('$dbPath.stamp').writeAsString('v1:0:deadbeef');
      await File(dbPath).writeAsBytes(<int>[1, 2, 3]);

      await refreshSaintsDatabaseAsset(
        dbPath: dbPath,
        databaseAssetPath: 'assets/saints.db',
        assetLoader: _loadCommittedAsset,
      );

      expect(await File(dbPath).readAsBytes(), assetBytes);
      expect(
        await File('$dbPath.stamp').readAsString(),
        computeAssetStamp(assetBytes),
      );
    });

    test(
      're-copies when the disk user_version is older than bundled',
      () async {
        // A valid-but-empty sqlite file whose sidecar stamp (wrongly) matches.
        // The stamp layer cannot catch this; the user_version belt must.
        final Database emptyDb = await openDatabase(
          dbPath,
          singleInstance: false,
        );
        await emptyDb.close();
        await File(
          '$dbPath.stamp',
        ).writeAsString(computeAssetStamp(assetBytes));

        await refreshSaintsDatabaseAsset(
          dbPath: dbPath,
          databaseAssetPath: 'assets/saints.db',
          assetLoader: _loadCommittedAsset,
        );

        expect(await File(dbPath).readAsBytes(), assetBytes);
      },
    );

    test('re-copies when the disk file is unreadable', () async {
      await File(
        dbPath,
      ).writeAsBytes(List<int>.generate(5000, (int i) => i % 251));
      await File('$dbPath.stamp').writeAsString(computeAssetStamp(assetBytes));

      await refreshSaintsDatabaseAsset(
        dbPath: dbPath,
        databaseAssetPath: 'assets/saints.db',
        assetLoader: _loadCommittedAsset,
      );

      expect(await File(dbPath).readAsBytes(), assetBytes);
      // The healed copy must be a real database again.
      final Database healed = await openDatabase(dbPath, singleInstance: false);
      final List<Map<String, Object?>> tables = await healed.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'saints'",
      );
      expect(tables, isNotEmpty);
      await healed.close();
    });

    test('swallows asset load failures and copies nothing', () async {
      Future<Uint8List> failingLoader(String assetPath) async {
        throw StateError('bundled asset unavailable');
      }

      await refreshSaintsDatabaseAsset(
        dbPath: dbPath,
        databaseAssetPath: 'assets/saints.db',
        assetLoader: failingLoader,
      );

      expect(File(dbPath).existsSync(), isFalse);
      expect(File('$dbPath.stamp').existsSync(), isFalse);
    });
  });

  group('openSaintsDatabase (real asset through rootBundle)', () {
    final List<Database> opened = <Database>[];
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('saints_open_test_');
      await databaseFactory.setDatabasesPath(tempDir.path);
    });

    tearDown(() async {
      for (final Database database in opened) {
        if (database.isOpen) {
          await database.close();
        }
      }
      opened.clear();
      await tempDir.delete(recursive: true);
    });

    test(
      'copies the asset, opens writable, and exposes the committed data',
      () async {
        final Database db = await openSaintsDatabase();
        opened.add(db);
        dbPathExists(tempDir);

        final List<Map<String, Object?>> version = await db.rawQuery(
          'PRAGMA user_version',
        );
        // The committed asset must ship the CURRENT schema (v2, saint
        // histories) so the loader's belt layer never needs to heal it.
        expect(version.single['user_version'], saintsSchemaVersion);
        expect(saintsSchemaVersion, 2);
        final List<Map<String, Object?>> counts = await db.rawQuery(
          'SELECT COUNT(*) AS n FROM saints',
        );
        expect(counts.single['n'], 2174);

        // Pinned surface: opens WRITABLE (sqlite needs metadata writes).
        await db.execute('CREATE TABLE _writability_probe (id INTEGER)');
        await db.execute('DROP TABLE _writability_probe');
      },
    );

    test(
      're-copies from the asset when the sidecar stamp disappears',
      () async {
        final Database first = await openSaintsDatabase();
        opened.add(first);
        await first.close();
        final String stampPath = '${tempDir.path}/saints.db.stamp';
        File(stampPath).deleteSync();

        // A prior build copied the database without writing a stamp: the next
        // open must refresh and restore the stamp.
        final Database second = await openSaintsDatabase();
        opened.add(second);
        expect(File(stampPath).existsSync(), isTrue);
        final List<Map<String, Object?>> counts = await second.rawQuery(
          'SELECT COUNT(*) AS n FROM saints',
        );
        expect(counts.single['n'], 2174);
      },
    );

    test(
      'rethrows instead of opening an empty store when the asset is missing',
      () async {
        // Final-review ruling: an empty saints store is worse than the
        // properly propagated error state. When the bundled asset cannot be
        // copied (here: an asset path that resolves nowhere), the onCreate
        // fallback must be LOUD — log the missing asset and rethrow, never
        // hand back a schema-only empty database.
        await expectLater(
          openSaintsDatabase(databaseAssetPath: 'assets/no-such-saints.db'),
          throwsA(anything),
          reason:
              'a missing saints asset must surface as a load failure, not '
              'as a silently empty saints store',
        );
      },
    );
  });
}

/// Asserts the database and its stamp sidecar landed in [tempDir].
void dbPathExists(Directory tempDir) {
  expect(File('${tempDir.path}/saints.db').existsSync(), isTrue);
  expect(File('${tempDir.path}/saints.db.stamp').existsSync(), isTrue);
}
