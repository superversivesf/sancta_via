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

## Resolved (was pending pre-publication)

| Material | Resolution |
|---|---|
| Chaplet of Divine Mercy (© Marians translation) | RESOLVED — replaced with fresh original house text in all three assets + engine fixtures (commit 789e6d8). No third-party translation ships. |
| Devotional packs (license annotation) | RESOLVED — see `sancta_via_devotionals/assets/content/CONTENT_NOTICES.md` (31 public-domain rows, 2 house-authored; scripture from public-domain translations). |
| Legacy staging corpus (`prayers_staging/`) | RESOLVED — purged from the repo (archived 2026-11-23). |

## Still open (pre-publication)

| Material | Status |
|---|---|
| Kneeling-figure glyph (embedded in app icons, badge of `sancta_via_devotionals/assets/app_icon.png`) | CC BY 4.0 — attribution line exists; `TODO(jason)`: still needs the source page URL before public distribution. |
| `sancta_via_confession_companion/assets/examinations/pope-francis.json` — "Based on Pope Francis' Teachings and Writings" | Examination questions are app-authored paraphrases inspired by papal themes (no LEV text reproduced). Re-label source honestly (e.g. "themes inspired by Pope Francis' magisterium; questions authored for this app") — judgment call pending (Jason). |
| `sancta_via_novena_companion/assets/novenas/st-john-paul-ii.json` | Prayers are house-authored (not JPII quotations). Source label says "Traditional" — re-label as authored-for-app for precision (Jason). |
