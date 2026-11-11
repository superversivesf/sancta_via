# SDD ledger — plan: docs/superpowers/plans/2026-11-11-saint-companion.md

## Environment
- Worktree: /Users/jason/.local/share/opencode/worktree/7a164e/feature/saint-companion, branch feature/saint-companion (was detached HEAD at 82bcb49; branch created)
- Flutter 3.47.9 stable
- Models: implementers glm-5.3-flash:cloud; reviewers deepseek-v4.1-flash / minimax-m3.1-flash (user constraint: flash-tier only)
- Baseline: no existing packages touched by this plan; full monorepo test baseline not run (record: 5 existing apps verified only via Task 17 melos run). Existing uncommitted bible-data files remain on the MAIN checkout, not here — worktree is clean.

## Pre-flight scan (plan: docs/superpowers/plans/2026-11-11-saint-companion.md)

| Pair/Task | Produces → Consumes | Finding | Ruling |
|---|---|---|---|
| 1 ↔ 5/6/7 | pubspec assets block grows additively | none | — |
| 2 → 7 | Saint.fromDbRow w/ patronages+sources params | names match | — |
| 3 → 5/7 | normalizeSearchText used build-side and query-side | same fn | — |
| 4 → 5 | manifest.saintCount consumed by build + integration test | keys match | — |
| 5 → 7 | createSaintsDatabase reused in test fixture | names match | — |
| 7 → 10 | repository method names vs providers | names match | — |
| 8 → 11–16 | routes reference screens | stubs created in Task 8 | — |
| 9 → 13/15/16 | saintAppSettingsProvider | names match | — |
| 10 → 14 | saintSearchProvider record key (String, SaintCategory?) | matches | — |
| Task 4 | `--source ../saint-for-that` default | worktree is outside /Users/jason/Repos so relative default would resolve wrong | Ruling: Task 4 dispatch passes absolute `/Users/jason/Repos/saint-for-that` as --source |
| Task 14 | PatronageChip pushes '/search' with extra; Task 8 routes pass no extra | plan gap: route must forward state.extra into SearchScreen | Ruling: Task 14 modifies lib/config/routes.dart to pass `s.extra` (String only) as SearchScreen(initialQuery) |
| Task 5 | integration test asserts featured >= 1 while "expected 6" | soft assertion is intentional (data-dependent) | fine as written |
| Task 11 | home retry affordance Key('load_error_state') | covered in plan text | — |

No contradictions with Global Constraints found. Spec present: docs/superpowers/specs/2026-11-11-saint-companion-design.md.

## Progress

Crash-recovery note (2026-11-11): the `feature/saint-companion` worktree branch died with the
`~/Repos` deletion; Task 1 (scaffold, 6251111) and Task 2 (models, 873c46d) deliverables were
reconstructed from session logs onto `main` (ed8cf5b). Repaired: barrel `saint_data.dart` re-exports
the three model files (recovery had dropped them — 28-model suite failed to load), `assets/`
directory restored (pubspec declares it). Gates: analyze clean, 29/29 tests pass. Next: Task 3.
Environment re-ruled (2026-11-12): the opencode worktree + feature/saint-companion branch died with the 2026-11-11 ~/Repos deletion; Tasks 1-2 deliverables were reconstructed onto main (ed8cf5b) and their repairs verified (db056bc: barrel exports + assets/). Partner chose work-in-place on main for the bible-data plan and wants regular commits + pushes; the same applies here. Standing model policy stands (glm-5.3-flash implementers; deepseek/minimax reviewers per partner flash-tier constraint).
Task 1: complete (commit 6251111 originally; reconstructed + repaired in main db056bc, review clean 2026-11-11)
Task 2: complete (commit 873c46d originally; reconstructed + repaired in main db056bc, review clean 2026-11-11, 29/29 tests)
Task 3 Ruling (plan-defect): Dart wraps DateTime(2025, 2, 29) -> March 1 (verified live), so the brief's test `feastKeyForDate(DateTime(2025, 2, 29)) == '02-28'` is unimplementable as written. Amended: date-side tests are `DateTime(2025, 2, 28) == '02-28'` (non-leap), `DateTime(2028, 2, 29) == '02-29'` (leap), zero-padding; the Feb-29 saints -> Feb-28 fallback is implemented at the FEAST LOOKUP side (Task 7 repo query: on '02-28' in a non-leap year with no matches, also match '02-29' rows). Carry this ruling into Task 7's dispatch.
Task 3: complete (commits bfa26ff..af4e37a, review clean — Approved; deferred minors: fold-table doc overclaims Ext-A coverage; ligature policy Ã¦â†’ae/Å“â†’oe untested; tab-stripping behavior untested; century-boundary leap tests missing; tests import src/ not barrel; fold table decimal-code audibility; package lacks analysis_options.yaml (whole-branch note))
Task 4: complete (commits 2635538..012eb67, review clean — Approved with independent byte-level verification vs sibling repo; deferred minors: sourceRepo normalization vs raw --source string; non-atomic multi-file write; no _extractNeedSynonyms golden test; mutable _keyLineCount top-level state; lenient arg parsing; 3.8MB pretty-printed snapshot; sha256OfString/Map<String,dynamic> style departures; barrel lacks manifest.dart export)
Task 5: fix round 1/5 — Important: tools/build_saints_db.dart:165 compares manifest.saintCount against records.length (drafts included) instead of the records-to-insert count; one draft record would hard-fail the build (spec design.md:98 documents draft exclusion). Summary text at :293-296 must follow.
Task 5: minor (deferred): spec §5.2(3) audit direction (data needs missing from synonyms) not implemented — tool warns on inverse set; category validation via enum only, categories.json not asserted equal; empty image {} bypasses image validation (model would ship unattributed thumb); integration test gaps (fts row count == saints count, thumbs convention, index presence); schema test containsAll + missing sqfliteFfiInit; Directory.current reliance; tool validation logic untestable monolith; need_synonyms only-indexed on synonym; regeneration non-deterministic across host sqlite versions; schema-test fixture uses stale spec thumbs prefix.
Task 5: complete (commits 81489f5..d1edced, review clean after fix round 1; FTS4 workaround ruling: pubspec hooks sqlite3 source:system is dev-host only, apps unaffected, README prereq + Task 7 define owed; Task 5 minors ledgered above)
Task 6: review = Needs fixes. Critical: 429 throttling treated as permanent failure with immediate retry and no pacing — live full-run evidence: 188 ledger entries all HTTP 429 vs 64 thumbs in ~1 min; controller KILLED the background run at 85 thumbs (politeness). Fix round 1 dispatched: inter-request pacing + 429/5xx backoff (Retry-After honored) before the retry, 429/5xx kept OUT of the permanent failure ledger. Important (in-loop): vacuous test assertion thumb_url_test.dart:96-101 (expect literal == same literal; wraps nothing). Minors (deferred): unguarded casts at :217/:228/:414 outside FetchSaintImagesException path; EXIF retention in output JPEGs; width-boundary + query-string tests missing; stale .part sweep; on Object catches swallow programming Errors as data failures; pubspec assets non-recursive confirmed (Step 6 needed later).
Task 6: fix round 1 re-review: both findings ADDRESSED, no Critical/Important breakage. New minors (deferred, but one load-bearing): poison pill — ImageException/FileSystemException escaping the per-image loop aborts the whole crawl and re-aborts every re-run (one-line remedy: convert non-fetch exceptions into FetchFailedException + ledger + continue); exhaustion paths skip trailing pacing gap (comment overstates); deferral doesn't purge stale ledger entries for same slug; pacing-test doc strings + elapsed bound cosmetic. Ruling: poison-pill fix + stale-ledger purge routed as fix round 2 before the controller's full run (load-bearing for that run).
Task 6: fix round 2 dispatched.
Task 6: fix round 2 re-review: both fixes ADDRESSED (poison pill ledger+continue with layer split; stale-ledger purge persists to disk), no new breakage; minors deferred (writeFailures infra-failure posture; post-run ledger skim owed before numbered final commit).
Task 6: full thumbnail run launched by controller (1,358 targets; 85 thumbs skip-existing; pacing 250ms + 2/4/8s ladder; deferrals self-heal on re-run).
Task 6: complete (commits 6ae89b4..ee7f696 after fix rounds 1-2, review clean; 1,439/1,443 thumbs, 4 genuine upstream 404s ledgered, idempotency proven, 85/85 tests)
Task 6 carry-forward for Task 7+ (runtime): 4 saints (casimir, isaac-the-syrian, moses-the-black, perpetuus) have image != null upstream with no thumb file — the app detail/lists must fall back gracefully when the thumbAsset file is missing (errorBuilder / existence check); flagged in task-6-report for next tasks.
Task 7: review = Needs fixes. Important 1: getSaintsForNeed expands synonyms only upward (synonym=input -> canonical need); spec §7 requires both directions (WHERE synonym = ? UNION WHERE need = ?) — shipped-DB losses (priests misses 18 'fathers' saints etc.); fix = bidirectional union + fixture saint with synonym-shaped patronage need. Important 2: query-side normalizeSearchText applied to inputs compared against RAW stored need/synonym text — 'day-laborers' (canonical key from getNeedsForCategory) normalizes to 'daylaborers' and matches nothing; multi-word synonyms ('cross-country skiing') unreachable. Fix = compare raw AND normalized forms in getSaintsForNeed/_candidateNeeds (+ assert categories-json/enum alignment is a Task-5 deferred minor) + committed-asset invariant test (every need from getNeedsForCategory must yield non-empty getSaintsForNeed). Minors (deferred): undeclared meta dep; double-quoted string at :213; operator-mangling test weaker than claim (fixture-only equality) — pin unquoted buildFtsTerms form for Tasks 8-16 dispatch; unbounded-tier hydration plan-shaped; loader doc overclaims isolate safety; onCreate fallback untested end-to-end; _candidateNeeds phrase lookup extra-beyond-brief; rootBundle default asset key = app-integration trap (packages/saint_data/assets/saints.db) for Tasks 11/13; stale barrel doc; report doc nits; getBySlug sources=[] (schema-authoritative; Tasks 8-16 must not expect sources).
Task 7: fix round 1 dispatched.
