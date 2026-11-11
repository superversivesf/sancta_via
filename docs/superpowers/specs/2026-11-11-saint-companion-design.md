# Sancta Via Saint Companion — Design

Date: 2026-11-11
Status: Approved design (pending spec review)
Scope: `sancta_via_saint_data` (new), `sancta_via_saint_companion` (new)

## 1. Problem

The Sancta Via monorepo has no saints app. The sibling project
`/Users/jason/Repos/saint-for-that` is a static Astro site ("What do you need a
saint for?") built on a dataset of **2,174 saint JSON files** (~8.5 MB) with
need-based patronage lookup. We want the same experience as a Flutter app in
the monorepo, reusing that dataset, plus the monorepo's differentiators:
liturgical-calendar theming and a daily-saints feed.

Source data facts (from the web repo, verified 2026-11-11):

- Per saint: `slug`, `name`, `feastDay` (`MM-DD` or `"unknown"`), `canonized`,
  `bio` (10–10,000 chars), `patronages[]` (`need` lowercase ≤4 words +
  `category`), optional `prayer` (`text` ≤2,000 + `source`
  `traditional`|`original`), optional `image` (`url`, `attribution`,
  `altText`), `sources[]` URLs, `featured`, `draft`.
- Coverage: 2,174/2,174 have `prayer`; 1,443 have `image` (hotlinked from
  Wikimedia Commons); 6 `featured`; 0 `draft`; 508 `feastDay: "unknown"`.
- Categories (10, fixed enum): `everyday`, `illness`, `jobs`, `travel`,
  `persecution`, `spiritual`, `military`, `family`, `nature`, `special`.
- `site/src/lib/taxonomy.ts` contains a `NEED_SYNONYMS` map with ~185 keys
  mapping a canonical need to synonym terms (e.g. `lost items` →
  `lost keys`, `misplaced objects`, …). The build audits that every key exists
  as a `need` in the data.

## 2. Goals

1. Full "need → saint" lookup parity with the web app: category browsing, need
   anchor chips, synonym-expanded search.
2. Liturgical daily-saints feed driven by each saint's `feastDay`, in an app
   themed by today's liturgical color (existing shared packages).
3. Data layer consistent with monorepo patterns: bundled SQLite content store,
   repository singleton with caching, Riverpod providers, shared-UI settings.
4. Offline-capable image experience with bundled thumbnails and preserved
   attribution.
5. Favorites + recently-viewed per monorepo app-settings conventions.

## Non-goals

- No in-app content editing or curation; data ships read-only from the assets.
- No liturgical-celebration-name ↔ saint-slug cross-matching in v1 (fragile;
  the daily feed and the calendar card are shown side by side instead).
- No accounts, sync, push notifications, or saint-content translation in v1.
- No web target in v1 (sqflite constraint; could follow later with
  `sqflite_common_ffi_web`).

## 3. Decisions (approved 2026-11-11)

| Decision | Choice |
|---|---|
| App focus | Web parity + liturgical daily saints (home-led) |
| Images | Bundled 256px JPEG thumbnails (~50 MB), attribution preserved |
| Architecture | Data package + app package (no separate riverpod wrapper package) |
| Storage | SQLite via `sqflite`, bundled asset DB, FTS for search (see §6) |
| Favorites/recents | App-settings `NotifierProvider` persisting to SharedPreferences |
| Platforms v1 | Android + iOS; web deferred |

## 4. Package layout

Two new packages; melos registers both automatically (`sancta_via_*` scope).

| Package | Pubspec name | Contents |
|---|---|---|
| `sancta_via_saint_data` | `saint_data` | Models, repository, DB loader, search, feast service; build tooling; assets (`saints.db`, `thumbs/`); source snapshot |
| `sancta_via_saint_companion` | `saint_companion` | Flutter app (un-prefixed pubspec name per monorepo convention): providers, GoRouter, screens, widgets, Makefile |

Dependency graph: `saint_companion` → `saint_data`, `sancta_via_shared_ui`,
`sancta_via_liturgical_calendar`, `sancta_via_liturgical_calendar_riverpod`.
`saint_data` stays minimal: `sqflite`, `path`, `flutter` (services only),
`AppLogger` equivalent as needed — no Riverpod in the data package.

## 5. Data pipeline (saint_data)

### 5.1 Source snapshot

- One-time copy: `/Users/jason/Repos/saint-for-that/data/saints/*.json` →
  `sancta_via_saint_data/data/saints_source.json` (single combined file,
  ~8.5 MB, committed). A `data/manifest.json` records the sibling-repo commit,
  fetch date, saint count, per-category counts, and SHA-256 of the snapshot.
- `NEED_SYNONYMS` + category metadata are ported from
  `saint-for-that/site/src/lib/taxonomy.ts` → `data/needs_synonyms.json`
  (list of `{need, synonyms[]}`) + `data/categories.json` (id → label,
  description). Ported by the same fetch step so both stay in sync.

### 5.2 `tools/build_saints_db.dart`

1. Validates every saint against the web schema rules (mirroring
   `saint-for-that`'s zod schema): slug kebab-case 1–100, name 1–200,
   `feastDay` valid `MM-DD` or `unknown`, bio 10–10,000, ≥1 patronage with
   need lowercase ≤4 words in the 10-category enum, prayer ≤2,000 + source
   enum, image URL/attribution/altText constraints. Any failure is a hard
   build error with the offending slugs listed. `draft` records (currently 0)
   are excluded.
2. Writes `assets/saints.db` per §6, with `PRAGMA user_version =
   SCHEMA_VERSION` (bumped when schema or content model changes).
3. Audits: needs in data missing from `needs_synonyms.json` are reported as
   warnings (informational, not errors); FTS rows built for all saints;
   row counts re-verified against the manifest.

### 5.3 `tools/fetch_saint_images.dart`

- For each saint with an image: download `image.url` (preferring a ~256px
  Wikimedia thumb-size URL when the `/thumb/<width>px-` pattern is present;
  fallback to the stored URL), center-crop to 256×256, save JPEG q~80 to
  `assets/thumbs/<slug>.jpg`.
- Skips existing thumbs unless `--force`; writes a failure report
  (slug + URL) and those saints ship with `thumb_asset = NULL` (the app shows
  a placeholder). Expected total ~40–60 MB committed, matching the repo's
  precedent of committing built binary assets (`bibles.db`).
- Attribution/alt text are stored in the DB (§6) and shown in the app.

## 6. Database schema (`assets/saints.db`)

```sql
CREATE TABLE saints (
  slug TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  feast_day TEXT NOT NULL,          -- 'MM-DD' or 'unknown'
  canonized TEXT,
  bio TEXT NOT NULL,
  prayer_text TEXT,
  prayer_source TEXT,               -- 'traditional' | 'original'
  featured INTEGER NOT NULL DEFAULT 0,
  thumb_asset TEXT,                 -- 'packages/saint_data/assets/thumbs/<slug>.jpg' when shipped
  image_attribution TEXT,
  image_alt TEXT
);
CREATE INDEX idx_saints_feast ON saints(feast_day);
CREATE INDEX idx_saints_featured ON saints(featured);

CREATE TABLE patronages (
  slug TEXT NOT NULL REFERENCES saints(slug),
  need TEXT NOT NULL,
  category TEXT NOT NULL
);
CREATE INDEX idx_patronages_category ON patronages(category);
CREATE INDEX idx_patronages_need ON patronages(need);

CREATE TABLE need_synonyms (
  need TEXT NOT NULL,
  synonym TEXT NOT NULL
);
CREATE INDEX idx_synonyms_synonym ON need_synonyms(synonym);

CREATE VIRTUAL TABLE saint_fts USING fts4(
  slug, name, patronages, bio, prayer,
  tokenize = 'unicode61'
);
```

FTS4 (not FTS5): the `sqlite3` on many Android devices still lacks FTS5; FTS4
is available everywhere both platforms ship. Tokenizing/diacritic strategy is
deliberately simple — searchable text is **pre-normalized at build time**
(lowercased, diacritics folded), and the query side applies the same
normalization function (shared constant in the package) before MATCH.
FTS row content is rebuilt by the build script; the app never writes to the DB
(read-only except initial asset copy).

## 7. Repository & services (saint_data)

- `SaintRepository` — singleton (`instance`), `_cached*` fields, all errors
  logged via `AppLogger` (tag `SAINT_DATA`) with safe defaults:
  - `Future<void> ensureLoaded()` — copies `assets/saints.db` from the
    package bundle to the documents directory if missing **or older than the
    bundled version** (`user_version` check, mirroring `SqliteBibleLoader`),
    then opens read-only.
  - `searchSaints(String query, {SaintCategory? category, int? limit})` —
    FTS match on the normalized query after synonym expansion, with a
    name-match boost; returns `List<Saint>` with a match-rationale string
    (name / patronage / bio) for UI badges.
  - `getSaintsForNeed(String need)` — direct patronage matches plus saints
    matched via synonyms of that need.
  - `getSaintsByCategory(SaintCategory)` , `getBySlug(String)`,
    `getSaintsForFeastDay(String)`, `getFeaturedSaints()`,
    `getCategoryCounts()`, `getNeedsForCategory(SaintCategory)` (need =>
    count, for anchor chips).
- Models: immutable `Saint`, `SaintPatronage`, `SaintCategory` enum (10 ids +
  display labels + descriptions), prayer fields; `hasImage`/`hasPrayer`
  helpers.
- `SaintFeastService` (pure Dart, no DB): `feastKeyForDate(DateTime)` →
  `MM-DD` with the leap-year rule below; `upcomingFeastDates(DateTime from,
  int days)` for future lists.

### Feast-day logic

- Today's saints = `feast_day == feastKeyForDate(today)`.
- **Feb 29 feasts are celebrated on Feb 28 in non-leap years** (keeps those
  saints reachable annually).
- `"unknown"` feast days never appear in the daily feed; they remain
  discoverable via categories and search.
- The home screen's liturgical celebration card comes from
  `currentLiturgicalDayProvider` and is not cross-matched to saint slugs (v1).

## 8. App architecture (saint_companion)

- `lib/main.dart`: `ProviderScope` bootstrap.
- `lib/app/app.dart`: `MaterialApp.router`; theme built by shared `AppTheme`
  from today's liturgical color → `themeModeProvider` +
  `colorIntensityProvider`; text scaling via `effectiveTextScaleProvider`
  (same composition as `liturgical_calendar_app`).
- `lib/config/routes.dart` (GoRouter + defensive `errorBuilder`):
  `/`, `/categories`, `/categories/:category`, `/saints/:slug`, `/search`,
  `/favorites`, `/settings`.
- Providers (`lib/providers/`): `saintRepositoryProvider`,
  `saintsTodayProvider`, `featuredSaintsProvider`, `categoryCountsProvider`,
  `saintsByCategoryProvider.family`, `saintsByNeedProvider.family`,
  `saintSearchProvider.family`, `saintBySlugProvider.family` (thin wrappers
  over the repository — no data logic in the app), plus
  `SaintAppSettingsProvider` following the
  `novena_app_settings_provider.dart` /
  `confession_app_settings_provider.dart` precedent: a `NotifierProvider`
  persisting `favoriteSlugs` + `recentSlugs` to SharedPreferences (base
  settings come from the shared `baseSettingsProvider`).
- Screens (`lib/screens/`):
  - **home**: liturgical celebration card (name/rank/color via
    `currentLiturgicalDayProvider`), **Today's Saints** (feast-day lookup,
    empty state when none), featured saints carousel, category grid with
    counts, search entry.
  - **categories + category detail**: category list; detail shows saints list
    plus need anchor chips with counts.
  - **search**: query field, category filter chips, results with
    match-rationale badges; synonym-expanded query is transparent to the user.
  - **saint detail**: thumbnail (asset) + attribution, name, feast day,
    canonized, patronage chips (tap → need lookup), bio, prayer card,
    sources list, favorite toggle (records a recents visit too).
  - **favorites**: favorites + recently viewed.
  - **settings**: shared widgets (`ThemeModeSelector`,
    `ColorIntensitySelector`, `AccessibilitySettings`, `LanguageSelector`,
    `AppInfo`) plus an app section (favorites count / data-version info).
- Widgets: `SaintCard`, `PatronageChip`, `CategoryCard`, `TodaySaintCard`,
  placeholder image widget for saints without a thumb.

## 9. Error handling

- All failures logged via `AppLogger`; repository/service methods return safe
  defaults (empty lists, `null`).
- First-load DB failure → error state with a retry affordance on the home
  screen.
- Missing thumbnail → placeholder widget (saint initial / icon).
- Empty states: no saints today, no search results, no favorites.

## 10. Testing

- `sancta_via_saint_data/test/`: `sqflite_common_ffi` in-memory DB — schema +
  fixture-based build tests, repository methods, search (synonym expansion,
  diacritic folding, category filter), feast-day logic (Feb 28/29 in leap and
  non-leap years), validation pipeline on a small fixture, plus a committed
  integration test asserting shipped `saints.db` matches the manifest counts
  (runs whenever tests run; `sqflite_common_ffi` opens assets extracted for
  the test env).
- `sancta_via_saint_companion/test/`: widget tests mirroring the other apps
  (provider overrides, `mocktail`), router tests, settings provider
  persistence tests with mocked `SharedPreferences`.
- Both packages pass `make deps / test / analyze / format`; melos
  `analyze`/`test` pick them up automatically.

## 11. Platforms & release

- v1: Android + iOS via the per-app `Makefile` (targets copied from
  `liturgical_calendar_app`: `deps, test, analyze, format, build-android,
  build-ios, clean, run, ci`). `build-release.sh` detects the app
  automatically (has `lib/main.dart` + platform folders).
- Web deferred; revisit with `sqflite_common_ffi_web` if desired.
- App bundle size delta from thumbnails (~50 MB) is verified in implementation
  (target < 80 MB installed base).

## 12. Provenance & attribution

- The dataset's origin is the sibling `saint-for-that` repo (recorded, with
  commit hash, in `data/manifest.json`). Per-saint Wikipedia `sources[]` are
  shipped and displayed on the detail screen.
- Wikimedia image attribution strings are stored and displayed under each
  image, preserving the license obligations the web app already carries.
- The web app's own credit ("inspired by *There Is a Saint for That* by
  Peter's Barque") is carried into the app's about/settings info section.

## 13. Success criteria

1. Searching "lost keys" (a synonym of need `lost items`) returns the same
   saints as the web app's search/browse for that need.
2. Today's Saints list matches an independent check against the dataset by
   date (all 2,174 saints loaded; Feb 29 rule exercised in a test).
3. Category browse + need chips cover all 10 categories with correct counts.
4. Themed daily experience: app icon-level theme follows today's liturgical
   color like the other apps.
5. Favorites and recents persist across restarts.
6. Full monorepo checks pass (`flutter analyze`, `flutter test`) in both new
   packages, melos clean.
