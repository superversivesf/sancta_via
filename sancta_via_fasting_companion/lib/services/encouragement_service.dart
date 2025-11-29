import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/encouragement.dart';
import '../models/fast_session.dart';
import '../providers/encouragement_providers.dart';
import '../providers/fast_session_providers.dart';
import '../providers/fast_type_providers.dart';
import '../repositories/fasting_repository.dart';

/// Trigger points for showing encouragements
enum EncouragementTrigger {
  start('start'),
  hourly('hourly'),
  milestone('milestone'),
  difficulty('difficulty'),
  completion('completion');

  final String value;
  const EncouragementTrigger(this.value);
}

/// Service for coordinating encouragement delivery
class EncouragementService {
  final Ref ref;
  final FastingRepository repository;

  DateTime? _lastHourlyCheck;
  int? _lastMilestonePercentage;

  EncouragementService(this.ref, this.repository);

  /// Check if it's time to show an hourly encouragement
  bool shouldShowHourlyEncouragement(FastSession session) {
    final now = DateTime.now();
    final elapsed = now.difference(session.startTime);

    // Check if at least one hour has passed
    if (elapsed.inHours < 1) {
      return false;
    }

    // Check if we haven't shown one in the last hour
    if (_lastHourlyCheck != null) {
      final timeSinceLastCheck = now.difference(_lastHourlyCheck!);
      if (timeSinceLastCheck.inMinutes < 60) {
        return false;
      }
    }

    return true;
  }

  /// Check if a milestone has been reached (25%, 50%, 75%)
  bool shouldShowMilestoneEncouragement(FastSession session) {
    final progress = _calculateProgress(session);
    final percentage = (progress * 100).round();

    // Define milestone thresholds
    final milestones = [25, 50, 75];

    for (final milestone in milestones) {
      // If we've reached or passed this milestone
      if (percentage >= milestone) {
        // And we haven't shown this milestone yet
        if (_lastMilestonePercentage == null ||
            _lastMilestonePercentage! < milestone) {
          return true;
        }
      }
    }

    return false;
  }

  /// Get an encouragement for a specific trigger
  Future<Encouragement?> getEncouragementForTrigger(
    EncouragementTrigger trigger,
  ) async {
    final encouragement = await ref.read(
      encouragementForTriggerProvider(trigger.value).future,
    );
    return encouragement;
  }

  /// Get a start encouragement
  Future<Encouragement?> getStartEncouragement() async {
    return getEncouragementForTrigger(EncouragementTrigger.start);
  }

  /// Get an hourly encouragement and update tracking
  Future<Encouragement?> getHourlyEncouragement() async {
    final sessionAsync = ref.read(activeFastSessionProvider);
    if (sessionAsync is! AsyncData<FastSession?> ||
        sessionAsync.value == null) {
      return null;
    }

    final session = sessionAsync.value!;

    if (!shouldShowHourlyEncouragement(session)) {
      return null;
    }

    final encouragement = await getEncouragementForTrigger(
      EncouragementTrigger.hourly,
    );

    if (encouragement != null) {
      _lastHourlyCheck = DateTime.now();
    }

    return encouragement;
  }

  /// Get a milestone encouragement and update tracking
  Future<Encouragement?> getMilestoneEncouragement() async {
    final sessionAsync = ref.read(activeFastSessionProvider);
    if (sessionAsync is! AsyncData<FastSession?> ||
        sessionAsync.value == null) {
      return null;
    }

    final session = sessionAsync.value!;

    if (!shouldShowMilestoneEncouragement(session)) {
      return null;
    }

    final encouragement = await getEncouragementForTrigger(
      EncouragementTrigger.milestone,
    );

    // Update tracking regardless of whether encouragement was found
    // to prevent showing the same milestone multiple times
    final progress = _calculateProgress(session);
    _lastMilestonePercentage = (progress * 100).round();

    return encouragement;
  }

  /// Get a difficulty encouragement (when user needs support)
  Future<Encouragement?> getDifficultyEncouragement() async {
    return getEncouragementForTrigger(EncouragementTrigger.difficulty);
  }

  /// Get a completion encouragement
  Future<Encouragement?> getCompletionEncouragement() async {
    return getEncouragementForTrigger(EncouragementTrigger.completion);
  }

  /// Mark an encouragement as shown to avoid repetition
  Future<void> markEncouragementShown(
    String sessionId,
    String encouragementId,
  ) async {
    final tracker = ref.read(encouragementTrackerProvider.notifier);
    await tracker.markShown(sessionId, encouragementId);
  }

  /// Reset encouragement tracking (e.g., when starting a new fast)
  void resetTracking() {
    _lastHourlyCheck = null;
    _lastMilestonePercentage = null;
    final tracker = ref.read(encouragementTrackerProvider.notifier);
    tracker.reset();
  }

  /// Check if any encouragements should be shown based on current state
  Future<Encouragement?> checkForAutoEncouragement() async {
    final sessionAsync = ref.read(activeFastSessionProvider);
    if (sessionAsync is! AsyncData<FastSession?> ||
        sessionAsync.value == null) {
      return null;
    }

    final session = sessionAsync.value!;

    // Check milestone first (more significant)
    if (shouldShowMilestoneEncouragement(session)) {
      return getMilestoneEncouragement();
    }

    // Then check hourly
    if (shouldShowHourlyEncouragement(session)) {
      return getHourlyEncouragement();
    }

    return null;
  }

  /// Get the current milestone percentage (25, 50, 75, or null)
  int? getCurrentMilestone(FastSession session) {
    final progress = _calculateProgress(session);
    final percentage = (progress * 100).round();

    if (percentage >= 75) return 75;
    if (percentage >= 50) return 50;
    if (percentage >= 25) return 25;
    return null;
  }

  /// Calculate progress as a value between 0.0 and 1.0
  double _calculateProgress(FastSession session) {
    final now = DateTime.now();
    final elapsed = now.difference(session.startTime);
    final target = Duration(minutes: session.targetDurationMinutes);

    if (target.inSeconds == 0) return 1.0;

    final progress = elapsed.inSeconds / target.inSeconds;
    return progress.clamp(0.0, 1.0);
  }
}

/// Provider for encouragement service
final encouragementServiceProvider = Provider<EncouragementService>((ref) {
  final repository = ref.watch(fastingRepositoryProvider);
  return EncouragementService(ref, repository);
});
