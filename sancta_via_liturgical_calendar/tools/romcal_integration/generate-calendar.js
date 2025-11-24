#!/usr/bin/env node

/**
 * Liturgical Calendar Generator for Sancta Via Monorepo
 * 
 * Generates liturgical calendar data using RomCal for multiple years
 * and saves them as JSON files for the liturgical_calendar package.
 * 
 * Usage:
 *   node generate-calendar.js                    # Generate default range (2024-2035)
 *   node generate-calendar.js --years=10         # Generate 10 years from current year
 *   node generate-calendar.js --start=2024 --end=2035  # Generate specific range
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

// Output directories
const LEGACY_OUTPUT_DIR = '../../legacy/assets/liturgical';
const PACKAGE_DATA_DIR = '../../packages/liturgical_calendar/lib/src/data';

// Ensure output directories exist
const legacyOutputPath = path.resolve(__dirname, LEGACY_OUTPUT_DIR);
const packageDataPath = path.resolve(__dirname, PACKAGE_DATA_DIR);

[legacyOutputPath, packageDataPath].forEach(dir => {
    if (!fs.existsSync(dir)) {
        fs.mkdirSync(dir, { recursive: true });
        console.log(`Created output directory: ${dir}`);
    }
});

/**
 * Format a date for our JSON structure
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
 * Generate calendar for a specific year
 */
async function generateYearCalendar(year) {
    console.log(`Generating liturgical calendar for ${year}...`);
    
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
        
        // Create the final data structure
        const calendarWithMetadata = {
            metadata: metadata,
            calendar: processedData
        };
        
        // Write to legacy location (for existing apps)
        const legacyFilename = `${year}.json`;
        const legacyFilepath = path.join(legacyOutputPath, legacyFilename);
        fs.writeFileSync(legacyFilepath, JSON.stringify(calendarWithMetadata, null, 2));
        
        console.log(`✅ Generated ${legacyFilename} - ${metadata.totalDays} days, ${metadata.prioritizedCelebrations} prioritized celebrations`);
        console.log(`   Seasons: ${Object.keys(metadata.seasons).join(', ')}`);
        console.log(`   Colors: ${Object.keys(metadata.colors).join(', ')}`);
        console.log(`   Types: ${Object.keys(metadata.types).join(', ')}`);
        
        return metadata;
        
    } catch (error) {
        console.error(`❌ Error generating calendar for ${year}:`, error);
        throw error;
    }
}

/**
 * Generate master index file with all years
 */
function generateMasterIndex(yearSummaries) {
    const masterIndex = {
        generatedAt: new Date().toISOString(),
        dataVersion: '1.0.0',
        romcalVersion: '1.3.0',
        years: yearSummaries.map(summary => ({
            year: summary.year,
            totalDays: summary.totalDays,
            prioritizedCelebrations: summary.prioritizedCelebrations,
            file: `${summary.year}.json`
        })),
        totalYears: yearSummaries.length,
        yearRange: {
            start: START_YEAR,
            end: END_YEAR
        },
        dataStructure: {
            description: "Liturgical calendar data generated from RomCal 1.3.0",
            dateFormat: "YYYY-MM-DD",
            structure: {
                metadata: "Summary information about the year",
                calendar: "Object with date keys containing liturgical information"
            },
            availableColors: ["red", "white", "green", "purple", "rose"],
            availableSeasons: ["Advent", "Christmas", "Ordinary Time", "Lent", "Easter"],
            availableTypes: ["SOLEMNITY", "FEAST", "MEMORIAL", "OPTIONAL_MEMORIAL", "WEEKDAY"],
            lastUpdated: new Date().toISOString()
        }
    };
    
    // Write to legacy location
    const legacyIndexPath = path.join(legacyOutputPath, 'index.json');
    fs.writeFileSync(legacyIndexPath, JSON.stringify(masterIndex, null, 2));
    console.log(`📋 Generated master index: ${legacyIndexPath}`);
    
    return masterIndex;
}

/**
 * Generate data loading instructions for the library
 */
function generateDataLoaderTemplate(yearSummaries) {
    const template = `// Auto-generated data loader template for Flutter/Dart
// This shows how to create a data loader for the liturgical_calendar package

import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:liturgical_calendar/liturgical_calendar.dart';

/// Flutter asset-based data loader for liturgical calendar
class AssetLiturgicalDataLoader implements LiturgicalDataLoader {
  static const String _assetBase = 'assets/liturgical';
  
  @override
  Future<bool> hasData(String filename) async {
    try {
      await rootBundle.loadString('$_assetBase/$filename');
      return true;
    } catch (e) {
      return false;
    }
  }
  
  @override
  Future<String> loadIndexData() async {
    return await rootBundle.loadString('$_assetBase/index.json');
  }
  
  @override
  Future<String> loadYearData(String filename) async {
    return await rootBundle.loadString('$_assetBase/$filename');
  }
}

// Usage example:
// final dataLoader = AssetLiturgicalDataLoader();
// await LiturgicalCalendarService.initialize(dataLoader);

// Available years: ${yearSummaries.map(s => s.year).join(', ')}
// Total data size: ~${yearSummaries.reduce((sum, s) => sum + s.totalDays, 0)} days
`;

    const templatePath = path.join(packageDataPath, 'asset_data_loader_template.dart');
    fs.writeFileSync(templatePath, template);
    console.log(`📝 Generated data loader template: ${templatePath}`);
}

/**
 * Main execution function
 */
async function main() {
    console.log('🗓️  Sancta Via Liturgical Calendar Generator v2.0');
    console.log(`📅 Generating calendars for years ${START_YEAR}-${END_YEAR}`);
    console.log(`📁 Legacy output: ${legacyOutputPath}`);
    console.log(`📁 Package data: ${packageDataPath}`);
    console.log('');
    
    const startTime = Date.now();
    const yearSummaries = [];
    
    try {
        // Generate calendar for each year
        for (let year = START_YEAR; year <= END_YEAR; year++) {
            const summary = await generateYearCalendar(year);
            yearSummaries.push(summary);
        }
        
        // Generate master index
        const masterIndex = generateMasterIndex(yearSummaries);
        
        // Generate data loader template
        generateDataLoaderTemplate(yearSummaries);
        
        const endTime = Date.now();
        const duration = ((endTime - startTime) / 1000).toFixed(2);
        
        console.log('');
        console.log('🎉 Calendar generation completed successfully!');
        console.log(`⏱️  Total time: ${duration} seconds`);
        console.log(`📊 Generated ${yearSummaries.length} calendar files`);
        
        // Calculate total file sizes
        let totalSize = 0;
        yearSummaries.forEach(summary => {
            const filepath = path.join(legacyOutputPath, `${summary.year}.json`);
            const stats = fs.statSync(filepath);
            totalSize += stats.size;
        });
        
        console.log(`💾 Total size: ${(totalSize / 1024 / 1024).toFixed(2)} MB`);
        console.log('');
        console.log('📋 Files generated:');
        console.log(`   • ${yearSummaries.length} year files (${START_YEAR}.json - ${END_YEAR}.json)`);
        console.log(`   • index.json (master index)`);
        console.log(`   • asset_data_loader_template.dart (integration template)`);
        console.log('');
        console.log('📝 Next steps:');
        console.log('1. Copy the JSON files to your Flutter app assets/liturgical/ folder');
        console.log('2. Use the generated template to create your data loader');
        console.log('3. Initialize the liturgical calendar service in your app');
        console.log('4. Run tests to verify the integration works');
        
    } catch (error) {
        console.error('❌ Failed to generate liturgical calendars:', error);
        process.exit(1);
    }
}

// Run the script
if (require.main === module) {
    main();
}

module.exports = {
    generateYearCalendar,
    formatDate,
    processCalendarData,
    START_YEAR,
    END_YEAR
};