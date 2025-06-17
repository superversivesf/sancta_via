import 'package:liturgical_calendar/liturgical_calendar.dart';

/// Example implementation of LiturgicalDataLoader for demonstration
class ExampleDataLoader implements LiturgicalDataLoader {
  @override
  Future<bool> hasData(String filename) async => filename == '2025.json';

  @override
  Future<String> loadIndexData() async {
    // This would normally load from assets, files, or network
    // For this example, we return minimal valid JSON
    return '''
{
  "generatedAt": "2025-06-18T00:00:00.000Z",
  "dataVersion": "1.0.0",
  "romcalVersion": "1.3.0",
  "years": [
    {
      "year": 2025,
      "totalDays": 365,
      "prioritizedCelebrations": 72,
      "file": "2025.json"
    }
  ],
  "totalYears": 1
}
''';
  }

  @override
  Future<String> loadYearData(String filename) async {
    // This would normally load the actual year data
    // For this example, we return minimal valid JSON
    return '''
{
  "metadata": {
    "year": 2025,
    "totalDays": 365,
    "seasons": {},
    "colors": {},
    "types": {},
    "prioritizedCelebrations": 72,
    "generatedAt": "2025-06-18T00:00:00.000Z",
    "dataVersion": "1.0.0",
    "romcalVersion": "1.3.0"
  },
  "calendar": {
    "2025-12-25": {
      "date": "2025-12-25",
      "season": "Christmas",
      "seasonKey": "christmas",
      "celebration": {
        "key": "christmas",
        "name": "The Nativity of the Lord",
        "type": "SOLEMNITY",
        "rank": "SOLEMNITY",
        "color": "WHITE",
        "colorName": "White",
        "source": "GENERAL",
        "prioritized": true,
        "titles": ["Christmas Day"]
      },
      "liturgicalYear": {
        "year": 2025,
        "cycle": {"key": 1, "value": "C"},
        "week": 52,
        "day": 4,
        "weekOfSeason": 1
      },
      "psalterWeek": {
        "key": 1,
        "value": "Week I"
      }
    }
  }
}
''';
  }
}

void main() async {
  print('Liturgical Calendar Library Example');
  print('===================================');

  // Initialize the service with our example data loader
  final dataLoader = ExampleDataLoader();
  await LiturgicalCalendarService.initialize(dataLoader);

  print('Service initialized successfully!');
  print('Available years: ${LiturgicalCalendarService.getAvailableYears()}');

  // Example: Get Christmas Day 2025
  final christmas = await LiturgicalCalendarService.getDayForDate(
    DateTime(2025, 12, 25),
  );

  if (christmas != null) {
    print('\nChristmas Day 2025:');
    print('  Celebration: ${christmas.celebration.name}');
    print('  Rank: ${christmas.celebration.rank}');
    print('  Color: ${christmas.celebration.color}');
    print('  Season: ${christmas.season}');
  }

  // Example: Check if service can handle current date gracefully
  final today = await LiturgicalCalendarService.getCurrentDay();
  if (today != null) {
    print('\nToday (${today.date}):');
    print('  ${today.displayName}');
  } else {
    print('\nNo data available for today\'s date.');
  }

  print('\nExample completed successfully!');
}