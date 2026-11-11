# Source Attribution

This directory holds byte-for-byte snapshots of the upstream Bible sources used
to rebuild the `bible_data` package assets. Snapshots are fetched and
checksum-verified by `tools/build_bibles/bin/fetch_sources.dart`; the pinned
URLs, SHA-256 checksums, sizes, fetch timestamps, and upstream revisions are
recorded in `tools/build_bibles/manifest.json`.

The `fallbackUrls` entries in the manifest are recorded metadata only; they
have **not** been downloaded and no snapshot for them exists here.

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

## `DRB.json` — Douay-Rheims (Challoner Revision) — NOT YET FETCHED

- **Status: no snapshot present.** The pinned primary URL
  <https://raw.githubusercontent.com/thomas992/catholicbible/main/DRB.json>
  returned HTTP 404 on 2026-11-11 during the initial pinning run: the
  `thomas992/catholicbible` repository does not exist publicly (GitHub API
  returns "Not Found" for the repo, the owner's public repository list contains
  no Bible-related repository, and the Wayback Machine has no archived
  snapshots of the raw URL). The `drc` manifest entry keeps the pinned URL and
  checksum fields empty until the controller confirms a replacement URL.
- Fallback (metadata only, not downloaded):
  <https://raw.githubusercontent.com/exanx/bible-json/main/DRB-73-Books/<file>.json> —
  per-book JSON files (`Genesis.json`, …, `Psalms.json`, …) under
  <https://github.com/exanx/bible-json>, to be joined into a single
  `DRB.json` object.
- Intended attribution once fetched: Douay-Rheims Bible (Douay 1582 / Rheims
  1610, Challoner Revision 1749–1752); public domain (published before
  1929, no copyright claim in upstream distribution; upstream declares CC0).

## License Summary

All three source texts (WEB-C, CPDV, Douay-Rheims/Challoner) are in the public
domain; the committed snapshots may be redistributed freely with attribution.
Derived files in `assets/bibles/` built from these snapshots inherit the same
public-domain status.
