# Source Attribution

This directory holds byte-for-byte snapshots of the upstream Bible sources used
to rebuild the `bible_data` package assets. Snapshots are fetched and
checksum-verified by `tools/build_bibles/bin/fetch_sources.dart`; the pinned
URLs, SHA-256 checksums, sizes, fetch timestamps, and upstream revisions are
recorded in `tools/build_bibles/manifest.json`.

The `fallbackUrls` entries in the manifest are recorded metadata only; the
`drc` source is now the eBible.org `engDRA` plain-zip snapshot (see its section
below, which also records the retired drc attempts in order).

## `engwebc_usfm.zip` — World English Bible (Catholic Edition) (WEB-C)

- Translation name: World English Bible (Catholic Edition) / "World English
  Bible (Catholic)"
- Source URL: <https://ebible.org/Scriptures/eng-web-c_usfm.zip>
- Fallback (metadata only, not downloaded):
  <https://ebible.org/Scriptures/engwebc2025eb.zip> (Sword module)
- Fetched: 2026-11-10T22:04:52Z (see `manifest.json`)
- License / public-domain notice (upstream, quoted from `copr.htm` in the
  snapshot): "The World English Bible is in the Public Domain. That means that
  it is not copyrighted. However, 'World English Bible' is a Trademark of
  eBible.org."
- Translator attribution line: World English Bible Catholic Book Order,
  edited by the World English Bible team (Rainbow Missions, Inc.), published by
  eBible.org. Dedicated to the Public Domain ("we who have worked on this
  translation freely give it to you by dedicating it to the Public Domain").
- Snapshot shape: 74 USFM files (73 canon books plus front matter
  `00-FRTeng-web-c.usfm`), one file per book, e.g. `02-GENeng-web-c.usfm`,
  `20-PSAeng-web-c.usfm`, `96-REVeng-web-c.usfm`; also contains upstream
  `copr.htm` and signature/key files.

## `EntireBible-CPDV.json` + `CPDV-books.json` — Catholic Public Domain Version (CPDV)

- Translation name (upstream `books.json` metadata): "Catholic Public Domain
  Version (CPDV)"
- Translator attribution line (upstream `books.json` metadata):
  translator: Ronald L. Conte Jr.; edition: 2009 Original Edition
- Source URL: <https://raw.githubusercontent.com/draino7n7/cpdv/master/CPDV-JSON/EntireBible-CPDV.json>
  and <https://raw.githubusercontent.com/draino7n7/cpdv/master/CPDV-JSON/books.json>
  (official CPDV JSON distribution of SacredBible.org,
  <https://www.sacredbible.org/catholic/>)
- Fallback (spec metadata; not downloaded): `CPDV.json`/`DRB.json` published
  from the now-missing `thomas992/catholicbible` repository.
- Fetched: 2026-11-10T22:04:53Z (see `manifest.json`; upstream revisions
  `draino7n7/cpdv@ea374e0c63c7e336fa3243644b3fcb67c782437f` [EntireBible] and
  `draino7n7/cpdv@66416f04fbfeec260f09eb3c095be9a289429f2d` [books]).
- License / public-domain notice (upstream `books.json` metadata):
  `license: "Public Domain"`.
- Snapshot shape: `EntireBible-CPDV.json` holds a `charset` metadata key plus
  73 book keys (e.g. `Genesis`, `1-Samuel`, `Song2`), each a
  chapter → verses map (Psalms 18 has 15 verses, Vulgate-style numbering);
  `books.json` records the 73-book canon, 1,335 chapters, and 35,839 verses.

## `drc_usfm.zip` — Douay-Rheims 1899 American Edition (eBible.org engDRA)

- **Status: fetched 2026-11-12 via the manifest's plain-zip path**, checksum-pinned
  in the manifest (SHA-256
  `fcb5de45f1f6083d56b738690e5b4b3bb6f0d87522d1d18329c57a4b09e05210`, 2,942,946
  bytes). 73 `\id`-keyed USFM book files (engDRA codes: the standard USFM set with
  `EST` and `DAN`, no WEB-C variants) plus upstream `copr.htm`, `gentium.css`,
  `keys.asc`, `signature.txt.asc`.
- Translation: **Douay-Rheims 1899 American Edition** — "The Holy Bible in
  English, Douay-Rheims American Edition of 1899, translated from the Latin
  Vulgate" = the 1749 Challoner revision. Attribution, verbatim from the zip's
  `copr.htm`: "Language: English Dialect: archaic American **Translation by:
  English College, Douai** This Public Domain Bible text is brought to you
  courtesy of eBible.org. Help support free Bible access at
  https://eBible.org/give.php . 2022-11-03 HTML generated with Haiola by
  eBible.org 30 Oct 2026 from source files dated 3 Nov 2022 Public Domain".
- Upstream: eBible.org module `engDRA`
  (<https://ebible.org/Scriptures/engDRA_usfm.zip>, details page
  https://ebible.org/find/details.php?id=engdra). Structural pass (2026-11-12,
  independent verifier): 73 books incl. all 7 deuterocanon, 1,334 chapters,
  35,811 verses, 0 contiguity violations, 0 empty texts, 0 markup; corruption
  probe ("Then Booz went up to the gate…") at the correct coordinate `RUT 4:1`.
- Provenance — retired `drc` attempts, in order: (1) the pinned primary
  <https://raw.githubusercontent.com/thomas992/catholicbible/main/DRB.json>
  returned HTTP 404 during the initial pinning run (2026-11-11; repository
  gone); (2) the authorized exanx/bible-json `DRB-73-Books` join
  (`exanx/bible-json@55d8cce6…`, joined via `drc_file_list.json` into the
  retired `assets/sources/drc.json`) proved **structurally corrupt upstream**
  (21/73 books missing tail chapters, verse texts at wrong coordinates — removed
  this round); (3) a drbo.org scrape was authorized and partially run (~55/73
  books) but abandoned (repeated transient connection kills); the scrape tooling
  remains in `fetch_sources.dart` for any future re-pinning and the drbo partial
  cache stays in the git-ignored `.drc_cache/`. All three text lineages were the
  same Challoner DRB edition; engDRA is its complete, clean, machine-readable
  form.

## License Summary

All three source texts (WEB-C, CPDV, Douay-Rheims/Challoner) are in the public
domain; the committed snapshots may be redistributed freely with attribution.
Derived files in `assets/bibles/` built from these snapshots inherit the same
public-domain status.
