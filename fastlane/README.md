# Sancta Via — release automation (fastlane)

One `fastlane` invocation ships a build for any of the seven apps to
TestFlight (iOS) or the Play internal track (Android).

## What requires money vs. what is free

- **fastlane** — free, open source, already installed (`/opt/homebrew/bin/fastlane`).
- **Apple Developer Program** — the $99–$100 fee itself. Letting it lapse
  freezes all seven store listings (no updates, TestFlight builds expire
  within 90 days, installed apps keep running but drift). The fee is due
  regardless of automation — fastlane only makes paying for it worthwhile.
- **Play Console** — one-time $25 fee, already paid.

## One-time setup (the only manual steps)

### Apple (≈15 minutes)

1. Generate an **App Store Connect API key**:
   <https://appstoreconnect.apple.com> → Users and Access → Integrations →
   App Store Connect API key → generate with **App Manager** role.
2. Save the `.p8` file OUTSIDE this repo (e.g. `~/.fastlane/AuthKey_<KEYID>.p8`)
   and copy the **Key ID** and **Issuer ID** from the same page.
3. Copy `.env.example` to `.env` and fill:
   ```text
   ASC_KEY_ID=...
   ASC_ISSUER_ID=...
   ASC_KEY_PATH=/Users/jason/.fastlane/AuthKey_<KEYID>.p8
   ```
4. `bundle exec fastlane` / `fastlane` picks up `.env` automatically; the key
   file itself is never committed.

### Google Play (≈15 minutes, only when first shipping an Android build)

1. Play Console → Setup → API access → create a **service account** and link
   it; download the JSON.
2. Save it outside the repo (e.g. `~/.fastlane/play-service-account.json`)
   and set in `.env`;
   ```text
   PLAY_JSON_KEY_PATH=/Users/jason/.fastlane/play-service-account.json
   ```
3. The first `ship_android` upload must be manual through the Console UI
   (Google's rule: the first AAB of a new app version can't go through the
   API); after that fastlane uploads work.

## Apps + identifiers

| App | Apple bundle id | Android application id |
|---|---|---|
| sancta_via_bible_reading_app | net.superversive.sancta_via.bible_reading_app | net.superversive.sancta_via.bible_reading_app |
| sancta_via_confession_companion | net.superversive.sancta_via.confession_companion | net.superversive.sancta_via.confession_companion |
| sancta_via_devotionals | net.sancta-via.sanctaViaDevotionals | net.sanctavia.sancta_via_devotionals |
| sancta_via_liturgical_calendar_app | net.superversive.sancta_via.liturgical_calendar_app | net.superversive.sancta_via.liturgical_calendar_app |
| sancta_via_novena_companion | net.superversive.sancta_via.novena_companion | net.superversive.sancta_via.novena_companion |
| sancta_via_prayer_companion | net.superversive.sancta_via.prayer_companion | net.superversive.sancta_via.prayer_companion |
| sancta_via_saint_companion | net.superversive.sanctavia.saintCompanion | net.superversive.sancta_via.saint_companion |

## Daily use

```bash
fastlane ship_ios app:saint_companion            # build + TestFlight
fastlane ship_android app:saint_companion        # signed AAB + Play internal
fastlane ship_all                                # every app, both platforms
fastlane release_notes app:saint_companion       # prompts for release notes
```

- iOS signing uses the same **Development Team `U2267GC4DS`** plus the ASC
  API key (no cert-repo / match needed — Xcode-managed automatic signing).
- Android release signing needs `android/key.properties` restored (lost on
  the crash restore) — a store upload without it falls back to debug
  signing, which the Console rejects.

## Renewal decision helper

If the membership is NOT renewed: the Play builds keep shipping (the
Console is unaffected), iOS TestFlight dies in ≤90 days and the 7 store
listings freeze. The apps stay installed on user devices.
