// The SQLite-backed persistence seam between the devotional engine and the
// app (Task 5).
//
// The repository stores and hands back engine values without interpreting
// them: packs are seeded as the engine serialized them and re-parsed through
// [PackLoader], progress round trips through [ProgressState.toJson] /
// [ProgressState.fromJson], and enrollment params are opaque JSON. Every
// scheduling, session, and progress decision stays in
// `sancta_via_devotional_engine`; nothing here re-implements it.
//
// Read failures degrade to the safe defaults the build rules pin — `[]` for
// [loadPacks], null for [progressFor] / [enrollmentParamsFor] /
// [persistedPackVersion] — and are logged through [AppLogger]. A corrupt pack
// row is skipped rather than emptying the catalog, and a present-but-
// unparsable progress row logs distinctly from a missing one (Task 9 owns
// reconciling that hazard). Writes log and rethrow: a swallowed write would
// leave the UI claiming state the store never took.
library;

import 'dart:convert';

import 'package:sancta_via_devotional_engine_riverpod/sancta_via_devotional_engine_riverpod.dart';

import '../database/database_migration_service.dart';
import '../database/devotionals_database.dart';
import '../utils/logger.dart';

/// A [ProgramRepository] backed by the app's `devotionals.db` store.
///
/// [loadPacks] returns the current `packs` rows parsed through the engine's
/// [PackLoader], in the rows' id order (the store's stable order) — an empty
/// store returns `[]`; seeding is the content pipeline's job, not the
/// repository's. A row that fails to parse is logged by id and skipped, so
/// one corrupt row never empties the whole catalog. [enroll] / [saveProgress] upsert their single rows on the
/// pinned primary keys, so re-enrolling replaces params instead of
/// duplicating them and saving progress never touches the enrollment.
/// [unenroll] removes the user's enrollment, progress, and notification rows
/// but keeps the pack row: packs are content, not user state.
///
/// Packs are cached after the first successful read; [clearCache] forces a
/// re-read, and [seedPacks] invalidates the cache itself. A read that races a
/// seed is never cached, so the next read sees the seeded rows.
class SqliteProgramRepository implements ProgramRepository {
  /// [database] overrides the backing store; defaults to the app-wide
  /// [DevotionalsDatabase.instance]. Tests inject an in-memory wrapper.
  SqliteProgramRepository({DevotionalsDatabase? database})
    : _database = database ?? DevotionalsDatabase.instance;

  final DevotionalsDatabase _database;

  /// The backing store this repository reads and writes — the seam the content
  /// pipeline's removed-pack reconciliation (Task 6) uses so it acts on
  /// exactly this repository's store, never a separately-opened one.
  DevotionalsDatabase get database => _database;

  /// The parsed packs of the last successful read, or null when a re-read is
  /// needed ([clearCache] or a seed invalidated it).
  List<ContentPack>? _packsCache;

  /// Bumped by [clearCache]; a read started under an older generation must
  /// not publish its result into the cache.
  int _packsGeneration = 0;

  /// Drops the cached packs so the next [loadPacks] re-reads the store.
  void clearCache() {
    _packsCache = null;
    _packsGeneration++;
  }

  /// Inserts or replaces every pack row with [pack]'s id at [packVersion],
  /// then stamps `meta.content_version` with [packVersion].
  ///
  /// Re-seeding with a new version replaces the row of every seeded id
  /// (upsert on `packs.id`), so no duplicates accumulate; ids absent from
  /// [packs] are left alone (the content pipeline seeds the full bundle).
  /// The pack cache is invalidated afterwards.
  ///
  /// Writes log and rethrow on failure; a failed seed must not look like a
  /// successful one to the content pipeline.
  Future<void> seedPacks(
    List<ContentPack> packs, {
    required String packVersion,
  }) async {
    try {
      final String embeddedAt = _nowIso();
      for (final ContentPack pack in packs) {
        await _database.upsertPack(
          id: pack.id,
          json: jsonEncode(pack.toJson()),
          packVersion: packVersion,
          embeddedAt: embeddedAt,
        );
      }
      await _database.setMeta(
        DatabaseMigrationService.contentVersionMetaKey,
        packVersion,
      );
      clearCache();
    } catch (e, stackTrace) {
      AppLogger.error('Failed to seed program packs', e, stackTrace, 'REPO');
      rethrow;
    }
  }

  /// The stored content version (`meta.content_version`), or null when the
  /// store has not been seeded yet.
  Future<String?> persistedPackVersion() async {
    try {
      return await _database.getMeta(
        DatabaseMigrationService.contentVersionMetaKey,
      );
    } catch (e, stackTrace) {
      AppLogger.error(
        'Failed to read persisted pack version',
        e,
        stackTrace,
        'REPO',
      );
      return null;
    }
  }

  /// The enrollment params stored for [packId], or null when the user is not
  /// enrolled in it.
  Future<Map<String, dynamic>?> enrollmentParamsFor(String packId) async {
    try {
      final EnrollmentRow? row = await _database.getEnrollment(packId);
      if (row == null) {
        return null;
      }
      final Object? decoded = jsonDecode(row.paramsJson);
      if (decoded is! Map<String, dynamic>) {
        throw FormatException(
          'enrollment params for "$packId" are not a JSON object',
        );
      }
      return Map<String, dynamic>.unmodifiable(decoded);
    } catch (e, stackTrace) {
      AppLogger.error(
        'Failed to load enrollment params for "$packId"',
        e,
        stackTrace,
        'REPO',
      );
      return null;
    }
  }

  /// Removes the user's state for [packId]: the enrollment (and with it the
  /// stored params), the progress row, and every notification row for the
  /// pack. The pack row itself is content and stays.
  ///
  /// Unenrolling a pack that is not enrolled is a no-op. Writes log and
  /// rethrow on failure.
  Future<void> unenroll(String packId) async {
    try {
      await _database.deleteEnrollment(packId);
      await _database.deleteProgress(packId);
      await _database.deleteNotificationsForPack(packId);
    } catch (e, stackTrace) {
      AppLogger.error(
        'Failed to unenroll from "$packId"',
        e,
        stackTrace,
        'REPO',
      );
      rethrow;
    }
  }

  @override
  Future<List<ContentPack>> loadPacks() async {
    final List<ContentPack>? cached = _packsCache;
    if (cached != null) {
      return cached;
    }
    final int generation = _packsGeneration;
    final List<PackRow> rows;
    try {
      rows = await _database.getAllPacks();
    } catch (e, stackTrace) {
      AppLogger.error('Failed to load program packs', e, stackTrace, 'REPO');
      return <ContentPack>[];
    }

    // One corrupt row must not take the whole catalog down: skip it, log it
    // by id, and still return every pack that parses.
    final List<ContentPack> parsed = <ContentPack>[];
    for (final PackRow row in rows) {
      try {
        parsed.add(PackLoader.loadFromJsonString(row.json));
      } catch (e, stackTrace) {
        AppLogger.error(
          'Failed to parse pack row "${row.id}"',
          e,
          stackTrace,
          'REPO',
        );
      }
    }
    final List<ContentPack> packs = List<ContentPack>.unmodifiable(parsed);
    // A seed that finished while this read was in flight bumped the
    // generation: returning the pre-seed rows once is harmless, but they
    // must not stay cached.
    if (generation == _packsGeneration) {
      _packsCache = packs;
    }
    return packs;
  }

  @override
  Future<ProgressState?> progressFor(String packId) async {
    final ProgressRow? row;
    try {
      row = await _database.getProgress(packId);
    } catch (e, stackTrace) {
      AppLogger.error(
        'Failed to load progress for "$packId"',
        e,
        stackTrace,
        'REPO',
      );
      return null;
    }
    if (row == null) {
      return null;
    }
    try {
      final Object? decoded = jsonDecode(row.stateJson);
      if (decoded is! Map<String, dynamic>) {
        throw FormatException(
          'progress state for "$packId" is not a JSON object',
        );
      }
      return ProgressState.fromJson(decoded);
    } catch (e, stackTrace) {
      // The row EXISTS but cannot be read: a distinct signal from "no
      // progress yet". The safe default is still null, but the log tells
      // the missed-day flow the difference before a save overwrites it.
      AppLogger.error(
        'Progress state present but unparsable for "$packId" — '
            'treating as absent',
        e,
        stackTrace,
        'REPO',
      );
      return null;
    }
  }

  @override
  Future<void> enroll(String packId, Map<String, dynamic> params) async {
    try {
      await _database.upsertEnrollment(
        packId: packId,
        paramsJson: jsonEncode(params),
        enrolledAt: _nowIso(),
      );
    } catch (e, stackTrace) {
      AppLogger.error('Failed to enroll in "$packId"', e, stackTrace, 'REPO');
      rethrow;
    }
  }

  @override
  Future<void> saveProgress(ProgressState s) async {
    try {
      await _database.saveProgress(
        packId: s.packId,
        stateJson: jsonEncode(s.toJson()),
        updatedAt: _nowIso(),
      );
    } catch (e, stackTrace) {
      AppLogger.error(
        'Failed to save progress for "${s.packId}"',
        e,
        stackTrace,
        'REPO',
      );
      rethrow;
    }
  }

  /// The current instant as an ISO-8601 UTC string, the timestamp format the
  /// store's text columns carry.
  static String _nowIso() => DateTime.now().toUtc().toIso8601String();
}
