# Consult Report: Release-Readiness Cross-Check (pi + claude + qwen)

**Date:** 2026-11-17 · **Panel:** pi (glm-5.3-flash), claude (minimax-m3.1-flash), qwen (deepseek-v4.1-flash)
**Method:** 3 agents, distinct focus angles (store-submission completeness / repo config correctness / F-Droid+Izzy policy), Round-1 findings cross-critiqued in Round 2. Raw reports: `/tmp/consult_{pi,claude,qwen}.md` + `/tmp/consult_round2_{pi,claude,qwen}.md`.
**Branch audited:** `release-readiness` @ `d7f7595` (through `36d867d` for the devotionals fix).

**Verdict:** the completed Wave-1/2 work is real but incomplete; the consult surfaced **8 items the plan missed** — one launch-crash defect (fixed mid-consult), a silent-debug-signing trap, cider erasing build numbers, a fastlane pipeline that cannot work as written, missing per-app LICENSEs, Apple field-limit violations, R8/proguard risk, and Android 11+ dead links.

## T-1 Fixed during the consult ✅

1. **devotionals launch crash** — package/namespace changed but `MainActivity.kt` kept the old `net.sanctavia.*` package; with R8 on, the unreachable class was **shrunk out of the AAB** (builds clean, crashes at launch). Fixed (`36d867d`), proven by rebuild + dex.

## BLOCKING (before any first submission)

| # | Finding | Fix |
|---|---|---|
| 2 | **Debug-signing fallback**: no keystore exists yet (Task 3 Step 5, Jason) → every `--release` build silently signs with the debug key. Izzy publishes whatever key; Play upgrade path breaks later | Generate keystores + `key.properties` (one command, Jason); make gradle **fail** without `key.properties` with an opt-out flag; post-build `apksigner verify` non-debug check |
| 3 | **cider erases `+N`** (verified in cider 0.2.8 source): every documented release flow ends with `versionCode=1` → Play rejects 2nd upload | Run `melos run version:bump:build` **after** cider bumps (never before); wire into `build-release.sh`; add `AGENTS.md` correction; optional `cider --keep-build` |
| 4 | **fastlane pipeline non-functional** (5 defects, all verified against fastlane 2.241.2 source): lanes run with cwd `fastlane/` so all relative paths break; `export_method: 'app_store'` invalid (`app-store`); `upload_to_testflight` gets an unusable nil api key (and `issuer_id`/`key_id` aren't pilot options at all); no `package_name`/Appfile for supply; supply misreads `<app>/en-US` trees as locales | One Fastfile rewrite: repo-root paths from `__dir__`, `app-store`, build api key object, per-app `package_name`, explicit `skip_upload_metadata`/`changelogs` (Play text by hand) **or** per-app `metadata_path` |
| 5 | **`build-release.sh` still exits 0 on failure** (loop logs and continues; script has no failure exit); auto-commit gate only watches the **root** pubspec so app version bumps are never committed; its `git add` exit code is unchecked; generated TestFlight script uses retired `altool` | Track failures → `exit 1`; fix pathspec/gate; check `git add` exit; delete the altool block |
| 6 | **Per-app + 3-package LICENSEs missing** (7 apps + `bible_data_riverpod`, `devotional_engine`, `saint_data`) — spec's own verification criterion unmet | Copy MIT LICENSE into all of them |
| 7 | **Apple listing fields violate limits** (verified counts): all 7 subtitles exceed 30 chars; Devotionals keywords 106/100 | Trim before ASC entry |
| 8 | **R8 is ON** (Flutter gradle plugin default; checklist + spec non-goal both wrong) and `proguard-rules.pro` is empty — `flutter_local_notifications` classes are at risk of obfuscation breaking alarm rescheduling | Decide keep-or-off explicitly; add `-keep class com.dexterous.flutterlocalnotifications.** { *; }`; mandatory pre-submission device smoke |
| 9 | **Dead links on Android 11+**: `canLaunchUrl` gating + no `<queries>` ACTION_VIEW/https block in any manifest → Privacy/Support buttons fail silently (privacy link is a store-review element) | Add `<queries>` blocks; fix the novena **placeholder URL** `yourusername.github.io/...` (forked screen — either fix URL or reuse shared_ui screen); update `privacy_policy.html` to list **all 7** apps; settle the one real policy URL (drop GitHub blob URL from listings) |
| 10 | **Izzy requires public release artifacts**: branch unpushed, zero tags, no GitHub Releases; metadata trees not in the shape F-Droid parses (`fastlane/metadata/android/<app>/…` wrong level); old debug-signed APKs in `releases/` must not be reused | Merge→push→tag; create GitHub Release per app (`gh release` in build script or CI); per-app `fastlane/metadata/android/en-US` under each app dir + `images/` (icon 512, featureGraphic, screenshots ≤2:1); commit 4 missing lockfiles |

## IMPORTANT (first submission quality)

11. **Screenshot gaps**: no saints/devotionals Android sets (Task 8); **no iOS iPad sets though all 7 apps target iPad** (`TARGETED_DEVICE_FAMILY = "1,2"`); existing 22 captures are **2.174:1 — over Izzy's 2:1 cap** → recapture/crop.
12. **`ITSAppUsesNonExemptEncryption=false`** missing in all 7 Info.plists (per-upload friction).
13. **`INTERNET` permission declared in 5 apps that never use the network** (and `privacy_policy.html` says "we do not transmit") → delete; also dead `http:` dep in `saint_data`; add `allowBackup=false` + backup rules to **devotionals and saint_companion** (contradicts data-safety "no data leaves the device"); fix `CFBundleName` inconsistency; melos version:bump scripts churn all 15 packages (scope to apps); `default.txt` changelogs + per-app build bumps with changelog stubs.
14. **F-Droid packaging**: no `.fvmrc` Flutter pin; explicit `$$flutter$$` srclib recipe needed (`gradle:` shorthand cannot work — `settings.gradle.kts` requires `flutter.sdk`); `fdroid/METADATA_TEMPLATE.md` (Task 12) still to write; `sqlite3` native-assets hook needs a clean-machine proof (`NetworkBibleLoader`/`http` dead code removal helps the FOSS story).

## YOURS-ONLY (user decisions, Jason)

15. **Kneeling glyph attribution** is still `TODO(jason)` in `THIRD_PARTY_NOTICES.md` — CC BY 4.0 needs author/title/source URL/changes; also add the Crimson Text OFL text file beside the fonts, and bundle the notices into apps.
16. **Saint thumbnails (1,439 files, 43 MB) lack per-file licence metadata** (`attribution: "Wikimedia Commons"` only — author + licence absent). Requires a Commons-API metadata pass + per-saint credit + a decision to keep/replace non-free files. Gates the saints app for F-Droid/Izzy.
17. **APK sizes vs Izzy 30MB cap**: bible 69MB (bibles.db 43MB — one translation per app?), saints 100MB → asset work (drop duplicate `saints.db` kept in `saint_data`, re-encode thumbs to ~128px WebP ≈ 4–6MB, split per ABI).
18. **IzzyOnDroid AI policy**: they reject "vibe-coded apps" — given this codebase is substantially agent-built, decide your transparency posture for the hosting request before filing it.
19. Single-password-for-all-keystores trade-off (acceptable if conscious — record it in release docs).

## Contradiction adjudications (verified)

- cider erases `+N` — claude right (cider source, `1.1.42+2` → `1.1.43`); pi/qwen described downstream symptoms.
- R8 **on** by default — claude right (mapping.txt + obfuscated dex prove it); all three Round-1 reports wrong.
- Novena exact-alarm permission is **load-bearing** (plugin default = exact); don't strip it. pi right.
- Screenshots: 22 PNGs exist for 5 apps (claude's "empty" was a `find -type d` artifact).
- `git add` behavior in `build-release.sh`: stages the root pubspec but **exits 1** — unchecked either way; plus the root-only pathspec.

## Recommended sequence (merged)

1. Keystores + key.properties (Jason) → release-signing hardening (B2).
2. Release-flow fix: bump-build **after** cider, build-release.sh exit-code + commit fix.
3. Fastfile rewrite (5 defects) → proof run on one app once ASC API key exists.
4. Fast small fixes: LICENSE ×10, `<queries>` + privacy-URL cleanup + novena screen, ITSAppUsesNonExemptEncryption, allowBackup ×2, INTERNET removal, http dep drop, proguard keep rule.
5. Screenshots: saints/devotionals Android + iPhone/iPad sets for all 7 (≤2:1 for Izzy).
6. Asset work: saints db dedupe/thumb re-encode, bible translation split, thumbnail licence pass.
7. Merge→push→tag→GitHub Releases → then Izzy hosting requests + fdroiddata MRs (with .fvmrc + YAML drafts).
8. Store consoles: Play listings (12-tester note for personal accounts), ASC listings (trimmed subtitles/keywords), first TestFlight + store submission.
