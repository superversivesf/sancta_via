// Loader for the bundled `assets/saints.db` SQLite store (Task 7).
//
// Mirrors the HARDENED sqlite-bible-loader asset-refresh pattern, re-
// implemented locally because `saint_data` must not import other workspace
// packages:
//
// 1. VERSION-STAMP layer: on every open, a small stamp of the bundled asset
//    is compared against the stamp stored in a sidecar file next to the
//    on-device copy (`<database file>.stamp`). The stamp format is
//    `v1:<byte length>:<8-hex-digit FNV-1a-32>` over the first and last
//    4096 bytes (the entire asset when it is at most 8192 bytes). When the
//    stamps differ (or no stamp exists — e.g. a prior-build copy), the
//    asset is re-copied and the stamp is rewritten, so devices that ran an
//    older build can never keep serving the old database forever.
// 2. user_version belt: `PRAGMA user_version` of the on-disk copy is
//    compared against [saintsSchemaVersion] via [needsAssetRecopy]; a
//    valid-but-older copy (e.g. one whose stamp file was tampered with) is
//    healed by re-copying the bundled asset.
//
// Refresh failures are logged and swallowed: the app then opens whatever
// copy already exists and never crashes on the refresh path. The onCreate
// path is the exception (final-review ruling): when the bundled asset
// could not be copied, [openSaintsDatabase] logs the missing asset and
// RETHROWS instead of opening an empty schema — an empty store is worse
// than the properly propagated error state (spec §9).
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:meta/meta.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

import '../db/saints_schema.dart';
import '../utils/async_lock.dart';
import '../utils/logger.dart';

/// Logging tag for the saints database loader.
const String saintsLoaderTag = 'SAINT_DATA';

/// Bytes sampled from each end of the bundled asset for the digest.
const int _sampleSize = 4096;

/// FNV-1a 32-bit offset basis.
const int _fnv1aBasis = 0x811c9dc5;

/// FNV-1a 32-bit prime.
const int _fnv1aPrime = 0x01000193;

/// Loads the bytes of a bundled asset (e.g. `assets/saints.db`).
typedef SaintsAssetBytesLoader = Future<Uint8List> Function(String assetPath);

/// Default [SaintsAssetBytesLoader] backed by Flutter's [rootBundle].
Future<Uint8List> defaultLoadSaintsAssetBytes(String assetPath) async {
  final ByteData data = await rootBundle.load(assetPath);
  return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
}

/// FNV-1a (32-bit) over [bytes], continuing from [hash].
int fnv1a32(List<int> bytes, [int hash = _fnv1aBasis]) {
  for (final int byte in bytes) {
    hash ^= byte & 0xff;
    hash = (hash * _fnv1aPrime) & 0xFFFFFFFF;
  }
  return hash;
}

/// Computes the version stamp of bundled database asset bytes:
/// `v1:<length>:<FNV-1a 32-bit digest over the first and last
/// [_sampleSize] bytes>` (the entire asset when it is at most
/// [_sampleSize * 2] bytes). Byte length plus a sampled digest
/// distinguishes changed app-shipped database assets without pulling a
/// hashing package into the runtime dependency set.
String computeAssetStamp(Uint8List bytes) {
  int hash;
  if (bytes.length <= _sampleSize * 2) {
    hash = fnv1a32(bytes);
  } else {
    hash = fnv1a32(bytes.sublist(0, _sampleSize));
    hash = fnv1a32(bytes.sublist(bytes.length - _sampleSize), hash);
  }
  return 'v1:${bytes.length}:${hash.toRadixString(16).padLeft(8, '0')}';
}

/// Pure version comparison for the user_version belt layer.
///
/// True only when the bundled schema version is NEWER than the on-disk
/// copy's `PRAGMA user_version` — i.e. the disk copy must be replaced with
/// the bundled asset. A newer disk version is kept (never downgraded).
///
/// The stamp layer in [refreshSaintsDatabaseAsset] subsumes this check for
/// byte-exact copies; this comparison stays the pinned surface for callers
/// that reason about schema versions directly, and drives the belt that
/// heals copies whose stamp (wrongly) matches their bytes.
bool needsAssetRecopy({required int bundledVersion, required int diskVersion}) {
  return bundledVersion > diskVersion;
}

/// Serializes opens so two isolates cannot race the refresh + open.
final AsyncLock _openLock = AsyncLock();

/// Opens the bundled saints database writable, refreshing the on-device
/// copy first.
///
/// Copies `assets/saints.db` from the package bundle to the databases
/// directory (the sidecar-stamped re-copy from
/// [refreshSaintsDatabaseAsset]) whenever the on-device copy is missing,
/// older, or stale, then opens it — WITHOUT `readOnly`, because SQLite
/// needs to write some metadata even for read operations (the same rule
/// `SqliteBibleLoader` follows).
///
/// The onCreate path is the loud failure: it fires only when the bundled
/// asset could not be copied (the copied asset bytes carry the schema
/// version, so a successful copy never re-creates), and an empty schema-only
/// store is worse than the propagated error state (final-review ruling).
/// The fallback therefore logs the missing asset and rethrows instead of
/// creating tables on the fly.
Future<Database> openSaintsDatabase({
  String databaseAssetPath = 'assets/saints.db',
  String dbName = 'saints.db',
}) async {
  return _openLock.synchronized(() async {
    final String dbPath = path.join(await getDatabasesPath(), dbName);
    await refreshSaintsDatabaseAsset(
      dbPath: dbPath,
      databaseAssetPath: databaseAssetPath,
    );
    try {
      final Database db = await openDatabase(
        dbPath,
        version: saintsSchemaVersion,
        onCreate: (Database db, int version) {
          final Object error = StateError(
            'Saints database asset copy unavailable: "$databaseAssetPath" '
            'did not resolve in the bundle, so no bundled copy could be '
            'opened. Refusing to fall back to an empty saints store; '
            'propagating the first-load failure instead.',
          );
          SaintLogger.error(
            'Creating (not opening) the saints schema: the bundled asset '
            'copy is unavailable — rethrowing instead of serving an empty '
            'store',
            error,
            StackTrace.current,
            tag: saintsLoaderTag,
          );
          throw error;
        },
        onOpen: (Database db) {
          SaintLogger.info(
            'Saints database opened: $dbPath',
            tag: saintsLoaderTag,
          );
        },
      );
      return db;
    } catch (e, stackTrace) {
      SaintLogger.error(
        'Failed to open saints database at $dbPath',
        e,
        stackTrace,
        tag: saintsLoaderTag,
      );
      rethrow;
    }
  });
}

/// Keeps the on-device saints database in sync with the bundled asset.
///
/// Stamp layer first (see the file doc comment for the stamp format), then
/// the [needsAssetRecopy] belt over `PRAGMA user_version`. Every failure is
/// logged and swallowed — a refresh problem must never block opening the
/// copy that already exists. [assetLoader] overrides how the bundled
/// bytes are loaded (production uses Flutter's rootBundle); it exists so
/// tests can drive the refresh against real files without the asset
/// channel.
@visibleForTesting
Future<void> refreshSaintsDatabaseAsset({
  required String dbPath,
  required String databaseAssetPath,
  SaintsAssetBytesLoader? assetLoader,
}) async {
  final SaintsAssetBytesLoader loadAssetBytes =
      assetLoader ?? defaultLoadSaintsAssetBytes;
  try {
    final Uint8List bytes = await loadAssetBytes(databaseAssetPath);
    final String stamp = computeAssetStamp(bytes);

    // Stamp layer: re-copy when the sidecar stamp is missing or stale.
    await _ensureStampFresh(dbPath: dbPath, bytes: bytes, stamp: stamp);

    // user_version belt: heal a valid copy whose stamp (wrongly) matches
    // but whose schema version predates the bundled asset.
    final int diskVersion = await _readDiskUserVersion(dbPath);
    if (needsAssetRecopy(
      bundledVersion: saintsSchemaVersion,
      diskVersion: diskVersion,
    )) {
      SaintLogger.warning(
        'Disk database user_version ($diskVersion) is older than the '
        'bundled schema ($saintsSchemaVersion); re-copying the asset',
        tag: saintsLoaderTag,
      );
      await _writeCopy(dbPath: dbPath, bytes: bytes, stamp: stamp);
    }
  } catch (e, stackTrace) {
    SaintLogger.error(
      'Saints database refresh failed; opening whatever copy exists on disk',
      e,
      stackTrace,
      tag: saintsLoaderTag,
    );
  }
}

/// Re-copies the asset when the stored sidecar stamp differs from [stamp]
/// (or when either the database or its stamp is missing entirely).
Future<void> _ensureStampFresh({
  required String dbPath,
  required Uint8List bytes,
  required String stamp,
}) async {
  final File dbFile = File(dbPath);
  final File stampFile = File('$dbPath.stamp');
  final String? storedStamp =
      (await dbFile.exists() && await stampFile.exists())
      ? await stampFile.readAsString()
      : null;

  if (storedStamp == stamp) {
    SaintLogger.info(
      'Using existing saints database at $dbPath',
      tag: saintsLoaderTag,
    );
    return;
  }

  SaintLogger.info(
    'Copying saints database from assets to $dbPath '
    '(stored stamp: ${storedStamp ?? 'none'}, bundled stamp: $stamp)',
    tag: saintsLoaderTag,
  );
  await _writeCopy(dbPath: dbPath, bytes: bytes, stamp: stamp);
  SaintLogger.info('Saints database copied successfully', tag: saintsLoaderTag);
}

/// Writes the bundled [bytes] to [dbPath] (overwriting), sets the copy
/// permissions, and stores [stamp] beside it.
Future<void> _writeCopy({
  required String dbPath,
  required Uint8List bytes,
  required String stamp,
}) async {
  final File dbFile = File(dbPath);
  await dbFile.parent.create(recursive: true);
  await dbFile.writeAsBytes(bytes, flush: true);
  await _setCopyPermissions(dbPath);
  await File('$dbPath.stamp').writeAsString(stamp, flush: true);
}

/// Mirrors the loaders' historical chmod of the on-device copy.
Future<void> _setCopyPermissions(String dbPath) async {
  if (Platform.isIOS ||
      Platform.isAndroid ||
      Platform.isMacOS ||
      Platform.isLinux) {
    try {
      await Process.run('chmod', <String>['644', dbPath]);
    } catch (e) {
      SaintLogger.warning(
        'Could not set file permissions: $e',
        tag: saintsLoaderTag,
      );
    }
  }
}

/// Reads `PRAGMA user_version` from the on-disk copy, or -1 when the file
/// is missing, unreadable, or not a database (which [needsAssetRecopy]
/// treats as strictly older than the bundled schema, forcing a heal).
Future<int> _readDiskUserVersion(String dbPath) async {
  Database? probe;
  try {
    probe = await openDatabase(dbPath, singleInstance: false);
    final List<Map<String, Object?>> rows = await probe.rawQuery(
      'PRAGMA user_version',
    );
    return rows.single['user_version'] as int? ?? -1;
  } catch (e) {
    SaintLogger.info(
      'Could not read user_version from the on-disk saints database; '
      'treating the copy as unreadable',
      tag: saintsLoaderTag,
    );
    return -1;
  } finally {
    await probe?.close();
  }
}
