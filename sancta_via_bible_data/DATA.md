# Bible Data Files

This package ships three complete Catholic-canon (73-book) Bible translations,
rebuilt from pinned upstream sources. The rebuild pipeline (fetchers, adapters,
USFM/CPDV parsers, and the structure validator) lives in `tools/build_bibles/`
of this repository; the pinned inputs and expected outputs it produces are
committed as artifacts:

- `tools/build_bibles/manifest.json` — pinned source URLs, SHA-256 hashes,
  fetch dates, and revisions.
- `tools/build_bibles/expected_structure.json` — the pinned per-translation
  expected structure (canon order, per-chapter verse counts, exact verse
  numbers for exception chapters, reference-verse pins).
- `tools/build_bibles/book_names.json` — shared canonical 73-book db names.
- `assets/bibles/*.json` — the rebuilt per-translation JSONs (build outputs;
  never hand-patched).

## Sources (pinned)

Copies are fetched by the pipeline and verified against these hashes. See
`tools/build_bibles/manifest.json` for the authoritative record (including
fetch timestamps and fallback URLs).

1. **World English Bible (Catholic Edition) — `engwebc`**
   - URL: `https://ebible.org/Scriptures/eng-web-c_usfm.zip`
     (fallback: `https://ebible.org/Scriptures/engwebc2025eb.zip`)
   - SHA-256: `add2ff69c0f07ed4059ee58a9dc391dc4ec77c0b8415dc38a865a1d9f1d3b9cb`
   - Revision: `engwebc2025eb`
   - 73 books, 35,379 verses. USFM source, parsed by the repository's USFM
     parser.

2. **Catholic Public Domain Version (2009 Original Edition) — `cpdv`**
   - URL: `https://raw.githubusercontent.com/draino7n7/cpdv/master/CPDV-JSON/EntireBible-CPDV.json`
   - SHA-256: `748db8fa1e126d14cba5d5647991a50ffe460d02cd797e4005c1605c983df19d`
   - Revision: `draino7n7/cpdv@ea374e0c63c7e336fa3243644b3fcb67c782437f`
   - 73 books, 35,827 verses. Book lists joined from
     `https://raw.githubusercontent.com/draino7n7/cpdv/master/CPDV-JSON/books.json`
     (SHA-256 `db979ed66676760e26238018161f82c1c8cd79c1e95c80b7f4e20b4f726f40d0`,
     revision `draino7n7/cpdv@66416f04fbfeec260f09eb3c095be9a289429f2d`).

3. **Douay-Rheims 1899 American Edition (Challoner) — `drc`**
   - URL: `https://ebible.org/Scriptures/engDRA_usfm.zip`
   - SHA-256: `fcb5de45f1f6083d56b738690e5b4b3bb6f0d87522d1d18329c57a4b09e05210`
   - Revision: eBible `engDRA` — Douay-Rheims 1899 American Edition
     (Challoner revision), public domain.
   - 73 books, 35,811 verses. USFM source, parsed by the repository's USFM
     parser. (Supersedes the retired drbo.org scrape and the structurally
     corrupt third-party JSON joins; see `manifest.json` for the full
     provenance ruling.)

All three texts are public domain.

## Per-translation native numbering

Verse and chapter numbers are kept exactly as the sources give them; the
pipeline never renumbers:

- **engwebc (WEB-C)**: native WEB (Hebrew) psalm numbering, superscriptions
  kept as headings (not verse rows) — e.g. Psalms 18/19/78/119 have
  50/14/72/176 verses. Its book set follows the Vulgate/LXX order.
- **drc (DRA) and cpdv**: Vulgate/LXX psalm numbering with the superscription
  as verse 1 — e.g. Psalms 18 = 15 verses (title included): the "heavens
  declare the glory of God" psalm is Psalms 18 in Vulgate numbering and
  Psalms 19 in WEB-C's Hebrew numbering, and WEB-C's 176-verse Psalms 119 is
  Psalms 118 here. drc/engwebc follow the Vulgate/LXX book order; cpdv is
  itself a Vulgate-order translation.
- **Sirach prologue omitted**: the prologue is not part of the 73-book canon
  used here; Sirach therefore has 51 chapters in every translation.
- **engwebc `verseNumbers` exception chapters**: in a handful of chapters
  (see the `verseNumbers` section of
  `tools/build_bibles/expected_structure.json` — Esther 4/9, Sirach 1/3/10/
  11/13/16-20/22/24-26, Luke 17, Acts 8/15/24), footnote-only verse markers in
  the source mean the real verse keys are NOT the contiguous 1..N run.
  Those chapters' exact ascending verse numbers are pinned in the manifest;
  every other chapter is contiguous 1..N. The other two translations have no
  such exceptions.

## Data Format

All Bible files follow this JSON structure (chapter and verse numbers are
true ints; verse numbers follow the numbering rules above):

```json
{
  "translation": "Catholic Public Domain Version (2009 Original Edition)",
  "metadata": {
    "name": "Catholic Public Domain Version (2009 Original Edition)",
    "abbreviation": "CPDV",
    "books": 73,
    "verses": 35827
  },
  "books": [
    {
      "name": "Genesis",
      "chapters": [
        {
          "chapter": 1,
          "verses": [
            {
              "verse": 1,
              "text": "In the beginning, God created heaven and earth."
            }
          ]
        }
      ]
    }
  ]
}
```

Per-translation metadata (all verified by the test suite):

| id        | name | abbreviation | books | verses |
|-----------|------|--------------|-------|--------|
| `engwebc` | World English Bible (Catholic Edition) | WEB-C | 73 | 35,379 |
| `cpdv`    | Catholic Public Domain Version (2009 Original Edition) | CPDV | 73 | 35,827 |
| `drc`     | Douay-Rheims 1899 American Edition (Challoner) | DRA | 73 | 35,811 |

## Validation

The JSON build outputs are pinned by `tools/build_bibles/expected_structure.json`
and checked by the repository test suites:

```bash
# From sancta_via_bible_data/ (validates assets/bibles/*.json against the
# pinned manifest):
flutter test test/bible_assets_validation_test.dart
flutter test test/bible_structure_validator_test.dart
```

`lib/src/utils/bible_structure_validator.dart` is the shared validator used by
both the JSON-side tests and the SQLite side.

## Building `bibles.db`

The reading app ships `assets/bibles.db` (SQLite), built by
`sancta_via_bible_reading_app/tools/build_bible_database.dart` from the
rebuilt JSONs:

```bash
# From sancta_via_bible_reading_app/:
dart pub get

# Stage the rebuilt JSONs where the converter expects them (dev-only, not
# committed):
mkdir -p assets/bibles
cp ../sancta_via_bible_data/assets/bibles/*.json assets/bibles/

# Run the converter (unchanged; reads assets/bibles/*.json):
dart tools/build_bible_database.dart

# IMPORTANT: sqflite_common_ffi resolves *relative* database paths against
# its own CWD-relative databases directory (`.dart_tool/sqflite_common_ffi/databases/`),
# so the converter leaves its output there. Copy it to the shipped asset:
cp .dart_tool/sqflite_common_ffi/databases/assets/bibles.db assets/bibles.db

# Validate the shipped DB against the pinned manifest (exits 0 on pass,
# 1 on any mismatch):
dart tools/validate_bible_db.dart

# Remove the staged dev-only JSONs:
rm -rf assets/bibles
```

`tools/validate_bible_db.dart` checks, per translation (each error grep-able,
prefixed with the translation id): book set and order, chapter sets, verse
numbering (contiguous 1..N or pinned `verseNumbers` lists), empty verse text,
USFM backslash leaks, reference-verse text prefixes, per-translation
`verses` row counts vs the manifest totals, uniqueness of
`(translation_id, book_name, chapter_number, verse_number)`, and the
`books`/`translations` summary counts.

## Using the Data in an Application

#### Option 1: Asset Files (Flutter Apps)

```dart
import 'package:flutter/services.dart';
import 'package:bible_data/bible_data.dart';

final loader = AssetBibleLoader(
  assetBasePath: 'assets/bibles',
  assetLoader: rootBundle.loadString,
);
final service = BibleService(loader);
```

Register the JSONs in your `pubspec.yaml`:

```yaml
flutter:
  assets:
    - assets/bibles/
```

#### Option 2: Embed Data (Any Dart App)

```dart
import 'dart:io';
import 'package:bible_data/bible_data.dart';

// Load the JSON strings
final cpdvJson = await File('assets/bibles/cpdv.json').readAsString();
final drcJson = await File('assets/bibles/drc.json').readAsString();
final webJson = await File('assets/bibles/engwebc.json').readAsString();

// Initialize the embedded loader
EmbeddedBibleLoader.initialize({
  BibleTranslation.cpdv: cpdvJson,
  BibleTranslation.drc: drcJson,
  BibleTranslation.engwebc: webJson,
});

final loader = EmbeddedBibleLoader();
final service = BibleService(loader);
```

#### Option 3: SQLite (`bibles.db`, used by the reading app)

The reading app ships the prebuilt `assets/bibles.db` and reads it through
its SQLite service; no JSON parsing happens at runtime on device.

#### Option 4: Network Loading

Host the JSON files on a server and use NetworkBibleLoader:

```dart
final loader = NetworkBibleLoader(
  baseUrl: 'https://your-server.com/bibles',
  httpClient: (url) async => (await http.get(Uri.parse(url))).body,
);
```

## Performance Considerations

- **File Size**: Each complete Bible JSON is ~7.5–8 MB; `bibles.db` is ~45 MB.
  The SQLite DB is the shipped runtime artifact for the reading app.
- **Memory Usage**: The EmbeddedBibleLoader keeps data in memory. Use
  AssetBibleLoader for better memory management.
- **Caching**: All loaders include caching to avoid repeated parsing.

## License

The Bible texts are in the public domain. The specific translations used are:

- **WEB-C**: World English Bible, Catholic Edition (eBible `eng-web-c`),
  public domain (CopyrightHolder statement inside the source USFM).
- **CPDV**: Catholic Public Domain Version, translated from the Latin
  Vulgate (CC0/public domain as declared upstream).
- **DRA**: Douay-Rheims 1899 American Edition (Challoner revision), public
  domain.

See `tools/build_bibles/manifest.json` for the pinned provenance of each
source; individual source notes carry detailed attribution statements.
