# Third-Party Notices

Licenses for third-party material bundled with the Sancta Via apps/packages.

## Bundled fonts

| Material | License | Notes |
|---|---|---|
| Crimson Text font family (`sancta_via_shared_ui/assets/fonts/CrimsonText-*.ttf`) | SIL Open Font License 1.1 | © The Crimson Text Project. Bundled locally; no font-fetching at runtime. |

## Images / icons

| Material | License | Notes |
|---|---|---|
| Kneeling-figure glyph (embedded in app icons, badge of `sancta_via_devotionals/assets/app_icon.png`) | CC BY 4.0 | TODO(jason): still needs the source page URL before public distribution. |

## Bundled text data

| Material | License | Notes |
|---|---|---|
| Saint-history texts derived from the Catholic Encyclopedia (1907–12) | Public domain | Attribution as shipped in-app: `Adapted from the Catholic Encyclopedia (1907–12)` |
| Saint-history texts derived from Wikipedia | CC BY-SA 4.0 | Attribution as shipped in-app: `Adapted from Wikipedia (CC BY-SA 4.0)`; see `sancta_via_saint_data/data/grounding_wikipedia/NOTICE.md` |
| Douay-Rheims / Challoner Bible text (`sancta_via_bible_data`) | Public domain | Full per-edition attribution in `sancta_via_bible_data/assets/sources/ATTRIBUTION.md` |
| World English Bible Catholic Edition (WEB-C) in `bibles.db` | Public domain | "World English Bible" is a Trademark of eBible.org — see ATTRIBUTION.md |
| Catholic Public Domain Version (CPDV) in `bibles.db` | Public domain | Translated by Ronald L. Conte Jr. — see ATTRIBUTION.md |
| romcal — generated liturgical calendar data (`sancta_via_liturgical_calendar/lib/src/data/generated/`) | MIT | Generator: https://github.com/romcal/romcal (permission/copyright notice retained per-MIT) |

## Pending permission notes (pre-publication TODO(jason))

| Material | Status |
|---|---|
| Chaplet of Divine Mercy (English translation, "Eternal Father, I offer you…") in `sancta_via_devotionals/assets/content/packs/divine_mercy_novena.json` + `mercy_hour.json`, and `sancta_via_novena_companion/assets/novenas/divine-mercy.json` | The standard English text is © the Marians of the Immaculate Conception (Diary translations). Permission is granted readily but must be requested and the required attribution statement included — or replace with the public-domain Latin text + house translation. |
| `sancta_via_confession_companion/assets/examinations/pope-francis.json` — "Based on Pope Francis' Teachings and Writings" | Papal magisterial texts are © Libreria Editrice Vaticana; paraphrase reduces but does not remove the claim. Re-label the source honestly or obtain permission. |
| `sancta_via_novena_companion/assets/novenas/st-john-paul-ii.json` | Labeled "traditional" but verify the content is pre-1978 (or repo-authored, then covered by the project's MIT). |
| Devotional packs (`sancta_via_devotionals/assets/content/packs/*.json`, 33 packs) | All ship `license: null` in-pack. Annotate each with license + source like the sibling `content/prayers/*` corpus. |
| Legacy staging corpus (`sancta_via_prayer_companion/assets/prayers_staging/`) — NOT bundled/shipped | 124 texts copied from a third-party proprietary Android app; unshipped but present in the (to-be-public) repo — purge or record the upstream's real license before any promotion. |
