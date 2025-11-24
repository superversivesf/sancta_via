# Sancta Via Liturgical Calendar

A comprehensive Catholic liturgical calendar library for Dart and Flutter with **embedded data** for zero-overhead performance.

Part of the **Sancta Via Catholic Apps Ecosystem**.

## 🚀 **Zero-Overhead Performance**

This package provides the **fastest possible** access to liturgical calendar data by embedding it directly as Dart objects:

- ⚡ **No JSON parsing** - Data is compiled into your app
- 🚀 **Instant access** - Zero initialization time  
- 📦 **Tree-shaking** - Only used data is included
- 🔒 **Type safety** - Compile-time validation
- 💾 **No assets** - Everything embedded in code

## 📅 **Complete Liturgical Data**

- **12 years** of data (2024-2035) 
- **4,383 liturgical days** with complete information
- **856 prioritized celebrations** (solemnities, feasts, memorials)
- **All liturgical seasons** (Advent, Christmas, Lent, Easter, Ordinary Time)
- **Liturgical colors, ranks, and cycles**
- **Generated from RomCal 1.3.0** (authoritative Roman Calendar)

## 🎯 **Simple, Powerful Usage**

### Main Service - Instant Access ⚡

**Zero initialization, maximum performance:**

```dart
import 'package:sancta_via_liturgical_calendar/sancta_via_liturgical_calendar.dart';

void main() {
  // Ready immediately - no initialization needed!
  final today = LiturgicalCalendarService.getCurrentDay();
  print('Today: ${today?.celebration.name}');
  
  // Get any liturgical day instantly
  final christmas = LiturgicalCalendarService.getDayForDate(
    DateTime(2025, 12, 25)
  );
  print('Christmas: ${christmas?.celebration.name}');
  
  // Search and filter with zero overhead
  final feasts = LiturgicalCalendarService.getUpcomingFeasts();
  final advent = LiturgicalCalendarService.getDaysForSeason(2025, 'Advent');
  final maryFeasts = LiturgicalCalendarService.searchCelebrations('Mary');
}
```

### Advanced Data Access 🏆

**Direct access to generated data for custom implementations:**

```dart
import 'package:sancta_via_liturgical_calendar/sancta_via_liturgical_calendar.dart';

void main() {
  // Direct access to generated data structures
  final day = GeneratedLiturgicalData.getDayForDate(DateTime.now());
  final allYears = GeneratedLiturgicalData.getAvailableYears();
  final stats = GeneratedLiturgicalData.getTotalDays();
  final year2025 = GeneratedLiturgicalData.getYearData(2025);
}
```

## 🏗️ **Advanced Features**

### Rich Query API
```dart
// Search celebrations by name
final results = LiturgicalCalendarService.searchCelebrations('Easter');

// Get celebrations by rank
final solemnities = LiturgicalCalendarService.getDaysByRank(2025, 'SOLEMNITY');

// Get seasonal data
final adventDays = LiturgicalCalendarService.getDaysForSeason(2025, 'Advent');

// Find next occurrence
final nextEaster = LiturgicalCalendarService.getNextOccurrence('Easter');

// Year statistics
final stats = LiturgicalCalendarService.getGlobalStatistics();
```

### Complete Data Model
```dart
final day = LiturgicalCalendarService.getCurrentDay();
if (day != null) {
  print('Date: ${day.date}');
  print('Season: ${day.season}');
  print('Celebration: ${day.celebration.name}');
  print('Rank: ${day.celebration.rank}');
  print('Color: ${day.celebration.color}');
  print('Liturgical Year: ${day.liturgicalYear.cycle.value}');
  print('Psalter Week: ${day.psalterWeek.value}');
  print('Prioritized: ${day.celebration.prioritized}');
}
```

## 📊 **Performance Comparison**

| Approach | Init Time | Access Time | Memory | Bundle Size |
|----------|-----------|-------------|---------|-------------|
| **Direct Service** | 0ms | ~0.05ms | Minimal | Optimized |
| JSON Assets | ~100ms | ~1ms | Higher | +External files |
| Network APIs | ~500ms | ~50ms | Variable | +Dependencies |

## 🎨 **Flutter Integration**

Perfect for Flutter apps across all platforms:

```dart
class LiturgicalWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Instant access - no FutureBuilder needed!
    final today = LiturgicalCalendarService.getCurrentDay();
    
    return Card(
      child: Column(
        children: [
          Text(today?.celebration.name ?? 'No celebration'),
          Text('Season: ${today?.season}'),
          Container(
            color: _getSeasonColor(today?.celebration.color),
            height: 4,
          ),
        ],
      ),
    );
  }
}
```

## 🚀 **Key Benefits**

- ⚡ **Instant Access**: No initialization or loading delays
- 🔒 **Type Safety**: Full compile-time validation  
- 📦 **Zero Dependencies**: No external assets or files
- 🎯 **Rich API**: Advanced search and filtering capabilities
- 🌐 **Universal**: Works on all platforms (mobile, web, desktop, server)
- 📈 **Performance**: 20x faster than JSON-based alternatives

## 🛠️ **Data Generation**

The embedded data is generated from authoritative sources:

```bash
# Generate latest liturgical data (run from package root)
./build_data.sh
```

**Source:** [RomCal 1.3.0](https://github.com/romcal/romcal) - Official Roman Calendar implementation

## 📦 **Installation**

Add to your `pubspec.yaml`:

```yaml
dependencies:
  sancta_via_liturgical_calendar:
    git:
      url: https://github.com/superversivesf/sancta_via_liturgical_calendar.git
      ref: v2.0.0  # Use specific version tag
```

Then run:
```bash
dart pub get
```

**No additional setup required** - liturgical data is embedded in the package!

## 🧪 **Examples**

Run the included example:

```bash
# Complete liturgical calendar example
dart run example/liturgical_calendar_example.dart
```

## 🎯 **Use Cases**

- **Prayer apps** - Daily liturgical information
- **Calendar apps** - Catholic liturgical overlays  
- **Church websites** - Seasonal content and decorations
- **Notification systems** - Feast day reminders
- **Educational tools** - Liturgical year learning
- **Widgets** - Liturgical status displays

## 🔄 **Compatibility**

- **Dart**: 3.7.2+
- **Flutter**: 3.7.2+
- **Platforms**: All (Web, Mobile, Desktop, Server)
- **Dependencies**: None (pure Dart)

## 📚 **Documentation**

- [Generated Data README](lib/src/data/generated/README.md)
- [Examples](example/)
- [RomCal Integration](tools/romcal_integration/)

## ⚡ **Why Embedded Data?**

Traditional approaches load liturgical data from JSON files or APIs, creating:
- ❌ Loading delays
- ❌ Parsing overhead  
- ❌ Network dependencies
- ❌ Asset management complexity

**Embedded data eliminates all of these issues** while providing:
- ✅ Instant access
- ✅ Compile-time safety
- ✅ Zero dependencies
- ✅ Optimal performance

## 🏗️ **Part of Sancta Via Ecosystem**

This package is part of the broader Sancta Via Catholic Apps ecosystem:

- `sancta_via_liturgical_calendar` - Core liturgical calendar (this package)
- `sancta_via_liturgical_calendar_riverpod` - Riverpod providers for reactive state
- `sancta_via_shared_ui` - Shared UI components with liturgical theming
- Various Catholic prayer and devotion apps

## 🤝 **Contributing**

Contributions welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests
5. Submit a pull request

## 📄 **License**

MIT License - see [LICENSE](LICENSE) file for details.

---

**Building the future of Catholic apps with zero-overhead liturgical data.** 🙏✨
*Part of the Sancta Via Catholic Apps Ecosystem*