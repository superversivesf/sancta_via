# Sancta Via Devotionals — App Design Spec

**Date:** 2026-11-09
**Status:** Approved design (sections approved in-session 2026-11-09)
**Research basis:** `docs/superpowers/research/2026-11-09-catholic-devotionals-research.md`

---

## 1. Overview

A Flutter app — the 6th app in the Sancta Via monorepo — that helps a Catholic user
*practice* daily devotions, not just read about them. It combines:

1. **Liturgy of the Hours** — reminders + guided sessions (1962 public-domain texts in v1; Ordinary-Form texts are a later licensed workstream).
2. **Commitment trackers** — novenas, Nine First Fridays, Five First Saturdays, 33-day consecrations, 54-day rosary novena, with countdowns, ordinal counters, grace windows, and completion badges.
3. **Daily prayer routine** — a "Today" screen assembling readings, Rosary (day-of-week + season-aware mysteries), Angelus/Regina Caeli, Divine Mercy 3pm hour, Examen, meal/night prayers.
4. **Liturgical-calendar awareness** — reuses Sancta Via's romcal-based calendar (season, rank, color, cycle) for theming and content selection.

### Success criteria

- A user can enroll in a First-Friday/First-Saturday/novena/consecration commitment and the app correctly counts across months, handles grace windows, and shows projected completion.
- The Today screen shows a complete, correctly themed picture of the devotional day, fully offline.
- Reminders fire at the right times (Angelus 6/12/6, 3pm mercy hour, morning-of for dated commitments).
- Adding a new devotion is authoring a content pack (JSON + texts) with **no engine code changes**.
- All texts render only with `source` + `license` metadata; attribution screen lists them.

### Distribution & constraints

- **Free, forever.** No sales, no ads, no accounts, no cloud. Fully offline.
- iOS + Android from one Flutter codebase (user's phone device tuned first).
- English; Latin display toggle is a variant flag where texts allow.
- Text-first sessions in v1 (no recorded audio; pacing timers instead).

### Non-goals for v1

Recorded audio narration · cloud sync / family sharing · widgets & Live Activities ·
full ~250-novena catalog · Ordinary-Form Office texts · saint bios · region profiles
beyond the US-default calendar already generated · scraping USCCB or any site.

---

## 2. Key decisions (carried from approval conversation)

| Decision | Choice |
|---|---|
| Distribution | Personal use first, given away free; never sold |
| Repo | 6th app in `sancta_via` monorepo (melos; relative path deps) |
| Reuse | `sancta_via_liturgical_calendar(+)riverpod` (dates/ranks/colors), `sancta_via_shared_ui` (theme, ColorIntensity, UnifiedSettingsScreen), `sancta_via_bible_data` (readings) |
| Hours text strategy | **Hybrid**: engine + 1962 PD texts now; edition-agnostic Office engine; pursue OF licensing (2nd-edition digital window opens mid-2027) later |
| v1 library depth | Core set deep + extensible (see §8) |
| Architecture style | Approach A: data-driven "programs" — schedule engine + session engine + progress store interpreting content packs |

---

## 3. Package architecture

```
sancta_via/
├── sancta_via_devotional_engine/            # NEW — pure Dart, no Flutter deps
│   ├── models/                              # Program, ScheduleSpec, SessionScript,
│   │                                        # ProgressState, ContentPack, PrayerText
│   ├── scheduling/                          # 6 ScheduleSpec interpreters + season overrides
│   ├── session/                             # script interpreter (steps, beadGroups, timers)
│   └── progress/                            # ordinal/phase/repetition/missed-day calculators
├── sancta_via_devotional_engine_riverpod/   # NEW — providers wiring calendar ↔ engine
├── sancta_via_devotionals/                  # NEW — the app
│   ├── assets/content/                      # content packs (JSON + prayer texts)
│   └── lib/{config,models,repositories,services,screens,providers,utils}
├── sancta_via_liturgical_calendar(+_riverpod)   # REUSED
└── sancta_via_shared_ui                          # REUSED
```

Conventions follow `APP_BUILD_RULES.md`: repository pattern with sqlite, Riverpod
providers, GoRouter named routes + centralized error handling, AppLogger,
`melos bootstrap` dependency graph, per-app Makefile + update_build_info.sh.

---

## 4. Data model

### 4.1 ContentPack (authored as JSON in `assets/content/`, migrated to SQLite on first launch)

```jsonc
{
  "id": "five_first_saturdays",
  "title": "Five First Saturdays",
  "family": "commitment",           // commitment | novena | office | routine | chaplet
  "schedule": {
    "type": "nthWeekdayOfMonth",    // one of six classes (§4.2)
    "weekday": 6, "nth": 1,
    "commitment": { "count": 5, "restartPolicy": "strict|permissive" },
    "graceWindows": [ { "item": "confession", "beforeDays": 8, "afterDays": 8 } ]
  },
  "session":   { /* SessionScript, §4.3 */ },
  "content":   { /* PrayerText entries, each with source + license fields */ },
  "reminders": { "offset": "morningOf", "fallback": ["previousEvening"] },
  "variants":  [ /* 15 vs 1 repetition, Latin parallel, 15th station, Luminous toggle */ ]
}
```

Every **PrayerText** carries `source`, `license`, `attribution`; the pack loader
refuses to render any text lacking them. Pack schema is validated by tests.

### 4.2 ScheduleSpec — the six pattern classes

| Type | Resolves | v1 examples |
|---|---|---|
| `fixedDate` | calendar month/day or range | O Antiphons (Dec 17–23), Holy Souls week (Nov 1–8) |
| `easterOffset` | Easter ± N (computus computed in-engine, any year) | Divine Mercy Novena (E−2…E+6) |
| `nthWeekdayOfMonth` | 1st/2nd/3rd… weekday of month | First Fri/Sat/Thu/Wed |
| `consecutiveCommitments` | N consecutive calendar *positions*, counter + restart policy + grace windows | Nine First Fridays; 33-day consecration (start = chosen feast − 33; leap-year aware) |
| `weeklyLoop` | every weekday-of-week | perpetual novenas; Friday penance |
| `timeOfDay` | daily clock anchor | Angelus 6/12/6, 3pm mercy hour, Lauds/Vespers/Compline |

Season overrides attach to any spec (Rosary Sunday exceptions: Advent/Christmas→Joyful,
Lent→Sorrowful; Angelus→Regina Caeli swap during Eastertide; seasonal Marian antiphon).
Counters count **calendar positions, not dates** (a missed First Saturday means that
month's position is unfulfilled).

### 4.3 SessionScript step types

- `prayer` — fixed text, multi-variant, optional Latin
- `verse` — versicle/response pair (Angelus, litany-style call-and-response)
- `beadGroup` — Our Father + 10 Hail Mary + Glory Be (+ optional Fatima prayer), with
  mystery title/fruit/scripture; parameterized for Rosary, chaplets, Divine Mercy
- `litany` — response-cycle list
- `repetition` — one text × N with increment counter (St. Andrew ×15, Therese ×24)
- `reflection` — timed block with optional reading (Examen steps, Lectio, 15-min First-Saturday meditation, consecration day readings)
- `checkpoint` — non-prayer sub-item (confession, Mass, 5 decades) participating in completion logic and grace windows
- `intercession` — intention/soul-list insertion (Morning Offering pulls the month's papal-intention line from content)

Steps record completion; pause/resume; partial credit supported ("2 of 5 decades")
per the program's lenient/strict policy.

### 4.4 ProgressState (per enrolled program; sqlite)

`ordinal` (e.g., 7 of 9 First Fridays), `phase` (54-day petition/thanksgiving;
consecration weeks 1–4 — day-of-emptying/ Self / Mary / Jesus / Joseph),
`repetitionsToday`, `completedItemsByDay` (grace-window lookups),
`missedDayPolicy`, `badgeHistory[]` (dated completions), `lifetimeCount`.
A missed-day evaluator runs on app open and surfaces the policy choice.

---

## 5. Engines

### Scheduling engine
Interprets ScheduleSpecs against (a) liturgical day from the calendar package and
(b) calendar date; emits due items for a date. Computes Easter internally
(computus) so novena/consecration math works beyond the calendar package's 2035
data horizon; the calendar package supplies season/rank/color metadata per day.

### Session engine
Renders SessionScripts: bead progress dots, tap-increment repetitions, countdown
rings + text for reflections, explicit checkboxes for checkpoints, end-of-session
completion summary. Office hours are composed programs: hour skeleton from the
1962 data subset (psalmody structure, antiphon selection incl. seasonal Marian
antiphon, canticles, collect) generated per day via an `EditionProvider` seam so
an Ordinary-Form edition can replace texts later without engine changes.

### Progress store
sqlite repositories (monorepo pattern), singleton caching with synchronization,
missed-day evaluator, ordinal projection ("next First Saturdays: Dec 6, Jan 3, Feb 7").

---

## 6. Data flow — the "Today" pipeline (offline, local only)

```
LiturgicalCalendarService.getDayForDate(today)      # reused calendar package
        ↓
ProgramScheduler.evaluate(today, enrolledPrograms)  # schedule engine
        ↓  today's items: due sessions, time anchors, routine blocks, feast prompts
TodayScreen: Morning / 6a·Noon·6pm / 3pm / Evening / Commitments / Feasts coming
        ↓
NotificationPlanner: precompute triggers → flutter_local_notifications (+timezone)
```

---

## 7. Screens & navigation

GoRouter + `StatefulShellRoute`, four tabs:

1. **Today** (home) — liturgical header (celebration, rank, color, psalter week);
   time-grouped sections (Morning · Angelus times · 3pm · Evening · Commitments ·
   Upcoming feasts via `nextOccurrenceProvider`); onboarding empty state.
2. **Practice** — program catalog by family; detail screen (description, structure,
   promises/indulgence notes with sources, schedule preview, variants, Enroll).
3. **Progress** — enrolled programs (ordinal counters, streaks, phase banners),
   badges with dates, history heatmap, lifetime counts, intentions/souls list,
   indulgence sheet (conditions checklist + 1-per-day plenary cap note).
4. **Settings** — `UnifiedSettingsScreen` (theme, color intensity, accessibility) +
   anchor reminder times/toggles, Luminous-set toggle, missed-day policy defaults,
   Latin toggle, app-specific links.

**Session Player** (pushed route): full-screen script renderer as in §4.3.
**Onboarding** (~90s): claim existing progress ("I'm already 7 First Fridays in"),
pick baseline routine, set reminders.
**Enrollment flow**: commitment-aware (Nine First Fridays counts from next occurrence;
33-day consecration = pick feast → start date = feast − 33 → day-34 milestone screen;
54-day = phase explainer + missed-day policy choice).

---

## 8. v1 content set

| Family | Programs |
|---|---|
| Office | 1962 Lauds, Vespers, Compline, minor hours, Office of Readings/Matins (curated Divinum Officium MIT data subset; Latin + English) |
| Commitments | Nine First Fridays; Five First Saturdays; de Montfort 33-day Total Consecration (PD); 54-day Rosary Novena (PD petitions; configurable missed-day policy) |
| Novenas (≈10) | Divine Mercy (Easter-anchored, 9 daily intentions); Christmas (Dec 16–24); Novena for the Dead; Holy Spirit/Pentecost; Sacred Heart; St. Jude; Mary Undoer of Knots; Miraculous Medal; Perpetual Help; St. Joseph |
| Anchors/routine | Rosary (weekday map + season overrides); Divine Mercy chaplet + 3pm hour; Angelus/Regina Caeli; Morning Offering; daily Examen; Lectio divina; meal/night prayers — seeded by importing prayer_companion's 67 prayers |
| Chaplets/litanies | St. Michael; Seven Sorrows; Franciscan Crown; Holy Wounds; St. Anne; Litanies of Loreto, St. Joseph, Humility, Sacred Heart, Precious Blood |

**Licensing gates (respected):**
- Not reproduced: Divine Mercy *Diary* translations (© Marians). Chaplet core formulas
  ship with attribution (universally reproduced e.g. by USCCB); Diary-only
  opening/closing prayers omitted pending license.
- Companion mode (schedule calculator + link, no copied text): Calloway & Gaitley
  33-day books.
- Readings: from `sancta_via_bible_data` + link-out to bible.usccb.org for the
  official text; no scraping. Translation's license verified before integration.
- No third-party app content (Universalis output, Franciscan Media bios, AELF, etc.).
- Martyrology/saint names come from the generated calendar data; saint bios deferred.

---

## 9. Notifications & offline behavior

- Zero network dependency, zero background tasks required: everything computed
  from embedded data (calendar 2024–2035 + in-engine computus + content packs).
- `NotificationPlanner` precomputes ~60-day horizon → `flutter_local_notifications`
  with `TZDateTime` (DST-safe). Anchors repeat; dated items scheduled individually.
- iOS ~64-pending cap: refresh points (app open, session completion, notification
  tap) re-run planner and rotate the window. Accuracy of the Today screen never
  degrades; only distant un-opened future pings may lapse. Documented trade-off.
- Deep links: tap → session player or Today section.
- Season-aware bodies ("Regina Caeli" in Easter; "Day 6 of 9"; "Tomorrow: First
  Saturday — confession may be made within 8 days").
- One composite Morning/Evening reminder by default; per-anchor toggles; night
  items fire only if explicitly enabled.
- Storage: sqlite content mirror + progress + notification index; `shared_preferences`
  for settings; version-stamped content migration on upgrade.

---

## 10. Testing strategy

- **Schedule-engine golden tables** per pattern class, validated against USCCB
  published calendars (e.g., 2026: Ash Wed Feb 18, Easter Apr 5, Divine Mercy E+7…
  2027: Ash Wed Feb 10, Easter Mar 28); nth-weekday edge cases; grace-window math;
  consecration feast−33 leap-year table.
- **Progress semantics**: consecutiveness breaks/resets, ordinals, phase
  transitions (27/54, weeks 1–4), strict vs permissive policies.
- **Session engine**: step-sequence goldens; partial credit; resume persistence.
- **Content packs**: schema validation — every text has source/license; every
  schedule resolves on a fixture year.
- **Today pipeline widget tests** on frozen `DateTime` (empty/onboarding, full day,
  feast day). Riverpod note: override `currentDateProvider` in tests with a
  single-emission stream (periodic timers never complete — known monorepo gotcha).
- TDD throughout; `melos run test` across packages.

---

## 11. Risks & open items

| # | Risk / open item | Handling |
|---|---|---|
| 1 | Calendar data horizon ends 2035 | Regeneration script exists (`sancta_via_liturgical_calendar/tools`); build-time task; engine computes Easter independently so practice scheduling never blocks |
| 2 | bible_data translation license unverified | Verify during implementation planning before readings integration; fallback Douay-Rheims PD |
| 3 | iOS 64-notification cap | 60-day rolling refresh documented above |
| 4 | OF (Ordinary Form) Office text | Out of scope v1; `EditionProvider` seam; licensing workstream documented (2nd edition digital licensing opens mid-2027; mandatory use Dec 2028) |
| 5 | romcal data lacks some practice metadata (e.g., Ember/rogation days, St. Blaise) | Practice scheduling is engine-owned (fixedDate/easterOffset), independent of romcal gaps |
| 6 | Papal monthly intention feed for Morning Offering | Shipped as manually updated content field until an official permissible feed is confirmed |

---

## 12. Roadmap after v1 (not in scope)

Full novena catalog (~250) · more chaplets/litanies · recorded audio ·
widgets/Live Activities · Ordinary-Form Office via licensing · regional profiles ·
family sharing / group novenas · unification with the 5 existing apps (per the
monorepo's unified-app feasibility report — this engine is designed to be the
foundation a future unified app inherits).
