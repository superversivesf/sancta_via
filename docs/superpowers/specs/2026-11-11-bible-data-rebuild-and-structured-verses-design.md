# Bible Data Rebuild & Structured Verse Rendering — Design

Date: 2026-11-11
Status: Approved design (pending spec review)
Scope: `sancta_via_bible_data`, `sancta_via_bible_reading_app`

## 1. Problem

Verse numbering "cuts off" mid-psalm and the remainder of a chapter renders as one long final verse
(user reports: Psalms 18 and 19). Investigation (2026-11-11) found the root cause is **corrupt source
data**, not the rendering engine:

- Every translation in `sancta_via_bible_data/assets/bibles/*.json` was forced into a **single
  Vulgate-style skeleton** (Psalter: 150 chapters / 2,531 verses). The three files have identical
  chapter/verse structure even though WEB-C uses Hebrew psalm numbering (2461 verses).
- Where WEB-C has **more** verses than the skeleton row count, surplus verses were **tail-merged**
  into the skeleton's final row (WEB Ps 18: v16–50 merged into row 15 = 3,434 chars; Ps 19: v11–15
  merged into row 10; Ps 119: 176 verses squeezed into 7 rows; ~60 chapters affected, mostly Psalms
  and Esther). Verified against bible-api.com (real WEB Psalm 18 = 50 verses).
- Where WEB-C has **fewer**, rows were padded **empty** (2,748 empty rows in engwebc). Books
  I Esdras (451 rows), II Esdras (945), Laodiceans, Prayer of Manasseh, Additional Psalms are
  **100% empty in all three translations** (CPDV has 1,443 empty rows; DRC 1,450).
- `sancta_via_bible_reading_app/tools/build_bible_database.dart` (JSON→SQLite) is a faithful
  converter; the corruption is upstream in the JSONs.
- Secondary renderer issue (did **not** cause the symptom): `chapter_reading_screen.dart`
  (`_parseVersesFromChapter`) and `verse_selection_screen.dart` (`_parseVerses`) re-derive verses
  from a **flattened string** (`BibleChapter.fullText`) with a digit-fragile regex
  (`[^0-9]*?` cannot cross an in-text digit, e.g. CPDV Acts 20:7 "12 (5 + 7)") and display
  **positional** numbers (`index + 1`) instead of the true `verse_number`, which hides numbering
  corruption from users.

## 2. Goals

1. Correct, per-translation Bible data with native numbering and real verse boundaries.
2. No empty verse rows, no ghost books, no merged tails — enforced by automated validation.
3. Reader + verse-selection render true verse numbers from structured data (no regex re-parsing).
4. Repeatable, auditable pipeline (committed snapshots + manifest + checksums).

## Non-goals

- No translation-aware remapping of psalm references for reading plans (native numbering accepted).
- No change to the SQLite schema; no new app features.
- No audio/search/sync changes.

## 3. Decisions (approved 2026-11-11)

| Decision | Choice |
|---|---|
| Data fix approach | Rebuild from upstream per-translation sources |
| Upstream sources | Committed snapshots in repo (with URLs + SHA-256 manifest) |
| Renderer contract | Full refactor: structured verses; delete regex parsing and flatten-in-reading-path |
| Psalm numbering | Native per translation (WEB-C Hebrew; CPDV/DRC Vulgate-style) |

## 4. Data pipeline

New tooling in `sancta_via_bible_data/tools/build_bibles/` (Dart, run from package root):

### 4.1 `fetch_sources.dart`
Downloads once and stores snapshots under `sancta_via_bible_data/assets/sources/<id>/`;
verifies SHA-256 against `manifest.json` (url, revision/date, sha256, fetch date) and fails on
mismatch or unreachable source.

| Translation | Primary source | Fallback |
|---|---|---|
| engwebc | eBible.org **eng-web-c** USFM: `https://ebible.org/Scriptures/eng-web-c_usfm.zip` (public domain; Catholic book order; longer Esther/Daniel; "LORD" style) | eBible HTML/Sword module |
| cpdv | SacredBible.org official CPDV JSON (site lists "The CPDV in JSON … useful for mobile and web-applications"); the Vulgate appendix books are expected in it | CrossWire SWORD module CPDV |
| drc | eBible/CrossWire Douay-Rheims (Challoner) module | drbo.org HTML |

Exact URLs and revisions are pinned in the manifest at fetch time; any future re-fetch updates the
manifest in the commit that regenerates artifacts.

### 4.2 `build_json.dart`
Parses each snapshot (USFM verse-marker parsing for WEB-C; JSON passthrough for CPDV; module/
HTML extraction for DRC) and writes `assets/bibles/{engwebc,cpdv,drc}.json` in the existing
package schema (`{translation, metadata, books[].chapters[].verses[]{verse, text}}`) —
**independent, per-translation structures**:

- **engwebc**: Hebrew psalm numbering (Ps 18 = 50 verses); psalm superscriptions are headings,
  not verse rows; contains exactly the WEB-C canon (73 books incl. deuterocanonicals, no Vulgate
  appendix books).
- **cpdv**: Vulgate-style numbering (superscriptions as verse 1; Ps 9 combined, 113 combined,
  114/115 and 146/147 split), incl. appendix books with real text.
- **drc**: Challoner numbering as published; no appendix books.
- Book `name` strings must stay compatible with `BookNameNormalizer` mapping; any new/renamed
  book keys get normalizer entries.
- Footnote/heading markers stripped; verse text trimmed; punctuation normalized against the
  upstream verbatim text (no editorial re-writing).

### 4.3 `validate.dart` (hard gate)
Committed `expected_structure.json` manifest = per translation: book list, chapter count per book,
verse count per chapter. Validation fails (non-zero exit) unless:

- chapter counts and per-chapter verse counts match the manifest exactly;
- verse numbers are contiguous from 1 in every chapter;
- every verse row contains non-empty trimmed text;
- no translation contains a book outside its canon list;
- ~20 pinned reference verses (e.g. WEB-C Ps 18:16, CPDV Ps 18:1, CPDV Acts 20:7, DRC Sirach 1:1)
  match expected first-words.
The same validation is re-run against the built SQLite DB (per-translation row counts, contiguity,
non-empty texts).

### 4.4 DB regeneration
Run existing `sancta_via_bible_reading_app/tools/build_bible_database.dart` unchanged (it is a
faithful JSON→SQLite converter), then DB validation. Expected: DB shrinks (no empty/ghost rows);
`translations.verse_count`/`books.verse_count` become per-translation true values.

### 4.5 Artifacts committed
`assets/sources/` snapshots (user decision), updated `assets/bibles/*.json`, updated
`bibles.db`, `manifest.json`, `expected_structure.json`. Legacy JSONs are replaced (git history
preserves them); `DATA.md` updated to reflect sources and numbering.

## 5. Renderer refactor (structured verses end-to-end)

- Source of truth: `BibleChapter.verses` (`BibleVerse{number, text}`) — real numbers from rows.
- `OptimizedScriptureContent` and `BibleService`'s `ScriptureContent` expose structured
  `List<BibleVerse>` as first-class data; a derived `text` remains for string-shaped consumers
  (clipboard/share strings, devotional previews) computed **from** structured verses.
- Reading path keeps structured verses; **derived-only** flattening (`fullText`) removed from the
  reading/selection extraction logic.
- `chapter_reading_screen.dart`: `_parseVersesFromChapter` + sentence fallback deleted;
  render `verse.number` (true number) + `verse.text`; verse-tap highlight/copy uses the real
  number; scroll-to-verse maps true verse number → key.
- `verse_selection_screen.dart`: `_parseVerses` deleted; one grid tile per real verse; selected
  verse carries its real number.
- Consumer inventory (verified 2026-11-11; plan re-verifies): search (`bible_search_service.dart`,
  `bible_book.dart`) already works on verse objects — unaffected; model helpers `fullText`/`textOnly`
  (bible_chapter.dart) retained as derived conveniences; riverpod doc-comment updated. Any app
  reading `.text` on content objects must keep working via the derived field (compiler + tests
  enforce).

## 6. Error handling

Unchanged: missing book/chapter in a translation → existing notFound path ("not available in this
translation"). Empty/blank chapter text is now impossible for contained books (validation gate).

## 7. Testing

| Layer | Tests |
|---|---|
| `sancta_via_bible_data` | `validate.dart` invariants as unit tests (manifest counts, contiguity, non-empty, reference verses) |
| Regression | WEB-C Ps 18 → 50 verses, Ps 19 → 15; CPDV Ps 18 → 15 (incl. superscription v1); CPDV I Esdras texts non-empty |
| Reading app widget tests | Reader renders true numbers (WEB-C Ps 19:10 is short); tap-copy reference string correct; verse-selection tile count == verse count; digit-containing verse (CPDV Acts 20:7 "12 (5 + 7)") renders correctly |
| Gates | `flutter analyze` and existing `flutter test` suites green in affected packages; final DB check with the corruption queries (no outlier `LENGTH(text)`, no empty rows, counts == manifest) |

## 8. Acceptance criteria

1. WEB-C Psalms 18/19/78/119 show 50/15/72/176 verses with correct numbers and text.
2. Zero empty verse rows in any translation; CPDV appendix books contain real text; drc/engwebc
   book lists match their canon (no ghost books).
3. Reader and verse-selection display and copy **true** verse numbers; regex parsing gone.
4. `flutter analyze` + `flutter test` green; validation passes on JSON and DB.

## 9. Risks / notes

- Reading plans that hardcode psalm numbers now resolve per-translation (accepted decision); a
  future translation-aware reference mapper is out of scope.
- WEB-C text edition is the 2020 stable eBible release (LORD style) — supersedes legacy mix.
- Repo grows by committed source snapshots (~30–60 MB) — accepted by decision.
- The DRC primary source must pass the manifest (verse counts per chapter); if the first choice
  fails validation, fallback sources are used and the manifest records which one won.
