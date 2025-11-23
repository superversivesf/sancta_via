# AGENTS.md - Quick Reference for AI Coding Agents

## Commands
- **Run app**: `flutter run` (use `-d chrome`, `-d macos`, etc. for specific platforms)
- **Test all**: `flutter test`
- **Test single file**: `flutter test test/path/to/test_file.dart`
- **Lint**: `flutter analyze`
- **Build**: `flutter build apk --release` (or `ios`, `web`)

## Code Style (analysis_options.yaml)
- **Strings**: Single quotes (`'text'`)
- **Trailing commas**: Required on all function/constructor calls
- **Immutability**: Prefer `const` constructors, `final` fields/locals
- **Types**: No implicit casts/dynamic (`implicit-casts: false`)
- **Prints**: Allowed for debugging (use `AppLogger` for production)

## Import Order
1. Dart/Flutter SDK imports (`dart:*`, `package:flutter/*`)
2. External package imports (`package:*/`)
3. Relative imports (`../models/*`, `../services/*`)
4. Blank line between groups

## Architecture Patterns
- **State**: Riverpod providers (`flutter_riverpod`) - never use StatefulWidget for business logic
- **Settings**: Use `prayerAppSettingsProvider` (NOT deprecated repository methods)
- **Database**: Always use `PrayerRepository`, never query `PrayerDatabase` directly
- **Navigation**: GoRouter (`lib/config/routes.dart`)

## Dependencies
This app depends on sibling packages: `sancta_via_shared_ui`, `sancta_via_liturgical_calendar`, `sancta_via_liturgical_calendar_riverpod`. Run `flutter pub get` after modifying them.
