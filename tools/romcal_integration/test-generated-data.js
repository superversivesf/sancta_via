#!/usr/bin/env node

/**
 * Test script to verify the generated liturgical calendar data
 */

const fs = require('fs');
const path = require('path');

const dataDir = '../../legacy/assets/liturgical';

console.log('🧪 Testing generated liturgical calendar data...\n');

try {
    // Test index file
    const indexPath = path.resolve(__dirname, dataDir, 'index.json');
    const index = JSON.parse(fs.readFileSync(indexPath, 'utf8'));
    
    console.log(`📋 Index file loaded successfully`);
    console.log(`   Years available: ${index.totalYears}`);
    console.log(`   Year range: ${index.yearRange.start}-${index.yearRange.end}`);
    console.log(`   Data version: ${index.dataVersion}`);
    console.log(`   RomCal version: ${index.romcalVersion}`);
    
    // Test sample year files
    console.log('\n📅 Testing year files...');
    const testYears = [2024, 2025, 2035];
    
    for (const year of testYears) {
        const yearPath = path.resolve(__dirname, dataDir, `${year}.json`);
        if (fs.existsSync(yearPath)) {
            const yearData = JSON.parse(fs.readFileSync(yearPath, 'utf8'));
            
            console.log(`   ✅ ${year}: ${yearData.metadata.totalDays} days, ${yearData.metadata.prioritizedCelebrations} prioritized celebrations`);
            
            // Test a few sample dates
            const sampleDates = [`${year}-01-01`, `${year}-12-25`];
            for (const date of sampleDates) {
                if (yearData.calendar[date]) {
                    const day = yearData.calendar[date];
                    console.log(`      ${date}: ${day.celebration.name} (${day.celebration.rank}, ${day.celebration.color})`);
                }
            }
        } else {
            console.log(`   ❌ ${year}: File not found`);
        }
    }
    
    // Calculate total data statistics
    console.log('\n📊 Data statistics:');
    let totalDays = 0;
    let totalCelebrations = 0;
    const allSeasons = new Set();
    const allColors = new Set();
    
    for (const yearInfo of index.years) {
        totalDays += yearInfo.totalDays;
        totalCelebrations += yearInfo.prioritizedCelebrations;
    }
    
    // Sample a year for detailed stats
    const sample2025Path = path.resolve(__dirname, dataDir, '2025.json');
    if (fs.existsSync(sample2025Path)) {
        const sample2025 = JSON.parse(fs.readFileSync(sample2025Path, 'utf8'));
        Object.keys(sample2025.metadata.seasons).forEach(s => allSeasons.add(s));
        Object.keys(sample2025.metadata.colors).forEach(c => allColors.add(c));
    }
    
    console.log(`   Total days across all years: ${totalDays}`);
    console.log(`   Total prioritized celebrations: ${totalCelebrations}`);
    console.log(`   Seasons found: ${Array.from(allSeasons).join(', ')}`);
    console.log(`   Colors found: ${Array.from(allColors).join(', ')}`);
    
    // File size analysis
    const files = fs.readdirSync(path.resolve(__dirname, dataDir)).filter(f => f.endsWith('.json'));
    let totalSize = 0;
    
    for (const file of files) {
        const filePath = path.resolve(__dirname, dataDir, file);
        const stats = fs.statSync(filePath);
        totalSize += stats.size;
    }
    
    console.log(`\n💾 File information:`);
    console.log(`   Total files: ${files.length}`);
    console.log(`   Total size: ${(totalSize / 1024 / 1024).toFixed(2)} MB`);
    console.log(`   Average per year: ${(totalSize / (files.length - 1) / 1024).toFixed(0)} KB`); // -1 for index.json
    
    console.log('\n✅ Generated data verification completed successfully!');
    console.log('\n🚀 Data is ready for use with the liturgical_calendar package');
    
} catch (error) {
    console.error('❌ Data verification failed:', error);
    console.error('\n💡 Make sure to run: npm run generate');
    process.exit(1);
}