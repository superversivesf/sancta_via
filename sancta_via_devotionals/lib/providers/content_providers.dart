// Riverpod wiring for the devotional content pipeline (Plan 2, Task 6).
//
// Two pieces:
//
// 1. [appProgramRepositoryProvider] — the app's real content repository
//    ([SqliteProgramRepository] over the runtime `devotionals.db`), plus
//    [programRepositoryOverride], the root-scope override that routes the
//    wrapper package's catalog providers (`enrolledProgramsProvider`,
//    `todayProgramsProvider`, `programDetailProvider`) through that same
//    repository instead of its in-memory fixture default.
//
// 2. [contentLoadedProvider] — the whole content catalog, guaranteed seeded:
//    watching it runs [ContentAssetService.ensureContentLoaded] (the
//    first-launch migration; a version match afterwards is a no-op) and the
//    migration's errors surface as the provider's error state.
//
// Enrolled-vs-catalog: [contentLoadedProvider] hands back the WHOLE store
// catalog (`loadPacks`, id ASC order); app-level "enrolled" filtering belongs
// to the wrapper's enrollment-aware providers (`enrollmentParamsFor(packId)
// != null`), not here. No file here needs the `hide AppLogger` shared_ui
// guard — none imports both `sancta_via_shared_ui` and the local logger.
library;

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sancta_via_devotional_engine/sancta_via_devotional_engine.dart';
import 'package:sancta_via_devotional_engine_riverpod/sancta_via_devotional_engine_riverpod.dart'
    show programRepositoryProvider;

import '../repositories/program_repository.dart';
import '../services/content_asset_service.dart';

/// The app's real content repository over the runtime devotionals database.
final Provider<SqliteProgramRepository> appProgramRepositoryProvider =
    Provider<SqliteProgramRepository>((Ref ref) => SqliteProgramRepository());

/// The root-scope override for the wrapper's [programRepositoryProvider]:
/// installs [appProgramRepositoryProvider] beneath it so the wrapper's
/// providers flow from the app's SQLite repository — the exact instance the
/// content pipeline seeds. `main.dart` puts this on the root [ProviderScope].
final Override programRepositoryOverride = programRepositoryProvider
    .overrideWith((Ref ref) => ref.watch(appProgramRepositoryProvider));

/// The whole catalog of devotional programs, guaranteed seeded.
///
/// Runs the version-stamped first-launch migration every time it first
/// becomes active; afterwards the version check makes re-runs a no-op. A
/// content authoring error (e.g. a malformed pack asset) surfaces here as
/// the provider's error state.
final FutureProvider<List<ContentPack>> contentLoadedProvider =
    FutureProvider<List<ContentPack>>((Ref ref) {
      final SqliteProgramRepository repository = ref.watch(
        appProgramRepositoryProvider,
      );
      final ContentAssetService service = ContentAssetService(
        assets: rootBundle,
        repository: repository,
        // The repository's OWN store (fix round 1: no separate
        // DevotionalsDatabase.instance), so the seed and the removed-pack
        // reconciliation act on one and the same database — the
        // split-brain hazard (prune one store, catalog another) cannot
        // recur, and an injected test repository carries its own store
        // through.
        database: repository.database,
      );
      return service.ensureContentLoaded();
    });
