# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Sancta Via Prayer Companion is a Flutter-based Catholic prayer app featuring 60+ traditional prayers with liturgical calendar integration. Part of the Sancta Via ecosystem, it demonstrates shared UI components, liturgical theming, and modern prayer management.

## Development Commands

### Setup
```bash
flutter pub get                    # Install dependencies
```

### Running
```bash
flutter run                        # Run on connected device/emulator
flutter run -d chrome              # Run on web
flutter run -d macos               # Run on macOS
```

### Building
```bash
flutter build apk --release        # Android APK
flutter build ios --release        # iOS build
flutter build web --release        # Web build
```

### Code Quality
```bash
flutter analyze                    # Run static analysis
flutter test                       # Run all tests
flutter test test/path/to/test.dart  # Run single test file
```

### Icons
```bash
flutter pub run flutter_launcher_icons  # Generate app icons
```

## Architecture

### Layered Architecture

**Provider Layer (Riverpod)**
- `lib/providers/prayer_providers.dart` - Central provider definitions for prayers, categories, search, favorites
- `lib/providers/prayer_app_settings_provider.dart` - Unified settings management (NEW system)
- `lib/providers/text_scaling_provider.dart` - Text scaling for accessibility
- Integrates with `sancta_via_liturgical_calendar_riverpod` for liturgical data
- Uses `sancta_via_shared_ui` providers for theming (themeModeProvider, colorIntensityProvider)

**Repository Layer**
- `lib/repositories/prayer_repository.dart` - SQLite database access with caching
- Handles database migration from JSON assets to SQLite on first run
- Singleton pattern for database connection
- Deprecated SharedPreferences methods (use PrayerAppSettingsProvider instead)

**Database Layer**
- `lib/database/prayer_database.dart` - SQLite schema and queries
- `lib/database/database_migration_service.dart` - One-time migration from JSON to SQLite
- Tables: `prayers`, `categories`, `category_groups`, junction tables for many-to-many relationships
- Migration checks occur on first repository call via `_ensureMigrationComplete()`

**Service Layer**
- `lib/services/prayer_of_the_day_service.dart` - Liturgical prayer selection logic
  - Priority: Feast days > Seasonal prayers > Ordinary time rotation
  - Uses `LiturgicalDayData` from `sancta_via_liturgical_calendar`

**Model Layer**
- `lib/models/prayer.dart` - Prayer with translations, liturgical metadata
- `lib/models/prayer_category.dart` - Prayer categorization
- `lib/models/prayer_category_group.dart` - Category grouping
- `lib/models/prayer_app_settings.dart` - User preferences and settings

**UI Layer**
- `lib/screens/` - Screen components organized by feature
- `lib/widgets/` - Reusable widgets (PrayerCard, EnhancedPrayerText, FontSizeSelector)
- `lib/config/routes.dart` - GoRouter navigation setup

### Dependency Structure

This app depends on sibling packages in the Sancta Via ecosystem:
- `sancta_via_shared_ui` (../sancta_via_shared_ui) - Shared UI components, AppTheme with liturgical colors
- `sancta_via_liturgical_calendar` (../sancta_via_liturgical_calendar) - Catholic liturgical calendar data
- `sancta_via_liturgical_calendar_riverpod` (../sancta_via_liturgical_calendar_riverpod) - Riverpod providers for calendar

**IMPORTANT**: When working with these dependencies:
1. Changes to shared packages require `flutter pub get` in this app to update
2. Liturgical theming flows from `currentLiturgicalColorProvider` (lib/main.dart:17)
3. Use `AppTheme.lightTheme()` and `AppTheme.darkTheme()` from shared_ui with liturgical color parameter

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

### Liturgical Integration

The app's theming and prayer selection dynamically respond to the liturgical calendar:

```dart
// main.dart - Dynamic liturgical theming
final currentLiturgicalColor = ref.watch(currentLiturgicalColorProvider);
final liturgicalColor = LiturgicalColor.fromString(currentLiturgicalColor);
theme: AppTheme.lightTheme(liturgicalColor, colorIntensity)
```

Prayer of the Day selection (lib/services/prayer_of_the_day_service.dart):
1. Checks for major feast days/solemnities
2. Falls back to seasonal prayers (Advent, Lent, Easter, etc.)
3. Uses day-of-year rotation for Ordinary Time

### Settings Management (IMPORTANT)

**NEW SYSTEM (Use this)**:
- `prayerAppSettingsProvider` from `lib/providers/prayer_app_settings_provider.dart`
- Unified NotifierProvider managing favorites, recent prayers, font size, language, reading mode
- Persists to SharedPreferences automatically

**DEPRECATED (Do not use)**:
- `PrayerRepository.getUserPreferences()`, `.toggleFavorite()`, etc. are marked @Deprecated
- Old `prayerPreferencesProvider` wraps new system for backward compatibility

When adding new settings:
1. Update `PrayerAppSettings` model (lib/models/prayer_app_settings.dart)
2. Add methods to `PrayerAppSettingsNotifier` (lib/providers/prayer_app_settings_provider.dart)
3. Never use repository methods for preferences

### Database Migration

Migration runs automatically on first app launch:
- `DatabaseMigrationService.isMigrationNeeded()` checks if database is empty
- `DatabaseMigrationService.migrateJsonToDatabase()` loads JSON assets and populates SQLite
- Flag `_migrationChecked` in PrayerRepository prevents redundant checks
- For testing: `repository.forceMigration()` to re-run migration

### Code Standards

From analysis_options.yaml:
- Use single quotes for strings
- Require trailing commas
- Prefer const constructors and final fields
- No implicit casts or dynamic
- Allow print statements (for development/debugging)

## Adding New Prayers

1. Create `assets/prayers/{prayer_id}.json` with required fields:
   - id, title, text, categories, description, tags
   - Optional: translation (map), attribution, notes, isLiturgical, liturgicalPriority, liturgicalSeason

2. On next app launch, call `repository.forceMigration()` to update database, OR:
   - Delete the app and reinstall to trigger automatic migration
   - Use debug settings to force re-migration (if implemented)

3. Prayer will automatically appear in app based on categories/tags

## Common Pitfalls

1. **Don't bypass the repository** - Always use PrayerRepository for data access, never query PrayerDatabase directly
2. **Migration state** - Repository migration check only runs once per session; restart app or call forceMigration() after JSON changes
3. **Shared package changes** - Run `flutter pub get` after modifying sibling packages
4. **Provider caching** - Repository caches prayers/categories; call `clearCache()` to force refresh
5. **Liturgical providers** - Don't mock liturgical calendar providers; they're essential for theming/prayer selection
6. **Settings** - Use PrayerAppSettingsProvider, not deprecated repository methods

## Testing

- Tests located in `test/`
- Run specific test: `flutter test test/widget_test.dart`
- Test database: Use in-memory SQLite for fast, isolated tests
- Mock providers: Use ProviderContainer with overrides for Riverpod providers
