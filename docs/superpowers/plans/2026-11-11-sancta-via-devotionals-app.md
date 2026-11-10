# Sancta Via Devotionals — App Implementation Plan (Plan 2 of 3)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build `sancta_via_devotionals` — the 6th Sancta Via app: offline, free, no accounts — delivering the Today pipeline, session player, enrollment + progress surfaces, sqlite repositories, and 60-day notification rotation, over the completed devotional engine.

**Architecture:** Data-driven "programs" (Approach A): the pure-Dart engine + riverpod wrapper (both complete) interpret content packs; the app adds (a) a sqlite persistence layer behind the wrapper's `ProgramRepository` seam, (b) the app-layer contracts Plan 1 reserved (checkpoint gating, grace-window credit, placeholder substitution, enrollment date recompute), (c) GoRouter + Riverpod UI in the monorepo's established patterns, and (d) `NotificationPlanner` rotating 60-day trigger windows through `flutter_local_notifications`. Content packs ship as app assets (`assets/content/`) migrated into sqlite on first launch, version-stamped.

**Tech Stack:** Flutter (iOS + Android), Dart SDK ^3.9.2, flutter_riverpod ^2.6.1, go_router ^15.1.2, sqflite ^2.3.3+1 (monorepo convention — matches siblings + `APP_BUILD_RULES.md`), shared_preferences ^2.5.3, flutter_local_notifications ^17.2.x + timezone ^0.9.4 + flutter_timezone (precedented in `sancta_via_novena_companion`), path-dep on `sancta_via_devotional_engine`, `sancta_via_devotional_engine_riverpod`, `sancta_via_liturgical_calendar(_riverpod)`, `sancta_via_shared_ui`, `sancta_via_bible_data(_riverpod)`.

**Spec:** `docs/superpowers/specs/2026-11-09-devotionals-app-design.md`

**Scope split (controller ruling, from the skill's scope check):** the spec's §8 **Office family (1962 Hours — Divinum Officium subset)** is its own independent subsystem (data tooling + `EditionProvider` composition). It becomes **Plan 3**; this plan builds the app so the Office drops in later with **zero app changes** (the session engine is edition-generic; hours will be ordinary packs). Everything else in §8 ships here.

## Global Constraints

- SDK `^3.9.2`; melos workspace — all Sancta Via deps are relative path deps; bootstrap via `melos bootstrap`
- Style per `APP_BUILD_RULES.md`: single quotes, trailing commas, explicit types (no `var`/`dynamic`), final/const by default, import order (dart → flutter → package → relative)
- Repository pattern: sqlite behind repositories; **never touch DB from UI**; cache with invalidation; return safe defaults on error; `AppLogger` for every log/error (never `print`)
- Navigation: GoRouter named routes + centralized `errorBuilder` (pattern §4 of build rules)
- Settings: `StateNotifier` extending `BaseSettingsModel` from shared_ui; delegate shared settings to `baseSettingsProvider`; app-specific state in the app's own storage key `devotionals_app_settings`
- **Text render gate:** no prayer text renders without non-empty `source` + `license` (engine enforces at load; the app surface shows attribution on every session/text view — Trust through the engine, plus the attribution section in the player)
- Zero network calls anywhere; zero background fetch (all computation from embedded data + engine)
- Conventional Commits (`feat:`, `test:`, `chore:`, `fix:`)
- Engine types are immutable: derive user-pack variants by patching **JSON** and re-loading via `PackLoader.loadFromJsonString` (ContentPack has no copyWith — decided)
- Missed-day decisions stay app-layer; the engine's `MissedDayEvaluator.evaluate(policyString, …)` is the verdict source
- The engine's dates are local-midnight date-only semantics: never hand the engine a `DateTime.parse`-constructed date

## Review Focus

1. **DST-crossing reminder times** — an anchor scheduled across a DST boundary must still fire at the user's local clock time. Pinned: Task 17 planner test schedules 6:00 anchors across the US DST spring-forward.
2. **Fulfilled-commitment resurrection** — after the final fulfillment (e.g., 5/5 Saturdays), the program must never reappear as due (Today or Progress) — regression class fixed mid-Plan-1. Pinned: Task 12 Today test + Task 16 Progress test with `fulfilledOrdinals == count`.
3. **Grace-window credit double-counting** — one confession must satisfy **at most one** anchor even when two anchors are inside its window. Pinned: Task 8 credit-service test.
4. **Unresolved placeholder leakage** — a `{{mysteryTitle}}`/`{{day}}` token reaching the screen uncovered is a user-visible defect. Pinned: Task 7 substitution test + Task 11 render guard test.
5. **Re-enrollment state clobbering** — re-enrolling a pack must replace the derived pack + params atomically, never duplicate rows or orphan progress. Pinned: Task 5 repository test.
6. **Missed-day application order** — the evaluator must run against the *persisted* `lastFulfilled` before any today's-session write, and `askUser` must surface before new progress lands. Pinned: Task 9 flow test.

---

### Task 1: App scaffold in the melos workspace

**Files:**
- Create: `sancta_via_devotionals/` (flutter create, org `net.sancta-via`, project name `sancta_via_devotionals`), mirroring `sancta_via_prayer_companion/'s` platform setup
- Create: `sancta_via_devotionals/pubspec.yaml` (deps listed in Tech Stack; note `flutter_local_notifications: ^17.2.3`, `timezone: ^0.9.4`, `flutter_timezone: ^3.0.1`), `lib/main.dart` (root `ProviderScope` → themed `MaterialApp.router`), `lib/config/routes.dart` (GoRouter with placeholder Today route + `errorBuilder`), `analysis_options.yaml` (mirror sibling), `.gitignore`, `Makefile` + `tool/update_build_info.sh` (mirror prayer companion), `README.md`
- Modify: root `melos.yaml` only if its glob does not already pick `sancta_via_*`

**Interfaces:**
- Produces: package `sancta_via_devotionals`; `GoRouter appRouter` (route `today` at `/`); app compiles under `flutter analyze` with zero new workspace issues
- Consumes: path deps (must resolve via `melos bootstrap`)

- [ ] **Step 1:** Scaffold + wire deps; `melos bootstrap` runs clean
- [ ] **Step 2:** `flutter test test/simple_test.dart` — smoke test: root widget renders an AppBar titled 'Sancta Via Devotionals'
- [ ] **Step 3:** `flutter analyze` clean; `melos run analyze` adds zero new issues
- [ ] **Step 4:** `git add sancta_via_devotionals && git commit -m "feat: devotionals app scaffold with go_router shell"`

---

### Task 2: Engine seam — typed policy overload

**Files:**
- Modify: `sancta_via_devotional_engine/lib/src/progress/missed_day_evaluator.dart`
- Test: `sancta_via_devotional_engine/test/progress/missed_day_test.dart` (append)

**Interfaces:**
- Consumes: existing `MissedDayEvaluator.evaluate(String policy,…)`, `enum RestartPolicy` (Task-1 engine artifacts, complete)
- Produces: `static MissedDayVerdict evaluateTyped({required RestartPolicy policy, required ProgressState state, required DateTime lastFulfilled, required DateTime nextDue})` — identical semantics to the string API, delegating to it (or vice-versa); the string API stays the public default (Task 12 ruling holds)

- [ ] **Step 1:** Failing test — `evaluateTyped` on a completed-but-`reset` scenario returns the same verdict the `'strict'` string call returns; `'permissive'` → `resume`; state with 0 ordinals + no completions → `askUser`
- [ ] **Step 2:** `cd sancta_via_devotional_engine && dart test test/progress/missed_day_test.dart` → FAIL
- [ ] **Step 3:** Implement the typed overload as a thin delegate (no semantic drift)
- [ ] **Step 4:** PASS; full engine suite green; `dart analyze` clean
- [ ] **Step 5:** `git commit -m "feat: typed restart-policy overload on MissedDayEvaluator"`

---

### Task 3: App settings model + notifiers

**Files:**
- Create: `lib/models/app_settings.dart`, `lib/providers/app_settings_provider.dart`
- Test: `test/models/app_settings_test.dart`, `test/providers/app_settings_provider_test.dart`

**Interfaces:**
- Consumes: shared_ui `BaseSettingsModel`, `baseSettingsProvider` (pattern §3 of build rules)
- Produces: `class DevotionsAppSettings { final BaseSettingsModel baseSettings; final TimeOfDay angelusMorning; // default 6:00, angelusNoon 12:00, angelusEvening 18:00, mercyHour 15:00; final bool morningReminderEnabled; final bool eveningReminderEnabled; final bool nightItemsEnabled; // default false; final bool enableAngelusAnchors; final bool enableMercyHourAnchor; final String missedDayDefaultPolicy; // 'permissive'; final bool latinDisplayEnabled; final bool luminousSetEnabled; // default true; final bool onboardingComplete; defaults(); fromJson/toJson; copyWith }` and `devotionsSettingsProvider` (`StateNotifierProvider<DevotionsSettingsNotifier, DevotionsAppSettings>`), storage key `devotionals_app_settings`, syncing base settings via `_ref.listen(baseSettingsProvider, …)`. Convenience providers: `anchorTimesProvider`, `missedDayDefaultPolicyProvider`, `latinDisplayProvider`, `onboardingCompleteProvider`
- TimeOfDay model: store as `{hour, minute}` JSON (no `DateTime.now()` dependency)

- [ ] **Step 1:** Failing model tests — defaults exact (6/12/6, 15:00, permissive, night off, luminous on, onboarding incomplete); JSON round-trip; base-settings sync replaces `baseSettings` and persists
- [ ] **Step 2:** FAIL — Step 3: implement — Step 4: PASS (`flutter test test/providers/app_settings_provider_test.dart`), `flutter analyze` clean
- [ ] **Step 5:** `git commit -m "feat: devotionals app settings model and notifiers"`

---

### Task 4: SQLite database + migration service

**Files:**
- Create: `lib/database/devotionals_database.dart`, `lib/database/database_migration_service.dart`
- Test: `test/database/devotionals_database_test.dart` (mocked via sqflite_common_ffi in-memory, or interface+mock per build-rules pattern §6)

**Interfaces:**
- Produces: tables (exact DDL):
  - `packs(id TEXT PRIMARY KEY, json TEXT NOT NULL, pack_version TEXT NOT NULL, embedded_at TEXT NOT NULL)`
  - `enrollments(pack_id TEXT PRIMARY KEY, params_json TEXT NOT NULL, enrolled_at TEXT NOT NULL)`
  - `progress(pack_id TEXT PRIMARY KEY, state_json TEXT NOT NULL, updated_at TEXT NOT NULL)`
  - `notification_index(id TEXT PRIMARY KEY, pack_id TEXT, fire_at TEXT NOT NULL, title TEXT NOT NULL, body TEXT NOT NULL, deep_link TEXT NOT NULL, status TEXT NOT NULL)` — status ∈ {scheduled, fired, cancelled}
  - `intentions(id TEXT PRIMARY KEY, kind TEXT NOT NULL, text TEXT NOT NULL, created_at TEXT NOT NULL)` — kind ∈ {intention, soul}
  - `meta(key TEXT PRIMARY KEY, value TEXT NOT NULL)` — stores `content_version`, `schema_version`
- `DevotionalsDatabase.instance` singleton with injectable `open()` for tests; `DatabaseMigrationService` version-stamps `meta.schema_version` (bump on later schema change); CRUD helpers per table returning engine-typed results where applicable

- [ ] **Step 1:** Failing tests — create-all-tables; round-trip a row each (pack json, enrollment params, progress state json, notification row, intention); schema_version written on first open
- [ ] **Step 2:** FAIL — Step 3: implement (sqflite + `sqflite_common_ffi` in tests) — Step 4: PASS
- [ ] **Step 5:** `git commit -m "feat: devotionals sqlite database with version-stamped migrations"`

---

### Task 5: SqliteProgramRepository (the persistence seam)

**Files:**
- Create: `lib/repositories/program_repository.dart`
- Test: `test/repositories/program_repository_test.dart`

**Interfaces:**
- Consumes: `ProgramRepository` abstract (wrapper), `PackLoader`, `ProgressState.toJson/fromJson`, `DevotionalsDatabase`
- Produces: `class SqliteProgramRepository implements ProgramRepository { SqliteProgramRepository({DevotionalsDatabase? database}); Future<void> seedPacks(List<ContentPack> packs, {required String packVersion}); Future<Map<String, dynamic>?> enrollmentParamsFor(String packId); Future<void> unenroll(String packId); Future<String?> persistedPackVersion(); }` — `loadPacks` reads `packs` (empty → caller seeds first, repository returns `[]`), `progressFor`/`saveProgress` JSON round-trip through `ProgressState`, `enroll` upserts `enrollments` **and** leaves existing progress intact, `unenroll` deletes progress + notification rows for the pack but keeps the pack row. Cache: `_packsCache`, `clearCache()`. Safe defaults on error per build rules (`[]` / null) with `AppLogger.error`
- Review Focus 5 pinned here: re-`seedPacks` with a new pack version replaces the rows of every pack id; re-`enroll` of a pack replaces params without duplicating

- [ ] **Step 1:** Failing tests — seed→loadPacks order stable; enroll/progressFor/unenroll lifecycle; re-seed replaces by id (no duplicates); re-enroll single row
- [ ] **Step 2:** FAIL — Step 3: implement — Step 4: PASS — Step 5: `git commit -m "feat: sqlite program repository with enrollment lifecycle"`

---

### Task 6: Content assets + first-launch migration

**Files:**
- Create: `assets/content/packs/*.json` (the 8 engine fixture packs byte-copied), `lib/services/content_asset_service.dart`, `lib/providers/content_providers.dart`
- Create: `lib/utils/app_logger.dart` (wrapper around shared/logger conventions per sibling apps)
- Test: `test/services/content_asset_service_test.dart`

**Interfaces:**
- Consumes: `PackLoader.loadFromJsonString`, `PackValidator`, `SqliteProgramRepository.seedPacks`, `DevotionalsDatabase.meta`
- Produces: `class ContentAssetService { ContentAssetService({required AssetBundle assets, required SqliteProgramRepository repository, required DevotionalsDatabase database}); Future<List<ContentPack>> ensureContentLoaded(); }` — reads `AssetManifest`-declared `assets/content/packs/*.json`, loads each through `PackLoader` (throws = authoring error, logged + rethrown at first launch), computes a stable content version (hash of sorted ids + embedded pack_version fields), and seeds the repository only when the stored `meta.content_version` differs. `contentLoadedProvider` (`FutureProvider<List<ContentPack>>`), `programRepositoryProvider` override: `SqliteProgramRepository` — the wrapper's providers (`todayProgramsProvider` etc.) now flow from the app repository
- Pack JSON: copy of `sancta_via_devotional_engine/test/fixtures/packs/*.json` (single source of truth = the engine fixtures; regenerate via copy whenever engine fixtures change)

- [ ] **Step 1:** Failing tests — fresh install seeds 8 packs + stamps version; second call with unchanged version does not re-seed; bumped fixture → re-seeds; malformed asset throws `ContentValidationException` naming the file
- [ ] **Step 2:** FAIL — Step 3: implement — Step 4: PASS — Step 5: `git commit -m "feat: content asset pipeline with version-stamped first-launch migration"`

---

### Task 7: Placeholder substitution service

**Files:**
- Create: `lib/services/substitution_service.dart`
- Test: `test/services/substitution_service_test.dart`

**Interfaces:**
- Produces: `class SubstitutionService { static String substitute(String input, {Map<String, String> tokens = const {}, int? dayIndex}); static String requireFullySubstituted(String input); }` — tokens replace `{{key}}` verbatim; `dayIndex` substitutes `{{day}}`; sanctioned token set: `day`, `mysteryTitle`, `mysteryFruit` (pack-content conventions from Plan 1 Tasks 16/17); `requireFullySubstituted` throws `StateError` listing any remaining `{{…}}` occurrences (Review Focus 4)
- Known legacy shape: the 54-day pack stores thanksgiving-decade formulas under key `petition` for BOTH phases (Plan 1 Task 19 ruling) — document on the class; callers read `variant['petition']` regardless of phase

- [ ] **Step 1:** Failing tests — `{{day}}`+4 → '5' at dayIndex 5; token map replaces `{{mysteryTitle}}`; double-`{{` scan detects leftovers; unknown token `{{color}}` surfaces in `requireFullySubstituted`'s error
- [ ] **Step 2:** FAIL — Step 3: implement — Step 4: PASS — Step 5: `git commit -m "feat: placeholder substitution for pack session content"`

---

### Task 8: Grace-window credit service

**Files:**
- Create: `lib/services/grace_window_service.dart`
- Test: `test/services/grace_window_service_test.dart`

**Interfaces:**
- Consumes: engine `ConsecutiveCommitmentSpec` (read via `pack.schedule is ConsecutiveCommitmentSpec`), its `GraceWindow` list, engine `GraceWindow.admits(anchor, completed)`
- Produces: `class GraceWindowService { static Map<String, DateTime> creditCheckpoints({required ConsecutiveCommitmentSpec spec, required DateTime anchor, required Map<String, String> completedItemsByDay}); }` — maps checkpoint item → the completed date that credits it for this anchor: exact-day completion by date-string key (`'<item>:<yyyy-mm-dd>'`, the engine's documented key convention), else the unique completion date within the item's `GraceWindow`; **first-come credit lock**: once credited to an anchor, a completion cannot credit a second anchor even inside its window (Review Focus 3; resolve greedily by date order, documented)
- Returns only REQUIRED items; missing entries = unsatisfied

- [ ] **Step 1:** Failing tests — exact-day hit; window-only hit (confession −8, anchor +0); double-anchor scenario: one confession between two First-Saturdays credits exactly the nearer anchor (second stays uncredited, visible in the returned map)
- [ ] **Step 2:** FAIL — Step 3: implement — Step 4: PASS — Step 5: `git commit -m "feat: grace-window checkpoint credit with per-anchor lock"`

---

### Task 9: Missed-day flow + session completion writer

**Files:**
- Create: `lib/services/progress_service.dart`
- Test: `test/services/progress_service_test.dart`

**Interfaces:**
- Consumes: engine `MissedDayEvaluator.evaluate(T|String …)` (Task 2), `CommitmentState.evaluate`, `ProgressState`, wrapper `ProgramRepository` (app: `SqliteProgramRepository` + `enrollmentParamsFor`), `GraceWindowService`, `DevotionsSettingsNotifier`
- Produces: `class ProgressService { static MissedDayVerdict missedVerdict(ProgressState? state, String policy, DateTime today); Future<void> applyMissedDay({required String packId, required MissedDayVerdict verdict}); SessionState completeSession({required SessionState state, required ContentPack pack, required Map<String, bool> checkpointStates, required Map<String, String> completedItemsByDay, required DateTime today}); Future<void> persistCompletion(…); }` —
  - `missedVerdict`: `askUser` surfaces FIRST when warranted (Review Focus 6); `reset` zeroes `fulfilledOrdinals`/`lastFulfilled`/badges-on-reset; `resume` keeps state
  - `completeSession`: runs AFTER `SessionRunner` ends the walk; enforces the checkpoint gate — a session with any `CheckpointStep.requiredForCompletion: true` step not in `checkpointStates` stays **incomplete** (returns the pre-final `SessionState`; the player shows what's missing) — Plan-2 contract (a); on success derives the new `ProgressState` (ordinal from `DueToday.schedule.ordinal`, badges appended with today, `repetitionsToday` reset)
  - `persistCompletion` routes through `GraceWindowService` for commitment packs, updates `fulfilledOrdinals` + `lastFulfilled`, saves

- [ ] **Step 1:** Failing tests — askUser precedence; strict-reset zeroes state; permissive resume keeps ordinal; completed session with unsatisfied required checkpoint returns incomplete state unchanged; satisfied 5th Saturday appends badge 5 and stores `fulfilledOrdinals: 5`
- [ ] **Step 2:** FAIL — Step 3: implement — Step 4: PASS — Step 5: `git commit -m "feat: progress service with missed-day flow and checkpoint gate"`

---

### Task 10: Session player controller

**Files:**
- Create: `lib/providers/session_player_provider.dart` (controller), `lib/services/variant_service.dart`
- Test: `test/providers/session_player_provider_test.dart`

**Interfaces:**
- Consumes: engine `SessionRunner` (`forState`, `completeCurrent(state, script:)`, `record(state, count)` — script param pins repetition/bead targets), `SessionState.toJson/fromJson`, pack `session` + `variants`; Task 7 `SubstitutionService`; Task 9 `ProgressService`
- Produces: `class SessionPlayerController extends StateNotifier<SessionPlayerState>` with `SessionPlayerState { final SessionState session; final Map<String, bool> checkpoints; final DateTime? reflectionEndsAt; final Map<String, String> tokens; }`; API: `startSession(packId, {DateTime? forDate})` — resolves the day's variant (dayIndex from `ScheduleResult`, mystery tokens from `SeasonVariant`/`rosaryMysteriesFor` + the pack's mystery metadata) and substitutes every text once at start; `completeStep()`, `record(int)`, `toggleCheckpoint(String item)`, `tickReflection(Duration remaining)`; persistence: session JSON + variant snapshot saved to `meta('active_session_<packId>')` on every transition, restored on construction (pause/resume); completion routes through `ProgressService.completeSession`
- `VariantService.resolveDayVariant(ContentPack pack, int dayIndex)`: returns the pack variant for `dayIndex` when one exists (`{{…}}` values in it become token values: `petition`-key text per Task 7's documented shape, mystery tokens by cycle) else empty tokens

- [ ] **Step 1:** Failing tests — angelus session walk completes and persists JSON; 54-day day-27 variant substitutes `{{day}}`='27' and `{{mysteryTitle}}` set from the cycle; repetition step blocks `completeStep` before target; checkpoint gate holds the session incomplete until toggled; resume round-trip restores step index + checkpoint map mid-session
- [ ] **Step 2:** FAIL — Step 3: implement — Step 4: PASS — Step 5: `git commit -m "feat: session player controller with resume and variant substitution"`

---

### Task 11: Session player UI

**Files:**
- Create: `lib/screens/session/session_player_screen.dart`, `lib/widgets/session/step_views.dart`, `lib/widgets/session/attribution_sheet.dart`
- Modify: `lib/config/routes.dart` (route `session/:packId`, optional `forDate` query param by iso date)
- Test: `test/screens/session_player_screen_test.dart`

**Interfaces:**
- Consumes: `SessionPlayerController` (Task 10), `attribution_sheet` (bottom sheet listing each viewed text's source/license/attribution)
- Produces: full-screen player: progress header (x of N steps, pack title, day label), per-step cards:
  - `PrayerStep` — title, scrollable text, Latin toggle block when the variant carries a parallel (`latinDisplayProvider`), attribution line
  - `VerseStep` — V./R. pairs; tap to advance
  - `BeadGroupStep` — mystery title/fruit header, decade dots (10), Fatima-prayer toggle when flagged
  - `RepetitionStep` — ring counter n of count; tap = `record`
  - `ReflectionStep` — countdown ring from `Duration`, then advance enabled
  - `LitanyStep` — invocation list, grouped/individual response display
  - `CheckpointStep` — checkbox tile; list title = item
  - `IntercessionStep` — prompt + current intentions list readout
  - Completion summary screen (title, ordinal/phase banner when present, badge callout) → back to Today
- Render guard (Review Focus 4): any card whose text still carries `{{` renders an error placeholder card naming the token, logged — never silently shows raw tokens

- [ ] **Step 1:** Widget tests — angelus (3 verse steps + prayer) tap-through completes; repetition UI blocks advance until count; reflection counts down (fake async); checkpoint toggle enables completion only when `requiredForCompletion` satisfied for all checkpooints; `{{leak}}` renders the error card
- [ ] **Step 2:** FAIL — Step 3: implement — Step 4: PASS (`flutter test test/screens/session_player_screen_test.dart`) — Step 5: `git commit -m "feat: session player screen with per-step renderers"`

---

### Task 12: Today assembler (providers)

**Files:**
- Create: `lib/providers/today_providers.dart`
- Test: `test/providers/today_providers_test.dart`

**Interfaces:**
- Consumes: wrapper `todayProgramsProvider`, `enrolledProgramsProvider`, `programRepositoryProvider`, calendar riverpod `upcomingFeastsProvider(days)`, `currentLiturgicalDayProvider(-family)`, settings anchors (`anchorTimesProvider`), `VariantService`
- Produces:
  - `final Provider<TodayAssembly> todayAssemblyProvider` — groups the day: `Morning` (morningRoutine + Morning Offering), `Anchors` (Angelus times + 3pm mercy hour from due time-of-day packs, resolved at the day's variant labels e.g. `regina_caeli`), `Evening` (examen/night routine), `Commitments` (DueToday with ordinal labels 'ordinal N'), `FeastsComing` (upcomingFeastsProvider(14) beyond today), each `TodayItem { final String title; final ContentPack? pack; final DateTime? anchor; final String? deepLink; final ScheduleResult? resolution; }`
  - Time-of-day packs (`TimeOfDaySpec`) surface in the section matching their hour (6→Morning, 12→Anchors-noon, 15→mercy, 18→Evening)
  - Date-seam: everything keyed off `currentDateProvider.future` (test override = `Stream.value`, the monorepo gotcha — Review Focus 2 pinned with fulfilledOrdinals==count excluded)

- [ ] **Step 1:** Failing tests — frozen 2026-12-05: Five First Saturdays under Commitments with ordinal; angelus pack under Morning/noon section with `angelus` label; Eastertide override (2026-04-20): label `regina_caeli`, Divine Mercy day 8 present; completed set omitted
- [ ] **Step 2:** FAIL — Step 3: implement — Step 4: PASS — Step 5: `git commit -m "feat: today assembly providers (sections, anchors, feasts)"`

---

### Task 13: Today screen UI

**Files:**
- Create: `lib/screens/home/today_screen.dart`, `lib/widgets/today/today_section_card.dart`, `lib/widgets/today/today_item_tile.dart`, `lib/widgets/onboarding/empty_today.dart`
- Modify: routes (`today` → `TodayScreen`)
- Test: `test/screens/today_screen_test.dart`

**Interfaces:**
- Consumes: `todayAssemblyProvider`, liturgical header data (celebration, rank, color via calendar riverpod + `ColorIntensity` theming), `onboardingCompleteProvider`, deep links → `session/:packId`
- Produces: liturgical header (color-ribbon + celebration + rank), time-grouped sections in spec §7 order, tiles (icon by family, ordinal badge, anchor time), empty-state CTA → onboarding when nothing enrolled

- [ ] **Step 1:** Widget tests — frozen 2026-12-05 renders Commitments tile with ordinal badge; tap navigates to session route; empty state shows onboarding CTA
- [ ] **Step 2:** FAIL — Step 3: implement — Step 4: PASS — Step 5: `git commit -m "feat: today screen with liturgical header and section cards"`

---

### Task 14: Practice tab — catalog + detail

**Files:**
- Create: `lib/screens/practice/practice_screen.dart`, `lib/screens/practice/program_detail_screen.dart`
- Modify: routes (`practice`, `program/:packId`), shell tabs (Task 1's router grows into the final `StatefulShellRoute`: today/practice/progress/settings)
- Test: `test/screens/practice_screen_test.dart`, `test/screens/program_detail_screen_test.dart`

**Interfaces:**
- Consumes: `contentLoadedProvider` (catalog), `programDetailProvider` (detail: restartPolicy, remainingDates), pack `family`, pack content for descriptions
- Produces: catalog grouped by family (`commitment | novena | office | routine | chaplet`), detail screen: description, schedule preview (next due dates — `Projection.remainingDates` for commitments; weekday table for weekly loops), phase explainer rows from variants, variants list with the 54-day strict/permissive explainer, **Enroll** CTA → Task 15 route

- [ ] **Step 1:** Widget tests — catalog shows the 8 seeded packs by family; detail of `five_first_saturdays` shows schedule preview containing 2026-12-05 (frozen date) and Enroll CTA; 54-day detail shows the two policy rows
- [ ] **Step 2:** FAIL — Step 3: implement — Step 4: PASS — Step 5: `git commit -m "feat: practice tab with program catalog and detail"`

---

### Task 15: Enrollment flow

**Files:**
- Create: `lib/screens/practice/enroll_screen.dart`, `lib/services/enrollment_service.dart`
- Test: `test/services/enrollment_service_test.dart`, `test/screens/enroll_screen_test.dart`

**Interfaces:**
- Consumes: `SqliteProgramRepository.enroll`, `ContentPack` JSON, `PackLoader.loadFromJsonString`, `ConsecrationPlanner.startFor`, settings (missed-day default policy)
- Produces: `class EnrollmentService { Future<ContentPack> derivePack({required ContentPack pack, required Map<String, dynamic> params}); Future<void> enroll({required ContentPack pack, required Map<String, dynamic> params}); }` —
  - **Commitments (nthWeekdayOfMonth):** enroll as-is; params `{}`; first anchor counts from the next occurrence (persisted progress starts empty — the ordinal math already does this)
  - **Consecration (total_consecration):** param `feast` (nominal date from the pack's `reminders.feastAnchor`); derivePack patches `schedule.startDate` to `ConsecrationPlanner.startFor(feast)`; NO calendar re-resolution of the nominal feast (Plan-1 Task 18 pointer). Params `{feast, startDate, day34}`; after enrolling, the flow offers the day-34 milestone note
  - **54-day:** explainer screen (phases 1–27 petition / 28–54 thanksgiving, one paragraph + mystery cycle); missed-day policy choice (strict | permissive rows, default from settings); param `startDate` = user-picked day-1 (date field); derivePack patches `schedule.startDate`; params carry `restartPolicy` (from `MissedDayEvaluator`'s consumed vocabulary)
  - All derived packs load through `PackLoader.loadFromJsonString` (schema-validated; `startAnchor`/`feastAnchor` reminders left intact)
- Progress on enroll: none (fresh); today's sessions flow naturally

- [ ] **Step 1:** Failing service tests — consecration derive for feast 2027-03-25 → startDate 2027-02-20 (leap case 2028-03-25 → 2028-02-21); 54-day derive patches startDate + preserves reminder blocks; re-enroll (Review Focus 5) replaces pack + params, keeps idempotent progress
- [ ] **Step 2:** Failing widget tests — consecration enroll screen offers the feast picker listing `feastAnchor` entries; 54-day shows phase explainer + policy choice; enroll button writes through the service
- [ ] **Step 3:** FAIL — implement — PASS both files
- [ ] **Step 4:** `git commit -m "feat: commitment-aware enrollment flow with derived packs"`

---

### Task 16: Progress tab

**Files:**
- Create: `lib/screens/progress/progress_screen.dart`, `lib/widgets/progress/badge_list.dart`, `lib/widgets/progress/phase_banner.dart`, `lib/widgets/progress/indulgence_sheet.dart`, `lib/repositories/intentions_repository.dart`
- Modify: `DevotionalsDatabase` gains `IntentionsRepository` wrapper access (from Task 4's table)
- Test: `test/screens/progress_screen_test.dart`, `test/repositories/intentions_repository_test.dart`

**Interfaces:**
- Consumes: `enrolledProgramsProvider`, `programDetailProvider`, `ProgressState.badges`, `VariantService` day→phase labels, `IntentionsRepository` (CRUD on the intentions table)
- Produces: enrolled programs list: ordinal counter chip ('3 of 9' / 'day 28 of 54' — sessionSeries packs), `Projection.remainingDates` line ('next: Dec 5, Jan 2, Feb 6'), `phase_banner` for consecration/54-day (label per dayIndex from pack variants), badges list with dates, lifetime count (= badges length, documented), missed-day verdict surfacing (uses Task 9 when lastFulfilled lags), add/remove intentions + souls (list editor), indulgence sheet (static conditions checklist + the one-per-day plenary cap note)
- Review Focus 2: a 5/5 First-Saturdays program renders 'Complete' with badges — never an ordinal

- [ ] **Step 1:** Failing tests — programs render ordinal + projection line; completed program shows Complete state; intentions add/remove persists; phase banner reads 'Petition · day 6 of 54' from pack variant data; badge list shows dated entries
- [ ] **Step 2:** FAIL — Step 3: implement — Step 4: PASS — Step 5: `git commit -m "feat: progress tab with ordinals, phases, badges, and intentions"`

---

### Task 17: NotificationPlanner (pure service first)

**Files:**
- Create: `lib/services/notification_planner.dart`
- Test: `test/services/notification_planner_test.dart`

**Interfaces:**
- Consumes: settings anchors (`anchorTimesProvider` values), enrolled packs + their pack JSON reminder blocks (`reminders.offset: 'morningOf'`, `fallback`), Projection for commitments (upcoming anchors), `upcomingFeastsProvider(60)` equivalent (pure call into the calendar data, not riverpod — the planner takes `List<LiturgicalDayData>`), pack variant labels for season-aware bodies, `timezone.TZDateTime`, `flutter_timezone` local tz name (injected)
- Produces: `class PlannedNotification { final String id; final DateTime fireAt; final String title; final String body; final String deepLink; final String packId; }` and `class NotificationPlanner { List<PlannedNotification> plan({required DateTime now, required String timeZoneName, required List<ContentPack> packs, required Map<String, Map<String, dynamic>> enrollments, required List<LiturgicalDayData> upcomingFeasts, required DevotionsAppSettings settings, required List<PlannedNotification> alreadyPending}); int get maxPending; // 60 }` —
  - Anchor times repeat **daily** as TZDateTime at the user's local offset (settings toggles gate them; night items only when explicitly enabled — default off)
  - Commitment/novena/series packs: one reminder per session due in the 60-day horizon (`offset: 'morningOf'` = 07:00 local that day; body uses the pack title + ordinal/day, e.g. 'Day 6 of 9'; confession-window note when the pack's GraceWindow exists)
  - Rotation (Review Focus 1+3): output pruned to the `maxPending` nearest upcoming, preferring what's already scheduled; `alreadyPending` lets the app re-run on every refresh point without duplicates (same id = replace)
- Pure Dart — NO plugin imports; the service returns data, Task 18 wires the plugin

- [ ] **Step 1:** Failing tests — 2026-12-01 plan (US Eastern zone name) across the 2027-03-14 DST spring-forward: each PlannedNotification's TZDateTime hour stays 7:00 in the zone's post-DST offset; rotation cap: 100 candidates → 60 returned, nearest first, already-scheduled ids preserved; angelus ×3 (morning/noon/evening) when toggles on; mercy hour 15:00; night items excluded by default, included when enabled
- [ ] **Step 2:** FAIL — Step 3: implement — Step 4: PASS — Step 5: `git commit -m "feat: notification planner with 60-day rotation and DST-safe anchors"`

---

### Task 18: Notification wiring + deep links

**Files:**
- Create: `lib/services/notification_service.dart`
- Modify: `lib/main.dart` (init), `providers/today_providers.dart` (app-open hook), session completion hook (Task 9 → service call)
- Test: `test/services/notification_service_test.dart`

**Interfaces:**
- Consumes: Task 17 planner, `flutter_local_notifications` (Android channel 'devotionals', iOS provisional auth), `flutter_timezone`, planner output, `PendingNotificationRequests` snapshot (= `alreadyPending` source), notification tap → `deep_link` (`context.go` to `session/:packId` or `/`)
- Produces: `class NotificationService { Future<void> initialize(); Future<void> refresh(); Stream<String> get taps; }` — `refresh()` runs: snapshot pending → plan → diff (new ids `zonedSchedule`, changed ids cancel+replace, dropped ids cancel) → persist to `notification_index`; idempotent (second refresh with unchanged inputs = no plugin writes). Refresh hooks: app open (post-splash, after `ensureContentLoaded`), every session completion, notification tap
- Backgrounds/polling: none (refresh points only, per spec §9)

- [ ] **Step 1:** Failing tests (plugin mocked) — refresh writes expected rows; duplicate refresh performs zero writes (diff empties); tap stream yields deep links; settings toggle off cancels that anchor's rows
- [ ] **Step 2:** FAIL — Step 3: implement — Step 4: PASS — Step 5: `git commit -m "feat: notification service wiring with idempotent diff refresh"`

---

### Task 19: Onboarding (~90s flow)

**Files:**
- Create: `lib/screens/onboarding/onboarding_screen.dart` (+ steps: welcome, claim, routine, reminders, done)
- Modify: routes (`onboarding`), `main.dart` (initial location = onboarding when `onboardingComplete` false)
- Test: `test/screens/onboarding_screen_test.dart`

**Interfaces:**
- Consumes: catalog (packs by family), `EnrollmentService` + `SqliteProgramRepository.enroll/progress-save`, `ProgressState` (claim sets `fulfilledOrdinal`+`lastFulfilled`), notification toggle write-through, `onboardingCompleteProvider`
- Produces: welcome (value statement, free/offline note) → **claim existing progress**: pick commitment family packs, stepper per pack ('I'm already N First Fridays in': spinner 0..count, writes progress lastFulfilled = last occurrence before today — computed from `Projection`/anchor math) → **baseline routine**: toggle Morning Offering / Examen / meal & night anchors (enrolls routine packs) → **reminders**: morning/evening enables + notification permission request → done sets `onboardingComplete`

- [ ] **Step 1:** Widget tests — full walk sets `onboardingComplete`; claim 3 First Fridays persists `fulfilledOrdinals: 3` + `lastFulfilled` = 2026-11-07 when frozen `now` = 2026-11-10 (next due 2026-12-05); routine picks enroll packs; reminder enable requests permission once
- [ ] **Step 2:** FAIL — Step 3: implement — Step 4: PASS — Step 5: `git commit -m "feat: onboarding with progress claim, routine picker, and reminders"`

---

### Task 20: Settings screen wiring

**Files:**
- Create: `lib/screens/settings/devotionals_settings_screen.dart`
- Modify: routes (`settings`), `main.dart` (material locale/dark-mode plumbing from `baseSettingsProvider`)
- Test: `test/screens/devotionals_settings_screen_test.dart`

**Interfaces:**
- Consumes: shared_ui `UnifiedSettingsScreen` composition (theme_mode_selector, font_size_selector, color_intensity_selector, notifications_settings, app_info_section) + app-specific section
- Produces: app section: anchor times (time pickers on `anchorTimesProvider`), anchor toggles, night-items toggle (explicit warning 'off by default'), missed-day default policy selector (strict/permissive), Latin display toggle, Luminous toggle; persist via `DevotionsSettingsNotifier`; `notification_service.refresh()` on any schedule-relevant change

- [ ] **Step 1:** Widget tests — toggling an anchor updates settings + triggers a planner refresh (service mocked); policy selection persists; base-settings controls delegate to `baseSettingsProvider`
- [ ] **Step 2:** FAIL — Step 3: implement — Step 4: PASS — Step 5: `git commit -m "feat: settings screen with anchors, policies, and shared-ui integration"`

---

### Task 21: Routine content — prayer companion import + routine anchors

**Files:**
- Create: `tool/import_prayers.dart`, `assets/content/prayers/*.json`, `assets/content/packs/morning_offering.json`, `…/daily_examen.json`, `…/lectio_divina.json`, `…/meal_night_prayers.json`, `…/fixed_prayers_morning.json`, `…/fixed_prayers_night.json`
- Modify: `content_providers.dart` manifest glob (prayers join the packs)
- Test: `test/content/routine_packs_test.dart`

**Interfaces:**
- Consumes: `sancta_via_prayer_companion/assets/prayers/*.json` + `prayers_metadata.json` (67 prayers with `timeOfDay` categories — import source), `PackLoader`, bible riverpod `readingsFor(date)` provider seam for Lectio (PD CPDV/DRC translations already in `sancta_via_bible_data`)
- Produces:
  - `tool/import_prayers.dart`: maps companion schema → engine `PrayerText` entries (id, text, source='companion attribution when present', license field carried over; anything missing source/license is dropped + listed in the tool's stdout as 'rejected'), writes `assets/content/prayers/<id>.json`; committed output is **checked in**, tool re-runnable
  - **morning_offering** pack: routine family; prayer step (traditional Morning Offering text, PD) + `intercession` step (papal-intention line shipped as a manually-updated content field — spec risk #6 handling), monthly metadata key
  - **daily_examen**: reflection steps ×5 with the Ignatian prompts (timeOfDay evening anchor)
  - **lectio_divina**: verse/prayer skeleton + reflection steps; readings content seeded from bible_data (CPDV, PD) with the day's readings resolved by the app via bible riverpod (pack stores the skeleton; a `readings` reminders note documents the app-side feed)
  - **meal_night_prayers**: timeOfDay anchors (11:45 grace-before/after window, 20:30 night set from imported prayers)
- Validation: every pack loads; every text non-empty source+license; schedule resolves fixture year 2026

- [ ] **Step 1:** Run import tool; failing test asserts packs load + resolve + no rejected-prayer regression count change without an explicit list update
- [ ] **Step 2:** PASS; `flutter analyze` clean
- [ ] **Step 3:** `git commit -m "feat: routine packs from prayer companion import (offering, examen, lectio, meals)"`

---

### Task 22: Content — novenas family (≈10 packs)

**Files:**
- Create: `assets/content/packs/{christmas_novena, novena_for_the_dead, holy_spirit_pentecost, sacred_heart, st_jude, undoer_of_knots, miraculous_medal, perpetual_help, st_joseph}.json`
- Modify: nothing in code (packs drop in via the pipeline)
- Test: `test/content/novena_packs_test.dart`

**Interfaces:**
- Authoring rules (from spec §8 + Plan 1 licensing rulings):
  - Schedule per novena: `fixedDate`/`easterOffset`/`sessionSeries` as tradition dictates (Christmas: fixedDate 12/16→12/24; Divine Mercy pack already exists; Holy Spirit: easterOffset offset −10 length 9 ending Pentecost; Perpetual Help: weeklyLoop tuesday; St. Jude: weeklyLoop wednesday; Sacred Heart: easterOffset +61 (friday after Corpus Christi week) for the annual feast-novena pair, else sessionSeries)
  - Texts PD or companion-mode; `source`+`license` on every entry; Divine-Mercy Diary rule unchanged
  - day-indexed novenas carry `dayIndex` variants with `{{day}}`-bearing content where the tradition has per-day texts; undoer-of-knots/st. joseph/for-the-dead use a single static session
- Test pins: all load; resolve ≥1 due date in 2026 + 2027 (fixed-date cross-year proof for the Christmas novena: resolves 2026-12-16..24 AND 2027-12-16 when asked of 2027); st_jude resolves only Wednesdays

- [ ] **Step 1:** Author the 9 packs + failing pack tests
- [ ] **Step 2:** PASS all (loader + resolution + license pins)
- [ ] **Step 3:** `git commit -m "feat: novena packs (9 PD/companion-mode novenas)"`

---

### Task 23: Content — chaplets + litanies

**Files:**
- Create: `assets/content/packs/{st_michael_chaplet, seven_sorrows, franciscan_crown, holy_wounds, st_anne_chaplet}.json`, `…/{litany_loreto, litany_st_joseph, litany_humility, litany_sacred_heart, litany_precious_blood}.json`
- Test: `test/content/chaplet_litanies_packs_test.dart`

**Interfaces:**
- Consumes: engine `BeadGroupStep`/`LitanyStep` shapes (Plan 1 Task 10); family `chaplet`
- Produces: chaplets as bead-script sessions (st_michael: 9 `BeadGroupStep`-style salutes + 4 Our Fathers — modeled per Task 16's supported shapes; seven_sorrows: 7 groups of 1 OF + 7 HM; franciscan_crown: 7 joys + 2 HM with Lenten substitution variant; holy_wounds: 39-bead groups; st_anne: 3×(1 OF + 5 HM)); litanies as `LitanyStep` sessions (invocation lists verbatim PD, response patterns, groupedResponse for Loreto-class)
- Test pins: all load; litanies' step inventory matches the invocation counts (loreto = the traditional invocation list length pinned); crown Lent variant key present

- [ ] **Step 1:** Author 10 packs + failing tests
- [ ] **Step 2:** PASS
- [ ] **Step 3:** `git commit -m "feat: chaplet and litany packs with litany-step sessions"`

---

### Task 24: Angelus full-anchor schedule (contract f)

**Files:**
- Modify: `sancta_via_devotional_engine/test/fixtures/packs/angelus.json` — schedule becomes `schedules: [...]` (the back-compat list schema from Plan 1 Task 14) with three `timeOfDay` entries: 6:00, 12:00, 18:00, each carrying the same season-pure variant set (`regina_caeli` in Eastertide), plus the existing labels
- Propagate: copy to `assets/content/packs/angelus.json`, re-run `tool/embed_packs.dart` in the wrapper, re-copy into engine fixtures dir (single source of truth stays engine fixtures)
- Test: `test/content/daily_anchors_pack_test.dart` (extend), `test/providers/today_providers_test.dart` (noon angelus appears under the noon section)

**Interfaces:**
- Consumes: `TimeOfDaySpec`(hour), pack `schedules` list (alias semantics: consumers read the list), `VariantService`
- Produces: pack resolves at 6/12/18 on any day; Eastertide labels `regina_caeli` at all three anchors

- [ ] **Step 1:** Failing tests — three anchors due on 2026-01-20; `regina_caeli` variant on 2026-04-20 ×3; Today assembly (frozen Easter date) shows angelus under Morning + noon + Evening sections
- [ ] **Step 2:** Implement pack change → PASS engine pack test + wrapper embed regeneration + app test
- [ ] **Step 3:** `git commit -m "feat: angelus pack at 6am, noon, and 6pm anchors"`

---

### Task 25: Integration hardening + release hygiene

**Files:**
- Modify: `README.md` (build/run/regen instructions incl. `melos bootstrap`, import tool, embed tool), `Makefile` entries final, `lib/main.dart` init order (db → content → notifications → router), `pubspec.yaml` version + `tool/update_build_info.sh`
- Test: `test/integration/today_full_day_test.dart`

**Interfaces:**
- Produces: frozen-date end-to-end test (2026-12-05, First-Saturday+Adam-and-Eve-ish ordinary day): seeded 8+ packs, enroll Five First Saturdays + 54-day novena via service, planner refresh once → Today shows commitments, anchors, feasts; notification index rows exist with DST-safe local times; full widget tree renders (pump entire app with overridden clock + repository)
- `melos run analyze` zero new issues; `melos run test` green across engine + wrapper + app

- [ ] **Step 1:** Write the integration test → FAIL (wiring gaps surface) → fix the gaps → PASS
- [ ] **Step 2:** Docs + analyze + suites green
- [ ] **Step 3:** `git commit -m "chore: integration pass, docs, and release hygiene"`

---

## Self-Review Notes

- **Spec coverage:** §4 (data model) → Tasks 4-6; §4.3 step types → Task 11 (all 8 renderers); §5 engines → engine-complete (Tasks 2 seam-only), session player Task 10-11, EditionProvider seam = Plan 3; §6 Today pipeline → Tasks 12-13; §7 screens → Tasks 13, 14, 16, 19, 20 + player 11 + enrollment 15; §8 content → Tasks 21-24 (Office deferred as Plan 3 — scope split); §9 notifications/offline → Tasks 17-18; §10 testing → every task is TDD + Task 25 integration; Plan-2 contract items: (a) checkpoint gate → Task 9, (b) grace-window credit → Task 8, (c) substitution → Task 7, (d) policy overload → Task 2, (e) enrollment read seam → Task 5, (f) angelus anchors → Task 24, plus recompute convention → Task 15
- **Type consistency:** repository/enrollment service names match across Tasks 5/9/15/19; `SubstitutionService.requireFullySubstituted` is the single leakage gate used by Tasks 10/11
- **Review Focus:** each pinned item names its owning task's test (1→T17, 2→T12+T16, 3→T8, 4→T7+T11, 5→T5, 6→T9)
- **Proportion:** plan is decision-dense (signatures, exact values, exact pins); no code bodies beyond interface sketches — the engine already owns all semantics
