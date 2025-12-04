import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/fast_session.dart';
import '../repositories/fasting_repository.dart';
import '../services/notification_service.dart';
import '../utils/app_logger.dart';
import 'achievement_providers.dart';
import 'fast_type_providers.dart';
import 'statistics_providers.dart';

/// Provider for the active fast session
final activeFastSessionProvider =
    StateNotifierProvider<ActiveFastSessionNotifier, AsyncValue<FastSession?>>(
  (ref) {
    return ActiveFastSessionNotifier(
      ref,
      ref.watch(fastingRepositoryProvider),
      ref.watch(notificationServiceProvider),
    );
  },
);

/// Notifier for managing the active fast session
class ActiveFastSessionNotifier
    extends StateNotifier<AsyncValue<FastSession?>> {
  final Ref ref;
  final FastingRepository fastingRepository;
  final NotificationService notificationService;
  Timer? _timer;

  ActiveFastSessionNotifier(
    this.ref,
    this.fastingRepository,
    this.notificationService,
  ) : super(const AsyncValue.loading()) {
    _initializeNotifications();
    _loadActiveFast();
  }

  /// Initialize notification service
  Future<void> _initializeNotifications() async {
    try {
      await notificationService.initialize();
      AppLogger.info('Notifications initialized', 'ActiveFastSessionNotifier');
    } catch (e, stack) {
      AppLogger.error(
        'Failed to initialize notifications',
        e,
        stack,
        'ActiveFastSessionNotifier',
      );
    }
  }

  /// Load the active fast session
  Future<void> _loadActiveFast() async {
    if (!mounted) return;
    state = const AsyncValue.loading();
    try {
      final session = await fastingRepository.getActiveFastSession();
      if (!mounted) return;
      state = AsyncValue.data(session);

      // Start timer if there's an active session
      if (session != null) {
        _startTimer();
      }
    } catch (e, stack) {
      if (!mounted) return;
      state = AsyncValue.error(e, stack);
    }
  }

  /// Start a new fast
  /// Returns a message if there are notification permission issues
  Future<String?> startFast({
    required String fastTypeId,
    required int targetDurationMinutes,
    String? notes,
  }) async {
    try {
      final session = await fastingRepository.startFast(
        fastTypeId: fastTypeId,
        targetDurationMinutes: targetDurationMinutes,
        notes: notes,
      );
      state = AsyncValue.data(session);
      _startTimer();

      // Schedule notifications and check for permission issues
      try {
        final result = await notificationService.scheduleNotificationsForFast(session);

        if (result.success) {
          AppLogger.info(
            'Notifications scheduled for fast: ${session.id}',
            'ActiveFastSessionNotifier',
          );
          return null; // No issues
        } else {
          // Log the issue but don't fail the fast start
          AppLogger.warning(
            'Notification scheduling issue: ${result.errorMessage}',
            'ActiveFastSessionNotifier',
          );

          // Return a user-friendly message based on the issue
          if (result.needsExactAlarmPermission) {
            return 'Your fast has started, but exact alarm permission is needed for timely notifications. You can enable it in Settings > Notifications.';
          } else if (result.needsNotificationPermission) {
            return 'Your fast has started, but notification permissions are needed for reminders. You can enable them in Settings > Notifications.';
          } else {
            return 'Your fast has started, but there was an issue scheduling notifications.';
          }
        }
      } catch (e, stack) {
        AppLogger.error(
          'Failed to schedule notifications',
          e,
          stack,
          'ActiveFastSessionNotifier',
        );
        // Don't fail the fast start if notifications fail
        return 'Your fast has started, but notifications could not be scheduled.';
      }
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  /// Complete the current fast
  Future<FastSession> completeFast({String? notes}) async {
    try {
      final currentSession = state.value;
      final completed = await fastingRepository.completeFast(notes: notes);
      state = AsyncValue.data(null);
      _stopTimer();

      // Cancel notifications for this fast
      if (currentSession != null) {
        try {
          await notificationService.cancelNotificationsForFast(currentSession.id);
          AppLogger.info(
            'Notifications cancelled for completed fast: ${currentSession.id}',
            'ActiveFastSessionNotifier',
          );
        } catch (e, stack) {
          AppLogger.error(
            'Failed to cancel notifications',
            e,
            stack,
            'ActiveFastSessionNotifier',
          );
        }
      }

      // Invalidate statistics providers to reflect the new completed fast
      ref.invalidate(dashboardStatisticsProvider);
      ref.invalidate(fastHistoryProvider);
      AppLogger.info(
        'Statistics providers invalidated after completing fast',
        'ActiveFastSessionNotifier',
      );

      // Check for new achievements
      try {
        final achievementService = ref.read(achievementServiceProvider);
        final newAchievements = await achievementService.checkNewAchievements(completed);
        if (newAchievements.isNotEmpty) {
          AppLogger.info(
            'Earned ${newAchievements.length} new achievements',
            'ActiveFastSessionNotifier',
          );
          // Invalidate achievement providers
          ref.invalidate(earnedAchievementsProvider);
          ref.invalidate(unseenAchievementCountProvider);
          ref.invalidate(totalAchievementPointsProvider);
        }
      } catch (e, stack) {
        AppLogger.error(
          'Failed to check achievements',
          e,
          stack,
          'ActiveFastSessionNotifier',
        );
        // Don't fail the fast completion if achievement check fails
      }

      // Return the completed session for display
      return completed;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  /// Break the current fast
  Future<FastSession> breakFast({String? notes}) async {
    try {
      final currentSession = state.value;
      final broken = await fastingRepository.breakFast(notes: notes);
      state = AsyncValue.data(null);
      _stopTimer();

      // Cancel notifications for this fast
      if (currentSession != null) {
        try {
          await notificationService.cancelNotificationsForFast(currentSession.id);
          AppLogger.info(
            'Notifications cancelled for broken fast: ${currentSession.id}',
            'ActiveFastSessionNotifier',
          );
        } catch (e, stack) {
          AppLogger.error(
            'Failed to cancel notifications',
            e,
            stack,
            'ActiveFastSessionNotifier',
          );
        }
      }

      // Invalidate statistics providers to reflect the broken fast
      ref.invalidate(dashboardStatisticsProvider);
      ref.invalidate(fastHistoryProvider);
      AppLogger.info(
        'Statistics providers invalidated after breaking fast',
        'ActiveFastSessionNotifier',
      );

      return broken;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  /// Update the current session (e.g., add notes)
  Future<void> updateSession(FastSession session) async {
    try {
      await fastingRepository.updateFastSession(session);
      state = AsyncValue.data(session);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  /// Refresh the active fast session (force reload from database)
  Future<void> refresh() async {
    await _loadActiveFast();
  }

  /// Start timer to update elapsed time every minute
  void _startTimer() {
    _stopTimer(); // Clear any existing timer
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (!mounted) return;
      final currentState = state;
      if (currentState is AsyncData<FastSession?> &&
          currentState.value != null) {
        // Trigger a rebuild by creating a new AsyncData with the same session
        // This will cause widgets to recalculate elapsed time
        state = AsyncValue.data(currentState.value);
      }
    });
  }

  /// Stop the timer
  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  void dispose() {
    _stopTimer();
    super.dispose();
  }
}

/// Provider for whether there is an active fast
final hasActiveFastProvider = Provider<bool>((ref) {
  final sessionAsync = ref.watch(activeFastSessionProvider);
  return sessionAsync.maybeWhen(
    data: (session) => session != null,
    orElse: () => false,
  );
});

/// Provider for the current elapsed time (updates every minute)
final currentElapsedTimeProvider = Provider<Duration?>((ref) {
  final sessionAsync = ref.watch(activeFastSessionProvider);
  return sessionAsync.maybeWhen(
    data: (session) => session?.elapsedDuration,
    orElse: () => null,
  );
});

/// Provider for the current progress percentage
final currentProgressProvider = Provider<double>((ref) {
  final sessionAsync = ref.watch(activeFastSessionProvider);
  return sessionAsync.maybeWhen(
    data: (session) => session?.progressPercentage ?? 0.0,
    orElse: () => 0.0,
  );
});

/// Provider for the remaining time
final remainingTimeProvider = Provider<Duration?>((ref) {
  final sessionAsync = ref.watch(activeFastSessionProvider);
  return sessionAsync.maybeWhen(
    data: (session) => session?.remainingDuration,
    orElse: () => null,
  );
});

/// Provider for whether the target has been reached
final hasReachedTargetProvider = Provider<bool>((ref) {
  final sessionAsync = ref.watch(activeFastSessionProvider);
  return sessionAsync.maybeWhen(
    data: (session) => session?.hasReachedTarget ?? false,
    orElse: () => false,
  );
});

/// Provider for fast session history
final fastHistoryProvider = FutureProvider<List<FastSession>>((ref) async {
  final repository = ref.watch(fastingRepositoryProvider);
  return repository.getFastHistory(limit: 50);
});

/// Provider for fast session history filtered by date range
final fastHistoryByDateProvider = FutureProvider.family<List<FastSession>,
    ({DateTime? startDate, DateTime? endDate})>(
  (ref, params) async {
    final repository = ref.watch(fastingRepositoryProvider);
    return repository.getFastHistory(
      startDate: params.startDate,
      endDate: params.endDate,
    );
  },
);
