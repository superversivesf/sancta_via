#!/usr/bin/env dart

import 'dart:io';
import 'package:sancta_via_liturgical_calendar/sancta_via_liturgical_calendar.dart';

/// Validation script for generated liturgical data
/// 
/// This script performs comprehensive validation of the embedded data
/// to ensure everything is working correctly after generation.
void main() async {
  print('🔍 Liturgical Calendar Data Validation');
  print('======================================');
  
  var passed = 0;
  var total = 0;
  
  void test(String description, bool Function() testFunc) {
    total++;
    try {
      final result = testFunc();
      if (result) {
        print('✅ $description');
        passed++;
      } else {
        print('❌ $description');
      }
    } catch (e) {
      print('❌ $description - Error: $e');
    }
  }

  void testAsync(String description, Future<bool> Function() testFunc) async {
    total++;
    try {
      final result = await testFunc();
      if (result) {
        print('✅ $description');
        passed++;
      } else {
        print('❌ $description');
      }
    } catch (e) {
      print('❌ $description - Error: $e');
    }
  }

  print('\n📊 Testing Generated Data Availability...');
  
  test('Available years count', () {
    final years = GeneratedLiturgicalData.getAvailableYears();
    return years.length == 12;
  });
  
  test('Year range correct', () {
    final range = GeneratedLiturgicalData.yearRange;
    return range.start == 2024 && range.end == 2035;
  });
  
  test('Year 2025 data exists', () {
    final data = GeneratedLiturgicalData.getYearData(2025);
    return data != null && data.isNotEmpty;
  });

  print('\n🎄 Testing Specific Liturgical Days...');
  
  test('Christmas Day 2025', () {
    final christmas = GeneratedLiturgicalData.getDayForDate(DateTime(2025, 12, 25));
    return christmas != null && 
           christmas.celebration.name.toLowerCase().contains('christmas') &&
           christmas.celebration.rank == 'SOLEMNITY';
  });
  
  test('New Year 2025 (Mary, Mother of God)', () {
    final newYear = GeneratedLiturgicalData.getDayForDate(DateTime(2025, 1, 1));
    return newYear != null && 
           newYear.celebration.name.toLowerCase().contains('mary') &&
           newYear.celebration.prioritized;
  });

  print('\n⚡ Testing LiturgicalCalendarService...');
  
  test('Service is initialized', () {
    return LiturgicalCalendarService.isInitialized;
  });
  
  test('Current day access (if in range)', () {
    final today = LiturgicalCalendarService.getCurrentDay();
    final now = DateTime.now();
    
    if (now.year >= 2024 && now.year <= 2035) {
      return today != null;
    } else {
      return today == null; // Expected for dates outside range
    }
  });
  
  test('Days in range query', () {
    final days = LiturgicalCalendarService.getDaysInRange(
      DateTime(2025, 12, 20),
      DateTime(2025, 12, 30),
    );
    return days.length == 11;
  });
  
  test('Search celebrations', () {
    final results = LiturgicalCalendarService.searchCelebrations('Mary', year: 2025);
    return results.isNotEmpty;
  });
  
  test('Get season days', () {
    final adventDays = LiturgicalCalendarService.getDaysForSeason(2025, 'Advent');
    return adventDays.isNotEmpty;
  });

  test('Get available years', () {
    final years = LiturgicalCalendarService.getAvailableYears();
    return years.length == 12 && years.contains(2025);
  });

  test('Global statistics', () {
    final stats = LiturgicalCalendarService.getGlobalStatistics();
    return stats['totalYears'] == 12 && stats['totalDays'] == 4383;
  });

  print('\n📈 Testing Performance...');
  
  test('Rapid data access', () {
    final stopwatch = Stopwatch()..start();
    
    // Test 1000 rapid accesses
    for (int i = 0; i < 1000; i++) {
      LiturgicalCalendarService.getDayForDate(DateTime(2025, 12, 25));
    }
    
    stopwatch.stop();
    final avgMicroseconds = stopwatch.elapsedMicroseconds / 1000;
    
    print('   📊 1000 accesses in ${stopwatch.elapsedMilliseconds}ms');
    print('   ⚡ Average: ${avgMicroseconds.toStringAsFixed(1)}μs per access');
    
    // Should be very fast (under 1ms average)
    return avgMicroseconds < 1000;
  });

  print('\n📊 Testing Data Integrity...');
  
  test('All years have data', () {
    final years = GeneratedLiturgicalData.getAvailableYears();
    return years.every((year) {
      final data = GeneratedLiturgicalData.getYearData(year);
      return data != null && data.isNotEmpty;
    });
  });
  
  test('Total statistics match', () {
    final totalDays = GeneratedLiturgicalData.getTotalDays();
    final totalCelebrations = GeneratedLiturgicalData.getTotalPrioritizedCelebrations();
    
    // Expected values based on generation
    return totalDays == 4383 && totalCelebrations == 856;
  });
  
  test('Date continuity check', () {
    // Check that dates are continuous within years
    final year2025Data = GeneratedLiturgicalData.getYearData(2025)!;
    final dates = year2025Data.keys.toList()..sort();
    
    // Should have 365 days for 2025 (not a leap year)
    return dates.length == 365 && 
           dates.first == '2025-01-01' && 
           dates.last == '2025-12-31';
  });

  print('\n📁 Testing File Structure...');
  
  test('Generated files exist', () {
    final generatedDir = Directory('lib/src/data/generated');
    if (!generatedDir.existsSync()) return false;
    
    final files = generatedDir.listSync().map((f) => f.path).toList();
    final expectedFiles = [
      'generated_liturgical_data.dart',
      'generated_data_loader.dart',
    ];
    
    // Check for year files
    for (int year = 2024; year <= 2035; year++) {
      expectedFiles.add('liturgical_calendar_$year.dart');
    }
    
    return expectedFiles.every((expectedFile) {
      return files.any((actualFile) => actualFile.endsWith(expectedFile));
    });
  });

  print('\n${'=' * 50}');
  print('📊 VALIDATION RESULTS');
  print('=' * 50);
  
  if (passed == total) {
    print('🎉 ALL TESTS PASSED! ($passed/$total)');
    print('✅ Generated liturgical data is working perfectly!');
    print('');
    print('🚀 Performance Benefits:');
    print('   ⚡ Zero initialization time');
    print('   🔥 Ultra-fast data access');
    print('   📦 No external dependencies');
    print('   🔒 Compile-time type safety');
    print('');
    print('💡 Ready for production use!');
    exit(0);
  } else {
    print('⚠️  SOME TESTS FAILED ($passed/$total passed)');
    print('❌ Please check the generated data and try regenerating:');
    print('   cd ../../tools/romcal_integration');
    print('   npm run generate-dart');
    exit(1);
  }
}
