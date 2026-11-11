import 'dart:io';
import 'dart:typed_data';

import 'package:bible_data/bible_data.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:test/test.dart';

/// Cache-refresh regression tests for the SQLite loaders.
///
/// The loaders used to copy the bundled `bibles.db` only when the on-device
/// file was missing, so any device that ran a prior build kept serving the OLD
/// database forever. The refresh contract proven here:
///
/// 1. a cached database that does NOT match the bundled asset (missing or
///    outdated stamp sidecar) is re-copied from the bundle;
/// 2. the loader stores the stamp of the bundled asset after a copy;
/// 3. a matching stamp means the next open does NOT copy (no-op);
/// 4. the refreshed database (not the stale one) is the one being served.
///
/// Database copies live in a temporary databases directory so the shared
/// `.dart_tool/sqflite_common_ffi/databases` directory is never touched.
void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Directory databasesDir;
  late File dbFile;
  late File stampFile;
  late Uint8List freshBytes;
  late Uint8List staleBytes;

  /// Builds a minimal valid SQLite database with a single `translations` row
  /// for [translationId] and returns its bytes as the "bundled asset".
  Future<Uint8List> buildFakeAssetBytes(String translationId) async {
    final File seedFile = File('${databasesDir.path}/seed_$translationId.db');
    final Database db = await databaseFactoryFfi.openDatabase(
      seedFile.path,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (Database created, int version) async {
          await created.execute(
            'CREATE TABLE translations '
            '(id TEXT PRIMARY KEY, name TEXT, abbreviation TEXT, '
            'language TEXT, book_count INTEGER, verse_count INTEGER)',
          );
          await created.execute(
            "INSERT INTO translations (id, name, abbreviation, language, "
            "book_count, verse_count) VALUES ('$translationId', "
            "'Fake $translationId', '${translationId.toUpperCase()}', "
            "'en', 73, 100)",
          );
        },
      ),
    );
    await db.close();
    final Uint8List bytes = await seedFile.readAsBytes();
    await seedFile.delete();
    return bytes;
  }

  bool bytesMatch(File file, Uint8List expected) {
    final Uint8List actual = file.readAsBytesSync();
    if (actual.length != expected.length) {
      return false;
    }
    for (int i = 0; i < expected.length; i++) {
      if (actual[i] != expected[i]) {
        return false;
      }
    }
    return true;
  }

  setUp(() async {
    databasesDir = await Directory.systemTemp.createTemp(
      'bible_loader_cache_refresh',
    );
    await databaseFactory.setDatabasesPath(databasesDir.path);
    dbFile = File('${databasesDir.path}/bibles.db');
    stampFile = File('${databasesDir.path}/bibles.db.stamp');

    // "Bundled asset" of the current build: contains translation 'drc'.
    freshBytes = await buildFakeAssetBytes('drc');
    // Database left behind by a prior build: contains only a stale row.
    staleBytes = await buildFakeAssetBytes('stalewebc');
    await dbFile.writeAsBytes(staleBytes, flush: true);
  });

  tearDown(() async {
    await SqliteBibleLoader.close();
    await OptimizedSqliteBibleLoader.close();
    SqliteBibleLoader.clearCache();
    OptimizedSqliteBibleLoader.clearCache();
    if (databasesDir.existsSync()) {
      await databasesDir.delete(recursive: true);
    }
  });

  test('sqlite loader re-copies a cached database without a stamp and is a '
      'no-op afterwards', () async {
    expect(
      stampFile.existsSync(),
      isFalse,
      reason: 'precondition: prior build stored no stamp sidecar',
    );

    final SqliteBibleLoader loader = SqliteBibleLoader(
      assetLoader: (String assetPath) async {
        return freshBytes;
      },
    );

    // Phase 1 (refresh): the file exists but carries no stamp, so the
    // loader must re-copy the bundled asset and store its stamp.
    final bool available = await loader.isTranslationAvailable(
      BibleTranslation.fromId('drc'),
    );
    expect(
      available,
      isTrue,
      reason:
          'the refreshed database (bundled asset) is served, '
          'not the stale prior-build copy',
    );
    expect(
      bytesMatch(dbFile, freshBytes),
      isTrue,
      reason: 'bibles.db was re-copied from the bundled asset',
    );
    expect(
      stampFile.existsSync(),
      isTrue,
      reason: 'the stamp of the bundled asset is stored after a copy',
    );

    final String stampContent = stampFile.readAsStringSync();

    // Phase 2 (no-op): with a matching stamp the next open must not
    // rewrite the database. The proof is byte-based rather than
    // time-based: replace the on-device database with the stale
    // prior-build bytes — if the loader re-copied, the fresh bundled
    // bytes would be back on disk; a no-op leaves the stale bytes there.
    await SqliteBibleLoader.close();
    await dbFile.writeAsBytes(staleBytes, flush: true);

    final bool availableAgain = await loader.isTranslationAvailable(
      BibleTranslation.fromId('drc'),
    );
    expect(
      availableAgain,
      isFalse,
      reason:
          'second open must NOT re-copy the database (the stale bytes '
          'are still being served)',
    );
    expect(
      bytesMatch(dbFile, staleBytes),
      isTrue,
      reason: 'second open must NOT re-copy the database',
    );
    expect(
      stampFile.readAsStringSync(),
      stampContent,
      reason: 'stored stamp is stable',
    );
  });

  test('optimized loader re-copies a cached database with an outdated stamp '
      'and is a no-op afterwards', () async {
    // A prior build of the current copy mechanism wrote a stamp that no
    // longer matches the bundled asset.
    stampFile.writeAsStringSync('v1:1:deadbeef');

    final OptimizedSqliteBibleLoader loader = OptimizedSqliteBibleLoader(
      assetLoader: (String assetPath) async {
        return freshBytes;
      },
    );

    // Phase 1 (refresh): stored stamp differs from the bundled asset's
    // stamp, so the loader must re-copy and store the fresh stamp.
    final bool available = await loader.isTranslationAvailable(
      BibleTranslation.fromId('drc'),
    );
    expect(
      available,
      isTrue,
      reason:
          'the refreshed database (bundled asset) is served, '
          'not the stale prior-build copy',
    );
    expect(
      bytesMatch(dbFile, freshBytes),
      isTrue,
      reason: 'bibles.db was re-copied from the bundled asset',
    );
    final String stampContent = stampFile.readAsStringSync();
    expect(
      stampContent,
      isNot('v1:1:deadbeef'),
      reason: 'the stale stamp was replaced',
    );

    // Phase 2 (no-op): with a matching stamp the next open must not
    // rewrite the database. The proof is byte-based rather than
    // time-based: replace the on-device database with the stale
    // prior-build bytes — if the loader re-copied, the fresh bundled
    // bytes would be back on disk; a no-op leaves the stale bytes there.
    await OptimizedSqliteBibleLoader.close();
    await dbFile.writeAsBytes(staleBytes, flush: true);

    final bool availableAgain = await loader.isTranslationAvailable(
      BibleTranslation.fromId('drc'),
    );
    expect(
      availableAgain,
      isFalse,
      reason:
          'second open must NOT re-copy the database (the stale bytes '
          'are still being served)',
    );
    expect(
      bytesMatch(dbFile, staleBytes),
      isTrue,
      reason: 'second open must NOT re-copy the database',
    );
    expect(
      stampFile.readAsStringSync(),
      stampContent,
      reason: 'stored stamp is stable',
    );
  });
}
