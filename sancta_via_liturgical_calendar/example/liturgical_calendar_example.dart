import 'package:sancta_via_liturgical_calendar/sancta_via_liturgical_calendar.dart';

void main() async {
  print('Liturgical Calendar Library Example - Embedded Data');
  print('==================================================');

  // No initialization needed - data is embedded!
  print('✅ Service ready immediately - no initialization required!');
  print('Available years: ${LiturgicalCalendarService.getAvailableYears()}');

  // Show the performance benefits
  final yearRange = LiturgicalCalendarService.getYearRange();
  print('Year range: ${yearRange.start} - ${yearRange.end}');
  print('Total days in dataset: ${GeneratedLiturgicalData.getTotalDays()}');
  print('Total prioritized celebrations: ${GeneratedLiturgicalData.getTotalPrioritizedCelebrations()}');

  // Example: Get Christmas Day 2025
  final christmas = LiturgicalCalendarService.getDayForDate(
    DateTime(2025, 12, 25),
  );

  if (christmas != null) {
    print('\n🎄 Christmas Day 2025:');
    print('  Celebration: ${christmas.celebration.name}');
    print('  Rank: ${christmas.celebration.rank}');
    print('  Color: ${christmas.celebration.color}');
    print('  Season: ${christmas.season}');
    print('  Prioritized: ${christmas.celebration.prioritized}');
  }

  // Example: Get today's liturgical information
  final today = LiturgicalCalendarService.getCurrentDay();
  if (today != null) {
    print('\n📅 Today (${today.date}):');
    print('  ${today.displayName}');
    print('  Season: ${today.season}');
    print('  Color: ${today.celebration.color}');
    print('  Rank: ${today.celebration.rank}');
  } else {
    print('\n❌ No data available for today\'s date (outside 2024-2035 range).');
  }

  // Example: Get upcoming feasts and solemnities
  print('\n⭐ Upcoming major celebrations (next 30 days):');
  final upcomingFeasts = LiturgicalCalendarService.getUpcomingFeasts();
  for (final feast in upcomingFeasts.take(5)) {
    print('  ${feast.date}: ${feast.celebration.name} (${feast.celebration.rank})');
  }

  // Example: Search for specific celebrations
  print('\n🔍 Search for "Mary" celebrations in 2025:');
  final maryFeasts = LiturgicalCalendarService.searchCelebrations('Mary', year: 2025);
  for (final feast in maryFeasts.take(3)) {
    print('  ${feast.date}: ${feast.celebration.name}');
  }

  // Example: Get seasonal data
  print('\n🕯️ Advent days in 2025:');
  final adventDays = LiturgicalCalendarService.getDaysForSeason(2025, 'Advent');
  print('  Found ${adventDays.length} days in Advent');
  if (adventDays.isNotEmpty) {
    print('  First day: ${adventDays.first.date}');
    print('  Last day: ${adventDays.last.date}');
  }

  // Performance comparison
  print('\n⚡ Performance Benefits:');
  print('  ✅ Zero initialization time');
  print('  ✅ No JSON parsing overhead');
  print('  ✅ Compile-time data validation');
  print('  ✅ Better tree-shaking (only used data included)');
  print('  ✅ Type safety at compile time');
  print('  ✅ Instant data access');

  print('\n🎉 Example completed successfully!');
  print('The liturgical calendar data is embedded as native Dart objects for maximum performance.');
}
