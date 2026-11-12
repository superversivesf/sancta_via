// Content asset pipeline + first-launch migration (Plan 2, Task 6).
//
// `sancta_via_devotional_engine/test/fixtures/packs/` is the single source of
// truth for the EIGHT engine-fixture packs; this app ships byte-for-byte
// copies of it under `assets/content/packs/` (declared in the app pubspec —
// regenerate via copy whenever the engine fixtures change; the pin test
// `test/services/content_app_asset_pin_test.dart` guards both the declaration
// and the byte equality). The six Task-21 routine packs are AUTHORED in the
// app assets instead (see `test/content/routine_packs_test.dart`); the
// imported companion prayers under `assets/content/prayers/` ride the same
// manifest but are not packs (the loader's prefix filter skips them). On the
// first launch — and whenever the bundle's
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
// Removed-pack reconciliation: on a version-changing migration, store rows
// whose id is absent from the bundle are pruned through
// [DevotionalsDatabase.deletePack] BEFORE the version stamp, so a pack
// removed from the asset set does not linger in the catalog and a failed
// prune leaves the version unadvanced (the next launch retries the whole
// migration). The prune is content-only: enrollment, progress, and
// notification rows of a removed id are outside this service's remit
// (Task 9 owns progress reconciliation; see _pruneRemovedPacks for the
// invariant).
//
// Enrollment reconciliation (the Task-6/Task-15 seam): a version-changing seed
// upserts the ASSET JSON over every bundled id, which would overwrite the
// DERIVED rows the enrollment flow writes — a consecration's planned day 1, or
// the 54-day novena's user-picked start date, would silently regress to the
// fixture placeholder. Immediately AFTER the seed, this service re-applies
// every stored enrollment: for each `enrollments` row whose pack id is still
// in the bundle it decodes the stored params, asks Task 15's
// [EnrollmentService] to derive the pack, and upserts that derived row under
// the version the seed just stamped. The repair calls no `setMeta` (so
// `meta.content_version` is never stamped twice) and never recurses into a
// re-seed. It runs ONLY on the version-changing path: an unchanged version
// skips both the seed and the repair.
//
// Repair-failure semantics (deliberate): the version is already stamped when
// the repair runs, so a repair failure must neither abort the launch nor roll
// the content back. Each id is isolated: unparsable stored params, a derive
// [ArgumentError] (e.g. params the updated pack can no longer satisfy), or a
// failed row write is logged loudly under the CONTENT tag and that id is
// SKIPPED while the remaining enrollments reconcile. The seeded asset row
// stays, the enrollment row stays as the durable source of truth, and the
// version remains advanced. A skipped id is not retried until the next
// version-changing migration or a fresh enrollment; user state is never
// deleted. If the enrollment list itself cannot be read, the whole repair is
// skipped with the same loud log — the seeded content is already correct.
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
import 'enrollment_service.dart';

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
  /// [enrollmentService] optionally overrides the Task-15 repair seam (tests
  /// count its derive calls); it must share [repository]'s store.
  ContentAssetService({
    required this.assets,
    required this.repository,
    required this.database,
    EnrollmentService? enrollmentService,
  }) : _enrollmentService =
           enrollmentService ?? EnrollmentService(repository: repository);

  final AssetBundle assets;
  final SqliteProgramRepository repository;
  final DevotionalsDatabase database;

  /// The Task-15 derive seam used by the post-seed enrollment repair.
  final EnrollmentService _enrollmentService;

  /// The bundle directory the pack assets live under.
  static const String _packAssetPrefix = 'assets/content/packs/';

  /// Ensures the repository carries the bundle's catalog: loads every
  /// `$_packAssetPrefix*.json` declared in the asset manifest, computes the
  /// bundle's content version, and — only when it differs from the stored
  /// `meta.content_version` — prunes store rows absent from the bundle
  /// (BEFORE the stamp, fix round 1), then seeds the repository, then
  /// re-applies the stored enrollments over the freshly seeded rows (the
  /// Task-15 repair; see the library header). Returns the whole catalog in the
  /// repository's stable id order.
  ///
  /// An unparseable pack asset (or a bundle with none declared, or two
  /// assets declaring one pack id) throws a [ContentValidationException]
  /// naming the file; nothing is written in that case. A prune or seed write
  /// failure propagates after logging — the version stamp only lands after
  /// both completed, so a failed migration leaves the previous version in
  /// place and the next launch retries the whole thing rather than
  /// permanently claiming a completed one. An enrollment-repair failure is
  /// DIFFERENT: it runs after the stamp, so it logs and skips the affected id
  /// (never aborting the migration or re-stamping the version).
  Future<List<ContentPack>> ensureContentLoaded() async {
    final List<_AssetPack> loaded = await _loadPackAssets();
    final String version = _contentVersion(loaded);
    final String? stored = await repository.persistedPackVersion();
    if (stored == version) {
      return repository.loadPacks();
    }
    // Removed-pack reconciliation runs BEFORE the version stamp (fix round
    // 1): a failed or killed prune must not leave `meta.content_version`
    // claiming a completed migration — stamped last, an unadvanced version
    // retries the whole migration on the next launch, and the deleted ids
    // were leaving the catalog regardless. (The previous seed-then-prune
    // order would make a failed/killed prune permanent.) The prune also
    // mutates the store without touching the Task-5 cache generation, so
    // running it before the seed keeps [SqliteProgramRepository.seedPacks]'s
    // clearCache() after the prune; any loadPacks that raced the prune and
    // cached the pre-prune catalog is evicted by the seed instead of being
    // cached permanently. The enrollment repair below is the only later
    // mutation and clears the cache itself after a derived-row write.
    await _pruneRemovedPacks(<String>{
      for (final _AssetPack assetPack in loaded) assetPack.pack.id,
    });
    final List<ContentPack> bundlePacks = <ContentPack>[
      for (final _AssetPack assetPack in loaded) assetPack.pack,
    ];
    await repository.seedPacks(bundlePacks, packVersion: version);
    // The seed upserted the ASSET JSON over every bundled id; the enrollment
    // repair now puts the user's derived rows back on top (Task-15 seam).
    await _reconcileEnrolledPacks(bundlePacks, version);
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
      // Deliberately broad for THIS asset only: platform bundles surface
      // missing/dead assets as FlutterError (an Error, not an Exception),
      // and staged test bundles throw their own failures — every per-file
      // failure is an authoring/packaging error that must name its file
      // rather than skip silently. Anything raised inside this try belongs
      // to loading/parsing THIS asset, so converting it keeps the loud,
      // file-naming failure instead of letting an Error-class escape mask
      // the file that caused it.
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

  /// Removes store pack rows whose id is absent from the bundle
  /// ([DevotionalsDatabase.deletePack]), logging each prune. A failure logs
  /// and rethrows, so it can abort the migration BEFORE the version stamp
  /// lands (see [ensureContentLoaded]).
  ///
  /// Invariant (Plan 3 note): the `packs` table is CONTENT, not user state —
  /// this prune touches only pack rows. An id's enrollment, progress, and
  /// notification rows are the user's, stay untouched by design, and remain
  /// their owners' responsibility (Task 9 owns progress reconciliation).
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

  /// Re-applies the stored enrollment choices over the freshly seeded asset
  /// rows (the Task-15 derived-pack seam).
  ///
  /// For each enrollment row whose pack id is still in [bundlePacks], decodes
  /// `params_json`, asks [EnrollmentService.derivePack] for the derived pack,
  /// and upserts the derived row under [version] (the version the seed just
  /// stamped; `setMeta` is deliberately never called here). A commitment's
  /// derive returns the bundle pack unchanged, so nothing is rewritten.
  ///
  /// Every failure is isolated to its id and loud: a bad params JSON, a derive
  /// [ArgumentError], or a failed row write logs under CONTENT and skips that
  /// id; the rest reconcile and the migration completes. An enrollment row for
  /// a pack no longer in the bundle is skipped (its pack row was pruned; the
  /// user row stays outside this service's remit). A failure to LIST the
  /// enrollments logs and skips the whole repair — the seeded content is
  /// already correct and the version is stamped.
  Future<void> _reconcileEnrolledPacks(
    List<ContentPack> bundlePacks,
    String version,
  ) async {
    final Map<String, ContentPack> byId = <String, ContentPack>{
      for (final ContentPack pack in bundlePacks) pack.id: pack,
    };

    final List<EnrollmentRow> enrollments;
    try {
      enrollments = await database.getAllEnrollments();
    } catch (e, stackTrace) {
      AppLogger.error(
        'Failed to read enrollments for the post-update repair; the seeded '
        'catalog stays authoritative this launch',
        e,
        stackTrace,
        _tag,
      );
      return;
    }

    bool repaired = false;
    for (final EnrollmentRow row in enrollments) {
      final ContentPack? assetPack = byId[row.packId];
      if (assetPack == null) {
        AppLogger.debug(
          'Enrollment for "${row.packId}" has no bundled pack (removed '
          'content); leaving the user row untouched',
          _tag,
        );
        continue;
      }
      try {
        final Object? decoded = jsonDecode(row.paramsJson);
        if (decoded is! Map<String, dynamic>) {
          throw FormatException(
            'enrollment params for "${row.packId}" are not a JSON object',
          );
        }
        final ContentPack derived = await _enrollmentService.derivePack(
          pack: assetPack,
          params: decoded,
        );
        if (identical(derived, assetPack)) {
          // No derivation applies (a commitment or routine pack): the seeded
          // asset row is already the enrolled shape.
          continue;
        }
        await database.upsertPack(
          id: assetPack.id,
          json: jsonEncode(derived.toJson()),
          packVersion: version,
          embeddedAt: DateTime.now().toUtc().toIso8601String(),
        );
        repaired = true;
        AppLogger.info(
          'Re-applied the enrollment parameters of "${assetPack.id}" over '
          'the updated content',
          _tag,
        );
      } on Object catch (e, stackTrace) {
        // The version stamp is already written: a broken repair must be loud
        // but must not abort the launch or roll content back. The seeded asset
        // row and the durable enrollment row both stay.
        AppLogger.error(
          'Failed to re-apply enrollment parameters for "${row.packId}" over '
          'the updated content; keeping the seeded pack row this launch',
          e,
          stackTrace,
          _tag,
        );
      }
    }
    if (repaired) {
      // A targeted row write bypassed the Task-5 cache generation; evict any
      // catalog read that raced it so the returned catalog is the repaired one.
      repository.clearCache();
    }
  }
}
