# AGENTS.md - SanctaVia Development Guide

## Monorepo Commands (Melos)
```bash
melos bootstrap          # Install dependencies for all packages
melos run analyze        # Run static analysis on all packages
melos run format         # Format all packages
melos run test           # Run all tests
melos run build:android  # Build Android APKs for all apps
```

## Per-Package Commands
### Flutter Apps (prayer/novena/confession/fasting companion, bible reading app)
```bash
make deps                             # flutter pub get
make format                           # dart format .
make analyze                          # flutter analyze
make test                             # flutter test
flutter test test/path/to_test.dart   # Single test file
flutter test --name "pattern"         # Tests matching pattern
make build-android                    # Build Android APK
```

### Pure Dart Packages (bible_data, liturgical_calendar, shared_ui)
```bash
dart pub get                           # Install dependencies
dart format .                          # Format code
dart analyze                           # Static analysis
dart test                              # Run all tests
dart test test/file_test.dart         # Single test file
```

## Code Style Guidelines
- **Quotes**: Single quotes only (`'string'`)
- **Commas**: Trailing commas required for parameters/collections
- **Imports**: dart libraries → packages → relative imports (sorted)
- **Naming**: Classes(PascalCase), variables/fields(camelCase), constants(SCREAMING_SNAKE)
- **Types**: Prefer `final`, explicit types (avoid `var`/`dynamic`)
- **Constructors**: Use `const`, include `key` parameter for widgets
- **Error handling**: `try/catch` with `AppLogger.error(message, e, stackTrace)`
- **No print statements**: Use `AppLogger.debug/info/warning/error()`
- **Prefer**: null-aware operators (`??`, `?.`), collection if/for