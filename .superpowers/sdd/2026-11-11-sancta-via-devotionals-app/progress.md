# SDD ledger — plan: docs/superpowers/plans/2026-11-11-sancta-via-devotionals-app.md

Branch: feature/devotionals-plan2 (from main a30f92b; working in place per established user pattern)
Workspace: /Users/jason/Repos/sancta_via/.superpowers/sdd/2026-11-11-sancta-via-devotionals-app
Model policy (user-directed 2026-11-11): implementers + reviewers restricted to ollama/glm-5.3-flash:cloud, ollama/deepseek-v4.1-flash:cloud, ollama/minimax-m3.1-flash:cloud. Assign deepseek-v4.1-flash to the higher-integration tasks (repository/planner/controllers) and its reviews; rotate glm-5.3-flash + minimax-m3.1-flash for mechanical/content tasks. Final review: deepseek-v4.1-flash.

## Preflight scan (2026-11-11)

| Pair | Shares | Finding | Ruling |
|---|---|---|---|
| T1→T2-25 | app scaffold | every app task adds to T1's skeleton | sequential by design; T1 pins package name + router growth |
| T2 → — | engine package only | typed overload delegates to string API; Plan-1 tests untouched | no conflict |
| T3→T10,T13,T17,T19,T20 | DevotionsAppSettings fields | exact field names pinned in T3 Interfaces | consumers use those names verbatim |
| T4→T5→T6→T12 | DevotionalsDatabase / SqliteProgramRepository | T5 declares seedPacks/enrollmentParamsFor/unenroll; later tasks consume exactly those | no conflict |
| T7→T10,T11 | SubstitutionService.requireFullySubstituted | single leakage gate | pinned |
| T8→T9 | creditCheckpoints map shape | Map<String,DateTime> item→completion date; per-anchor lock | consumed by T9 |
| T9→T10,T16 | ProgressService.completeSession | incomplete-state contract (checkpoint gate) | player + progress tab honor it |
| T10→T11 | SessionPlayerState | fields pinned in T10 Interfaces | T11 renders those fields |
| T12→T13,T24 | TodayAssembly/TodayItem | T24 adds 3 angelus anchors; wrapper providers already iterate pack.schedules list | no conflict |
| T17→T18 | PlannedNotification shape | pure service → wiring | no conflict |
| T21,T22,T23 | assets/content/packs/ | distinct pack files per task; shared surface = T6 manifest glob | sequential; no conflict |
| T24 | angelus.json ×3 copies (engine fixture → wrapper embed → app assets) | propagation explicitly stepped in T24 | executes after T21-23 |
| T15→T19 | EnrollmentService | T19 onboarding claims reuse enroll + progress writes | no conflict |

Scan: clean — no test-that-asserts-nothing or duplication mandates found; every task reuses the engine rather than re-implementing it.

## Task log

### Task 1 — DONE (repaired post-crash)
Original commit 5df1742 was lost with the 2026-11-11 `~/Repos` deletion; the ed8cf5b recovery
reconstructed only lib/pubspec/Makefile/README/test. Repaired on 2026-11-11: pubspec path-dep keys
for the bible packages restored to the DECLARED names (`bible_data`/`bible_data_riverpod`, the same
fix as original deviation #1 — the recovery had reintroduced the directory-name bug); analysis
options/.gitignore/scripts/update_build_info.sh copied verbatim from prayer_companion; six platform
dirs regenerated via `flutter create` (org/bundle IDs match the original tool output); template
`widget_test.dart` deleted again; pubspec_overrides.yaml (already on disk, melos-shaped) + force-added
pubspec.lock committed. Gates: analyze clean, smoke test green. Next: Task 2.
Environment re-ruled (2026-11-12): the feature/devotionals-plan2 branch died with the 2026-11-11 ~/Repos deletion; Task-1 deliverables reconstructed onto main (ed8cf5b) and repaired (e760dec: platform dirs, pubspec keys, overrides; verified pub get + tests). Work-in-place on main for the remainder (house ruling since bible-data). Partner directives: commit early, push often, expect interruptions — controller stops and waits if a disconnection blocks a subagent/report. Standing model policy unchanged (all subagents flash-tier; deepseek on integration tasks + their reviews; rotate glm/minimax).
Task 2: starting.
Task 2: review = Approved WITH format fix: dart format test/progress/missed_day_test.dart (regression introduced by this diff; 1bc0df4 base was clean). Minors (deferred): doc clauses on evaluateTyped semantics; optional inlining.
Task 2: complete (commits 1bc0df4..e2001ca, review clean after format fix round; minors deferred: doc clauses)
Task 3: complete (commits d71b2d5..2d09e5f after fix round 1, review clean: authoritative-base restore overlay + non-clobber sync test + doc fixes; 18/18; minors deferred: _mergeSettings raced-load stale-base fallback (one-line follow-up if ledger wants it), on-disk base snapshot not self-healing, off-default merge limitation doc sentence, silent catches till AppLogger (T6), Map<String,dynamic> vs Map cast nit, setMissedDayDefaultPolicy unguarded string, import grouping nit, settle() helper robustness, strengthening test suggestions)
