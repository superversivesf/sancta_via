# Design Patterns & Architecture Guide

This document captures the design patterns, architectural decisions, and common structures used across the Sancta Via Flutter applications.

---

## Table of Contents

1. [Architecture Overview](#1-architecture-overview)
2. [State Management Patterns](#2-state-management-patterns)
3. [Data Layer Patterns](#3-data-layer-patterns)
4. [Navigation Patterns](#4-navigation-patterns)
5. [Widget Patterns](#5-widget-patterns)
6. [Error Handling Patterns](#6-error-handling-patterns)
7. [Testing Patterns](#7-testing-patterns)
8. [Common Pitfalls to Avoid](#8-common-pitfalls-to-avoid)
9. [Recommended Improvements](#9-recommended-improvements)

---

## 1. Architecture Overview

### Monorepo Structure

The Sancta Via project is organized as a Flutter monorepo with shared packages:

```
sancta_via/
├── sancta_via_prayer_companion/      # Prayer app
├── sancta_via_novena_companion/      # Novena tracking app
├── sancta_via_liturgical_calendar_app/  # Liturgical calendar app
├── sancta_via_confession_companion/  # Confession preparation app
├── sancta_via_bible_reading_app/     # Bible reading app
├── sancta_via_liturgical_calendar/   # Pure Dart calendar data
├── sancta_via_liturgical_calendar_riverpod/  # Riverpod providers
├── sancta_via_shared_ui/             # Shared UI components
├── sancta_via_bible_data/            # Bible texts (pure Dart)
└── sancta_via_bible_data_riverpod/   # Bible providers
```

### Feature-Based Directory Structure

Each app follows a feature-based organization:

```
lib/
├── main.dart
├── config/
│   └── routes.dart
├── models/
│   └── <model>.dart
├── repositories/
│   └── <entity>_repository.dart
├── providers/
│   └── <feature>_providers.dart
├── services/
│   └── <service_name>_service.dart
├── screens/
│   └── <feature>/
│       └── <screen>_screen.dart
├── widgets/
│   └── <widget_name>.dart
├── database/
│   └── <entity>_database.dart
└── utils/
    └── logger.dart
```

### Dependency Direction

```
┌─────────────────────────────────────────────────────────────┐
│                        UI Layer                              │
│  (screens/, widgets/)                                        │
├─────────────────────────────────────────────────────────────┤
│                    State Management                          │
│  (providers/ - Riverpod)                                     │
├─────────────────────────────────────────────────────────────┤
│                     Data Layer                               │
│  (repositories/, services/, database/)                       │
├─────────────────────────────────────────────────────────────┤
│                      Models                                  │
│  (models/ - Pure Dart classes)                               │
└─────────────────────────────────────────────────────────────┘
```

---

## 2. State Management Patterns

### Riverpod Provider Types

The codebase uses three main Riverpod provider patterns:

#### FutureProvider (Read-Only Async Data)

```dart
// For one-time data loading
final allPrayersProvider = FutureProvider<List<Prayer>>((ref) async {
  final repository = ref.watch(prayerRepositoryProvider);
  return await repository.getAllPrayers();
});

// With family for parameterized queries
final prayerProvider = FutureProvider.family<Prayer?, String>((ref, prayerId) async {
  final repository = ref.watch(prayerRepositoryProvider);
  return await repository.getPrayer(prayerId);
});
```

**When to use**: Loading data that doesn't change frequently, list views, detail views.

#### StateNotifierProvider (Mutable State)

```dart
class PrayerAppSettingsNotifier extends StateNotifier<PrayerAppSettings> {
  final Ref _ref;
  
  PrayerAppSettingsNotifier(this._ref) : super(PrayerAppSettings.defaults()) {
    _loadSettings();
  }
  
  Future<void> toggleFavorite(String prayerId) async {
    if (state.isFavorite(prayerId)) {
      state = state.removeFavorite(prayerId);
    } else {
      state = state.addFavorite(prayerId);
    }
    await _saveSettings();
  }
}

final prayerAppSettingsProvider =
    StateNotifierProvider<PrayerAppSettingsNotifier, PrayerAppSettings>((ref) {
  return PrayerAppSettingsNotifier(ref);
});
```

**When to use**: User preferences, favorites, settings, complex state mutations.

#### StateProvider (Simple State)

```dart
// For simple state like search queries
final searchQueryProvider = StateProvider<String>((ref) => '');

// For filter toggles
final showFavoritesOnlyProvider = StateProvider<bool>((ref) => false);
```

**When to use**: Simple boolean toggles, string filters, selected values.

### Derived Providers

Create computed state by combining providers:

```dart
// Derive favorites from all prayers and settings
final favoritePrayersProvider = FutureProvider<List<Prayer>>((ref) async {
  final allPrayers = await ref.watch(allPrayersProvider.future);
  final settings = ref.watch(prayerPreferencesProvider);
  
  return allPrayers
      .where((prayer) => settings.favoritePrayerIds.contains(prayer.id))
      .toList();
});

// Derived convenience providers
final fontSizeProvider = Provider<double>((ref) {
  return ref.watch(prayerAppSettingsProvider).fontSize;
});
```

### Provider Anti-Patterns to Avoid

```dart
// ❌ WRONG: Creating new instances in build
Widget build(BuildContext context) {
  final provider = Provider((ref) => SomeClass()); // Creates new provider each build
}

// ✅ CORRECT: Define providers at module level
final someProvider = Provider<SomeClass>((ref) => SomeClass());
```

---

## 3. Data Layer Patterns

### Repository Pattern

Repositories abstract data sources and provide a clean API:

```dart
class PrayerRepository {
  // Singleton with optional injection for testing
  static PrayerRepository? _instance;
  final PrayerDatabase _database;
  
  PrayerRepository._internal({PrayerDatabase? database})
      : _database = database ?? PrayerDatabase.instance;
  
  static PrayerRepository get instance {
    _instance ??= PrayerRepository._internal();
    return _instance!;
  }
  
  // For testing with mocked database
  factory PrayerRepository({PrayerDatabase? database}) {
    return PrayerRepository._internal(database: database);
  }
  
  // Caching
  List<Prayer>? _cachedPrayers;
  
  Future<List<Prayer>> getAllPrayers() async {
    if (_cachedPrayers != null) return _cachedPrayers!;
    
    try {
      final prayers = await _database.getAllPrayers();
      _cachedPrayers = prayers;
      return prayers;
    } catch (e) {
      AppLogger.error('Failed to load prayers', e, null, 'REPO');
      return []; // Safe default
    }
  }
  
  void clearCache() {
    _cachedPrayers = null;
  }
}
```

### Repository Provider Pattern

```dart
// Provider for repository (supports testing)
final prayerRepositoryProvider = Provider<PrayerRepository>((ref) {
  return PrayerRepository();
});
```

### Database Singleton Pattern

```dart
class PrayerDatabase {
  static PrayerDatabase? _instance;
  static Database? _database;
  
  PrayerDatabase._();
  
  static PrayerDatabase get instance {
    _instance ??= PrayerDatabase._();
    return _instance!;
  }
  
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }
}
```

### ⚠️ N+1 Query Problem (Known Issue)

The current `getAllPrayers()` implementation has an N+1 query issue:

```dart
// ❌ CURRENT - N+1 queries problem
Future<List<Prayer>> getAllPrayers() async {
  final prayerMaps = await db.query('prayers');
  final List<Prayer> prayers = [];
  
  for (final prayerMap in prayerMaps) {
    // Each prayer triggers 3 additional queries!
    final categories = await db.query('prayer_categories', where: 'prayer_id = ?', whereArgs: [prayerId]);
    final tags = await db.query('prayer_tags', where: 'prayer_id = ?', whereArgs: [prayerId]);
    final translations = await db.query('prayer_translations', where: 'prayer_id = ?', whereArgs: [prayerId]);
    prayers.add(Prayer(...));
  }
  return prayers;
}
```

**Better approach** (recommended improvement):

```dart
// ✅ BETTER - Batch loading with joins
Future<List<Prayer>> getAllPrayers() async {
  final db = await database;
  
  // Single queries with joins
  final prayerMaps = await db.query('prayers');
  final allCategories = await db.query('prayer_categories');
  final allTags = await db.query('prayer_tags');
  final allTranslations = await db.query('prayer_translations');
  
  // Group in memory
  final categoriesByPrayer = _groupByPrayerId(allCategories);
  final tagsByPrayer = _groupByPrayerId(allTags);
  final translationsByPrayer = _groupByPrayerId(allTranslations);
  
  return prayerMaps.map((map) => Prayer(
    id: map['id'],
    categories: categoriesByPrayer[map['id']] ?? [],
    tags: tagsByPrayer[map['id']] ?? [],
    translations: translationsByPrayer[map['id']] ?? {},
  )).toList();
}
```

---

## 4. Navigation Patterns

### GoRouter Configuration

All apps use GoRouter for declarative navigation:

```dart
final appRouter = GoRouter(
  initialLocation: '/',
  debugLogDiagnostics: false,
  
  routes: [
    GoRoute(
      path: '/',
      name: 'home',
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: '/prayer/:prayerId',
      name: 'prayer-detail',
      builder: (context, state) {
        final prayerId = state.pathParameters['prayerId']!;
        return PrayerDetailScreen(prayerId: prayerId);
      },
    ),
    GoRoute(
      path: '/settings',
      name: 'settings',
      builder: (context, state) => const SettingsScreen(),
    ),
  ],
  
  errorBuilder: (context, state) => Scaffold(
    appBar: AppBar(title: const Text('Page Not Found')),
    body: Center(
      child: Column(
        children: [
          const Icon(Icons.error_outline, size: 64),
          Text('No route found for ${state.uri.path}'),
          ElevatedButton(
            onPressed: () => context.go('/'),
            child: const Text('Go Home'),
          ),
        ],
      ),
    ),
  ),
);
```

### Navigation Within Widgets

```dart
// Push with GoRouter
context.push('/prayer/${prayer.id}');

// Navigate to named route
context.go('/settings');

// Return to previous screen
Navigator.of(context).pop();

// For modal dialogs (not GoRouter managed)
Navigator.of(context).push(MaterialPageRoute(
  builder: (_) => const SettingsScreen(),
));
```

---

## 5. Widget Patterns

### ConsumerWidget for Riverpod

```dart
class PrayerDetailScreen extends ConsumerWidget {
  final String prayerId;
  
  const PrayerDetailScreen({required this.prayerId, super.key});
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch providers for reactive updates
    final prayerAsync = ref.watch(prayerProvider(prayerId));
    final preferences = ref.watch(prayerPreferencesProvider);
    
    // Listen for side effects
    ref.listen(prayerProvider(prayerId), (previous, next) {
      if (next.hasValue && next.value != null) {
        ref.read(prayerAppSettingsProvider.notifier).addToRecent(prayerId);
      }
    });
    
    return Scaffold(
      appBar: AppBar(title: const Text('Prayer')),
      body: prayerAsync.when(
        data: (prayer) => PrayerContent(prayer: prayer!),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => ErrorWidget(error: error),
      ),
    );
  }
}
```

### AsyncValue Pattern

Handle loading, data, and error states:

```dart
body: prayerAsync.when(
  data: (prayer) {
    if (prayer == null) {
      return const Center(child: Text('Prayer not found'));
    }
    return PrayerContent(prayer: prayer);
  },
  loading: () => const Center(child: CircularProgressIndicator()),
  error: (error, stack) => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.error_outline, size: 64, color: Theme.of(context).colorScheme.error),
        const SizedBox(height: 16),
        Text('Error loading data', style: Theme.of(context).textTheme.headlineSmall),
        Text(error.toString(), textAlign: TextAlign.center),
      ],
    ),
  ),
),
```

### ⚠️ DateTime.now() in Build Methods (Known Issue)

Avoid calling `DateTime.now()` directly in build methods:

```dart
// ❌ WRONG - Creates new date every build, breaks testing
Widget build(BuildContext context) {
  final now = DateTime.now();
  final isToday = date.year == now.year && date.month == now.month && date.day == now.day;
}

// ✅ CORRECT - Use a provider
final currentDateProvider = Provider<DateTime>((ref) => DateTime.now());

// Or pass as parameter
class CalendarDay extends StatelessWidget {
  final DateTime date;
  final DateTime currentDate; // Injected from parent
  
  bool get isToday => date.year == currentDate.year && 
                      date.month == currentDate.month && 
                      date.day == currentDate.day;
}
```

### Accessible Widget Pattern

```dart
// ✅ Include semantic labels
Semantics(
  label: 'Prayer: ${prayer.title}',
  button: true,
  child: GestureDetector(
    onTap: () => context.push('/prayer/${prayer.id}'),
    child: PrayerCard(prayer: prayer),
  ),
)

// ✅ Provide tooltip for icon buttons
IconButton(
  icon: const Icon(Icons.favorite),
  onPressed: () => toggleFavorite(),
  tooltip: isFavorite ? 'Remove from favorites' : 'Add to favorites',
)
```

---

## 6. Error Handling Patterns

### AppLogger Pattern

All apps use `AppLogger` for consistent logging:

```dart
class AppLogger {
  static const String _prefix = '[AppPrefix]';
  
  /// Debug logs (debug mode only)
  static void debug(String message, [String? tag]) {
    if (kDebugMode) {
      final tagStr = tag != null ? '[$tag]' : '';
      print('$_prefix$tagStr DEBUG: $message');
    }
  }
  
  /// Info logs (debug mode only)
  static void info(String message, [String? tag]) {
    if (kDebugMode) {
      final tagStr = tag != null ? '[$tag]' : '';
      print('$_prefix$tagStr INFO: $message');
    }
  }
  
  /// Warnings (debug mode)
  static void warning(String message, [String? tag]) {
    if (kDebugMode) {
      final tagStr = tag != null ? '[$tag]' : '';
      print('$_prefix$tagStr WARNING: $message');
    }
  }
  
  /// Errors (always logged)
  static void error(String message, [dynamic error, StackTrace? stackTrace, String? tag]) {
    if (kDebugMode) {
      print('$_prefix$tagStr ERROR: $message');
      if (error != null) print('Error details: $error');
      if (stackTrace != null) print('Stack trace: $stackTrace');
    }
  }
}
```

### Repository Error Handling

```dart
Future<List<Prayer>> getAllPrayers() async {
  try {
    await _ensureMigrationComplete();
    final prayers = await _database.getAllPrayers();
    _cachedPrayers = prayers;
    
    AppLogger.info('Loaded ${prayers.length} prayers from database', 'REPO');
    return prayers;
  } catch (e) {
    AppLogger.error('Error loading prayers from database', e, null, 'REPO');
    return []; // Return safe default, never throw
  }
}
```

### ⚠️ Silent Failure Anti-Pattern

```dart
// ❌ WRONG - Silent failure, hard to debug
Future<void> _saveSettings() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, json.encode(state.toJson()));
  } catch (e) {
    // Silent failure - user never knows save failed!
  }
}

// ✅ CORRECT - Log the error
Future<void> _saveSettings() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, json.encode(state.toJson()));
  } catch (e) {
    AppLogger.error('Failed to save settings', e, null, 'SETTINGS');
    // Optionally notify user or retry
  }
}
```

---

## 7. Testing Patterns

### Repository Testing with Mockito

```dart
@GenerateMocks([PrayerDatabase])
import 'prayer_repository_test.mocks.dart';

void main() {
  group('PrayerRepository', () {
    late MockPrayerDatabase mockDatabase;
    late PrayerRepository repository;
    
    setUp(() {
      mockDatabase = MockPrayerDatabase();
      repository = PrayerRepository(database: mockDatabase);
    });
    
    test('returns prayers from database', () async {
      // Arrange
      when(mockDatabase.getAllPrayers()).thenAnswer((_) async => [testPrayer]);
      
      // Act
      final result = await repository.getAllPrayers();
      
      // Assert
      expect(result, hasLength(1));
      verify(mockDatabase.getAllPrayers()).called(1);
    });
    
    test('returns empty list on error', () async {
      // Arrange
      when(mockDatabase.getAllPrayers()).thenThrow(Exception('DB error'));
      
      // Act
      final result = await repository.getAllPrayers();
      
      // Assert - never throw, return safe default
      expect(result, isEmpty);
    });
  });
}
```

### Running Tests

```bash
# All tests
flutter test

# Specific test file
flutter test test/repositories/prayer_repository_test.dart

# With coverage
flutter test --coverage

# Generate mocks
flutter pub run build_runner build
```

### Test Coverage Gaps (Known Issue)

Current coverage gaps:
- Widget tests limited
- Integration tests missing
- Error scenarios undertested

---

## 8. Common Pitfalls to Avoid

### 1. State Management in StatefulWidget

```dart
// ❌ WRONG - Don't use StatefulWidget for business logic
class PrayerListScreen extends StatefulWidget {
  @override
  State<PrayerListScreen> createState() => _PrayerListScreenState();
}

class _PrayerListScreenState extends State<PrayerListScreen> {
  List<Prayer> _prayers = [];
  
  @override
  void initState() {
    super.initState();
    _loadPrayers(); // Manual loading
  }
}

// ✅ CORRECT - Use Riverpod ConsumerWidget
class PrayerListScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prayersAsync = ref.watch(allPrayersProvider);
    return prayersAsync.when(...);
  }
}
```

### 2. Direct Database Access

```dart
// ❌ WRONG - Bypassing repository
final prayers = await PrayerDatabase.instance.getAllPrayers();

// ✅ CORRECT - Use repository
final repository = ref.read(prayerRepositoryProvider);
final prayers = await repository.getAllPrayers();
```

### 3. Deprecated Repository Methods

```dart
// ❌ WRONG - Using deprecated methods
await repository.toggleFavorite(prayerId);

// ✅ CORRECT - Use settings provider
await ref.read(prayerAppSettingsProvider.notifier).toggleFavorite(prayerId);
```

### 4. Missing Trailing Commas

```dart
// ❌ WRONG
Widget build(BuildContext context) {
  return Column(children: [
    Text('Hello'),
    Text('World')
  ]);
}

// ✅ CORRECT - Required by analysis_options.yaml
Widget build(BuildContext context) {
  return Column(
    children: [
      Text('Hello'),
      Text('World'),
    ],
  );
}
```

### 5. Implicit Types

```dart
// ❌ WRONG - implicit-casts: false in analysis_options
final prayers = data; // What type is this?

// ✅ CORRECT - Explicit types
final List<Prayer> prayers = data;

// ❌ WRONG - implicit-dynamic: false
final json = {'key': 'value'}['key']; // Dynamic

// ✅ CORRECT
final String? value = (json as Map<String, dynamic>)['key'] as String?;
```

### 6. Accessible Widget Omission

```dart
// ❌ WRONG - No accessibility information
GestureDetector(
  onTap: () => playPrayer(),
  child: Icon(Icons.play_arrow),
)

// ✅ CORRECT - Include semantics
Semantics(
  button: true,
  label: 'Play prayer audio',
  child: GestureDetector(
    onTap: () => playPrayer(),
    child: Icon(Icons.play_arrow),
  ),
)
```

---

## 9. Recommended Improvements

### From Code Reviews

#### 1. Fix N+1 Queries in Database Layer

**Priority: High**

The database layer makes multiple queries per entity. Implement batch loading:

```dart
// Recommended: Use single queries with in-memory grouping
Future<List<Prayer>> getAllPrayersOptimized() async {
  final db = await database;
  
  // Load all data in 4 queries instead of N*4
  final prayers = await db.query('prayers');
  final categories = await db.query('prayer_categories');
  final tags = await db.query('prayer_tags');
  final translations = await db.query('prayer_translations');
  
  // Group in memory (O(n) instead of O(n²))
  final categoryMap = _groupByPrayerId(categories, 'category_id');
  final tagsMap = _groupByPrayerId(tags, 'tag');
  
  return _mapToPrayers(prayers, categoryMap, tagsMap, translations);
}
```

#### 2. DateTime Provider for Testability

**Priority: Medium**

Create a testable current time provider:

```dart
// Add to providers
final currentDateTimeProvider = StateProvider<DateTime>((ref) => DateTime.now());

// In tests, override:
ProviderScope(
  overrides: [
    currentDateTimeProvider.overrideWithValue(
      StateController(DateTime(2024, 12, 25)),
    ),
  ],
  child: MyWidget(),
)
```

#### 3. Accessibility Audit

**Priority: Medium**

Add semantics to interactive widgets:

```dart
// Create reusable accessible widgets
class AccessibleCard extends StatelessWidget {
  final String label;
  final Widget child;
  final VoidCallback? onTap;
  
  const AccessibleCard({
    required this.label,
    required this.child,
    this.onTap,
    super.key,
  });
  
  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: onTap != null,
      label: label,
      child: InkWell(
        onTap: onTap,
        child: child,
      ),
    );
  }
}
```

#### 4. Comprehensive Error Logging

**Priority: Low**

Improve silent failure handling:

```dart
// Add optional error callbacks
class PrayerRepository {
  final void Function(String, dynamic)? onError;
  
  Future<void> _saveSettings() async {
    try {
      // ... save logic
    } catch (e) {
      AppLogger.error('Failed to save', e, null, 'REPO');
      onError?.call('Failed to save settings', e);
    }
  }
}
```

#### 5. Test Coverage Expansion

**Priority: Medium**

- Add widget tests for all screens
- Add integration tests for critical flows
- Test error scenarios

```dart
// Widget test template
testWidgets('PrayerDetailScreen displays prayer', (tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        prayerProvider.overrideWith((ref, id) => 
          AsyncValue.data(testPrayer)),
      ],
      child: const MaterialApp(
        home: PrayerDetailScreen(prayerId: 'test-id'),
      ),
    ),
  );
  
  expect(find.text('Test Prayer'), findsOneWidget);
});
```

---

## Shared Packages Usage

### sancta_via_liturgical_calendar

Pure Dart package for liturgical calendar data:

```dart
import 'package:sancta_via_liturgical_calendar/sancta_via_liturgical_calendar.dart';

final day = LiturgicalCalendar.getDay(DateTime.now());
print(day.celebration.name); // "Sunday of Ordinary Time"
print(day.season); // "ordinary_time"
print(day.celebration.color); // LiturgicalColor.green
```

### sancta_via_liturgical_calendar_riverpod

Riverpod providers for the calendar:

```dart
import 'package:sancta_via_liturgical_calendar_riverpod/sancta_via_liturgical_calendar_riverpod.dart';

// In widget
final liturgicalDay = ref.watch(currentLiturgicalDayProvider);
final liturgicalColor = ref.watch(currentLiturgicalColorProvider);
final colorIntensity = ref.watch(colorIntensityProvider);
```

### sancta_via_shared_ui

Shared UI components with liturgical theming:

```dart
import 'package:sancta_via_shared_ui/sancta_via_shared_ui.dart';

// Base settings (shared across apps)
final baseSettings = ref.watch(baseSettingsProvider);
await ref.read(baseSettingsProvider.notifier).setFontSize(18.0);

// Theme-aware widgets
LiturgicalColorPreview()
FontSizeSelector()
LanguageSelector()
ColorIntensitySelector()
```

### sancta_via_bible_data / sancta_via_bible_data_riverpod

Bible data and providers:

```dart
import 'package:sancta_via_bible_data_riverpod/sancta_via_bible_data_riverpod.dart';

final verses = ref.watch(bibleVersesProvider);
final searchResults = ref.watch(bibleSearchProvider(query));
```

---

## Liturgical Theming

All apps use dynamic theming based on the Catholic liturgical calendar:

| Season/Event | Color | Usage |
|-------------|-------|-------|
| Ordinary Time | Green | Default Sundays |
| Advent | Purple | Preparation for Christmas |
| Lent | Purple | Preparation for Easter |
| Gaudete Sunday (Advent 3) | Rose | Joy in waiting |
| Laetare Sunday (Lent 4) | Rose | Joy in anticipation |
| Christmas, Easter | White/Gold | Celebration |
| Pentecost, Martyrs | Red | Holy Spirit, Blood of Martyrs |

### Color Intensity

Supports vibrant and muted intensity options:

```dart
final colorIntensity = ref.watch(colorIntensityProvider);

// Apply to widgets
final themeColor = liturgicalColor?.toFlutterColor(colorIntensity);
Container(
  decoration: BoxDecoration(
    color: themeColor?.withValues(alpha: 0.2),
    border: Border.all(color: themeColor ?? Colors.grey),
  ),
)
```

---

## Pre-Commit Checklist

Before committing, always run:

```bash
# 1. Format code
dart format .

# 2. Static analysis
flutter analyze

# 3. Run tests
flutter test
```

---

## Code Style Summary

From `analysis_options.yaml`:

- **Strings**: Single quotes (`'text'`)
- **Trailing commas**: Required on all function/constructor calls
- **Types**: No implicit casts or dynamic
- **Immutable**: Prefer `const` constructors, `final` fields
- **Widgets**: Use keys in widget constructors
- **Spacing**: SizedBox for whitespace (not Container)

---

*This document should be updated as patterns evolve. Last updated: 2024*