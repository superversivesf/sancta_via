// SaintRepository: the runtime data layer over `assets/saints.db` (Task 7).
//
// All data access flows through this repository (no direct DB queries
// elsewhere); every method logs failures via [SaintLogger] (tag
// 'SAINT_DATA') and returns a safe default instead of throwing. Search
// implements the pinned 5-step tiered algorithm:
//
//   1. tokenize the query (empty tokens -> no results);
//   2. expand synonym lookups into candidate canonical needs;
//   3. build OR-joined FTS prefix terms with [buildFtsTerms];
//   4. run the three FTS tier queries (name / patronages / bio+prayer),
//      union direct `patronages.need IN (candidates)` into tier 2, order
//      results tier 1 -> 2 -> 3, dedupe by slug, attach the rationale;
//   5. apply the category filter and the limit after the merge.
import 'package:meta/meta.dart';
import 'package:sqflite/sqflite.dart';

import '../models/saint.dart';
import '../models/saint_category.dart';
import '../models/saint_search_result.dart';
import '../utils/async_lock.dart';
import '../utils/logger.dart';
import '../utils/normalization.dart';
import 'saints_db_loader.dart';

/// The logging tag for the saint repository, per AGENTS.md.
const String _tag = 'SAINT_DATA';

/// Maximum bound parameters per `IN (...)` list (keeps well under the
/// smallest SQLite host variable limit).
const int _inClauseChunkSize = 500;

/// Builds the FTS MATCH expression for [terms]: each term normalized, a
/// trailing `*` appended for prefix matching, terms joined with ' OR '.
///
/// Note on quoting: the tokens reaching this function come from
/// [tokenizeSearchQuery], whose normalization (lowercase, diacritic fold,
/// strip to `a-z0-9` and space) provably leaves no FTS operators or
/// punctuation, so quoting adds no safety — and empirically HURTS: on
/// SQLite 3.54 FTS4, `"term"*` (quote + star) matches only when it is the
/// entire expression; combined with `OR` the whole MATCH silently returns
/// zero rows (`'"ther"* OR "not"*'` -> 0 rows). Unquoted prefix terms work
/// everywhere, and keyword-shaped tokens (`or*`, `not*`) parsed as prefix
/// terms, not operators (verified against the committed database). The
/// operator-mangling test pins exactly this: `'"therese" OR NOT'` must
/// behave like the plain query.
String buildFtsTerms(List<String> terms) {
  final List<String> parts = <String>[];
  for (final String term in terms) {
    final String normalized = normalizeSearchText(term).replaceAll(' ', '');
    if (normalized.isEmpty) {
      continue;
    }
    parts.add('$normalized*');
  }
  return parts.join(' OR ');
}

/// Singleton data layer over the bundled saints SQLite database.
class SaintRepository {
  SaintRepository._internal() : _injectedDatabase = null;

  /// Testing-only constructor: runs every method against [database] and
  /// never touches the bundled asset or the databases directory.
  @visibleForTesting
  SaintRepository.forDatabase(Database database) : _injectedDatabase = database;

  static final SaintRepository _instance = SaintRepository._internal();

  /// The process-wide repository instance.
  static SaintRepository get instance => _instance;

  final Database? _injectedDatabase;
  Database? _database;
  final AsyncLock _loadLock = AsyncLock();

  /// Opens the bundled database (no-op when a database was injected or is
  /// already open). Failures are logged and swallowed; every access method
  /// then returns its safe default.
  Future<void> ensureLoaded() async {
    if (_injectedDatabase != null || _database != null) {
      return;
    }
    await _loadLock.synchronized(() async {
      // Double-check after acquiring the lock.
      if (_injectedDatabase != null || _database != null) {
        return;
      }
      try {
        _database = await openSaintsDatabase();
      } catch (e, stackTrace) {
        SaintLogger.error(
          'Failed to load the saints database',
          e,
          stackTrace,
          tag: _tag,
        );
      }
    });
  }

  /// Runs [action] against the loaded database, or returns [fallback]
  /// (after logging) when the database is unavailable or [action] fails.
  Future<T> _withDatabase<T>(
    Future<T> Function(Database db) action,
    T fallback,
  ) async {
    await ensureLoaded();
    final Database? db = _injectedDatabase ?? _database;
    if (db == null) {
      SaintLogger.warning(
        'Saints database unavailable; returning a safe default',
        tag: _tag,
      );
      return fallback;
    }
    try {
      return await action(db);
    } catch (e, stackTrace) {
      SaintLogger.error('Saint query failed', e, stackTrace, tag: _tag);
      return fallback;
    }
  }

  /// Saints whose stored feast day equals [feastKey].
  ///
  /// `'unknown'` is never a match result: unknown-feast saints stay
  /// discoverable via categories and search only (spec section 7).
  Future<List<Saint>> getSaintsForFeastDay(String feastKey) {
    return _withDatabase<List<Saint>>((Database db) async {
      final String key = feastKey.trim();
      if (key.isEmpty || key == 'unknown') {
        return const <Saint>[];
      }
      final List<Map<String, Object?>> rows = await db.query(
        'saints',
        where: 'feast_day = ?',
        whereArgs: <String>[key],
        orderBy: 'name',
      );
      return _loadSaints(db, rows);
    }, const <Saint>[]);
  }

  /// The featured homepage set, ordered by name.
  Future<List<Saint>> getFeaturedSaints() {
    return _withDatabase<List<Saint>>((Database db) async {
      final List<Map<String, Object?>> rows = await db.query(
        'saints',
        where: 'featured = 1',
        orderBy: 'name',
      );
      return _loadSaints(db, rows);
    }, const <Saint>[]);
  }

  /// One saint by slug, with patronages hydrated (plus an empty source
  /// list — the committed schema stores no per-saint sources table).
  Future<Saint?> getBySlug(String slug) {
    return _withDatabase<Saint?>((Database db) async {
      final List<Map<String, Object?>> rows = await db.query(
        'saints',
        where: 'slug = ?',
        whereArgs: <String>[slug],
        limit: 1,
      );
      if (rows.isEmpty) {
        return null;
      }
      return (await _loadSaints(db, rows)).first;
    }, null);
  }

  /// Saints carrying a patronage in [category], ordered by name.
  Future<List<Saint>> getSaintsByCategory(
    SaintCategory category, {
    int limit = 200,
  }) {
    return _withDatabase<List<Saint>>((Database db) async {
      final List<Map<String, Object?>> rows = await db.rawQuery(
        'SELECT * FROM saints s WHERE EXISTS ('
        'SELECT 1 FROM patronages p WHERE p.slug = s.slug '
        'AND p.category = ?) ORDER BY s.name LIMIT ?',
        <Object?>[category.name, limit],
      );
      return _loadSaints(db, rows);
    }, const <Saint>[]);
  }

  /// Saints invoked for [need], including saints whose canonical need maps
  /// to it through `need_synonyms` (e.g. `lost keys` -> `lost items`).
  Future<List<Saint>> getSaintsForNeed(String need, {int limit = 100}) {
    return _withDatabase<List<Saint>>((Database db) async {
      final String normalized = normalizeSearchText(need);
      if (normalized.isEmpty) {
        return const <Saint>[];
      }
      // The canonical need itself, plus every need that lists the input
      // phrase as one of its synonyms.
      final List<Map<String, Object?>> synonymRows = await db.query(
        'need_synonyms',
        where: 'synonym = ?',
        whereArgs: <String>[normalized],
      );
      final Set<String> needs = <String>{
        normalized,
        for (final Map<String, Object?> row in synonymRows)
          row['need']! as String,
      };
      final List<Map<String, Object?>> rows = await db.rawQuery(
        'SELECT * FROM saints s WHERE EXISTS ('
        'SELECT 1 FROM patronages p WHERE p.slug = s.slug '
        "AND p.need IN (${needs.map((String _) => '?').join(', ')})) "
        'ORDER BY s.name LIMIT ?',
        <Object?>[...needs, limit],
      );
      return _loadSaints(db, rows);
    }, const <Saint>[]);
  }

  /// Tiered search over the `saint_fts` index (see the file doc comment).
  Future<List<SaintSearchResult>> searchSaints(
    String query, {
    SaintCategory? category,
    int limit = 100,
  }) {
    return _withDatabase<List<SaintSearchResult>>((Database db) async {
      final List<String> tokens = tokenizeSearchQuery(query);
      if (tokens.isEmpty) {
        return const <SaintSearchResult>[];
      }
      final String ftsTerms = buildFtsTerms(tokens);

      // Tier 1: name matches.
      final List<String> nameSlugs = await _ftsSlugs(
        db,
        'WHERE name MATCH ?',
        ftsTerms,
      );
      // Tier 2: patronage FTS matches, unioned with the direct
      // patronages-table hits for synonym-expanded canonical needs.
      final List<String> patronageSlugs = await _ftsSlugs(
        db,
        'WHERE patronages MATCH ?',
        ftsTerms,
      );
      final Set<String> candidateNeeds = await _candidateNeeds(
        db,
        tokens,
        normalizeSearchText(query),
      );
      if (candidateNeeds.isNotEmpty) {
        final List<String> placeholders = List<String>.filled(
          candidateNeeds.length,
          '?',
        );
        final List<Object?> args = <Object?>[...candidateNeeds];
        final List<Map<String, Object?>> directRows = await db.rawQuery(
          'SELECT DISTINCT slug FROM patronages '
          'WHERE need IN (${placeholders.join(', ')})',
          args,
        );
        patronageSlugs.addAll(<String>[
          for (final Map<String, Object?> row in directRows)
            row['slug']! as String,
        ]);
      }
      // Tier 3: bio or prayer matches.
      final List<String> bioSlugs = <String>[
        ...(await _ftsSlugs(db, 'WHERE bio MATCH ?', ftsTerms)),
        ...(await _ftsSlugs(db, 'WHERE prayer MATCH ?', ftsTerms)),
      ];

      // Hydrate every tier hit once, then merge tier by tier, deduped by
      // slug and ordered deterministically (name, then slug) within a
      // tier.
      final Map<String, Saint> bySlug = await _saintsBySlug(db, <String>{
        ...nameSlugs,
        ...patronageSlugs,
        ...bioSlugs,
      });
      final List<SaintSearchResult> merged = <SaintSearchResult>[];
      final Set<String> seen = <String>{};
      void addTier(List<String> slugs, String rationale) {
        final List<String> ordered =
            <String>[
              for (final String slug in slugs.toSet())
                if (bySlug.containsKey(slug)) slug,
            ]..sort((String a, String b) {
              final int byName = bySlug[a]!.name.toLowerCase().compareTo(
                bySlug[b]!.name.toLowerCase(),
              );
              return byName != 0 ? byName : a.compareTo(b);
            });
        for (final String slug in ordered) {
          // Dedupe by slug: a saint matched in several tiers keeps the
          // highest-tier (first) rationale only.
          if (seen.add(slug)) {
            merged.add(
              SaintSearchResult(
                saint: bySlug[slug]!,
                matchRationale: rationale,
              ),
            );
          }
        }
      }

      // FTS rows without a matching saints row would be a build bug; if
      // they ever appear, they are dropped here rather than crashing the
      // repository (the hydration map already omits them).
      addTier(nameSlugs, 'name');
      addTier(patronageSlugs, 'patronage');
      addTier(bioSlugs, 'bio');

      // Step 5: category filter, then limit, after the merge.
      final Iterable<SaintSearchResult> filtered = category == null
          ? merged
          : merged.where(
              (SaintSearchResult result) => result.saint.patronages.any(
                (SaintPatronage patronage) => patronage.category == category,
              ),
            );
      return filtered.take(limit).toList();
    }, const <SaintSearchResult>[]);
  }

  /// Distinct saint count per category (a saint can carry needs in
  /// multiple categories).
  Future<Map<SaintCategory, int>> getCategoryCounts() {
    return _withDatabase<Map<SaintCategory, int>>((Database db) async {
      final List<Map<String, Object?>> rows = await db.rawQuery(
        'SELECT category, COUNT(DISTINCT slug) AS n FROM patronages '
        'GROUP BY category',
      );
      return <SaintCategory, int>{
        for (final Map<String, Object?> row in rows)
          if (SaintCategory.tryParse(row['category']! as String)
              case final SaintCategory parsed)
            parsed: row['n']! as int,
      };
    }, <SaintCategory, int>{});
  }

  /// need -> distinct saint count for [category], ordered count-desc
  /// (then need-asc for stable ties) — the anchor-chip shape.
  Future<Map<String, int>> getNeedsForCategory(SaintCategory category) {
    return _withDatabase<Map<String, int>>((Database db) async {
      final List<Map<String, Object?>> rows = await db.rawQuery(
        'SELECT need, COUNT(DISTINCT slug) AS n FROM patronages '
        'WHERE category = ? GROUP BY need '
        'ORDER BY n DESC, need ASC',
        <Object?>[category.name],
      );
      return <String, int>{
        for (final Map<String, Object?> row in rows)
          row['need']! as String: row['n']! as int,
      };
    }, <String, int>{});
  }

  /// [column] filter fragment for saint_fts (e.g. `WHERE name MATCH ?`);
  /// returns the matched slugs.
  Future<List<String>> _ftsSlugs(
    Database db,
    String whereFragment,
    String ftsTerms,
  ) async {
    if (ftsTerms.isEmpty) {
      return const <String>[];
    }
    final List<Map<String, Object?>> rows = await db.rawQuery(
      'SELECT slug FROM saint_fts $whereFragment',
      <Object?>[ftsTerms],
    );
    return <String>[
      for (final Map<String, Object?> row in rows) row['slug']! as String,
    ];
  }

  /// Canonical needs whose `need_synonyms` rows list [tokens] (or the whole
  /// normalized [phrase]) as one of their synonyms.
  Future<Set<String>> _candidateNeeds(
    Database db,
    List<String> tokens,
    String phrase,
  ) async {
    final Set<String> lookups = <String>{
      ...tokens,
      if (phrase.isNotEmpty) phrase,
    };
    final Set<String> candidates = <String>{};
    for (final String lookup in lookups) {
      final List<Map<String, Object?>> rows = await db.query(
        'need_synonyms',
        where: 'synonym = ?',
        whereArgs: <String>[lookup],
      );
      for (final Map<String, Object?> row in rows) {
        candidates.add(row['need']! as String);
      }
    }
    return candidates;
  }

  /// Hydrates [slugs] into `slug -> Saint` (patronages attached; sources
  /// are not stored in the committed schema, so they stay empty).
  Future<Map<String, Saint>> _saintsBySlug(
    Database db,
    Set<String> slugs,
  ) async {
    if (slugs.isEmpty) {
      return const <String, Saint>{};
    }
    final Map<String, Saint> bySlug = <String, Saint>{};
    for (final List<String> chunk in _chunks(
      slugs.toList(),
      _inClauseChunkSize,
    )) {
      final List<Map<String, Object?>> rows = await db.query(
        'saints',
        where: 'slug IN (${List<String>.filled(chunk.length, '?').join(', ')})',
        whereArgs: chunk,
      );
      for (final Saint saint in await _loadSaints(db, rows)) {
        bySlug[saint.slug] = saint;
      }
    }
    return bySlug;
  }

  /// Builds saints from `saints` rows with their patronages hydrated.
  Future<List<Saint>> _loadSaints(
    Database db,
    List<Map<String, Object?>> rows,
  ) async {
    if (rows.isEmpty) {
      return const <Saint>[];
    }
    final Map<String, List<SaintPatronage>> patronages =
        await _patronagesBySlug(db, <String>{
          for (final Map<String, Object?> row in rows) row['slug']! as String,
        });
    return <Saint>[
      for (final Map<String, Object?> row in rows)
        Saint.fromDbRow(
          row,
          patronages:
              patronages[row['slug']! as String] ?? const <SaintPatronage>[],
          // The committed schema carries no sources table; DB-loaded
          // saints keep the (empty) default so the model field survives.
        ),
    ];
  }

  /// Grouped patronages for the given slugs, chunked to stay under any
  /// SQLite host-variable limit.
  Future<Map<String, List<SaintPatronage>>> _patronagesBySlug(
    Database db,
    Set<String> slugs,
  ) async {
    final Map<String, List<SaintPatronage>> patronages =
        <String, List<SaintPatronage>>{};
    for (final List<String> chunk in _chunks(
      slugs.toList(),
      _inClauseChunkSize,
    )) {
      final List<Map<String, Object?>> rows = await db.query(
        'patronages',
        where: 'slug IN (${List<String>.filled(chunk.length, '?').join(', ')})',
        whereArgs: chunk,
      );
      for (final Map<String, Object?> row in rows) {
        final SaintCategory? category = SaintCategory.tryParse(
          row['category']! as String,
        );
        if (category == null) {
          SaintLogger.warning(
            'Skipping patronage row with unknown category: '
            '${row['category']}',
            tag: _tag,
          );
          continue;
        }
        patronages
            .putIfAbsent(row['slug']! as String, () => <SaintPatronage>[])
            .add(
              SaintPatronage(need: row['need']! as String, category: category),
            );
      }
    }
    return patronages;
  }
}

/// Splits [items] into fixed-size chunks.
Iterable<List<T>> _chunks<T>(List<T> items, int size) sync* {
  for (int start = 0; start < items.length; start += size) {
    yield items.sublist(
      start,
      start + size < items.length ? start + size : items.length,
    );
  }
}
