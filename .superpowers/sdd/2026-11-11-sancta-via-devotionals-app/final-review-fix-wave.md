# Final-review fix wave — 2026-11-14

Scope: the complete final-review finding set for Plan 2 (devotionals), applied
in place on `main` (never pushed). All fixes are offline; no new dependencies.

## Status

| Item | Status | Where |
| --- | --- | --- |
| C1 Android notification platform config | done | `sancta_via_devotionals/android/…`, `ios/Runner/AppDelegate.swift` |
| C2 Eastertide plays the resolved label's content | done | `session_player_provider.dart` |
| C3 commitment counting: double-count + strict dead letter | done | `progress_service.dart`, `progress_providers.dart` |
| I1 grace-window surface | done | `step_views.dart`, `progress_providers.dart`, `progress_screen.dart` |
| I2 Leave program | done | `program_detail_screen.dart` |
| I3 Luminous inert switch | done — HIDDEN (engine has no with-luminous selector) | `devotionals_settings_screen.dart` |
| I4 dishonest 'Meal & night' copy | done | settings + onboarding |
| I5 Fatima from pack content + attribution | done | `session_player_provider.dart`, `step_views.dart` |
| I6 lectio/unused deps | done — deferral ledgered, bible_data deps kept | `README.md` |
| I7 promises/indulgence notes | done — de-scoped with a ledger line | `README.md` |

Commits (on `main`, not pushed): `5091910` (C1), `a26afb8` (C2/C3/I1/I5),
`ab110ff` (I2/I3/I4), plus the docs/ledger commit that carries this file.

## Red → green evidence

### C2 — Eastertide plays Regina Caeli (session must match the notification)

Red first (new test, current code):

```
00:00 +8 -1: SessionPlayerController schedule-label alternates an Eastertide
  Angelus resolves the Regina Caeli versicles and collect [E]
  Expected: contains 'Queen of Heaven, rejoice, alleluia'
    Actual: 'The Angel of the Lord declared unto Mary.'
```

Green after the fix:

```
00:00 +14: All tests passed!   (test/providers/session_player_provider_test.dart)
```

Mapping rule (documented in the provider header): the first resolved
`ScheduleResult.labels` entry for which the pack ships `<label>_versicles` /
`<label>_collect` selects the alternate — the versicles text's V./R. pairs
replace the verse steps pair-for-pair in script order, and `<label>_collect`
replaces the prayer step whose content id ends `_collect`. Ordinary time keeps
the pack default (pinned by a second test). The season key now comes from
`LiturgicalCalendarService.getDayForDate(sessionDay)` in `_resolveDay`, the
same resolution Today and the notification planner use.

### C3(a) — same-anchor-day double count

Red (guard disabled temporarily to record the baseline):

```
  Expected: <1>
    Actual: <2>
00:00 +0 -1: Some tests failed.
```

Green:

```
00:00 +15: All tests passed!   (completion-counting group)
```

Rule: `persistCompletion` skips the increment AND the badge when the pack's
family is `commitment` and the persisted `lastFulfilled` is the completion's
own calendar day; completion records still layer (a grace-window item recorded
later credits the anchor). Routine packs keep incrementing — the same test
pins two same-day Angelus sessions at ordinal 2 / two badges.

### C3(b) — strict gap on a commitment surfaces

Red (verdict gate disabled):

```
  Expected: exactly one matching candidate
    Actual: _KeyWidgetFinder:<Found 0 widgets with key
      [<'missed_day_nine_first_fridays'>]: []>
```

Green: `progress_screen_test.dart` — 12/12 including the new case; the
commitment's records credit two first-Friday anchors, the engine's strict walk
labels the skipped November anchor, and the reset card appears while the
persisted streak overstates the engine's series. Applying it zeroes the claim
(card leaves; badge history stays).

Implementation: `ProgressService.evaluateCommitment` composes
`fulfilledAnchorDates` (previously tested but uncalled) into
`CommitmentState.evaluate`; `progressAssemblyProvider` surfaces `reset` only
when the engine reports a gap, the policy is strict, the program is not
complete, and the persisted ordinal still exceeds the engine's series.

### I1 — off-anchor completion date → credit

Red (card affordance removed / old same-day dating):

```
  Expected: exactly one matching candidate
    Actual: _KeyWidgetFinder:<Found 0 widgets with key
      [<'session_checkpoint_when_confession'>]: []
```
```
  Expected: DateTime:<2026-12-02 00:00:00.000>
    Actual: DateTime:<2026-12-05 00:00:00.000>
```

Green: `session_player_provider_test.dart` + `session_player_screen_test.dart`
pass; the off-anchor `confession:2026-12-02` record composes with the
anchor-day `communion:2026-12-05` record to credit the 2026-12-05 anchor. The
Progress card renders `2 anchor days credited` beside the ordinal (pinned in
the C3(b) test).

Library headers corrected: the player documents the additive
`checkpointDates` / `windowedCheckpointItems` / `fatimaPrayer`, and the
progress service header now describes the actual surfaces instead of claiming
one that did not exist.

### I2 — Leave program

Test: enroll → seed progress → Today lists the commitment → tap Leave →
confirm dialog ("removes your enrollment and your saved history") → CTA back,
`enrollmentParamsFor` null, `progressFor` null, Today no longer lists it.
Green in `program_detail_screen_test.dart` (7/7).

### I3 — Luminous switch

Ruling applied: HIDDEN, because the engine's
`rosaryMysteriesFor(DateTime, LiturgicalDayData?)` has no with-luminous
selector — Thursday (and the non-season Sunday override) always resolves the
luminous set, so a switch could only change a stored boolean no consumer
reads. The pin is `expect(find.byKey(Key('toggle_luminous_set')), findsNothing)`
plus the unchanged default `luminousSetEnabled == true`; the persisted field
stays for store compatibility (documented in `app_settings.dart`).

### I4 — 'Meal & night' copy

Settings: subtitle "Lets your night anchors remind you"; warning states the
toggle lets the night-anchor reminders fire (from 8pm) and that Today listing
is decided by enrollments. Onboarding: "Lets your night anchors remind you.
Off by default." Both replace the old claim that the toggle adds items to
Today.

### I5 — Fatima from the pack

Red (old hardcoded copy restored):

```
  Expected: exactly one matching candidate
    Actual: _TextContainingWidgetFinder:<Found 0 widgets with text containing
      save us from the fires
```

Green: the rosary decade card renders `content.fatima-prayer` ("…save us from
the fires of hell…") with `_AttributionLine` reading
`Fatima prayer tradition (1910s) · public-domain`. `_fatimaPrayerText` is
deleted; the state carries the substituted `PrayerText`.

### I6 / I7 — deferral ledger

`sancta_via_devotionals/README.md` gains a "Deferred content work (ledger)"
section: the lectio readings feature is explicitly deferred (bible_data path
deps kept, no screen reads them), and promises/indulgence notes are deferred
content authoring (the app does not fake text).

## Gates (final)

```
sancta_via_devotional_engine:          flutter test  → 264 passed
sancta_via_devotional_engine_riverpod: flutter test  → 18 passed
sancta_via_devotionals:                flutter test  → 303 passed
                                       flutter analyze → No issues found! (all three)
                                       dart format --set-exit-if-changed → clean (all three)
git status → clean
```

App delta: 296 → 303 (+7: C2 ×2, C3(a) ×1, C3(b) ×1, I1 ×2, I2 ×1).

Note: `sancta_via_devotional_engine/test/content/novena_54_day_test.dart`
carried formatter drift (committed with an older `dart format` style) with no
content change; it was formatted to satisfy the format gate.

## Concerns

1. **Device/build verification is the controller's.** The Android desugaring +
   receivers and the iOS delegate cannot be exercised by unit tests here; the
   debug build and a scheduled-notification smoke test must run out of band.
2. `luminousSetEnabled` remains a stored no-op until the engine grows a
   documented with-luminous selection; the switch stays hidden meanwhile.
3. The commitment missed-day card's copy is the series copy ("A due day was
   missed…"); it is accurate for a lapsed strict commitment but does not name
   the specific skipped anchor date the engine labels.
