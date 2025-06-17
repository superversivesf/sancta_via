import 'package:liturgical_calendar/liturgical_calendar.dart';
import 'package:test/test.dart';

/// Mock data loader for testing
class MockDataLoader implements LiturgicalDataLoader {
  @override
  Future<bool> hasData(String filename) async => filename == '2025.json';

  @override
  Future<String> loadIndexData() async {
    return '''
{
  "generatedAt": "2025-06-18T00:00:00.000Z",
  "dataVersion": "1.0.0",
  "romcalVersion": "1.3.0",
  "years": [
    {
      "year": 2025,
      "totalDays": 365,
      "prioritizedCelebrations": 1,
      "file": "2025.json"
    }
  ],
  "totalYears": 1
}
''';
  }

  @override
  Future<String> loadYearData(String filename) async {
    if (filename == '2025.json') {
      return '''
{
  "metadata": {
    "year": 2025,
    "totalDays": 365,
    "seasons": {"Christmas": 12},
    "colors": {"WHITE": 12},
    "types": {"SOLEMNITY": 1},
    "prioritizedCelebrations": 1,
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
    throw Exception('File not found: $filename');
  }
}

void main() {
  group('LiturgicalCalendarService', () {
    late MockDataLoader mockDataLoader;

    setUp(() {
      mockDataLoader = MockDataLoader();
      LiturgicalCalendarService.reset(); // Reset service state
    });

    tearDown(() {
      LiturgicalCalendarService.reset();
    });

    test('should initialize successfully', () async {
      await LiturgicalCalendarService.initialize(mockDataLoader);
      
      expect(LiturgicalCalendarService.isInitialized, isTrue);
      expect(LiturgicalCalendarService.getAvailableYears(), contains(2025));
    });

    test('should handle uninitialized state gracefully', () async {
      // Service not initialized
      final day = await LiturgicalCalendarService.getDayForDate(DateTime(2025, 12, 25));
      expect(day, isNull);
      
      expect(LiturgicalCalendarService.getAvailableYears(), isEmpty);
      expect(LiturgicalCalendarService.isYearAvailable(2025), isFalse);
    });

    test('should load and return liturgical day data', () async {
      await LiturgicalCalendarService.initialize(mockDataLoader);
      
      final christmas = await LiturgicalCalendarService.getDayForDate(DateTime(2025, 12, 25));
      
      expect(christmas, isNotNull);
      expect(christmas!.celebration.name, equals('The Nativity of the Lord'));
      expect(christmas.celebration.rank, equals('SOLEMNITY'));
      expect(christmas.celebration.color, equals('WHITE'));
      expect(christmas.season, equals('Christmas'));
    });

    test('should return null for unavailable dates', () async {
      await LiturgicalCalendarService.initialize(mockDataLoader);
      
      final unavailableDay = await LiturgicalCalendarService.getDayForDate(DateTime(2026, 1, 1));
      expect(unavailableDay, isNull);
    });

    test('should check year availability correctly', () async {
      await LiturgicalCalendarService.initialize(mockDataLoader);
      
      expect(LiturgicalCalendarService.isYearAvailable(2025), isTrue);
      expect(LiturgicalCalendarService.isYearAvailable(2026), isFalse);
    });

    test('should handle cache correctly', () async {
      await LiturgicalCalendarService.initialize(mockDataLoader);
      
      // Load year data
      await LiturgicalCalendarService.loadYear(2025);
      
      // Clear cache
      LiturgicalCalendarService.clearCache();
      
      // Should still work (reload data)
      final christmas = await LiturgicalCalendarService.getDayForDate(DateTime(2025, 12, 25));
      expect(christmas, isNotNull);
    });
  });

  group('LiturgicalDayData', () {
    test('should parse date correctly', () {
      final dayData = LiturgicalDayData(
        date: '2025-12-25',
        season: 'Christmas',
        seasonKey: 'christmas',
        celebration: const LiturgicalCelebration(
          key: 'christmas',
          name: 'Christmas',
          type: 'SOLEMNITY',
          rank: 'SOLEMNITY',
          color: 'WHITE',
          colorName: 'White',
          source: 'GENERAL',
          prioritized: true,
          titles: [],
        ),
        liturgicalYear: const LiturgicalYearInfo(
          year: 2025,
          cycle: LiturgicalCycle(key: 1, value: 'C'),
          week: 52,
          day: 4,
          weekOfSeason: 1,
        ),
        psalterWeek: const PsalterWeek(key: 1, value: 'Week I'),
      );

      expect(dayData.dateTime, equals(DateTime(2025, 12, 25)));
      expect(dayData.isSolemnity, isTrue);
      expect(dayData.hasPrioritizedCelebration, isTrue);
      expect(dayData.displayName, equals('Christmas'));
    });
  });

  group('Enums', () {
    test('LiturgicalSeason should convert from string', () {
      expect(LiturgicalSeason.fromString('advent'), equals(LiturgicalSeason.advent));
      expect(LiturgicalSeason.fromString('christmas'), equals(LiturgicalSeason.christmas));
      expect(LiturgicalSeason.fromString('ordinary time'), equals(LiturgicalSeason.ordinaryTime));
      expect(LiturgicalSeason.fromString('invalid'), isNull);
    });

    test('LiturgicalColor should convert from string', () {
      expect(LiturgicalColor.fromString('WHITE'), equals(LiturgicalColor.white));
      expect(LiturgicalColor.fromString('red'), equals(LiturgicalColor.red));
      expect(LiturgicalColor.fromString('PURPLE'), equals(LiturgicalColor.purple));
      expect(LiturgicalColor.fromString('invalid'), isNull);
    });

    test('CelebrationRank should convert from string', () {
      expect(CelebrationRank.fromString('SOLEMNITY'), equals(CelebrationRank.solemnity));
      expect(CelebrationRank.fromString('FEAST'), equals(CelebrationRank.feast));
      expect(CelebrationRank.fromString('OPT_MEMORIAL'), equals(CelebrationRank.optionalMemorial));
      expect(CelebrationRank.fromString('invalid'), equals(CelebrationRank.weekday));
    });
  });
}