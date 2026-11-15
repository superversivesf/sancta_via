# Devotional Descriptions Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Each devotional pack shows a one-sentence human description as a subtitle in onboarding's routine picker so users can decide at a glance.

**Architecture:** Add optional `description` to `ContentPack` model + JSON pipeline; author descriptions in pack JSONs (engine-fixture packs via engine source + copy, app packs in place); render via `SwitchListTile.subtitle` in onboarding; no detail/Today change this pass.

**Tech Stack:** Dart/Flutter, `sancta_via_devotional_engine` (engine), `sancta_via_devotionals` (app), Riverpod, `sqflite`.

**Spec:** `docs/superpowers/specs/2026-11-15-devotional-descriptions-design.md`

## Global Constraints

- Analysis: `analysis_options.yaml` — relative imports, single quotes, trailing commas, `dart format .`.
- `ContentPack.fromJson` is single-pass accumulating validation into `ContentValidationException` — new field optional, empty/absent → null, non-string → problem.
- Engine-fixture-origin packs (`_engineFixtureFilenames` in `content_app_asset_pin_test.dart`) must stay byte-identical to `sancta_via_devotional_engine/test/fixtures/packs/` — edit engine source then copy.
- Content version is `sha256(packId:digest)` — any pack byte change triggers re-seed on next launch (no extra migration).
- Existing providers/cache (`loadPacks` id ASC order, `persistedPackVersion`) unchanged.

## Review Focus

- **Missing description:** pack with no `description` key renders title-only (subtitle null) — no crash/empty widget — pinned by Task 2.
- **Empty string:** `description: ""` treated as absent (null), not rendered — pinned by Task 1.
- **Wrong-type description:** `description: 42` adds one `ContentValidationException` problem, pack fails to parse like other bad fields — pinned by Task 1.
- **Round-trip fidelity:** `ContentPack(id,title,family,schedule,session,description:"x").toJson() → fromJson` preserves description; null description omits key — pinned by Task 1.
- **Long subtitle wrapping:** subtitle uses `bodySmall` + wrap, onboarding `ListView` scrolls correctly with two-line subtitles — pinned by Task 3 visual check.

---

## File Structure

```
sancta_via_devotional_engine/
  lib/src/models/content_pack.dart          # add String? description field

sancta_via_devotionals/
  lib/screens/onboarding/onboarding_screen.dart  # subtitle in _routineStep
  assets/content/packs/*.json               # add "description" to 33 packs
  test/screens/onboarding_screen_test.dart  # subtitle cases
```

## Task 1: Engine model — optional description field

**Files:**
- Modify: `sancta_via_devotional_engine/lib/src/models/content_pack.dart`
- Test: `sancta_via_devotional_engine/test/content/pack_loader_test.dart` (extend) or new `sancta_via_devotional_engine/test/models/content_pack_description_test.dart`

**Interfaces:**
- Consumes: `ContentValidationException`, ` ContentPack` existing fields
- Produces: `ContentPack({..., String? description})`, `ContentPack.fromJson` parses optional `description`, `ContentPack.toJson` emits it when non-null

- [ ] **Step 1: Write failing tests in `sancta_via_devotional_engine/test/content/pack_loader_test.dart` (or new file)**

```dart
test('fromJson parses optional description string', () {
  final pack = ContentPack.fromJson(minimalValidJsonWith({"description": "Three daily pauses — 6am, noon, 6pm."}));
  expect(pack.description, "Three daily pauses — 6am, noon, 6pm.");
});
test('fromJson missing/empty description is null', () {
  expect(ContentPack.fromJson(minimalValidJsonWith({})).description, isNull);
  expect(ContentPack.fromJson(minimalValidJsonWith({"description": ""})).description, isNull);
});
test('fromJson non-string description is a validation problem', () {
  expect(() => ContentPack.fromJson(minimalValidJsonWith({"description": 42})),
      throwsA(isA<ContentValidationException>().having((e) => e.problems.join(), 'problems', contains('description'))));
});
test('toJson round-trips description, omits when null', () {
  expect(roundTrip(ContentPack(..., description: "x")).description, "x");
  expect(roundTrip(ContentPack(..., description: null)).toJson(), isNot(contains('description')));
});
```

- [ ] **Step 2: Run tests — expect FAIL (no description field)**

Run: `cd sancta_via_devotional_engine && flutter test test/content/pack_loader_test.dart --name description -v`

Expected: FAIL — `description` getter/param not found.

- [ ] **Step 3: Implement in `lib/src/models/content_pack.dart`**

Add `final String? description;` field after `family`. Constructor: optional named `this.description`. `fromJson`: after family parsing, if `json.containsKey('description')` then `_optionalString(json,'description', problems, 'pack')` with normalization: if result empty (trimmed) → null; else store. Non-string caught by `_optionalString` → problem added. `toJson`: conditional `if (description != null) 'description': description`. Preserve all other fields.

- [ ] **Step 4: Run tests — expect PASS**

Run: `cd sancta_via_devotional_engine && flutter test test/content/pack_loader_test.dart -v`

Expected: PASS; `dart analyze` clean.

- [ ] **Step 5: Commit**

```bash
git add sancta_via_devotional_engine/lib/src/models/content_pack.dart sancta_via_devotional_engine/test/content/pack_loader_test.dart
git commit -m "feat(engine): add optional pack description field

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

---

## Task 2: Author pack descriptions (content)

**Files:**
- Modify (engine source): `sancta_via_devotional_engine/test/fixtures/packs/*.json` for engine-fixture packs (angelus, rosary, mercy_hour, nine_first_fridays, five_first_saturdays, divine_mercy_novena, total_consecration, novena_54_day)
- Modify (app): `sancta_via_devotionals/assets/content/packs/*.json` — copy engine packs + edit all remaining app-authored packs (daily_examen, morning_offering, fixed_prayers_*, meal_night_prayers, lectio_divina, franciscan_crown, holy_wounds, seven_sorrows, st_michael_chaplet, st_anne_chaplet, litany_* ×4, christmas_novena, holy_spirit_pentecost, miraculous_medal, st_joseph, st_jude, perpetual_help, sacred_heart, undoer_of_knots, novena_for_the_dead, etc. — 33 total)
- Test: existing `test/content/routine_packs_test.dart`, `test/content/novena_packs_test.dart`, `test/content/chaplet_litanies_packs_test.dart`, `test/services/content_app_asset_pin_test.dart`

**Interfaces:**
- Consumes: Task 1's `ContentPack.fromJson` description parsing
- Produces: all 33 shipped packs carry `description: "<one sentence — what + when + ~duration>"`

**Description copy rule (builder drafts, owner edits in review):** One sentence, ≤120 chars, pattern: *what it is + anchor time + ~duration*. Examples: `"The Angelus — three daily pauses recalling the Incarnation (6am, noon, 6pm) · ~3 min"`, `"Ignatian review of your day before God · ~7 min (evenings)"`, `"Nine consecutive First Fridays with Communion · monthly anchor"`. Use `—` / `·` separators as elsewhere in the app. Keep theologically neutral voice from existing About text.

- [ ] **Step 1: Add descriptions to 8 engine fixture packs, copy to app**

Edit `sancta_via_devotional_engine/test/fixtures/packs/{angelus,rosary,mercy_hour,nine_first_fridays,five_first_saturdays,divine_mercy_novena,total_consecration,novena_54_day}.json` — insert `"description": "..."` after `title`. Copy each to `sancta_via_devotionals/assets/content/packs/<same>.json` (byte-identical).

- [ ] **Step 2: Add descriptions to remaining 25 app-authored packs**

Edit each `sancta_via_devotionals/assets/content/packs/*.json` that wasn't in step 1 — same insertion.

- [ ] **Step 3: Verify**

Run: `cd sancta_via_devotionals && flutter test test/services/content_app_asset_pin_test.dart test/content/ -v`

Expected: PASS — pin test sees byte-identical engine packs; content tests still pass (they don't forbid extra keys — verify, or update their allow-list).

Run: `cd sancta_via_devotional_engine && flutter test test/content/ -v` — pack loader parses new field.

- [ ] **Step 4: Commit**

```bash
git add sancta_via_devotional_engine/test/fixtures/packs/*.json sancta_via_devotionals/assets/content/packs/*.json
git commit -m "feat(content): add one-line descriptions to devotional packs

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

---

## Task 3: Onboarding UI — render subtitle + tests

**Files:**
- Modify: `sancta_via_devotionals/lib/screens/onboarding/onboarding_screen.dart:807-816`
- Test: `sancta_via_devotionals/test/screens/onboarding_screen_test.dart`

**Interfaces:**
- Consumes: `ContentPack.description` (Task 1), 33 described packs (Task 2), `contentLoadedProvider` → `List<ContentPack>`
- Produces: routine step shows subtitle when description present; null description → no subtitle widget

- [ ] **Step 1: Write failing widget tests**

```dart
testWidgets('routine step shows pack description as subtitle', (t) async {
  await pumpOnboardingToRoutine(t, catalogWithDescription: "Three daily pauses — 6am, noon, 6pm · ~3 min");
  expect(find.text("Three daily pauses — 6am, noon, 6pm · ~3 min"), findsOneWidget);
});
testWidgets('routine step hides subtitle when description is null', (t) async {
  await pumpOnboardingToRoutine(t, catalogWithDescription: null);
  expect(find.byType(SubtitleWidgetOrText), findsNothing); // or find.text(description) == 0
});
```

Use harness's real-chain pattern (in-memory FFI store, wrapper override, `currentDateProvider` Stream.value, SharedPreferences fake).

- [ ] **Step 2: Run tests — expect FAIL**

Run: `cd sancta_via_devotionals && flutter test test/screens/onboarding_screen_test.dart --name "routine.*description" -v`

Expected: FAIL — subtitle not rendered.

- [ ] **Step 3: Implement in `lib/screens/onboarding/onboarding_screen.dart`**

In `_routineStep()` loop over `packs` where `SwitchListTile` is built (around line 808): change to:

```dart
SwitchListTile(
  key: Key('routine_toggle_${pack.id}'),
  value: _routineOn[pack.id] ?? false,
  title: Text(pack.title),
  subtitle: pack.description != null ? Text(pack.description!) : null,
  onChanged: ...
)
```

That's the entire change. If `description` null, `subtitle` is null and tile renders title-only (existing behavior). No new widgets, no icon/button. Keep relative imports, single quotes.

Note: `ContentPack` lives in engine; `sancta_via_devotional_engine` already is a dependency of the app — no pubspec change.

- [ ] **Step 4: Run tests — expect PASS + analyze**

Run: `cd sancta_via_devotionals && flutter test test/screens/onboarding_screen_test.dart -v`

Expected: PASS (new + existing). `dart format . && flutter analyze` clean.

- [ ] **Step 5: Commit**

```bash
git add sancta_via_devotionals/lib/screens/onboarding/onboarding_screen.dart sancta_via_devotionals/test/screens/onboarding_screen_test.dart
git commit -m "feat(devotionals): show pack descriptions in onboarding routine picker

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

---

## Self-Review

**Spec coverage:** Spec's onboarding-only subtitle ✓ (Task 3); content-field + authoring ✓ (Tasks 1–2); existing schedule-derived detail kept ✓ (no task touches it); Practice/Today deferred ✓.

**Step scan:** Each step is one checkable action — test write, run, code, run, commit — no vague lines; code steps name exact file + line and the one reasonable body (field + parse + toJson branch; subtitle ternary).

**Type consistency:** `String? description` field name matches across engine model, JSON key `description`, and `pack.description` in UI — same identifier throughout.

**Review Focus:** Five failure modes (missing, empty, wrong-type, round-trip, wrapping) each assigned to owning task's test — no gap.

**Proportion:** Spec ~40 lines; plan ~120 + code snippets — justified by 33-file content task needing explicit engine-vs-app copy rule to avoid pin-test breakage.
