# APP_BUILD_RULES.md - Architecture Patterns for Sancta Via Apps

This document defines the six core architecture patterns used across all Sancta Via applications. Follow these patterns when building new features or apps.

---

## Table of Contents

1. [Repository Pattern](#1-repository-pattern)
2. [Riverpod Provider Pattern](#2-riverpod-provider-pattern)
3. [Settings Pattern](#3-settings-pattern)
4. [Navigation Pattern](#4-navigation-pattern)
5. [Theming Pattern](#5-theming-pattern)
6. [Testing Pattern](#6-testing-pattern)

---

## 1. Repository Pattern

### Purpose
Single source of truth for data access with built-in caching and error handling.

### Key Principles
- **Singleton pattern** with optional dependency injection for testing
- **Nullable caching** with `_cachedData` fields
- **Migration awareness** for database transitions
- **AppLogger** for all error handling (never raw `print`)

### Implementation

```dart
/// Repository with caching, migration support, and error handling
class ExampleRepository {
  // Database instance (injectable for testing)
  final ExampleDatabase _database;
  final bool _skipMigration;

  // Nullable cache fields - null until first load
  List<Example>? _cachedItems;
  List<Category>? _cachedCategories;
  bool _migrationChecked = false;

  /// Create repository with optional database injection (for testing)
  ExampleRepository({ExampleDatabase? database})
      : _database = database ?? ExampleDatabase.instance,
        _skipMigration = database != null;

  /// Ensure migration complete before any data access
  Future<void> _ensureMigrationComplete() async {
    if (_migrationChecked || _skipMigration) return;

    try {
      AppLogger.info('Checking database migration status...');
      if (await DatabaseMigrationService.isMigrationNeeded()) {
        await DatabaseMigrationService.migrateJsonToDatabase();
        AppLogger.info('Database migration completed');
      }
      _migrationChecked = true;
    } catch (e) {
      AppLogger.error('Database migration failed', e, null, 'MIGRATION');
      _migrationChecked = true; // Avoid infinite retry
      rethrow;
    }
  }

  /// Get all items with caching
  Future<List<Example>> getAllItems() async {
    // Return cached data if available
    if (_cachedItems != null) {
      return _cachedItems!;
    }

    try {
      await _ensureMigrationComplete();
      final items = await _database.getAllItems();
      _cachedItems = items;

      AppLogger.info('Loaded ${items.length} items', 'REPO');
      return items;
    } catch (e) {
      AppLogger.error('Error loading items', e, null, 'REPO');
      return []; // Return safe default
    }
  }

  /// Clear cache to force fresh data
  void clearCache() {
    _cachedItems = null;
    _cachedCategories = null;
    AppLogger.info('Cache cleared', 'REPO');
  }
}
```

### Rules
1. **NEVER** access the database directly from UI code - always use repository
2. **ALWAYS** return safe defaults (empty lists, null) on error
3. **ALWAYS** use `AppLogger` for logging, never `print()`
4. **CHECK** cache before database query
5. **INJECT** database for tests, use singleton for production

---

## 2. Riverpod Provider Pattern

### Purpose
Reactive state management with different provider types for different use cases.

### Provider Types

| Type | Use Case | Example |
|------|----------|---------|
| `Provider` | Simple computed values, singletons | Repository instances, derived state |
| `FutureProvider` | Async data loading (read-only) | Fetching data from repository |
| `FutureProvider.family` | Parameterized async data | Data by ID, filtered queries |
| `StateProvider` | Simple mutable state | Search query, toggle flags |
| `StateNotifierProvider` | Complex state with mutations | Settings, user preferences |

### Implementation

#### Simple Provider (for repositories, derived values)
```dart
/// Provider for repository singleton
final exampleRepositoryProvider = Provider<ExampleRepository>((ref) {
  return ExampleRepository();
});

/// Derived provider - watches another provider
final itemCountProvider = Provider<int>((ref) {
  final items = ref.watch(allItemsProvider).valueOrNull ?? [];
  return items.length;
});
```

#### FutureProvider (for async data loading)
```dart
/// Simple async data loading
final allItemsProvider = FutureProvider<List<Item>>((ref) async {
  final repository = ref.watch(exampleRepositoryProvider);
  return await repository.getAllItems();
});

/// Parameterized async data with .family
final itemByIdProvider = FutureProvider.family<Item?, String>((ref, id) async {
  final repository = ref.watch(exampleRepositoryProvider);
  return await repository.getItem(id);
});

/// Family with multiple parameters (use record type)
final itemsByCategoryAndTagProvider = FutureProvider.family<List<Item>, ({String category, String tag})>(
  (ref, params) async {
    final repository = ref.watch(exampleRepositoryProvider);
    return await repository.getItemsByCategoryAndTag(
      params.category,
      params.tag,
    );
  },
);
```

#### StateProvider (simple mutable state)
```dart
/// Simple toggle state
final showFavoritesOnlyProvider = StateProvider<bool>((ref) => false);

/// Search query state
final searchQueryProvider = StateProvider<String>((ref) => '');
```

#### StateNotifierProvider (complex state with persistence)
```dart
/// Notifier with persistence and sync to base settings
class AppSettingsNotifier extends StateNotifier<AppSettings> {
  static const String _storageKey = 'app_settings';
  final Ref _ref;

  AppSettingsNotifier(this._ref) : super(AppSettings.defaults()) {
    _loadSettings();
    
    // Sync with other providers
    _ref.listen(baseSettingsProvider, (previous, next) {
      if (previous != next) {
        _syncBaseSettings(next);
      }
    });
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_storageKey);
      if (json != null && mounted) {
        state = AppSettings.fromJson(jsonDecode(json));
      }
    } catch (e) {
      // Keep defaults on error
    }
  }

  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storageKey, jsonEncode(state.toJson()));
    } catch (e) {
      // Handle error
    }
  }

  void _syncBaseSettings(BaseSettingsModel newBase) {
    if (state.baseSettings != newBase) {
      state = state.updateBaseSettings(newBase);
      _saveSettings();
    }
  }

  Future<void> toggleFavorite(String id) async {
    state = state.isFavorite(id)
        ? state.removeFavorite(id)
        : state.addFavorite(id);
    await _saveSettings();
  }
}

final appSettingsProvider = StateNotifierProvider<AppSettingsNotifier, AppSettings>((ref) {
  return AppSettingsNotifier(ref);
});
```

### Rules
1. **USE** `Provider` for singletons and computed values
2. **USE** `FutureProvider` for async data that doesn't change
3. **USE** `FutureProvider.family` for parameterized data queries
4. **USE** `StateNotifierProvider` for mutable state needing persistence
5. **WATCH** providers with `ref.watch()` in providers, `ref.read()` in callbacks
6. **NEVER** use `StatefulWidget` for business logic - use providers

---

## 3. Settings Pattern

### Purpose
Hierarchical settings with shared base settings and app-specific extensions.

### Architecture

```
BaseSettingsModel (shared_ui)
├── fontSize: double
├── defaultLanguage: AppLanguage
├── notificationsEnabled: bool
├── showLiturgicalColors: bool
└── ...shared settings

AppSettings (app-specific)
├── baseSettings: BaseSettingsModel
├── favorites: List<String>
├── recentItems: List<String>
└── ...app-specific settings
```

### Base Settings Provider (in shared_ui)
```dart
/// Base settings shared across all apps
class BaseSettingsNotifier extends StateNotifier<BaseSettingsModel> {
  static const String _storageKey = 'sancta_via_base_settings';

  BaseSettingsNotifier() : super(BaseSettingsModel.defaults()) {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_storageKey);
      if (json != null && mounted) {
        state = BaseSettingsModel.fromJson(jsonDecode(json));
      }
    } catch (e) {
      // Keep defaults
    }
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(state.toJson()));
  }

  Future<void> setFontSize(double fontSize) async {
    state = state.copyWith(fontSize: fontSize.clamp(12.0, 32.0));
    await _saveSettings();
  }

  Future<void> setDefaultLanguage(AppLanguage language) async {
    state = state.copyWith(defaultLanguage: language);
    await _saveSettings();
  }
}

final baseSettingsProvider = StateNotifierProvider<BaseSettingsNotifier, BaseSettingsModel>((ref) {
  return BaseSettingsNotifier();
});
```

### App-Specific Settings Provider
```dart
/// App-specific settings extending base settings
class AppSettingsNotifier extends StateNotifier<AppSettings> {
  static const String _storageKey = 'prayer_app_settings';
  final Ref _ref;

  AppSettingsNotifier(this._ref) : super(AppSettings.defaults()) {
    _loadSettings();

    // Listen to base settings changes and sync
    _ref.listen(baseSettingsProvider, (previous, next) {
      if (previous != next) {
        _syncBaseSettings(next);
      }
    });
  }

  void _syncBaseSettings(BaseSettingsModel newBase) {
    if (state.baseSettings != newBase) {
      state = state.updateBaseSettings(newBase);
      _saveSettings();
    }
  }

  // Delegate to base provider for shared settings
  Future<void> updateFontSize(double fontSize) async {
    await _ref.read(baseSettingsProvider.notifier).setFontSize(fontSize);
  }

  // App-specific methods
  Future<void> toggleFavorite(String id) async {
    state = state.isFavorite(id)
        ? state.removeFavorite(id)
        : state.addFavorite(id);
    await _saveSettings();
  }
}

final appSettingsProvider = StateNotifierProvider<AppSettingsNotifier, AppSettings>((ref) {
  return AppSettingsNotifier(ref);
});
```

### Convenience Providers
```dart
/// Derived providers for specific settings (avoid repeated ref.watch)
final fontSizeProvider = Provider<double>((ref) {
  return ref.watch(baseSettingsProvider).fontSize;
});

final favoritesProvider = Provider<List<String>>((ref) {
  return ref.watch(appSettingsProvider).favoriteIds;
});
```

### Rules
1. **EXTEND** BaseSettingsModel for app-specific settings
2. **DELEGATE** shared settings to `baseSettingsProvider`
3. **SYNC** using `_ref.listen()` when base changes
4. **PERSIST** app-specific settings in app's own storage key
5. **PROVIDE** convenience providers for frequently accessed settings

---

## 4. Navigation Pattern

### Purpose
Declarative routing with GoRouter, named routes, and centralized error handling.

### Implementation

```dart
import 'package:go_router/go_router.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  debugLogDiagnostics: false,

  routes: [
    // Home route
    GoRoute(
      path: '/',
      name: 'home',
      builder: (context, state) => const HomeScreen(),
    ),

    // List routes
    GoRoute(
      path: '/items',
      name: 'items',
      builder: (context, state) => const ItemsScreen(),
    ),

    // Detail route with path parameter
    GoRoute(
      path: '/item/:itemId',
      name: 'item-detail',
      builder: (context, state) {
        final itemId = state.pathParameters['itemId']!;
        return ItemDetailScreen(itemId: itemId);
      },
    ),

    // Query parameters
    GoRoute(
      path: '/search',
      name: 'search',
      builder: (context, state) {
        final query = state.uri.queryParameters['q'] ?? '';
        return SearchScreen(initialQuery: query);
      },
    ),

    // Settings
    GoRoute(
      path: '/settings',
      name: 'settings',
      builder: (context, state) => const SettingsScreen(),
    ),
  ],

  // Centralized error handling
  errorBuilder: (context, state) => Scaffold(
    appBar: AppBar(
      title: const Text('Page Not Found'),
      automaticallyImplyLeading: true,
    ),
    body: Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64),
          const SizedBox(height: 16),
          Text(
            'Page Not Found',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text('No route found for ${state.uri.path}'),
          const SizedBox(height: 24),
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

### Navigation Methods

```dart
// Navigate using named route
context.goNamed('item-detail', pathParameters: {'itemId': '123'});

// Navigate with query parameters
context.go('/search?q=prayer');

// Navigate and replace current
context.replace('/settings');

// Go back
context.pop();

// Check if can pop
if (context.canPop()) {
  context.pop();
}
```

### Rules
1. **NAME** all routes for type-safe navigation
2. **USE** path parameters for IDs (`/item/:itemId`)
3. **USE** query parameters for optional data
4. **PROVIDE** centralized error handling
5. **USE** `context.goNamed()` over string paths

---

## 5. Theming Pattern

### Purpose
Dynamic theming based on Catholic liturgical calendar with color intensity options.

### Liturgical Colors

| Liturgical Season | Color | Usage |
|-------------------|-------|-------|
| Ordinary Time | Green | Default, growth |
| Advent, Lent | Purple | Penance, preparation |
| Gaudete/Laetare | Rose | Joy in midst of penance |
| Christmas, Easter | White | Celebration, resurrection |
| Pentecost, Martyrs | Red | Holy Spirit, blood of martyrs |
| High Feasts | Gold | Solemnities |

### Color Intensity

```dart
enum ColorIntensity {
  vibrant,
  muted;

  String get displayName {
    switch (this) {
      case ColorIntensity.vibrant:
        return 'Vibrant';
      case ColorIntensity.muted:
        return 'Muted';
    }
  }
}
```

### Providers

```dart
// Color intensity with persistence
final colorIntensityProvider = StateNotifierProvider<ColorIntensityNotifier, ColorIntensity>((ref) {
  return ColorIntensityNotifier();
});

// Current liturgical color from calendar
final liturgicalColorProvider = Provider<Color>((ref) {
  final colorString = ref.watch(currentLiturgicalColorProvider);
  return _getLiturgicalColor(colorString);
});

// Theme data based on liturgical color
final liturgicalThemeProvider = Provider<ThemeData>((ref) {
  final color = ref.watch(liturgicalColorProvider);
  final season = ref.watch(currentLiturgicalSeasonProvider);
  final intensity = ref.watch(colorIntensityProvider);

  return ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: _applyIntensity(color, intensity),
      brightness: _getSeasonBrightness(season),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: color,
      foregroundColor: _getContrastingTextColor(color),
    ),
  );
});
```

### Color Conversion Helper

```dart
Color _getLiturgicalColor(String? colorString) {
  switch (colorString?.toUpperCase()) {
    case 'WHITE':
      return Colors.grey.shade100;
    case 'RED':
      return Colors.red.shade700;
    case 'GREEN':
      return Colors.green.shade700;
    case 'PURPLE':
      return Colors.purple.shade700;
    case 'ROSE':
      return Colors.pink.shade300;
    case 'GOLD':
      return Colors.amber.shade600;
    default:
      return Colors.grey.shade500;
  }
}

Color _applyIntensity(Color color, ColorIntensity intensity) {
  if (intensity == ColorIntensity.muted) {
    return color.withOpacity(0.7);
  }
  return color;
}
```

### Usage in App

```dart
class MyApp extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final theme = ref.watch(liturgicalThemeProvider);
    final showLiturgicalColors = ref.watch(showLiturgicalColorsProvider);

    return MaterialApp.router(
      routerConfig: appRouter,
      theme: showLiturgicalColors ? theme : ThemeData.light(),
      darkTheme: showLiturgicalColors ? theme : ThemeData.dark(),
      themeMode: themeMode,
    );
  }
}
```

### Rules
1. **USE** `currentLiturgicalColorProvider` from liturgical_calendar_riverpod
2. **APPLY** `ColorScheme.fromSeed()` for Material 3 theming
3. **SUPPORT** vibrant/muted intensity toggle
4. **RESPECT** `showLiturgicalColorsProvider` for user preference
5. **CONTRAST** text color with background (check luminance)

---

## 6. Testing Pattern

### Purpose
Test repositories with Mockito, using dependency injection and mock generation.

### Test Structure
```
test/
├── repositories/
│   ├── example_repository_test.dart
│   └── example_repository_test.mocks.dart  # Generated
├── providers/
│   └── example_provider_test.dart
└── models/
    └── example_model_test.dart
```

### Repository Test Example

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

// Generate mocks - this creates example_repository_test.mocks.dart
@GenerateMocks([ExampleDatabase])
import 'example_repository_test.mocks.dart';

void main() {
  group('ExampleRepository - Feature Tests', () {
    late MockExampleDatabase mockDatabase;
    late ExampleRepository repository;

    // Helper to create test data
    Example createExample(String id, String name) {
      return Example(id: id, name: name);
    }

    setUp(() {
      mockDatabase = MockExampleDatabase();
      repository = ExampleRepository(database: mockDatabase);
    });

    group('getAllItems', () {
      test('returns items from database', () async {
        // Arrange
        final expectedItems = [
          createExample('1', 'Item 1'),
          createExample('2', 'Item 2'),
        ];
        when(mockDatabase.getAllItems()).thenAnswer((_) async => expectedItems);

        // Act
        final result = await repository.getAllItems();

        // Assert
        expect(result, hasLength(2));
        expect(result.first.name, equals('Item 1'));
        verify(mockDatabase.getAllItems()).called(1);
      });

      test('returns empty list on error', () async {
        // Arrange
        when(mockDatabase.getAllItems()).thenThrow(Exception('DB error'));

        // Act
        final result = await repository.getAllItems();

        // Assert - graceful degradation
        expect(result, isEmpty);
      });

      test('caches results for subsequent calls', () async {
        // Arrange
        when(mockDatabase.getAllItems()).thenAnswer((_) async => [createExample('1', 'Item')]);

        // Act
        await repository.getAllItems();
        await repository.getAllItems();
        await repository.getAllItems();

        // Assert - database only called once due to cache
        verify(mockDatabase.getAllItems()).called(1);
      });
    });

    group('clearCache', () {
      test('clears cached data', () async {
        // Arrange
        when(mockDatabase.getAllItems()).thenAnswer((_) async => [createExample('1', 'Item')]);

        // Act
        await repository.getAllItems();
        repository.clearCache();
        await repository.getAllItems();

        // Assert - database called twice after cache clear
        verify(mockDatabase.getAllItems()).called(2);
      });
    });
  });
}
```

### Provider Test Example

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  group('ExampleProvider', () {
    test('provides repository instance', () {
      // Arrange
      final container = ProviderContainer();

      // Act
      final repository = container.read(exampleRepositoryProvider);

      // Assert
      expect(repository, isA<ExampleRepository>());
    });

    test('allItemsProvider returns data from repository', () async {
      // Arrange
      final container = ProviderContainer(
        overrides: [
          exampleRepositoryProvider.overrideWithValue(
            MockExampleRepository(),
          ),
        ],
      );

      // Act
      final items = await container.read(allItemsProvider.future);

      // Assert
      expect(items, isA<List<Example>>());
    });
  });
}
```

### Mock Generation

**Run this command to generate mocks:**
```bash
flutter pub run build_runner build
```

**Or watch for changes:**
```bash
flutter pub run build_runner watch
```

### Rules
1. **MIRROR** `lib/` structure in `test/`
2. **USE** `@GenerateMocks` annotation for mock generation
3. **INJECT** mocks via constructor in `setUp()`
4. **VERIFY** mock interactions with `verify()`
5. **TEST** error handling returns safe defaults
6. **NAME** test groups after the method/feature being tested
7. **FOLLOW** Arrange-Act-Assert pattern

---

## Quick Reference

### Import Order
```dart
// 1. Dart/Flutter SDK
import 'dart:convert';
import 'package:flutter/material.dart';

// 2. External packages
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// 3. Local relative imports
import '../models/example.dart';
import '../repositories/example_repository.dart';
```

### Code Style
- **Strings**: Single quotes (`'text'`)
- **Trailing commas**: Required on all multi-line calls
- **Types**: Explicit, no `var` or `dynamic`
- **Final**: Prefer for fields and locals
- **Const**: Use for constructors and literals
- **Private**: Prefix with `_`

### Commands
```bash
flutter test                          # Run all tests
flutter test test/path/to/test.dart   # Run specific test
flutter analyze                       # Static analysis
dart format .                         # Format code
```

---

## See Also
- [AGENTS.md](./AGENTS.md) - Quick reference for AI agents
- [README.md](./README.md) - Project overview
- Individual app `AGENTS.md` files for app-specific instructions