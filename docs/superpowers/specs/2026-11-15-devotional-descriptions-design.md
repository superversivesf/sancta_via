# Devotional Descriptions — Short Design

**Date:** 2026-11-15
**Status:** Proposed — awaiting approval
**Parent:** `2026-11-09-devotionals-app-design.md`, Plan 2 / onboarding (`lib/screens/onboarding/onboarding_screen.dart`)
**Scope:** Small change — optional content field + onboarding UI

---

## Intent & Why

Onboarding's "Your daily anchors" step lists routine-family packs as bare toggles (`SwitchListTile` with title only, e.g. "Franciscan Crown"). Users don't know what each option is or what it costs them in time, so they skip or guess. Intent: give each devotional a one-sentence human description at the decision point so users can choose confidently, without clutter or a second tap.

Primary surface: onboarding routine picker. Secondary (out-of-scope for this pass, but enabled by the same data): Practice catalog and program detail.

## Goals

- Every pack that appears in onboarding shows a subtitle: what it is + when + ~duration.
- Existing packs without description still render (no breakage).
- One authoring place — add `description` to a pack JSON and it appears everywhere we choose to wire it.

## Non-Goals / Anti-Goals

- Full editorial copy or history per devotion (that belongs in program detail's "About" later).
- Replacing the derived schedule sentence in program detail (`_describeSchedule`) — that stays.
- Filtering/search by description.

## Constraints

- Must follow existing pack JSON → `ContentPack` → `contentLoadedProvider` pipeline (Task 6 content version / migration must fire on pack edits).
- `ContentPack.fromJson` is accumulating validation — new field must be optional, empty-string-treated-as-absent.
- Keep `analysis_options.yaml` (relative imports, single quotes) and existing widget style (`const` ctors, `TodaySectionCard`).

## Approaches Considered

**A — Subtitle under title (chosen).** Add optional `description` to `ContentPack` (`String?`), populate ~30 pack JSONs, render as `SwitchListTile.subtitle: Text(pack.description)` in `onboarding_screen.dart:808`. Always visible, zero interaction cost, most accessible in an onboarding decision list.

**B — ⓘ icon → dialog/bottom sheet.** Info button per row opens `showDialog`/`showModalBottomSheet` with longer text. Keeps list clean but hides context — users don't tap ⓘ on every row to decide, so it doesn't solve "I don't know what they all are" at a glance.

**C — Expandable tile.** Tap row to expand description in-place. Non-standard for `SwitchListTile`, risks accidental enroll on tap-to-expand.

**Pick: A**, because onboarding is a scan-and-decide list. B remains a clean progressive enhancement later (longer "origin" text from the same field or a new `longDescription`) without data-shape change — noted as follow-up, not this pass.

## What the Change Touches

1. **Engine model** `sancta_via_devotional_engine/lib/src/models/content_pack.dart` — add `final String? description`, parse `json['description']` when string, include in `toJson`; validation: optional, empty/absent → null.
2. **Pack content** `sancta_via_devotionals/assets/content/packs/*.json` — author one-line description per pack (~30, engine-fixture packs are byte-pinned so update the engine fixture source of truth + re-copy to app assets with the pin test `content_app_asset_pin_test.dart` in mind; routine/app-authored packs edited in place).
3. **Onboarding UI** `sancta_via_devotionals/lib/screens/onboarding/onboarding_screen.dart:808` — `subtitle: description != null ? Text(description) : null`, styled via `bodySmall` + `onSurfaceVariant` matching existing subtitle.
4. **Tests** — engine `content_pack_test.dart` round-trip, devotional `content_app_asset_pin_test` expectations, onboarding widget test for subtitle.

Left to builder: exact wording of each description (builder drafts, owner approves), line-length policy for subtitle wrapping, whether to also wire Practice catalog subtitle in the same PR (recommend: onboard only, follow-up PR for Practice).

## Open Decisions (owner to confirm)

- Are you happy for me to draft the ~30 one-liners (what / when / ~duration) for you to edit in review, rather than you authoring them?
- Onboarding-only this PR, or also Practice catalog `ListTile.subtitle` in the same pass?

## Approval

Reply "approved" to proceed to plan. Any correction above is approval with that change.
