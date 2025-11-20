# Time-of-Day Prayer Panel - Implementation TODO

## Overview
Add a new home screen panel that displays a randomly selected prayer appropriate to the current time of day.

## Design Decisions
- **Time boundaries**: Morning (5AM-9AM), Anytime (9AM-11AM), Afternoon (11AM-5PM), Evening (5PM-9PM), Night (9PM-5AM)
- **Single category**: Each prayer belongs to exactly ONE time category (morning/afternoon/evening/night/anytime)
- **Refresh frequency**: Random prayer refreshes on each app opening
- **Panel position**: Next to Prayer of the Day, favorites panel moves down
- **Card style**: Same style as Prayer of the Day card
- **Selection logic**: Only prayers from the exact time-of-day category are shown (no anytime fallback during specific time slots)

---

## Phase 1 - Data Layer ✅

### Models
- [x] Create `PrayerTimeOfDay` enum in `lib/models/prayer_time_of_day.dart`
  - Values: morning, afternoon, evening, night, anytime
  - Include helper method to determine current period from DateTime
  - Include display name getter (e.g., "Morning", "Any Time")
- [x] Update `Prayer` model in `lib/models/prayer.dart`
  - Add `String timeOfDay` field (single value, not list)
  - Update `fromJson` and `toJson` methods
  - Update `copyWith` method
  - Default to 'anytime' if not specified

### Database
- [x] Update `PrayerDatabase` schema in `lib/database/prayer_database.dart`
  - Add `time_of_day TEXT` column to `prayers` table
  - Bump database version to 2
  - Add index on `time_of_day` column
  - Add query method `getPrayersByTimeOfDay(String timeOfDay)` - returns prayers matching time OR 'anytime'
  - Add query method `getPrayersForExactTimeOfDay(String timeOfDay)` - returns only exact matches
- [x] Migration service already handles new fields automatically (no changes needed)
  - `Prayer.fromJson` defaults `timeOfDay` to 'anytime' for prayers without the field

### Repository
- [x] Update `PrayerRepository` in `lib/repositories/prayer_repository.dart`
  - Add `getPrayersForTimeOfDay(PrayerTimeOfDay timeOfDay)` method
  - Returns record with `timePrayers` and `anytimePrayers` for weighted selection

---

## Phase 2 - Service/Provider Layer ✅

### Service
- [x] Create `TimeOfDayPrayerService` in `lib/services/time_of_day_prayer_service.dart`
  - `selectRandomPrayer()` - selection with date-based seeding
  - `selectDifferentPrayer()` - for manual refresh with timestamp-based seeding
  - Only selects from exact time-of-day matches (no anytime fallback)
  - Uses date as seed for consistent daily selection

### Providers
- [x] Create `time_of_day_prayer_providers.dart` in `lib/providers/`
  - `currentTimeOfDayProvider` - determines current period from device time
  - `timeOfDayPrayersProvider` - fetches exact time-of-day prayers (no anytime fallback)
  - `dailyTimeOfDayPrayerProvider` - selects random prayer on each app opening
  - `timeOfDayPrayerContextProvider` - metadata for UI display
  - `timeOfDayPrayerStatsProvider` - counts of prayers per time period

---

## Phase 3 - UI Layer ✅

### Widget
- [x] Create `TimeOfDayPrayerCard` widget in `lib/widgets/time_of_day_prayer_card.dart`
  - Same style as Prayer of the Day card
  - Display prayer title and description
  - Show current time period label (e.g., "Morning Prayer")
  - Time-appropriate icons (sun, cloud, twilight, moon)
  - Tap to navigate to full prayer view
  - Handles loading, error, and empty states

### Home Screen
- [x] Update home screen to include `TimeOfDayPrayerCard`
  - Added import for the widget
  - Position next to Prayer of the Day panel
  - Favorites and other panels moved down
  - Consistent styling with other panels

---

## Phase 4 - Content

### Categorize Existing Prayers
- [x] Review all existing prayers in `assets/prayers/`
- [x] Add `timeOfDay` field to each prayer JSON file
- [x] Categorization guide:
  - `morning`: Prayers traditionally said upon waking or in early hours (5AM-9AM)
  - `afternoon`: Midday prayers, grace before/after meals (11AM-5PM)
  - `evening`: Prayers for end of day, Vespers-related (5PM-9PM)
  - `night`: Prayers before sleep, Compline-related (9PM-5AM)
  - `anytime`: General prayers with no specific time association (shown during 9AM-11AM window)

### Add New Prayers (as needed)
- [ ] Morning prayers
  - [ ] Morning Offering (traditional)
  - [ ] Prayer to the Holy Spirit for the day
- [ ] Afternoon prayers
  - [ ] Grace before meals
  - [ ] Grace after meals
- [ ] Evening prayers
  - [ ] Evening Prayer
- [ ] Night prayers
  - [ ] Prayer before sleep
  - [ ] Nunc Dimittis

---

## Testing
- [ ] Unit tests for `PrayerTimeOfDay` enum and time period detection
- [ ] Unit tests for `TimeOfDayPrayerService` weighted selection
- [ ] Unit tests for repository query methods
- [ ] Widget tests for `TimeOfDayPrayerCard`
- [ ] Verify per-opening randomization works correctly

---

## Future Enhancements
- Manual refresh button to get a different prayer
- Setting to adjust time period boundaries
- History of past time-of-day prayers
