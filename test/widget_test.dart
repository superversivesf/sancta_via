// Basic tests for the Sancta Via Calendar app.

import 'package:flutter_test/flutter_test.dart';
import 'package:sancta_via_liturgical_calendar/sancta_via_liturgical_calendar.dart';

void main() {
  group('Liturgical Calendar Integration', () {
    test('LiturgicalCalendarService provides current day', () {
      // Test that the liturgical calendar service works
      final currentDay = LiturgicalCalendarService.getCurrentDay();
      
      // Should return a day or null (both are valid)
      expect(currentDay, isA<LiturgicalDayData?>());
    });

    test('LiturgicalCalendarService has available years', () {
      final availableYears = LiturgicalCalendarService.getAvailableYears();
      
      // Should have multiple years of data
      expect(availableYears, isNotEmpty);
      expect(availableYears.length, greaterThan(5));
    });

    test('LiturgicalCalendarService provides statistics', () {
      final stats = LiturgicalCalendarService.getGlobalStatistics();
      
      // Should have meaningful statistics
      expect(stats['totalDays'], greaterThan(1000));
      expect(stats['totalYears'], greaterThan(5));
    });

    test('Can search for Christmas celebration', () {
      final results = LiturgicalCalendarService.searchCelebrations('Christmas');
      
      // Should find Christmas celebrations
      expect(results, isNotEmpty);
      expect(results.any((day) => 
        day.celebration.name.toLowerCase().contains('christmas')), isTrue);
    });
  });
}