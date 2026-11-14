# Saint Histories Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Author grounded, cross-checked 250–800-word summary histories for ≈400 CE-matched saints, ship them in `saints.db` v2 with live per-saint sources, and render them in the saint companion's detail screen.

**Architecture:** A dev-only Dart pipeline in `sancta_via_saint_data/tools/` (selection → grounding scrape → orchestrator) extends each matched saint's story; authored text lands in slug-keyed `data/histories.json`, merged into `assets/saints.db` (schema v2) only by the build tool; the app renders `history` where present, falling back to bio.

**Tech Stack:** Dart dev-only tools (`dart:io` HTTP, `package:crypto`), SQLite via sqflite_common_ffi (existing), model access via `opencode run -m <model>` subprocess (verified working, no new API keys).

**Spec:** docs/superpowers/specs/2026-11-14-saint-histories-design.md

## Global Constraints

- Verse text/content: no editorial invention beyond the grounding source + "tradition holds" hedges for uncertain claims.
- Model access: via `opencode run -m <model>` subprocess calls ONLY (no API keys, no direct endpoints). Authoring model: `ollama/glm-5.3-flash:cloud`; cross-check models rotate `ollama/deepseek-v4.1-flash:cloud` / `ollama/minimax-m3.1-flash:cloud` (a model that did not write the entry).
- Tools are dev-only: nothing in `tools/` imported by runtime code.
- Polite scraping: ≥2.2 s between requests to newadvent.org, resumable/cached, robots rules honored (`/cgi-bin/`, `/tmp/` only blocked).
- Authored entry JSON: history body 400–4000 chars; `historySource` matching `^catholic-encyclopedia-1907 https?://www\.newadvent\.org/cathen/\S+$`.
- `data/saints_source.json` is byte-pinned (manifest sha) — authored text NEVER lands there; it lives in `data/histories.json` and merges at build time.
- Code style per AGENTS.md: single quotes, trailing commas, prefer final/const, explicit types, dart→package→relative import order.
- Match discipline: 1:1 slug↔article only; collisions and <0.9 fuzzy matches quarantine to `data/grounding/manual_review.json`, never auto-shared.

## Review Focus

- **Name-collision leakage**: `St. Adalbert of Egmond` must not resolve to CE's `Adalbert, Saint` article — pinned by Task 1's quarantine tests.
- **Cross-check honesty**: an authoring error the cross-checker flags must actually drop the entry after 2 rounds — pinned by Task 5's loop tests.
- **Schema v2 rollback safety**: `saints.db` v1 opens on the v2 schema (loader `needsAssetRecopy(bundled 2, disk 1)` forces re-copy) — pinned by Task 6's loader test.
- **Provenance honesty**: detail screen attribution says "Adapted from the Catholic Encyclopedia (1907–12)", never "as written by CE" — pinned by Task 7's widget test.
- **Fallback honesty**: a saint without history still renders its bio + prayer unchanged — pinned by Task 7.

---

### Task 1: CE selection tool

**Files:**
- Create: `sancta_via_saint_data/tools/select_ce_matches.dart`
- Test: `sancta_via_saint_data/test/tools/select_ce_matches_test.dart`
- Output (committed): `sancta_via_saint_data/data/grounding/selection.json`, `selection_review.json` (partner-readable summary), `manual_review.json` (quarantine)

**Interfaces:**
- Consumes: `data/saints_source.json` (2,174 seeds), network (newadvent).
- Produces (shapes pinned):
  - `data/grounding/selection.json`: `{"generatedAt": "...", "matches": [{"slug","name","ceCode","ceTitle","ceUrl","patronageCount","featured"}...], "drops": [{"name","reason"}...], "counts": {"seeds","matched","dropped"}}` — ranked: featured first, then patronageCount desc, then name.
  - `selection_review.json`: human-readable variant (name + 2-line CE note per match).
  - `manual_review.json`: `{"collisions": [{"slug","name","ceHead","ceCode"}...], "fuzzy": [{"slug","name","ceHead","ratio"}...]}`.

- [ ] **Step 1: Write failing tests** — unit tests over a committed mini-fixture (not network): a tiny CE-index HTML fixture (`test/fixtures/ce_index_sample.html`) and a 6-saint seed subset, asserting: honorific stripping (`St. Francis of Assisi` → match), trailing-honorific strip (`Francis of Assisi, Saint` → match), surname-reorder (`Loyola, Ignatius` variant), collision quarantine (two slugs matching one article → BOTH quarantined), 1:1 acceptance, ranking order (patronageCount then name), drop reasons recorded.
- [ ] **Step 2: Run, verify FAIL** (`flutter test test/tools/select_ce_matches_test.dart` — tool not defined). Then implement `tools/select_ce_matches.dart`: fetch `cathen/{a..z}-ce.htm` (2.2 s spacing, entity-decode `&nbsp;|&ouml;|&#151;`, parse titles → code), normalize + match, rank, write outputs. `dart analyze tools` clean. Run the real thing; record measured counts in the report.
- [ ] **Step 3: Verify** against the REAL seeds: `matches.length` ∈ [300, 450], all `ceCode` unique, all slugs exist in seeds, no two matches share a `ceCode`. Fixture tests PASS.
- [ ] **Step 4: Commit** `feat(saint_data): CE selection tool with 1:1 normalized matching`.

**GATE (controller, between Task 1 and Task 2):** bring `selection_review.json` to the partner for the approved pre-spend read; record approval + any partner-ordered drops in the ledger; partner-ordered drops re-run through the selection tool's drop list before Task 2 starts.

---

### Task 2: CE grounding scrape

**Files:**
- Create: `sancta_via_saint_data/tools/scrape_grounding.dart`
- Test: `sancta_via_saint_data/test/tools/scrape_grounding_test.dart`
- Output: `data/grounding/<ceCode>.txt` + `data/grounding/manifest.json` + `selection.json` gains `grounded: true|false` per entry.

**Interfaces:**
- Consumes: `selection.json`.
- Produces: `manifest.json`: `{"generatedAt":"...","articles":[{"slug","ceCode","url","file","chars","sha256","fetchedAt"}...]}`; `scrapeGroundingArticle(html) -> {text, title}` pure-ish function (testable).

- [ ] **Step 1: Failing tests** over a committed real fixture (`test/fixtures/ce_article_francis.html`, saved from the verified fetch): asserts boilerplate stripped (no "help support the mission", no letter-nav, no "See also"/copyright tail, no `../cathen` link artifacts), body text present, title extracted, paragraphs joined with blank lines.
- [ ] **Step 2: Implement** — fetch each selected URL (2.2 s spacing, resumable via existing `<ceCode>.txt` presence), strip, save; manifest with sha256; failures recorded per slug (exit 1 with list; retried slugs don't re-fetch existing files).
- [ ] **Step 3: Verify** — all selected slugs grounded (or per-slug failure list); manifest rows == successes; spot-read the Francis text.
- [ ] **Step 4: Commit** `feat(saint_data): CE grounding scrape with manifest`.

---

### Task 3: Authoring orchestrator + cross-check loop

**Files:**
- Create: `sancta_via_saint_data/tools/histories_orchestrator.dart`
- Test: `sancta_via_saint_data/test/tools/histories_orchestrator_test.dart`
- Output: `data/histories.json` (slug-keyed: `{"history","historySource","ceCode","authoredAt","checkedBy"}`), `data/histories_run_report.json` (per-entry status).

**Interfaces:**
- Consumes: `data/grounding/` (manifest + txt files) + `data/saints_source.json` seed facts + `opencode run -m <model>` subprocess (verified working).
- Produces (shape pinned): `data/histories.json` map; entry JSON: `{"slug","history","historySource":"catholic-encyclopedia-1907 https://www.newadvent.org/cathen/<code>.htm","ceCode","authoredAt","checkedBy","roundsUsed"}`.

- [ ] **Step 1: Failing tests** with a FAKE model runner (injected callable, not network): validator rejects a history <400 chars (>4000); author prompt contains the grounding text + seed feast day + `min(800, 1.5×anchorWords)` target; parse of model JSON envelope (tolerates fenced JSON); cross-check `pass` accepts, `issues` triggers a repair round, second `issues` drops the entry; concurrency: 2 simultaneous entries with a serialized fake both complete.
- [ ] **Step 2: Implement**:
  - Deterministic validator (entry vs seed: feast-day consistency, name presence, 400–4000 chars, no `{{`) BEFORE model calls.
  - Author call: `opencode run -m ollama/glm-5.3-flash:cloud "<system+user prompt>"` (target word count from grounding length; rules: grounded in the CE text + "tradition holds" hedges; facts consistent with the seed record; per-entry 240 s timeout, 1 retry).
  - Cross-check call: `opencode run -m ollama/deepseek-v4.1-flash:cloud` (alternating deepseek/minimax per batch) — JSON verdict `{verdict, issues[]}`.
  - Dispute loop ≤2 rounds; concurrency 4–6 via a small process pool; per-entry logs; resume: entries already in `data/histories.json` skipped (idempotent).
- [ ] **Step 3: Verify** — fixture tests PASS; smoke on ONE real entry (Francis of Assisi) end-to-end with real models: accepted entry 400–4000 chars, cross-check pass.
- [ ] **Step 4: Commit** `feat(saint_data): grounded history orchestrator with cross-model check`.

---

### Task 4: Content passes (controller-run, not an implementer dispatch)

**Files:**
- Output growth: `data/histories.json` (≈400 entries), per-batch run reports.

Controller executes repeated orchestrator runs (resumable), spot-reviews 2–3 entries per batch by hand against the grounding text, watches drop counts, keeps the ledger. Complete when every selected slug is accepted, flagged-dropped (with reason), or partner-cleared.

---

### Task 5: Schema v2 + build merge + sources

**Files:**
- Modify: `sancta_via_saint_data/lib/src/db/saints_schema.dart` (version 2), `tools/build_saints_db.dart` (merge + sources), `lib/src/models/saint.dart` (fields), `lib/src/services/saint_repository.dart` (sources join)
- Test: extend `test/db/saints_schema_test.dart`, `test/db/saints_db_integration_test.dart`, `test/tools/build_saints_db_fixture_test.dart`, `test/models/saint_model_test.dart`

**Interfaces:**
- Produces: `saintsSchemaVersion = 2`; DDL adds `ALTER TABLE saints ADD COLUMN history TEXT` / `ADD COLUMN history_source TEXT` + `CREATE TABLE sources(slug TEXT NOT NULL, url TEXT NOT NULL, position INTEGER NOT NULL, PRIMARY KEY (slug, position))`; `Saint` gains optional `history`, `historySource` (fromSourceJson/fromDbRow/toSourceJson chain); `getBySlug` returns `sources: List<String>` from the table (replacing the hardcoded empty); build tool reads `data/histories.json` (validated: 400–4000 chars, source regex, slug exists) and inserts `sources` rows from every seed record's `sources` list for ALL 2,174.

- [ ] **Step 1: Failing tests** — v2 schema (columns exist, `sources` round-trip, version 2, downgrade-loud); build-merge fixture (2-saint fixture + sample histories file → history + history_source populated, sources rows for a saint with sources, a bad-source-regex histories entry exits 1); `fromDbRow` optional new params; loader: `needsAssetRecopy(bundledVersion: 2, diskVersion: 1)` still true.
- [ ] **Step 2: Implement** — DDL + version bump + merge + model fields + getBySlug sources join (`SELECT url FROM sources WHERE slug = ? ORDER BY position`).
- [ ] **Step 3: PASS** all suites (record saint_data count).
- [ ] **Step 4: Commit** `feat(saint_data): schema v2 with histories, history source, and live sources`.

---

### Task 6: Detail screen renders history + sources

**Files:**
- Modify: `/Users/jason/Repos/sancta_via/sanctica_via_saint_companion/...` — CORRECT PATH: `/Users/jason/Repos/sancta_via/sancta_via_saint_companion/lib/screens/saint_detail/saint_detail_screen.dart`
- Test: extend the saint companion's `saint_detail_screen_test.dart`

**Interfaces:**
- Consumes: `getBySlug` now returning history + sources.
- Produces: when history is present, a scrollable History section BETWEEN bio and prayer card with an "Adapted from the Catholic Encyclopedia (1907–12)" attribution line under it; the Sources section (existing dormant widget) goes live via `sources`; saints without history render exactly as today.

- [ ] **Step 1: Failing widget tests** — history present → 'History' section + attribution text render; absent → identical to today (bio + prayer, no History header, no Sources rows); sources rows render URLs as plain launch-less text (Task-13 ruling).
- [ ] **Step 2: Implement** (minimal diff: insert after the bio paragraph inside the existing SingleChildScrollView), repository passthrough.
- [ ] **Step 3: PASS** app suite (record count) + analyze clean.
- [ ] **Step 4: Commit** `feat(saint_companion): render anchored histories and live sources`.

---

### Task 7: Rebuild, integration, verification

**Files:**
- Output: rebuilt `assets/saints.db` (schema v2), regenerated app asset copy, final manifest.

- [ ] **Step 1: Rebuild + propagate** — `dart run tools/build_saints_db.dart` (assert version 2, history rows == accepted count, sources rows == seeds-with-sources count); copy `assets/saints.db` → saint companion app assets (bible-app precedent, both layers stamped).
- [ ] **Step 2: Suites + gates** — saint_data full suite, saint_companion full suite, analyze 0, engines untouched; screenshot of a major saint's detail (Francis) showing bio → History → prayer → sources on the booted simulator.
- [ ] **Step 3: Ledger + final report** — accepted count, dropped list, provenance files committed.
- [ ] **Step 4: Commit** `feat(saint_data): ship anchored saint histories (schema v2)`.

---

## Execution notes

- Task 4's content passes are controller-run (like the thumb download); model calls go through `opencode run` with per-entry 240 s timeouts and 1 retry.
- The partner `selection.json` read is a hard stop-gate between Tasks 1 and 2.
- Schema v2 ships via the loader's existing stamp-refresh (bundled 2 re-copies over users' v1 copies); no in-place ALTER path needed.
- Drop policy is honest: flagged entries return to their existing ~120-word bios; the ledger records what was dropped and why.
