# Distribution Guide — Getting Sancta Via Apps into App Stores

> **Scope.** 7 apps in this monorepo are distribution candidates:
>
> | # | Directory | Display name | Bundle ID | Current version |
> |---|-----------|-------------|-----------|-----------------|
> | 1 | `sancta_via_prayer_companion` | Sancta Via Prayer | `net.superversive.sancta_via.prayer_companion` | 1.1.42 |
> | 2 | `sancta_via_bible_reading_app` | Sancta Via Bible | `net.superversive.sancta_via.bible_reading_app` | 1.1.63 |
> | 3 | `sancta_via_confession_companion` | Sancta Via Confession | `net.superversive.sancta_via.confession_companion` | 1.1.55 |
> | 4 | `sancta_via_liturgical_calendar_app` | Sancta Via Calendar | `net.superversive.sancta_via.liturgical_calendar_app` | 1.1.49 |
> | 5 | `sancta_via_novena_companion` | Sancta Via Novena | `net.superversive.sancta_via.novena_companion` | 1.1.50 |
> | 6 | `sancta_via_devotionals` | Sancta Via Devotionals | `net.sanctavia.sancta_via_devotionals` | 1.0.8 |
> | 7 | `sancta_via_saint_companion` | Sancta Via Saints | `net.superversive.sancta_via.saint_companion` | 1.0.3 |
>
> All 6 earlier apps use the `net.superversive.sancta_via.*` prefix; `devotionals` uses `net.sanctavia.*` — standardise before first submission (see §1).
>
> These apps are **offline-first, no backend, free, no ads, no in-app purchases**. That makes every store submission simpler — no server to attest, no purchase flow to test.
>
> This doc covers **what you have to do** (one-time setup) and **what stays easy** (every future update). Technical build/signing work is flagged so it can be scripted.

---

## 1. One decision to make before anything else

### Bundle ID / package name

> **RESOLVED 2026-11-17** (commit "chore: standardize bundle IDs…"): every app now
> uses `net.superversive.sancta_via.<snake_name>` on Android **and** iOS —
> `devotionals` was moved off `net.sanctavia.*`/`net.sancta-via.*` and
> `saint_companion`'s iOS camelCase ID was corrected. Nothing below needs action;
> the original advice (pick one prefix before first submission) is kept for the record:

The 6 older apps share a prefix; `devotionals` breaks it:

```
net.superversive.sancta_via.prayer_companion   ← consistent
net.sanctavia.sancta_via_devotionals           ← odd one out
```

Bundle IDs **cannot change after first store submission**. Pick one prefix and stick to it. Recommendation: rename `devotionals` to `net.superversive.sancta_via.devotionals` (a one-line change in `android/app/build.gradle`, `ios/Runner.xcodeproj/project.pbxproj`, and `AndroidManifest.xml`).

### Display names

`AndroidManifest.xml` currently uses short labels like `Prayer SV` / `Bible Reader SV`. Store listings have their own display name (from `pubspec.yaml` `app_store.display_name`) — the manifest label is what shows on the home screen after install. Keep both; they don't need to match, but make the home-screen label recognisable (e.g. `S. Via Prayer` rather than `Prayer SV` if you prefer).

---

## 2. Google Play — required for Android

### One-time account setup (human, ~30 min + waiting)

1. **Create a Google Play Console account** at <https://play.google.com/console> — one account for all 7 apps.
   - Cost: **$25 one-time** developer registration fee.
   - You'll need a Google account with 2FA enabled, a legal name/address, and a credit card.
2. **Verify identity.** Google now requires identity verification (government ID) for all new developer accounts. Allow 1–2 days.
3. **Accept the Developer Distribution Agreement.**

### One-time per-app setup (human, ~15 min each)

For each app:

1. **Create app** in Play Console: _Create app_ → fill title, default language (English), app vs game (App), free, declarations (no ads, no IAP, target audience, content rating questionnaire — answer honestly; these are religious/reference apps, 4+ / Everyone).
2. **Data safety form.** Because these apps are offline:
   - "Does your app collect or share any user data?" → **No** (unless you add analytics/crash reporting later — then revisit).
   - No data types to declare, no encryption disclosure beyond the standard "no".
   - If you keep `INTERNET` permission (currently in all manifests for `share_plus` / future use), declare that the app *may* access the network for sharing, but does not collect data. Google flags `INTERNET` + "no data collected" as a mismatch only if you claim encrypted transit — leave those boxes unchecked.
3. **Target audience & content rating.** Fill the questionnaire once; it's identical for all 7 apps (Reference, no violence, no user-generated content). Save the answers to reuse.
4. **Store listing.** For each app you need:
   - App icon 512×512 PNG (you already have `assets/app_icon.png` — export at 512).
   - Feature graphic 1024×500 PNG (one per app, or one shared Sancta Via banner).
   - 2–8 screenshots (phone + 7" tablet minimum; 16:9 or 9:16). Generate with `flutter screenshot` or a device farm.
   - Short description (≤80 chars) and full description — already drafted in each `pubspec.yaml` under `app_store:`.
   - Contact email, privacy policy URL (see §2.1), category (`Reference` or `Lifestyle`).
5. **Signing.** Choose **Play App Signing** (Google manages the upload key). This is the default and recommended path — you keep an upload keystore, Google re-signs for distribution. If you lose the upload key, Google can reset it; if you opt out and lose the keystore, the app is dead.
   - Technical step: generate one upload keystore per app (or one shared keystore with 7 aliases — simpler to rotate, but one breach affects all). Store in CI secrets, never in git.

#### 2.1 Privacy policy

Google **requires** a privacy policy URL for every app, even if you collect nothing. You already have essentially nothing to disclose, so a single hosted page covering all 7 apps is enough. Options, simplest first:

- A static page at `https://sancta-via.net/privacy` (or your domain) — GitHub Pages is fine.
- Required content: what data is *not* collected, that the app works offline, contact email, last-updated date.

No lawyer needed for a "we collect nothing" policy, but keep the wording accurate if you later add notifications/analytics.

### Building & uploading (automatable)

```bash
# Per app — produces the binary Play wants (AAB, not APK)
flutter build appbundle --release   # → build/app/outputs/bundle/release/app-release.aab

# Upload via Play Console web UI, or automate with fastlane supply / Google Play Developer API
```

Add to CI (GitHub Actions; note: no workflow exists yet — this guide's earlier
claim of a `.github/workflows/flutter.yml` was stale. CI is a non-goal for the
2026-11-17 release-readiness pass; fastlane local runs are the pipeline):

- Build AABs on tag push.
- Upload to the **internal testing** track first (instant, no review).
- Promote to **closed → open → production** as you gain confidence.

### Updates

- Bump version in `pubspec.yaml` (`version: 1.1.43+43` — the `+N` build number **must increase** every upload).
- `cider bump patch` already does this; wire `melos run version:bump:patch` into the release workflow.
- Upload new AAB, fill "What's new" (one line), submit. Review is typically hours, often minutes for updates without permission changes.

---

## 3. Apple App Store — required for iOS

### One-time account setup (human, ~30 min + waiting)

1. **Enroll in Apple Developer Program** at <https://developer.apple.com/programs/enroll/> — one membership for all 7 apps.
   - Cost: **$99/year** (annual, not one-time).
   - Requires Apple ID with 2FA, legal entity verification. **Individual** enrollment is fastest; **Organization** requires a D-U-N-S number and takes 1–2 weeks. For a community/religious project, Individual is fine unless you need multiple team members with distinct roles.
2. **Accept agreements** in App Store Connect.

### One-time per-app setup (human, ~15 min each)

For each app:

1. **Create App ID** in _Certificates, Identifiers & Profiles_ → Identifiers → App ID. Use the bundle ID from the table above (e.g. `net.superversive.sancta_via.prayer_companion`). Enable only needed capabilities — currently **none** beyond defaults (no push, no iCloud, no associated domains for these offline apps; add `devotionals` notifications later if needed).
2. **Create App record** in App Store Connect → My Apps → + → New App. Fill: name, bundle ID, SKU (use bundle ID), primary language, category (Reference).
3. **App Privacy (privacy nutrition label).** Same story as Play: "Does your app collect data?" → **No**. Apple requires a privacy policy URL even when the answer is no — reuse the same `https://sancta-via.net/privacy`.
4. **Store listing** (App Store Connect → App Information / Version):
   - Icon 1024×1024 PNG (same `app_icon.png`, no alpha channel — Apple rejects transparency).
   - Screenshots: 6.7" (1290×2796), 6.5" (1284×2778), and iPad 12.9" if you claim iPad support (your `TARGETED_DEVICE_FAMILY = 1,2` says you do — either keep it and add iPad screenshots, or drop iPad to reduce screenshot burden).
   - Description, keywords (≤100 chars), support URL, marketing URL.
   - Age rating questionnaire (same answers as Play — 4+).
5. **Signing & provisioning.** Easiest path:
   - Use **Xcode automatic signing** with your Developer Team (`U2267GC4DS` is already in `project.pbxproj`).
   - For CI, use **App Store Connect API key** (create at _Users and Access → Keys_, download `.p8`, store in CI secrets) — avoids interactive Xcode login.

#### Current project.pbxproj notes

- `DEVELOPMENT_TEAM = U2267GC4DS` is already set — good.
- `IPHONEOS_DEPLOYMENT_TARGET = 15.0` — reasonable; raising it later is fine, lowering it after submission is not.
- No `ExportOptions.plist` yet — needed for IPA export / CI. Create one per app (see §7 snippet).
- `CODE_SIGN_STYLE = Automatic` — keep it.

### Building & uploading (automatable)

```bash
# Per app
flutter build ios --release          # produces Runner.xcarchive
# then export IPA (needs ExportOptions.plist) or use fastlane pilot/deliver
```

Or let `fastlane` / `xcodebuild -exportArchive` handle it. Upload via **Transporter** app, `altool`, or `fastlane deliver` / App Store Connect API.

Add to CI:

- Build on macOS runner (GitHub Actions `macos-latest`).
- Upload to **TestFlight** first (internal testers get it instantly; external testers need a short beta review, ~hours).
- Promote to App Store review when ready.

### Updates

- Bump `pubspec.yaml` version (same as Android — one source of truth).
- `CFBundleShortVersionString` = `version` before `+`, `CFBundleVersion` = build number — Flutter maps this automatically from `version: 1.1.43+43`.
- Submit for review. Updates typically review in <24h, often a few hours. No permission changes = faster.

---

## 4. F-Droid — optional but free and easy for FOSS

**Why:** F-Droid is the open-source Android store. Listing is free, no review theatre, and your audience (privacy-conscious, offline-first users) overlaps heavily with F-Droid users. It's also the easiest store to automate.

**Requirement:** Apps must be **fully open-source** with a license F-Droid recognises. Your repos are public on GitHub — add/verify a `LICENSE` file (MIT, GPL-3.0, Apache-2.0, etc.) at the repo root if not already present. Each app's `pubspec.yaml` dependencies must also be FOSS-compatible — check `flutter_oss_licenses` if unsure.

### Setup

Two paths — pick one:

#### A. Official F-Droid repo (main repository) — most discoverable

1. Fork <https://gitlab.com/fdroid/fdroiddata>.
2. Add a metadata file per app: `metadata/net.superversive.sancta_via.prayer_companion.yml` (example below).
3. Open a merge request. F-Droid maintainers review (days to weeks first time, then automated).
4. Once merged, F-Droid builds your app from source on their servers — you don't upload binaries.

Example metadata (minimal):

```yaml
Categories: [Religion, Reading]
License: MIT
SourceCode: https://github.com/superversivesf/sancta_via  # or per-app repo
IssueTracker: https://github.com/superversivesf/sancta_via/issues

AutoName: Sancta Via Prayer
Description: |
  Traditional Catholic prayers and devotions. Offline, no tracking.

RepoType: git
Repo: https://github.com/superversivesf/sancta_via

Builds:
  - versionName: 1.1.42
    versionCode: 42
    commit: v1.1.42
    subdir: sancta_via_prayer_companion
    gradle: [yes]

AutoUpdateMode: Version
UpdateCheckMode: Tags
CurrentVersion: 1.1.42
CurrentVersionCode: 42
```

F-Droid expects **one repo per app** or a monorepo with `subdir` — yours is the latter, which works.

#### B. Own F-Droid repo (self-hosted) — instant, no gatekeeping

Host your own F-Droid repository using `fdroidserver`:

```bash
pip install fdroidserver
fdroid init
# add APKs to repo/, run fdroid update, host the repo/ dir on any static host
```

Users add your repo URL in the F-Droid app. Good as a stopgap while waiting for main-repo inclusion, or as your permanent channel if you prefer control.

### Updates

- Tag a release in git, bump `versionName`/`versionCode` — F-Droid's bot picks it up automatically (`AutoUpdateMode: Version`).
- No manual upload.

---

## 5. Other stores worth considering (ranked by effort/return)

| Store | Platform | Cost | Effort | Why bother? |
|-------|----------|------|--------|-------------|
| **GitHub Releases** | Android (APK) | Free | ~0 — you already build APKs | Direct download, no gatekeeper. Link from your website. Users sideload. Do this regardless. |
| **Amazon Appstore** | Android (Fire) | Free | Low — same AAB/APK, separate console | Reaches Kindle Fire tablets. Reuse Play assets verbatim. |
| **Huawei AppGallery** | Android | Free | Low | Large outside Play. Same binary. |
| **Samsung Galaxy Store** | Android | Free | Low | Pre-installed on Samsung. Same binary. |
| **Obtainium** | Android | Free | Zero | Not a store — an app that watches GitHub Releases and auto-updates sideloaded APKs. Your users get auto-updates for free if you publish GitHub Releases. Mention it in your README. |
| **Accrescent** | Android | Free | Low | Newer FOSS-focused store, growing. Similar to F-Droid but with modern signing. |
| **Flatpak / Snap** | Linux desktop | Free | Medium | `flutter build linux` exists — if you ship Linux builds, these are the stores for it. Low priority unless users ask. |
| **Microsoft Store** | Windows | ~$19 one-time | Medium | `flutter build windows` → MSIX. Only if you ship Windows builds. |

**Not worth it:** Alternative iOS stores (AltStore, etc.) — iOS sideloading is niche and requires user technical effort. Stick to App Store for iOS.

**Recommendation:** Do **GitHub Releases + Obtainium** immediately (zero store process), **Amazon** if you have time, **F-Droid** when you have a LICENSE file, and ignore the rest until users request it.

---

## 6. Making updates stay simple — automation you should add

Your current state:

- ✅ `melos.yaml` with `version:bump:*` scripts and `build:android`.
- ✅ `build-release.sh` that bumps versions and builds APK/AAB/IPA (but uses deprecated `altool`, no CI integration, no signing config).
- ✅ `.github/workflows/flutter.yml` with `analyze` + `test` (no build, no deploy).
- ❌ No signing keystore / provisioning in CI.
- ❌ No store upload automation.
- ❌ No `ExportOptions.plist` for iOS.

### Minimal CI upgrade (do this first)

1. **Add signing to CI secrets:**
   - Android: upload keystore file (base64-encode it), `KEYSTORE_PASSWORD`, `KEY_ALIAS`, `KEY_PASSWORD` as GitHub Secrets. Add `android/key.properties` from secrets at build time (`.gitignore` it).
   - iOS: App Store Connect API key (`.p8` + key ID + issuer ID) as secrets, or use `apple-actions/import-codesigning-certs`.
2. **Extend `.github/workflows/flutter.yml`:**

   ```yaml
   # Trigger on version tag, e.g. git tag p1.1.43 && git push --tags
   on:
     push:
       tags: ['v*', 'p*', 'bible*', 'saint*', 'novena*', 'cal*', 'conf*', 'dev*']
   jobs:
     build-android:
       runs-on: ubuntu-latest
       steps:
         - uses: actions/checkout@v4
         - uses: subosito/flutter-action@v2
         - run: melos bootstrap
         - run: flutter build appbundle --release  # per app
         # upload AAB as artifact + optionally to Play via fastlane supply
     build-ios:
       runs-on: macos-latest
       steps:
         - uses: actions/checkout@v4
         - uses: subosito/flutter-action@v2
         - run: melos bootstrap
         - run: flutter build ios --release --no-codesign  # or with signing
     release:
       needs: [build-android, build-ios]
       # create GitHub Release with APKs attached (for Obtainium / sideloaders)
   ```

3. **Bump + tag workflow:** `melos run version:bump:patch && git tag v1.1.43 && git push --tags` → CI builds everything.

### Nice-to-have later

- **fastlane** lanes per app (`Fastfile` with `supply` for Play, `deliver`/`pilot` for App Store) — one command to upload to all stores.
- **Screenshot automation** with `screenshots` or `fastlane frameit`.
- **F-Droid auto-update** already handles itself once metadata is in.

---

## 7. Snippets you'll need

### `android/key.properties` (create from CI secrets, never commit)

```properties
storeFile=../upload-keystore.jks
storePassword=${KEYSTORE_PASSWORD}
keyAlias=sancta-via
keyPassword=${KEY_PASSWORD}
```

### `android/app/build.gradle` signing block (add inside `android {}`)

```gradle
def keystoreProperties = new Properties()
def keystorePropertiesFile = rootProject.file('key.properties')
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
}
android {
    // ...
    signingConfigs {
        release {
            if (keystorePropertiesFile.exists()) {
                keyAlias keystoreProperties['keyAlias']
                keyPassword keystoreProperties['keyPassword']
                storeFile file(keystoreProperties['storeFile'])
                storePassword keystoreProperties['storePassword']
            }
        }
    }
    buildTypes {
        release { signingConfig signingConfigs.release }
    }
}
```

### `ios/ExportOptions.plist` (create per app, commit it — no secrets)

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key><string>app-store</string>
  <key>teamID</key><string>U2267GC4DS</string>
  <key>signingStyle</key><string>automatic</string>
</dict>
</plist>
```

### Privacy policy stub (host at `https://sancta-via.net/privacy`)

> **Sancta Via Privacy Policy** — Last updated: 2026-11-15
>
> Sancta Via apps (Prayer, Bible, Confession, Calendar, Novena, Devotionals, Saints) do not collect, transmit, or share any personal data. All content is bundled with the app and stored locally on your device. Favorites, recent prayers, and settings are stored locally via SharedPreferences/SQLite and never leave your device. The apps request Internet permission only to support sharing features. No analytics, advertising, or tracking is included. Contact: [your email].

---

## 8. Checklist — first release to each store

### Google Play (per app, first time)

- [ ] App created in Play Console (title, free, no ads, no IAP)
- [ ] Data safety form: "No data collected"
- [ ] Content rating questionnaire done
- [ ] Upload keystore generated, stored in CI secrets
- [ ] `android/key.properties` wiring + `signingConfig` in `build.gradle`
- [ ] Store listing: icon 512, feature graphic 1024×500, 2+ screenshots, description, contact email, privacy URL
- [ ] AAB built and uploaded to internal testing track
- [ ] Promoted to production after testing

### Apple App Store (per app, first time)

- [ ] App ID created (bundle ID matches `project.pbxproj`)
- [ ] App record in App Store Connect
- [ ] App Privacy: "No data collected" + privacy policy URL
- [ ] Age rating questionnaire done
- [ ] `ExportOptions.plist` added to `ios/`
- [ ] App Store Connect API key in CI secrets
- [ ] Store listing: icon 1024 (no alpha), screenshots (6.7" + 6.5" + iPad if claimed), description, keywords, support URL
- [ ] IPA built and uploaded to TestFlight → App Store review

### F-Droid (once, covers all Android apps)

- [ ] `LICENSE` file at repo root
- [ ] `metadata/*.yml` per app in `fdroiddata` fork
- [ ] Merge request opened
- [ ] (Optional) self-hosted repo via `fdroidserver` as interim

### Always (zero store process)

- [ ] GitHub Release with APKs on every version tag (for sideloaders + Obtainium)

---

## 9. FAQ

**Do I need separate developer accounts per app?** No. One Google Play Console account and one Apple Developer Program membership cover unlimited apps.

**Can I submit all 7 apps at once?** You *can*, but stagger by a few days. If one app has a review issue, it won't block the others, and you learn what reviewers care about. Start with the simplest (Calendar or Prayer).

**What about the bundle ID mismatch for devotionals?** Fix it now, before first submission. After submission it's permanent.

**Do I need a website?** Google Play requires a privacy policy URL. Apple requires support + privacy URLs. A single GitHub Pages site (`sancta-via.net` or `superversivesf.github.io/sancta_via`) is enough.

**What about translations?** All store listings support multiple locales. Your `app_store` metadata in `pubspec.yaml` is English-only — that's fine for launch. Add translations later per store console (no code change).

**What about app review rejections?** Common for religious/reference apps: ensure descriptions don't make medical claims, don't use "free" deceptively (you're actually free, so fine), and don't include placeholder text. Your apps are straightforward — low rejection risk.

---

*This doc covers strategy and manual steps. The automatable build/signing/upload pieces are ready to be scripted — see §6. Skipped: exact fastlane lane definitions and screenshot automation (add when CI signing is in place).*
