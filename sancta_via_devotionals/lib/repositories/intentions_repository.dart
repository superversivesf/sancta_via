// The intentions CRUD wrapper (Plan 2, Task 16).
//
// A thin typed seam over the Task-4 `intentions` table: the user's prayer
// intentions and their departed souls (`kind: 'intention' | 'soul'`) in one
// list, added and removed through this repository instead of the database's
// raw table helpers. The wrapper is deliberately narrow — every table-level
// decision (upsert on `intentions.id`, oldest-first ordering, the value-set
// guard on `kind`) stays in `DevotionalsDatabase`, exactly as the pack and
// progress repositories delegate to the store.
//
// Writes are validated here BEFORE the store for a clear error: a blank text
// (whitespace only) and an unknown `kind` throw [ArgumentError], so a refused
// entry can never leave an empty row behind. The id is caller-suppliable
// (tests pin rows deterministically); when absent the wrapper mints a
// random-hex id. The created timestamp is an ISO-8601 UTC string — the store's
// timestamp convention, owned by callers (Task 4).
//
// Read compat: the Task-11 `intentionsProvider` keeps its own read over the
// same table (same rows, same order) — this wrapper is additive, not a
// replacement; the session player's intercession readout gains add/delete
// through it later.
library;

import 'dart:math' as math;

import '../database/devotionals_database.dart'
    show DevotionalsDatabase, IntentionRow, intentionKinds;

/// The CRUD wrapper over the `intentions` table of a [DevotionalsDatabase].
///
/// Construct over the SAME store the rest of the app acts on —
/// `SqliteProgramRepository.database` in production (Task 6's one-store
/// ruling), an injected FFI store in tests. `DevotionalsDatabase.intentions`
/// exposes a lazily-built wrapper over exactly that store.
class IntentionsRepository {
  /// Creates a wrapper over [database] (the store carrying the pinned
  /// `intentions` table).
  const IntentionsRepository({required this.database});

  /// The store the wrapper reads and writes through.
  final DevotionalsDatabase database;

  /// Adds one entry and returns the stored row.
  ///
  /// [kind] must be one of [intentionKinds] (`'intention'` for a personal
  /// prayer intention, `'soul'` for a departed soul); [text] must carry
  /// something beyond whitespace. [id] is the row's primary key — caller
  /// supplied (deterministic in tests) or a generated random-hex id; an
  /// existing id is replaced (the store's upsert semantics).
  Future<IntentionRow> add({
    required String kind,
    required String text,
    String? id,
  }) async {
    if (!intentionKinds.contains(kind)) {
      throw ArgumentError.value(
        kind,
        'kind',
        'must be one of: ${intentionKinds.toList()..sort()}',
      );
    }
    if (text.trim().isEmpty) {
      throw ArgumentError.value(text, 'text', 'must not be empty');
    }
    final String rowId = id ?? _newId();
    final String createdAt = DateTime.now().toUtc().toIso8601String();
    await database.insertIntention(
      id: rowId,
      kind: kind,
      text: text.trim(),
      createdAt: createdAt,
    );
    return IntentionRow(
      id: rowId,
      kind: kind,
      text: text.trim(),
      createdAt: createdAt,
    );
  }

  /// The stored entries oldest-first, optionally filtered by [kind]
  /// (validated against [intentionKinds] by the store).
  Future<List<IntentionRow>> list({String? kind}) {
    return database.getAllIntentions(kind: kind);
  }

  /// Removes one entry by [id]; returns whether a row was removed (an
  /// unknown id is false, never an error).
  Future<bool> remove(String id) {
    return database.deleteIntention(id);
  }

  /// A random-hex id (12 bytes): enough entropy for a lifetime of entries
  /// and safely outside any caller-supplied id space in tests.
  String _newId() {
    final math.Random random = math.Random.secure();
    final StringBuffer id = StringBuffer();
    for (int i = 0; i < 12; i++) {
      id.write(random.nextInt(256).toRadixString(16).padLeft(2, '0'));
    }
    return id.toString();
  }
}
