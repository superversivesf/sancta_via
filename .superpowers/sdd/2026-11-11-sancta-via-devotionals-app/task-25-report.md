# Task 25 Report — Integration hardening + release hygiene

Status: **COMPLETE** — committed on `main`, NOT pushed.

Commit: `chore: integration pass, docs, and release hygiene` (single commit; the
hash is in the task dispatch summary because a report cannot name the commit
that contains it without a second commit).

## What shipped

### 1. T24 carry-forwards (all five)

1. **Program-detail anchor row renders every clock.** `_scheduleRows` no longer
   reads `detail.pack.schedule` (the first schedule) for a time-of-day pack: a
   new `_anchorRows` helper renders ONE row — `Every day at 06:00, 12:00,
   18:00` — and dedupes the season variants by `variantId` (all three Angelus
   specs carry the same `regina_caeli`, so a per-spec expansion would also
   recreate the ledgered duplicate-`ValueKey` seam). The About paragraph
   (`_describeSchedule`) now names the same full clock list instead of the
   first schedule's `06:00` half-truth. Pin updated:
   `test/screens/program_detail_screen_test.dart` now asserts the exact
   `Every day at 06:00, 12:00, 18:00` row, the full About sentence, and the
   single `regina_caeli` row.
2. **Duplicate configured Angelus times.** Chosen fix = the **settings-screen
   guard** (the smaller safe change): each Angelus time row now receives the
   other two Angelus times, and a pick matching one is REFUSED with a visible
   SnackBar (`anchor_time_duplicate`) — nothing persists and no notification
   refresh fires. This leaves Task 17's pinned
   `<packId>:anchor:<date>T<HH:mm>` id scheme untouched (the alternative —
   adding the authored hour to the id — would have rewritten dozens of pinned
   ids across Task 18). New widget test:
   `a duplicate Angelus anchor time is refused — settings unchanged, no
   refresh, explicit reason` (picks 6:00 PM from the noon row, whose 12:00 PM
   initial period makes `06:00` mean 18:00, colliding with the evening row).
   Residue: a store already containing duplicates (possible only in a
   pre-release build) is not rewritten; the picker prevents re-creating it.
3. **Stale invariant line.** `notification_service.dart:63-65` now states the
   three-anchor reality (06:00/12:00/18:00 since Task 24), says the planner
   maps each authored spec, and names the settings guard against id collisions.
4. **Wrapper-copy CI pin.** New
   `sancta_via_devotional_engine_riverpod/test/embedded_packs_test.dart`
   reads every engine fixture from disk and requires
   `embeddedPackJson` to be byte-for-byte identical, in sorted filename order;
   a second test names the Angelus' 6/12/18 hours explicitly. This closes the
   one previously unpinned link in the fixture → wrapper-embed → app-asset
   chain (the app asset copy was already pinned by Task 6's test).
5. **Stale `today_providers.dart` sentence.** The commitments-section doc no
   longer claims an anchor pack "never appears twice" (meaningless since the
   Angelus appears three times in the anchor sections); it now says each
   time-of-day spec contributes its own anchor item and the pack never also
   joins the due list.

### 2. Integration test — `test/integration/today_full_day_test.dart`

Frozen **2026-12-05**, real providers over an isolated in-memory FFI store:

- content pipeline seeds the real 33-pack catalog once (`contentLoadedProvider`);
- `EnrollmentService` enrolls **Five First Saturdays** (as-is) and the
  **54-Day Rosary Novena** (`startDate: 2026-11-10`, `restartPolicy:
  permissive`), plus the Angelus and Hour of Mercy anchor packs;
- **one** `todayAssemblyProvider` read and **one** real
  `notificationRefreshProvider` pass (Task 18's service; only the platform
  plugin is faked);
- asserts Today's morning/noon/evening anchors (6:00 / 12:00+15:00 / 18:00),
  both due commitments (`ordinal 1`; novena day 26), and the coming feasts
  (`Immaculate Conception`);
- asserts the `notification_index` rows: 60 (the iOS cap), all `scheduled`,
  the plugin received all 60 writes, and the zoned `fire_at` values carry the
  user's local wall clock — `angelus:anchor:2026-12-05T06:00` →
  `2026-12-05T06:00:00.000-0500`, likewise 12:00/18:00, the mercy 15:00, and
  both 07:00 session reminders with the pack's deep link. Every anchor row's
  stored local clock is checked against its id;
- **full app tree**: `SanctaViaDevotionalsApp` (production root:
  `MaterialApp.router`, onboarding gate, nav shell) is pumped over the same
  container and renders all six Today sections, the three Angelus tiles, the
  mercy tile, both commitments, and the feast tile.

**Depth choice**: the full widget tree was kept (the brief's preferred depth),
not only the provider chain, because the production root's extra work is the
tap listener plus the app-open refresh — and the latter's future was already
resolved once through the real provider, so the widget's read is the cached
completed future (no second plan). The only seams are the clock and the
notification plugin adapter.

**DST note**: 2026-12-05 + the 60-day horizon ends in early February, entirely
inside EST, so this test pins the integration seam (local clock + `-0500`
offset on every row) and deliberately does not duplicate the planner's own
spring-forward pin (`notification_planner_test.dart`'s 2027-03-14 case).

### 3. Init-order audit (`lib/main.dart`)

Verified and documented at the top of the file. The effective dependency order
is **db → content → notifications**: `notificationRefreshProvider` awaits
`contentLoadedProvider`, which opens the database and seeds the catalog before
the service initializes and the planner reads packs/enrollments/progress. The
**router** is the one step constructed early (`main` must pass it to
`MaterialApp.router`), and that is safe by construction — it consumes no
database, content, notification, or repository state; its only input is the
persisted onboarding flag.

Deliberate non-adjustment: moving notification initialization ahead of
`runApp` would initialize before a tap listener exists, and the cold-start
launch payload is emitted from `initialize` with no buffering (Task 18's pinned
contract) — the tap would be dropped. The harmless config-ordering inversion is
kept instead.

### 4. Docs and Makefile

- `sancta_via_devotionals/README.md` rewritten around the real workflow:
  `melos bootstrap`, run/build/test/analyze/format, the three content sources
  (engine fixtures, app-authored packs, imported prayers), the regeneration
  order (fixture → wrapper embed → app asset copy → tests), the launch content
  pipeline (sha256 content version, one-shot re-seed, enrollment re-derivation),
  startup order, and the package map.
- `Makefile`: help now lists every target, and three accurate content targets
  were added — `import-prayers`, `sync-engine-packs` (the eight engine-fixture
  files only), and `embed-packs` (runs the wrapper tool). All pre-existing
  targets verified against the actual scripts/artifacts; `make help` and
  dry-runs pass.

### 5. Gates

| Package | Suite | Count |
| --- | --- | --- |
| `sancta_via_devotional_engine` | `dart test` | **264 / 264** |
| `sancta_via_devotional_engine_riverpod` | `flutter test` | **18 / 18** (16 baseline + 2 new pins) |
| `sancta_via_devotionals` | `flutter test` | **296 / 296** (294 baseline + settings guard + integration) |

- `flutter analyze` / `dart analyze`: **0 issues** in all three Plan-2 packages
  (engine, wrapper, app).
- Workspace-wide `dart run melos exec -- flutter analyze .`: the three Plan-2
  packages are clean; the command reports **pre-existing** findings in seven
  unrelated packages (`sancta_via_shared_ui` 55 issues, plus
  `bible_data_riverpod`, `liturgical_calendar_app`, `bible_reading_app`,
  `confession_companion`, `novena_companion`,
  `sancta_via_liturgical_calendar_riverpod`). No file in those packages was
  touched by this task; **zero new issues**.
- `dart format --set-exit-if-changed`: clean on every touched Dart file.
- `git status`: clean after the commit.

## Decisions / notes

- **Duplicate guard vs planner id**: chose the settings-screen rejection (see
  above) to keep the pinned id contract; documented at the guard, in the
  settings screen header, and in the notification service header.
- **Version bump not performed**: the brief listed `pubspec.yaml` version +
  `tool/update_build_info.sh`; the app is still pre-release at `1.0.0+1`, and
  the actual script lives at `scripts/update_build_info.sh` (referenced
  correctly by the Makefile). No release-number change was in this task's
  instruction set.
- **Program-detail variant dedupe** also closes the T24 duplicate-`ValueKey`
  hazard for the multi-anchor pack (a side benefit of the row fix).

## Concerns

- Workspace `melos analyze` is not zero because of the seven unrelated,
  pre-existing packages above; the Plan-2 gates are zero.
- The duplicate guard prevents new collisions at the picker but does not
  rewrite an already-colliding persisted store (pre-release only).
- The 60-slot iOS cap now spends three Angelus anchors/day (≈20 days of
  horizon) — Task 17's rotation semantics are unchanged, but the density is a
  known polish item (ledgered by Task 24).
