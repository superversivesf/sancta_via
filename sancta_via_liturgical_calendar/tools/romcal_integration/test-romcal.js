#!/usr/bin/env node

/**
 * Test script to verify RomCal installation and basic functionality
 * Run this first to make sure romcal is working before generating full calendars
 */

const Romcal = require('romcal').default;

console.log('🧪 Testing RomCal library...\n');

try {
    // Test basic calendar generation for current year
    const currentYear = new Date().getFullYear();
    console.log(`📅 Testing calendar generation for ${currentYear}...`);
    
    const calendar = Romcal.calendarFor({
        year: currentYear,
        country: 'general',
        locale: 'en'
    });
    
    // Handle both Map and Array formats
    const calendarArray = calendar instanceof Map ? Array.from(calendar.values()) : calendar;
    
    console.log(`✅ Successfully generated calendar with ${calendarArray.length} days`);
    
    // Show a few sample days
    console.log('\n📝 Sample liturgical days:');
    let count = 0;
    for (const day of calendarArray) {
        if (count >= 5) break;
        
        let dateStr;
        if (day.moment) {
            dateStr = day.moment.format ? day.moment.format('YYYY-MM-DD') : day.moment.toString().split('T')[0];
        } else if (day.date) {
            dateStr = day.date.toString().split('T')[0];
        } else {
            dateStr = 'Unknown date';
        }
        
        console.log(`   ${dateStr}: ${day.name || 'Ordinary day'}`);
        console.log(`      Rank: ${day.rank || day.type || 'N/A'}`);
        console.log(`      Color: ${day.color || day.data?.meta?.liturgicalColor?.key || 'Green'}`);
        console.log(`      Season: ${day.season || day.data?.season?.value || 'Ordinary Time'}`);
        console.log('');
        
        count++;
    }
    
    // Test specific important dates
    console.log('🎄 Testing access to specific liturgical dates:');
    
    const testDates = [
        { month: 12, day: 25, name: 'Christmas' },
        { month: 1, day: 1, name: 'Mary, Mother of God' },
        { month: 1, day: 6, name: 'Epiphany' },
    ];
    
    for (const testDate of testDates) {
        const found = calendarArray.find(day => {
            let dayDate;
            if (day.moment) {
                dayDate = day.moment.format ? day.moment.format('MM-DD') : day.moment.toString().substring(5, 10);
            } else if (day.date) {
                dayDate = day.date.toString().substring(5, 10);
            }
            const expectedDate = `${testDate.month.toString().padStart(2, '0')}-${testDate.day.toString().padStart(2, '0')}`;
            return dayDate === expectedDate;
        });
        
        if (found) {
            console.log(`   ✅ ${testDate.name}: ${found.name || 'Found'}`);
            console.log(`      Rank: ${found.rank || found.type || 'N/A'}`);
            console.log(`      Color: ${found.color || found.data?.meta?.liturgicalColor?.key || 'N/A'}`);
        } else {
            console.log(`   ❓ ${testDate.name}: Not found or different name`);
        }
    }
    
    // Test data structure analysis
    console.log('\n🔍 Analyzing data structure...');
    if (calendarArray.length > 0) {
        const sampleDay = calendarArray[0];
        console.log('Sample day structure:');
        console.log('Available properties:', Object.keys(sampleDay));
        
        if (sampleDay.data) {
            console.log('Data sub-properties:', Object.keys(sampleDay.data));
            if (sampleDay.data.meta) {
                console.log('Meta sub-properties:', Object.keys(sampleDay.data.meta));
            }
        }
    }
    
    console.log('\n✅ RomCal test completed successfully!');
    console.log('🚀 Ready to generate full calendar data');
    console.log('\nRun: npm run generate');
    
} catch (error) {
    console.error('❌ RomCal test failed:', error);
    console.error('\n💡 Troubleshooting steps:');
    console.error('1. Make sure to run: npm install');
    console.error('2. Check that romcal version 1.3.0 is installed');
    console.error('3. Verify Node.js version is compatible');
    console.error('\nError details:', error.stack);
    process.exit(1);
}