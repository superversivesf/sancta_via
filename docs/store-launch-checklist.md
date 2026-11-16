# Store Distribution Checklist — Sancta Via (7 apps)

Order = recommended execution order. Every step notes whether it is
**manual** (you, in a web console) or **automated** (fastlane / repo tooling).
Deadlines matter only for Apple: the dev-account renewal is due ~**Nov 24**.

Costs recap: Apple membership $99/yr (due regardless if the 7 iOS apps stay
live) · fastlane $0 · Play $25 one-time (already paid) · IzzyOnDroid $0 ·
F-Droid $0.

---

## 0. Shared prerequisites (one-time, before any store)

- [x] **(done)** Website pages written: `<site>/apps/` (pitch + support
      link) and `<site>/privacy/` (one-paragraph offline-first policy) —
      the local test build is at the home-server docker stack.
- [ ] **(manual)** **Deploy the site to a proper domain** — store-submission
      blocker (both Apple and Play require a live privacy-policy URL).
      Options: GitHub/Cloudflare Pages ($0, static Astro build), home
      server + Cloudflare Tunnel (keeps hosting in-house), or a small VPS
      + Caddy. Domain suggestion: `sancta-via.net` (already referenced in
      the Wikimedia fetch User-Agent).
- [ ] **(manual)** Replace the placeholder Buy-me-a-coffee link in
      `site/src/pages/apps.astro` once your page exists.
- [ ] **(automated-ready)** Restore Android release signing — UPDATED
      2026-11-17: nothing was ever published, so there is no "reset upload
      key" step. Instead: `android/key.properties` + per-app keystores were
      lost with the crash restore; regenerate them with
      `SV_KEYSTORE_PASS=<secret> ./tool/generate_keystores.sh generate`
      then create each app's `android/key.properties` from its
      `key.properties.template`. Play App Signing is granted on first upload.
- [ ] **(manual)** Create the App Store Connect **API key** (App Manager role):
      ASC → Users and Access → Integrations → App Store Connect API.
      Save `.p8` outside the repo; copy Key ID + Issuer ID.
- [ ] **(manual)** Copy `fastlane/.env.example` → `fastlane/.env`; fill
      `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_PATH`.
- [ ] **(automated)** Verify the key works: `fastlane asc_key_check`
      (from `/Users/jason/Repos/sancta_via/fastlane`).

## 1. Apple / TestFlight (fastlane automated after step 0)

- [ ] **(manual)** Renew the Apple Developer Program **before Nov 24**
      (auto-renewal setting or manual payment in ASC).
- [ ] **(automated)** Proof run on one app:
      `fastlane ship_ios app:saint_companion` → build + upload to TestFlight.
- [ ] **(automated)** Then the rest:
      `fastlane ship_all` (all seven apps → TestFlight; uploads are
      skipped-fast because we don't wait for processing).
- [ ] **(manual)** In ASC, rename the two new listings to match the on-device
      names: **Devotions SV** and **Saints SV** (TestFlight shows the bundle
      display name already; store listing metadata is separate).
- [ ] **(manual)** Invite yourself + any beta testers to the TestFlight build
      (TestFlight → app → internal testers).
- [ ] **(manual)** Submit the first store update: ASC → app → iOS App →
      pick the uploaded build → review info → submit (fastlane can pre-fill
      this later via `deliver`; keep manual for the first pass).

## 2. Google Play (fastlane automated after the keystore + service account)

- [ ] **(manual)** Create the Play **service account** and link it:
      Play Console → Setup → API access → link a project → grant
      Release-to-testing + production access; download the JSON to
      `~/.fastlane/play-service-account.json`; add
      `PLAY_JSON_KEY_PATH` to `fastlane/.env`.
- [ ] **(automated)** First internal-track upload:
      `fastlane ship_android app:saint_companion`
      (draft release in the internal track).
- [ ] **(manual)** Publish the internal release once in the Console UI
      (first publish per app needs the Console; later uploads are
      fastlane-only).
- [ ] **(automated)** Remaining six apps: `ship_android app:<name>` each.
      Note: the very first AAB of each NEW app version has the
      must-publish-first-time-in-Console rule only for brand-new listings.
- [ ] **(manual)** Runtime smoke on a device BEFORE any production push:
      CORRECTION 2026-11-17: R8/minification is currently OFF in every app's
      `android/app/build.gradle.kts` (the earlier claim that it was turned ON
      was wrong — re-check `isMinifyEnabled` before relying on it). Exercise
      a release build from the internal track anyway; if R8 gets enabled
      later, that smoke becomes mandatory.

## 3. IzzyOnDroid (fastlane-compatible metadata, developer-signed APKs)

- [ ] **(automated)** Build release APKs per app (the Android side of the
      release pipeline, `flutter build apk --release`) with the restored
      release keystore.
- [ ] **(automated)** Scaffold `fastlane/metadata/android/<locale>/`
      per app: `title.txt`, `short_description.txt`, `full_description.txt`,
      `changelogs/<versionCode>.txt` (IzzyOnDroid reads exactly this shape).
      Content source: each app's seed record + store descriptions.
- [ ] **(manual)** Request hosting: gitlab.com/IzzyOnDroid → repo → create a
      hosting request issue per app, attaching the signed APK + link to the
      source repo (`github.com/<you>/sancta_via`).
- [ ] **(manual)** Respond to review comments; expect days, not weeks.
- [ ] **(automated thereafter)** New versions: attach a new signed APK to the
      same issue; changelog comes from the fastlane metadata.

## 4. F-Droid main repo (they build + sign from source; slowest channel)

- [ ] **(manual)** Licensing audit for F-Droid policy: all dependencies
      FOSS (checked: no Firebase/GMS; sqflite uses the system SQLite),
      bundled fonts/images carry licenses (kneeling glyph CC BY 4.0,
      attribution already recorded in the app READMEs). Fix anything
      flagged.
- [ ] **(manual)** Prepare `fdroiddata` metadata `yml` per app: category,
      description, source URL to this repo, commit/branch pinning,
      build flavors (Flutter: they build with pinned Flutter version).
- [ ] **(manual)** Submit the packaging request to the F-Droid build team;
      iterate on their build-server feedback (they compile from source and
      sign with F-Droid's key).
- [ ] **(manual)** Accept: F-Droid installs will NOT cross-upgrade from
      Play/Izzy installs (different signature) — expected, documented.
- [ ] **(manual thereafter)** Every app release = a metadata version bump +
      a new packaging request (days-to-weeks queue). Plan a cadence (monthly
      data refreshes, faster only for critical fixes).

## 5. Ongoing cadence (after all channels are live)

- [ ] **(automated)** Data refresh (saint histories, liturgical year, icons):
      update `saints.db` → `build_saints_db.dart` → propagate to app assets →
      `fastlane ship_all` + Izzy APK attach — one working session.
- [ ] **(checklist)** Before each production push: device smoke on the
      R8-optimized builds; release notes into
      `fastlane/metadata/android/<locale>/changelogs/`.
- [ ] **(annual)** Apple renewal reminder ~Oct (a month before expiry);
      fastlane makes the post-renewal ship a single command.

---

Fastfile lanes (from `fastlane/`): `asc_key_check`, `ship_ios app:x`,
`ship_android app:x`, `ship_all`. Env: `fastlane/.env` (never committed).
