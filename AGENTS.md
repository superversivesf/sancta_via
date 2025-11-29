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
### Flutter Apps (prayer/novena/confession companion)
```bash
make deps                             # flutter pub get
make format                           # dart format .
make analyze                          # flutter analyze
make test                             # flutter test
flutter test test/path/to_test.dart  # Single test file
flutter test --name "pattern"        # Tests matching pattern
make build-android                   # Build Android APK
```

### Pure Dart Library (sancta_via_liturgical_calendar)
```bash
dart pub get                               # Install dependencies
dart analyze                              # Static analysis
dart format .                            # Format code
dart test                                # Run all tests
dart test test/file_test.dart          # Single test file
```

## Code Style Guidelines
- **Single quotes only**: `'string'` not `"string"`
- **Trailing commas required** for parameters and collections
- **Import order**: dart libraries → packages → relative imports
- **Naming**: Classes(PascalCase), variables(camelCase), constants(SCREAMING_SNAKE)
- **Types**: Prefer `final`, use explicit types (avoid `var`/`dynamic`)
- **Constructors**: Use `const` and include `key` parameter for widgets
- **Error handling**: `try/catch` with `AppLogger.error(message, e, stackTrace