import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sancta_via_liturgical_calendar_riverpod/sancta_via_liturgical_calendar_riverpod.dart';

import '../models/encouragement.dart';
import '../models/fast_session.dart';
import '../models/fast_type.dart';
import '../repositories/fasting_repository.dart';
import 'fast_session_providers.dart';
import 'fast_type_providers.dart';

/// Provider for all encouragements
final allEncouragementsProvider = FutureProvider<List<Encouragement>>((ref) async {
  final repository = ref.watch(fastingRepositoryProvider);
  return repository.getAllEncouragements();
});

/// Provider for encouragement based on trigger and current context
final encouragementForTriggerProvider =
    FutureProvider.family<Encouragement?, String>((ref, triggerPoint) async {
  final repository = ref.watch(fastingRepositoryProvider);

  // Get current liturgical season
  final liturgicalDay = ref.watch(currentLiturgicalDayProvider);
  final liturgicalSeason = liturgicalDay?.season.toLowerCase();

  // Get active session ID if available
  final sessionAsync = ref.watch(activeFastSessionProvider);
  String? sessionId;
  if (sessionAsync is AsyncData<FastSession?> && sessionAsync.value != null) {
    sessionId = sessionAsync.value!.id;
  }

  return repository.getEncouragementForContext(
    triggerPoint: triggerPoint,
    liturgicalSeason: liturgicalSeason,
    sessionId: sessionId,
  );
});

/// Provider for start encouragement
final startEncouragementProvider = FutureProvider<Encouragement?>((ref) {
  return ref.watch(encouragementForTriggerProvider('start').future);
});

/// Provider for hourly encouragement
final hourlyEncouragementProvider = FutureProvider<Encouragement?>((ref) {
  return ref.watch(encouragementForTriggerProvider('hourly').future);
});

/// Provider for milestone encouragement
final milestoneEncouragementProvider = FutureProvider<Encouragement?>((ref) {
  return ref.watch(encouragementForTriggerProvider('milestone').future);
});

/// Provider for difficulty encouragement
final difficultyEncouragementProvider = FutureProvider<Encouragement?>((ref) {
  return ref.watch(encouragementForTriggerProvider('difficulty').future);
});

/// Provider for completion encouragement
final completionEncouragementProvider = FutureProvider<Encouragement?>((ref) {
  return ref.watch(encouragementForTriggerProvider('completion').future);
});

/// Notifier for tracking which encouragements have been shown
class EncouragementTrackerNotifier extends StateNotifier<Set<String>> {
  final FastingRepository fastingRepository;

  EncouragementTrackerNotifier(this.fastingRepository) : super({});

  /// Mark an encouragement as shown for the current session
  Future<void> markShown(String sessionId, String encouragementId) async {
    await fastingRepository.markEncouragementShown(sessionId, encouragementId);
    state = {...state, encouragementId};
  }

  /// Reset the tracker (e.g., when starting a new fast)
  void reset() {
    state = {};
  }
}

/// Provider for tracking shown encouragements
final encouragementTrackerProvider =
    StateNotifierProvider<EncouragementTrackerNotifier, Set<String>>((ref) {
  return EncouragementTrackerNotifier(
    ref.watch(fastingRepositoryProvider),
  );
});

/// Provider for checking if milestone encouragement should be shown
final shouldShowMilestoneProvider = Provider<bool>((ref) {
  final sessionAsync = ref.watch(activeFastSessionProvider);
  if (sessionAsync is! AsyncData<FastSession?> || sessionAsync.value == null) {
    return false;
  }

  final session = sessionAsync.value!;
  final elapsedHours = session.elapsedHours;

  // Get the fast type to check milestones
  final fastTypeAsync = ref.watch(fastTypeByIdProvider(session.fastTypeId));
  if (fastTypeAsync is! AsyncData<FastType?> || fastTypeAsync.value == null) {
    return false;
  }

  final fastType = fastTypeAsync.value!;

  // Check if we've hit a milestone hour
  final milestoneHours = fastType.milestoneMessages.keys.toList()..sort();
  for (final milestoneHour in milestoneHours) {
    // If we just passed a milestone hour (within the last minute update cycle)
    if (elapsedHours >= milestoneHour &&
        elapsedHours < milestoneHour + 1 / 60) {
      // Check if we haven't shown this milestone yet
      final shownEncouragements = ref.watch(encouragementTrackerProvider);
      final milestoneKey = 'milestone_$milestoneHour';
      if (!shownEncouragements.contains(milestoneKey)) {
        return true;
      }
    }
  }

  return false;
});

/// Provider for current milestone message
final currentMilestoneMessageProvider = Provider<String?>((ref) {
  final sessionAsync = ref.watch(activeFastSessionProvider);
  if (sessionAsync is! AsyncData<FastSession?> || sessionAsync.value == null) {
    return null;
  }

  final session = sessionAsync.value!;
  final elapsedHours = session.elapsedHours;

  // Get the fast type to check milestones
  final fastTypeAsync = ref.watch(fastTypeByIdProvider(session.fastTypeId));
  if (fastTypeAsync is! AsyncData<FastType?> || fastTypeAsync.value == null) {
    return null;
  }

  final fastType = fastTypeAsync.value!;

  // Find the most recent milestone that has been passed
  String? message;
  int closestHour = -1;

  for (final entry in fastType.milestoneMessages.entries) {
    if (elapsedHours >= entry.key && entry.key > closestHour) {
      closestHour = entry.key;
      message = entry.value;
    }
  }

  return message;
});

/// Provider for checking if hourly encouragement should be shown
final shouldShowHourlyProvider = Provider<({bool show, int hour})>((ref) {
  final sessionAsync = ref.watch(activeFastSessionProvider);
  if (sessionAsync is! AsyncData<FastSession?> || sessionAsync.value == null) {
    return (show: false, hour: 0);
  }

  final session = sessionAsync.value!;
  final elapsedMinutes = session.elapsedMinutes;
  final currentHour = (elapsedMinutes / 60).floor();

  // Show hourly encouragement at the start of each hour
  // (within first minute of the hour)
  final minutesIntoHour = elapsedMinutes % 60;
  if (minutesIntoHour < 1 && currentHour > 0) {
    final shownEncouragements = ref.watch(encouragementTrackerProvider);
    final hourlyKey = 'hourly_$currentHour';
    if (!shownEncouragements.contains(hourlyKey)) {
      return (show: true, hour: currentHour);
    }
  }

  return (show: false, hour: currentHour);
});
