# SanctaVia Fasting Companion App - Development Plan

## Executive Summary

Create a Catholic fasting companion app (`sancta_via_fasting_companion`) that tracks various fasting types (intermittent, 24-hour, multi-day) with integrated encouragement system featuring scriptural quotes, saint writings, prayers, and imagery to support spiritual growth through fasting.

## Architecture Overview

The app follows established SanctaVia patterns with Riverpod state management, SQLite persistence, and integration with existing shared packages.

## Component Structure

### 1. Core Models (`lib/models/`)

**FastSession.dart**
```dart
class FastSession {
  final String id;
  final FastType type;
  final DateTime startTime;
  final DateTime? endTime;
  final int targetDurationMinutes;
  final FastStatus status;
  final String? notes;
  final List<Encouragement> encouragementsShown; // Track seen encouragements
}
```

**FastType.dart**
```dart
enum FastTypeCategory {
  intermittent,    // 16:8, 18:6, 20:4
  daily24hr,       // Single 24-hour period
  multiDay,        // 2-5 day fasts
  liturgical,      // Seasonal fasts (Advent, Lent)
}

class FastType {
  final String id;
  final String name;
  final String description;
  final FastTypeCategory category;
  final int? targetDurationHours; // null for multi-day
  final Map<int, String> milestoneMessages; // Hour mark → message key
  final List<String> associatedPrayers;
}
```

**Encouragement.dart**
```dart
class Encouragement {
  final String id;
  final EncouragementCategory category; // scripture, saint_quote, prayer
  final String triggerPoint; // start, hourly, milestone, completion, difficulty
  final String? liturgicalSeason; // Ordinary, Advent, Lent, Easter, etc.
  final String content;
  final String? attribution; // Author/source
  final String? relatedScripture; // Reference
  final String? categoryHint; // Suffering, perseverance, victory, etc.
}
```

### 2. Database Layer (`lib/database/`)

**Schema**
```sql
CREATE TABLE fast_sessions (
  id TEXT PRIMARY KEY,
  type_id TEXT NOT NULL,
  start_time INTEGER NOT NULL,
  end_time INTEGER,
  target_duration_minutes INTEGER NOT NULL,
  status TEXT NOT NULL,
  notes TEXT,
  encouragements_shown TEXT, -- JSON array of encouragement IDs
  FOREIGN KEY (type_id) REFERENCES fast_types (id)
);

CREATE TABLE fast_types (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  description TEXT NOT NULL,
  category TEXT NOT NULL,
  target_duration_hours INTEGER,
  milestones TEXT, -- JSON map of hour->message
  prayers TEXT -- JSON array of prayer IDs
);

CREATE TABLE encouragements (
  id TEXT PRIMARY KEY,
  category TEXT NOT NULL,
  trigger_point TEXT NOT NULL,
  liturgical_season TEXT,
  content TEXT NOT NULL,
  attribution TEXT,
  related_scripture TEXT,
  category_hint TEXT
);

CREATE TABLE encouragement_history (
  id TEXT PRIMARY KEY,
  fast_session_id TEXT,
  encouragement_id TEXT,
  shown_at INTEGER NOT NULL,
  FOREIGN KEY (fast_session_id) REFERENCES fast_sessions (id),
  FOREIGN KEY (encouragement_id) REFERENCES encouragements (id)
);
```

**Pre-populated Data**
- 50+ Scripture passages (Matthew 4:1-11, Isaiah 58, etc.)
- 30+ Saint quotes (St. Augustine on fasting, St. Francis, St. Teresa)
- 20+ Catholic prayers (Litany of Humility, Prayer of Abandonment)
- Fast types: Intermittent variations, Traditional Catholic fasts

### 3. Repository Layer (`lib/repositories/`)

**FastingRepository.dart** (Singleton pattern)
```dart
class FastingRepository {
  static final FastingRepository instance = FastingRepository._internal();
  factory FastingRepository() => instance;
  FastingRepository._internal();

  // Current active fast
  Future<FastSession?> getActiveFast();
  Future<void> startFast(FastType type, {String? notes});
  Future<void> updateFast(FastSession session);
  Future<void> completeFast(String sessionId);
  Future<void> breakFast(String sessionId); // Mark as broken

  // Historical data
  Future<List<FastSession>> getFastHistory({DateTime? from, DateTime? to});
  Future<Map<FastTypeCategory, int>> getFastTypeStats();
  Future<Map<String, int>> getMonthlyFastCount();

  // Encouragement management
  Future<Encouragement> getEncouragement(String trigger, {String? season});
  Future<void> markEncouragementShown(String fastId, String encouragementId);
  
  // Settings
  Future<void> saveNotificationSettings(FastingNotificationSettings settings);
}
```

### 4. State Management (`lib/providers/`)

**fast_session_provider.dart**
```dart
class FastSessionProvider extends Notifier<FastSession?> {
  @override
  FastSession? build() {
    // Load active fast on startup
    return ref.watch(fastingRepositoryProvider).getActiveFast();
  }

  void startFast(FastType type) { /* ... */ }
  void updateProgress() { /* ... */ }
  void completeFast() { /* ... */ }
  void breakFast() { /* ... */ }
}

final fastSessionProvider = NotifierProvider<FastSessionProvider, FastSession?>(FastSessionProvider.new);
```

**encouragement_provider.dart**
```dart
class EncouragementProvider extends Notifier<Encouragement?> {
  @override
  Encouragement? build() {
    // Return encouragement based on current fast state
    final fast = ref.watch(fastSessionProvider);
    if (fast == null) return null;
    
    return _getRelevantEncouragement(fast);
  }

  Encouragement _getRelevantEncouragement(FastSession fast) {
    // Logic to determine best encouragement based on:
    // - Time elapsed
    // - Fast type
    // - Liturgical season
    // - Previous encouragements shown
    // - Difficulty markers (user can mark "struggling")
  }
}
```

### 5. UI Screens (`lib/screens/`)

**Fast Tracker Screen** (Main UI)
- Large timer showing elapsed time (HH:MM:SS)
- Progress ring/bar with milestone markers
- Current encouragement display (swipeable)
- "I'm struggling" button → triggers supportive encouragement
- Liturgical color theming from shared provider
- Quick action: Complete fast / Break fast / Extend fast

**Fast Setup Screen**
- Grid of fast type cards with icons and descriptions
- Custom duration picker for multi-day fasts
- Intention setting text field (saved with session)
- Preview of encouragements for this fast type

**Encouragement View Screen** (Full-screen)
- Beautiful background imagery related to theme
- Large, readable text for encouragement
- Attribution and related scripture
- Prayer button (if prayer available)
- Share button for social sharing

**History & Stats Screen**
- Calendar view with completed fasts marked
- Statistics: Total hours, streaks, most common type
- Charts: Weekly/monthly fasting patterns
- Tap date to see fast details and encouragements shown

### 6. Notification System

**Notification Types:**
1. **Start Reminder**: "Time for your daily fast" (customizable time)
2. **Hourly Encouragement**: Rotating quotes during active fast
3. **Milestone Celebration**: "6 hours complete! You're doing great"
4. **Near End**: "30 minutes left. Final push!"
5. **Completion**: Fast complete, offer thanksgiving prayer
6. **Struggling Check-in**: If user marked struggling, extra encouraging message

**Notification Content Examples:**
- **Start**: "Blessed are those who hunger and thirst for righteousness" (Matt 5:6)
- **Hour 4**: "Do you not know that your body is a temple of the Holy Spirit?" (1 Cor 6:19)
- **Hour 16**: St. Augustine quote on fasting and prayer
- **Difficulty**: "When the devil cannot make us bad, he makes us busy" - St. Francis
- **Completion**: Thanksgiving prayer and reflection prompt

### 7. Encouragement Content Database

**Scripture Passages** (organized by theme):
- **Starting**: Matthew 4:1-11 (Jesus fasted 40 days), Isaiah 58 (True fasting)
- **Perseverance**: James 1:12, Hebrews 12:1-2, 1 Corinthians 9:27
- **Victory**: 2 Timothy 4:7, Revelation 3:21, 1 John 5:4
- **Body as Temple**: 1 Corinthians 6:19-20, Romans 12:1
- **Suffering**: Romans 5:3-5, James 1:2-4, 1 Peter 4:12-13

**Saint Quotes**:
- **St. Augustine**: "Fasting cleanses the soul, raises the mind, subjects one's flesh to the spirit..."
- **St. Francis**: "Sanctify yourself and you will sanctify society"
- **St. Teresa of Avila**: "Much more is accomplished by a single word of the Our Father..."
- **St. John of the Cross**: "What we need most in order to make progress is to be silent..."
- **St. Thomas Aquinas**: "Fasting is the guardian of chastity..."

**Prayers**:
- **Prayer Before Fasting**: "Lord, as I begin this fast, unite my sacrifice with Your suffering..."
- **During Difficulty**: "Jesus, I trust in You" (Chaplet of Divine Mercy)
- **Completion**: "Father, I thank You for the grace to complete this fast..."
- **Litany of Humility**: O Jesus! meek and humble of heart, Hear me...

**Imagery Themes**:
- **Desert/Wilderness**: Representing Jesus' 40 days
- **Vine and Branches**: John 15
- **Light in Darkness**: Psalm 119:105
- **Eagle**: Isaiah 40:31 (renew strength)
- **Cross**: Union with Christ's suffering
- **Heart**: Sacred Heart, purity of intention

### 8. Liturgical Calendar Integration

**Season-Specific Content**:
- **Advent**: Focus on preparation, waiting, hope
- **Christmas**: Joy, incarnation, Word made flesh
- **Ordinary Time**: Growth, discipleship, perseverance
- **Lent**: Penance, sacrifice, 40 days, temptation
- **Easter**: Victory, resurrection, new life

**Suggested Fasts by Season**:
- **Advent**: Daily intermittent fasts
- **Lent**: Multi-day fasts, Ash Wednesday/Good Friday 24hr
- **Ordinary**: Flexible personal fasts
- **Easter**: Celebratory (less intensive fasting)

### 9. Package Dependencies

```yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_riverpod: ^2.4.9
  go_router: ^13.0.0
  sqflite: ^2.3.0
  path: ^1.8.3
  intl: ^0.18.1
  
  # SanctaVia ecosystem
  sancta_via_liturgical_calendar: ^1.0.0
  sancta_via_liturgical_calendar_riverpod: ^1.0.0
  sancta_via_shared_ui: ^1.0.0
  
  # Notifications
  flutter_local_notifications: ^16.3.0
  timezone: ^0.9.2

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^3.0.0
```

### 10. Development Phases

**Phase 1: Core Foundation** (Week 1)
- Project structure and database schema
- Basic CRUD operations for fast sessions
- Timer implementation

**Phase 2: Encouragement System** (Week 2)
- Populate encouragement database
- Trigger logic based on fast state
- Full-screen encouragement viewer

**Phase 3: Notifications** (Week 3)
- Local notification setup
- Customizable notification preferences
- Background tracking

**Phase 4: Polish & Integration** (Week 4)
- Statistics and history UI
- Liturgical calendar integration
- Shared theming and settings
- App icon and launch screen

**Phase 5: Testing & Content** (Ongoing)
- Beta testing with real users
- Content expansion (more quotes, prayers)
- Performance optimization

### 11. Testing Strategy

**Unit Tests**:
- Database operations
- Encouragement selection logic
- Time calculations

**Widget Tests**:
- Timer display accuracy
- Encouragement rendering
- Navigation flow

**Integration Tests**:
- Full fast lifecycle
- Notification delivery
- Background tracking accuracy

### 12. Deployment

**App Stores**:
- Google Play Store: `net.superversive.sancta_via.fasting_companion`
- Apple App Store: Follow existing SanctaVia account

**Build Commands**:
```bash
# Development
flutter run

# Release
make build-android  # From app directory
```

---

## Next Steps

1. Create project structure: `sancta_via_fasting_companion/`
2. Initialize Flutter project with Riverpod
3. Set up database schema and basic CRUD
4. Implement timer and progress tracking
5. Design UI screens following SanctaVia patterns
6. Populate encouragement database
7. Integrate with existing packages (calendar, shared UI)
8. Beta testing with Catholic community

**Estimated Timeline**: 4-6 weeks for initial release