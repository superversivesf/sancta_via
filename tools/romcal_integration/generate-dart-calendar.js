#!/usr/bin/env node

/**
 * Dart Liturgical Calendar Generator for Sancta Via
 * 
 * Generates liturgical calendar data using RomCal and converts it to 
 * native Dart code with embedded data objects for zero-overhead access.
 * 
 * Usage:
 *   node generate-dart-calendar.js                    # Generate default range (2024-2035)
 *   node generate-dart-calendar.js --years=10         # Generate 10 years from current year
 *   node generate-dart-calendar.js --start=2024 --end=2035  # Generate specific range
 */

const fs = require('fs');
const path = require('path');
const Romcal = require('romcal').default;

// Parse command line arguments
const args = process.argv.slice(2);
let START_YEAR = 2024;
let END_YEAR = 2035;

args.forEach(arg => {
    if (arg.startsWith('--years=')) {
        const years = parseInt(arg.split('=')[1]);
        const currentYear = new Date().getFullYear();
        START_YEAR = currentYear;
        END_YEAR = currentYear + years - 1;
    } else if (arg.startsWith('--start=')) {
        START_YEAR = parseInt(arg.split('=')[1]);
    } else if (arg.startsWith('--end=')) {
        END_YEAR = parseInt(arg.split('=')[1]);
    }
});

// Output directory
const DART_OUTPUT_DIR = '../../packages/liturgical_calendar/lib/src/data/generated';

// Ensure output directory exists
const dartOutputPath = path.resolve(__dirname, DART_OUTPUT_DIR);
if (!fs.existsSync(dartOutputPath)) {
    fs.mkdirSync(dartOutputPath, { recursive: true });
    console.log(`Created output directory: ${dartOutputPath}`);
}

/**
 * Format a date for our Dart structure
 */
function formatDate(date) {
    if (typeof date === 'string') {
        return date.split('T')[0]; // Extract YYYY-MM-DD from ISO string
    } else if (date && date.format) {
        // Handle Moment.js object
        return date.format('YYYY-MM-DD');
    } else if (date instanceof Date) {
        // Handle regular Date object
        return date.toISOString().split('T')[0];
    } else {
        throw new Error(`Unknown date format: ${typeof date}`);
    }
}

/**
 * Escape and format a string for Dart code
 */
function escapeDartString(str) {
    if (!str || typeof str !== 'string') return '\'\'';
    return '\'' + str.replace(/\\/g, '\\\\').replace(/'/g, '\\\'').replace(/\n/g, '\\n') + '\'';
}

/**
 * Format a list of strings for Dart code
 */
function formatDartStringList(list) {
    if (!Array.isArray(list) || list.length === 0) {
        return 'const <String>[]';
    }
    const items = list.map(item => escapeDartString(item)).join(', ');
    return `const <String>[${items}]`;
}

/**
 * Process RomCal calendar data into our preferred structure
 */
function processCalendarData(calendarData, year) {
    const processedData = {};
    const statistics = {
        totalDays: 0,
        seasons: {},
        colors: {},
        types: {},
        prioritizedCelebrations: 0
    };
    
    // Handle both Map and Array formats from RomCal
    const dataArray = calendarData instanceof Map ? Array.from(calendarData.values()) : calendarData;
    
    dataArray.forEach(day => {
        try {
            // Extract date - handle different RomCal formats
            let dateKey;
            if (day.moment) {
                dateKey = formatDate(day.moment);
            } else if (day.date) {
                dateKey = formatDate(day.date);
            } else {
                console.warn('Day object missing date information:', day);
                return;
            }
            
            // Build the day data structure
            const dayData = {
                date: dateKey,
                season: day.data?.season?.value || day.season || 'Ordinary Time',
                seasonKey: day.data?.season?.key || day.seasonKey || 'ordinary_time',
                
                celebration: {
                    key: day.key || day.name?.toLowerCase().replace(/\s+/g, '_') || 'weekday',
                    name: day.name || 'Weekday',
                    type: day.type || 'WEEKDAY',
                    rank: day.rank || day.type || 'WEEKDAY',
                    color: day.data?.meta?.liturgicalColor?.key || day.color || 'GREEN',
                    colorName: day.data?.meta?.liturgicalColor?.value || day.colorName || 'Green',
                    source: day.source || 'GENERAL',
                    prioritized: Boolean(day.data?.prioritized || day.prioritized || false),
                    titles: day.data?.meta?.titles || day.titles || [],
                },
                
                liturgicalYear: {
                    year: year,
                    cycle: day.data?.meta?.cycle || day.cycle || { key: 1, value: 'A' },
                    week: day.data?.calendar?.week || day.week || 1,
                    day: day.data?.calendar?.day || day.dayOfWeek || 1,
                    weekOfSeason: day.data?.calendar?.weekOfSeason || day.weekOfSeason || 1
                },
                
                psalterWeek: day.data?.meta?.psalterWeek || day.psalterWeek || { key: 1, value: 'Week I' }
            };
            
            // Normalize cycle structure
            if (typeof dayData.liturgicalYear.cycle === 'string') {
                dayData.liturgicalYear.cycle = {
                    key: dayData.liturgicalYear.cycle === 'A' ? 1 : dayData.liturgicalYear.cycle === 'B' ? 2 : 3,
                    value: dayData.liturgicalYear.cycle
                };
            }
            
            // Normalize psalter week structure
            if (typeof dayData.psalterWeek === 'string' || typeof dayData.psalterWeek === 'number') {
                dayData.psalterWeek = {
                    key: typeof dayData.psalterWeek === 'number' ? dayData.psalterWeek : 1,
                    value: `Week ${dayData.psalterWeek}`
                };
            }
            
            processedData[dateKey] = dayData;
            
            // Update statistics
            statistics.totalDays++;
            statistics.seasons[dayData.season] = (statistics.seasons[dayData.season] || 0) + 1;
            statistics.colors[dayData.celebration.color] = (statistics.colors[dayData.celebration.color] || 0) + 1;
            statistics.types[dayData.celebration.type] = (statistics.types[dayData.celebration.type] || 0) + 1;
            if (dayData.celebration.prioritized) {
                statistics.prioritizedCelebrations++;
            }
            
        } catch (error) {
            console.warn(`Error processing day data:`, error.message, day);
        }
    });
    
    return { processedData, statistics };
}

/**
 * Generate Dart code for liturgical celebration object
 */
function generateCelebrationDart(celebration) {
    return `LiturgicalCelebration(
      key: ${escapeDartString(celebration.key)},
      name: ${escapeDartString(celebration.name)},
      type: ${escapeDartString(celebration.type)},
      rank: ${escapeDartString(celebration.rank)},
      color: ${escapeDartString(celebration.color)},
      colorName: ${escapeDartString(celebration.colorName)},
      source: ${escapeDartString(celebration.source)},
      prioritized: ${celebration.prioritized},
      titles: ${formatDartStringList(celebration.titles)},
    )`;
}

/**
 * Generate Dart code for liturgical cycle object
 */
function generateCycleDart(cycle) {
    return `LiturgicalCycle(
      key: ${cycle.key},
      value: ${escapeDartString(cycle.value)},
    )`;
}

/**
 * Generate Dart code for psalter week object
 */
function generatePsalterWeekDart(psalterWeek) {
    return `PsalterWeek(
      key: ${psalterWeek.key},
      value: ${escapeDartString(psalterWeek.value)},
    )`;
}

/**
 * Generate Dart code for liturgical year info object
 */
function generateLiturgicalYearDart(liturgicalYear) {
    return `LiturgicalYearInfo(
      year: ${liturgicalYear.year},
      cycle: ${generateCycleDart(liturgicalYear.cycle)},
      week: ${liturgicalYear.week},
      day: ${liturgicalYear.day},
      weekOfSeason: ${liturgicalYear.weekOfSeason},
    )`;
}

/**
 * Generate Dart code for a single liturgical day
 */
function generateDayDataDart(dayData) {
    return `    ${escapeDartString(dayData.date)}: LiturgicalDayData(
      date: ${escapeDartString(dayData.date)},
      season: ${escapeDartString(dayData.season)},
      seasonKey: ${escapeDartString(dayData.seasonKey)},
      celebration: ${generateCelebrationDart(dayData.celebration)},
      liturgicalYear: ${generateLiturgicalYearDart(dayData.liturgicalYear)},
      psalterWeek: ${generatePsalterWeekDart(dayData.psalterWeek)},
    )`;
}

/**
 * Generate calendar for a specific year and create Dart file
 */
async function generateYearDartCalendar(year) {
    console.log(`Generating Dart liturgical calendar for ${year}...`);
    
    try {
        // Generate the liturgical calendar for the year
        const calendar = Romcal.calendarFor({
            year: year,
            country: 'general', // Use general Roman calendar
            locale: 'en'
        });
        
        // Process the calendar data
        const { processedData, statistics } = processCalendarData(calendar, year);
        
        // Create summary metadata
        const metadata = {
            year: year,
            totalDays: statistics.totalDays,
            seasons: statistics.seasons,
            colors: statistics.colors,
            types: statistics.types,
            prioritizedCelebrations: statistics.prioritizedCelebrations,
            generatedAt: new Date().toISOString(),
            dataVersion: '1.0.0',
            romcalVersion: '1.3.0'
        };
        
        // Generate the Dart file content
        const dartContent = `// Generated liturgical calendar data for ${year}
// DO NOT EDIT - This file is auto-generated by generate-dart-calendar.js
// Generated at: ${metadata.generatedAt}
// Data version: ${metadata.dataVersion}
// RomCal version: ${metadata.romcalVersion}

import '../../../liturgical_calendar.dart';

/// Liturgical calendar data for the year ${year}
/// 
/// Contains ${metadata.totalDays} days with ${metadata.prioritizedCelebrations} prioritized celebrations.
/// Seasons: ${Object.keys(metadata.seasons).join(', ')}
/// 
/// This data is generated from RomCal ${metadata.romcalVersion} and represents
/// the official Roman Catholic liturgical calendar.
class LiturgicalCalendarData${year} {
  /// Year information
  static const int year = ${year};
  static const int totalDays = ${metadata.totalDays};
  static const int prioritizedCelebrations = ${metadata.prioritizedCelebrations};
  static const String generatedAt = ${escapeDartString(metadata.generatedAt)};
  static const String dataVersion = ${escapeDartString(metadata.dataVersion)};
  static const String romcalVersion = ${escapeDartString(metadata.romcalVersion)};

  /// Calendar data for ${year} - maps date strings to liturgical day data
  static const Map<String, LiturgicalDayData> calendar = {
${Object.entries(processedData).map(([date, dayData]) => generateDayDataDart(dayData)).join(',\n')}
  };

  /// Get liturgical day for a specific date
  static LiturgicalDayData? getDayForDate(DateTime date) {
    final dateKey = '\${date.year.toString().padLeft(4, '0')}-'
        '\${date.month.toString().padLeft(2, '0')}-'
        '\${date.day.toString().padLeft(2, '0')}';
    return calendar[dateKey];
  }

  /// Get all days in this calendar year
  static List<LiturgicalDayData> getAllDays() {
    return calendar.values.toList();
  }

  /// Get prioritized celebrations (feasts, solemnities, etc.)
  static List<LiturgicalDayData> getPrioritizedDays() {
    return calendar.values.where((day) => day.celebration.prioritized).toList();
  }
}
`;

        // Write the Dart file
        const dartFileName = `liturgical_calendar_${year}.dart`;
        const dartFilePath = path.join(dartOutputPath, dartFileName);
        fs.writeFileSync(dartFilePath, dartContent);
        
        console.log(`✅ Generated ${dartFileName} - ${metadata.totalDays} days, ${metadata.prioritizedCelebrations} prioritized celebrations`);
        console.log(`   Seasons: ${Object.keys(metadata.seasons).join(', ')}`);
        console.log(`   Colors: ${Object.keys(metadata.colors).join(', ')}`);
        console.log(`   Types: ${Object.keys(metadata.types).join(', ')}`);
        
        return metadata;
        
    } catch (error) {
        console.error(`❌ Error generating Dart calendar for ${year}:`, error);
        throw error;
    }
}

/**
 * Generate master index Dart file with all years
 */
function generateMasterDartIndex(yearSummaries) {
    const dartContent = `// Generated liturgical calendar master index
// DO NOT EDIT - This file is auto-generated by generate-dart-calendar.js
// Generated at: ${new Date().toISOString()}

import '../../../liturgical_calendar.dart';
${yearSummaries.map(summary => `import 'liturgical_calendar_${summary.year}.dart';`).join('\n')}

/// Master index for all generated liturgical calendar data
/// 
/// Provides access to ${yearSummaries.length} years of liturgical data (${START_YEAR}-${END_YEAR})
/// covering ${yearSummaries.reduce((sum, s) => sum + s.totalDays, 0)} total days.
class GeneratedLiturgicalData {
  /// Available years in the generated data
  static const List<int> availableYears = [
    ${yearSummaries.map(s => s.year).join(',\n    ')}
  ];

  /// Year range of available data
  static const yearRange = (start: ${START_YEAR}, end: ${END_YEAR});

  /// Index of all available years with metadata
  static const LiturgicalIndex index = LiturgicalIndex(
    generatedAt: ${escapeDartString(new Date().toISOString())},
    dataVersion: '1.0.0',
    romcalVersion: '1.3.0',
    years: [
${yearSummaries.map(summary => `      YearInfo(
        year: ${summary.year},
        totalDays: ${summary.totalDays},
        prioritizedCelebrations: ${summary.prioritizedCelebrations},
        file: 'liturgical_calendar_${summary.year}.dart',
      )`).join(',\n')}
    ],
    totalYears: ${yearSummaries.length},
  );

  /// Get calendar data for a specific year
  static Map<String, LiturgicalDayData>? getYearData(int year) {
    switch (year) {
${yearSummaries.map(summary => `      case ${summary.year}:
        return LiturgicalCalendarData${summary.year}.calendar;`).join('\n')}
      default:
        return null;
    }
  }

  /// Get metadata for a specific year
  static Map<String, dynamic>? getYearMetadata(int year) {
    switch (year) {
${yearSummaries.map(summary => `      case ${summary.year}:
        return {
          'year': LiturgicalCalendarData${summary.year}.year,
          'totalDays': LiturgicalCalendarData${summary.year}.totalDays,
          'prioritizedCelebrations': LiturgicalCalendarData${summary.year}.prioritizedCelebrations,
          'generatedAt': LiturgicalCalendarData${summary.year}.generatedAt,
          'dataVersion': LiturgicalCalendarData${summary.year}.dataVersion,
          'romcalVersion': LiturgicalCalendarData${summary.year}.romcalVersion,
        };`).join('\n')}
      default:
        return null;
    }
  }

  /// Get liturgical day for any date in the available range
  static LiturgicalDayData? getDayForDate(DateTime date) {
    final year = date.year;
    if (!availableYears.contains(year)) {
      return null;
    }

    switch (year) {
${yearSummaries.map(summary => `      case ${summary.year}:
        return LiturgicalCalendarData${summary.year}.getDayForDate(date);`).join('\n')}
      default:
        return null;
    }
  }

  /// Check if a year is available in the generated data
  static bool isYearAvailable(int year) {
    return availableYears.contains(year);
  }

  /// Get all available years as a list
  static List<int> getAvailableYears() {
    return List.from(availableYears);
  }

  /// Get total number of days across all years
  static int getTotalDays() {
    return ${yearSummaries.reduce((sum, s) => sum + s.totalDays, 0)};
  }

  /// Get total number of prioritized celebrations across all years
  static int getTotalPrioritizedCelebrations() {
    return ${yearSummaries.reduce((sum, s) => sum + s.prioritizedCelebrations, 0)};
  }
}
`;

    const indexFilePath = path.join(dartOutputPath, 'generated_liturgical_data.dart');
    fs.writeFileSync(indexFilePath, dartContent);
    console.log(`📋 Generated master Dart index: ${indexFilePath}`);
    
    return dartContent;
}


/**
 * Main execution function
 */
async function main() {
    console.log('🗓️  Sancta Via Dart Liturgical Calendar Generator v2.0');
    console.log(`📅 Generating Dart calendars for years ${START_YEAR}-${END_YEAR}`);
    console.log(`📁 Dart output: ${dartOutputPath}`);
    console.log('');
    
    const startTime = Date.now();
    const yearSummaries = [];
    
    try {
        // Generate calendar for each year
        for (let year = START_YEAR; year <= END_YEAR; year++) {
            const summary = await generateYearDartCalendar(year);
            yearSummaries.push(summary);
        }
        
        // Generate master index
        generateMasterDartIndex(yearSummaries);
        
        const endTime = Date.now();
        const duration = ((endTime - startTime) / 1000).toFixed(2);
        
        console.log('');
        console.log('🎉 Dart calendar generation completed successfully!');
        console.log(`⏱️  Total time: ${duration} seconds`);
        console.log(`📊 Generated ${yearSummaries.length} Dart calendar files`);
        
        // Calculate total file sizes
        let totalSize = 0;
        yearSummaries.forEach(summary => {
            const filepath = path.join(dartOutputPath, `liturgical_calendar_${summary.year}.dart`);
            const stats = fs.statSync(filepath);
            totalSize += stats.size;
        });
        
        console.log(`💾 Total Dart code size: ${(totalSize / 1024 / 1024).toFixed(2)} MB`);
        console.log('');
        console.log('📋 Files generated:');
        console.log(`   • ${yearSummaries.length} year files (liturgical_calendar_YYYY.dart)`);
        console.log(`   • generated_liturgical_data.dart (master index)`);
        console.log('');
        console.log('📝 Next steps:');
        console.log('1. Use LiturgicalCalendarService for instant data access');
        console.log('2. Run `dart analyze` to check the generated code');
        console.log('3. Run tests to verify the integration works');
        console.log('4. The data is now embedded and requires no external assets!');
        
    } catch (error) {
        console.error('❌ Failed to generate Dart liturgical calendars:', error);
        process.exit(1);
    }
}

// Run the script
if (require.main === module) {
    main();
}

module.exports = {
    generateYearDartCalendar,
    formatDate,
    processCalendarData,
    generateMasterDartIndex,
    START_YEAR,
    END_YEAR
};
