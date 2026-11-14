# Saint Histories — top-20% authored entries design

**Date:** 2026-11-14
**Status:** draft — pending builder check + partner approval

## Intent

Enrich the saint companion's most significant saints with reasonably
detailed, accurate summary histories. The companion currently ships a
~120-word story per saint; ~20% (≈435) of the most well-known saints get
longer, anchored, cross-checked entries. Saints not covered this round
keep their existing story unchanged.

## Why this scope

The partner asked for longer histories only where authoring can be
**anchored to a verifiable source**. New Advent's Catholic Encyclopedia
(CE, 1907–12, public domain) is both a significance signal (a CE article
exists ⇒ the saint is historically notable) and the anchor source itself
(robots.txt permits /cathen/; articles fetch as structured HTML —
verified 2026-11-14). Cross-model review catches authoring errors.

## Goals / non-goals / anti-goals

**Goals**
- ~435 detailed histories (400–800 words; longer for the most major)
- Every entry grounded in the saint's CE article (PD) + the seed record
- Every entry fact-checked by a second, different model against that
  source; disputes fixed before acceptance
- Schema v2 of `saints.db` carrying the new fields; detail screen renders
  them; the dormant sources section goes live
- Per-saint provenance (`historySource`) shipped in the data

**Non-goals**
- The other ~1,739 saints stay on their existing stories (future pass)
- No new prayers, no patronage changes from this work
- No app UI redesign beyond rendering the history

**Anti-goals**
- Invented miracle claims beyond tradition; uncited specific facts that
  contradict the CE anchor; promotional tone

## Approach (picked by the partner)

Hybrid, narrowed: author only CE-matched saints. Considered and rejected:
pure Butler/CE scraping for all saints (coverage + archaic-prose costs)
and fully ungrounded authoring (accuracy risk at scale).

## Pipeline (how)

1. **Selection** — scrape the New Advent CE full index (`cathen/{letter}-ce.htm`); normalize names
   (3 rules: honorific strip, trailing-honorific strip `", Saint|Blessed|…"`, surname-reorder);
   match 1:1 against the 2,174 seed records — collisions and <0.9 ratio matches quarantine to
   `data/grounding/manual_review.json` (never auto-shared); rank matches (article length ×
   patronage count; featured is 6/2,174 so it's a weak signal — noted); produce `selection.json`
   **for a partner read**; alias pass from the quarantines + renamed list; take ≈400 + documented
   drops. Rate-limit ≥2.2 s/request, idempotent/cache like `fetch_sources`.
2. **Anchor scrape** — per selected saint, the CE article → `data/grounding/<ce-code>.txt`
   (cache keyed on CE code; re-runs resume; strip CE site nav/"help support"/copyright
   boilerplate), manifest `data/grounding/manifest.json` (slug, ceCode, url, fetchedAt, sha256).
3. **Authoring** — per-entry (4–6 concurrent): the authoring model writes each history grounded
   in (CE article + seed record), length `min(800, ~1.5× anchor)` floor ~250 words, facts
   consistent with the seed record (feast day, canonization, patronages), conservative language
   where tradition is uncertain.
4. **Cross-check** — a *different* model re-reads each entry against the CE grounding text:
   flags unsupported claims, date errors, confabulations; disputes loop (max 2 rounds) →
   unresolved entries drop from the round (fall back to short bio). Deterministic validators
   run first (dates/names/feast-day cross-refs) before any model spend.
5. **Validators** — history 400–4000 chars; `history_source` matching
   `^catholic-encyclopedia-1907 https://www\.newadvent\.org/cathen/\S+$`; seed-record
   consistency (feast day, patronages); spot controller review 2–3 per batch.
6. **Storage** — authored text in `data/histories.json` (slug-keyed; never in the byte-pinned
   `saints_source.json`); `saints.db` schema v2: `history TEXT`, `history_source TEXT` columns +
   new `sources(slug, url, position)` table (built from the seed data's existing per-saint
   source URLs for ALL 2,174); version stamp bump; rebuild via the existing tooling.
7. **App** — detail screen: bio (lead) → **History section** (rendered when present) → prayer
   card → **live Sources section** (the dormant `_buildSources` renders once the table exists
   and `Saint.fromDbRow` gains sources; minimal diff to existing layout).

**Partner decisions (2026-11-14):**
- Count: exact matching (~327) + the one-time alias/rename pass → target
  ~400; CE-modern saints have no article and are documented drops.
- `selection.json` (ranked list + drops + reasons) gets a partner read
  before authoring spend.
- `sources` table populated for ALL 2,174 records (Wikipedia URLs already
  shipped in the seed data) — near-free at schema v2.

**Builder rulings accepted:**
- Full CE index `cathen/{letter}-ce.htm` (327 exact matches measured vs
  185 partial); 3-rule name normalization + 1:1 quarantine of collisions
  to `data/grounding/manual_review.json`; per-entry authoring w/ 4–6
  concurrent; authored text in `data/histories.json` merged at build
  (never in the byte-pinned snapshot); grounding files
  `data/grounding/<ce-code>.txt` + manifest; schema v2 adds `history`,
  `history_source` columns and a live `sources(slug, url, position)`
  table; leave FTS on `bio`; length scales to anchor
  `min(800, ~1.5× anchor)`, floor ~250 words; attribution wording:
  "Adapted from the Catholic Encyclopedia (1907–12)" + article URL;
  bio remains the lead with History stacking under it; real test counts:
  `saint_data` 137, `saint_companion` 64 (schema-v2 pins listed: version
  tests, `fromDbRow` optional params, detail-screen section tests).

## Model policy

Authoring: glm (session model). Cross-check: deepseek + minimax
(rotating) — every entry checked by a model that did not write it.

## What's left to the builder

Exact CE-index URL forms / redirect handling; name-normalization edge
cases; per-batch prompt tuning; the history section's exact UI styling.

## Risks

- CE matching may miss some well-known saints under variant names
  (documented drops, counted).
- Cross-check disagreement loops are bounded (2 rounds → drop).
- Schema v2 must keep the existing 29-test suite green plus new pins.
