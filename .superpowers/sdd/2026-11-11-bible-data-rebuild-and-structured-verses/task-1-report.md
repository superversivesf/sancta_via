# Task 1 Report — Source-fetch tool, manifest, and committed snapshots

**Status: NEEDS_CONTEXT** — all deliverables implemented, verified, and committed (commit `3fe163c`), but the **pinned primary URL for `drc` is dead** (404), so `assets/sources/DRB.json` does not exist. I did **not** substitute any source (per instructions); the controller must decide the fix before Task 2 can parse DRB.json.

## What I implemented

1. **`sancta_via_bible_data/tools/build_bibles/bin/fetch_sources.dart`** (~285 lines, `Future<void> main(List<String> args)`):
   - Reads sibling `tools/build_bibles/manifest.json`, validates shape `{"sources": {"<id>": {...}}}`.
   - Per source: resolves `zip`/`json` ext from the URL suffix; downloads the primary `url` with `dart:io` `HttpClient` (redirect-follow, gzip auto-uncompress, 30s connect timeout) into `assets/sources/<id>.<ext>`; computes SHA-256 via `package:crypto`.
   - Snapshot naming: a fixed map in the tool maps manifest ids → the Produces-contract file names (`cpdv_entire`→`EntireBible-CPDV.json`, `cpdv_books`→`CPDV-books.json`, `drc`→`DRB.json`; `engwebc_usfm`→`engwebc_usfm.zip` = plain `<id>.<ext>`). Needed because the brief's Step 2 ids and the Produces/Step-3 file names differ.
   - Idempotent mode: snapshot present + `sha256` pinned → local checksum verify only (no network). Checksum mismatch without `--update` → print both hashes, exit 1.
   - First fetch (unpinned entry): downloads and pins `sha256`/`fileSize`/`fetchedAt` into the manifest.
   - `--update`: force re-download, update `sha256`/`fetchedAt`/`fileSize`, print per-field old→new diff.
   - `fallbackUrls` treated as metadata only (never downloaded); failures recorded per source; exit 1 if any fail.
   - Package root resolved by walking up from the script until `pubspec.yaml` (fallback: cwd).

2. **`tools/build_bibles/manifest.json`** — exact shape from the brief, keys `engwebc_usfm`, `cpdv_entire`, `cpdv_books`, `drc`, with pinned URLs verbatim:
   - `engwebc_usfm`: `https://ebible.org/Scriptures/eng-web-c_usfm.zip`, fallback `"https://ebible.org/Scriptures/engwebc2025eb.zip"` (Sword module).
   - `cpdv_entire` / `cpdv_books`: `https://raw.githubusercontent.com/draino7n7/cpdv/master/CPDV-JSON/EntireBible-CPDV.json` / `.../books.json` (fallbacks: none, per brief).
   - `drc`: `https://raw.githubusercontent.com/thomas992/catholicbible/main/DRB.json`, fallback string recorded **exactly as given**: `https://raw.githubusercontent.com/exanx/bible-json/main/DRB-73-Books/<file>.json` (joined list; metadata only, not downloaded).
   - `revision` metadata: `engwebc2025eb` (eBible pinned module designation); CPDV entries carry the GitHub commit SHAs touching those files (`draino7n7/cpdv@ea374e0c…` EntireBible, `@66416f04…` books, both 2026-10-23).
   - Populated by first fetch: sha256/fileSize/fetchedAt (see Step 2 evidence). `drc` entry left with empty checksum fields.

3. **Snapshots committed in `assets/sources/`** (3 of 4; zip committed as-is):
   | file | bytes | sha256 |
   |---|---|---|
   | `engwebc_usfm.zip` | 3,091,065 | `add2ff69c0f07ed4059ee58a9dc391dc4ec77c0b8415dc38a865a1d9f1d3b9cb` |
   | `EntireBible-CPDV.json` | 5,722,375 | `748db8fa1e126d14cba5d5647991a50ffe460d02cd797e4005c1605c983df19d` |
   | `CPDV-books.json` | 109,577 | `db979ed66676760e26238018161f82c1c8cd79c1e95c80b7f4e20b4f726f40d0` |
   | `DRB.json` | — | **not fetched (primary URL dead)** |

4. **`assets/sources/ATTRIBUTION.md`** — per snapshot: translation names, translator attribution lines, source URLs, fetch dates (from manifest), public-domain notices (per spec §4); CPDV name/translator/edition/license taken verbatim from upstream `books.json` metadata; WEB-C notice quoted from upstream `copr.htm` inside the zip; drc section documents the NOT-YET-FETCHED status and evidence.

5. **`sancta_via_bible_data/pubspec.yaml`** — added `archive: ^4.6.0` + `crypto: ^3.0.8` as dev_dependencies; `flutter pub add` run (package `pubspec.lock` updated and committed; root `pubspec.lock` is gitignored, so it was omitted from the commit).

## Step 2 verification evidence (fetch + idempotent rerun)

First run (`dart tools/build_bibles/bin/fetch_sources.dart`, exit 1 due to drc):
```
[pinned]   engwebc_usfm -> engwebc_usfm.zip
           sha256: add2ff69c0f07ed4059ee58a9dc391dc4ec77c0b8415dc38a865a1d9f1d3b9cb (3091065 bytes)
[pinned]   cpdv_entire -> EntireBible-CPDV.json
           sha256: 748db8fa1e126d14cba5d5647991a50ffe460d02cd797e4005c1605c983df19d (5722375 bytes)
[pinned]   cpdv_books -> CPDV-books.json
           sha256: db979ed66676760e26238018161f82c1c8cd79c1e95c80b7f4e20b4f726f40d0 (109577 bytes)
[fail]     drc: HTTP 404 for https://raw.githubusercontent.com/thomas992/catholicbible/main/DRB.json
Summary: verified=0 pinned=3 updated=0 failed=1
```
`--update` run: printed per-source diffs (sha256/fileSize identical before→after; fetchedAt bumped) — `updated=3 failed=1`, exit 1. **Idempotent rerun (twice, incl. after final edit):**
```
[ok] engwebc_usfm -> engwebc_usfm.zip (checksum verified)
[ok] cpdv_entire -> EntireBible-CPDV.json (checksum verified)
[ok] cpdv_books -> CPDV-books.json (checksum verified)
[fail] drc: HTTP 404 ...
Summary: verified=3 pinned=0 updated=0 failed=1
```
Upstream content is stable across fetches (same sha256 each time).

## Step 3 verification evidence (disk structure)

- `unzip -l assets/sources/engwebc_usfm.zip`: **78 files; 74 `.usfm` = 73 books + front matter; one `.usfm` per book**, e.g. `02-GENeng-web-c.usfm`, `20-PSAeng-web-c.usfm`, `96-REVeng-web-c.usfm` (also front matter `00-FRTeng-web-c.usfm`, and upstream `copr.htm`/keys/signature files). Numbered-prefixed names contain the book code (`GEN`, `PSA`, `REV`); Task 2 should key on `\id` as planned.
- CPDV: `python3 -c "... print(list(d)[:5]); print(len(d['Psalms']['18']))"` → `['charset', 'Genesis', 'Exodus', 'Leviticus', 'Numbers']` and **Psalms/18 = 15 verses** (Vulgate-style numbering, matches spec psalm-numbering regression).
  - Shape notes for Task 2: `EntireBible-CPDV.json` has 74 top-level keys = a `charset` metadata key (`"UTF-8"`) **plus 73 book keys** — downstream must skip `charset`. Keys confirmed: `Genesis`, `1-Samuel`, `Song2`. Chapters are string-number keys (`'1'`, `'2'`, …).
- `CPDV-books.json`: metadata dict — `charset: UTF-8, translation: "Catholic Public Domain Version (CPDV)", edition: "2009 Original Edition", translator: "Ronald L. Conte Jr.", source_url: https://www.sacredbible.org/catholic/, license: "Public Domain", book_count: 73, old/new testament counts 46/27, chapter_count 1335, verse_count 35839` (matches spec's 35,839) + nested `books` and `normalization` keys.
- DRB check: **not runnable — no snapshot** (see drc blocker). The exact psalms book-key spelling is unobservable; note the pinned *fallback* repo lists `DRB-73-Books/Psalms.json` by filename, but the actual top-level key inside a file is unknown until a snapshot exists.

## drc blocker — evidence (NOT substituted)

- `GET https://raw.githubusercontent.com/thomas992/catholicbible/main/DRB.json` → HTTP 404 (while the CPDV raw URLs on the same host returned 200, so the network/host is fine).
- GitHub API `GET /repos/thomas992/catholicbible` → `{"message":"Not Found"}`; user `thomas992` exists but has exactly 3 public repos (`gfxd-sys`, `rust-jsc`, `VIIPER` — none Bible-related); repository search finds nothing.
- Wayback Machine: no archived snapshots of that raw URL.

**Question for controller:** how to proceed? (a) authorize building `DRB.json` from the brief's pinned exanx fallback (`DRB-73-Books/*.json` joined — repo is live, 58 per-book files incl. `Psalms.json`), (b) supply a corrected primary URL, or (c) drop/skip drc. Until then the manifest's `drc` entry keeps the pinned primary + exact fallback string with empty checksum fields, and every fetch run reports drc as `failed` (exit 1).

## Files changed (commit `3fe163c`, `feat(bible-data): pin upstream sources and add fetch tool`)

- Created: `sancta_via_bible_data/tools/build_bibles/bin/fetch_sources.dart`, `sancta_via_bible_data/tools/build_bibles/manifest.json`
- Created: `sancta_via_bible_data/assets/sources/{ATTRIBUTION.md, engwebc_usfm.zip, EntireBible-CPDV.json, CPDV-books.json}`
- Modified: `sancta_via_bible_data/pubspec.yaml` (dev_dependencies: archive ^4.6.0, crypto ^3.0.8), `sancta_via_bible_data/pubspec.lock`
- Untouched: `assets/bibles/*.json` (corrupted legacy files were not read or modified).

## Self-review findings

- Analyzer: `dart analyze tools/build_bibles` → "No issues found!" (fixed 2 deprecated `BytesBuilder` import warnings by importing from `dart:typed_data`). `dart format` clean.
- The tool writes the manifest on first-fetch/update; key order is preserved from the parsed file; `revision` is never auto-modified (seeded metadata).
- `--help`-style extra args → usage message, exit 2; usage/behavior documented in the file header doc comment.
- The brief's git add included root `pubspec.lock`, but it is gitignored in this repo; the package's own `pubspec.lock` (tracked) was committed instead — the only dependency-lock change the dev_dependency add actually produced.
- Partial-failure runs are honest: any unreachable source fails the run (exit 1) while fetchable sources still succeed — committed state reflects this (drc fails until fixed).

## Concerns

1. **`drc`/DRB.json missing** — main open item (details above; needs controller decision).
2. Fetch run currently exits 1 on every invocation because of drc; downstream tasks that just read snapshots are unaffected, but whoever repairs the drc URL should rerun with `--update` (or defaults) to pin it.
3. The USFM zip is 3.1 MB (not ~10 MB) — fine, recorded for expectations.
4. `CPDV.json`-style 'Song2' key and the `charset` first key are downstream mapping details surfaced here early; the exanx fallback also spells 'Zachariah' (DRB naming) — relevant to Task 2's `BookNameNormalizer` mapping if that fallback is ever used.
