# AGENTS.md - SanctaVia Development Guide

## Build & Test Commands

```bash
# In any app directory (sancta_via_prayer_companion, etc.)
make deps                                    # Install dependencies (flutter pub get)
make format                                  # Format code (dart format .)
make analyze                                 # Static analysis (flutter analyze)
make test                                    # Run all tests (flutter test)
flutter test test/path/to/test.dart         # Run single test file
flutter test --name "test name pattern"     # Run tests matching pattern
make build-android                          # Build Android APK
make build-web                              # Build web version
flutter run                                  # Run app on connected device
flutter run -d chrome                       # Run on web browser
```

## Code Style Guidelines

### Imports & Formatting
- **Single quotes only**: `'string'` not `"string"`
- **Trailing commas required** for all function parameters and collection literals
- **Import order**: dart libraries → package imports → relative imports
- **Relative imports**: Use `../models/prayer.dart` not package imports for local files
- Run `dart format .` before committing (enforced by `analysis_options.yaml`)

### Naming Conventions
- **Classes/Enums/Typedefs**: `PascalCase` (e.g., `PrayerDatabase`, `LiturgicalSeason`)
- **Variables/Functions/Methods**: `camelCase` (e.g., `getPrayers`, `categoryId`)
- **Constants**: `SCREAMING_SNAKE_CASE` (e.g., `_DATABASE_VERSION`)
- **Private members**: Prefix with `_` (e.g., `_cachedPrayers`, `_instance`)

### Types & Null Safety
- **Prefer `final`** for local variables and class fields whenever possible
- **Const constructors** for widgets and immutable objects
- **Explicit types**: Avoid `var` and `dynamic` - use concrete types
- **Null-aware operators**: Use `?.`, `??`, `??=` appropriately
- **No implicit casts** (enforced by `implicit-casts: false`)

### Flutter Best Practices
- **Widget keys**: Use `key` parameter in all widget constructors (`use_key_in_widget_constructors`)
- **Const widgets**: Prefer `const` constructors (`prefer_const_constructors`)
- **SizedBox for spacing**: Use `SizedBox` instead of `Container` or `Padding` for whitespace
- **Avoid unnecessary containers** (`avoid_unnecessary_containers`)

### Error Handling & Logging
```dart
try {
  final result = await repository.getData();
  return result;
} catch (e, stackTrace) {
  AppLogger.error('Failed to load data', e, stackTrace, 'TAG_NAME');
  return []; // Return safe default (empty list, null, etc.)
}
```

Use `AppLogger` from `sancta_via_shared_ui`:
- `AppLogger.debug(message, tag)` - Debug info (dev only)
- `AppLogger.info(message, tag)` - General info
- `AppLogger.warning(message, tag)` - Warnings
- `AppLogger.error(message, error, stackTrace, tag)` - Errors with stack traces

### Architecture Patterns
- **Repository Pattern**: Single source of truth with caching; all data access through repositories
- **Singleton repositories**: Use `static final instance` pattern
- **Riverpod providers**: Use `NotifierProvider` for stateful, `Provider` for read-only
- **Relative paths for shared packages**: `path: ../sancta_via_liturgical_calendar` in `pubspec.yaml`

### Version Management
```bash
# Use cider for semantic versioning
flutter pub run cider bump patch  # 1.0.0 → 1.0.1
flutter pub run cider bump minor  # 1.0.0 → 1.1.0
flutter pub run cider bump major  # 1.0.0 → 2.0.0
```

## Testing Guidelines
- Test files mirror source structure in `test/` directory
- Use in-memory SQLite for database tests
- Mock providers with `ProviderContainer` overrides
- **DO NOT mock** liturgical calendar providers (core functionality)

## File Organization
```
lib/
├── main.dart                    # App entry with ProviderScope
├── config/routes.dart          # GoRouter configuration
├── database/                   # SQLite schema & queries
├── models/                     # Data models
├── providers/                  # Riverpod state management
├── repositories/               # Data access layer (singleton pattern)
├── screens/                    # UI screens (grouped by feature)
├── services/                   # Business logic
└── widgets/                    # Reusable UI components
```

## Important Notes
- This is a **monorepo** with multiple Flutter apps and shared libraries
- Apps dynamically theme based on Catholic liturgical calendar (Green, Purple, Rose, White, Red, Gold)
- SQLite migration happens automatically on first app run from JSON assets
- All apps share `sancta_via_shared_ui` for common components and theming
- Analysis rules enforced via `analysis_options.yaml` (single quotes, trailing commas, const, etc.)
