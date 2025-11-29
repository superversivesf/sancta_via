import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/fast_session.dart';
import '../repositories/fasting_repository.dart';
import 'fast_type_providers.dart';

/// Provider for the active fast session
final activeFastSessionProvider =
    StateNotifierProvider<ActiveFastSessionNotifier, AsyncValue<FastSession?>>(
  (ref) {
    return ActiveFastSessionNotifier(
      ref.watch(fastingRepositoryProvider),
    );
  },
);

/// Notifier for managing the active fast session
class ActiveFastSessionNotifier
    extends StateNotifier<AsyncValue<FastSession?>> {
  final FastingRepository fastingRepository;
  Timer? _timer;

  ActiveFastSessionNotifier(this.fastingRepository)
      : super(const AsyncValue.loading()) {
    _loadActiveFast();
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
  Future<void> startFast({
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
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  /// Complete the current fast
  Future<FastSession> completeFast({String? notes}) async {
    try {
      final completed = await fastingRepository.completeFast(notes: notes);
      state = AsyncValue.data(null);
      _stopTimer();
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
      final broken = await fastingRepository.breakFast(notes: notes);
      state = AsyncValue.data(null);
      _stopTimer();
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
