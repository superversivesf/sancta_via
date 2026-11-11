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

Crash-recovery ruling (2026-11-11): the original `feature/devotionals-plan2` branch died with the
`~/Repos` deletion; Task-1 deliverables were reconstructed from session logs onto `main` (ed8cf5b).
Ruling (drc): partner authorized building `drc.json` from the pinned `exanx/bible-json` fallback —
73 `DRB-73-Books/*.json` per-book files joined via `joinList` (`drc_file_list.json`, committed);
retired primary (thomas992/catholicbible, HTTP 404) kept in `fallbackUrls` for provenance.
All four snapshots re-fetched and checksum-pinned 2026-11-11 (idempotent rerun verified=4 failed=0).
Ruling (drc, Task 2): the authorized exanx join proved structurally corrupt UPSTREAM (21/73 books
missing tail chapters, 20 books with verse texts at wrong coordinates; xxruyle/Bible-DouayRheims
shares the same corrupted lineage — both carry "Then Booz went up to the gate" at Ruth[2][44]).
Partner authorized scraping drbo.org (Douay-Rheims Challoner text is public domain; drbo.org
robots.txt Allow: /, Disallow: only system dirs, Crawl-delay: 5 — honored at exactly 5s/request,
~1334 chapter pages ≈ 2h background crawl). drc must re-enter the manifest before Task 2 review.

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
- Task 1: fetch tool + snapshots + manifest — done (3fe163c originally; re-fetched and re-pinned after crash recovery; drc resolved via authorized exanx join)
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
Task 2: fix round 1/5 — Important: no cross-process crawl guard (lockfile) — two concurrent fetch_sources instances would double the effective request rate and violate Crawl-delay 5 (fetch_sources.dart:528-623).
Task 2: minor (deferred): manifest Esther-verification provenance typo 01916→19016/01917→19017; dead destructured `overridden` at _drboChapterCountTable call sites (:1077/:1315); dead cacheDir+scrape params in _verifyBookBoundary; dead empty `if (booksRaw is! Map...)` :1095-1097; lowercaset-only residual-entity regex; exanx-era fail message attributing post-crawl drc violations to the corrupt exanx join; --smoke summary counts drc as verified without qualifier; near-duplicate bookNames validators (dev-only tools). Final review triages.
Task 2: fix round 1/5 (1 addressed, 0 open — cross-process crawl lock w/ stale-PID takeover; commits 832f942..56a3f1b)
Task 2: fix round 1 re-review: all findings addressed, no new Critical/Important breakage; new minors (ledgered): truncated header doc bullet ("Every fetched response…"); non-FetchException lock-acquire failures surface as stack trace.
Task 2: operational finding (from crawl, not review): drbo.org drops connections intermittently — HttpException "Connection closed before full header received" at 01004 and again at 01006 on resume; single transient aborts the whole scrape. Fix round 2 dispatched: bounded retry with >=5s spacing + connection handling. Ruling: retry counts as a request (robots delay honored); crawl aborted and paused while the fix lands.
Task 2: fix round 2 (transient retries + per-request clients, commit 22a0b1b) — scoped re-review pending (package review-56a3f1b..22a0b1b.diff).
Ruling (drc, 2026-11-12): partner authorized switching drc to eBible.org engDRA_usfm.zip (Douay-Rheims 1899 American Edition = Challoner revision; PD; 73 books verified clean by independent hunt agent — sha256 fcb5de45...). drbo crawl stopped mid-run (~5 chapters cached; scrape tooling stays committed). Corrupt exanx drc.json to be git-rm'd; book_names drc keys switch to engDRA USFM codes; manifest drc → plain zip kind; expected_structure re-emits 3 translations. Merge-from-fragments ruled out (corrupt fragments have no arbiter).
Task 2: fix round 2 re-review: all addressed, no new Critical/Important breakage. New minors (deferred/ledgered): shared keep-alive client in unreachable _downloadJoined path; header doc overstates final-retry spacing (~2x claim vs actual ~5.05s); exhausted-budget `gave up` path code-verified only.
Task 2: fix round 3 complete: engDRA switch (55d9946) — drc → pinned eBible engDRA USFM zip; exanx drc.json + drc_file_list.json removed; book_names drc keys = engDRA \id codes; expected_structure re-emitted with 3 translations (drc 73/1334/35811); pins verified against engDRA. Scoped re-review pending.
Task 2: fix round 3 re-review: all requirements addressed, independently verified against committed bytes; no new Critical/Important. Minors (deferred): manifest drc fileSize/fetchedAt unstamped (report overstated); stale doc refs (fetch_sources.dart:13 join example, validate_sources.dart:11 CPDV+drb wording); drc referenceVerses pin book labeled 'Revelation' not in drc order ('Revelation of John'); join machinery now consumer-less (Ruling: retained as tooling; docs updated, keep joinShapeViolation test).
Task 2: fix round 4/5 dispatched — fold minors: rename drc pin book to 'Revelation of John' + re-emit manifest; stamp drc fileSize/fetchedAt via --update; fix both stale header docs.
Task 2: fix round 4 re-review: all 4 findings ADDRESSED, no new breakage.
Task 2: complete (commits 884e2c7..f97d64b, review clean after rounds 1-4; deferred minors ledgered above for final review)
Task 3: complete (commits 1317299..a5b2dcf, review clean; deferred minors: dangling library doc comment; unexpected-chapter verses skip content checks; test-3 assertion looser than peers; test-2 fixture book differs from brief's literal parenthetical)
Task 4 Ruling (plan-defect, pre-dispatch — Sirach gaps): engwebc Sirach has footnote-only/composite \v markers (Task-2 heads-up), so built verse keys there are NOT 1..N (e.g. ch 1 lacks the note-only verses 5 and 7 in the best authorities). True verse numbers are the plan's goal, so silent renumbering is forbidden and the 1..N rule as pinned cannot hold universally. Ruling: expected_structure.json gains an optional per-book `verseNumbers` map (decimal-STRING chapter key -> ascending list of true verse ints) for exceptional chapters ONLY; for listed chapters the validator (Task 4 extends Task 3's implementation, test-first) requires verse keys to EQUAL that list exactly and verseCount semantics = list length; for all other chapters the 1..N rule stands unchanged; note-only \v markers (empty after footnote-strip) are omitted ONLY where the manifest list agrees — otherwise empty text fails validation per the brief's no-silent-dropping rule. drc (engDRA) and cpdv verified gap-free, lists expected absent for them. Any chapter not in the manifest and containing a gap must fail validation (implementer enumerates the exact exception list from the engwebc zip and records it in the report).
Task 4: complete (commits 92a542c..2b37a2b, review clean — Approved; deferred minors: parser StateError vs contextual catch; unreachable duplicate guard in validate_sources; cpdv verse-key strictness asymmetry; misleading test name 'true ints everywhere'; tautological expect; CWD-relative asset paths)
Task 4 Ruling (load-bearing carry-forward for Task 5): Bible.fromJson mislabels the rebuilt drc asset (name 'Douay-Rheims 1899 American Edition (Challoner)' / abbreviation 'DRA' unrecognized → BibleTranslation.cpdv enum) — the Task 5 converter consumes these JSONs, so Task 5's dispatch MUST include the loader fix (recognize DRA/name) with a test, before regenerating bibles.db; otherwise the shipped drc rows would carry cpdv's translation id.
