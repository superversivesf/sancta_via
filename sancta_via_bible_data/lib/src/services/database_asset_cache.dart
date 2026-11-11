import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:meta/meta.dart';

import '../utils/logger.dart';

/// Loads the bytes of a bundled asset (e.g. `assets/bibles.db`).
typedef AssetBytesLoader = Future<Uint8List> Function(String assetPath);

/// Keeps the on-device copy of a bundled SQLite database in sync with the
/// shipped asset.
///
/// Historically the SQLite loaders copied the bundled `bibles.db` only when
/// the on-device file was missing, so any device that ran a prior build kept
/// serving the OLD database forever. `ensureFresh` version-stamps the copy
/// instead: on every open, a small stamp of the bundled asset is compared
/// against the stamp stored next to the on-device copy
/// (`<database file>.stamp`), and the asset is re-copied (overwriting) when
/// they differ. The stamp format is
/// `v1:<byte length>:<8-hex-digit FNV-1a-32>` where the FNV-1a digest is
/// computed over the first and last 4096 bytes of the asset (the entire
/// asset when it is at most 8192 bytes). Byte length plus a sampled digest
/// distinguishes changed app-shipped database assets without pulling a
/// hashing package into the runtime dependency set (package:crypto stays
/// dev-only).
///
/// Refresh failures are logged and swallowed: the app then opens whatever
/// copy already exists (openDatabase may create an empty database when none
/// exists, exactly as before this class) and never crashes on the
/// cache-refresh path.
class DatabaseAssetCache {
  /// Bytes sampled from each end of the bundled asset for the digest.
  static const int _sampleSize = 4096;

  /// FNV-1a 32-bit offset basis.
  static const int _fnv1aBasis = 0x811c9dc5;

  /// FNV-1a 32-bit prime.
  static const int _fnv1aPrime = 0x01000193;

  final String databaseAssetPath;

  /// Loads the bundled asset bytes; overridable in tests (production code
  /// uses [defaultLoadAssetBytes] backed by Flutter's rootBundle).
  @visibleForTesting
  final AssetBytesLoader loadAssetBytes;

  const DatabaseAssetCache({
    required this.databaseAssetPath,
    AssetBytesLoader? assetLoader,
  }) : loadAssetBytes = assetLoader ?? defaultLoadAssetBytes;

  /// Default [AssetBytesLoader] backed by Flutter's [rootBundle].
  static Future<Uint8List> defaultLoadAssetBytes(String assetPath) async {
    final ByteData data = await rootBundle.load(assetPath);
    return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  }

  /// Computes the version stamp of bundled database asset bytes:
  /// `v1:<length>:<FNV-1a 32-bit digest over the first and last
  /// [_sampleSize] bytes>`.
  static String computeStamp(Uint8List bytes) {
    int hash;
    if (bytes.length <= _sampleSize * 2) {
      hash = fnv1a32(bytes);
    } else {
      hash = fnv1a32(bytes.sublist(0, _sampleSize));
      hash = fnv1a32(bytes.sublist(bytes.length - _sampleSize), hash);
    }
    return 'v1:${bytes.length}:${hash.toRadixString(16).padLeft(8, '0')}';
  }

  /// FNV-1a (32-bit) over [bytes], continuing from [hash].
  static int fnv1a32(List<int> bytes, [int hash = _fnv1aBasis]) {
    for (final int byte in bytes) {
      hash ^= byte & 0xff;
      hash = (hash * _fnv1aPrime) & 0xFFFFFFFF;
    }
    return hash;
  }

  /// Ensures the on-device database file at [dbPath] matches the bundled
  /// asset: re-copies (overwrites) the file when the stored stamp differs
  /// from the bundled asset's stamp and stores the new stamp once the copy
  /// succeeded. Failures are logged and swallowed — the existing copy, if
  /// any, stays in place for openDatabase to handle. [tag] matches the
  /// calling loader's logging tag.
  Future<void> ensureFresh({
    required String dbPath,
    required String tag,
  }) async {
    final File dbFile = File(dbPath);
    final File stampFile = File('$dbPath.stamp');
    try {
      final Uint8List bytes = await loadAssetBytes(databaseAssetPath);
      final String stamp = computeStamp(bytes);
      final String? storedStamp =
          (await dbFile.exists() && await stampFile.exists())
          ? await stampFile.readAsString()
          : null;

      if (storedStamp == stamp) {
        // The on-device copy came from exactly this bundled asset.
        AppLogger.loader('Using existing database at $dbPath', tag);
        return;
      }

      // The device never copied this asset (prior builds copied the
      // database only when the file was missing, so a prior-build copy has
      // no stamp), or the bundled asset changed (new app build).
      AppLogger.loader(
        'Copying database from assets to $dbPath'
        ' (stored stamp: ${storedStamp ?? 'none'}, bundled stamp: $stamp)',
        tag,
      );
      await dbFile.parent.create(recursive: true);
      await dbFile.writeAsBytes(bytes, flush: true);
      await _setCopyPermissions(dbPath, tag);
      await stampFile.writeAsString(stamp, flush: true);
      AppLogger.loader('Database copied successfully', tag);
    } catch (e) {
      AppLogger.error(
        'Database cache refresh failed; opening the existing copy',
        e,
        null,
        tag,
      );
    }
  }

  /// Mirrors the loaders' historical chmod of the on-device copy.
  static Future<void> _setCopyPermissions(String dbPath, String tag) async {
    if (Platform.isIOS ||
        Platform.isAndroid ||
        Platform.isMacOS ||
        Platform.isLinux) {
      try {
        await Process.run('chmod', ['644', dbPath]);
      } catch (e) {
        AppLogger.loader('Warning: Could not set file permissions: $e', tag);
      }
    }
  }
}
