# Modern Saint Histories Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Extend the grounded-history pipeline to a second license-clean source class (Wikipedia, CC BY-SA 4.0) and author grounded histories for the modern-era saints, incl. St John Paul II.

**Architecture:** The existing pipeline (selection → grounding scrape → orchestrator author/cross-check → build merge → detail render) stays as-is; we widen the `historySource` format from the single pinned class `catholic-encyclopedia-1907` to a two-entry class registry (`catholic-encyclopedia-1907`, `wikipedia`) and add a Wikipedia grounding scraper that writes the same `data/grounding/` shape (plain-text + sha256 manifest). App attribution lines are chosen by source-class prefix.

**Tech Stack:** Dart/Flutter (saint_data package + saint_companion app), Wikipedia plain-text API (`action=query&prop=extracts&explaintext=1`), existing orchestrator with cross-model check.

**Spec:** Repo `docs/superpowers/plans/2026-11-14-saint-histories.md` (pipeline, Global Constraints) plus the source-class decisions recorded in this document's Global Constraints. No separate spec file for this extension.

## Global Constraints

- Sources are license-clean only: `catholic-encyclopedia-1907` (PD, New Advent) and `wikipedia` (CC BY-SA 4.0). No vatican.va / CNA / Franciscan Media content.
- `historySource` format: `<class> <url>` where class ∈ {`catholic-encyclopedia-1907`, `wikipedia`}. Anything else is invalid (exit 1).
- Attribution copy pinned EXACTLY: CE class → `Adapted from the Catholic Encyclopedia (1907–12)`; Wikipedia class → `Adapted from Wikipedia (CC BY-SA 4.0)`.
- Authoring rules unchanged: grounded-in-source claims only, "tradition holds" hedges, 400–4000 chars, cross-check dispute loop ≤ 2 rounds.
- Wikipedia grounding scraped via `https://en.wikipedia.org/w/api.php?action=query&prop=extracts&explaintext=1&format=json&titles=<title>&formatversion=2&redirects=1` — plain text, manifest entry carries sha256 like the CE manifest.
- Never push from a subagent; commit messages exactly as specified per task.

## Review Focus

- **Unknown source class**: a history with `historySource: random-site <url>` must abort loudly, never silently merge — pinned by Task 1.
- **Disambiguation**: seed `sources` lists may point at a Wikipedia disambiguation/homograph page (e.g. two saints named Martin); the scraper must fail-loud (exit 1) when the fetched extract's first line doesn't contain the saint's name, not ingest the wrong person — pinned by Task 2.
- **Attribution correctness**: a Wikipedia-sourced saint must never render the CE attribution line — pinned by Task 5.
- **Provenance completeness**: every merged Wikipedia history must carry a `historySource` whose URL is in that seed's `sources` list — pinned by Task 4's merge check.
- **Modern-saint honesty**: saints whose grounding extract is too short (<2000 chars) are dropped, not forced — Task 4 run report gates on drops > 0 being reported, not hidden.

---

### Task 1: Source-class registry + validation

**Files:**
- Create: `lib/src/utils/history_source.dart`
- Modify: `tools/histories_orchestrator.dart` (replace single `historySourcePattern`), `tools/build_saints_db.dart` (merge validation)
- Test: extend `test/tools/histories_orchestrator_test.dart`, `test/tools/build_saints_db_fixture_test.dart`, create `test/utils/history_source_test.dart`

**Interfaces:**
- Produces: `sourceClasses: Map<String, String>` (class → attribution line, exact pinned copy); `RegExp historySourcePatternFor(Iterable<String> classes)`; helper `String attributionFor(String historySource)` (throws on unknown class). Old behavior preserved for `catholic-encyclopedia-1907`.

- [ ] **Step 1: Failing tests** — `wikipedia https://en.wikipedia.org/wiki/Pope_John_Paul_II` valid; `random-site <url>` invalid; `attributionFor` returns both pinned lines; orchestrator test: a wikipedia-class entry passes validation; build fixture: bad class exits 1.
- [ ] **Step 2: Run tests, verify FAIL** (`dart test test/utils/history_source_test.dart test/tools/`)
- [ ] **Step 3: Implement** the registry + wire both tools.
- [ ] **Step 4: Full saint_data suite PASS** (record count; baseline 249)
- [ ] **Step 5: Commit** `feat(saint_data): source-class registry for wiki-sourced histories`

### Task 2: Wikipedia grounding scraper

**Files:**
- Create: `tools/wikipedia_grounding.dart`, output dir `data/grounding_wikipedia/` (+ `.gitignore`? No — committed like CE grounding)
- Test: create `test/tools/wikipedia_grounding_test.dart`

**Interfaces:**
- Consumes: seed `sources` lists in `data/saints_source.json` (first `en.wikipedia.org/wiki/...` URL = the article title).
- Produces: `data/grounding_wikipedia/<slug>.txt` plain text + `manifest.json` with the CE manifest's entry shape (`slug`, `url`, `file`, `chars`, `sha256`, `fetchedAt`) + `"title"` field.

- [ ] **Step 1: Failing test** — fixture: parse a recorded `explaintext` JSON response → extract, dedupe section headers, write file + manifest entry with sha256; first-line/seed-name mismatch → exit 1 (Review Focus disambiguation).
- [ ] **Step 2: Verify FAIL**
- [ ] **Step 3: Implement** (HTTP GET network part modeled on the CE scraper's structure; per-entry timeout + 1 retry)
- [ ] **Step 4: PASS + analyze clean**
- [ ] **Step 5: Commit** `feat(saint_data): wikipedia grounding scraper with manifest`

### Task 3: Thérèse of Lisieux CE recovery (ops)

**Files:**
- Modify: `data/grounding/` (+`17721a.txt` + manifest entry), `data/grounding/selection.json` (add match therese-of-lisieux → article "Teresa of Lisieux, Saint"), then `data/histories.json` via orchestrator

- [ ] **Step 1: Fetch** `https://www.newadvent.org/cathen/17721a.htm` with the CE scraper's fetch path; confirm sha256 + manifest entry `therese-of-lisieux` / ceCode `17721a`.
- [ ] **Step 2: Add the selection match** (slug `therese-of-lisieux`, article url `https://www.newadvent.org/cathen/17721a.htm`) with the same field shape as siblings.
- [ ] **Step 3: Author** `dart run tools/histories_orchestrator.dart --slug therese-of-lisieux` → accepted in ≤2 rounds; verify history in `data/histories.json` with CE-class source.
- [ ] **Step 4: Commit** `feat(saint_data): recover therese-of-lisieux grounded history (CE 17721a)`

### Task 4: Modern batch — scrape + author 52 (ops)

**Files:**
- Output: `data/grounding_wikipedia/*.txt` + manifest (~52), `data/histories.json`, `data/histories_run_report.json`

- [ ] **Step 1: Enumerate** eligible slugs (seed `canonized` >= 1918; expect 52 incl. `john-paul-ii`) → write `data/wikipedia_batch.json` (slug → title) mapping each to its seed wikipedia URL; flag saints whose `sources` list has no wikipedia URL for manual title fix-up (explicit list in run report).
- [ ] **Step 2: Scrape** all eligible slugs → verify count + manifest.
- [ ] **Step 3: Author** the batch (`.superpowers/sdd/` gates: run orchestrator unthrottled as in the 2026-11-14 run, concurrency 5) → review run report: accepted/dropped/error counts and no `random-site` classes; drop every drop name in the report.
- [ ] **Step 4: Commit** `feat(saint_data): author wikipedia-grounded histories for modern saints`

### Task 5: App attribution by source class

**Files:**
- Modify: `/Users/jason/Repos/sancta_via/sancta_via_saint_companion/lib/screens/saint_detail/saint_detail_screen.dart`, plus app db copy gets updated in Task 6
- Test: extend the app's `saint_detail_screen_test.dart`

- [ ] **Step 1: Failing widget tests** — saint with `historySource: wikipedia ...` renders `Adapted from Wikipedia (CC BY-SA 4.0)`; CE source still renders the exact CE line; unknown class falls back to `Adapted from a Catholic source` (never CE line).
- [ ] **Step 2: Verify FAIL**
- [ ] **Step 3: Implement** prefix lookup (mirror the pinned strings from Task 1's registry; keep the app-side mapping local to the screen file to avoid a new app↔package contract).
- [ ] **Step 4: PASS + analyze clean** (record count, baseline 67)
- [ ] **Step 5: Commit** `feat(saint_companion): render source-class attribution for wiki histories`

### Task 6: Rebuild, propagate, verify (ops)

- [ ] **Step 1:** `dart run tools/build_saints_db.dart` — asserts source classes all valid; history rows now > 312 (record the exact count); copy → app assets; sqlite3 verify user_version 2 + counts.
- [ ] **Step 2:** saint_companion + saint_data suites PASS, analyze 0. Simulator: screenshot John Paul II detail showing History with the Wikipedia attribution line.
- [ ] **Step 3:** Commit `feat(saint_data): ship modern saint histories via wikipedia sourcing`

### Task 7 (needs a separate go-ahead): curate missing famous moderns (Padre Pio, More, Fisher, Serra, Charbel, Newman, Paul VI)

**Files:**
- Modify: `data/saints_source.json` (7 new entries: complete fields — slug, name, feastDay, bio, patronages, prayer, sources incl. the wikipedia URL + license note, `draft: false`)

- [ ] **Step 1: Draft** the 7 entries; bio adapted from Wikipedia (attribution), prayers: traditional/PD or attributed.
- [ ] **Step 2:** partner gate — user reviews entries before merge.
- [ ] **Step 3: Merge + build + author** their histories (CE for More/Fisher/Serra/Charbel/Newman where CE articles exist; wikipedia for Padre Pio/Paul VI).
- [ ] **Step 4: Commit** `feat(saint_data): curate missing modern saints` (only after the user's gate).

---

**Execution note:** tasks 1, 2, 5 are code (TDD); tasks 3, 4, 6 are operator runs with report gates; task 7 is user-gated curation.
