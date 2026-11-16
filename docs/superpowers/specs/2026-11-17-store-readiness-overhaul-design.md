# Design: Store-Readiness Overhaul — Sancta Via (7 apps)

**Date:** 2026-11-17
**Status:** Draft for approval
**Source docs superseded:** `docs/DISTRIBUTION_GUIDE.md` (strategy, kept), `docs/store-launch-checklist.md` (checklist sections corrected by this doc where reality diverged).

## Intent and why

The monorepo's 7 Flutter apps have never been submitted to any store. The existing
launch checklist predates an audit (2026-11-17) which found the repo diverging from
what the checklist assumed. Goal: clean the repo to genuine store-readiness, then
submit to Google Play, Apple App Store/TestFlight, IzzyOnDroid, and F-Droid main repo.

Nothing is published anywhere, so every identifier is still mutable **until first
submission**; bundle IDs are permanent afterwards. Apple Developer renewal due
~2026-11-24 — user-owned, urgent.

## Decisions made (by Jason)

1. **All bundle IDs standardized** to `net.superversive.sancta_via.<snake_app_name>`
   on every platform. Fixes: `devotionals` → `net.superversive.sancta_via.devotionals`
   (Android was `net.sanctavia.sancta_via_devotionals`, iOS was the invalid
   `net.sancta-via.sanctaViaDevotionals`); `saint_companion` iOS corrected from
   `net.superversive.sanctavia.saintCompanion` to match its Android ID.
2. **License: MIT** at repo root and all apps lacking one (5 packages already carry
   one; align any that differ).
3. **Signing restored fresh** — no past store keys exist, so generate one keystore
   with per-app aliases (or per-app keystores — builder's call), one `key.properties`
   per app, Play App Signing applied at first upload. No "upload key reset" needed —
   that checklist item is deleted (it assumed already-live apps).

## Goals

- Every app produces a valid signed AAB (`flutter build appbundle --release`) and a
  valid signed IPA that passes `xcodebuild -exportArchive` (exit code checked, not assumed).
- Every upload has a unique `versionCode`/`CFBundleVersion` (build numbers exist: `+N`).
- F-Droid-acceptable FOSS hygiene: root + app LICENSE files, in-tree asset attribution,
  no proprietary deps, no dead deps that trigger review flags.
- Play policy-clean manifests (no stale permission/receiver declarations).
- Listing assets present for all 7 apps (Play icon 512, feature graphic 1024×500,
  screenshots incl. saints/devotionals, adaptive Android icons).
- `fastlane/metadata/android/<locale>/` scaffolded per app (IzzyOnDroid format).
- One proof run: single app through `ship_android` (internal track) and `ship_ios`
  (TestFlight) before batch submission.

## Non-goals

- No new features, no app code changes beyond release plumbing/manifest fixes.
- No CI pipeline this round (no CI exists today; fastlane local is the pipeline).
- No web/desktop store targets (Microsoft Store, Flatpak, etc.).
- No translations of listings (English launch).
- No R8/minification enablement in this pass (revisit with a smoke-test round later;
  enabling it now would change runtime risk right before first submission).

## Anti-goals (failure modes)

- Submitting with debug-signed or unversioned artifacts.
- Committing keystore/`key.properties` secrets to the repo (the `build-release.sh`
  auto-commit flow and the missing per-app `.gitignore` rules make this a live risk).
- Bundle-ID drift between Android and iOS for the same app.

## Constraints

- Apple renewal (user, console) before 2026-11-24 gates all TestFlight work.
- Privacy-policy URL must be publicly reachable before Apple/Play listing creation
  (site deploy is user-owned; repo-side only ensures the policy content exists).
- ASC API key + Play service account creation are user-owned console work;
  `fastlane/.env` (never committed) consumed by lanes.
- Melos workspace with path dependencies — cross-package edits need `melos bootstrap` /
  `flutter pub get` propagation.

## Builder-check resolutions (2026-11-17)

1. **iOS certificates:** only an Apple *Development* cert exists on the build Mac;
   no *Distribution* cert (cause of the 7 failed IPA exports). Wave 3 gains a
   post-renewal step: mint the Apple Distribution cert (Xcode sign-in or fastlane),
   then `ship_ios`/automatic signing works. All iOS export validation is sequenced
   after the Apple renewal.
2. **Membership status:** assumed active until ~2026-11-24 (renewal pending).
3. **Play account:** exists ($25 paid, per checklist). If it is a personal account
   created after Nov 2023, Play requires a closed test with 12 testers for 14 days
   before production — flagged as a user task in Wave 4 (recruitment may be needed).
4. **"Wave 0" defined:** user-owned console items — Apple renewal; site deploy with
   privacy URL; ASC API key (`.p8` + key ID + issuer); Play service-account JSON.
5. **Notification intent:** bible app notifications are dead (plugin commented out
   in pubspec; only `.backup` files reference it) → strip receivers/permissions and
   delete the backup file. Novena and devotionals notifications are intentional —
   keep, including exact-alarm permissions where used.
6. **Screenshots:** reuse existing captures for the 5 original apps; optional
   recapture pass if UI changed since; generate fresh sets for saints/devotionals.
7. **Listing copy:** the builder drafts saints/devotionals copy from pubspec
   `app_store:` blocks / app descriptions; Jason reviews before Wave 4 submission.
8. **Confirmed:** all 7 apps free, no ads, no IAP, no analytics/telemetry.
9. **Privacy URL:** placeholder `https://sancta-via.net/privacy` (domain suggested
   in the checklist); Jason confirms the live URL at site deploy.

## Wave plan (execution order)

**Wave 1 — repo hygiene (automatable, no secrets needed):**
1. Bundle IDs per decision 1: `android/app/build.gradle(.kts)`, `AndroidManifest.xml`
   (incl. legacy `package=` attr), `ios/Runner.xcodeproj/project.pbxproj`, Info.plist
   display names unchanged; verify `fastlane/Fastfile` app-name mapping still correct.
2. Build numbers: `version: X.Y.Z+N` on all 7 apps; melos script `version:bump:build`
   incrementing `+N`; document scheme in AGENTS.md.
3. Signing: keystore generation script (documented, secrets outside repo),
   `signingConfig` wiring for saint_companion + devotionals (missing entirely),
   `key.properties.template` for those two, per-app `.gitignore` rules for
   `key.properties`, `*.jks`, keystores dir.
4. Manifest hygiene: remove stale notification receivers/permissions from
   `bible_reading_app`; audit every manifest once; drop dead `google_fonts` dep from
   novena; add missing `LSApplicationCategoryType` keys on iOS.
5. FOSS hygiene: root `LICENSE` (MIT) + any missing app/package licenses; in-tree
   attribution file for the kneeling glyph (CC BY 4.0); confirm it's accurate.
6. Tooling fixes: `build-release.sh` exit-code handling for iOS export (don't
   report success on failure); correct stale claims in checklist/docs (R8 state,
   nonexistent CI workflow, no-existing-apps reality); update `fastlane/README`
   identifiers table with corrected IDs.

**Wave 2 — listing assets (automatable from in-repo sources):**
7. Adaptive icon config (`flutter_launcher_icons` adaptive keys) + regenerate.
8. Play 512 icon, 1024×500 feature graphics for all 7.
9. Screenshots for `saint_companion` + `devotionals`.
10. `fastlane/metadata/android/en-US/` scaffold per app: title, short_description,
    full_description, `changelogs/<versionCode>.txt`; source from `store_listings.md`
    + per-app pubspec `app_store:` blocks. Add missing listings for saints/devotionals
    to `store_listings.md`.

**Wave 3 — verification:**
11. Clean builds: each app `flutter build appbundle --release` signed correctly;
    one app IPA exported with working signing (needs Wave 0 cert state from Jason).
12. `fastlane asc_key_check` once the API key exists; `ship_android app:saint_companion`
    → internal track; `ship_ios app:saint_companion` → TestFlight; device smoke.

**Wave 4 — submissions (largely user-owned in consoles, with repo support):**
13. Play listing creation per app (data safety: no collection; content rating; assets).
14. Apple listing creation per app after TestFlight; first store-review submission.
15. IzzyOnDroid hosting requests (signed APK + source link per app).
16. F-Droid: `fdroiddata` metadata per app (pinned Flutter version, subdir builds),
    MR to fdroiddata; iterate on build-server feedback.

## What's left to the builder

- Keystore granularity: one keystore with 7 aliases vs 7 keystores — builder's call,
  default one-keystore-multi-alias (simpler rotation story is not needed pre-publication).
- Exact build-number starting values (propose `versionCode` = monotonic int starting
  at 1 per app; bump scheme must survive cider's `X.Y.Z` bumps without collision).
- Whether adaptive icons need a foreground/vector asset per app or use the existing
  `app_icon.png` for both layers (acceptable for first submission).
- Manifest backup/extraction rules completeness per app.
- Any additional stale-doc reconciliation found while editing.

## Verification criteria

- `flutter analyze` + `flutter test` green across workspace.
- A signed release AAB per app produced by the standard pipeline.
- `grep`-verifiable: consistent bundle IDs across platforms; no `USE_EXACT_ALARM` in
  bible app; no `google_fonts` in novena pubspec; LICENSE present at root and apps;
  `.gitignore` covers all secret paths; every app version carries `+N`.
