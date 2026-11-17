# AGENTS.md - Quick Reference for AI Coding Agents

## Commands

### Running Apps
```bash
flutter run                    # Run on connected device
flutter run -d chrome          # Run on web
flutter run -d macos           # Run on macOS
```

### Testing
```bash
flutter test                                    # All tests
flutter test test/path/to/test_file.dart       # Single test file
flutter test --name "test name"                # By name pattern
```

### Linting & Formatting
```bash
flutter analyze               # Static analysis
dart format .                 # Auto-format code
```

### Build Commands (per app)
```bash
make deps              # flutter pub get
make test              # Run tests
make analyze           # Static analysis
make format            # Format code
make build-android     # Build APK release
make build-ios         # Build iOS release
make build-web         # Build web release
```

### Multi-Project Release
```bash
./build-release.sh --patch      # Bump patch version
./build-release.sh --minor      # Bump minor version
./build-release.sh --dry-run    # Preview without building
```

## Code Style (from analysis_options.yaml)

### Strings & Formatting
- **Single quotes**: `'text'` not `"text"`
- **Trailing commas**: Required on all function/constructor calls
- **Sort dependencies**: `sort_pub_dependencies: true`

### Types & Null Safety
- **No implicit casts**: `implicit-casts: false`
- **No implicit dynamic**: `implicit-dynamic: false`
- **Prefer explicit types**: Avoid `var` and `dynamic`
- **Final by default**: `prefer_final_fields`, `prefer_final_locals`
- **Const constructors**: `prefer_const_constructors`, `prefer_const_literals_to_create_immutables`

### Flutter Conventions
- **Use keys in widgets**: `use_key_in_widget_constructors: true`
- **Avoid unnecessary containers**: `avoid_unnecessary_containers: true`
- **SizedBox for spacing**: `sized_box_for_whitespace: true`

### Naming
- `PascalCase` for classes, enums, typedefs
- `camelCase` for variables, functions, methods
- `SCREAMING_SNAKE_CASE` for constants
- Private members prefixed with `_`

## Import Order
```dart
// 1. Dart/Flutter SDK imports
import 'dart:convert';
import 'package:flutter/material.dart';

// 2. External package imports
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// 3. Local relative imports
import '../models/prayer.dart';
import '../repositories/prayer_repository.dart';
```

Blank line between each group.

## Architecture Patterns

### Repository Pattern
- Singleton with static `instance` property
- Built-in caching with nullable fields (`_cachedData`)
- All data access flows through repository (no direct DB queries)
- Example: `PrayerRepository.instance` or inject for testing

```dart
class ExampleRepository {
  static final ExampleRepository _instance = ExampleRepository._internal();
  static ExampleRepository get instance => _instance;

  List<Example>? _cachedItems;

  Future<List<Example>> getItems() async {
    if (_cachedItems != null) return _cachedItems!;
    _cachedItems = await _database.queryAllItems();
    return _cachedItems!;
  }
}
```

### Provider Pattern (Riverpod)
- Use `FutureProvider` for async data loading
- Use `NotifierProvider` for complex state with mutations
- Use `StateProvider` for simple state

```dart
final itemsProvider = FutureProvider<List<Item>>((ref) async {
  final repository = ref.watch(repositoryProvider);
  return await repository.getItems();
});
```

### Error Handling
Always use `AppLogger` for logging:

```dart
try {
  final result = await _database.queryData();
  return result;
} catch (e) {
  AppLogger.error('Failed to load data', e, null, 'REPO');
  return [];  // Return safe default
}
```

Logger methods:
- `AppLogger.debug(message, tag)` - Debug only
- `AppLogger.info(message, tag)` - Info messages
- `AppLogger.warning(message, tag)` - Warnings
- `AppLogger.error(message, error, stackTrace, tag)` - Errors

## Release Versioning

`pubspec.yaml` versions are `major.minor.patch+build`. On every release, in this order:

1. `melos run version:bump:patch|minor|major` — cider bumps `X.Y.Z`.
   **Always pass `--bump-build` when scripting cider**: a plain cider bump ERASES the
   `+N` build number (cider 0.2.8 default), which makes the next upload ship
   `versionCode=1` and get rejected by Play. The workspace scripts below already
   pass `--bump-build` for apps.
2. `melos run version:bump:build` — increments only the `+N` build number in all app
   pubspecs, without touching `X.Y.Z` (for store-only republishes).
3. Commit the bumped app pubspecs, then build/ship via `fastlane/`.

`version:bump:build` is the only command that may be run standalone; the
`version:bump:patch|minor|major` scripts already include the build bump.

## Testing

### Regression Bar & Release Gate

`build-release.sh` refuses to build anything until **every workspace package's
test suite and `flutter analyze` are green** (`melos run analyze && melos run
test` run before the first build; any failure aborts the release non-zero).

Per-app regression bar (keep it when adding screens or features):

1. **Boot smoke** — the app renders, principal routes are reachable (widget
   test pumping the real app widget with liturgical-provider overrides).
2. **Screen tests** — the app's main flow screens.
3. **Unit tests** — services/repos with logic (scheduling, search, persistence
   round-trips). Database-backed tests run through `sqflite_common_ffi` (see
   each app's `test/flutter_test_config.dart`); platform-channel-backed
   plugins (path_provider, secure storage) get mock handlers in
   `test/helpers/platform_mocks.dart` where a screen needs them.

### Test Organization
- Test files in `test/` directory at app root
- Mirror `lib/` structure in `test/`
- Use `mockito` for mocking with `@GenerateMocks` annotation

### Mock Generation
```bash
flutter pub run build_runner build
```

### Test Example
```dart
@GenerateMocks([ExampleDatabase])
import 'example_test.mocks.dart';

void main() {
  late MockExampleDatabase mockDatabase;
  late ExampleRepository repository;

  setUp(() {
    mockDatabase = MockExampleDatabase();
    repository = ExampleRepository(database: mockDatabase);
  });

  test('returns items from database', () async {
    when(mockDatabase.getItems()).thenAnswer((_) async => []);

    final result = await repository.getItems();

    expect(result, isEmpty);
    verify(mockDatabase.getItems()).called(1);
  });
}
```

## Monorepo Dependencies

This is a monorepo with path dependencies. Shared packages:
- `sancta_via_shared_ui` - UI components with liturgical theming
- `sancta_via_liturgical_calendar` - Pure Dart liturgical calendar data
- `sancta_via_liturgical_calendar_riverpod` - Riverpod providers
- `sancta_via_bible_data` - Bible texts and search
- `sancta_via_bible_data_riverpod` - Bible providers

After modifying shared packages, run `flutter pub get` in dependent apps.

## Liturgical Theming

All apps use dynamic theming based on the Catholic liturgical calendar:
- **Green** - Ordinary Time
- **Purple** - Advent/Lent
- **Rose** - Gaudete/Laetare Sundays
- **White** - Christmas/Easter
- **Red** - Pentecost/Martyrs
- **Gold** - High Feasts

Colors support "vibrant" and "muted" intensity options via `colorIntensityProvider`.

## Settings Architecture

Use the unified `[App]SettingsProvider` (NotifierProvider) which:
- Persists to SharedPreferences automatically
- Manages favorites, recent items, font size, language, reading mode
- Provides reactive updates when settings change

## Pre-Commit Checklist

1. `dart format .`
2. `flutter analyze`
3. `flutter test`