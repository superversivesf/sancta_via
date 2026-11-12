/// Riverpod providers over the saint data repository: the repository they
/// read through, today's feast-day saints, the featured set, category
/// counts, category and need browsing, search, and per-slug lookup.
///
/// The providers are a thin reactive seam: every query is delegated to
/// `sancta_via_saint_data`'s [SaintRepository]; nothing here re-implements
/// repository semantics. Tests override [saintRepositoryProvider] with
/// `saintRepositoryProvider.overrideWithValue(
/// SaintRepository.forDatabase(fixtureDb))`.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:saint_data/saint_data.dart';

/// The saint data repository every saint data provider reads through.
///
/// Production resolves the process-wide [SaintRepository.instance]; tests
/// and alternate wiring override with `SaintRepository.forDatabase(...)`.
final Provider<SaintRepository> saintRepositoryProvider =
    Provider<SaintRepository>((Ref ref) => SaintRepository.instance);

/// Resolves the repository through [saintRepositoryProvider] and guarantees
/// its database is open before the first query.
///
/// [SaintRepository.ensureLoaded] is a no-op once loaded and when a
/// database was injected, so this is cheap when watched repeatedly.
Future<SaintRepository> _loadedRepository(Ref ref) async {
  final SaintRepository repository = ref.watch(saintRepositoryProvider);
  await repository.ensureLoaded();
  return repository;
}

/// Saints whose stored feast day is today (`MM-DD` via
/// [SaintFeastService.feastKeyForDate]); unknown-feast saints never match.
/// The calendar year is captured alongside the key so the repository's
/// Feb-29 lookup-side fallback resolves against the same captured date
/// (final-review ruling: in non-leap years the '02-28' lookup unions the
/// '02-29' saints).
///
/// Staleness: `DateTime.now()` is captured at first provider use, so the
/// result refreshes on app restart or an `invalidate()` of this provider;
/// the house `currentDateProvider` pattern could drive live rollover later.
final FutureProvider<List<Saint>> saintsTodayProvider =
    FutureProvider<List<Saint>>((Ref ref) async {
      final SaintRepository repository = await _loadedRepository(ref);
      final DateTime now = DateTime.now();
      return repository.getSaintsForFeastDay(
        SaintFeastService.feastKeyForDate(now),
        year: now.year,
      );
    });

/// The featured homepage set, ordered by name.
final FutureProvider<List<Saint>> featuredSaintsProvider =
    FutureProvider<List<Saint>>((Ref ref) async {
      final SaintRepository repository = await _loadedRepository(ref);
      return repository.getFeaturedSaints();
    });

/// Distinct saint count per patronage category (a saint can carry needs in
/// multiple categories); categories with zero saints are absent.
final FutureProvider<Map<SaintCategory, int>> categoryCountsProvider =
    FutureProvider<Map<SaintCategory, int>>((Ref ref) async {
      final SaintRepository repository = await _loadedRepository(ref);
      return repository.getCategoryCounts();
    });

/// Saints carrying a patronage in [category], ordered by name.
final FutureProviderFamily<List<Saint>, SaintCategory>
saintsByCategoryProvider = FutureProvider.family<List<Saint>, SaintCategory>((
  Ref ref,
  SaintCategory category,
) async {
  final SaintRepository repository = await _loadedRepository(ref);
  return repository.getSaintsByCategory(category);
});

/// Need -> distinct saint count within [category], ordered count-desc then
/// need-asc — the repository's anchor-chip shape for the category detail
/// screen's need chips.
final FutureProviderFamily<Map<String, int>, SaintCategory>
needsForCategoryProvider =
    FutureProvider.family<Map<String, int>, SaintCategory>((
      Ref ref,
      SaintCategory category,
    ) async {
      final SaintRepository repository = await _loadedRepository(ref);
      return repository.getNeedsForCategory(category);
    });

/// Saints invoked for [need] (direct patronage matches plus saints matched
/// via bidirectional synonym expansion), ordered by name.
final FutureProviderFamily<List<Saint>, String> saintsByNeedProvider =
    FutureProvider.family<List<Saint>, String>((Ref ref, String need) async {
      final SaintRepository repository = await _loadedRepository(ref);
      return repository.getSaintsForNeed(need);
    });

/// Tiered search for [query] restricted to [categoryOrNull] (null = all
/// categories), results ordered name-tier first; results carry the
/// match rationale.
///
/// Family key is the `(query, categoryOrNull)` record, so a cached result
/// is reused for the same query + category combination only.
final FutureProviderFamily<List<SaintSearchResult>, (String, SaintCategory?)>
saintSearchProvider =
    FutureProvider.family<List<SaintSearchResult>, (String, SaintCategory?)>((
      Ref ref,
      (String, SaintCategory?) key,
    ) async {
      final SaintRepository repository = await _loadedRepository(ref);
      return repository.searchSaints(key.$1, category: key.$2);
    });

/// One saint by slug (null when the slug is unknown), with patronages
/// hydrated.
final FutureProviderFamily<Saint?, String> saintBySlugProvider =
    FutureProvider.family<Saint?, String>((Ref ref, String slug) async {
      final SaintRepository repository = await _loadedRepository(ref);
      return repository.getBySlug(slug);
    });
