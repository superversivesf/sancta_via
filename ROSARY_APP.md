# Sancta Via Rosary Companion - Design Document

## 1. App Overview & Purpose

**Sancta Via Rosary Companion** is a Catholic prayer app that helps users pray the traditional rosary with liturgical integration. The app provides both automated daily rosaries based on the traditional weekday schedule and flexible manual selection for all mysteries.

**Key Features:**
- Daily rosary with automatic mystery selection based on traditional weekday schedule
- Manual mystery selection for all four sets (Joyful, Sorrowful, Glorious, Luminous)
- Interactive bead counter for prayer tracking
- Full text display for each prayer and mystery
- Progress tracking and statistics (weekly/monthly/yearly)
- Local persistence with SQLite for performance
- Pre-loaded prayers and mysteries in assets
- Liturgical calendar integration

## 2. Module Dependencies

### Core Dependencies
```yaml
dependencies:
  flutter:
    sdk: flutter
  
  # Sancta Via shared modules
  sancta_via_shared_ui:
    path: ../sancta_via_shared_ui
  sancta_via_liturgical_calendar:
    path: ../sancta_via_liturgical_calendar
  sancta_via_liturgical_calendar_riverpod:
    path: ../sancta_via_liturgical_calendar_riverpod
  
  # State management & navigation
  flutter_riverpod: ^2.6.1
  go_router: ^15.1.2
  
  # Storage & persistence
  shared_preferences: ^2.5.3
  sqflite: ^2.3.3+1
  path: ^1.9.1
  
  # Utils
  package_info_plus: ^8.3.0
  intl: ^0.20.2
```

**Version:** 1.0.0+1
**Environment:** sdk: ^3.9.2

## 3. Data Models

### 3.1 Rosary Bead Model
```dart
class RosaryBead {
  final String id;
  final BeadType type; // our_father, hail_mary, glory_be, apostle_creed, hail_holy_queen
  final int decadePosition; // 1-10 for Hail Mary beads, 0 for others
  final String prayerText;
  final String audioUrl; // For Phase 2
  
  const RosaryBead({
    required this.id,
    required this.type,
    required this.decadePosition,
    required this.prayerText,
    this.audioUrl,
  });
}
```

### 3.2 Rosary Mystery Model
```dart
class RosaryMystery {
  final String id;
  final MysteryType mysteryType; // joyful, sorrowful, glorious, luminous
  final int mysteryNumber; // 1-5
  final String title;
  final String description;
  final String scriptureText;
  final String meditationText;
   
  const RosaryMystery({
    required this.id,
    required this.mysteryType,
    required this.mysteryNumber,
    required this.title,
    required this.description,
    required this.scriptureText,
    required this.meditationText,
  });
}
```

### 3.3 Rosary Session Model
```dart
class RosarySession {
  final String id;
  final MysteryType mysteryType;
  final DateTime startTime;
  final DateTime? endTime;
  final int completedBeads; // 0-53 (or 4 for introduction prayers)
  final bool isComplete;
  final String? notes;
  
  const RosarySession({
    required this.id,
    required this.mysteryType,
    required this.startTime,
    this.endTime,
    required this.completedBeads,
    required this.isComplete,
    this.notes,
  });
}
```

### 3.4 Rosary Settings Model
```dart
class RosarySettings {
  final bool useDailySchedule;
  final MysteryType? preferredMystery;
  final bool showFullText;
  final bool enableBeadCounter;
  final bool autoAdvance;
  final double fontSize;
  final bool showImagery;
  final ColorIntensity? colorIntensity;
  
  const RosarySettings({
    required this.useDailySchedule,
    this.preferredMystery,
    required this.showFullText,
    required this.enableBeadCounter,
    required this.autoAdvance,
    required this.fontSize,
    required this.showImagery,
    this.colorIntensity,
  });
}
```

### 3.5 Statistics Model
```dart
class RosaryStatistics {
  final String id;
  final DateTime date;
  final int completedRosaries; // Full 5-decade rosaries
  final int completedDecades; // Partial rosaries
  final MysteryType mysteryType;
  final int totalPrayerTimeMinutes;
  
  const RosaryStatistics({
    required this.id,
    required this.date,
    required this.completedRosaries,
    required this.completedDecades,
    required this.mysteryType,
    required this.totalPrayerTimeMinutes,
  });
}
```

### Enums
```dart
enum BeadType {
  our_father,
  hail_mary,
  glory_be,
  apostle_creed,
  hail_holy_queen,
  sign_of_cross,
  final_prayer,
}

enum MysteryType {
  joyful,
  sorrowful,
  glorious,
  luminous,
}

enum ColorIntensity {
  normal,
  vivid,
  subdued,
}
```

## 4. Database Schema & Repositories

### SQLite Schema

```sql
-- Rosary Mysteries Table
CREATE TABLE mysteries (
  id TEXT PRIMARY KEY,
  mystery_type TEXT NOT NULL,
  mystery_number INTEGER NOT NULL,
  title TEXT NOT NULL,
  description TEXT NOT NULL,
  scripture_text TEXT NOT NULL,
  meditation_text TEXT NOT NULL
);

-- Rosary Beads Table
CREATE TABLE beads (
  id TEXT PRIMARY KEY,
  bead_type TEXT NOT NULL,
  decade_position INTEGER NOT NULL,
  prayer_text TEXT NOT NULL,
  audio_url TEXT
);

-- Rosary Sessions Table
CREATE TABLE sessions (
  id TEXT PRIMARY KEY,
  mystery_type TEXT NOT NULL,
  start_time INTEGER NOT NULL,
  end_time INTEGER,
  completed_beads INTEGER NOT NULL,
  is_complete INTEGER NOT NULL,
  notes TEXT
);

-- Statistics Table
CREATE TABLE statistics (
  id TEXT PRIMARY KEY,
  date INTEGER NOT NULL,
  completed_rosaries INTEGER NOT NULL,
  completed_decades INTEGER NOT NULL,
  mystery_type TEXT NOT NULL,
  total_prayer_time_minutes INTEGER NOT NULL
);

-- Settings Table
CREATE TABLE settings (
  use_daily_schedule INTEGER NOT NULL,
  preferred_mystery TEXT,
  show_full_text INTEGER NOT NULL,
  enable_bead_counter INTEGER NOT NULL,
  auto_advance INTEGER NOT NULL,
  font_size REAL NOT NULL,
  show_imagery INTEGER NOT NULL
);
```

### Repository Interface
```dart
abstract class RosaryRepository {
  // Data loading
  Future<List<RosaryMystery>> getMysteriesByType(MysteryType type);
  Future<List<RosaryBead>> getBeads();
  Future<List<RosaryMystery>> getAllMysteries();
  Future<RosaryMystery?> getDailyMystery(DateTime date);
  
  // Session management
  Future<void> createSession(RosarySession session);
  Future<void> updateSession(RosarySession session);
  Future<RosarySession?> getActiveSession();
  Future<List<RosarySession>> getSessionHistory(DateTime from, DateTime to);
  
  // Statistics
  Future<List<RosaryStatistics>> getStatistics(DateTime from, DateTime to);
  Future<void> addStatistics(RosaryStatistics stats);
  Future<RosaryStatistics> getStatisticsSummary();
  
  // Settings
  Future<RosarySettings> getSettings();
  Future<void> saveSettings(RosarySettings settings);
  
  // Data seeding (run once on first launch)
  Future<void> seedInitialData();
}
```

## 5. Business Logic & Services

### 5.1 Rosary Progress Service
```dart
class RosaryProgressService {
  static const totalBeads = 53; // 4 introductory + 5 decades
  
  static Map<String, int> calculateProgress(int completedBeads) {
    final progressPercentage = (completedBeads / totalBeads * 100).round();
    final currentDecade = (completedBeads - 4) ~/ 11 + 1;
    final beadsInCurrentDecade = (completedBeads - 4) % 11;
    
    return {
      'progressPercentage': progressPercentage,
      'currentDecade': currentDecade.clamp(0, 5),
      'beadsInCurrentDecade': beadsInCurrentDecade,
    };
  }
  
  static MysteryType getDailyMysteryType(DateTime date) {
    // Traditional schedule: Sun:Glorious, Mon:Joyful, Tue:Sorrowful,
    // Wed:Glorious, Thu:Luminous, Fri:Sorrowful, Sat:Joyful
    switch (date.weekday) {
      case 1: return MysteryType.joyful; // Monday
      case 2: return MysteryType.sorrowful; // Tuesday
      case 3: return MysteryType.glorious; // Wednesday
      case 4: return MysteryType.luminous; // Thursday
      case 5: return MysteryType.sorrowful; // Friday
      case 6: return MysteryType.joyful; // Saturday
      case 7: return MysteryType.glorious; // Sunday
      default: return MysteryType.joyful;
    }
  }
  
  static int getNextBeadIndex(int currentIndex) {
    return currentIndex + 1;
  }
  
  static bool isRosaryComplete(int completedBeads) {
    return completedBeads >= totalBeads;
  }
}
```

### 5.2 Statistics Service
```dart
class RosaryStatisticsService {
  static Future<RosaryStatisticsSummary> getSummary() async {
    // Weekly, monthly, yearly statistics
    // Total rosaries, average time, streak
  }
  
  static Future<void> updateStatistics(RosarySession session) async {
    // Update stats when session completes
  }
}
```

### 5.3 Notification Service (Phase 2)
```dart
class RosaryNotificationService {
  Future<void> scheduleDailyReminder(TimeOfDay time);
  Future<void> cancelAllNotifications();
  Future<void> showCompletionNotification();
}
```

## 6. Riverpod Providers Architecture

```dart
// Core providers
final rosaryRepositoryProvider = Provider<RosaryRepository>((ref) {
  return RosaryRepositoryImpl();
});

final mysteryProvider = FutureProvider.family<RosaryMystery, String>((ref, id) {
  final repository = ref.watch(rosaryRepositoryProvider);
  return repository.getMysteryById(id);
});

final allMysteriesProvider = FutureProvider<List<RosaryMystery>>((ref) {
  final repository = ref.watch(rosaryRepositoryProvider);
  return repository.getAllMysteries();
});

// Settings providers
final rosarySettingsProvider = StateNotifierProvider<RosarySettingsNotifier, RosarySettings>((ref) {
  return RosarySettingsNotifier();
});

// Session providers
final activeSessionProvider = StateNotifierProvider<RosarySessionNotifier, RosarySession?>((ref) {
  return RosarySessionNotifier();
});

final sessionHistoryProvider = FutureProvider<List<RosarySession>>((ref) {
  final repository = ref.watch(rosaryRepositoryProvider);
  return repository.getSessionHistory(fromDate, toDate);
});

// Statistics providers
final statisticsProvider = StateNotifierProvider<RosaryStatisticsNotifier, List<RosaryStatistics>>((ref) {
  return RosaryStatisticsNotifier();
});
```

### Notifiers
```dart
class RosarySettingsNotifier extends StateNotifier<RosarySettings> {
  RosarySettingsNotifier() : super(_defaultSettings);
  
  Future<void> updateSettings(RosarySettings settings);
  Future<void> updateSingleSetting(String key, dynamic value);
}

class RosarySessionNotifier extends StateNotifier<RosarySession?> {
  RosarySessionNotifier() : super(null);
  
  Future<void> startSession(MysteryType type);
  Future<void> updateProgress(int beadsCompleted);
  Future<void> completeSession();
  Future<void> pauseSession();
}
```

## 7. UI Screens & Navigation

### Navigation Structure
```dart
final rosaryRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', name: 'home', builder: (context, state) => const HomeScreen()),
    GoRoute(path: '/daily', name: 'daily', builder: (context, state) => const DailyRosaryScreen()),
    GoRoute(path: '/select', name: 'select', builder: (context, state) => const MysterySelectionScreen()),
    GoRoute(path: '/rosary/:mysteryType', name: 'rosary', builder: (context, state) => RosaryScreen(mysteryType: state.pathParameters['mysteryType'])),
    GoRoute(path: '/statistics', name: 'statistics', builder: (context, state) => const StatisticsScreen()),
    GoRoute(path: '/settings', name: 'settings', builder: (context, state) => const RosarySettingsScreen()),
  ],
);
```

### 7.1 Home Screen (`/home`)
**Components:**
- Header: App title + liturgical information
- Daily Rosary Card: Featured mystery based on schedule
- Quick Start: Button to start today's rosary
- Mysteries Grid: Cards for each mystery type
- Recent Activity: Last completed rosary
- Statistics Preview: Weekly/monthly summary
- Settings access

**Widgets:**
- `DailyRosaryCard`
- `MysteryTypeCard`
- `RecentActivityTile`
- `StatisticsPreview`
- `LiturgicalHeader`

### 7.2 Mystery Selection Screen (`/select`)
**Components:**
- Grid of 4 mystery type cards
- Each card shows: title, icon, brief description
- Recent/Popular indicator
- Direct start button

**Widgets:**
- `MysteryTypeGrid`
- `MysterySelectionCard`

### 7.3 Rosary Prayer Screen (`/rosary/:mysteryType`)
**Components:**
- Top: Current mystery info with image
- Center: Bead counter with progress indicator
- Bottom: Current prayer text
- Navigation: Previous/next buttons
- Progress: Decade progress indicator
- Settings: Toggle full text, bead counter visibility

**Features:**
- Swipe left/right to advance/reverse
- Tap bead to jump to position
- Auto-advance toggle
- Font size adjustment from settings
- Full text display toggle

**Widgets:**
- `RosaryProgressIndicator`
- `BeadCounterWidget`
- `PrayerTextDisplay`
- `MysteryInfoHeader`
- `RosaryControls`

### 7.4 Statistics Screen (`/statistics`)
**Components:**
- Summary cards: total rosaries, streak, average time
- Charts: weekly/monthly/yearly view
- Completion history list
- Filtering by date range

**Widgets:**
- `StatisticsSummaryCard`
- `RosaryChart`
- `SessionHistoryList`

### 7.5 Settings Screen (`/settings`)
**Components:**
- General: Daily schedule toggle, preferred mystery
- Display: Show full text, bead counter, imagery toggle
- Behavior: Auto-advance, font size
## 8. Asset Organization

```
sancta_via_rosary_companion/
  assets/
    app_icon.png
    images/
      mysteries/
        joyful/
          1-annunciation.jpg
          2-visitation.jpg
          ...
        sorrowful/
          1-agony.jpg
          2-scourging.jpg
          ...
        glorious/
          1-resurrection.jpg
          2-ascension.jpg
          ...
        luminous/
          1-baptism.jpg
          2-wedding.jpg
          ...
    data/
      mysteries.json
      prayers.json
```

### Data Structure (JSON)
```json
{
  "mysteries": [
    {
      "id": "joyful-1",
      "mystery_type": "joyful",
      "mystery_number": 1,
      "title": "The Annunciation",
      "description": "The Angel Gabriel announces to Mary that she will bear the Son of God",
      "scripture_text": "'Hail, full of grace, the Lord is with you!' (Luke 1:28)",
      "meditation_text": "We pray for humility and acceptance of God's will..."
    }
  ],
  "prayers": {
    "our_father": "Our Father, who art in heaven...",
    "hail_mary": "Hail Mary, full of grace...",
    "glory_be": "Glory be to the Father...",
    "apostles_creed": "I believe in God...",
    "hail_holy_queen": "Hail, holy Queen, Mother of Mercy..."
  }
}
```

## 9. Settings & Preferences

### 9.1 General Settings (`RosarySettings`)
- **useDailySchedule**: bool - Follow traditional weekday schedule
- **preferredMystery**: MysteryType? - User's preferred mystery when not using daily schedule
- **showFullText**: bool - Display full prayer text vs. abbreviated
- **enableBeadCounter**: bool - Show bead counter UI
- **autoAdvance**: bool - Automatically advance to next bead
- **fontSize**: double - Text size for prayers (12.0 - 24.0)
- **showImagery**: bool - Display mystery images
- **colorIntensity**: ColorIntensity - Liturgical color intensity

### 9.2 Settings Storage
- Implemented through `shared_preferences` for simple settings
- Complex data stored in SQLite `settings` table
- Sync between providers and repository for consistency

### 9.3 Settings UI
- Located in `RosarySettingsScreen`
- Uses shared UI components from `sancta_via_shared_ui`
- Includes: toggles, sliders, dropdowns for mystery selection

## 10. Feature Roadmap

### 10.1 MVP (Minimum Viable Product)
**Core Features:**
- [ ] Project setup with Melos integration
- [ ] Database schema and repository implementation
- [ ] Seed initial data from JSON assets
- [ ] Data models and enums
- [ ] Core business logic (RosaryProgressService)
- [ ] Riverpod providers architecture
- [ ] Home screen with daily rosary card
- [ ] Mystery selection screen
- [ ] Rosary prayer screen with bead counter
- [ ] Basic settings persistence
- [ ] Statistics tracking (completed rosaries)

**Navigation:**
- [ ] Home → Daily/Manual selection → Rosary prayer
- [ ] Settings access from home
- [ ] Statistics access from home

**Data:**
- [ ] All four mystery sets with full text
- [ ] Complete rosary prayer texts
- [ ] SQLite integration with seeding

### 10.2 Phase 2 (Enhanced Experience)
**Features:**
- [ ] Mystery imagery for each mystery (15 images)
- [ ] Audio prayer integration
- [ ] Background audio with pause/resume
- [ ] Notification system for daily reminders
- [ ] Prayer streak tracking
- [ ] Enhanced statistics with charts
- [ ] Export prayer history

**UI Enhancements:**
- [ ] Animated bead counter
- [ ] Swipe gestures for navigation
- [ ] Improved visual feedback
- [ ] Accessibility improvements

### 10.3 Phase 3 (Advanced Features)
**Features:**
- [ ] Custom prayer texts
- [ ] Multiple languages support
- [ ] Family sharing features
- [ ] iCloud/backup sync
- [ ] Apple Watch companion
- [ ] Widgets for home screen
- [ ] Advanced notifications (multiple reminders)
- [ ] Community features (prayer intentions)

## 11. Implementation Guidelines

### 11.1 Code Style (following AGENTS.md)
- **Quotes**: Single quotes only (`'string'`)
- **Commas**: Trailing commas required
- **Imports**: dart → packages → relative (sorted)
- **Naming**: Classes(PascalCase), variables(camelCase), constants(SCREAMING_SNAKE)
- **Types**: Prefer `final`, explicit types (avoid `var`/`dynamic`)
- **Constructors**: Use `const`, include `key` parameter
- **Error handling**: `try/catch` with `AppLogger.error()`
- **No print statements**: Use `AppLogger()` instead

### 11.2 File Structure
```
sancta_via_rosary_companion/
  lib/
    config/
      routes.dart
    database/
      rosary_database.dart
      database_migration_service.dart
    models/
      rosary_bead.dart
      rosary_mystery.dart
      rosary_session.dart
      rosary_settings.dart
      rosary_statistics.dart
    repositories/
      rosary_repository.dart
      rosary_repository_impl.dart
    providers/
      rosary_providers.dart
      rosary_settings_provider.dart
      rosary_session_provider.dart
      rosary_statistics_provider.dart
    screens/
      home/
        home_screen.dart
      mystery_selection/
        mystery_selection_screen.dart
      rosary/
        rosary_screen.dart
        widgets/
          bead_counter_widget.dart
          prayer_text_display.dart
          rosary_progress_indicator.dart
          mystery_info_header.dart
      statistics/
        statistics_screen.dart
      settings/
        settings_screen.dart
    services/
      rosary_progress_service.dart
      rosary_statistics_service.dart
    utils/
      logger.dart
      constants.dart
    widgets/
      shared/
        mystery_type_card.dart
        daily_rosary_card.dart
    generated/
      assets.dart
    main.dart
```

### 11.3 Testing Strategy
- Unit tests for business logic (RosaryProgressService)
- Widget tests for screens
- Integration tests for navigation
- Repository tests with in-memory database

### 11.4 Asset Creation
- Create mystery images (15 total, 4 mystery sets)
- Generate app icon following Sancta Via branding
- Prepare JSON data files for initial seeding

## 12. Integration Points

### 12.1 Shared UI Module
Use components from `sancta_via_shared_ui`:
- `AppTheme` - Liturgical color theming
- `LiturgicalColorExtensions` - Color utilities
- `BaseSettingsModel` - Settings pattern
- Standard fonts, colors, typography
- Privacy policy, support screens

### 12.2 Liturgical Calendar Module
- Integrate `sancta_via_liturgical_calendar` for liturgical context
- Use liturgical colors in theme
- Display current liturgical season on home screen
- Adapt mystery schedule for special seasons (Lent, Advent)

### 12.3 Melos Integration
- Follow monorepo structure
- Consistent versioning
- Shared analysis_options.yaml
- Automated testing and building via Melos scripts

## 13. Questions & Clarifications

❓ **Bead Counter Implementation**: Should the bead counter be a visual representation of the rosary (circular with beads) or a simple progress indicator? The prayer app has a simpler linear design, but a rosary-specific circular design might be more intuitive.

❓ **Session Persistence**: If a user closes the app mid-rosary, should we restore their position? This would require saving the active session state periodically.

❓ **Font Size**: Should font size be app-specific or use the shared UI's text scaling system? The prayer app has its own `textScalingProvider`.

❓ **Mystery Images**: Should we commission custom artwork or use public domain religious art? What's the licensing approach for other Sancta Via apps?

❓ **Statistics Detail**: How granular should statistics be? Should we track:
- Time per decade?
- Pause/resume events?
- Which mysteries are most/least prayed?
- Prayer streaks with grace periods?

❓ **Audio Implementation**: Should audio be:
- Pre-recorded prayers (requires voice talent)
- Text-to-speech (less personal but scalable)
- User-recorded (personal but complex)

This design document provides a complete blueprint for implementing the Sancta Via Rosary Companion app following all established patterns in the Sancta Via ecosystem.