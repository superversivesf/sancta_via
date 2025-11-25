import 'package:sancta_via_liturgical_calendar_riverpod/sancta_via_liturgical_calendar_riverpod.dart';

// Liturgical color enum
enum LiturgicalColor {
  green, // Ordinary Time
  purple, // Advent, Lent
  rose, // Gaudete, Laetare Sundays
  white, // Christmas, Easter, major feasts
  red, // Pentecost, martyrs, Palm Sunday
  gold, // High feasts (alternative to white)
}

// Provider for active liturgical color based on current day
final activeLiturgicalColorProvider = Provider<LiturgicalColor>((ref) {
  final liturgicalColorString = ref.watch(currentLiturgicalColorProvider);

  return _mapLiturgicalColorFromString(liturgicalColorString ?? 'green');
});

// Map liturgical color string to enum
LiturgicalColor _mapLiturgicalColorFromString(String colorString) {
  switch (colorString.toLowerCase()) {
    case 'green':
      return LiturgicalColor.green;
    case 'purple':
    case 'violet':
      return LiturgicalColor.purple;
    case 'rose':
    case 'pink':
      return LiturgicalColor.rose;
    case 'white':
      return LiturgicalColor.white;
    case 'red':
      return LiturgicalColor.red;
    case 'gold':
    case 'yellow':
      return LiturgicalColor.gold;
    default:
      return LiturgicalColor.green; // Default fallback
  }
}

// Provider for liturgical season name
final liturgicalSeasonProvider = Provider<String>((ref) {
  final season = ref.watch(currentLiturgicalSeasonProvider);
  return season ?? 'Ordinary Time';
});

// Provider for today's liturgical celebration
final liturgicalCelebrationProvider = Provider<String>((ref) {
  final currentDay = ref.watch(currentLiturgicalDayProvider);
  return currentDay?.celebration.name ?? 'Weekday';
});

// Provider for today's liturgical rank
final liturgicalRankProvider = Provider<String>((ref) {
  final rank = ref.watch(currentCelebrationRankProvider);
  return rank ?? 'Weekday';
});

// Provider for whether today is a special celebration
final isSpecialCelebrationProvider = Provider<bool>((ref) {
  return ref.watch(todayHasPrioritizedCelebrationProvider);
});
