import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/fast_session.dart';
import '../providers/fast_session_providers.dart';
import '../providers/settings_provider.dart';

/// Timer state for a fast session
enum TimerState {
  running,
  stopped,
}

/// Service for managing timer functionality
class TimerService {
  final Ref ref;
  Timer? _timer;
  TimerState _state = TimerState.stopped;
  FastSession? _currentSession;

  // Callbacks for timer events
  void Function()? onTick;
  void Function()? onMilestone;
  void Function()? onCompletion;

  TimerService(this.ref);

  /// Current timer state
  TimerState get state => _state;

  /// Current session being timed
  FastSession? get currentSession => _currentSession;

  /// Start the timer for an active session
  void startTimer(FastSession session) {
    // Stop any existing timer
    stopTimer();

    _currentSession = session;
    _state = TimerState.running;

    // Get timer update interval from settings
    final settings = ref.read(fastingSettingsProvider);
    final intervalSeconds = settings.timerUpdateInterval;

    // Start periodic timer
    _timer = Timer.periodic(
      Duration(seconds: intervalSeconds),
      (_) => _handleTick(),
    );
  }

  /// Stop the timer
  void stopTimer() {
    _timer?.cancel();
    _timer = null;
    _state = TimerState.stopped;
    _currentSession = null;
  }

  /// Handle timer tick
  void _handleTick() {
    if (_currentSession == null || _state != TimerState.running) {
      return;
    }

    // Trigger tick callback
    onTick?.call();

    // Check if we've reached a milestone
    if (_shouldTriggerMilestone()) {
      onMilestone?.call();
    }

    // Check if we've completed the fast
    if (_shouldTriggerCompletion()) {
      onCompletion?.call();
    }
  }

  /// Check if a milestone should be triggered
  bool _shouldTriggerMilestone() {
    if (_currentSession == null) return false;

    final elapsed = getElapsedTime(_currentSession!);
    final target = Duration(minutes: _currentSession!.targetDurationMinutes);

    // Check for 25%, 50%, 75% milestones
    final progress = elapsed.inSeconds / target.inSeconds;
    final percentage = (progress * 100).round();

    // Trigger on exact milestone percentages
    return percentage == 25 || percentage == 50 || percentage == 75;
  }

  /// Check if completion should be triggered
  bool _shouldTriggerCompletion() {
    if (_currentSession == null) return false;

    final elapsed = getElapsedTime(_currentSession!);
    final target = Duration(minutes: _currentSession!.targetDurationMinutes);

    return elapsed >= target;
  }

  /// Get elapsed time for a session
  Duration getElapsedTime(FastSession session) {
    final now = DateTime.now();
    return now.difference(session.startTime);
  }

  /// Get remaining time for a session
  Duration getRemainingTime(FastSession session) {
    final elapsed = getElapsedTime(session);
    final target = Duration(minutes: session.targetDurationMinutes);
    final remaining = target - elapsed;

    return remaining.isNegative ? Duration.zero : remaining;
  }

  /// Get progress as a value between 0.0 and 1.0
  double getProgress(FastSession session) {
    final elapsed = getElapsedTime(session);
    final target = Duration(minutes: session.targetDurationMinutes);

    if (target.inSeconds == 0) return 1.0;

    final progress = elapsed.inSeconds / target.inSeconds;
    return progress.clamp(0.0, 1.0);
  }

  /// Check if target has been reached
  bool hasReachedTarget(FastSession session) {
    final elapsed = getElapsedTime(session);
    final target = Duration(minutes: session.targetDurationMinutes);
    return elapsed >= target;
  }

  /// Format duration as HH:MM:SS
  String formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    return '${hours.toString().padLeft(2, '0')}:'
        '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  /// Format duration as human-readable string (e.g., "2h 30m")
  String formatDurationHuman(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }

  /// Get time until next milestone
  Duration? getTimeUntilNextMilestone(FastSession session) {
    final progress = getProgress(session);
    final percentage = (progress * 100).round();

    // Determine next milestone
    int? nextMilestone;
    if (percentage < 25) {
      nextMilestone = 25;
    } else if (percentage < 50) {
      nextMilestone = 50;
    } else if (percentage < 75) {
      nextMilestone = 75;
    } else if (percentage < 100) {
      nextMilestone = 100;
    } else {
      return null; // No more milestones
    }

    // Calculate time to reach that milestone
    final target = Duration(minutes: session.targetDurationMinutes);
    final milestoneTime = session.startTime.add(
      Duration(seconds: (target.inSeconds * nextMilestone / 100).round()),
    );

    final now = DateTime.now();
    final timeUntil = milestoneTime.difference(now);

    return timeUntil.isNegative ? Duration.zero : timeUntil;
  }

  /// Sync timer with active session from provider
  void syncWithActiveSession() {
    final sessionAsync = ref.read(activeFastSessionProvider);

    if (sessionAsync is AsyncData<FastSession?>) {
      final session = sessionAsync.value;

      if (session != null && _state != TimerState.running) {
        // There's an active session but timer isn't running - start it
        startTimer(session);
      } else if (session == null && _state == TimerState.running) {
        // No active session but timer is running - stop it
        stopTimer();
      } else if (session != null && _currentSession?.id != session.id) {
        // Different session - restart timer
        startTimer(session);
      }
    }
  }

  /// Dispose of the timer service
  void dispose() {
    stopTimer();
    onTick = null;
    onMilestone = null;
    onCompletion = null;
  }
}

/// Provider for timer service
final timerServiceProvider = Provider<TimerService>((ref) {
  final service = TimerService(ref);

  // Auto-sync with active session when provider is created
  service.syncWithActiveSession();

  // Clean up when provider is disposed
  ref.onDispose(() {
    service.dispose();
  });

  return service;
});

/// Provider that emits periodic ticks to trigger UI rebuilds
/// This provider emits a new value every second when there's an active fast
final timerTickProvider = StreamProvider<DateTime>((ref) async* {
  final sessionAsync = ref.watch(activeFastSessionProvider);

  // Only emit ticks if there's an active session
  if (sessionAsync is AsyncData<FastSession?> && sessionAsync.value != null) {
    // Emit current time immediately
    yield DateTime.now();

    // Then emit every second
    await for (final _ in Stream.periodic(const Duration(seconds: 1))) {
      // Check if session is still active
      final currentSession = ref.read(activeFastSessionProvider);
      if (currentSession is AsyncData<FastSession?> && currentSession.value != null) {
        yield DateTime.now();
      } else {
        // Session ended, stop emitting
        break;
      }
    }
  }
});
