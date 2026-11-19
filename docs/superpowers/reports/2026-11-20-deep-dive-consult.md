# Deep-Dive Consult — Pre-Release Cross-Check (5 agents, 2 rounds)

**Date:** 2026-11-20 · **Panel:** codex (glm-5.3-flash), claude (minimax-m3.1-flash), qwen (deepseek-v4.1-flash), copilot (muse-spark-open), pi (glm-5.3-flash)
**Angles:** shared-package runtime + test blind spots · cross-app consistency · release pipeline + store compliance · first-run UX/store-reviewer · licensing/FOSS/attribution
**Branch:** `release-readiness` @ `3e3d23c` · Raw reports: `/tmp/consult_{codex,claude2,qwen,copilot,pi}.md` + `/tmp/round2_*.md`

**Verdict:** the Nov-17 release plumbing holds (7/7 signed Android AAB+APK; all identifiers, signing, icons, licenses verified across all 7). The two hard blocks that remain are (1) iOS IPA export — root-caused and *proven fixable in minutes* (manual signing + profile map) — and (2) the Novena app's entire advertised reminder feature, which is **switched off at startup** and unreachable in any build. Around those: one real app-logic bug (Bible search ignores the user's chosen translation), one App Review 2.3.3 listing-vs-build mismatch, and a content-licensing gap ("MIT" asserted over unlicensed content).

## A. Release blockers

1. **iOS export: manual signing + profile map — fix proven by qwen.** `ExportOptions.plist` ×7 and `Fastfile:54-58` say `signingStyle: automatic` with an empty profile map; the 7 registered profiles are `IsXcodeManaged=false`, so automatic can never find them and gym never passes `-allowProvisioningUpdates`. qwen exported a valid signed IPA from the existing (dev-signed) archive in seconds with `method: app-store-connect` + `signingStyle: manual` + `provisioningProfiles: {bundle: UUID}`. ~10 lines × 7 + Fastfile. *Archive signing is irrelevant — export re-signs.*
2. **Novena reminders are dead code, shipped.** The service is disabled at startup (`main.dart:70` "temporarily disabled"), `scheduleNovenaNotifications()` has **zero callers**, `notificationServiceStatusProvider` is never watched, the Android merged manifest has **no** `ScheduledNotificationReceiver`/`RECEIVE_BOOT_COMPLETED` (devotionals has 2+2), the iOS AppDelegate lacks the `UNUserNotificationCenter` delegate, and the Play-blocked `SCHEDULE_EXACT_ALARM` path can't be granted on Android 13+ (plugin `requestExactAlarmsPermission()` never called). The listing promises reminders — App Review 2.3.3 / Play deceptive-behavior. **Fix stack:** wire `scheduleNovenaNotifications()` into `_startNovena()`, make the screen watch `notificationServiceStatusProvider`, copy devotionals' 4 manifest lines + iOS delegate, and adopt devotionals' `inexactAllowWhileIdle` (drop `SCHEDULE_EXACT_ALARM`) — or strike reminders from the listing and ship silent.
3. **`PrivacyInfo.xcprivacy` missing from all 7 iOS apps** (found in Round 2, by claude+copilot) — Apple's required-reason-API declaration; a common fresh-upload rejection even with plugin manifests present. One file per app + resource-phase wiring.
4. **ASC app records still uncreated** (API keys can't POST /apps on personal accounts — verified server-side). Manual: ASC → My Apps → **+**, seven records (names/bundle IDs per the pairing list). `Fastfile::register_apps` (`produce` with `api_key_path`) is dead code — delete; `tool/register_asc.rb` already registered bundle IDs + profiles.
5. **Privacy/support URLs are dead end-to-end:** repo 404 (private), `sancta-via.net/privacy` unresponsive, listings point at a GitHub blob URL, and the novena in-app screen still ships `yourusername.github.io/...` (`privacy_policy_screen.dart:317,359` — orphaned: no app currently exposes a reachable privacy link). Site deploy + one URL everywhere.

## B. App bugs to fix before release

6. **Bible search ignores the selected translation.** Search screen shows the app setting (`bible_search_screen.dart:55`) but the query reads the shared `selectedBibleTranslationProvider`, hard-defaulted CPDV and never written by the app (`bible_data_riverpod/search_providers.dart:117`, `settings_providers.dart:5-8`). Fix at the seam + widget test (set DRC → search → assert result translation).
7. **Calendar erases a deliberately selected date on resume** (`app.dart:38-65` resets any non-today selection) and **deep-link dates roll silently** (`/day/2026-13-05` → 2027-01-05; `DateTime.parse` normalises; devotionals' strict parser is the pattern).
8. **Saints "today" freezes at first open** — captured `DateTime.now()` at provider init; no midnight invalidation; feast lists can show yesterday's saints all day.
9. **"Test Examination of Conscience" ships in the production Confession list** (`examinations_metadata.json:54-60`, `target_audience: Developers`, unfiltered ListView) — visible to reviewers; one-line filter/metadata fix.
10. **Text scaling:** 3 of 7 apps (Bible, Confession, Prayer) lack `withClampedTextScaling`; extract the shared helper. Novena/Devotionals/Calendar/Saints clamp.
11. **Dark-mode liturgical-color flicker** on Confession (theme gated on `null` calendar); cache last color like novena does. Confession home spinner narrows to out-of-range dates only (embedded range 2024–2035) — keep a null/error branch, Medium.

## C. Content & licensing (blocks F-Droid; risk on all stores)

12. **`License: MIT` asserted over unlicensed content** (the metadata reviewers read first): 33/33 devotional packs `license: null`; Marians' Divine Mercy chaplet translation bundled **twice** with no permission note; Pope Francis examination unannotated; `saint-for-that` upstream is private AND unlicensed while the in-app About claims "open-source"; `prayers_staging/` holds 124 texts copied from a third-party proprietary app (unshipped — purge or annotate). Annotation pass + chaplet permission (Marians grant readily, but ask) or PD replacement.
13. **1,439/1,443 saint thumbnails have only `attribution: "Wikimedia Commons"`** (site, not license): Commons-API metadata pass → author/license/file-page per image; 4 dead thumb refs (`casimir`, `isaac-the-syrian`, `moses-the-black`, `perpetuus`); the in-app About copy must stop overclaiming.
14. **Kneeling glyph `TODO(jason)` still live** (`THIRD_PARTY_NOTICES.md:15`) — CC BY 4.0 needs author/title/source/changes. Also: bundle the notices into apps, add the Crimson Text OFL text, fold in the full Bible-corpus attribution (WEB-C trademark + CPDV), add the romcal MIT row.
15. **`saints.db` ships twice per APK (9.2 MB × 2)** — fix direction is **opposite of pi's Round-1**: keep the app-side copy (the loader's literal key), drop the package-side bundle from `saint_data/pubspec.yaml`; update `app_asset_pin_test.dart` together. Also delete the 0-byte local `bibles.db` stub (untracked) and the committed Wikimedia-error-page-as-jpg at `assets/images/mysteries/joyful/1-annunciation.jpg`.

## D. Store listings & assets

16. **App Store screenshots cannot be uploaded — for two reasons:** all 26 captures are 1206×2622 (the 6.3" raster — **not an ASC slot**; slots are 6.9"/6.5"/5.5"), and saints/devotionals have only 2 screenshots (ASC minimum 3). Re-shoot at 1320×2868 + 2064×2752 (iPad) and take a 3rd frame for the two new apps.
17. **Apple subtitle limits:** all 7 subtitles >30 chars (42/31/39/35/42/47/69); devotionals keywords 106/100. Trims exist in Round-1 (claude2 §15/16).
18. **Listing-source-of-truth is three-way contradictory:** categories ("Lifestyle" vs "Books & Reference"), Play short descriptions in `fastlane/metadata/android/*/en-US/` vs `store_listings.md` subtitles, no `fastlane/metadata/ios/` at all. Reconcile one field/one file before entry.
19. **App Review 4.3 (spam) exposure:** 7 near-identical apps, same icon motif, overlapping content (Divine Mercy ships in devotionals AND novena), one developer, batch submission. Mitigate by staggering submissions, distinct first screenshots + distinct listing copy per app, and pre-write the 4.3 rebuttal.

## E. Pipeline corrections (fast, mechanical)

20. `*.mobileprovision` + `*.p12` + `fastlane/report.xml` → root `.gitignore`; move the 7 profiles out of the repo root (they're installed in Xcode already).
21. Track the 4 missing lockfiles (`devotionals`, `saint_data`, `devotional_engine`, `devotional_engine_riverpod`) — the green gate ran *before* `pub get` on untracked-lock packages, i.e. the shipped binary graphs were never tested.
22. Delete the dead `register_apps` lane; delete the redundant `flutter build ios` step; export to `releases/<ts>/ipa/`; add a post-build manifest (app→version→commit→SHA256) and per-app tags on first publish; add an `apksigner` post-check.
23. Version drift: shipped build is `versionCode 4` while metadata changelogs say 2 and fdroid ymls pin 2 — regenerate changelogs (`4.txt`) and ymls from the manifest after tags exist. Also fix fdroid `apt-get update || install` → `&&` ×**7**, `Description:` pointers (wrong level ×7), and the per-applicationId throwaway `key.properties` note (or `SV_ALLOW_DEBUG_SIGNING=1` since F-Droid re-signs).
24. Docs truth-up: checklist §2 "R8 OFF correction" is wrong in substance — R8 *runs* (mapping.txt ×7) but **obfuscation is effectively off** (no app/plugin/AndroidX class renamed in shipped dex; only `j$.time` desugars); the mandatory device smoke covers the **shrinking** (time-zone path) not renaming; DISTRIBUTION_GUIDE's `altool` line; fastlane README lane claims.
25. ProGuard rules: 5 apps keep a package prefix that no longer matches reality **[claude2 quotes `net.supersive` — verify against files before writing the fix]**, devotionals has 1 line, saints has **no file at all**; give all 7 correct, uniform rule sets (harmless while obfuscation is off, armed trap if anyone enables it).
26. Melos bump scripts: drop `--depends-on=cider` (broader filter, redundant next to `--file-exists=lib/main.dart`); one rule for "what is an app".
27. `CFBundleURLTypes` missing in devotionals + saints iOS (the only two with deep-link routes) — dead incoming links.
28. Saints iOS uses SPM (no Podfile) while the other 6 use CocoaPods — resources verified present in its archive; just verify per-app plugin PrivacyInfo manifests at once.

## Adjudicated contradictions (Round 2)

- **Novena notifications:** claude2's call-graph + AAB evidence wins — the feature is off at startup; copilot's timing critique describes code that never runs; its UX priming work becomes relevant *after* the wiring fix. pi+qwen converge on the same order.
- **R8:** qwen right that "OFF" is wrong; claude2 right that "obfuscated dex" was wrong — R8 runs, obfuscation effectively off, risk is shrinking.
- **IPA export cause:** qwen's manual-signing repro is decisive; archive signing irrelevant (claude2's "so" deleted).
- **Lockfile count:** pi's 4 wins (claude2 said 1).
- **`saints.db` dedupe direction:** claude2's opposite-direction fix wins (pi's would break the loader).
- **Copilot misc:** "infinite spinner" narrowed; "5 of 7" → 3 of 7; ATT key dropped; "privacy screen reachable" downgraded (orphaned screen, but listing URL remains the blocker).

## Proven good (re-verified this run)

Bundle IDs, per-app LICENSE ×16, adaptive icons ×7, `ITSAppUsesNonExemptEncryption` + category + `allowBackup` + `<queries>` ×7, signing gate, keystores/`key.properties` gitignored, 7/7 release-signed AAB+APK (versionCode 4, no `INTERNET` in release manifests, distinct release certs), 7 valid profiles ACTIVE (2027), API key + `asc_key_check` green, regression gate green (1,142 tests), saint thumbs integrity, dependency hygiene clean.

## Suggested execution order

1. **iOS export fix** (ExportOptions ×7 + Fastfile, manual+map) → re-run export → 7 IPAs.
2. **Novena reminder stack** (wire, receivers, delegate, inexact mode) or strike the listing claims.
3. **Privacy manifests + PrivacyInfo** ×7 + ASC app records (manual ×7) + privacy URL deploy → **first TestFlight upload**.
4. **App-logic fixes** (Bible search seam, calendar resume/rollover, saints staleness, test-examination filter, text-scale helper, feedback tiles, notification primer timing).
5. **Content licensing pass** (packs, chaplet, saint-for-that license+copy, Commons metadata, glyph TODO, notices bundling).
6. **Screenshots for ASC** (re-shoot at 1320×2868 + iPad + 3rd frame) + listing reconciliation (subtitles, keywords, categories, ios metadata tree).
7. **Pipeline hygiene** (gitignores/profiles, lockfiles, manifest+tags, fdroid/fdroiddata regeneration, docs truth-up, Play service account + 12-tester clock start).
