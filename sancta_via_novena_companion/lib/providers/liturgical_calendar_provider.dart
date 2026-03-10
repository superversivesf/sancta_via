import 'package:sancta_via_liturgical_calendar_riverpod/sancta_via_liturgical_calendar_riverpod.dart';

// Provider for active liturgical color based on current day
final activeLiturgicalColorProvider = Provider<LiturgicalColor?>((ref) {
  final liturgicalColorString = ref.watch(currentLiturgicalColorProvider);

  return LiturgicalColor.fromString(liturgicalColorString ?? 'GREEN');
});

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
