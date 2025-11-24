# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**SanctaVia** is a monorepo containing a comprehensive ecosystem of Flutter-based Catholic mobile and web applications focused on prayer, scripture reading, and liturgical awareness. The project emphasizes combining Catholic tradition with contemporary technology, with dynamic theming based on the Church's liturgical calendar.

### Core Apps
- **sancta_via_prayer_companion** - Prayer app with 60+ traditional prayers
- **sancta_via_bible_reading_app** - Bible reader with multiple Catholic translations
- **sancta_via_liturgical_calendar_app** - Liturgical calendar viewer
- **sancta_via_confession_companion** - Examination of conscience and confessional guidance
- **sancta_via_novena_companion** - Novena prayers and devotional guidance

### Shared Libraries (Critical Dependencies)
- **sancta_via_shared_ui** - Reusable UI components with automatic liturgical theming
- **sancta_via_liturgical_calendar** - Pure Dart library with 12 years of Catholic liturgical calendar data
- **sancta_via_liturgical_calendar_riverpod** - Riverpod providers for liturgical calendar
- **sancta_via_bible_data** - Catholic Bible texts (3 translations) with search
- **sancta_via_bible_data_riverpod** - Riverpod providers for Bible data

## Development Commands

### Build and Test (Makefile targets available in each app directory)
```bash
make deps              # flutter pub get (install dependencies)
make clean             # flutter clean
make format            # dart format .
make analyze           # flutter analyze
make test              # flutter test
make build-android     # flutter build apk --release
make build-ios         # flutter build ios --release
make build-web         # flutter build web --release
```

### Running Apps
```bash
flutter run                    # Run on connected device
flutter run -d chrome          # Run on web
flutter run -d macos           # Run on macOS
flutter run -d windows         # Run on Windows
```

### Running Tests
```bash
flutter test                                    # All tests
flutter test test/path/to/test.dart            # Specific file
flutter test --name "test name"                # By name pattern
```

### Multi-Project Release Build
```bash
./build-release.sh --patch      # Bump patch version, build all apps
./build-release.sh --minor      # Bump minor version
./build-release.sh --major      # Bump major version
./build-release.sh --dry-run    # Preview without building
```

## Code Architecture

### Layered Architecture (Bottom to Top)
1. **Data Layer** - SQLite database, asset files
2. **Repository Layer** - Single source of truth with caching
3. **Service Layer** - Business logic and specialized services
4. **Provider Layer** - Riverpod state management
5. **UI Layer** - Screens and widgets

### Key Architectural Patterns

#### Repository Pattern
- Located in `lib/repositories/`
- Singleton instance via static `instance` property
- Built-in caching with nullable fields (`_cachedData`)
- Automatic migration from JSON assets to SQLite on first run
- All data access flows through repository (no direct DB queries)

Example structure:
```dart
class PrayerRepository {
  static final PrayerRepository _instance = PrayerRepository._internal();
  static PrayerRepository get instance => _instance;

  List<Prayer>? _cachedPrayers;

  Future<List<Prayer>> getPrayers() async {
    if (_cachedPrayers != null) return _cachedPrayers!;
    _cachedPrayers = await _database.queryAllPrayers();
    return _cachedPrayers!;
  }
}
```

#### Provider Pattern (Riverpod)
- Located in `lib/providers/`
- Use `NotifierProvider` for complex state
- Simple providers for read-only data access
- Theme providers integrated with liturgical calendar

#### Dependency Injection
- Shared packages used via path dependencies: `path: ../sancta_via_[package]`
- Monorepo structure allows development without pub.dev publishing

#### Liturgical Integration
All apps dynamically theme based on the Church's liturgical calendar. Colors include: Green (Ordinary Time), Purple (Advent/Lent), Rose (special Sundays), White (Christmas/Easter), Red (Pentecost/Martyrs), Gold (High Feasts). Colors support "vibrant" and "muted" intensity options.

### Database Architecture
- **SQLite** for persistent storage (via sqflite)
- **One-time automatic migration** on first app run (checks if database is populated)
- Prayer/Bible data loaded from JSON assets → SQLite on first run
- Each app has its own database schema
- Force re-migration in development via `repository.forceMigration()`

### State Management
- **Riverpod 2.6.1** for reactive state management
- **SharedPreferences** for user preferences and settings
- Use `ProviderContainer` with overrides for testing
- **Do not mock liturgical calendar providers** - they're essential for app function

## Code Style and Standards

From `AGENTS.md` and `analysis_options.yaml`:

### Formatting and Imports
- **Single quotes** for strings: `'string'` not `"string"`
- **Trailing commas** required for collections and parameters
- **Relative imports**: `import '../models/prayer.dart'`
- **Group imports**: dart → package → local
- Run `dart format .` to auto-format

### Naming
- `PascalCase` for classes, enums, typedefs
- `camelCase` for variables, functions, methods
- `SCREAMING_SNAKE_CASE` for constants
- Private members prefixed with `_`

### Types and Null Safety
- **Final locals and fields** when possible
- **Const constructors** for widgets
- Explicit types (avoid `var` and `dynamic`)
- Null-aware operators: `?.`, `??`, `??=`
- Implicit casts disabled

### Flutter-Specific
- Always use keys in widget constructors
- Avoid unnecessary containers
- Use SizedBox for spacing, not Padding/Container
- Prefer const constructors and literals

### Error Handling
```dart
try {
  // operation
  return result;
} catch (e) {
  AppLogger.error('Error message', e, null, 'TAG');
  return defaultValue;  // empty list, null, etc.
}
```

### Logging
Use `AppLogger` for all logging:
- `AppLogger.debug(msg, tag)` - debug only
- `AppLogger.info(msg, tag)` - info only
- `AppLogger.warning(msg, tag)` - warnings
- `AppLogger.error(msg, error, stackTrace, tag)` - errors

## File Organization Within Apps

Typical app directory structure:
```
lib/
├── main.dart                              # Entry point with ProviderScope
├── config/
│   └── routes.dart                        # GoRouter setup
├── database/
│   ├── [type]_database.dart              # SQLite schema & queries
│   └── database_migration_service.dart
├── models/
│   └── [data_models].dart
├── providers/
│   ├── [type]_providers.dart
│   └── settings_provider.dart
├── repositories/
│   └── [type]_repository.dart
├── screens/
│   ├── category/
│   ├── home/
│   ├── detail/
│   └── settings/
├── services/
│   └── [business_logic_services].dart
└── widgets/
    └── [reusable_widgets].dart
```

## Testing

### Test Organization
- Test files in `test/` directory at app root
- Use in-memory SQLite for isolated database tests
- Mock providers with `ProviderContainer` overrides
- **Don't mock**: Liturgical calendar providers (essential)

### Running Tests
```bash
flutter test                     # All tests
flutter test test/path/file.dart # Specific file
flutter test --name "pattern"    # By name
```

### CI/CD Testing
- GitHub Actions workflow in `.github/workflows/flutter.yml`
- Runs on push to main and PRs
- Tests: analyze, flutter test, build validation
- Ubuntu for Android/Web, macOS for iOS

## Important Implementation Notes

### Database Initialization
Apps use `DatabaseMigrationService` to check if initial migration is needed:
```dart
bool isMigrationNeeded = await DatabaseMigrationService.isMigrationNeeded();
if (isMigrationNeeded) {
  await repository.performInitialMigration();
}
```

### Settings Architecture
Use the unified `[AppName]SettingsProvider` (NotifierProvider) which:
- Persists to SharedPreferences automatically
- Manages favorites, recent items, font size, language, reading mode
- Provides reactive updates when settings change

### Version Management
Use `cider` for semantic versioning:
```bash
flutter pub run cider bump patch  # 1.0.0 → 1.0.1
flutter pub run cider bump minor  # 1.0.0 → 1.1.0
flutter pub run cider bump major  # 1.0.0 → 2.0.0
```
Version stored in `pubspec.yaml` as `version: X.Y.Z+B` format.

## Shared Package Integration

When adding features to shared libraries:
1. Make changes in the shared package directory (e.g., `sancta_via_shared_ui/`)
2. Run `flutter pub get` in apps that depend on it (path dependency)
3. Changes are reflected immediately in dependent apps

## Documentation Files

- **`AGENTS.md`** - Build commands, code style, architecture patterns, error handling
- **`CLAUDE.md`** (this file) - High-level architecture and development guidance
- **`README.md`** (per-app) - Features, setup, getting started
- **`TESTING_GUIDE.md`** (apps with complex features) - Testing patterns and examples
- Migration docs - For schema/structure changes (e.g., `SQLITE_MIGRATION_COMPLETE.md`)

## Quick Start for New Development

1. Navigate to the app directory (e.g., `cd sancta_via_prayer_companion`)
2. Run `flutter pub get` or `make deps`
3. Run `flutter run` or check `README.md` for the app
4. For shared package changes, re-run `flutter pub get` in dependent apps
5. Run tests with `flutter test` or `make test`
6. Run `dart format .` and `flutter analyze` before committing
