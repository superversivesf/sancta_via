# Sancta Via Liturgical Calendar Riverpod

Reactive Riverpod providers for **sancta_via_liturgical_calendar** with automatic updates and Flutter UI integration.

Part of the **Sancta Via Catholic Apps Ecosystem**.

## 🔄 **Reactive Liturgical Data**

This package provides comprehensive Riverpod providers that make liturgical calendar data **reactive and automatic**:

- 🔄 **Auto-updates at midnight** - Never stale data
- ⚡ **Zero-overhead performance** - Built on embedded data  
- 🎨 **Flutter UI integration** - Colors, themes, icons
- 📱 **Responsive state management** - Perfect for Catholic apps
- 🔍 **Rich provider ecosystem** - 30+ specialized providers

## 🚀 **Quick Start**

### Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  sancta_via_liturgical_calendar_riverpod:
    git:
      url: https://github.com/superversivesf/sancta_via_liturgical_calendar_riverpod.git
      ref: v2.0.0
```

### Basic Usage

```dart
import 'package:flutter/material.dart';
import 'package:sancta_via_liturgical_calendar_riverpod/sancta_via_liturgical_calendar_riverpod.dart';

class LiturgicalWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Automatically updates at midnight!
    final today = ref.watch(currentLiturgicalDayProvider);
    final color = ref.watch(liturgicalColorProvider);
    final icon = ref.watch(seasonIconProvider);
    
    return Card(
      color: color.withOpacity(0.1),
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(today?.celebration.name ?? 'Loading...'),
        subtitle: Text(today?.season ?? ''),
        trailing: today?.celebration.prioritized == true 
          ? Icon(Icons.star, color: Colors.amber)
          : null,
      ),
    );
  }
}

void main() {
  runApp(
    ProviderScope(  // Required for Riverpod
      child: MyApp(),
    ),
  );
}
```

## 📅 **Core Providers**

### **Reactive Current Day**
```dart
// Main provider - updates automatically at midnight
final today = ref.watch(currentLiturgicalDayProvider);

// Current season (Advent, Christmas, Lent, etc.)
final season = ref.watch(currentLiturgicalSeasonProvider);

// Current liturgical color
final color = ref.watch(currentLiturgicalColorProvider);

// Is today a major celebration?
final isPrioritized = ref.watch(todayHasPrioritizedCelebrationProvider);
```

### **Liturgical Data Access**
```dart
// Get specific date
final christmas = ref.watch(liturgicalDayProvider(DateTime(2025, 12, 25)));

// Upcoming celebrations (next 7 days)
final upcoming = ref.watch(upcomingFeastsProvider(7));

// Search for celebrations
final maryFeasts = ref.watch(searchCelebrationsProvider((
  query: 'Mary', 
  year: 2025
)));

// Days in a season
final adventDays = ref.watch(seasonDaysProvider((
  year: 2025, 
  season: 'Advent'
)));
```

### **Flutter UI Integration**
```dart
// Liturgical color as Flutter Color
final color = ref.watch(liturgicalColorProvider);

// Season-appropriate theme
final theme = ref.watch(liturgicalThemeProvider);

// Season icon (Icons.*)
final icon = ref.watch(seasonIconProvider);

// Formatted display info
final info = ref.watch(liturgicalInfoProvider);
```

### **Analytics & Utilities**
```dart
// Global statistics
final stats = ref.watch(globalStatisticsProvider);

// This week's liturgical days
final thisWeek = ref.watch(thisWeekProvider);

// Next major celebration
final nextMajor = ref.watch(nextMajorCelebrationProvider);

// Liturgical reminders/notifications
final reminders = ref.watch(liturgicalRemindersProvider);
```

## 🎨 **UI Examples**

### **Automatic Theme Updates**
```dart
class MyApp extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Theme automatically adapts to liturgical season!
    final theme = ref.watch(liturgicalThemeProvider);
    
    return MaterialApp(
      theme: theme,  // Purple in Advent, White at Christmas, etc.
      home: HomePage(),
    );
  }
}
```

### **Responsive Calendar Widget**
```dart
class WeeklyCalendar extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final thisWeek = ref.watch(thisWeekProvider);
    
    return Column(
      children: thisWeek.map((day) {
        final color = ref.watch(liturgicalColorByDateProvider(
          DateTime.parse(day.date)
        ));
        
        return ListTile(
          leading: CircleAvatar(backgroundColor: color),
          title: Text(day.celebration.name),
          subtitle: Text(day.season),
          trailing: day.celebration.prioritized 
            ? Icon(Icons.star)
            : null,
        );
      }).toList(),
    );
  }
}
```

### **Search Interface**
```dart
class CelebrationSearch extends ConsumerStatefulWidget {
  @override
  ConsumerState<CelebrationSearch> createState() => _SearchState();
}

class _SearchState extends ConsumerState<CelebrationSearch> {
  String query = '';
  
  @override
  Widget build(BuildContext context) {
    final results = ref.watch(searchCelebrationsProvider((
      query: query, 
      year: null
    )));
    
    return Column(
      children: [
        TextField(
          onChanged: (value) => setState(() => query = value),
          decoration: InputDecoration(hintText: 'Search celebrations...'),
        ),
        ...results.map((result) => ListTile(
          title: Text(result.celebration.name),
          subtitle: Text('${result.date} • ${result.season}'),
        )),
      ],
    );
  }
}
```

## 🔄 **Automatic Updates**

The providers automatically update when:
- **Midnight occurs** - Current day providers refresh
- **Dependencies change** - Reactive provider chain
- **Manual refresh** - Using `ref.refresh(provider)`

```dart
class HomePage extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // This widget automatically rebuilds at midnight!
    final today = ref.watch(currentLiturgicalDayProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: Text('Today: ${today?.celebration.name}'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () {
              // Manual refresh if needed
              ref.refresh(currentLiturgicalDayProvider);
            },
          ),
        ],
      ),
      // ... rest of UI
    );
  }
}
```

## 📊 **Complete Provider Reference**

### **Current Day & Reactivity**
- `currentDateProvider` - Stream that updates at midnight
- `currentLiturgicalDayProvider` - Current liturgical day
- `currentLiturgicalSeasonProvider` - Current season
- `currentLiturgicalColorProvider` - Current color
- `currentCelebrationRankProvider` - Current rank
- `todayHasPrioritizedCelebrationProvider` - Is today special?

### **Data Access**
- `liturgicalDayProvider(date)` - Specific date
- `upcomingFeastsProvider(days)` - Upcoming celebrations
- `daysInRangeProvider(start, end)` - Date range
- `searchCelebrationsProvider(query, year)` - Search
- `seasonDaysProvider(year, season)` - Seasonal days
- `allDaysInYearProvider(year)` - Complete year

### **UI Integration** 
- `liturgicalColorProvider` - Current Flutter Color
- `liturgicalThemeProvider` - Season-based ThemeData
- `seasonIconProvider` - Appropriate Icons.*
- `rankIconProvider` - Icon for celebration rank
- `liturgicalInfoProvider` - Formatted display strings
- `upcomingCelebrationsUIProvider` - UI-ready upcoming list

### **Analytics & Utilities**
- `globalStatisticsProvider` - Overall data stats
- `liturgicalAnalyticsProvider(year)` - Year analytics
- `thisWeekProvider` - This week's days
- `thisMonthProvider` - This month's days
- `nextMajorCelebrationProvider` - Next important feast
- `liturgicalRemindersProvider` - Notification-ready reminders
- `liturgicalModeProvider` - Current liturgical "mode"
- `liturgicalYearProgressProvider` - Year completion %

## 🏗️ **Architecture Benefits**

### **Performance**
- ⚡ **Zero initialization** - No async loading
- 🚀 **Instant provider access** - Built on embedded data
- 📦 **Selective updates** - Only affected widgets rebuild
- 🔄 **Efficient caching** - Riverpod's built-in optimizations

### **Developer Experience**
- 🔧 **Type safety** - Full compile-time validation
- 🎯 **IntelliSense** - Rich autocompletion
- 🔍 **Provider Inspector** - Debug with Riverpod DevTools
- 📖 **Rich documentation** - Comprehensive examples

### **Reactive Patterns**
- 🔄 **Automatic updates** - No manual date checking
- 📱 **UI consistency** - All widgets stay in sync
- 🎨 **Theme coherence** - Colors and themes match liturgical data
- 🔔 **Notification ready** - Built-in reminder support

## 🛠️ **Development Setup**

```bash
# Clone and test the package
git clone https://github.com/superversivesf/sancta_via_liturgical_calendar_riverpod.git
cd sancta_via_liturgical_calendar_riverpod

# Install dependencies  
flutter pub get

# Run build_runner for generated providers
flutter packages pub run build_runner build

# Run tests
flutter test

# Try the examples
flutter run example/current_day_example.dart
```

## 🔄 **Compatibility**

- **Dart**: 3.7.2+
- **Flutter**: 3.7.2+
- **Riverpod**: 2.6.1+
- **Dependencies**: `sancta_via_liturgical_calendar` v2.0.0+

## 🏗️ **Part of Sancta Via Ecosystem**

This package is part of the broader Sancta Via Catholic Apps ecosystem:

- **sancta_via_liturgical_calendar** - Core liturgical data (this package depends on it)
- **sancta_via_liturgical_calendar_riverpod** - Riverpod providers (this package)
- **sancta_via_shared_ui** - Shared UI components with liturgical theming
- Various Catholic prayer and devotion apps

## 🤝 **Contributing**

Contributions welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Make your changes with tests
4. Run `flutter packages pub run build_runner build`
5. Submit a pull request

## 📄 **License**

MIT License - see [LICENSE](LICENSE) file for details.

---

**Reactive liturgical data for modern Catholic Flutter apps.** 🙏✨
*Part of the Sancta Via Catholic Apps Ecosystem*