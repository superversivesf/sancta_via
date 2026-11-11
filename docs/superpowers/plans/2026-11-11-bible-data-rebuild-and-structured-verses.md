# Bible Data Rebuild & Structured Verse Rendering — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebuild all three Bible data assets from authoritative upstream sources with native, validated verse structures, and make the reader/verse-selection UIs render true verse numbers from structured data.

**Architecture:** A new dev-only Dart pipeline under `sancta_via_bible_data/tools/build_bibles/` fetches pinned upstream snapshots, normalizes each translation independently into the existing JSON schema, and validates everything against a committed expected-structure manifest. The faithful existing JSON→SQLite converter regenerates `bibles.db`. In parallel, scripture content objects carry `List<BibleVerse>` and the two app screens stop re-parsing flattened text entirely.

**Tech Stack:** Flutter/Dart (Flutter SDK 3.x, Dart 3.13), sqflite_common_ffi (existing), `package:archive` (dev-only, for USFM zip), plain `dart:io` HTTP for fetch.

**Spec:** `docs/superpowers/specs/2026-11-11-bible-data-rebuild-and-structured-verses-design.md`

## Global Constraints

- All data artifacts regenerated, never hand-patched: `assets/bibles/*.json` and `bibles.db` are build outputs only.
- Verse text is upstream-verbatim, whitespace-trimmed only — no editorial rewriting.
- No new runtime dependencies; `package:archive` may be added as `dev_dependency` to `sancta_via_bible_data` only.
- Tools are dev-only: nothing in `tools/` is imported by app runtime code.
- Code style per `AGENTS.md`: single quotes, trailing commas, no `var`/`dynamic` in shipped code (tools may use untyped JSON `Map<String, dynamic>`), AppLogger for errors in `lib/`, group import order (dart / package / relative).
- Committing generated artifacts (`*.json`, `bibles.db`) is expected in Tasks 4–5; the DB is not in git LFS (plain binary commit is the repo's existing convention).
- Do not modify `bible_translation.dart` enum ids (`cpdv`, `drc`, `engwebc`) — they are persisted user settings.

## Review Focus

- **USFM marker leakage**: a verse `text` containing `\f \d \s \q` fragments or stray backslashes must fail validation (validator invariant: no `\` in text) — pinned by Task 3's marker test and asserted per-file in Task 4's asset run.
- **Digit-bearing verse text** (CPDV Acts 20:7 contains "12 (5 + 7)"): the reader must render it verbatim as one verse with number 7, and the copied reference must be "Acts 20:7" — pinned by Task 7's widget test.
- **Ghost-book disappearance** (I/II Esdras, Laodiceans, Prayer of Manasseh, Additional Psalms removed from the DB): a reading app whose saved location or plan references one of the removed book names must degrade gracefully into the existing notFound/"not available" path — pinned by Task 5's DB-validation run asserting these rows are absent, plus existing app tests staying green in Task 9.
- **Prologue chapter "P"** in Sirach/Lamentations (CPDV): must be mapped deterministically — omit prologue chapters from the DB entirely; pinned by Task 4's asset-validation test expecting exactly the manifest chapter set for those books.
- **Cross-translation book-order drift** (WEB-C's Septuagint placements of Esther/Maccabees): `book_order` must follow each translation's own source order — pinned by Task 5's validator asserting manifest book order equals DB `book_order` per translation.

---

### Task 1: Source-fetch tool, manifest, and committed snapshots

**Files:**
- Create: `sancta_via_bible_data/tools/build_bibles/bin/fetch_sources.dart`
- Create: `sancta_via_bible_data/tools/build_bibles/manifest.json`
- Create: `sancta_via_bible_data/assets/sources/` (snapshot files) + `sancta_via_bible_data/assets/sources/ATTRIBUTION.md`
- Modify: `sancta_via_bible_data/pubspec.yaml` (add `archive` as dev_dependency)

**Interfaces:**
- Consumes: pinned URLs below (verified 2026-11-11).
- Produces: `assets/sources/engwebc_usfm.zip`, `assets/sources/EntireBible-CPDV.json`, `assets/sources/CPDV-books.json`, `assets/sources/DRB.json`; `manifest.json` with shape `{"sources": {"<id>": {"url": String, "fallbackUrls": [String], "sha256": String, "fetchedAt": String, "fileSize": int, "revision": String}}}`. Later tasks read snapshots by these fixed names and never re-download.

- [ ] **Step 1: Write `fetch_sources.dart`** — `Future<void> main(List<String> args)` in `sancta_via_bible_data/tools/build_bibles/bin/fetch_sources.dart`: reads `manifest.json` siblings; for each source entry downloads `url` with `dart:io` `HttpClient` into `assets/sources/<id>.<ext>` (resolve zip/json by URL suffix), computes SHA-256 (`package:crypto`? no — use `crypto` if already transitively available, else implement SHA-256 via `package:crypto` dev_dependency; decide by checking `pubspec.lock`), and compares to the manifest entry. `--update` flag: re-download, update `sha256`/`fetchedAt`/`fileSize` in manifest, and print a diff for human review. Exit 1 on checksum mismatch without `--update`.
- [ ] **Step 2: Seed manifest and run fetch** — pinned values in `manifest.json`: `engwebc_usfm` → `https://ebible.org/Scriptures/eng-web-c_usfm.zip` (fallback: `engwebc2025eb.zip` Sword module URL), `cpdv_entire` → `https://raw.githubusercontent.com/draino7n7/cpdv/master/CPDV-JSON/EntireBible-CPDV.json`, `cpdv_books` → `.../CPDV-JSON/books.json` (same base), `drc` → `https://raw.githubusercontent.com/thomas992/catholicbible/main/DRB.json` (fallback: `https://raw.githubusercontent.com/exanx/bible-json/main/DRB-73-Books/<file>.json` joined list). Run `dart tools/build_bibles/bin/fetch_sources.dart` from `sancta_via_bible_data/`; rerun once to verify idempotent checksum verification passes.
- [ ] **Step 3: Verify snapshot structure on disk** — commands, from `sancta_via_bible_data/`:
```bash
unzip -l assets/sources/engwebc_usfm.zip | head -30
python3 -c "import json; d=json.load(open('assets/sources/EntireBible-CPDV.json')); print(list(d)[:5]); print(len(d['Psalms']['18']))"
python3 -c "import json; d=json.load(open('assets/sources/DRB.json')); print(list(d)[:5]); print(len(d.get('Psalm',d.get('Psalms','19'))))"
```
Expected: zip lists one `.usfm` file per book (record 2–3 sample names in the task notes); CPDV file has per-book chapter→verse→text with Psalms 18 present; DRB shape visible (note its exact book-key spelling for psalms — Task 2 mapping depends on it).
- [ ] **Step 4: Commit** — snapshots (unzip USFM? No: commit the zip as-is), tool, manifest, ATTRIBUTION.md (translation names, translator attribution lines, source URLs, fetch dates, public-domain notices from spec §4), pubspec dev_dependency.
```bash
git add sancta_via_bible_data/tools/build_bibles sancta_via_bible_data/assets/sources sancta_via_bible_data/pubspec.yaml pubspec.lock
git commit -m "feat(bible-data): pin upstream sources and add fetch tool"
```

### Task 2: Book-name map and expected-structure manifest

**Files:**
- Create: `sancta_via_bible_data/tools/build_bibles/book_names.json`
- Create: `sancta_via_bible_data/tools/build_bibles/expected_structure.json`
- Create: `sancta_via_bible_data/tools/build_bibles/bin/validate_sources.dart` (throwaway-ish helper that emits per-source chapter/verse counts for manifest generation; committed for re-runs)

**Interfaces:**
- Consumes: snapshots from Task 1 (fixed names), current `bibles.db`.
- Produces: `book_names.json` — `{"<USFM-or-source-key>": {"dbName": String, "order": int}}` merged across sources (keys: USFM book codes like `PSA`/`ESG`/`DAG` for engwebc, CPDV EntireBible keys like `1-Samuel`/`Song2`, DRB keys from Task 1 Step 3's observation); `expected_structure.json` — `{"translations": {"<id>": {"order": [db book names in source order], "chapters": {"<dbName>": {"<chapterNo>": verseCount}}, "referenceVerses": [{"book": String, "chapter": int, "verse": int, "startsWith": String}]}}}`. Task 3's validator and Task 4's builder are the only readers.

- [ ] **Step 1: Dump the DB book-name vocabulary** — command (readonly):
```bash
sqlite3 sancta_via_bible_reading_app/assets/bibles.db "SELECT translation_id, book_name, book_order FROM books ORDER BY translation_id, book_order;" > /tmp/opencode/db_books.txt; head -80 /tmp/opencode/db_books.txt
```
Use the cpdv rows as the canonical DB vocabulary/order (73 names, e.g. `Genesis`, `I Samuel`, `Psalms`, `Revelation…` — take exact spellings from this dump).
- [ ] **Step 2: Generate `book_names.json`** — write the mapping by hand into the file (73 DB names + the distinct source keys found in Task 1 Step 3 and the snapshots: USFM `\id` codes, `1-Samuel`/`Song2`-style CPDV keys, DRB keys). Every DB name's `order` = its `book_order` from Step 1's cpdv dump. Include the WEB-C-only spellings as additional keys (`ESG`→`Esther`, `DAG`→`Daniel`, `1SG`?—check actual `\id` codes in the usfm zip and include what exists).
- [ ] **Step 3: Emit per-translation chapter/verse counts** — `validate_sources.dart` prints for each translation each book's chapter count and verse count per chapter (parsing with the same adapters Task 4 will use: for now simple inline parse: USFM `\c`/`\v` line counting, CPDV/DRB JSON `len(chapter)`). Run it, paste output into `expected_structure.json` (chapters keyed numerically; skip `"P"` prologues).
- [ ] **Step 4: Pin reference verses** — verify each of these against the snapshots and the independent refs below; record `"startsWith"` with the exact first 25–40 chars of the target verse:
  - engwebc (against USFM source): `Psalms 18:16` → "He sent from on high.", `Psalms 19:11` → "Moreover by them", `Psalms 119:8` → (from source; fill exact text), `Matthew 6:33` → from source, `Esther 4:1` → from source.
  - cpdv: `Psalms 18:1` → "Unto the end. A Psalm of David.", `Acts 20:7` → starts with "On the first day of the week" (digit-bearing: verify full text contains "12 (5 + 7)" and record its `startsWith`), `Psalms 119:7` → from source (last verse of Vulgate Ps 119).
  - drc: `Genesis 1:1` → "In the beginning God created heaven", `Sirach 1:1` → from source, `Revelation 22:21` → from source.
  Cross-check WEB refs against `https://bible-api.com` fetches and cpdv/drc against sacredbible.org/drbo.org if any mismatch appears. If a source's reference verse disagrees materially with a pin, STOP and investigate before continuing (that indicates wrong source).
- [ ] **Step 5: Commit**
```bash
git add sancta_via_bible_data/tools/build_bibles
git commit -m "feat(bible-data): add book-name map and expected structure manifest"
```

### Task 3: Structure validator + expected structure model (TDD)

**Files:**
- Create: `sancta_via_bible_data/lib/src/utils/bible_structure_validator.dart`
- Test: `sancta_via_bible_data/test/bible_structure_validator_test.dart`

**Interfaces:**
- Produces (used by Task 4 asset tests, Task 5 DB tool):
```dart
// lib/src/utils/bible_structure_validator.dart
List<String> validateBibleStructure({
  required Map<String, Map<String, Map<int, Map<int, String>>>> translations, // id -> dbName -> chapterNo -> verseNo -> text
  required Map<String, dynamic> expectedStructure,                            // parsed expected_structure.json
});
```
Error strings must name translation, book, chapter, and rule (grep-able, e.g. `engwebc Psalms 118: contiguous numbering gap at verse 7`).

- [ ] **Step 1: Write failing tests** — `bible_structure_validator_test.dart`, six tests with tiny in-memory fixtures: (1) valid two-translation fixture → empty list; (2) missing book (`expected` has `Genesis`, data lacks it) → error naming it; (3) chapter verse-count mismatch (manifest says 3 verses, data has 2) → error; (4) numbering gap (verses 1,2,4) → contiguous-numbering error; (5) empty text verse (`''` after trim) → non-empty-text error; (6) USFM-marker leak (`'He said \\d text'` in a verse) → backslash-in-text error; (7) reference-verse mismatch (pin says verse startsWith "For God so loved", fixture text is different) → error naming book:chapter:verse.
- [ ] **Step 2: Run tests, verify failures**
```bash
cd sancta_via_bible_data && flutter test test/bible_structure_validator_test.dart
```
Expected: FAIL ("validateBibleStructure" not defined).
- [ ] **Step 3: Implement `validateBibleStructure`** — one pass per translation: book-set equality with manifest `order`; per-book chapter keys equal manifest chapters; per-chapter verse keys exactly `1..verseCount`; no empty/whitespace-only texts; `!text.contains('\\')`; for each `referenceVerses` entry: verse exists and `text.startsWith(pin)`. Each violation appends a distinct message.
- [ ] **Step 4: Run tests, verify pass** — same command; Expected: all PASS.
- [ ] **Step 5: Commit**
```bash
git add sancta_via_bible_data/lib/src/utils/bible_structure_validator.dart sancta_via_bible_data/test/bible_structure_validator_test.dart
git commit -m "feat(bible-data): structure validator with manifest checks"
```

### Task 4: Build JSONs from snapshots (adapters + regeneration + asset tests)

**Files:**
- Create: `sancta_via_bible_data/tools/build_bibles/bin/build_json.dart`
- Create: `sancta_via_bible_data/tools/build_bibles/lib/usfm_parser.dart` (imported relatively by the bin script)
- Modify: `sancta_via_bible_data/assets/bibles/engwebc.json`, `cpdv.json`, `drc.json` (regenerated)
- Test: `sancta_via_bible_data/test/bible_usfm_parser_test.dart`
- Test: `sancta_via_bible_data/test/bible_assets_validation_test.dart`

**Interfaces:**
- Consumes: Task 1 snapshots, Task 2 `book_names.json` + `expected_structure.json`, Task 3 `validateBibleStructure`.
- Produces: the three `assets/bibles/*.json` in the existing schema `{translation, metadata, books: [{name, chapters: [{chapter, verses: [{verse, text}]}]}]}`; and the parser API:
```dart
// tools/build_bibles/lib/usfm_parser.dart
class UsfmChapter { final int number; final List<(int, String)> verses; const UsfmChapter(this.number, this.verses); }
List<UsfmChapter> parseUsfmBook(String usfmText);  // drops \\d/\\s/\\f/\\q/\\p markers from verse text
```

- [ ] **Step 1: Write failing USFM parser tests** — fixture string with: `\\id PSA`, a `\\d` superscription before `\\c 18`, `\\c 18`, `\\v 1 He said \\w love\\w* to them`, `\\c 19`, `\\v 1 Clouds darkened. \\f + \\fr 4:1 \\ft footnote text\\f* \\v 2 Then light.` — assertions: chapter 18 has one verse `He said love to them` (inline marker `\\w`/`\\w*` stripped, text kept); verse does not contain any `\` character; chapter 19 verse 1 text ends at the footnote (`Clouds darkened.`), footnote body dropped, verse 2 = `Then light.`; superscription/`\\d` content absent from verses.
- [ ] **Step 2: Run, verify fail** — `flutter test test/bible_usfm_parser_test.dart` → FAIL (no such file `usfm_parser.dart`).
- [ ] **Step 3: Implement `parseUsfmBook`** — split on `\\v ` tokens; within each verse retain inline-character-marker text but strip all backslash markers/tags (`\\w`, `\\w*`, `\\f`–`\\f*` sections), concatenate with single spaces, collapse whitespace, trim; chapter number from the nearest preceding `\\c`; ignore text before the first `\\v` of a chapter (headings).
- [ ] **Step 4: Run parser tests, verify pass.**
- [ ] **Step 5: Write `build_json.dart`** — `Future<void> main(List<String> args)`: three adapters: engwebc = unzip zip in-memory (`package:archive`, dev_dependency), route each file by its `\\id` code through `book_names.json`; cpdv = `EntireBible-CPDV.json` keyed by its book keys, skipping `P` prologue chapters; drc = DRB.json keyed by its keys. Build verse text verbatim (trimmed), drop empty-text verses only if the manifest chapter count agrees WITHOUT them? No — emit as-is and let validation fail if any verse text is empty (no silent dropping). Write minimal-pretty JSON files to `assets/bibles/{engwebc,cpdv,drc}.json` with `metadata` `{name, abbreviation, books, verses}` fields matching the existing files' shape.
- [ ] **Step 6: Write `bible_assets_validation_test.dart`** — loads all three real JSONs from `assets/bibles/` via `File` relative to package root, converts to the validator's triple map, and asserts: `validateBibleStructure(..., expectedStructure)` returns empty; then spec-pinned regressions: engwebc `Psalms/18` → 50 verses, `Psalms/19` → 14, `Psalms/119` → 176; cpdv `Psalms/18` → 15; no translation contains `I Esdras`/`II Esdras`/`Laodiceans`/`Prayer of Manasses`/`Additional Psalm`; `Sirach` chapter list excludes chapter `0`.
- [ ] **Step 7: Run build + tests**
```bash
cd sancta_via_bible_data && dart tools/build_bibles/bin/build_json.dart && flutter test test/bible_assets_validation_test.dart test/bible_usfm_parser_test.dart
```
Expected: build prints per-translation book/verse counts; tests PASS. If validation errors appear, fix the adapter/parser or the manifest — never the generated JSON by hand.
- [ ] **Step 8: Commit**
```bash
git add sancta_via_bible_data/tools/build_bibles sancta_via_bible_data/assets/bibles sancta_via_bible_data/test
git commit -m "feat(bible-data): rebuild translation JSONs from upstream snapshots"
```

### Task 5: Rebuild bibles.db + DB validation tool

**Files:**
- Modify: `sancta_via_bible_reading_app/assets/bibles.db` (regenerated)
- Create: `sancta_via_bible_reading_app/tools/validate_bible_db.dart`
- Modify: `sancta_via_bible_data/DATA.md` (new sources, numbering note, validation instructions)

**Interfaces:**
- Consumes: Task 4 JSONs; existing `tools/build_bible_database.dart` (unchanged); Task 3 validator.
- Produces: `validate_bible_db.dart` — `Future<int> main()` returning 0/1; loads `assets/bibles.db` via `sqflite_common_ffi` (readonly) into the validator's triple map and returns 1 on any error, printing errors with the same grep-able prefixes.

- [ ] **Step 1: Write `validate_bible_db.dart`** — reuses `packagesancta_via_bible_data` import of `validateBibleStructure` (add path/relative import consistent with existing tools; `pubspec_overrides.yaml` already wires the local package); assert additionally: every `verses` row's `(translation_id, book_name, chapter_number, verse_number)` is unique (already UNIQUE-constrained — verify row counts equal manifest totals) and `book_order` equals the manifest's order index + 1 per translation.
- [ ] **Step 2: Rebuild the DB** — from `sancta_via_bible_reading_app/`:
```bash
dart tools/build_bible_database.dart
```
- [ ] **Step 3: Run DB validation + corruption probes**
```bash
dart tools/validate_bible_db.dart
sqlite3 sancta_via_bible_reading_app/assets/bibles.db "
  SELECT translation_id, COUNT(*) FROM verses WHERE TRIM(text)='' GROUP BY translation_id;
  SELECT translation_id, book_name, COUNT(DISTINCT book_name) FROM verses WHERE book_name IN ('I Esdras','II Esdras','Laodiceans','Prayer of Manasses','Additional Psalm') GROUP BY translation_id, book_name;
  SELECT translation_id, LENGTH(text) FROM verses WHERE LENGTH(text)>1000 ORDER BY LENGTH(text) DESC LIMIT 10;
  SELECT translation_id, verse_count FROM translations;"
```
Expected: no empty-text rows; ghost books absent; no verse over ~600 chars; per-translation verse_count sums match manifest (engwebc/cpdv/drc totals from spec/source — record actuals).
- [ ] **Step 4: Update `DATA.md`** — document: rebuilt from committed snapshots (paths), per-translation native numbering (with the psalm-numbering sentence from the spec), validation tool commands, and remove the "legacy directory" instructions that reference `legacy/`.
- [ ] **Step 5: Commit**
```bash
git add sancta_via_bible_reading_app/tools/validate_bible_db.dart sancta_via_bible_reading_app/assets/bibles.db sancta_via_bible_data/DATA.md
git commit -m "feat(bible-data): rebuild bibles.db from corrected JSONs with validation"
```

### Task 6: Structured verses on the content objects (TDD)

**Files:**
- Modify: `sancta_via_bible_data/lib/src/services/bible_service.dart:10-66, 170-232`
- Modify: `sancta_via_bible_data/lib/src/services/optimized_bible_service.dart:7-53, 68-170`
- Test: `sancta_via_bible_data/test/bible_data_test.dart` (add a group at the end)

**Interfaces:**
- Produces (used by Tasks 7–8):
```dart
class ScriptureContent {
  // NEW nullable field, default const [] — existing positional usage untouched
  final List<BibleVerse> verses; // real numbers from the chapter/range
}
// Same change on OptimizedScriptureContent. Factories gain `List<BibleVerse> verses = const []`.
```

- [ ] **Step 1: Write failing tests** — append to `test/bible_data_test.dart`: with the existing loader/fixture setup in that file, request a whole chapter reference (pick one the file already covers) and assert `content.verses` is non-empty, ordered ascending, and `content.verses[i].number == i + 1`; request a 2-verse range and assert exactly 2 verse objects with those numbers and that `content.text` still contains both texts prefixed by their numbers; request a missing chapter and assert `verses` is empty on notFound. Mirror the same three assertions for `OptimizedBibleService` if that file's tests exist here; otherwise only the `BibleService` ones (the optimized path gets covered by the app's Task 7 fixtures).
- [ ] **Step 2: Run, verify fail** — `flutter test test/bible_data_test.dart` → FAIL (`verses` getter/field missing).
- [ ] **Step 3: Implement** — add `final List<BibleVerse> verses;` default `const []` to both classes (factories gain optional param, notFound default const []); in `BibleService.getScriptureContent` pass `chapter.verses` (whole-chapter) or the `getVerseRange` result (range) into `.found(...)`; same in `OptimizedBibleService.getScriptureContent`. Keep `text` exactly as today (it stays the derived display string).
- [ ] **Step 4: Run package tests, verify pass** — `flutter test test/` in `sancta_via_bible_data`; all green.
- [ ] **Step 5: Commit**
```bash
git add sancta_via_bible_data/lib/src/services sancta_via_bible_data/test
git commit -m "feat(bible-data): expose structured verses on scripture content"
```

### Task 7: chapter_reading_screen renders true verse numbers (TDD)

**Files:**
- Modify: `sancta_via_bible_reading_app/lib/screens/chapter/chapter_reading_screen.dart` (`_buildSelectableChapterText` ~458-484, `_parseVersesFromChapter` ~699-739, scroll-to-verse ~741+, tap/copy ~487-544)
- Test: `sancta_via_bible_reading_app/test/chapter_reading_structured_verses_test.dart` (new; follow the provider-override pattern of `test/chapter_reading_scrollbar_test.dart`)

**Interfaces:**
- Consumes: `OptimizedScriptureContent.verses` (Task 6); existing providers unchanged.
- Produces: screen behavior — displayed numbers are `verse.number`; copy format unchanged (`'$verseText ($currentBookName $currentChapter:$verseNumber, $translationAbbrev)'`) but with the true number.

- [ ] **Step 1: Write failing widget tests** — pump `ChapterReadingScreen` with provider overrides exactly as `chapter_reading_scrollbar_test.dart` does, but override the scripture provider with `OptimizedScriptureContent.found(..., verses: [BibleVerse(number: 1, text: 'Alpha text.'), BibleVerse(number: 5, text: 'Beta says 12 (5 + 7) done.'), BibleVerse(number: 7, text: 'Gamma text.')])` and `text: '1 Alpha text. 5 Beta says 12 (5 + 7) done. 7 Gamma text.'`. Assert: exactly 3 verse rows rendered; the first row's bold leading number renders `1` (find RichText/TextSpan — assert the full displayed string of row 1 equals `'1 Alpha text.'`), row 2 equals `'5 Beta says 12 (5 + 7) done.'` (digit preserved, NOT split into '5'/'12' fragments), row 3 equals `'7 Gamma text.'` (gap 5→7 renders row numbers 1,5,7 — NOT 1,2,3); tapping row 2 copies a string containing `( <chapter>:5, ` (true number 5, not 2).
- [ ] **Step 2: Run, verify fail** —
```bash
cd sancta_via_bible_reading_app && flutter test test/chapter_reading_structured_verses_test.dart
```
Expected: FAIL (current code re-parses string positionally → rows numbered 1,2,3 and digit-breaks).
- [ ] **Step 3: Implement** — `_buildSelectableChapterText(context, scripture, themeColor)`: take `scripture.verses`, map entries with `final verseNumber = verse.number;`; `_handleVerseTap` keeps its signature (already receives `verseNumber` — now the true number); delete `_parseVersesFromChapter` and its only call site; in scroll-to-verse, map a requested verse number via `verses.indexWhere((v) => v.number == startVerse)` for key lookup (keep the rest of the scroll logic).
- [ ] **Step 4: Run app widget tests, verify pass** — new test + `flutter test test/chapter_reading_scrollbar_test.dart test/widget_test.dart` still green.
- [ ] **Step 5: Commit**
```bash
git add sancta_via_bible_reading_app/lib/screens/chapter sancta_via_bible_reading_app/test
git commit -m "feat(bible-app): render true verse numbers in reading screen"
```

### Task 8: verse_selection_screen uses real verse numbers (TDD)

**Files:**
- Modify: `sancta_via_bible_reading_app/lib/screens/verse_selection/verse_selection_screen.dart` (`_buildVerseGrid` ~125-301, `_parseVerses` ~303-350)
- Test: `sancta_via_bible_reading_app/test/verse_selection_screen_test.dart` (new, same provider-override pattern as Task 7)

**Interfaces:**
- Consumes: `ScriptureContent.verses` (Task 6).
- Produces: grid `itemCount = scripture.verses.length`; each tile shows `verses[i].number`; tap navigates with that true number.

- [ ] **Step 1: Write failing widget tests** — override `scriptureByReferenceProvider` (the non-optimized one) with `ScriptureContent.found(..., verses: [1..15 as numbers 1..9,11..15? no: numbers 1..15])` plus a variant chapter with `verses: [BibleVerse(1),BibleVerse(5),BibleVerse(7)]`; assert grid renders 3 tiles labeled 1, 5, 7 (find widgets by `Text('5')` etc.), and tapping the tile labeled 5 pushes a location carrying verse 5 (assert via the widget-test navigation callback used in existing tests, or the pushed route arguments pattern from `chapter_reading_scrollbar_test.dart`).
- [ ] **Step 2: Run, verify fail** — `flutter test test/verse_selection_screen_test.dart` → FAIL (3 verses parsed from string ≠ 3 tiles with those numbers; current code shows 1,2,3).
- [ ] **Step 3: Implement** — in `_buildVerseGrid`: replace `final verses = ...; final verseCount = verses.length;` with `final verseCount = scripture.verses.length;`; in the grid builder use `final verseNumber = scripture.verses[index].number;` for both the tile label and `_navigateToChapterWithVerse(context, verseNumber)`; delete `_parseVerses` and the sentence fallback.
- [ ] **Step 4: Run, verify pass** — new test + existing `test/widget_test.dart` green.
- [ ] **Step 5: Commit**
```bash
git add sancta_via_bible_reading_app/lib/screens/verse_selection sancta_via_bible_reading_app/test
git commit -m "feat(bible-app): real verse numbers in verse selection grid"
```

### Task 9: Full gates and acceptance verification

**Files:**
- No new files (verification + fixes only). Any fix found here is a normal code change committed on its own merit.

- [ ] **Step 1: Format + analyze both packages**
```bash
dart format sancta_via_bible_data/lib sancta_via_bible_data/tools sancta_via_bible_data/test sancta_via_bible_reading_app/lib sancta_via_bible_reading_app/test sancta_via_bible_reading_app/tools
cd sancta_via_bible_data && flutter analyze && flutter test && cd ../sancta_via_bible_reading_app && flutter analyze && flutter test
```
Expected: zero analyzer issues; all tests green (record counts).
- [ ] **Step 2: Acceptance probes on rebuilt assets** — run Task 5's DB probes and Task 4's asset tests once more on the final artifacts; verify the spec's acceptance criteria §8 one by one (WEB-C psalm counts 50/14/72/176; no empty rows; ghost books absent; true numbers in UI tests copy format).
- [ ] **Step 3: Commit any stragglers + tag the work**
```bash
git status --short   # must show nothing uncommitted
git log --oneline -12  # record the task chain in the report to the user
```
- [ ] **Step 4: Report** — summarize: counts per translation (old → new), list of deleted regex functions, and how to re-run the pipeline (`fetch_sources.dart --update`, `build_json.dart`, `build_bible_database.dart`, `validate_bible_db.dart`).
