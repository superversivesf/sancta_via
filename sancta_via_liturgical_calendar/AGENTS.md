# AGENTS.md

## Build/Lint/Test Commands

```bash
# Install dependencies
dart pub get

# Run static analysis
dart analyze

# Format code
dart format .

# Run all tests
dart test

# Run specific test file
dart test test/liturgical_calendar_test.dart

# Run specific test by name
dart test --name "test_name"

# Build example
dart compile exe example/liturgical_calendar_example.dart
```

## Code Style Guidelines

### Types & Formatting
- **Prefer `final`** over `var` and use const constructors where possible
- **Single quotes** for strings: `'string'` not `"string"`
- **Trailing commas** for all collection literals and function parameters
- **Import order**: dart libraries → package imports → relative imports
- **Explicit types**: Avoid `dynamic` - use concrete types

### Naming Conventions
- **Classes/Enums**: `PascalCase` (e.g., `LiturgicalCelebration`)
- **Variables/Functions**: `camelCase` (e.g., `getCelebrationForDate`)
- **Constants**: `SCREAMING_SNAKE_CASE` (e.g., `LITURGICAL_COLORS`)
- **Private members**: `_prefix` with underscore (e.g., `_cachedData`)

### Error Handling
- Use try/catch for date parsing errors
- Return null for missing data instead of throwing exceptions
- Add meaningful error messages for debugging

### Generated Code
- Data files in `lib/src/data/generated/` are auto-generated from Romcal
- Do not manually edit generated files - use `tool/build_generated_data.dart`
- Generated files contain 12 years of liturgical calendar data (2024-2035)