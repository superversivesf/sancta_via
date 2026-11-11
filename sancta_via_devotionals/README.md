# Sancta Via Devotionals

An offline-first Catholic devotional app built with Flutter, part of the Sancta Via
melos workspace. This app hosts the Today pipeline, guided prayer sessions, and
commitment trackers powered by the shared `sancta_via_devotional_engine` packages.

## Features

### 📖 **Today Pipeline**
- Single daily surface assembling devotional content by day-of-program
- Liturgical-calendar-aware content curation

### 🙏 **Guided Prayer Sessions**
- Step-by-step guided sessions driven by devotional engine programs
- Progress tracking with restart policies and substitution rules

### ⭐ **Commitment Trackers**
- 54-day novena-style tracks with per-anchor completion checkpoints

## Getting Started

Run from the workspace root (`melos` manages path-dependency linking):

```bash
melos bootstrap
cd sancta_via_devotionals
flutter run
```

Or simply:

```bash
cd sancta_via_devotionals
flutter run
```

> **Note:** On first checkout, run `melos bootstrap` from the workspace root so the
> path dependencies (`sancta_via_devotional_engine`, `sancta_via_shared_ui`, etc.)
> resolve.

## Build & Test

The Makefile provides convenience targets (see the sibling apps for the full set):

```bash
make deps      # flutter pub get
make test      # Run tests
make analyze   # Static analysis
make format    # Format code
make clean     # Clean build artifacts
make build-android  # Build release APK
make build-ios      # Build iOS release (macOS only)
```

## Architecture

- `lib/main.dart` — application entry point (root `ProviderScope` → `MaterialApp.router`)
- `lib/config/routes.dart` — GoRouter configuration (`today` route at `/`)
- `lib/screens/` — feature screens
- Path dependencies link the shared Sancta Via engine/UI/data packages
- Database layer uses `sqflite` with `flutter_local_notifications` + `timezone`
  for scheduled reminders

## Related Packages

- `../sancta_via_devotional_engine` — core devotional domain logic
- `../sancta_via_devotional_engine_riverpod` — Riverpod bindings for the engine
- `../sancta_via_liturgical_calendar` (+ `_riverpod`) — liturgical calendar data
- `../sancta_via_bible_data` (+ `_riverpod`) — Bible content
- `../sancta_via_shared_ui` — shared theming and settings components
