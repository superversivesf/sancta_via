// Content asset pipeline + first-launch migration (Plan 2, Task 6).
//
// `sancta_via_devotional_engine/test/fixtures/packs/` is the single source of
// truth for the catalog; this app ships byte-for-byte copies of it under
// `assets/content/packs/` (declared in the app pubspec — regenerate via copy
// whenever the engine fixtures change; the pin test
// `test/services/content_app_asset_pin_test.dart` guards both the declaration
// and the byte equality). On the first launch — and whenever the bundle's
// computed content version differs from the stored `meta.content_version` —
// every declared pack asset is parsed through the engine's [PackLoader] and
// seeded into the SQLite program repository.
//
// Validation seam: [PackLoader.loadFromJsonString] runs the engine's full,
// problem-accumulating validation pass ([ContentPack.fromJson]) — the same
// single pass the engine's fixture tooling leans on. `PackValidator.problems`
// is a separate, fixture-time check (every schedule resolves to at least one
// due date within a given year) that has no meaning at app-load time, so
// re-running it here would be redundant. Any per-file failure (malformed JSON
// syntax, an engine [ContentValidationException], an unloadable asset) is
// logged and rethrown as a [ContentValidationException] naming the offending
// asset file — an authoring/packaging error, never a silent skip.
//
// Content version: a stable sha256 over the newline-joined `<packId>:<asset
// digest>` entries sorted by pack id, where `<asset digest>` is the sha256 of
// the asset's own bytes. The engine fixtures carry no embedded version field
// (the brief's "embedded pack_version fields" has no counterpart in the
// format), so each asset's byte digest stands in as its per-pack version:
// byte-identical assets always compute the same version, and any fixture edit
// — text fix, schedule change, new or removed pack — changes it and triggers
// the one-shot re-seed below.
//
// Removed-pack reconciliation: after a successful seed, store rows whose id is
// absent from the bundle are deleted through [DevotionalsDatabase.deletePack],
// so a pack removed from the asset set does not linger in the catalog. The
// prune is content-only: enrollment, progress, and notification rows of a
// removed id are outside this service's remit (Task 9 owns progress
// reconciliation).
//
// Ordering: the seeded catalog flows back through [SqliteProgramRepository
// .loadPacks], which returns the store's `packs.id ASC` order — the bundle's
// filename/manifest order is the parse order, not an exposed ordering
// contract (consumer surfaces must not assume it; noted for Task 12).
library;

import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:sancta_via_devotional_engine/sancta_via_devotional_engine.dart';

import '../database/devotionals_database.dart';
import '../repositories/program_repository.dart';
import '../utils/logger.dart';

/// Log tag for the content pipeline.
const String _tag = 'CONTENT';

/// One parsed pack asset: its bundle path, the parsed pack, and the sha256
/// digest of the asset bytes (the per-pack component of the content version).
class _AssetPack {
  const _AssetPack({
    required this.path,
    required this.pack,
    required this.digest,
  });

  final String path;
  final ContentPack pack;
  final String digest;
}

/// Seeds the engine's devotional programs from the app's bundled content
/// assets, exactly once per bundle content state.
class ContentAssetService {
  /// [assets] supplies the bundle the manifest and pack assets resolve
  /// against (the real [rootBundle] in the app; a staged fake in tests).
  /// [repository] is seeded and read back through; [database] is the same
  /// underlying store, used for the removed-pack reconciliation only.
  ContentAssetService({
    required this.assets,
    required this.repository,
    required this.database,
  });

  final AssetBundle assets;
  final SqliteProgramRepository repository;
  final DevotionalsDatabase database;

  /// The bundle directory the pack assets live under.
  static const String _packAssetPrefix = 'assets/content/packs/';

  /// Ensures the repository carries the bundle's catalog: loads every
  /// `$_packAssetPrefix*.json` declared in the asset manifest, computes the
  /// bundle's content version, and — only when it differs from the stored
  /// `meta.content_version` — seeds the repository and prunes store rows
  /// absent from the bundle. Returns the whole catalog in the repository's
  /// stable id order.
  ///
  /// An unparseable pack asset (or a bundle with none declared, or two
  /// assets declaring one pack id) throws a [ContentValidationException]
  /// naming the file; nothing is seeded in that case. A seed or prune write
  /// failure propagates after logging — a failed migration must not look
  /// like a successful one.
  Future<List<ContentPack>> ensureContentLoaded() async {
    final List<_AssetPack> loaded = await _loadPackAssets();
    final String version = _contentVersion(loaded);
    final String? stored = await repository.persistedPackVersion();
    if (stored == version) {
      return repository.loadPacks();
    }
    await repository.seedPacks(<ContentPack>[
      for (final _AssetPack assetPack in loaded) assetPack.pack,
    ], packVersion: version);
    await _pruneRemovedPacks(<String>{
      for (final _AssetPack assetPack in loaded) assetPack.pack.id,
    });
    return repository.loadPacks();
  }

  /// Every declared pack asset, parsed, in manifest/filename order.
  Future<List<_AssetPack>> _loadPackAssets() async {
    final AssetManifest manifest = await AssetManifest.loadFromAssetBundle(
      assets,
    );
    final List<String> paths =
        manifest.listAssets().where(_isPackAsset).toList()..sort();
    if (paths.isEmpty) {
      final ContentValidationException error = _authoringError(
        _packAssetPrefix,
        'no content pack assets are declared under "$_packAssetPrefix"',
        problems: <String>[
          'no "$_packAssetPrefix*.json" keys in the asset manifest',
        ],
        error: 'empty pack asset manifest',
      );
      throw error;
    }

    final List<_AssetPack> loaded = <_AssetPack>[];
    final Map<String, String> idToPath = <String, String>{};
    for (final String path in paths) {
      final _AssetPack assetPack = await _loadPackAsset(path);
      final String? previous = idToPath[assetPack.pack.id];
      if (previous != null) {
        throw _authoringError(
          path,
          'pack id "${assetPack.pack.id}" is declared twice '
          '("$previous" and "$path")',
          problems: <String>[
            '$previous: pack id "${assetPack.pack.id}"',
            '$path: pack id "${assetPack.pack.id}"',
          ],
          error: 'duplicate pack id "${assetPack.pack.id}"',
        );
      }
      idToPath[assetPack.pack.id] = path;
      loaded.add(assetPack);
    }
    return List<_AssetPack>.unmodifiable(loaded);
  }

  bool _isPackAsset(String key) =>
      key.startsWith(_packAssetPrefix) && key.endsWith('.json');

  /// Loads, digests, and parses one pack asset. Every failure is logged and
  /// rethrown as a [ContentValidationException] naming the file.
  Future<_AssetPack> _loadPackAsset(String path) async {
    try {
      final ByteData data = await assets.load(path);
      final Uint8List bytes = Uint8List.sublistView(data);
      final String digest = sha256.convert(bytes).toString();
      final String text = utf8.decode(bytes);
      return _AssetPack(
        path: path,
        pack: PackLoader.loadFromJsonString(text),
        digest: digest,
      );
    } on ContentValidationException catch (e, stackTrace) {
      throw _authoringError(
        path,
        'failed engine validation: ${e.message}',
        problems: <String>[
          for (final String problem in e.problems) '$path: $problem',
        ],
        error: e,
        stackTrace: stackTrace,
      );
    } on FormatException catch (e, stackTrace) {
      throw _authoringError(
        path,
        'is not valid pack JSON: ${e.message}',
        problems: <String>['$path: ${e.message}'],
        error: e,
        stackTrace: stackTrace,
      );
    } on Object catch (e, stackTrace) {
      throw _authoringError(
        path,
        'could not load the asset: $e',
        problems: <String>['$path: could not load the asset'],
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Logs an authoring/packaging failure and wraps it in a
  /// [ContentValidationException] that names [source] (the file, or the
  /// bundle directory for manifest-level failures).
  ContentValidationException _authoringError(
    String source,
    String detail, {
    required List<String> problems,
    required Object error,
    StackTrace? stackTrace,
  }) {
    AppLogger.error(
      'Failed to load content pack asset "$source"',
      error,
      stackTrace,
      _tag,
    );
    return ContentValidationException(
      message: 'content pack asset "$source" $detail',
      problems: problems,
    );
  }

  /// The stable content version: sha256 over the newline-joined
  /// `<packId>:<asset digest>` entries sorted by pack id (ids are unique by
  /// the duplicate check, so entry order == id order).
  String _contentVersion(List<_AssetPack> loaded) {
    final List<String> entries = <String>[
      for (final _AssetPack assetPack in loaded)
        '${assetPack.pack.id}:${assetPack.digest}',
    ]..sort();
    return sha256.convert(utf8.encode(entries.join('\n'))).toString();
  }

  /// After a seed: removes store pack rows whose id is absent from the bundle
  /// ([DevotionalsDatabase.deletePack]), logging each prune. A failure logs
  /// and rethrows.
  Future<void> _pruneRemovedPacks(Set<String> bundleIds) async {
    final List<PackRow> rows = await database.getAllPacks();
    for (final PackRow row in rows) {
      if (bundleIds.contains(row.id)) {
        continue;
      }
      try {
        final bool removed = await database.deletePack(row.id);
        if (removed) {
          AppLogger.info('Pruned removed content pack "${row.id}"', _tag);
        }
      } catch (e, stackTrace) {
        AppLogger.error(
          'Failed to prune removed content pack "${row.id}"',
          e,
          stackTrace,
          _tag,
        );
        rethrow;
      }
    }
  }
}
