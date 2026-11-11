# SDD ledger — plan: docs/superpowers/plans/2026-11-11-bible-data-rebuild-and-structured-verses.md

BASE at plan start: 65047cc (branch: feature/devotionals-plan2, work in place per partner choice)
Spec: docs/superpowers/specs/2026-11-11-bible-data-rebuild-and-structured-verses-design.md (committed 97a0517, amended 65047cc)
Workspace: /Users/jason/Repos/sancta_via/.superpowers/sdd/2026-11-11-bible-data-rebuild-and-structured-verses

Model ruling: ALL subagents (implementer + task reviewer + re-reviewer + final review) dispatch on
`ollama/glm-5.3-flash:cloud` — partner constraint caps every model tier at flash. Escalation rounds
4–5 therefore get a FRESH implementer on the same flash model with re-framed context, not a model
bump. If a task truly cannot converge at the cap, surface to the partner.
Ruling: worktree consent — partner chose work-in-place on feature/devotionals-plan2 (Step 0 verified:
normal checkout, clean, non-main branch).

Baseline: sancta_via_bible_data `flutter test` → 8/8 pass. Reading app suite running (will append).
Ruling (T2 vocabulary): Task 2's canonical DB book vocabulary = the cpdv rows of the CURRENT
(broken) bibles.db `books` table, EXCLUDING the 5 ghost books (I Esdras, II Esdras, Laodiceans,
Prayer of Manasses, Additional Psalm) — cross-checked against CPDV-JSON/books.json order. Cost if
wrong: book names drift from normalizer expectations; caught by asset validator + app tests.

## Pre-flight scan

| Pair / task | One produces | Other consumes | Finding / ruling |
|---|---|---|---|
| T1→T4 | manifest.json ids + snapshot files `assets/sources/{engwebc_usfm.zip,cpdv_entire.json,cpdv_books.json,drc.json}` | build_json reads snapshots by fixed name | Clean; ids pinned in both tasks |
| T2→T3/T4 | expected_structure.json (order + chapters + referenceVerses), book_names.json | validator manifest contract + builder mapping | Clean; shapes defined in T2 Interfaces |
| T3→T4/T5 | validateBibleStructure(nested map, manifest) | asset test + DB tool import | Clean; same signature referenced |
| T5→(none) | validate_bible_db.dart reads rebuilt DB | — | Clean |
| T6→T7/T8 | `.verses` on ScriptureContent/OptimizedScriptureContent (nullable-default, factories optional param) | screens read `scripture.verses` | Clean; field name `verses` fixed in both |
| T7/T8 | delete regex parsers; separate test files | — | Clean; no shared file edits |
| T2 self | Step 1 dumps current DB books (includes 5 ghosts) vs Step 2's "73 DB names" | — | Ruling above (exclude ghosts, cross-check books.json) |
| T4 self | Step 6 real-asset test needs T4's build output | same task | Clean (build runs before test in Step 7) |
| All | Global constraints (no runtime deps; artifacts build-only) | — | Clean; archive+crypto are dev-only (T1 commits pubspec) |

Tasks tracked here (todo):
- Task 1: fetch tool + snapshots + manifest — pending
- Task 2: book-name map + expected-structure manifest — pending
- Task 3: structure validator (TDD) — pending
- Task 4: build JSONs + asset tests — pending
- Task 5: rebuild bibles.db + DB validation — pending
- Task 6: structured verses on content objects (TDD) — pending
- Task 7: reading screen true numbers (TDD) — pending
- Task 8: verse-selection grid true numbers (TDD) — pending
- Task 9: full gates + acceptance verification — pending

Minor-findings register (fed to final review):
(none yet)
