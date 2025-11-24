import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sancta_via_liturgical_calendar/sancta_via_liturgical_calendar.dart';
import 'liturgical_providers.dart';

/// Provider for major feasts (Christmas, Easter, etc.)
final majorFeastsProvider = Provider.family<List<LiturgicalDayData>, int>((ref, year) {
  final allDays = ref.watch(allDaysInYearProvider(year));
  return allDays.where((day) => 
    day.celebration.rank == 'SOLEMNITY' && 
    day.celebration.prioritized
  ).toList();
});

/// Provider for Mary-related celebrations
final maryFeastsProvider = Provider.family<List<LiturgicalDayData>, int>((ref, year) {
  return ref.watch(searchCelebrationsProvider((query: 'Mary', year: year)));
});

/// Provider for saint commemorations
final saintCommemorationsProvider = Provider.family<List<LiturgicalDayData>, int>((ref, year) {
  final allDays = ref.watch(allDaysInYearProvider(year));
  return allDays.where((day) => 
    day.celebration.rank == 'MEMORIAL' || 
    day.celebration.rank == 'OPTIONAL_MEMORIAL' ||
    day.celebration.rank == 'OPT_MEMORIAL'
  ).toList();
});

/// Provider for this week's liturgical days
final thisWeekProvider = Provider<List<LiturgicalDayData>>((ref) {
  final now = DateTime.now();
  final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
  final endOfWeek = startOfWeek.add(const Duration(days: 6));
  
  return ref.watch(daysInRangeProvider((start: startOfWeek, end: endOfWeek)));
});

/// Provider for this month's liturgical days
final thisMonthProvider = Provider<List<LiturgicalDayData>>((ref) {
  final now = DateTime.now();
  final startOfMonth = DateTime(now.year, now.month, 1);
  final endOfMonth = DateTime(now.year, now.month + 1, 0);
  
  return ref.watch(daysInRangeProvider((start: startOfMonth, end: endOfMonth)));
});

/// Provider for feast days this month
final feastDaysThisMonthProvider = Provider<List<LiturgicalDayData>>((ref) {
  final thisMonth = ref.watch(thisMonthProvider);
  return thisMonth.where((day) => 
    day.celebration.prioritized ||
    day.celebration.rank == 'SOLEMNITY' ||
    day.celebration.rank == 'FEAST'
  ).toList();
});

/// Provider for liturgical calendar analytics
final liturgicalAnalyticsProvider = Provider.family<Map<String, dynamic>, int>((ref, year) {
  final allDays = ref.watch(allDaysInYearProvider(year));
  final stats = <String, dynamic>{};
  
  // Count by season
  final seasonCounts = <String, int>{};
  final colorCounts = <String, int>{};
  final rankCounts = <String, int>{};
  
  for (final day in allDays) {
    seasonCounts[day.season] = (seasonCounts[day.season] ?? 0) + 1;
    colorCounts[day.celebration.color] = (colorCounts[day.celebration.color] ?? 0) + 1;
    rankCounts[day.celebration.rank] = (rankCounts[day.celebration.rank] ?? 0) + 1;
  }
  
  stats['totalDays'] = allDays.length;
  stats['seasonCounts'] = seasonCounts;
  stats['colorCounts'] = colorCounts;
  stats['rankCounts'] = rankCounts;
  stats['prioritizedCount'] = allDays.where((d) => d.celebration.prioritized).length;
  
  return stats;
});

/// Provider for next major celebration
final nextMajorCelebrationProvider = Provider<LiturgicalDayData?>((ref) {
  final upcoming = ref.watch(upcomingFeastsProvider(90));
  
  // Find the next solemnity or major feast
  for (final day in upcoming) {
    if (day.celebration.rank == 'SOLEMNITY' || 
        (day.celebration.rank == 'FEAST' && day.celebration.prioritized)) {
      return day;
    }
  }
  
  return upcoming.isNotEmpty ? upcoming.first : null;
});

/// Provider for days until next major celebration
final daysUntilMajorCelebrationProvider = Provider<int?>((ref) {
  final nextMajor = ref.watch(nextMajorCelebrationProvider);
  if (nextMajor == null) return null;
  
  final nextDate = DateTime.parse(nextMajor.date);
  final now = DateTime.now();
  return nextDate.difference(now).inDays;
});

/// Provider for seasonal color progression
final seasonalColorProgressionProvider = Provider<List<Map<String, dynamic>>>((ref) {
  final now = DateTime.now();
  final yearData = ref.watch(allDaysInYearProvider(now.year));
  
  final progression = <Map<String, dynamic>>[];
  String? currentSeason;
  String? currentColor;
  DateTime? seasonStart;
  
  for (final day in yearData) {
    if (day.season != currentSeason || day.celebration.color != currentColor) {
      if (currentSeason != null) {
        progression.add({
          'season': currentSeason,
          'color': currentColor,
          'startDate': seasonStart!.toIso8601String().split('T')[0],
          'endDate': DateTime.parse(day.date).subtract(const Duration(days: 1)).toIso8601String().split('T')[0],
        });
      }
      currentSeason = day.season;
      currentColor = day.celebration.color;
      seasonStart = DateTime.parse(day.date);
    }
  }
  
  // Add the final season
  if (currentSeason != null) {
    progression.add({
      'season': currentSeason,
      'color': currentColor,
      'startDate': seasonStart!.toIso8601String().split('T')[0],
      'endDate': '${now.year}-12-31',
    });
  }
  
  return progression;
});

/// Provider for liturgical reminders/notifications
final liturgicalRemindersProvider = Provider<List<Map<String, dynamic>>>((ref) {
  final upcoming = ref.watch(upcomingFeastsProvider(7));
  final reminders = <Map<String, dynamic>>[];
  
  for (final day in upcoming) {
    final dayDate = DateTime.parse(day.date);
    final daysUntil = dayDate.difference(DateTime.now()).inDays;
    
    if (day.celebration.prioritized) {
      reminders.add({
        'title': day.celebration.name,
        'date': day.date,
        'daysUntil': daysUntil,
        'rank': day.celebration.rank,
        'season': day.season,
        'color': day.celebration.color,
        'priority': day.celebration.rank == 'SOLEMNITY' ? 'high' : 'medium',
      });
    }
  }
  
  return reminders;
});

/// Provider for current liturgical "mode" or emphasis
final liturgicalModeProvider = Provider<Map<String, dynamic>>((ref) {
  final currentDay = ref.watch(currentLiturgicalDayProvider);
  if (currentDay == null) {
    return {'mode': 'unknown', 'emphasis': 'none'};
  }
  
  final season = currentDay.season.toLowerCase();
  final rank = currentDay.celebration.rank;
  
  String mode;
  String emphasis;
  
  if (rank == 'SOLEMNITY') {
    mode = 'celebration';
    emphasis = 'high';
  } else if (season.contains('advent')) {
    mode = 'preparation';
    emphasis = 'anticipation';
  } else if (season.contains('lent')) {
    mode = 'penance';
    emphasis = 'reflection';
  } else if (season.contains('christmas') || season.contains('easter')) {
    mode = 'celebration';
    emphasis = 'joy';
  } else {
    mode = 'ordinary';
    emphasis = 'growth';
  }
  
  return {
    'mode': mode,
    'emphasis': emphasis,
    'season': currentDay.season,
    'rank': rank,
    'color': currentDay.celebration.color,
  };
});

/// Provider for liturgical year progress
final liturgicalYearProgressProvider = Provider<Map<String, dynamic>>((ref) {
  final now = DateTime.now();
  final currentDay = ref.watch(currentLiturgicalDayProvider);
  if (currentDay == null) {
    return {'progress': 0.0, 'dayOfYear': 0, 'totalDays': 365};
  }
  
  final yearData = ref.watch(allDaysInYearProvider(now.year));
  final dayOfYear = now.difference(DateTime(now.year, 1, 1)).inDays + 1;
  final totalDays = yearData.length;
  final progress = dayOfYear / totalDays;
  
  return {
    'progress': progress,
    'dayOfYear': dayOfYear,
    'totalDays': totalDays,
    'currentWeek': currentDay.liturgicalYear.week,
    'weekOfSeason': currentDay.liturgicalYear.weekOfSeason,
  };
});
