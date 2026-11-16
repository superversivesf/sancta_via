# Store-Readiness Overhaul Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the 7 Sancta Via Flutter apps genuinely release-ready (signed, versioned, policy-clean, FOSS-complete) so they can be submitted to Google Play, App Store, IzzyOnDroid, and F-Droid.

**Architecture:** Repo-hygiene waves before any submission: identifiers → build numbers → signing → manifest/FOSS hygiene → tooling/doc fixes → listing assets → verification builds. Console/account work (Apple renewal, site deploy, ASC key, Play service account) stays with Jason and gates Wave 3 verification steps only.

**Tech Stack:** Flutter (3.47.8, Dart SDK ^3.9.2), Gradle Kotlin DSL (Android), Xcode/automatic signing (iOS), melos workspace, cider (X.Y.Z bumps), fastlane (uploads), `flutter_launcher_icons`, shell/dart tooling in `tool/`.

**Spec:** `docs/superpowers/specs/2026-11-17-store-readiness-overhaul-design.md` (read both; the spec records decisions: IDs standardized to `net.superversive.sancta_via.*`, MIT license, per-app keystores at `android/keystores/<app>.jks`, notification intent resolved — bible app strips, novena/devotionals keep).

## Global Constraints

- Bundle IDs (permanent after first submission — never partially apply):
  - `net.superversive.sancta_via.<snake_name>` on Android for ALL 7 apps; on iOS for the 6 existing apps.
  - `devotionals`: Android `net.sanctavia.sancta_via_devotionals` → `net.superversive.sancta_via.devotionals`; iOS `net.sancta-via.sanctaViaDevotionals` → same value as Android.
  - `saint_companion`: iOS `net.superversive.sanctavia.saintCompanion` → `net.superversive.sancta_via.saint_companion`.
- Secrets (`key.properties`, `*.jks`, keystores dirs, `fastlane/.env`) must never be committed; `.gitignore` rules come before keystore generation.
- Versions: `version: X.Y.Z+N` in all 7 app pubspecs; `+N` (build number) increments monotonically, never resets; cider manages only `X.Y.Z`.
- App store answers (data safety / privacy / age rating): free, no ads, no IAP, no analytics, no data collection — for all 7 apps.
- Manifest hygiene: bible app loses all notification receivers/permissions; novena and devotionals keep their notification/alarm declarations.
- License: MIT, repo root + every app/package lacking one; kneeling-glyph CC BY 4.0 attribution in-tree.
- No R8/minification enablement this round; no CI; no translation of listings.
- Style: single quotes, trailing commas (Dart); follow existing file conventions.

## Review Focus

- **Secret commits:** `build-release.sh` auto-commits and per-app flows could stage `key.properties`/`*.jks` — expected behavior: every secret path ignored, `git status --ignored` shows them untracked. Pinned by Task 3 verification.
- **Build-number collision on release:** a release flow that bumps `X.Y.Z` (cider) but leaves `+N` stale → upload rejected as duplicate versionCode. Expected: `xcode build`/release docs state bump-build-then-bump-version order; Task 2 pins `tool/bump_build_numbers.dart` behavior.
- **Notification regression:** stripping bible-app receivers while keeping novena/devotionals — a grep-only "fix" that removes the wrong app's receivers silently breaks reminder features. Expected: bible app has zero notification declarations *and* zero `flutter_local_notifications` references outside `.backup` (deleted); novena/devotionals receivers still compile. Pinned by Task 4 verification.
- **ID drift between platforms for one app:** partial edits (gradle only, pbxproj only) leave mismatches that block store listing creation. Expected: for each of the 7 apps, Android `applicationId` == iOS bundle identifier string. Pinned by Task 1 verification table.
- **Silent IPA-export failures:** `build-release.sh` reporting success on `xcodebuild` failure hides the distribution-cert gap. Expected: non-zero script exit on export failure. Pinned by Task 6 verification.

---

### Task 1: Bundle-ID standardization (2 apps, 4 config sites)

**Files:**
- Modify: `sancta_via_devotionals/android/app/build.gradle.kts` (applicationId line)
- Modify: `sancta_via_devotionals/android/app/src/main/AndroidManifest.xml` (legacy `package=` attr, if present)
- Modify: `sancta_via_devotionals/ios/Runner.xcodeproj/project.pbxproj` (PRODUCT_BUNDLE_IDENTIFIER lines — Debug/Release/Profile)
- Modify: `sancta_via_devotionals/ios/Runner/Base.lproj/…` only if any plist references the ID (none expected)
- Modify: `sancta_via_saint_companion/ios/Runner.xcodeproj/project.pbxproj` (PRODUCT_BUNDLE_IDENTIFIER lines)

**Interfaces:**
- Produces: store-consistent IDs consumed by Task 6 (fastlane/README), Task 10 (metadata), Wave 3 verification builds.

- [ ] **Step 1:** Set devotionals Android `applicationId` and manifest `package=` attr to `net.superversive.sancta_via.devotionals`; set devotionals iOS `PRODUCT_BUNDLE_IDENTIFIER` (all 3 build configs) to `net.superversive.sancta_via.devotionals`.
- [ ] **Step 2:** Set saint_companion iOS `PRODUCT_BUNDLE_IDENTIFIER` (all 3 build configs) to `net.superversive.sancta_via.saint_companion`.
- [ ] **Step 3:** Verify the other 5 apps are already consistent Android↔iOS (they are per audit — confirm, no edits).
- [ ] **Step 4 (verification):** For each app dir, print gradle `applicationId` and pbxproj bundle identifier; assert Android == iOS for all 7. Expected: 7/7 match, values per Global Constraints.
- [ ] **Step 5 (verification):** `flutter analyze` in the two touched apps (config-only change, but catches stale references): expect "No issues found".
- [ ] **Step 6:** Commit: `chore: standardize bundle IDs to net.superversive.sancta_via.*`.

### Task 2: Build numbers (`+N`) on all 7 apps

**Files:**
- Modify: 7 app `pubspec.yaml` `version:` lines (e.g. `version: 1.1.57` → `version: 1.1.57+1`)
- Create: `tool/bump_build_numbers.dart` (workspace-root; increments the `+N` in every `sancta_via_*` app pubspec that has `lib/main.dart`)
- Modify: `melos.yaml` — add `version:bump:build` script running the tool
- Modify: `AGENTS.md` — document release bump order (build number first, then cider X.Y.Z)

**Interfaces:**
- Produces: `melos run version:bump:build` — the single command every future release uses before upload; consumed by Task 6 docs and the Wave 3/4 cadence notes.

- [ ] **Step 1:** Add `+1` to all 7 `version:` lines (initial build numbers all `1`; they only need monotonic growth per app, never global uniqueness).
- [ ] **Step 2:** Write `tool/bump_build_numbers.dart`: walk the 7 app dirs, parse `version: (\d+\.\d+\.\d+)(\+(\d+))?`, rewrite as `X.Y.Z+(N+1)` (missing `+N` → `+1`); print a per-app before→after table; exit non-zero if any pubspec parse fails.
- [ ] **Step 3:** Add melos script `version:bump:build: run: dart run ../../tool/bump_build_numbers.dart` — if melos cwd semantics complicate the relative path, make the melos script a `run` of a tiny `tool/build.sh` wrapper instead (builder's call; the interface stays `melos run version:bump:build`).
- [ ] **Step 4 (verification):** `melos run version:bump:build` in the workspace; expect every pubspec now at `+2`; run once more → `+3`; restore to `+1` (or leave at 2/3 — any monotonic value is valid, builder's choice).
- [ ] **Step 5 (verification):** `flutter analyze` clean for touched Dart; commit: `feat: build numbers (+N) with melos version:bump:build`.

### Task 3: Signing restore (keystore generation + gradle wiring + `.gitignore`)

**Files:**
- Create: `tool/generate_keystores.sh` (generates `android/keystores/<app>.jks` per app via `keytool`; reads passwords from env `SV_KEYSTORE_PASS`, alias = app name)
- Modify: `.gitignore` (root) — add `**/key.properties`, `**/keystores/`, `*.jks`, `*.keystore`
- Modify: all 7 per-app `.gitignore`s lacking those lines (audit: only liturgical_calendar_app has them)
- Modify: `sancta_via_saint_companion/android/app/build.gradle.kts` — replace debug signingConfig with key.properties-conditional release config (pattern from liturgical_calendar_app, in Kotlin DSL)
- Modify: `sancta_via_devotionals/android/app/build.gradle.kts` — same
- Create: `key.properties.template` in both those app `android/` dirs (copy from an app that has one, e.g. `sancta_via_prayer_companion/android/key.properties.template`)
- Create (user-assisted, secrets outside repo): `key.properties` in all 7 app `android/` dirs once keystores exist

**Interfaces:**
- Produces: signed release AABs; `key.properties` shape (`storePassword` / `keyPassword` / `keyAlias` / `storeFile`) matching existing templates and gradle readers; Wave 3 task depends on this being done for all 7.

- [ ] **Step 1:** Add ignore rules to root + per-app `.gitignore`s (before anything else). Verify: `git check-ignore -v sancta_via_prayer_companion/android/key.properties` resolves.
- [ ] **Step 2:** Write `tool/generate_keystores.sh`: loops the 7 app names, `keytool -genkeypair -v -keystore android/keystores/<app>.jks -alias <app> -keyalg RSA -keysize 2048 -validity 10000` with env-provided passwords, skips keystore-if-exists.
- [ ] **Step 3:** Wire KTS signing config into saint_companion + devotionals gradles: load `key.properties` if present → `signingConfigs.release`; `buildTypes.release.signingConfig` = release when properties exist else debug (mirrors the 5 existing apps so local `flutter run --release` keeps working).
- [ ] **Step 4:** Copy `key.properties.template` into the two new apps' `android/` dirs with correct alias values.
- [ ] **Step 5 (user-assisted):** Jason runs `SV_KEYSTORE_PASS=<secret> ./tool/generate_keystores.sh` then copies each template to `key.properties` with the real values. Executor verifies presence of all 7 `key.properties` and 7 `.jks` files (paths only, no contents in log).
- [ ] **Step 6 (verification):** `git status --porcelain` shows zero secret files; `cd sancta_via_saint_companion/android && flutter build appbundle --release` (post-Step-5) exits 0 and `keytool -list -keystore …jks` confirms it's signed with the release alias (fallback: `apksigner verify --print-certs` on release APK).
- [ ] **Step 7:** Commit the non-secret parts: `chore: release signing configs + keystore tooling (secrets gitignored)`.

### Task 4: Manifest & Info.plist hygiene

**Files:**
- Modify: `sancta_via_bible_reading_app/android/app/src/main/AndroidManifest.xml` — remove `RECEIVE_BOOT_COMPLETED`, `VIBRATE`, `USE_EXACT_ALARM`, `SCHEDULE_EXACT_ALARM`, `POST_NOTIFICATIONS` (if present) and the stale notification `<receiver>` blocks (`BootReceiver`/scheduled-notification receivers)
- Delete: `sancta_via_bible_reading_app/lib/services/notification_service.dart.backup`
- Modify: `sancta_via_saint_companion/ios/Runner/Info.plist` — add `LSApplicationCategoryType` = `public.app-category.reference`
- Modify: `sancta_via_devotionals/ios/Runner/Info.plist` — same key
- Verify: `sancta_via_novena_companion/android/…/AndroidManifest.xml` and `sancta_via_devotionals/android/…/AndroidManifest.xml` unchanged (notifications intentional)

**Interfaces:**
- Consumes: Task 1's verified IDs (same files, sequential). Produces: policy-clean manifests consumed by Play data-safety answers (Wave 4 doc).

- [ ] **Step 1:** Strip bible-app stale declarations/receivers; delete the `.backup` file. Confirm no live Dart code references notification classes (audit: plugin commented out of pubspec; `.backup` was the only importer).
- [ ] **Step 2:** Add the category key to the two iOS plists.
- [ ] **Step 3 (verification):** `grep -c 'USE_EXACT_ALARM\|SCHEDULE_EXACT_ALARM\|RECEIVE_BOOT_COMPLETED'` in bible manifest → 0; `grep flutter_local_notifications -r sancta_via_bible_reading_app/lib` → 0 hits outside `.backup` (which is deleted); `flutter analyze` + `flutter test` in bible app → green; novena/devotionals manifests still declare their notification permissions.
- [ ] **Step 4:** Commit: `chore: strip dead notification plumbing from bible app; add iOS category keys`.

### Task 5: FOSS hygiene (LICENSE, attribution, dead dep)

**Files:**
- Create: `LICENSE` (repo root, MIT, copyright holder "Sancta Via contributors" — Jason to confirm byline choice at review)
- Modify/verify: package + app LICENSEs (5 packages have one; confirm they're MIT; if any differs, keep and record in doc, don't relicense silently)
- Create: `THIRD_PARTY_NOTICES.md` (repo root) — kneeling glyph CC BY 4.0 attribution with source link (source recorded per checklist/commit `d77c65a`; if the exact URL isn't recoverable, mark TODO(jason) for the source page rather than invent one)
- Modify: `sancta_via_novena_companion/pubspec.yaml` — remove `google_fonts` dependency
- Refresh: `sancta_via_novena_companion/pubspec.lock` via `flutter pub get`

**Interfaces:**
- Produces: F-Droid-acceptable license/attribution surface consumed by Task 10 metadata (`License: MIT` lines).

- [ ] **Step 1:** Write root `LICENSE` (MIT text) and `THIRD_PARTY_NOTICES.md`; reconcile package LICENSE findings.
- [ ] **Step 2:** Remove `google_fonts` from novena pubspec; `flutter pub get`; confirm no imports in live code (audit: only `theme.dart.backup`).
- [ ] **Step 3:** Optionally delete `sancta_via_novena_companion/lib/config/theme.dart.backup` if it's the only `google_fonts` reference (audit says yes) — otherwise leave and note.
- [ ] **Step 4 (verification):** `grep -r 'google_fonts' sancta_via_novena_companion` → 0 live-code hits (`.backup` gone); `flutter analyze`/`flutter test` in novena → green; root LICENSE parses (`head -2 LICENSE` shows MIT).
- [ ] **Step 5:** Commit: `chore: MIT license + third-party notices; drop dead google_fonts dep`.

### Task 6: Build tooling & docs truth-up

**Files:**
- Modify: `build-release.sh` — check exit codes of `xcodebuild`/IPA-export steps (`set -o pipefail` / explicit `if ! xcodebuild …; then fail "iOS export failed for <app>"`), don't proceed past failures
- Modify: `docs/store-launch-checklist.md` — correct §2 (R8 is OFF, delete the "R8 was turned ON" claim and its smoke-test item), delete the "reset upload key for existing apps" item (nothing was ever published; Task 3 generates fresh keys), update bundle-ID guidance to "resolved — see design doc"
- Modify: `fastlane/README.md` — identifiers table to Task 1 values; note `version:bump:build` order
- Modify: `docs/DISTRIBUTION_GUIDE.md` — mark §1 bundle-ID fix as DONE, delete the stale `.github/workflows/flutter.yml` reference

**Interfaces:**
- Consumes: Tasks 1–5 outcomes. Produces: accurate execution-order checklist that Wave 4 follows.

- [ ] **Step 1:** Fix `build-release.sh` failure handling.
- [ ] **Step 2:** Truth-up the three docs with the edits above (concise; keep them useful, don't rewrite).
- [ ] **Step 3 (verification):** `bash -n build-release.sh` (syntax); grep: "reset upload key" absent from checklist; R8 claim absent; identifiers table matches Task 1 values.
- [ ] **Step 4:** Commit: `docs: truth-up release checklist; fail iOS exports properly in build-release.sh`.

### Task 7: Adaptive icons + Play image assets

**Files:**
- Modify: all 7 app `pubspec.yaml` `flutter_launcher_icons:` blocks — add `adaptive_icon_background: "#FFFFFF"` (verify each app's app-icon background color first and use that), `adaptive_icon_foreground` using a padded source (create `assets/app_icon_foreground.png` = icon scaled to ~66% inside transparent 1024 canvas, via `tool/make_foreground_icons.dart` or sips commands)
- Create: `releases_assets/play/<app>-512.png` and `releases_assets/play/<app>-feature.png` (1024×500, background color + centered icon; generated by the same tool from each `assets/app_icon.png`)
- Regenerate: `flutter pub run flutter_launcher_icons` per app (mipmap refresh)

**Interfaces:**
- Produces: `releases_assets/play/*` consumed by Wave 4 Play listing uploads and Task 10 metadata.

- [ ] **Step 1:** Write the asset generator (pure ImageMagick/sips/dart-image approach — builder's call; no new runtime deps in apps).
- [ ] **Step 2:** Add adaptive-icon keys to the 7 pubspec blocks; run icon generation; verify `mipmap-anydpi-v26/*.xml` appears in each app.
- [ ] **Step 3 (verification):** each app builds (`flutter build apk --debug` on one app is enough to catch manifest merge errors for all — icon XML is app-generic); generated PNGs exist at exact sizes (512, 1024×500).
- [ ] **Step 4:** Commit: `feat: adaptive launcher icons + Play store image assets`.

### Task 8: Screenshots for saints/devotionals

**Files:**
- Create: `screenshots/saint_companion/*.png`, `screenshots/devotionals/*.png` (home + one detail screen, light + dark, matching the existing 5 apps' naming)
- Modify: `docs/store-launch-checklist.md` — add optional note re-capturing the 5 original apps' screenshots if UI changed since (Jason decides at review; not a blocker)

**Interfaces:**
- Produces: `screenshots/` sets consumed by Wave 4 (Play listing upload; `screenshots/` README update if one exists).

- [ ] **Step 1:** Launch each app on an Android emulator (or Jason's device), capture home + detail, save with the existing naming convention. Executor uses `flutter run -d <emulator>` + screenshot tooling; requires an emulator on the machine (verify availability; if none, this step blocks on Jason — flagged task).
- [ ] **Step 2 (verification):** 4+ PNGs per new app dir, dimensions sane (1080×2400-ish), no debug banners.
- [ ] **Step 3:** Commit: `docs: add saints/devotionals screenshots`.

### Task 9: No-op placeholder removal (fold into Task 8 if the emulator path is smooth)

**Files:** none

- [ ] **Step 1:** If Task 8's emulator capture worked inline, delete this task; if it blocked, keep work here for the device/emulator retry.

### Task 10: IzzyOnDroid fastlane metadata + listing copy for the 2 unlisted apps

**Files:**
- Create: `fastlane/metadata/android/<app>/en-US/` for all 7 apps: `title.txt` (short home-screen recognisable), `short_description.txt` (≤80 chars), `full_description.txt`, `changelogs/<firstVersionCode>.txt` (one line)
- Modify: `store_listings.md` — append full listings (subtitle, promo text, keywords, description) for `saint_companion` and `devotionals`, drafted from their pubspec `app_store:` blocks/app descriptions — **flagged for Jason's review before Wave 4**

**Interfaces:**
- Consumes: Task 2's version codes (changelog filenames), Task 1 IDs (app dir ↔ fastlane `APP_NAMES` mapping already matches).
- Produces: metadata consumed by IzzyOnDroid hosting requests and reusable in Play listing UI.

- [ ] **Step 1:** Write the 7 metadata trees (title/short/full/changelogs); keep copy accurate to what each app actually does (source: store_listings.md for 5, pubspec/descriptions for 2).
- [ ] **Step 2:** Extend `store_listings.md` with the 2 new app listings; mark both clearly as draft-for-review.
- [ ] **Step 3 (verification):** char-count checks (`short_description` ≤ 80; `title` ≤ 30); all 7 `changelogs/1.txt` exist.
- [ ] **Step 4:** Commit: `feat(izzy): fastlane metadata for all apps; draft listings for saints/devotionals`.

### Task 11: Wave 3 verification (gated on Jason's Wave 0 console work)

**Files:** none created; verification only. May modify `docs/store-launch-checklist.md` to tick items.

**Interfaces:**
- Consumes: everything above; Jason's ASC API key, Play service-account JSON (via `fastlane/.env`), Apple renewal + distribution certificate.

- [ ] **Step 1 (blocked until Apple renewal + new Distribution cert):** `cd fastlane && bundle exec fastlane asc_key_check` → "API key OK".
- [ ] **Step 2:** `APP_NAME=saint_companion fastlane ship_ios` → TestFlight build appears; Jason installs via TestFlight and smokes the app.
- [ ] **Step 3:** `APP_NAME=saint_companion fastlane ship_android` → draft internal-track release; Jason publishes once via Console UI (first-time rule), installs on device, smokes.
- [ ] **Step 4:** Remaining 6 apps: `ship_android app:<name>` each; `ship_all` for TestFlight.
- [ ] **Step 5:** Update checklist doc ticks; commit: `docs: wave-3 verification results`.

### Task 12: Wave 4 submission support (user-owned, doc-backed)

**Files:**
- Modify: `docs/store-launch-checklist.md` — as items complete (Play listings, data-safety forms, ASC listings, IzzyOnDroid hosting requests, F-Droid metadata MRs)
- Create: `fdroid/METADATA_TEMPLATE.md` (draft YAML blob per app from `docs/DISTRIBUTION_GUIDE.md` §4 with real current versions/tags) to hand-carry into the fdroiddata MRs

- [ ] **Step 1:** Draft the fdroiddata YAML blobs for all 7 apps (versions from pubspec, commit = release tag or HEAD sha to pin, `subdir: sancta_via_<name>`, `gradle: [yes]`, `License: MIT`).
- [ ] **Step 2:** Leave the rest to Jason's consoles; keep the checklist updated as each store responds.
- [ ] **Step 3:** Commit: `docs: f-droid metadata drafts`.

---

## Execution notes

- Tasks 1–7 are tightly ordered but independently committable; 8–10 can run in parallel after 7; 11–12 gate on Jason's console work.
- The executor should not open the design's "Wave 4" consoles — only repo work. All secret values (`SV_KEYSTORE_PASS`, `.env`) come from Jason, never guessed, never committed.
- Apple renewal deadline (2026-11-24) is Jason's to book; Task 11 Step 1 is the earliest Apple work and can slip behind Tasks 7–10 without harm.
