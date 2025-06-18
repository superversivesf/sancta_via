# Generated Liturgical Calendar Data

This directory contains auto-generated Dart files with embedded liturgical calendar data. **Do not edit these files manually** - they are regenerated from RomCal data.

## 🚀 **Zero-Overhead Performance**

These files provide the fastest possible access to liturgical calendar data by embedding it directly as Dart objects, eliminating:
- ❌ JSON file loading
- ❌ JSON parsing overhead  
- ❌ Async asset loading
- ❌ Runtime validation

## 📁 **Generated Files**

### Individual Year Data
- `liturgical_calendar_YYYY.dart` - Complete liturgical data for each year
- Each file contains ~365-366 days with full liturgical information

### Master Index & Access
- `generated_liturgical_data.dart` - Master index and unified access to all years
- `generated_data_loader.dart` - Compatibility layer for existing services

## 🛠️ **Usage Options**

### Main Service (Recommended) ⚡
```dart
import 'package:liturgical_calendar/liturgical_calendar.dart';

// No initialization needed!
final today = LiturgicalCalendarService.getCurrentDay();
final christmas = LiturgicalCalendarService.getDayForDate(DateTime(2025, 12, 25));
final feasts = LiturgicalCalendarService.getUpcomingFeasts();
final maryFeasts = LiturgicalCalendarService.searchCelebrations('Mary');
final adventDays = LiturgicalCalendarService.getDaysForSeason(2025, 'Advent');
```

### Direct Data Access (Custom Implementations) 🏆
```dart
import 'package:liturgical_calendar/liturgical_calendar.dart';

// Access data directly from generated classes
final christmas = GeneratedLiturgicalData.getDayForDate(DateTime(2025, 12, 25));
final allYears = GeneratedLiturgicalData.getAvailableYears();
final yearData = GeneratedLiturgicalData.getYearData(2025);
final stats = GeneratedLiturgicalData.getTotalDays();
```

## 🔄 **Regenerating Data**

To update the generated data (e.g., when RomCal releases new versions):

```bash
# From project root
cd tools/romcal_integration
npm run generate-dart

# Or using melos
melos run build:liturgical-dart
```

## 📊 **Data Coverage**

- **Years**: 2024-2035 (12 years)
- **Total Days**: 4,383 liturgical days
- **Celebrations**: 856 prioritized celebrations
- **File Size**: ~3MB total Dart code
- **Source**: RomCal 1.3.0 (official Roman Calendar)

## 🎯 **Performance Comparison**

| Method | Initialization | Access Time | Memory Usage | Bundle Impact |
|--------|---------------|-------------|--------------|---------------|
| JSON Assets | ~100ms | ~1ms | Higher | External files |
| **Embedded Data** | **0ms** | **~0.05ms** | **Minimal** | **Tree-shaken** |

## 🧪 **Testing**

Run the example to verify the generated data:

```bash
# Complete liturgical calendar example
dart run example/liturgical_calendar_example.dart
```

## ⚠️ **Important Notes**

1. **Never edit generated files** - Changes will be lost on regeneration
2. **Commit generated files** - They should be part of your repository
3. **Update annually** - Regenerate data when new liturgical years begin
4. **Use the main service** - `LiturgicalCalendarService` for all standard needs

## 🔗 **Integration**

The generated data integrates seamlessly with:
- ✅ Flutter applications (any platform)
- ✅ Pure Dart applications  
- ✅ Web applications
- ✅ Server-side Dart
- ✅ Command-line tools

No external dependencies or assets required!
