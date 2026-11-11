# Sancta Via Saint Companion Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship `sancta_via_saint_data` (SQLite data package built from the 2,174-saint `saint-for-that` dataset) and `sancta_via_saint_companion` (Flutter app: need-based lookup, search, daily saints, favorites), per spec `docs/superpowers/specs/2026-11-11-saint-companion-design.md`.

**Architecture:** Data package owns models, SQLite store (`assets/saints.db`, FTS4), source snapshot, and build tooling; app package owns Riverpod providers, GoRouter screens, and liturgical theming via shared packages. Repository is an injectable-DB singleton; build scripts share schema code with tests.

**Tech Stack:** Flutter/Dart 3.9+, sqflite (FTS4), flutter_riverpod 2, go_router, shared packages (`sancta_via_shared_ui`, `sancta_via_liturgical_calendar[_riverpod]`), melos workspace; build tools: `sqflite_common_ffi`, `http`, `image`, `crypto`.

**Spec:** `docs/superpowers/specs/2026-11-11-saint-companion-design.md`

## Global Constraints

- Dart SDK `^3.9.2`, Flutter `>=3.9.2` (match `liturgical_calendar_app` pubspec).
- Pubspec names are **un-prefixed**: `saint_data`, `saint_companion`; dirs `sancta_via_saint_data`, `sancta_via_saint_companion` (melos scope `sancta_via_*` picks both up automatically).
- SQLite: `sqflite: ^2.3.3+1` only (no drift). **FTS4, never FTS5** (Android device sqlite compatibility). `PRAGMA user_version = 1` = `saintsSchemaVersion`; bump only when schema changes.
- Runtime DB is never written by the app (read-only usage; sqlite may write its own metadata).
- Asset paths at runtime: `'assets/saints.db'` and `'assets/thumbs/<slug>.jpg'` resolved with `package: 'saint_data'` (i.e. `Image.asset('assets/thumbs/$slug.jpg', package: 'saint_data')`).
- Search normalization: lowercase, diacritics folded, non-alphanumeric characters stripped, whitespace collapsed — one shared function `normalizeSearchText` used by build AND query sides.
- Style (AGENTS.md): single quotes; trailing commas; explicit types (no `var`/`dynamic`); `final`/`const` by default; keys in widget constructors; import order dart → package → relative with blank-line groups; `AppLogger`-equivalent local logger in `saint_data` (matching `sancta_via_bible_data`'s own `utils/logger.dart`), tags `SAINT_DATA`.
- New app: `applicationId`/bundle id `net.superversive.sancta_via.saint_companion` (from `--org net.superversive.sancta_via`), display name "Sancta Via Saints", initial version `1.0.0+1`.
- Platforms v1: Android + iOS only. No web build target in the Makefile.
- Never modify sibling repo `/Users/jason/Repos/saint-for-that` or its files; read it only in the snapshot-fetch script (default path `../saint-for-that`, overridable).
- English-only content; no l10n toolchain.
- Every task ends with `dart format .`, `flutter analyze` (0 issues) and a commit.

## Review Focus

Five inputs/failure modes not fully exercised by task tests; each is pinned by the named test:

1. **Feb 29 feast in a non-leap year** — the saint should appear under Feb 28, never be lost. → Task 3: `feastKeyForDate(DateTime(2025, 2, 29))` returns `'02-28'`; leap year 2028 returns `'02-29'`.
2. **Search input with punctuation/diacritics/FTS operators** (`"Thérèse"`, `"st. john's (of the cross)"`, `""`) — must never throw and must behave like the folded tokens. → Task 3: `normalizeSearchText` unit tests; Task 7: `searchSaints("\"therese\" OR NOT")` returns Thérèse results without throwing.
3. **Saints with `feastDay: 'unknown'`** — never on the daily feed, still findable by category/search. → Task 7: `getSaintsForFeastDay` excludes unknowns; Task 11: home empty state renders when today has no saints.
4. **Saint without a bundled thumbnail** (image download failed at build time) — placeholder renders, image never fetched over network. → Task 13: `SaintDetailScreen` widget test with `thumb_asset: null` asserts placeholder and no `Image.network` widgets.
5. **On-disk DB older than bundled DB after an app update** — loader must re-copy (`user_version` check) so users never see stale data. → Task 7: `needsAssetRecopy(bundledVersion: 2, diskVersion: 1)` is `true`, same-version is `false`.

## File Structure

### `sancta_via_saint_data/` (pubspec `saint_data`)

```
pubspec.yaml                       # name saint_data; deps sqflite, path, flutter; dev: flutter_test, sqflite_common_ffi, mocktail? (none needed), http, image, crypto, flutter_lints
lib/saint_data.dart                # barrel
lib/src/models/saint.dart          # Saint, SaintPatronage, SaintPrayer
lib/src/models/saint_category.dart # SaintCategory enum (10 ids + label + description)
lib/src/models/saint_search_result.dart
lib/src/utils/logger.dart          # SaintLogger (debug/info/warning/error, tag REQUIRED param)
lib/src/utils/normalization.dart   # normalizeSearchText(String) -> String
lib/src/services/saint_feast_service.dart
lib/src/db/saints_schema.dart      # saintsSchemaVersion, createSaintsDatabase(Database), table/DDL constants
lib/src/services/saints_db_loader.dart  # openSaintsDatabase(), needsAssetRecopy()
lib/src/services/saint_repository.dart
data/saints_source.json            # combined snapshot (committed by Task 4)
data/needs_synonyms.json           # [{need, synonyms[]}] (committed by Task 4)
data/categories.json               # 10 categories verbatim from taxonomy.ts (committed by Task 4)
data/manifest.json                 # sha256/counts/commit (committed by Task 4)
data/image_failures.json           # produced by Task 6 (may be empty)
tools/fetch_snapshot.dart
tools/build_saints_db.dart
tools/fetch_saint_images.dart
assets/saints.db                   # built by Task 5
assets/thumbs/<slug>.jpg           # built by Task 6
test/...                           # mirrors lib/src layout
```

### `sancta_via_saint_companion/` (pubspec `saint_companion`)

```
pubspec.yaml                       # app_store block; path deps: saint_data, shared_ui, liturgical_calendar, liturgical_calendar_riverpod
Makefile                           # copy of liturgical_calendar_app Makefile; APP_NAME := saint_companion; no build-web
lib/main.dart
lib/app/app.dart                   # SaintCompanionApp: AppTheme from currentLiturgicalColorProvider
lib/config/routes.dart             # appRouter (7 routes + errorBuilder)
lib/models/saint_app_settings.dart
lib/providers/saint_providers.dart # saintRepositoryProvider + data providers
lib/providers/saint_app_settings_provider.dart
lib/screens/home/home_screen.dart
lib/screens/categories/categories_screen.dart
lib/screens/categories/category_detail_screen.dart
lib/screens/search/search_screen.dart
lib/screens/saint_detail/saint_detail_screen.dart
lib/screens/favorites/favorites_screen.dart
lib/screens/settings/settings_screen.dart
lib/widgets/saint_image.dart       # Asset thumb w/ placeholder fallback
lib/widgets/saint_card.dart
lib/widgets/patronage_chip.dart
lib/widgets/category_card.dart
lib/widgets/liturgical_day_card.dart
test/...                           # one test file per screen/provider (flutter_test + mocktail)
assets/app_icon.png                # placeholder: copy of liturgical_calendar_app icon
android/, ios/                     # from flutter create
```

---

### Task 1: `saint_data` package scaffold

**Files:** Create `sancta_via_saint_data/pubspec.yaml`, `lib/saint_data.dart`, `lib/src/utils/logger.dart`, `test/logger_test.dart`

**Interfaces (Produces):**
- `SaintLogger.debug(String message, {required String tag})`, `.info`, `.warning`, `.error(String message, Object error, StackTrace stackTrace, {required String tag})` — stdout in debug builds only (`kDebugMode`), matching `sancta_via_bible_data/lib/utils/logger.dart` shape.
- `lib/saint_data.dart` barrel: `export 'src/utils/logger.dart';` (grows in later tasks).

- [ ] **Step 1: Create package files** — pubspec:

```yaml
name: saint_data
description: Saint dataset, SQLite store, and search for Sancta Via apps
publish_to: 'none'
version: 0.1.0
environment:
  sdk: ^3.9.2
dependencies:
  flutter:
    sdk: flutter
  path: ^1.9.0
  sqflite: ^2.3.3+1
dev_dependencies:
  crypto: ^3.0.0
  flutter_lints: ^6.0.0
  flutter_test:
    sdk: flutter
  http: ^1.2.0
  image: ^4.2.0
  sqflite_common_ffi: ^2.3.0
flutter:
  assets:
    - assets/
```

(Do NOT list `assets/` sub-entries yet — `assets/saints.db` is added in Task 5; empty `assets/` dir must exist with a `.gitkeep` until then.)

- [ ] **Step 2: Write `test/logger_test.dart`** — `SaintLogger.error('x', e, st, tag: 'SAINT_DATA')` does not throw (smoke).
- [ ] **Step 3:** `cd sancta_via_saint_data && flutter test` → PASS (1 test).
- [ ] **Step 4: Commit** `feat(saint_data): scaffold saint data package`.

### Task 2: Models — `Saint`, `SaintPatronage`, `SaintPrayer`, `SaintCategory`, `SaintSearchResult`

**Files:** Create `lib/src/models/{saint.dart, saint_category.dart, saint_search_result.dart}`, `test/models/saint_model_test.dart`; Modify barrel to export models.

**Interfaces (Produces):**

```dart
enum SaintCategory {
  everyday, illness, jobs, travel, persecution, spiritual, military, family, nature, special;
  static SaintCategory? tryParse(String id);
  String get label;   // 'Illness & healing', 'Jobs & professions', 'Travel & transport',
                      // 'Persecution & prisoners', 'Spiritual life', 'Military & first responders',
                      // 'Children & family', 'Animals & nature', 'Special intentions',
                      // 'Everyday life'  (verbatim from saint-for-that taxonomy.ts)
  String get description; // same descriptions verbatim
}
class SaintPatronage { final String need; final SaintCategory category; factory fromJson(Map<String, dynamic>); Map<String, dynamic> toJson(); }
class SaintPrayer { final String text; final String source; // 'traditional' | 'original'
  factory fromJson(Map<String, dynamic>); bool get isValid; }
class Saint {
  final String slug; final String name; final String feastDay; // 'MM-DD' or 'unknown'
  final String? canonized; final String bio; final SaintPrayer? prayer;
  final List<SaintPatronage> patronages; final bool featured;
  final String? thumbAsset;        // relative 'assets/thumbs/<slug>.jpg' or null
  final String? imageAttribution; final String? imageAlt;
  final List<String> sources;
  factory Saint.fromSourceJson(Map<String, dynamic> json); // parses the RAW saint-for-that record
  factory Saint.fromDbRow(Map<String, dynamic> row, {List<SaintPatronage> patronages, List<String> sources});
  Map<String, dynamic> toSourceJson(); // round-trip
  bool get hasImage; bool get hasPrayer; bool get hasKnownFeast;
}
class SaintSearchResult { final Saint saint; final String matchRationale; // 'name' | 'patronage' | 'bio'
  const SaintSearchResult({required this.saint, required this.matchRationale}); }
```

- [ ] **Step 1: Write failing tests** `test/models/saint_model_test.dart`:
  - inline fixture JSON (based on real `abba-garima.json`: 2 patronages `monks`/`missionaries` category `spiritual`, prayer `original`); `Saint.fromSourceJson` → all fields parse; `hasPrayer` true; `hasImage` false.
  - fixture with `"image": {"url": "https://…", "attribution": "…", "altText": "..."}`, `draft: true`, `featured: true` → parse; `toSourceJson().then(fromSourceJson)` equals original (round-trip equality on every field).
  - `SaintCategory.tryParse('illness')` → `SaintCategory.illness` with label `'Illness & healing'`; `tryParse('bogus')` → `null`; all 10 labels non-empty.
  - fixture with no `prayer` key → `Saint.prayer == null`, `hasPrayer` false.
- [ ] **Step 2:** `flutter test` → fails (models undefined). **Step 3: implement models.** **Step 4:** `flutter test` → PASS. 
- [ ] **Step 5: Commit** `feat(saint_data): saint models and category enum`.

### Task 3: `SaintFeastService` + `normalizeSearchText`

**Files:** Create `lib/src/services/saint_feast_service.dart`, `lib/src/utils/normalization.dart`, `test/services/saint_feast_service_test.dart`, `test/utils/normalization_test.dart`; Modify barrel.

**Interfaces (Produces):**

```dart
class SaintFeastService {
  static String feastKeyForDate(DateTime date); // 'MM-DD'; Feb 29 -> '02-28' in non-leap years
  static bool isLeapYear(int year);
}
String normalizeSearchText(String input); // lowercase, fold diacritics (é->e, ö->o, ñ->n, etc.),
                                          // strip all non [a-z0-9 ] chars, collapse runs of spaces
List<String> tokenizeSearchQuery(String query); // normalizeSearchText + split(' ') + remove empties
```

- [ ] **Step 1: Write failing tests:**
  - feast: `feastKeyForDate(DateTime(2026, 3, 5))` == `'03-05'`; `(DateTime(2025, 2, 29))` == `'02-28'`; `(DateTime(2028, 2, 29))` == `'02-29'`; single-digit month/day zero-padded.
  - normalization: `normalizeSearchText('St. Thérèse of Lisieux')` == `'st therese of lisieux'`; `tokenizeSearchQuery("  \\"Émile's —  Café!" )` == `['emiles', 'cafe']`; `normalizeSearchText('   ')` == `''`; `tokenizeSearchQuery('')` == `[]`.
- [ ] **Step 2:** FAIL. **Step 3: implement.** **Step 4: PASS.** **Step 5: Commit** `feat(saint_data): feast-day service and search normalization`.

### Task 4: Source snapshot fetch (`tools/fetch_snapshot.dart`)

**Files:** Create `tools/fetch_snapshot.dart`, `lib/src/db/manifest.dart`, `test/db/manifest_test.dart`. **Run once; commit data outputs.**

**Interfaces (Produces):**
- `data/manifest.json` (read by Task 5's build + tests):

```json
{
  "sourceRepo": "/Users/jason/Repos/saint-for-that",
  "sourceCommit": "<git rev-parse HEAD of sibling repo>",
  "fetchedAt": "2026-11-11T…",
  "saintCount": 2174,
  "categoryCounts": {"everyday": 0, "illness": 0, …},
  "snapshotSha256": "…"
}
```

- `Map<String, Object> buildManifest(...)` — pure function in `lib/src/db/manifest.dart`: signature `Map<String, Object> buildManifest({required int saintCount, required Map<String, int> categoryCounts, required String sourceRepo, required String sourceCommit, required DateTime fetchedAt, required String snapshotSha256})`; `String sha256OfBytes(List<int>)` wraps `package:crypto`.

- [ ] **Step 1: Write failing test** `test/db/manifest_test.dart`: `buildManifest` fills all keys; `sha256OfBytes('abc'.codeUnits)` equals the known sha256 of "abc" (`ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad`).
- [ ] **Step 2:** FAIL → **implement** → PASS.
- [ ] **Step 3: Implement `tools/fetch_snapshot.dart`** — reads each `data/saints/*.json` from `--source ../saint-for-that` (path arg), writes:
  - `data/saints_source.json` = `{"saints": [ <raw records in sorted-slug order> ]}`
  - `data/needs_synonyms.json` = `[{"need": <key>, "synonyms": [...]}, …]` — ported from `saint-for-that/site/src/lib/taxonomy.ts` `NEED_SYNONYMS` (hardcode the port inside the tool as a copy: read the TS file, extract entries between `export const NEED_SYNONYMS` and the closing `};` via a regex that captures `'key': [ 'a', … ]` pairs, JSON5-tolerant: single quotes → double quotes; verify count ≈185 keys and print it).
  - `data/categories.json` = the 10 `{id, label, description}` objects verbatim (hardcoded in the tool to match taxonomy.ts lines 8–17).
  - `data/manifest.json` via `buildManifest` (sha256 over `saints_source.json` bytes; `categoryCounts` from raw records).
- [ ] **Step 4: Run:** `dart run tools/fetch_snapshot.dart` (in package dir). Expected: prints `saints: 2174`, synonym keys ~= count of NEED_SYNONYMS keys in taxonomy.ts, all 10 categories written; every file valid JSON.
- [ ] **Step 5: Verify counts:**
  ```bash
  python3 -c "import json;d=json.load(open('data/saints_source.json'));print(len(d['saints']));print(sum(1 for s in d['saints'] if s['feastDay']=='unknown'));print(sum(1 for s in d['saints'] if s.get('image')))"
  ```
  Expected: `2174`, `508`, `1443`. `data/needs_synonyms.json` contains `'lost items'` with `'lost keys'` among its synonyms.
- [ ] **Step 6: Commit** `feat(saint_data): import saint-for-that dataset snapshot and manifest` (includes data files).

### Task 5: Schema + `saints.db` build tool

**Files:** Create `lib/src/db/saints_schema.dart`, `tools/build_saints_db.dart`, `test/db/saints_schema_test.dart`, `test/db/saints_db_integration_test.dart`; Modify `pubspec.yaml` assets block (`- assets/` stays; file lands); Modify `lib/saint_data.dart` (export schema + normalization).

**Interfaces (Produces):**

```dart
const int saintsSchemaVersion = 1;
const List<String> saintsSchemaStatements = <String>[ /* exact DDL from spec §6, FTS4, unicode61 */ ];
Future<void> createSaintsDatabase(Database db); // runs statements, then PRAGMA user_version = saintsSchemaVersion
// FTS rows are filled by the build tool with pre-normalized text.
```

DDL exact content (spec §6, verbatim semantics): `saints` (11 cols), indexes `idx_saints_feast`, `idx_saints_featured`; `patronages` + 2 indexes; `need_synonyms` + `idx_synonyms_synonym`; `CREATE VIRTUAL TABLE saint_fts USING fts4(slug, name, patronages, bio, prayer, tokenize = 'unicode61')`.

- [ ] **Step 1: Write failing test** `test/db/saints_schema_test.dart` (setUp: `databaseFactory = databaseFactoryFfi; sqlite3.tempDirectory`-backed `openDatabase(inMemory)`):
  - `createSaintsDatabase` → `PRAGMA user_version` == `1`; inserting a saint + 2 patronages + synonym works; inserting duplicate slug fails; `SELECT * FROM saint_fts WHERE saint_fts MATCH 'monk*'` returns the seeded FTS row.
- [ ] **Step 2:** FAIL → **implement schema** → PASS.
- [ ] **Step 3: Implement `tools/build_saints_db.dart`**:
  - `main()`: set `sqfliteFfiInit(); databaseFactory = databaseFactoryFfi;`
  - Load `data/saints_source.json`; validate every record with the Task 2 schema checks (slug kebab-case 1–100, name 1–200, feastDay `MM-DD`-valid or `unknown`, bio 10–10,000, ≥1 patronage with need lowercase ≤4 words + known category, prayer ≤2,000 + valid source, image URL/attribution valid). Collect violations; **exit 1 listing offending slugs** if any. Skip `draft: true` records (count printed).
  - Delete existing `assets/saints.db`; `openDatabase('assets/saints.db')`; `createSaintsDatabase`; insert saints (fts text = `normalizeSearchText(name)` / joined normalized patronage needs / normalized bio / normalized prayer text); insert `need_synonyms` from `data/needs_synonyms.json`; `VACUUM`; close.
  - Print summary: counts per table, synonym needs missing from data (warnings only), total file size.
- [ ] **Step 4: Run:** `dart run tools/build_saints_db.dart`. Expected: `2174` saints, `0` drafts skipped, exit 0, `assets/saints.db` exists.
- [ ] **Step 5: Write integration test** `test/db/saints_db_integration_test.dart` (opens committed `assets/saints.db` read-only via `databaseFactoryFfi.openDatabase(<abs path>)` — file path = `Directory.current.path` + `/assets/saints.db`, works from package dir under `flutter test`):
  - row count `saints` == manifest `saintCount` (2174); patronages rows > 8,000 (sanity: 2,174 min 1 each, expect ~9k; assert `> 8000`); every `patronages.category` ∈ 10 ids; `feast_day` values match `^\d{2}-\d{2}$|unknown`; FTS `MATCH 'therese*'` finds at least one row; `SELECT COUNT(*) FROM saints WHERE featured=1` == manifest-independent count `>= 1` (print it; expected 6).
  - `PRAGMA user_version` == 1.
- [ ] **Step 6:** `flutter test` → PASS. **Step 7: Commit** `feat(saint_data): build saints.db with fts4 search (2174 saints)`.

### Task 6: Image thumbnails (`tools/fetch_saint_images.dart`)

**Files:** Create `tools/fetch_saint_images.dart`, `test/tools/thumb_url_test.dart`, `data/image_failures.json` (output), `assets/thumbs/` (output). **Network step: one-time, resumable.**

**Interfaces (Produces):** `String wikimediaThumbUrl(String url, {int width = 256})` — for URLs containing `/thumb/`…`/<w>px-<name>`, rewrites `<w>` up to `max(width, 256)`; non-thumb URLs returned unchanged; unit-tested pure.

- [ ] **Step 1: Write failing test** `test/tools/thumb_url_test.dart`: a real-shape Wikimedia thumb URL `'https://upload.wikimedia.org/wikipedia/commons/thumb/8/88/Fresco.jpg/220px-Fresco.jpg'` → `…/256px-Fresco.jpg`; width 512 → `512px`; non-thumb `'https://example.org/a.jpg'` unchanged; malformed returns unchanged. **Step 2:** FAIL → **implement** → PASS.
- [ ] **Step 3: Implement tool:** iterate saints with images from `data/saints_source.json`; skip existing thumb unless `--force`; fetch (`http.get` with required Wikimedia-compliant `User-Agent: 'SanctaViaSaintDataBuild/1.0 (+https://sancta-via.net)'`), decode via `package:image`, center-crop square (`copyCrop`), `copyResize(256, 256)`, `encodeJpg(quality: 80)` → `assets/thumbs/<slug>.jpg`; failures → retry once, then append `{slug, url, error}` to `data/image_failures.json`; print progress every 100.
  - `--limit N` flag for smoke runs.
- [ ] **Step 4: Smoke run:** `dart run tools/fetch_saint_images.dart --limit 20` → 20 thumbs produced (or failures recorded).
- [ ] **Step 5: Full run** (background-capable, ~30–60 min): `dart run tools/fetch_saint_images.dart` → re-run once more (idempotent skip) to confirm "0 downloaded, 1443 present or N failures listed". Expected: ≥1,400 thumbs, `data/image_failures.json` small (<~50 entries).
- [ ] **Step 6: Update pubspec** assets: add `- assets/thumbs/` line. **Step 7:** `flutter test` still green; **Commit** `feat(saint_data): generate 256px saint thumbnails (~<N> images, <N> failures)`.

### Task 7: DB loader + `SaintRepository` (+ search)

**Files:** Create `lib/src/services/saints_db_loader.dart`, `lib/src/services/saint_repository.dart`, `test/services/saints_db_loader_test.dart`, `test/services/saint_repository_test.dart`; Modify `pubspec.yaml` assets (add `- assets/saints.db`), barrel exports.

**Interfaces (Produces):**

```dart
// lib/src/services/saints_db_loader.dart
bool needsAssetRecopy({required int bundledVersion, required int diskVersion}); // bundled > disk
Future<Database> openSaintsDatabase({String databaseAssetPath = 'assets/saints.db', String dbName = 'saints.db'});
// mirrors SqliteBibleLoader: getDatabasesPath(); copy from rootBundle if missing OR needsAssetRecopy
// (PRAGMA user_version), AsyncLock-guarded, AppLogger tags 'SAINT_DATA'. Opens writable (sqlite needs metadata writes).

// lib/src/services/saint_repository.dart
class SaintRepository {
  SaintRepository._internal();                 // singleton _instance + static instance getter
  SaintRepository.forDatabase(Database database); // @visibleForTesting injection
  Future<void> ensureLoaded();                 // no-op when injected; else openSaintsDatabase()
  Future<List<Saint>> getSaintsForFeastDay(String feastKey);   // exact match on feast_day; never 'unknown'
  Future<List<Saint>> getFeaturedSaints();                     // featured=1, ORDER BY name
  Future<Saint?> getBySlug(String slug);                       // + patronages + sources
  Future<List<Saint>> getSaintsByCategory(SaintCategory category, {int limit = 200});
  Future<List<Saint>> getSaintsForNeed(String need, {int limit = 100});
  Future<List<SaintSearchResult>> searchSaints(String query, {SaintCategory? category, int limit = 100});
  Future<Map<SaintCategory, int>> getCategoryCounts();
  Future<Map<String, int>> getNeedsForCategory(SaintCategory category); // need -> saint count, desc
}
```

Search algorithm (implement exactly):
1. `tokenizeSearchQuery(query)`; if empty → `[]`.
2. Expand: for each token, look up `need_synonyms` rows with `synonym = token` → add their `need` as candidate need-phrases (e.g. `lost keys` → `lost items`).
3. FTS per tier with OR-joined prefix terms built by `String buildFtsTerms(List<String> terms)` → each term normalized, trailing `*` appended, joined with `' OR '` (quoting whole token for safety, e.g. `"therese"*` — tests cover operator-mangling).
4. Run three queries against `saint_fts`: `WHERE name MATCH ?`, `WHERE patronages MATCH ?`, `WHERE bio MATCH ? OR prayer MATCH ?` (+ join to saints for category filter via saint slug list when `category != null`); order results tier 1 → 2 → 3, dedupe by slug, attach rationale `name`/`patronage`/`bio`; also union direct `patronages.need IN (candidate need-phrases)` into tier 2.
5. Apply `category` filter and `limit` after merge.

- [ ] **Step 1: Write failing tests** `test/services/saint_repository_test.dart` (setUp: ffi in-memory DB + `createSaintsDatabase` + seed fixture: saints `anthony-of-padua` (patronages `lost items`/`everyday`), `therese-of-lisieux` (name has é, patronage `missions`/`spiritual`), `joan-of-arc` (bio contains `'lost battles'`, patronage `soldiers`/`military`), `george` (patronage `soldiers`/`travel`... use `military`), one `unknown-feast` saint, 6 featured only if needed; synonyms for `lost items` → `['lost keys', 'misplaced objects']`):
  - `getBySlug('anthony-of-padua')` returns saint with 1 patronage; unknown slug → null.
  - `getSaintsForFeastDay` returns seeded saints for their seeded feast_day keys and **never** the unknown-feast saint.
  - `searchSaints('lost keys')` → Anthony first with rationale `patronage` (synonym expansion); `searchSaints('therese')` → Thérèse with rationale `name` (diacritic folding); `searchSaints('"therese" OR NOT')` → no throw, same result.
  - tier ordering: `searchSaints('soldiers')` → Joan/George (patronage tier) before any bio-only match; if a seeded name-only match exists it is first.
  - `searchSaints('', category: SaintCategory.military)` → `[]`; `searchSaints('joan', category: SaintCategory.military)` → Joan; same query with `category: SaintCategory.nature` → `[]`.
  - `getSaintsForNeed('lost items')` → Anthony; `getSaintsForNeed('lost keys')` → Anthony (synonym).
  - `getCategoryCounts()` sums == seeded total per category; `getNeedsForCategory(SaintCategory.military)['soldiers']` == 2.
  - `getFeaturedSaints()` returns only featured.
  - `needsAssetRecopy(bundledVersion: 2, diskVersion: 1)` true; equal versions false; bundled 1, disk 2 false.
- [ ] **Step 2:** FAIL → **implement loader + repository** → **Step 3: PASS.**
- [ ] **Step 4: Asset integration check:** run `dart run` of a scratch (test-only) snippet or add to integration test: open committed `assets/saints.db` through repository injected path: `searchSaints('lost keys').isNotEmpty == true`.
- [ ] **Step 5: Commit** `feat(saint_data): saint repository with fts search, synonyms, feast-day and category queries`.

### Task 8: `saint_companion` app scaffold

**Files:** Create `sancta_via_saint_companion/` (flutter create), `pubspec.yaml` (template values, below), `lib/main.dart`, `lib/app/app.dart`, `lib/config/routes.dart`, `lib/screens/home/home_screen.dart` (placeholder), `test/app_smoke_test.dart`, `Makefile` (copy of liturgical app's, `APP_NAME := saint_companion`, **no** `build-web` target), `assets/app_icon.png` (copy placeholder from `../sancta_via_liturgical_calendar_app/assets/app_icon.png`), `analysis_options.yaml` (copy liturgical app's).

**pubspec deps (exact):** `flutter_riverpod: ^2.6.1`, `go_router: ^15.1.2`, `intl: ^0.20.2`, `package_info_plus: ^8.3.0`, `shared_preferences: ^2.5.3`, path deps `saint_data`, `sancta_via_shared_ui`, `sancta_via_liturgical_calendar`, `sancta_via_liturgical_calendar_riverpod`, dev deps `cider`, `flutter_launcher_icons`, `flutter_lints: ^6.0.0`, `flutter_test`, `mocktail: ^1.0.0`; `app_store.display_name: "Sancta Via Saints"`; `version: 1.0.0+1`.

**Interfaces (Produces):**

```dart
// lib/config/routes.dart
final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  routes: <RouteBase>[
    GoRoute(path: '/', name: 'home', builder: (c, s) => const HomeScreen()),
    GoRoute(path: '/categories', name: 'categories', builder: (c, s) => const CategoriesScreen()),
    GoRoute(path: '/categories/:category', name: 'category_detail', builder: (c, s) => CategoryDetailScreen(categoryId: s.pathParameters['category']!)),
    GoRoute(path: '/saints/:slug', name: 'saint_detail', builder: (c, s) => SaintDetailScreen(slug: s.pathParameters['slug']!)),
    GoRoute(path: '/search', name: 'search', builder: (c, s) => const SearchScreen()),
    GoRoute(path: '/favorites', name: 'favorites', builder: (c, s) => const FavoritesScreen()),
    GoRoute(path: '/settings', name: 'settings', builder: (c, s) => const SettingsScreen()),
  ],
  errorBuilder: (c, s) => const _RouteErrorScreen(), // shows s.error, button back to '/'
);

// lib/app/app.dart
class SaintCompanionApp extends ConsumerWidget {
  // build: watch currentLiturgicalColorProvider (String?) -> LiturgicalColor.fromString,
  // themeModeProvider, colorIntensityProvider, effectiveTextScaleProvider ->
  // MaterialApp.router(title: 'Sancta Via Saints', theme: AppTheme.lightTheme(color, intensity),
  //   darkTheme: AppTheme.darkTheme(color, intensity), themeMode, routerConfig: appRouter,
  //   builder: MediaQuery.withClampedTextScaling(0.8..2.0) — identical composition to liturgical app)
}
```

- [ ] **Step 1:** `flutter create . --project-name saint_companion --org net.superversive.sancta_via --platforms android,ios` in the new dir; then overwrite generated pubspec/README with template values above.
- [ ] **Step 2: Write smoke test** `test/app_smoke_test.dart`: pump `ProviderScope(child: SaintCompanionApp())`, expect `find.byType(MaterialApp)` present; navigate to bogus route `appRouter.go('/nope')`, expect back-home affordance rendered (`find.byType(FilledButton)`) — placeholder home shows a `Text('Saints')` header.
- [ ] **Step 3:** From repo root `melos bootstrap` (links path deps; generates `pubspec_overrides.yaml`). **Step 4:** `flutter analyze` (0 issues) + `flutter test` PASS. **Step 5: Commit** `feat(saint_companion): scaffold app with router, theming, and placeholder home`.

### Task 9: `SaintAppSettings` provider (favorites + recents)

**Files:** Create `lib/models/saint_app_settings.dart`, `lib/providers/saint_app_settings_provider.dart`, `test/saint_app_settings_provider_test.dart`.

**Interfaces (Produces):**

```dart
class SaintAppSettings {
  final List<String> favoriteSlugs; final List<String> recentSlugs; // most-recent-first
  factory defaults(); fromJson(Map<String, dynamic>); toJson(); copyWith({...});
}
class SaintAppSettingsNotifier extends StateNotifier<SaintAppSettings> {
  static const String storageKey = 'saint_app_settings';
  SaintAppSettingsNotifier(); void _loadSettings(); // async SharedPreferences, AppLogger-safe
  Future<void> toggleFavorite(String slug);         // add-or-remove, persists
  Future<void> addRecent(String slug);              // move-to-front, dedupe, cap 50, persists
  bool isFavorite(String slug);
}
final saintAppSettingsProvider = StateNotifierProvider<SaintAppSettingsNotifier, SaintAppSettings>(
  (ref) => SaintAppSettingsNotifier());
```

- [ ] **Step 1: Write failing tests** (use `SharedPreferences.setMockInitialValues({})` before each notifier construction):
  - toggle twice → appears then disappears; state persisted (`SharedPreferences.getInstance()` mock value contains slug under `saint_app_settings`).
  - `addRecent('a')`, `addRecent('b')`, `addRecent('a')` → `['a', 'b']`; cap: add 60 → length 50; persistence reloaded instance keeps state.
- [ ] **Step 2:** FAIL → **implement** → **Step 3: PASS.** **Step 4: Commit** `feat(saint_companion): favorites and recents settings provider`.

### Task 10: Data providers

**Files:** Create `lib/providers/saint_providers.dart`, `test/saint_providers_test.dart`; Modify barrel-less app (no barrel in app template).

**Interfaces (Produces):**

```dart
final Provider<SaintRepository> saintRepositoryProvider = Provider<SaintRepository>((ref) => SaintRepository.instance);
final FutureProvider<List<Saint>> saintsTodayProvider;       // feastKeyForDate(DateTime.now())
final FutureProvider<List<Saint>> featuredSaintsProvider;
final FutureProvider<Map<SaintCategory, int>> categoryCountsProvider;
final FutureProviderFamily<List<Saint>, SaintCategory> saintsByCategoryProvider;
final FutureProviderFamily<List<Saint>, String> saintsByNeedProvider;
final FutureProviderFamily<List<SaintSearchResult>, (String, SaintCategory?)> saintSearchProvider; // record key (query, categoryOrNull)
final FutureProviderFamily<Saint?, String> saintBySlugProvider;
```

- [ ] **Step 1: Write failing test** `test/saint_providers_test.dart` — `ProviderContainer(overrides: [saintRepositoryProvider.overrideWithValue(SaintRepository.forDatabase(fixtureDb))])` with an in-memory fixture DB (reuse Task 7 helpers); assert `container.read(saintsTodayProvider.future)` resolves to seeded feast-day saints; `saintSearchProvider(('lost keys', null))` resolves Anthony; `categoryCountsProvider` map matches seed.
- [ ] **Step 2:** FAIL → **implement** → **Step 3: PASS.** **Step 4: Commit** `feat(saint_companion): riverpod providers for saint data`.

### Task 11: Widgets + Home screen

**Files:** Create `lib/widgets/{saint_image.dart, saint_card.dart, patronage_chip.dart, category_card.dart, liturgical_day_card.dart}`, replace `lib/screens/home/home_screen.dart`, `test/widgets/saint_image_test.dart`, `test/screens/home_screen_test.dart`.

**Interfaces (Produces):**

```dart
class SaintImage extends StatelessWidget { const SaintImage({required Saint saint, this.width, this.height, this.borderRadius, super.key}); }
// Image.asset('assets/thumbs/<slug>.jpg', package: 'saint_data', fit: cover) when thumbAsset != null;
// otherwise gray Container with Icon(Icons.person_outline); NO Image.network anywhere.
class SaintCard extends StatelessWidget { const SaintCard({required Saint saint, super.key}); }
// ListTemplate: thumb, name, first patronage need + category label; whole card tappable -> context.push('/saints/<slug>'); key: Key('saint_card_<slug>')
class PatronageChip { const PatronageChip({required SaintPatronage patronage}); } // chip label = need; tap -> push('/search', extra: need) — search route reads `extra` as initial query; key: Key('patronage_chip')
class CategoryCard { const CategoryCard({required SaintCategory category, required int count}); } // tap -> '/categories/<id>'; icons: everyday=Icons.home, illness=Icons.healing, jobs=Icons.work, travel=Icons.flight, persecution=Icons.shield, spiritual=Icons.church, military=Icons.shield_moon, family=Icons.family_restroom, nature=Icons.pets, special=Icons.volunteer_activism
class LiturgicalDayCard { const LiturgicalDayCard({required LiturgicalDayData? day}); } // null day -> nothing; shows celebration.name, rank label, colored dot from celebration.color
```

- [ ] **Step 1: Write failing tests:**
  - `saint_image_test.dart`: with thumbAsset → `Image.asset` present, `Image.network` absent (assert `find.byType(Image.network).isEmpty` — Review Focus #4 pin at widget layer); without → placeholder container present.
  - `home_screen_test.dart`: ProviderContainer overrides + `MaterialApp(home: HomeScreen())`; seeded fixture: today's saint appears under `Key('today_saints_section')`; empty feast day → `Key('today_empty_state')` visible; featured row shows `Key('featured_section')`; category grid shows 10 `CategoryCard`s with counts; liturgical card renders celebration name for a fixed `LiturgicalDayData` override via `currentLiturgicalDayProvider.overrideWith…` (simple: skip — override at widget level by passing `day` through constructor, HomeScreen reads provider internally; for test, override `currentLiturgicalDayProvider` with a `Provider` override).
- [ ] **Step 2:** FAIL → **implement widgets + home** (sections in spec order; `saintRepositoryProvider.ensureLoaded()` triggered in `saintsTodayProvider` etc. via repository's `ensureLoaded()` called inside provider builds) → **Step 3: PASS.**
- [ ] **Step 4: Commit** `feat(saint_companion): home screen with today's saints, featured, categories`.

### Task 12: Categories screens

**Files:** Create `lib/screens/categories/{categories_screen.dart, category_detail_screen.dart}`, `test/screens/categories_screens_test.dart`.

**Behavior:** list screen = grid/list of `CategoryCard` + total counts; detail screen (`categoryId` from route, `tryParse` unknown id → error builder style fallback page) = saints list + need chips (`Key('need_chip_<need>')`) with counts, tapping chip → `'/search'` with extra query = need text.

- [ ] **Step 1: Write failing tests** (overrides container): 10 categories rendered; detail for `military` shows seeded need chip with count and saints list; invalid category id → fallback text `Key('category_not_found')`.
- [ ] **Step 2:** FAIL → **implement** → **Step 3: PASS.** **Step 4: Commit** `feat(saint_companion): category browse and detail screens`.

### Task 13: Saint detail screen

**Files:** Create `lib/screens/saint_detail/saint_detail_screen.dart`, `test/screens/saint_detail_screen_test.dart`.

**Behavior (spec §8):** header `SaintImage` + attribution line (`Key('image_attribution')`, only when present); name, `feast day` formatted `'March 5'` via `SaintFeastService.feastKeyForDate`-independent formatter (`DateFormat('MMMM d').parse('MM-DD')`-based helper in the screen file), `canonized` when present; patronage `PatronageChip`s; bio paragraph; prayer card `Key('prayer_card')` with copy button (`Clipboard.setData` + snack bar); sources list (launch-less: plain `ListTile` with url text); favorite `IconButton` `Key('favorite_toggle')` → `saintAppSettingsProvider.toggleFavorite`; on open → `addRecent`. Unknown slug → `Key('saint_not_found')` message.

- [ ] **Step 1: Write failing tests:** renders bio/name/patronage chips; attribution only when `imageAttribution != null`; no-thumb → placeholder (no network); tapping `favorite_toggle` flips state in provider container; unknown slug shows not-found. **Step 2:** FAIL → **implement** → **Step 3: PASS.** **Step 4: Commit** `feat(saint_companion): saint detail screen with prayer, attribution, favorites`.

### Task 14: Search screen

**Files:** Create `lib/screens/search/search_screen.dart`, `test/screens/search_screen_test.dart`.

**Behavior:** `TextField` `Key('search_field')`; on submit/read → `saintSearchProvider((query, selectedCategory))`; category filter chips row (10 + 'all'); initial query from route `extra` (string) when pushed via `PatronageChip`; results use `SaintCard`-like tile with rationale badge (`Key('rationale_badge')` text: `name`/`patronage`/`bio`); empty state `Key('search_empty_state')`.

- [ ] **Step 1: Write failing tests** (debounce not required — submit + on-changed immediate): typing `lost keys` after container override shows Anthony with patronage badge; no results → empty state; extra-query prefill works. **Step 2:** FAIL → **implement** → **Step 3: PASS.** **Step 4: Commit** `feat(saint_companion): search screen with category filters and rationale badges`.

### Task 15: Favorites screen

**Files:** Create `lib/screens/favorites/favorites_screen.dart`, `test/screens/favorites_screen_test.dart`.

**Behavior:** two sections `Key('favorites_section')` (saint cards from slugs → `saintBySlugProvider` per slug, missing slugs ignored) and `Key('recents_section')` (recents list); unfavorite inside list updates immediately.

- [ ] **Step 1: Write failing tests** (seed settings state + fixture db): favorites show; unfavorite removes row; recents show in order. **Step 2:** FAIL → **implement** → **Step 3: PASS.** **Step 4: Commit** `feat(saint_companion): favorites and recents screen`.

### Task 16: Settings screen

**Files:** Create `lib/screens/settings/settings_screen.dart`, `test/screens/settings_screen_test.dart`.

**Behavior (spec §8):** compose shared widgets exactly as liturgical app does: `ThemeModeSelector`, `ColorIntensitySelector`, `LiturgicalColorPreview`, `AccessibilitySettings`, `LanguageSelector`, `AppInfo(...)` + app section `Key('app_data_section')` (favorites count, recents count, data version = `PRAGMA user_version` via repository — display static `1` acceptable if query is awkward; show favorites count + recents count at minimum). Include "About this dataset" credit paragraph per spec §12 (link URL text only, no launcher).

- [ ] **Step 1: Write failing test:** renders each shared widget type; favorites count text updates with seeded settings. **Step 2:** FAIL → **implement** → **Step 3: PASS.** **Step 4: Commit** `feat(saint_companion): settings screen with shared-ui selectors and dataset info`.

### Task 17: Full pipeline re-run, melos verification, release dry-run

**Files:** Possibly regenerated `assets/saints.db` + final commit; root README not modified.

- [ ] **Step 1:** From `sancta_via_saint_data`: re-run `dart run tools/build_saints_db.dart` (idempotent; commit if bytes changed).
- [ ] **Step 2:** Repo root: `melos bootstrap` → `melos analyze` → `melos test` (all packages 0 issues / pass).
- [ ] **Step 3:** `sancta_via_saint_companion`: `make deps && make test && make analyze` (Android debug build sanity: `flutter build apk --debug --target lib/main.dart` — verify plugin wiring only, do not distribute).
- [ ] **Step 4:** Root: `./build-release.sh --dry-run` → confirms the new app is detected (has `lib/main.dart` + platform folders) with version `1.0.0`.
- [ ] **Step 5:** Spec success-criteria check (§13): run `flutter test` in `saint_data` (criteria 1–3 covered by tests), confirm criteria 4–5 in test output (theming smoke + settings persistence tests).
- [ ] **Step 6: Commit** `chore: verify saint companion build pipeline and app integration` (if artifacts changed) — and report results.

---

## Execution notes

- Tasks 1–7 are `saint_data`; 8–16 are `saint_companion`; 17 is integration. Task 6's full image download is the only long-running step (~30–60 min) and is resumable/idempotent.
- After any dependency change: run `melos bootstrap` from the repo root before `flutter test`.
- `pubspec_overrides.yaml` files generated by melos must never be edited by hand and are gitignored in the workspace (check root `.gitignore`).
- Data artifacts (`saints_source.json`, `saints.db`, `thumbs/`, manifest) are committed — regeneration must be deterministic (sorted keys/order) or the diffs will churn.
