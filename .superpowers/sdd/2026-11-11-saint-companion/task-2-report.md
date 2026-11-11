# Task 2 Report: Models — `Saint`, `SaintPatronage`, `SaintPrayer`, `SaintCategory`, `SaintSearchResult`

**Status:** DONE
**Commit:** `873c46d` — `feat(saint_data): saint models and category enum`

## What I did (TDD, per brief Steps 1–5)
1. Read `task-2-brief.md`, the plan (`docs/superpowers/plans/2026-11-11-saint-companion.md`,
   Task 2 + Task 7 + Task 5 sections), the design spec §5/§6 (DB columns, `thumb_asset`
   shape), and Task 1's report. Read the verbatim taxonomy from the read-only sibling repo
   `/Users/jason/Repos/saint-for-that/site/src/lib/taxonomy.ts` (CATEGORIES, lines 8–17 —
   file only read, never written) and the real raw record `data/saints/abba-garima.json`
   (plus canonized/image-bearing records) to base fixtures on the true shape.
2. **Step 1:** Wrote `test/models/saint_model_test.dart` first — 28 model tests covering
   every brief bullet (see test list below).
3. **Step 2:** `flutter test test/models/saint_model_test.dart` → compile failure
   (`Saint`, `SaintSearchResult` etc. undefined), as required.
4. **Step 3:** Implemented the three model files + barrel exports.
5. **Step 4:** `flutter test` (package root) → `00:00 +29: All tests passed!`
   (28 model tests + Task 1's logger smoke test).
6. **Step 5:** Committed exactly the 5 files with the brief's message. Did not push.

## Files
- `sancta_via_saint_data/lib/src/models/saint_category.dart` — enhanced enum with the 10 ids
  in brief order (`everyday, illness, jobs, travel, persecution, spiritual, military, family,
  nature, special`), label/description constructor fields (verbatim from taxonomy.ts —
  byte-equal, including `'Military & first responders'`, `'Animals & nature'`, etc.), and
  `static SaintCategory? tryParse(String id)` (null for unknown/empty ids).
- `sancta_via_saint_data/lib/src/models/saint.dart` — three classes:
  - `SaintPatronage` (need + category; `fromJson` throws FormatException on missing need or
    unknown category; `toJson`; ==/hashCode/toString).
  - `SaintPrayer` (text + source `'traditional'|'original'`; `fromJson` strict, `toJson`,
    `isValid` = non-empty trimmed text && recognized source; ==/hashCode).
  - `Saint` (const constructor with defaults `featured=false`,
    `patronages=[]`/`sources=[]` const; `fromSourceJson` for RAW records — **`draft` never
    read**, `featured` absent → false, `feastDay` absent → 'unknown', `image` object →
    `thumbAsset='assets/thumbs/<slug>.jpg'` + attribution/altText retained, url not retained;
    `fromDbRow(row, {patronages, sources})` — DB column names, `featured` accepts `num`
    (sqlite 0/1) or `bool`, `prayer_text==null → prayer==null`, missing prayer_source falls
    back to 'traditional'; `toSourceJson()` emits the retained-field source shape (no
    `draft`, no image `url`) for round-trips; `hasImage`/`hasPrayer`/`hasKnownFeast`;
    field-by-field ==/hashCode with `_listEquals` helper, mirroring bible_data's
    `bible_book.dart` pattern).
- `sancta_via_saint_data/lib/src/models/saint_search_result.dart` — const
  `SaintSearchResult({required saint, required matchRationale})` + ==/hashCode (bonus
  beyond brief, consistent with the other models).
- `sancta_via_saint_data/test/models/saint_model_test.dart` — fixtures inline as
  top-level maps: `garimaJson` (real abba-garima values; bio shortened), `imagedJson`
  (image {url, attribution, altText} + `draft: true` + `featured: true`), `noPrayerJson`,
  `minimalJson` (absent feastDay/featured/canonized/prayer/image), `thereseRow` (DB row with
  packages-prefixed thumb_asset, featured as `1`).
- `sancta_via_saint_data/lib/saint_data.dart` — barrel now exports
  `src/models/saint.dart`, `src/models/saint_category.dart`,
  `src/models/saint_search_result.dart`, `src/utils/logger.dart` (doc comment updated).

## Test output summary
- `flutter test` → `00:00 +29: All tests passed!` (29/29).
- `dart format .` → "Formatted 7 files (2 changed)" (saint.dart + test file), then tests
  re-run green.
- `flutter analyze` → "No issues found!" (clean, required gate).

## Test list (test/models/saint_model_test.dart)
`Saint.fromSourceJson`: parses abba-garima fields (slug/name/feastDay/canonized-null/bio/
prayer text+`original`/2 patronages `monks`+`missionaries` category `spiritual`/sources/
featured false/thumb-null); flags (`hasPrayer` true, `hasImage` false, `hasKnownFeast`
true); image fields parse + featured kept + **draft dropped** (no `draft` key survives
`toSourceJson`); round-trip `toSourceJson().then(fromSourceJson)` equals original on every
retained field (field-by-field, both image-bearing and prayerless fixtures); equal parses
have equal hashCode.
`Saint field defaults`: absent booleans/feastDay/image fall back (`'unknown'`, hasKnownFeast
false); no-`prayer` fixture → `prayer == null`, `hasPrayer == false`.
`Saint.fromDbRow`: DB columns + passed patronages/sources; `featured` 1→true, 0→false,
absent→false; null prayer columns → null prayer; empty-list defaults; null image columns
→ null fields.
`SaintPatronage`: fromJson/toJson round-trip; unknown/missing category and missing need
throw FormatException; equality/hashCode (incl. negative case).
`SaintPrayer`: fromJson + toJson; `isValid` accepts traditional/original, rejects blank
text/'' text/unknown source; fromJson requires text and source; equality/hashCode.
`SaintCategory`: `tryParse('illness')` → illness with verbatim label + description;
`tryParse('bogus')`/`tryParse('')` → null; all 10 ids parse in brief/source order with
byte-verbatim labels; all 10 descriptions verbatim (full maps asserted).
`SaintSearchResult`: holds saint + rationale; equality/hashCode.

## Self-review notes
- **`draft` dropped:** `Saint` has no draft field and `fromSourceJson` never reads the key;
  the round-trip serialization omits it (test asserts `containsKey('draft')` false on
  `toSourceJson()`).
- **`thumbAsset` derivation from raw records:** raw records carry `image{url,attribution,
  altText?}` only; the runtime derives `assets/thumbs/<slug>.jpg` from image presence (the
  url is not meaningful to the runtime model — the DB ships the package-prefixed
  `packages/saint_data/assets/thumbs/<slug>.jpg`, which `fromDbRow` copies verbatim, per
  spec §6 and Task 6). `toSourceJson()` re-emits an `image` object (attribution/altText)
  so the derived thumb round-trips; equality holds field-by-field (verified).
- **Strictness choices:** `SaintPatronage.fromJson` and `SaintPrayer.fromJson` throw
  `FormatException` on malformed input (never masks data errors; Task 5's build tool exits
  and lists violations); `Saint.fromSourceJson` required-string fields cast directly.
  Brief-specified leniencies honored: `featured`/`draft` absent → false; `feastDay` absent
  → 'unknown'; `prayer` absent → null.
- **`fromDbRow` featured coercion:** sqlite returns `1`/`0` ints; the model accepts both
  `num != 0` and raw `bool`, defaulting false (default empty const lists for patronages/
  sources; Task 7 passes them separately).
- **Equality:** implemented on Saint, SaintPatronage, SaintPrayer (brief requirement for
  later set-based tests) and also on SaintSearchResult; hashCode via
  `Object.hash`/`Object.hashAll` following the sibling bible_data pattern (private
  `_listEquals`, no extra deps).
- **Interface conformance:** exact names/signatures from the brief — enum member order,
  `tryParse`, `label`/`description` getters (implemented as enhanced-enum fields, same call
  surface), factories, getters, `toSourceJson`, const `SaintSearchResult`. Small additions:
  `SaintPrayer.toJson` and toString overrides (symmetry/debugging; no brief conflict).
- **Style:** single quotes, trailing commas, explicit types (no var/dynamic), final locals,
  const-first, import order (relative `saint_category.dart` in saint.dart; barrel paths
  sorted) — analyze clean with no lints.
- Nothing outside `sancta_via_saint_data/` was modified; sibling saint-for-that repo only
  read (`git status` clean after commit).
