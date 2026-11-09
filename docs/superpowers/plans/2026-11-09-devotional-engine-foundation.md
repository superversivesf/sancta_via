# Devotional Engine Foundation — Implementation Plan (Plan 1 of 2)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the pure-Dart devotional engine (scheduling, sessions, progress) plus content-pack schema and the six v1 exemplar packs, so the app (Plan 2) consumes a tested, working foundation.

**Architecture:** Approach A from the spec — data-driven "programs". Two new packages: `sancta_via_devotional_engine` (pure Dart, zero deps except a path dep on the liturgical calendar package for season context) and `sancta_via_devotional_engine_riverpod` (thin provider wrapper). Exemplar content packs are authored as JSON test fixtures in the engine package; Plan 2 copies them into app assets.

**Tech Stack:** Dart 3.9 (sealed classes, records), `test` package (pure Dart packages), `flutter_test`+Riverpod (wrapper), no network, no Flutter in the engine.

**Spec:** `docs/superpowers/specs/2026-11-09-devotionals-app-design.md`

**Plan 2 (not written yet — written AFTER this plan lands):** the `sancta_via_devotionals` app — Today pipeline, screens, session player, NotificationPlanner, sqlite repositories, remaining content packs. Its task list depends on the exact engine APIs defined below.

## Global Constraints

- SDK `^3.9.2`; engine package has **no dart-code dependencies** except `sancta_via_liturgical_calendar` (added in Task 8)
- Pure Dart packages: dev deps `lints: ^4.0.0`, `cider: ^0.2.8`, `test: ^1.24.0` (mirror `sancta_via_liturgical_calendar/pubspec.yaml`); wrapper mirrors `..._riverpod` (flutter_lints ^6.0.0, flutter_riverpod ^2.6.1)
- Style: single quotes, trailing commas, final/const by default, explicit types (no `var`/`dynamic`), import order (dart → package → relative), per `APP_BUILD_RULES.md`
- No `AppLogger` in the pure engine (no Flutter dep); engine errors throw typed engine exceptions
- All date-only arithmetic uses `DateTime(year, month, day)` local construct — never `DateTime.parse` (UTC midnight drift); never convert engine dates to UTC
- Conventional Commits (`feat:`, `test:`, `chore:`) matching repo history
- Every `PrayerText` requires non-empty `source` and `license`; pack loader throws `ContentValidationException` otherwise

## Review Focus

1. **Missed consecutive position** — user skips a First Saturday: counter must mark that position unfulfilled and behave per policy (strict resets, permissive continues), never silently roll forward. Test: Task 6.
2. **UTC drift in date-only math** — `DateTime.parse('2026-12-05')` is UTC midnight; comparisons against local midnight shifts the day. All resolution must construct dates locally. Test: Task 3.
3. **Easter computus outliers** — Meeus/Jones/Butcher exceptions (e.g., 1954, 2049, 2076) must not produce wrong dates for the 1900–2400 range the app can be used in. Test: Task 2.
4. **54-day phase boundary** — day 27→28 must swap petition→thanksgiving openings and 27/54 must terminate, not index out of range. Test: Task 19.
5. **Text without license metadata** — pack loader must throw, never render. Test: Task 11.

---

### Task 1: Engine package scaffold + PrayerText

**Files:**
- Create: `sancta_via_devotional_engine/pubspec.yaml`, `analysis_options.yaml`, `lib/sancta_via_devotional_engine.dart`, `lib/src/models/prayer_text.dart`
- Create: `test/models/prayer_text_test.dart`
- Scaffold mirrors `sancta_via_liturgical_calendar` (topics, funding, environment), name `sancta_via_devotional_engine`, description "Pure Dart engine for Catholic devotional programs: scheduling, sessions, and progress"

**Interfaces:**
- Produces: `class PrayerText { final String id; final String text; final String? latin; final String source; final String license; PrayerText({...required}) ; fromJson/toJson }` and barrel `export src/models/prayer_text.dart`
- Produces: `class ContentValidationException implements Exception` (empty `lib/src/content_validation_exception.dart`) with `final String message; final List<String> problems;`

- [ ] **Step 1: Write failing test** — constructing `PrayerText(id:'memorare', text:'Remember…', source:'', license:'public-domain')` throws `ContentValidationException` mentioning `source`; missing `latin` is fine; `toJson`/`fromJson` round-trip preserves all fields.
- [ ] **Step 2:** `cd sancta_via_devotional_engine && dart test test/models/prayer_text_test.dart` → FAIL (file/model undefined)
- [ ] **Step 3:** Implement `PrayerText` with const constructor validating source/license non-empty; implement `ContentValidationException`.
- [ ] **Step 4:** Same command → PASS; also `dart analyze` clean.
- [ ] **Step 5:** `git add sancta_via_devotional_engine && git commit -m "feat: devotional engine scaffold with PrayerText model"`

---

### Task 2: Computus (Easter calculator)

**Files:**
- Create: `lib/src/scheduling/computus.dart`
- Test: `test/scheduling/computus_test.dart`

**Interfaces:**
- Produces: `DateTime easterSundayFor(int year)` — local `DateTime(year, month, day)`, valid 1900–2400, throws `ArgumentError` outside.

- [ ] **Step 1: Failing test** — golden dates: 2024→Mar 31, 2025→Apr 20, 2026→Apr 5, 2027→Mar 28, 2033→Apr 17, 1954→Apr 18, 2049→Apr 18, 2076→Apr 19; year 1899 and 2401 throw.
- [ ] **Step 2:** `dart test test/scheduling/computus_test.dart` → FAIL
- [ ] **Step 3:** Implement Meeus/Jones/Butcher Gregorian algorithm (exact integer steps; verify against the 1954/2049/2076 exception years the test pins).
- [ ] **Step 4:** PASS
- [ ] **Step 5:** `git commit -m "feat: Gregorian computus (Meeus/Jones/Butcher) with exception-year goldens"`

---

### Task 3: ScheduleResult + FixedDateSpec + EasterOffsetSpec

**Files:**
- Create: `lib/src/models/schedule_result.dart`, `lib/src/models/schedule_spec.dart` (sealed base), `lib/src/models/schedule_context.dart`, `lib/src/scheduling/schedule_evaluator.dart` (fixed/easter resolution)
- Test: `test/scheduling/fixed_and_easter_test.dart`

**Interfaces:**
- Produces:
```dart
class ScheduleContext { final LiturgicalDayData? liturgicalDay; const ScheduleContext({this.liturgicalDay}); }
class ScheduleResult {
  final bool due; final int? dayIndex;      // dayIndex: position within a series/window, 1-based
  final int? ordinal;                        // fulfilled commitment ordinal, e.g. 7 of 9
  final List<String> labels;
  const ScheduleResult({required this.due, this.dayIndex, this.ordinal, this.labels = const []});
}
sealed class ScheduleSpec {
  ScheduleResult resolve(DateTime date, ScheduleContext context);
  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day); // never UTC
}
class FixedDateSpec extends ScheduleSpec { final int month, day; final int? untilMonth, untilDay; }  // range when until set
class EasterOffsetSpec extends ScheduleSpec { final int startOffset; final int lengthDays; }          // due dates Easter+startOffset .. +lengthDays-1
```
- Consumes: `easterSundayFor` (Task 2).

- [ ] **Step 1: Failing test** — `FixedDateSpec(12,17)` due on 2026-12-17, not 12-18; `FixedDateSpec(11,1..8 range)` due 2026-11-03 with `dayIndex: 3`; `EasterOffsetSpec(-2, 9)` due on 2026 Good Friday (Apr 3, dayIndex 1) through Apr 11 (dayIndex 9), not due Apr 12; **UTC-drift test**: `resolve(DateTime.parse('2026-12-17'), ctx).due == false` (UTC-midnight-constructed date resolves as its local-shifted self, not the 17th — pins `_dateOnly` usage).
- [ ] **Step 2:** `dart test test/scheduling/fixed_and_easter_test.dart` → FAIL
- [ ] **Step 3:** Implement sealed `ScheduleSpec` + the two subclasses; `EasterOffsetSpec` uses `easterSundayFor(date.year)`. (Divine Mercy Novena spans years only at ±2 days — no cross-year case in v1; resolution uses Easter of the date's own year.)
- [ ] **Step 4:** PASS
- [ ] **Step 5:** `git commit -m "feat: ScheduleSpec base, FixedDateSpec, EasterOffsetSpec with UTC-drift guard"`

---

### Task 4: NthWeekdayOfMonthSpec

**Files:** Modify `lib/src/models/schedule_spec.dart` (add subclass), `lib/src/models/schedule_result.dart` unchanged. Test: `test/scheduling/nth_weekday_test.dart`

**Interfaces:**
- Produces: `class NthWeekdayOfMonthSpec extends ScheduleSpec { final int weekday; final int nth; }` (weekday: DateTime.monday=1…sunday=7)

- [ ] **Step 1: Failing test** — 1st Saturday of 2026-12 → due 2026-12-05; 1st Friday of 2027-01 → **2027-01-01** (New Year edge); 2nd Sunday of 2026-11 → 2026-11-08; not-due on a non-matching Fri (12-11) or Sat (12-12); no 5th occurrence in a 4-week month → not due (never invents one).
- [ ] **Step 2:** FAIL
- [ ] **Step 3:** Implement: first day of month → first matching weekday → +(nth−1)×7; if resulting day > daysInMonth, not due.
- [ ] **Step 4:** PASS
- [ ] **Step 5:** `git commit -m "feat: NthWeekdayOfMonthSpec with nth>weeks edge"`

---

### Task 5: WeeklyLoopSpec + TimeOfDaySpec

**Files:** Modify `lib/src/models/schedule_spec.dart` (add both). Test: `test/scheduling/weekly_and_tod_test.dart`

**Interfaces:**
- Produces:
```dart
class WeeklyLoopSpec extends ScheduleSpec { final Set<int> weekdays; final List<int>? skipMonths; } // skipMonths: e.g. Friday-solemnity suppression handled via context label, not engine — v1: weekdays only
class TimeOfDaySpec extends ScheduleSpec { final int hour, minute; final List<SeasonVariant> variants; }
class SeasonVariant { final List<int> months; final Set<String>? seasons; final String variantId; } // variant selection by seasonKey from context
```

- [ ] **Step 1: Failing test** — `WeeklyLoopSpec({tuesday})` due every Tuesday in 2026-12 (1,8,15,22,29) and only those; `TimeOfDaySpec(15,0)` due on any date with `labels: ['15:00']`; `TimeOfDaySpec(6,0, variants: […months 4-5→'regina_caeli', else 'angelus'])` returns label `regina_caeli` on 2026-04-20 Eastertide context and `angelus` on 2026-01-20 (same date, both label variants by context.seasonKey — context provides `'Eastertide'` vs `'Christmas'`).
- [ ] **Step 2:** FAIL — **Step 3:** Implement both; variant match: first variant whose seasons/months match context's seasonKey, else base label. — **Step 4:** PASS — **Step 5:** `git commit -m "feat: WeeklyLoopSpec and TimeOfDaySpec with season variants"`

---

### Task 6: ConsecutiveCommitmentSpec

**Files:** Modify `lib/src/models/schedule_spec.dart` (add subclass); Create: `lib/src/progress/commitment_state.dart`. Test: `test/scheduling/consecutive_commitment_test.dart`

**Interfaces:**
- Consumes: `NthWeekdayOfMonthSpec`, `ScheduleResult`.
- Produces:
```dart
class ConsecutiveCommitmentSpec extends ScheduleSpec {
  final ScheduleSpec anchor;      // the per-position spec, e.g. First Saturday
  final int count;                // 5 or 9
  final RestartPolicy policy;     // enum { strict, permissive }
  final List<GraceWindow> windows; // item-level grace, e.g. confession ±8
}
class GraceWindow { final String item; final int beforeDays, afterDays; bool admits(DateTime anchor, DateTime completed); }
class CommitmentState { final int fulfilledOrdinals; final DateTime? lastFulfilledAnchor; static CommitmentState evaluate(ConsecutiveCommitmentSpec spec, Set<DateTime> completedAnchorDates, DateTime today); }
```

- [ ] **Step 1: Failing test** — completed `{2026-09-05, 2026-10-03, 2026-11-07}` First Saturdays → `fulfilledOrdinals: 3`, `lastFulfilledAnchor: 2026-11-07`; adding `2027-01-02` (skipped Dec 5) → strict: state resets to 1 (Dec break); permissive: ordinals continue to 4 with a `labels` note of the gap. Nine First Fridays: completed 5 Fridays then gap → same policy behavior with 2027-01-01 as the 6th in a clean run.
- [ ] **Step 2:** FAIL — **Step 3:** Implement: derive anchor dates since (lastReset|firstCompletion); consecutive = every anchor between first completion and last fulfilled present in set; policy applies on gap. — **Step 4:** PASS — **Step 5:** `git commit -m "feat: ConsecutiveCommitmentSpec with grace windows and restart policies"`

---

### Task 7: Consecration planner + series spec

**Files:** Create `lib/src/scheduling/consecration_planner.dart`; Modify `schedule_spec.dart` (add `SessionSeriesSpec`). Test: `test/scheduling/consecration_test.dart`

**Interfaces:**
- Produces:
```dart
class ConsecrationPlanner { static DateTime startFor(DateTime consecrationDay); } // day 1 = consecrationDay - 33 days; day 34 = consecration day
class SessionSeriesSpec extends ScheduleSpec { final DateTime startDate; final int lengthDays; } // due when 0 <= (date-start).inDays < lengthDays; dayIndex = offset+1
```

- [ ] **Step 1: Failing test** — `startFor(DateTime(2027,3,25))` → 2027-02-20 (non-leap: Feb 20+33 = Mar 25); `startFor(DateTime(2028,3,25))` → 2028-02-21 (leap year); day 34 on the feast itself is due with `dayIndex: 34`; day 35 not due.
- [ ] **Step 2:** FAIL — **Step 3:** `startFor = _dateOnly(consecrationDay).subtract(Duration(days: 33))`; series due-window math. — **Step 4:** PASS — **Step 5:** `git commit -m "feat: consecration 33-day planner and SessionSeriesSpec"`

---

### Task 8: Liturgical context + season overrides

**Files:** Add path dep `sancta_via_liturgical_calendar: { path: ../sancta_via_liturgical_calendar }` to pubspec; Create `lib/src/scheduling/season_overrides.dart`. Test: `test/scheduling/season_overrides_test.dart`

**Interfaces:**
- Consumes: `LiturgicalDayData.seasonKey`, `celebration.rank` from the calendar package (see its `LiturgicalDayData` model).
- Produces:
```dart
enum MysterySet { joyful, sorrowful, glorious, luminous }
MysterySet rosaryMysteriesFor(DateTime date, LiturgicalDayData? day);
// weekday map: Mon/Sat joyful, Tue/Fri sorrowful, Wed/Sun glorious, Thu luminous;
// Sunday overrides: seasonKey Advent or Christmas → joyful; Lent → sorrowful; else glorious.
String angelusPrayerFor(DateTime date, LiturgicalDayData? day); // 'regina_caeli' Easter..Pentecost, else 'angelus'
String marianAntiphonFor(LiturgicalDayData? day); // alma (Advent..Feb 2), ave_regina_caelorum (Feb 2..Holy Week), regina_caeli (Easter..Pentecost), salve (else) — keyed by seasonKey/date month-day
```

- [ ] **Step 1: Failing test** — weekday map (2026-12-14 Mon → joyful; 2026-12-16 Wed → glorious); Sunday exceptions: 2026-12-20 (Advent Sunday) → joyful while 2026-02-22 (Lent-era Sunday seasonKey 'Lent') → sorrowful; Luminous Thursday 2026-12-17; angelus→regina_caeli on 2026-04-05 (Easter context) vs 2026-01-06; antiphon by date: 2026-12-18 → alma, 2027-02-10 → ave, 2026-04-20 → regina, 2026-07-05 → salve.
- [ ] **Step 2:** FAIL — **Step 3:** Implement with the weekday/season/date rules above; antiphon boundaries by (month,day) plus seasonKey for Easter window. — **Step 4:** PASS — **Step 5:** `git commit -m "feat: season overrides for rosary mysteries, angelus swap, Marian antiphons"`

---

### Task 9: SessionScript steps + SessionRunner (core steps)

**Files:** Create `lib/src/models/session_script.dart`, `lib/src/session/session_runner.dart`. Test: `test/session/runner_core_test.dart`

**Interfaces:**
- Produces:
```dart
sealed class SessionStep { final String id; final String? title; }
class PrayerStep extends SessionStep { final PrayerText text; }
class VerseStep extends SessionStep { final String versicle; final String response; final PrayerText? closing; }
class ReflectionStep extends SessionStep { final PrayerText? text; final Duration duration; }
class CheckpointStep extends SessionStep { final String item; final bool requiredForCompletion; }
class IntercessionStep extends SessionStep { final String prompt; }
class SessionScript { final List<SessionStep> steps; final String id; }  // concrete, NOT sealed (Dart sealed types cannot be instantiated; packs/app consume a directly-constructible script type — Task 9 ruling)
class SessionState { final String scriptId; final int stepIndex; final Map<int,int> recordedCounts; final Map<int,DateTime> completedAt; bool get isComplete; toJson/fromJson }
class SessionRunner {
  static SessionState forState(SessionScript script);
  static SessionState completeCurrent(SessionState state);            // advances stepIndex
  static SessionState record(SessionState state, int count);          // increments current step's counter (repetition/reflection progress)
}
```

- [ ] **Step 1: Failing test** — start → stepIndex 0, not complete; completing steps 1..N marks completedAt and ends with `isComplete: true` and stepIndex == steps.length; record() on the current step accumulates counts; `fromJson(toJson(state))` round-trips (resume persists).
- [ ] **Step 2:** FAIL — **Step 3:** Implement immutable state transitions. — **Step 4:** PASS — **Step 5:** `git commit -m "feat: session script steps and core SessionRunner"`

---

### Task 10: SessionRunner bead/repetition/litany steps

**Files:** Modify both Task 9 files. Test: `test/session/runner_beads_test.dart`

**Interfaces:**
- Produces:
```dart
class BeadGroupStep extends SessionStep { final String? mysteryTitle; final String? mysteryFruit; final int hailMaryCount; final bool includeFatimaPrayer; }
class RepetitionStep extends SessionStep { final PrayerText text; final int count; }   // completeCurrent allowed only when recordedCounts reaches count
class LitanyStep extends SessionStep { final List<String> invocations; final String response; final bool groupedResponse; }
```

- [ ] **Step 1: Failing test** — `RepetitionStep(count: 15)`: 14 records → `completeCurrent` throws `StateError` (or records partial and stays), 15th → advance; `LitanyStep(invocations 5)` completes in one action; `BeadGroupStep(mysteryTitle: 'The Annunciation', mysteryFruit: 'Humility', hailMaryCount: 10, includeFatimaPrayer: true)` records decade count 10 then Fatima flag then advances.
- [ ] **Step 2:** FAIL — **Step 3:** Implement the three step types in runner transitions. — **Step 4:** PASS — **Step 5:** `git commit -m "feat: bead group, repetition, and litany session steps"`

---

### Task 11: ContentPack model + loader

**Files:** Create `lib/src/models/content_pack.dart`, `lib/src/content/pack_loader.dart`. Test: `test/content/pack_loader_test.dart`

**Interfaces:**
- Consumes: `PrayerText`, `ScheduleSpec` hierarchy, `SessionScript/SessionStep`, `ContentValidationException`.
- Produces:
```dart
enum PackFamily { commitment, novena, office, routine, chaplet }
class ContentPack { final String id, title; final PackFamily family; final ScheduleSpec schedule; final SessionScript session; final Map<String,PrayerText> content; final Map<String,dynamic> reminders; final List<Map<String,dynamic>> variants; fromJson/toJson }
class PackLoader { static ContentPack load(Map<String,dynamic> json); static ContentPack loadFromJsonString(String s); static List<ContentPack> loadFixturesIn(String dir); }
class PackValidator { static List<String> problems(ContentPack pack, int fixtureYear); } // schedule must resolve on fixtureYear (≥1 due date); every content text has source+license
```

- [ ] **Step 1: Failing test** — valid pack JSON (fixed-date, one prayer) loads; text with empty `license` → `ContentValidationException` (Review Focus 5); unknown `family` → throws; `PackValidator` on a pack with zero due dates in fixture year 2026 → problem listed; schedule type dispatch covers all six spec classes (constructor error otherwise).
- [ ] **Step 2:** FAIL — **Step 3:** Implement loader/validator with per-class JSON parsing (`fixedDate|easterOffset|nthWeekdayOfMonth|consecutiveCommitments|weeklyLoop|timeOfDay`). — **Step 4:** PASS — **Step 5:** `git commit -m "feat: ContentPack model, loader, and validator with license enforcement"`

---

### Task 12: ProgressState + MissedDayEvaluator

**Files:** Create `lib/src/models/progress_state.dart`, `lib/src/progress/missed_day_evaluator.dart`. Test: `test/progress/missed_day_test.dart`

**Interfaces:**
- Consumes: `CommitmentState.evaluate` (Task 6).
- Produces:
```dart
class BadgeRecord { final String title; final DateTime date; }
class ProgressState { final String packId; final int fulfilledOrdinals; final DateTime? lastFulfilled; final int repetitionsToday; final Map<String,String> completedItemsByDay; final List<BadgeRecord> badges; toJson/fromJson }
enum MissedDayVerdict { resume, reset, askUser }
class MissedDayEvaluator { static MissedDayVerdict evaluate(String policy, ProgressState s, DateTime lastFulfilled, DateTime nextDue); }
```

- [ ] **Step 1: Failing test** — state 5/9 with next due 2027-01-01 and policy `strict` + gap → `reset`; `permissive` → `resume`; no gap → `resume`; boundary: state `0` with no completions → `askUser` (nothing to reset).
- [ ] **Step 2:** FAIL — **Step 3:** Implement: `askUser` when user must decide; policy passthrough otherwise. — **Step 4:** PASS — **Step 5:** `git commit -m "feat: ProgressState and missed-day evaluator"`

---

### Task 13: Projection calculator

**Files:** Create `lib/src/progress/projection.dart`. Test: `test/progress/projection_test.dart`

**Interfaces:**
- Consumes: `ConsecutiveCommitmentSpec`, `CommitmentState` (Task 6).
- Produces: `class Projection { static List<DateTime> remainingDates(ConsecutiveCommitmentSpec spec, int fulfilledOrdinals, DateTime from); }`

- [ ] **Step 1: Failing test** — Five First Saturdays, 2 fulfilled, `from 2026-11-20` → exactly `[2026-12-05, 2027-01-02, 2027-02-06]`; length 3; ordinals beyond count → empty list.
- [ ] **Step 2:** FAIL — **Step 3:** Walk anchor dates forward skipping already-fulfilled ones. — **Step 4:** PASS — **Step 5:** `git commit -m "feat: projected completion dates for commitments"`

---

### Task 14: Content pack — Daily anchors (Angelus/Regina Caeli + mercy hour)

**Files:** Create `test/fixtures/packs/daily_anchors.json`; Test: `test/content/daily_anchors_pack_test.dart`

**Interfaces:**
- Consumes: `PackLoader.loadFixturesIn`, `TimeOfDaySpec` variants, `VerseStep`, `PrayerText`, `angelusPrayerFor`.

- [ ] **Step 1: Write pack** — `id: daily_anchors`, family `routine`, `timeOfDay` specs: 6:00 (variants: months [4,5] + seasonKey 'Eastertide' → `regina_caeli` variant; else `angelus`) with 3 verse steps + collect; 15:00 mercy hour with `PrayerStep` (Diary-free Hour of Mercy text, source/license fields filled: `source: 'Diary of St. Faustina (short invocation)', license: 'short-phrase' — see plan note below`) and repetition step ×1; session steps reference `angelus_prayers` content map.
- [ ] Note: Divine Mercy *Diary* translations stay out (spec §8). The 3pm hour uses the universally-reproduced short invocations w/ attribution `"St. Faustina tradition (public-domain devotional rendering)"`, license `"public-domain"`. If implementer cannot source a clean text, mark the step `reflection` with prompt instead of prayer text.
- [ ] **Step 2: Failing test** — pack loads; resolves 2026-01-20 label `angelus` + 2026-04-20 label `regina_caeli`; session has 3 `verse` steps then 1 prayer; validator passes fixture years 2026.
- [ ] **Step 3:** Fix until pass — **Step 4:** `cd sancta_via_devotional_engine && dart test test/content/daily_anchors_pack_test.dart` PASS — **Step 5:** `git commit -m "feat: daily anchors pack (angelus/regina caeli, mercy hour)"`

> Ruling amendment (2026-11-09 fix round): the `daily_anchors` pack was split into two per-devotion packs — `test/fixtures/packs/angelus.json` (Angelus/Regina Caeli, variant keyed by seasonKey only, no month leak into Lent/post-Pentecost) and `test/fixtures/packs/mercy_hour.json` (15:00 Hour of Mercy); the `schedules` list schema from the round-1 ruling remains for future multi-anchor packs.

---

### Task 15: Content packs — Nine First Fridays & Five First Saturdays

**Files:** Create `test/fixtures/packs/nine_first_fridays.json`, `test/fixtures/packs/five_first_saturdays.json`; Test: `test/content/first_weekday_packs_test.dart`

**Interfaces:** Consumes `NthWeekdayOfMonthSpec`, `ConsecutiveCommitmentSpec` (counts 9 and 5), `GraceWindow` (confession ±8 on Saturdays only), `CheckpointStep` (saturday: confession, communion, 5 decades, 15-min meditation; friday: communion, reparation prayer).

- [ ] **Step 1: Write packs** — Friday pack: anchor `nthWeekdayOfMonth(6,1)`, count 9, policy `strict`, session: prayer (offeratory) + checkpoint communion + prayer of reparation (source: public-domain Sacred Heart devotion texts). Saturday pack: anchor `nthWeekdayOfMonth(7,1)`, count 5, windows `[{item:'confession',beforeDays:8,afterDays:8}]`, session: 4 checkpoints + rosary 5-decade `BeadGroupStep`s (Joyful mysteries referenced) + 15-min `ReflectionStep`.
- [ ] **Step 2: Failing test** — both load and validate (fixture year 2026); Saturday grace window admits 2026-11-30 for anchor 2026-12-05 but rejects 2026-11-20; Friday pack resolves 2027-01-01.
- [ ] **Step 3–5:** fix → PASS → `git commit -m "feat: Nine First Fridays and Five First Saturdays packs"`

---

### Task 16: Content pack — Divine Mercy Novena

**Files:** Create `test/fixtures/packs/divine_mercy_novena.json`; Test: `test/content/divine_mercy_pack_test.dart`

**Interfaces:** Consumes `EasterOffsetSpec(-2, 9)`, `BeadGroupStep`-scripted chaplet (opening O Blood & Water ×3 as `repetition`, Eternal Father on 5 large-bead prayers as a 5× `prayer` cycle within the group, closing Holy God ×3), 9 daily intention labels.

- [ ] **Step 1: Write pack** — novena pack: `easterOffset` schedule; session: opening prayers, one `beadGroup`-formatted chaplet step group (modeled as repetition+prayer steps per Task 10's supported shapes), closing; `variants`: 9 daily intentions as `intercessionStep` prompt list (day N = intention N via session day-index); no Diary translation texts (spec §8) — core chaplet formulas only, attribution `license: public-domain (universally reproduced; attribution: USCCB/MARIANS wording)`.
- [ ] **Step 2: Failing test** — resolves Good Friday 2026-04-03..2026-04-11 (9 dates); day-intention mapping returns intention list item N; validator passes.
- [ ] **Step 3–5:** fix → PASS → `git commit -m "feat: Divine Mercy novena pack (Easter-anchored, 9 intentions)"`

---

### Task 17: Content pack — Four-mystery Rosary

**Files:** Create `test/fixtures/packs/rosary.json`; Test: `test/content/rosary_pack_test.dart`

**Interfaces:** Consumes `WeeklyLoopSpec` (every day) + pack-level `mysteryOverride` (Task 8's `rosaryMysteriesFor` provides the day's set; pack carries all 20 mystery titles/fruits as content).

- [ ] **Step 1: Write pack** — routine pack, schedule `weeklyLoop` all weekdays; session: opening (creed/Our Father/3 HMs/Glory be as verse+prayer steps), 5 `BeadGroupStep`s with mystery titles parameterized by the day's set (`mysterySource: rosaryMysteriesFor`), closing Hail Holy Queen + collect. Sunday season overrides are engine-side; pack stores 20 mysteries with fruits.
- [ ] **Step 2: Failing test** — pack resolves daily; session's mystery-source hook returns `{joyful sorrowful glorious luminous[4th]}` for the 2026-12-14..17 weekday run; Advent-Sunday override yields joyful without pack changes.
- [ ] **Step 3–5:** fix → PASS → `git commit -m "feat: rosary pack with all 20 mysteries and season-driven set selection"`

---

### Task 18: Content pack — Total Consecration (de Montfort)

**Files:** Create `test/fixtures/packs/total_consecration.json`; Test: `test/content/consecration_pack_test.dart`

**Interfaces:** Consumes `ConsecrationPlanner.startFor`, `SessionSeriesSpec`, phase labels (`emptying(1-12)`, `self(13-19)`, `mary(20-26)`, `jesus(27-33)`, `consecration(34)`).

- [ ] **Step 1: Write pack** — commitment pack; `sessionSeries`-shaped schedule (start computed at enrollment); daily `reflection` steps referencing public-domain de Montfort reading titles (source/license: `public-domain`), daily prayer steps (Veni Creator, Ave Maris Stella, Magnificat — Latin + English as variant texts); day-34 → `prayer` Act of Consecration + badge.
- [ ] **Step 2: Failing test** — enrollment for feast 2027-03-25 yields start 2027-02-20; day index→phase label mapping correct at 1/12/13/19/26/33/34; validator passes.
- [ ] **Step 3–5:** fix → PASS → `git commit -m "feat: de Montfort Total Consecration pack with 4 phases"`

---

### Task 19: Content pack — 54-Day Rosary Novena

**Files:** Create `test/fixtures/packs/novena_54_day.json`; Test: `test/content/novena_54_day_test.dart`

**Interfaces:** Consumes `SessionSeriesSpec` (user-picked start, length 54), phase logic: `dayIndex ≤ 27 → petition`, else `thanksgiving`; daily mystery = cycle J,S,G by `dayIndex % 3` (1→joyful, 2→sorrowful, 0→glorious).

- [ ] **Step 1: Write pack** — novena pack; daily session: phase opening (two PD opening petitions stored in content), 3 `BeadGroupStep`s (one per chosen mystery), phase closing; restart policy surfaced as `variants: [{id: strict},{id: permissive}]` (engine `MissedDayEvaluator` consumes policy).
- [ ] **Step 2: Failing test** — Review Focus 4: day 27 → petition label + Joyful-set mysteries; day 28 → thanksgiving + Sorrowful; day 54 → thanksgiving and `isComplete` at series end (no index overflow); day 55 not due.
- [ ] **Step 3–5:** fix → PASS → `git commit -m "feat: 54-day rosary novena pack with petition/thanksgiving phases"`

---

### Task 20: Riverpod wrapper package

**Files:**
- Create: `sancta_via_devotional_engine_riverpod/pubspec.yaml` (mirror liturgical_calendar_riverpod: flutter sdk, flutter_riverpod ^2.6.1, path deps on engine + liturgical_calendar(_riverpod)), `lib/sancta_via_devotional_engine_riverpod.dart`, `lib/src/program_repository.dart`, `lib/src/providers/program_providers.dart`
- Test: `test/program_providers_test.dart`

**Interfaces:**
- Consumes: engine barrel (Task 1–19 types), `sancta_via_liturgical_calendar_riverpod`'s `currentDateProvider` (see its `liturgical_providers.dart`).
- Produces:
```dart
abstract class ProgramRepository {
  Future<List<ContentPack>> loadPacks();
  Future<ProgressState?> progressFor(String packId);
  Future<void> enroll(String packId, Map<String, dynamic> params);
  Future<void>saveProgress(ProgressState s);
}
class InMemoryProgramRepository implements ProgramRepository  // ships preloaded with the six fixture packs (compiled-in via a generated dart map — packs are test fixtures in the engine; wrapper embeds them through `loadFixturesIn`)
final enrolledProgramsProvider = FutureProvider<List<EnrolledProgram>>(…);
final todayProgramsProvider = FutureProvider<List<DueToday>>((ref) async {
  // combine repo packs + progress + ref.watch(currentLiturgicalDayProvider) + ScheduleResult.resolve
});
final programDetailProvider = FutureProvider.family<ProgramDetail, String>(…);
```

- [ ] **Step 1: Failing test** — `InMemoryProgramRepository.loadPacks()` returns 6 packs; `todayProgramsProvider` on overridden date 2026-12-05 + progress 0 shows Five First Saturdays as due with ordinal 1; **test-override**: `currentDateProvider.updateWith(Stream.value(DateTime(2026,12,5)))` (periodic timers never complete — monorepo gotcha).
- [ ] **Step 2:** FAIL — **Step 3:** Implement thin providers; embed fixture packs via a build step: `dart tool/embed_packs.dart` copies `../sancta_via_devotional_engine/test/fixtures/packs/*.json` into `lib/src/embedded_packs.dart` (const map wrapper) and run it once; document regeneration in README. — **Step 4:** PASS (engine `dart test`, wrapper `flutter test`) — **Step 5:** `git commit -m "feat: devotional engine riverpod wrapper with in-memory program repository"`; then `cd sancta_via_devotional_engine && dart test && cd ../sancta_via_devotional_engine_riverpod && flutter test` → both green, `melos run analyze` clean; commit any melos-lockfile updates ("chore: workspace bootstrap").

---

## Self-Review Notes

- **Spec coverage:** six schedule classes (T3–T7), season overrides (T8), session engine + all 8 step types (T9–T10), pack format + license enforcement + all v1 exemplar packs (T11, T14–T19), progress/missed-day/projection (T6, T12, T13), riverpod integration seam (T20). Office/1962 content authoring and the app itself are **Plan 2** (need real engine APIs + sqlite + flutter_local_notifications; plan written after this one lands — per spec §11 open items and the user's iterate-in-use expectation).
- **Deferred on purpose:** NotificationPlanner, sqlite, onboarding/enrollment UI, Office edition content — Plan 2 scope.
