# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Sancta Via Prayer Companion is a Flutter-based Catholic prayer app featuring 60+ traditional prayers with liturgical calendar integration. Part of the Sancta Via ecosystem, it demonstrates shared UI components, liturgical theming, and modern prayer management.

## Development Commands

### Setup & Dependencies
```bash
flutter pub get                         # Install dependencies
make deps                               # Alias via Makefile
```

### Running the App
```bash
flutter run                             # Run on connected device/emulator
flutter run -d chrome                   # Run on web (hot reload supported)
flutter run -d macos                    # Run on macOS
flutter run -d windows                  # Run on Windows
```

### Building for Release
```bash
flutter build apk --release             # Android APK (release)
flutter build ios --release             # iOS build (release)
flutter build web --release             # Web production build
make build-android                      # Alias via Makefile
make build-ios                          # Alias via Makefile
make build-web                          # Alias via Makefile
```

### Code Quality & Testing
```bash
flutter analyze                         # Run static analysis (lints & type checking)
flutter test                            # Run all tests
flutter test test/path/to/test.dart     # Run single test file
flutter test --name "pattern"           # Run tests matching name pattern
make analyze                            # Alias via Makefile
make test                               # Alias via Makefile
```

### Formatting & Cleanup
```bash
dart format .                           # Auto-format code (required before commits)
make format                             # Alias via Makefile
flutter clean                           # Delete build artifacts
make clean                              # Alias via Makefile
```

### Other Commands
```bash
flutter pub run flutter_launcher_icons  # Generate app icons
flutter pub run cider bump patch        # Bump patch version (1.0.0 → 1.0.1)
flutter pub run cider bump minor        # Bump minor version (1.0.0 → 1.1.0)
flutter pub run cider bump major        # Bump major version (1.0.0 → 2.0.0)
```

## Architecture

### Layered Architecture (Bottom to Top)

```
┌─────────────────────────────────────────────┐
│ UI Layer (Screens & Widgets)                │ lib/screens/, lib/widgets/
├─────────────────────────────────────────────┤
│ Provider Layer (Riverpod State)             │ lib/providers/
├─────────────────────────────────────────────┤
│ Service Layer (Business Logic)              │ lib/services/
├─────────────────────────────────────────────┤
│ Repository Layer (Data Access)              │ lib/repositories/
├─────────────────────────────────────────────┤
│ Database Layer (SQLite)                     │ lib/database/
├─────────────────────────────────────────────┤
│ Model Layer (Data Structures)               │ lib/models/
└─────────────────────────────────────────────┘
```

**Model Layer** (`lib/models/`)
- `prayer.dart` - Prayer entity with translations, liturgical metadata, timeOfDay field
- `prayer_category.dart` - Prayer categorization
- `prayer_category_group.dart` - Top-level category groupings
- `prayer_app_settings.dart` - User preferences (favorites, recent, font size, etc.)
- `prayer_time_of_day.dart` - Enum for time-of-day categorization (morning/afternoon/evening/night/anytime)

**Database Layer** (`lib/database/`)
- `prayer_database.dart` - SQLite schema and query methods
  - Tables: `prayers`, `categories`, `category_groups`, `prayer_categories`, `prayer_tags`, `prayer_translations`
  - Indexes on frequently queried columns (category, tags, time_of_day)
  - Database version 2 (added time_of_day support)
- `database_migration_service.dart` - One-time JSON→SQLite migration on first app launch
  - Checks via `isMigrationNeeded()`, executes via `migrateJsonToDatabase()`
  - Handles new fields gracefully (defaults applied for prayers without new fields)

**Repository Layer** (`lib/repositories/`)
- `prayer_repository.dart` - Singleton data access layer with built-in caching
  - Automatically triggers migration on first data access
  - Methods: `getPrayers()`, `getCategoryGroups()`, `getPrayersByCategory()`, `getPrayersForTimeOfDay()`, etc.
  - Caches results in memory (`_cachedPrayers`, `_cachedCategories`, etc.)
  - Never query database directly—always use repository

**Service Layer** (`lib/services/`)
- `prayer_of_the_day_service.dart` - Liturgical prayer selection logic
  - Priority: Feast days/solemnities > Seasonal prayers (Advent/Lent/Easter) > Ordinary time daily rotation
  - Uses `LiturgicalDayData` from `sancta_via_liturgical_calendar` for date-aware selection
- `time_of_day_prayer_service.dart` - Random prayer selection by current time of day
  - Date-seeded selection for consistency within a day
  - Only selects from exact time-of-day category (no anytime fallback during specific times)
  - Timestamp-seeded selection for manual refresh

**Provider Layer** (`lib/providers/`) - Riverpod 2.6.1 state management
- `prayer_providers.dart` - Core data providers
  - `allPrayersProvider` - Fetches all prayers from repository
  - `categoriesProvider`, `categoryGroupsProvider` - Category data
  - `prayerSearchProvider` - Search/filter state and results
  - `selectedCategoryProvider` - UI state for selected category
- `prayer_app_settings_provider.dart` - Unified settings management (NotifierProvider)
  - Methods: `toggleFavorite()`, `addRecentPrayer()`, `updateFontSize()`, etc.
  - Auto-persists to SharedPreferences
  - Single source of truth for all user preferences
- `text_scaling_provider.dart` - Accessibility text scaling
- `time_of_day_prayer_providers.dart` - Time-of-day specific providers
  - `currentTimeOfDayProvider`, `timeOfDayPrayersProvider`, `dailyTimeOfDayPrayerProvider`
  - Integrates with `TimeOfDayPrayerService` for selection logic
- Integrates with `sancta_via_liturgical_calendar_riverpod` for liturgical calendar data
- Integrates with `sancta_via_shared_ui` providers for theming (themeModeProvider, colorIntensityProvider)

**UI Layer** (`lib/screens/` & `lib/widgets/`)
- Screens: home, prayer (list/detail), categories, search, settings
- Reusable widgets: `PrayerCard`, `TimeOfDayPrayerCard`, `FontSizeSelector`, `EnhancedPrayerText`
- Navigation via GoRouter (`lib/config/routes.dart`)

### Dependency Structure

**Core Framework**
- `flutter_riverpod: ^2.6.1` - State management (never use StatefulWidget for business logic)
- `go_router: ^15.1.2` - Navigation (GoRouter in lib/config/routes.dart)
- `sqflite: ^2.3.3` - SQLite database access
- `shared_preferences: ^2.5.3` - User preferences persistence

**Sancta Via Ecosystem (path dependencies - monorepo)**
- `sancta_via_shared_ui` - Shared UI components, AppTheme with liturgical colors
  - Provides: `AppTheme.lightTheme()`, `AppTheme.darkTheme()`, reusable widgets, liturgical color definitions
  - Providers: `themeModeProvider`, `colorIntensityProvider`
- `sancta_via_liturgical_calendar` - Pure Dart library with Catholic liturgical calendar data (12 years)
  - Provides: `LiturgicalDayData`, liturgical season/color lookup by date
- `sancta_via_liturgical_calendar_riverpod` - Riverpod providers wrapping liturgical calendar
  - Provides: `currentLiturgicalColorProvider`, `currentLiturgicalSeasonProvider`, etc.

**IMPORTANT - Shared Package Integration**:
1. When modifying shared packages, run `flutter pub get` in this app to sync path dependencies
2. Liturgical theming is automatic: `main.dart` watches `currentLiturgicalColorProvider` and applies theme
3. Always import from shared packages via `package:` imports, not relative paths
4. Do not mock liturgical calendar providers—they're essential for app function and color selection

### Prayer Data Flow

**Initial Load**:
1. App starts → main.dart initializes ProviderScope
2. First prayer access → PrayerRepository._ensureMigrationComplete()
3. DatabaseMigrationService checks if SQLite database is populated
4. If empty, migrates from `assets/prayers/*.json` to SQLite
5. Repository caches prayers, categories, groups in memory

**Prayer Structure** (assets/prayers/):
- Individual prayer files: `{prayer_id}.json` with translations, attribution, liturgical metadata
- Each prayer JSON includes: id, title, text, translation (map), attribution, notes, categories, description, tags, isLiturgical, liturgicalPriority, liturgicalSeason
- Example: act_of_contrition.json contains English text and Latin translation

**Database Schema**:
- `prayers` table: Core prayer data with liturgical fields
- `categories` table: Prayer categories linked to groups
- `category_groups` table: Top-level groupings
- `prayer_categories` junction: Many-to-many prayer↔category
- `prayer_tags` junction: Many-to-many prayer↔tags
- `prayer_translations` table: Prayer translations by language

## Key Implementation Details

### Liturgical Integration & Dynamic Theming

The app responds dynamically to the Catholic liturgical calendar:

```dart
// main.dart - Automatic liturgical theming
final currentLiturgicalColor = ref.watch(currentLiturgicalColorProvider);
final liturgicalColor = currentLiturgicalColor != null
    ? LiturgicalColor.fromString(currentLiturgicalColor)
    : null;
theme: AppTheme.lightTheme(liturgicalColor, colorIntensity),
darkTheme: AppTheme.darkTheme(liturgicalColor, colorIntensity),
```

App colors change based on liturgical season:
- **Green** (Ordinary Time), **Purple** (Advent/Lent), **Rose** (special Sundays), **White** (Christmas/Easter), **Red** (Pentecost/Martyrs), **Gold** (High Feasts)
- User can select "vibrant" or "muted" intensity via settings
- All providers automatically reflect color/season changes

**Prayer of the Day Selection** (`lib/services/prayer_of_the_day_service.dart`):
1. Checks for major feast days/solemnities (highest priority)
2. Falls back to seasonal prayers (Advent, Lent, Easter, Pentecost, etc.)
3. Uses day-of-year rotation for Ordinary Time (consistent daily prayer)
4. Caches result per date to avoid recalculation

**Time of Day Prayers** (`lib/services/time_of_day_prayer_service.dart`):
- Categorizes prayers by time: morning (5AM-9AM), afternoon (11AM-5PM), evening (5PM-9PM), night (9PM-5AM), anytime (9AM-11AM)
- Date-seeded random selection ensures same prayer shown throughout the day
- Manually refresh with timestamp seeding for different prayer
- Each prayer belongs to exactly ONE time category

### Settings Management

**Current System** (use this):
- `prayerAppSettingsProvider` from `lib/providers/prayer_app_settings_provider.dart` (NotifierProvider)
- Unified settings: favorites, recent prayers, font size, language, reading mode
- Auto-persists to SharedPreferences via `PrayerAppSettings.save()`
- Single source of truth for all user preferences

**Deprecated** (do not use):
- `PrayerRepository.getUserPreferences()`, `.toggleFavorite()`, etc. marked @Deprecated
- `prayerPreferencesProvider` wrapper maintained for backward compatibility only

When adding settings:
1. Add field to `PrayerAppSettings` model (lib/models/prayer_app_settings.dart)
2. Add method to `PrayerAppSettingsNotifier` (lib/providers/prayer_app_settings_provider.dart)
3. Update `save()` and `fromSharedPreferences()` serialization
4. Never use repository methods for preferences

### Database & Migration

**One-Time Automatic Migration**:
- First app launch: `DatabaseMigrationService.isMigrationNeeded()` checks if database is empty
- If needed: `migrateJsonToDatabase()` loads JSON assets → SQLite
- Repository flag `_migrationChecked` prevents redundant checks per session
- New fields added to prayers default gracefully (e.g., `timeOfDay` defaults to 'anytime')

**For Development**:
- Call `repository.forceMigration()` to re-run migration after JSON changes
- Or delete app and reinstall to trigger automatic migration
- Or restart app with debug settings (if implemented)

**Schema Evolution**:
- Database version 2 added `time_of_day` column to `prayers` table
- Migration service handles missing columns via Prayer model defaults
- Add indexes when adding frequently-queried columns

### Code Standards & Style

From `analysis_options.yaml` and project conventions:
- **Strings**: Single quotes (`'text'`) not double quotes
- **Trailing commas**: Required on all function/constructor calls and collections
- **Immutability**: Prefer `const` constructors and `final` fields/locals
- **Types**: Explicit types (no `var` or `dynamic`), implicit casts disabled
- **Imports**: Group by dart → package → relative, with blank lines between
- **Prints**: Allowed for debugging (prefer `AppLogger` in `lib/utils/logger.dart` for production)

## Adding New Prayers

**Process**:
1. Create prayer JSON file: `assets/prayers/{prayer_id}.json`
2. Include required fields:
   ```json
   {
     "id": "unique_id",
     "title": "Prayer Title",
     "text": "Prayer text in English",
     "categories": ["category1", "category2"],
     "description": "Brief description for UI",
     "tags": ["tag1", "tag2"],
     "timeOfDay": "morning"
   }
   ```
3. Optional fields (with defaults if omitted):
   - `translation`: Object with language keys mapping to translated text (e.g., `{"latin": "..."}`)
   - `attribution`: Prayer author or source
   - `notes`: Additional context
   - `isLiturgical`: Boolean, whether prayer is liturgical
   - `liturgicalPriority`: Priority level for prayer selection
   - `liturgicalSeason`: Seasonal association ("advent", "lent", "easter", etc.)
   - `timeOfDay`: Time category ("morning", "afternoon", "evening", "night", "anytime"); defaults to "anytime"

4. Trigger migration:
   - **Development**: Call `repository.forceMigration()` or restart app
   - **Testing**: Delete app and reinstall
   - **Automated**: Happens automatically on first data access if database is empty

5. Prayer appears automatically in app—category pages, search, time-of-day rotation, etc.

**Example Prayer JSON** (act_of_contrition.json):
```json
{
  "id": "act_of_contrition",
  "title": "Act of Contrition",
  "text": "O my God, I am heartily sorry for having offended You...",
  "translation": {
    "latin": "Deus meus, ex toto corde meum me paenitet..."
  },
  "categories": ["core_prayers", "sacramental"],
  "description": "Traditional expression of repentance",
  "tags": ["repentance", "confession", "contrition"],
  "timeOfDay": "anytime",
  "isLiturgical": true
}
```

## Common Pitfalls & Troubleshooting

1. **Repository as Single Source of Truth**
   - WRONG: Query `PrayerDatabase` directly in widgets or services
   - RIGHT: Always use `PrayerRepository.instance.getPrayers()` or related methods
   - Why: Repository handles caching, ensures data consistency, and manages migration state

2. **Migration & JSON Changes**
   - Issue: Added new prayer JSON but it doesn't appear in app
   - Cause: Migration runs once per session and only checks if database is empty
   - Solution: Call `repository.forceMigration()` in debug, or restart app, or delete/reinstall app

3. **Shared Package Updates**
   - After modifying `sancta_via_shared_ui`, `sancta_via_liturgical_calendar`, or related packages:
   - Run `flutter pub get` to sync path dependencies
   - Rebuild/reload the app
   - Without this, changes won't be visible

4. **Provider Caching**
   - Repository caches prayers/categories in memory (`_cachedPrayers`, etc.)
   - After direct database changes: Call `repository.clearCache()` to force refresh
   - Provider watchers automatically update when repository returns new data

5. **Liturgical Calendar Providers**
   - WRONG: Mocking `currentLiturgicalColorProvider` in tests
   - RIGHT: Let liturgical providers run naturally (they're fast, essential for app function)
   - Why: Prayer selection, theming, and seasonal content depend on accurate liturgical data
   - If needed: Override with specific date via `LiturgicalCalendar.instance.getDayData(DateTime.parse('2024-12-25'))`

6. **Settings Management**
   - WRONG: Using `repository.toggleFavorite()` or `getUserPreferences()`
   - RIGHT: Using `ref.read(prayerAppSettingsProvider.notifier).toggleFavorite(prayerId)`
   - Why: Old methods are deprecated; new NotifierProvider is the single source of truth

7. **Testing Strategy**
   - Unit tests: No app context needed (test services, models)
   - Integration tests: Use in-memory SQLite database via dependency injection
   - Provider tests: Use `ProviderContainer` with carefully chosen overrides
   - Widget tests: Mock only necessary providers; let liturgical providers run

## Testing Guide

**Running Tests**:
```bash
flutter test                              # All tests
flutter test test/models/prayer_test.dart # Specific file
flutter test --name "Prayer"              # By name pattern
flutter test test/ -k "not widget"        # Exclude tests by pattern
```

**Test Structure**:
- `test/models/` - Model serialization/deserialization tests
- `test/repositories/` - Repository with mocked database tests
- `test/services/` - Business logic (prayer selection, time-of-day logic)
- `test/providers/` - Riverpod provider tests with ProviderContainer
- `test/widgets/` - Widget tests with test-specific overrides

**Mocking Database**:
```dart
// For repository tests, inject in-memory SQLite via constructor
final testDb = await openDatabaseSync(':memory:');
await PrayerDatabase(testDb).createTables();
final repository = PrayerRepository.withDatabase(testDb);
```

**Mocking Providers**:
```dart
// Use ProviderContainer with overrides
final container = ProviderContainer(
  overrides: [
    selectedCategoryProvider.overrideWithValue('category1'),
    // Let other providers run naturally
  ],
);
expect(container.read(someProvider), expectedValue);
```

**Current Test Coverage**: 69 tests, all passing
- Repository tests use dependency-injected mock database
- Only 2 intentional error messages (from error handling tests)
