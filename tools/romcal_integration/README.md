# RomCal Integration for Liturgical Calendar Generation

This directory contains tools for generating liturgical calendar data using the [RomCal](https://github.com/romcal/romcal) library.

## Overview

The RomCal integration generates comprehensive liturgical calendar data in JSON format for use with the `liturgical_calendar` package. It creates structured data files containing daily liturgical information including:

- Liturgical seasons and their progression
- Feast days, solemnities, and memorials
- Liturgical colors for each day
- Psalter week calculations
- Liturgical year cycles (A, B, C)

## Setup

### 1. Install Dependencies

```bash
cd tools/romcal_integration
npm install
```

### 2. Test RomCal Installation

Before generating data, test that RomCal is working correctly:

```bash
npm run test
```

This will:
- Verify RomCal can generate calendar data
- Show sample liturgical days
- Test access to major feasts
- Analyze the data structure

## Generating Calendar Data

### Quick Start - Generate 10 Years

Generate liturgical calendar data for 10 years (2024-2035):

```bash
npm run generate
```

### Generate Custom Date Range

```bash
# Generate specific range
node generate-calendar.js --start=2024 --end=2035

# Generate 10 years from current year
node generate-calendar.js --years=10

# Generate 5 years from current year
node generate-calendar.js --years=5
```

### Available Scripts

| Script | Description |
|--------|-------------|
| `npm run test` | Test RomCal installation and functionality |
| `npm run generate` | Generate default range (2024-2035) |
| `npm run generate-10-years` | Generate 10 years from current year |
| `npm run generate-range` | Generate specific range (2024-2035) |
| `npm run clean` | Remove existing JSON files |
| `npm run install-and-generate` | Install dependencies and generate |

## Output

The generator creates the following files:

### JSON Data Files
- `../../legacy/assets/liturgical/2024.json` - Liturgical data for 2024
- `../../legacy/assets/liturgical/2025.json` - Liturgical data for 2025
- `...` (one file per year)
- `../../legacy/assets/liturgical/index.json` - Master index with metadata

### Integration Templates
- `../../packages/liturgical_calendar/lib/src/data/asset_data_loader_template.dart` - Template for Flutter integration

## File Structure

Each year file contains:

```json
{
  "metadata": {
    "year": 2025,
    "totalDays": 365,
    "seasons": {"Advent": 28, "Christmas": 12, ...},
    "colors": {"GREEN": 180, "PURPLE": 46, ...},
    "types": {"WEEKDAY": 200, "SOLEMNITY": 15, ...},
    "prioritizedCelebrations": 72,
    "generatedAt": "2025-06-18T...",
    "dataVersion": "1.0.0",
    "romcalVersion": "1.3.0"
  },
  "calendar": {
    "2025-01-01": {
      "date": "2025-01-01",
      "season": "Christmas",
      "seasonKey": "christmas",
      "celebration": {
        "key": "mary_mother_of_god",
        "name": "Solemnity of Mary, Mother of God",
        "type": "SOLEMNITY",
        "rank": "SOLEMNITY",
        "color": "WHITE",
        "colorName": "White",
        "source": "GENERAL",
        "prioritized": true,
        "titles": []
      },
      "liturgicalYear": {
        "year": 2025,
        "cycle": {"key": 1, "value": "C"},
        "week": 1,
        "day": 3,
        "weekOfSeason": 1
      },
      "psalterWeek": {
        "key": 1,
        "value": "Week I"
      }
    }
  }
}
```

## Integration with Flutter Apps

### 1. Copy JSON Files

Copy the generated JSON files to your Flutter app:

```bash
# Copy to your Flutter app's assets folder
cp ../../legacy/assets/liturgical/*.json /path/to/your/flutter/app/assets/liturgical/
```

### 2. Update pubspec.yaml

Add the assets to your Flutter app's `pubspec.yaml`:

```yaml
flutter:
  assets:
    - assets/liturgical/
```

### 3. Create Data Loader

Use the generated template to create your data loader:

```dart
import 'package:liturgical_calendar/liturgical_calendar.dart';
// Copy the template code from asset_data_loader_template.dart
```

### 4. Initialize the Service

```dart
final dataLoader = AssetLiturgicalDataLoader();
await LiturgicalCalendarService.initialize(dataLoader);

// Now you can use the service
final today = await LiturgicalCalendarService.getCurrentDay();
print('Today: ${today?.celebration.name}');
```

## Data Size and Performance

- **File size**: ~500KB per year (JSON)
- **Total for 10 years**: ~5-6MB
- **Performance**: Fast lookup by date key
- **Caching**: Built-in year-level caching in the service

## Customization

### Modify Date Range

Edit the script or use command line arguments:

```javascript
// In generate-calendar.js
const START_YEAR = 2020; // Your start year
const END_YEAR = 2030;   // Your end year
```

### Add Custom Countries

RomCal supports different countries. Modify the script:

```javascript
const calendar = Romcal.calendarFor({
    year: year,
    country: 'unitedStates', // or 'general', 'england', etc.
    locale: 'en'
});
```

### Custom Data Processing

Modify the `processCalendarData` function to adjust the output format or add custom fields.

## Troubleshooting

### Common Issues

1. **Module not found: 'romcal'**
   ```bash
   npm install
   ```

2. **Permission denied**
   ```bash
   chmod +x generate-calendar.js
   ```

3. **Output directory not found**
   - The script automatically creates directories
   - Check file paths in the script

4. **Invalid date format**
   - Ensure RomCal version 1.3.0 is installed
   - Check Node.js version compatibility

### Verification

After generation, verify the data:

```bash
# Check file sizes
ls -lh ../../legacy/assets/liturgical/

# Validate JSON structure
node -e "console.log(Object.keys(require('../../legacy/assets/liturgical/2025.json')))"

# Test with the liturgical_calendar package
cd ../../packages/liturgical_calendar
dart run example/liturgical_calendar_example.dart
```

## Version Information

- **RomCal**: 1.3.0
- **Node.js**: Compatible with 14+
- **Data format**: JSON
- **Dart compatibility**: 3.7.2+