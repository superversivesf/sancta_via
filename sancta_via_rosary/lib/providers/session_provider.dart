import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../services/rosary_session_service.dart';
import 'rosary_provider.dart';

/// Provider for the RosarySessionService instance
final rosarySessionServiceProvider = Provider<RosarySessionService>((ref) {
  return RosarySessionService.instance;
});

/// Future provider for the current active session
final currentSessionProvider = FutureProvider<RosarySession?>((ref) async {
  final service = ref.watch(rosarySessionServiceProvider);
  return service.getCurrentSession();
});

/// Future provider for session history
final sessionHistoryProvider = FutureProvider<List<RosarySession>>((ref) async {
  final service = ref.watch(rosarySessionServiceProvider);
  return service.getSessionHistory();
});

/// Future provider for completed sessions only
final completedSessionsProvider = FutureProvider<List<RosarySession>>((
  ref,
) async {
  final service = ref.watch(rosarySessionServiceProvider);
  return service.getCompletedSessions();
});

/// Notifier for managing the current session state
class RosarySessionNotifier extends StateNotifier<AsyncValue<RosarySession?>> {
  final RosarySessionService _service;

  RosarySessionNotifier(this._service) : super(const AsyncValue.loading()) {
    _loadCurrentSession();
  }

  Future<void> _loadCurrentSession() async {
    try {
      final session = await _service.getCurrentSession();
      state = AsyncValue.data(session);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  /// Start a new session with the given mystery set
  Future<void> startSession(MysterySet set) async {
    state = const AsyncValue.loading();
    try {
      final session = await _service.startSession(set);
      state = AsyncValue.data(session);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  /// Start a session with today's recommended mystery set
  Future<void> startTodaysSession() async {
    await startSession(MysterySet.forToday());
  }

  /// Complete a mystery in the current session
  Future<void> completeMystery(int number) async {
    final currentSession = state.value;
    if (currentSession == null) return;

    try {
      await _service.completeMystery(number);

      // Reload to get updated state
      final updated = await _service.getCurrentSession();
      state = AsyncValue.data(updated);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  /// Record prayer completion
  Future<void> recordPrayer(PrayerType type) async {
    try {
      await _service.recordPrayerCompletion(type);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  /// Update current position/progress
  Future<void> updateProgress({
    required int position,
    int? mysteryNumber,
    int? hailMary,
  }) async {
    try {
      await _service.updateProgress(
        position: position,
        mysteryNumber: mysteryNumber,
        hailMary: hailMary,
      );
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  /// Finish the current session
  Future<RosarySession?> finishSession() async {
    state = const AsyncValue.loading();
    try {
      final completed = await _service.finishSession();
      state = const AsyncValue.data(null);
      return completed;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      return null;
    }
  }

  /// Abandon the current session
  Future<void> abandonSession() async {
    state = const AsyncValue.loading();
    try {
      await _service.abandonSession();
      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  /// Resume an existing session
  Future<void> resumeSession() async {
    await _loadCurrentSession();
  }

  /// Check if there's an active session
  bool get hasActiveSession => state.value?.isInProgress ?? false;

  /// Get current mystery number from session
  int? get currentMysteryNumber => state.value?.currentMysteryNumber;

  /// Get current Hail Mary count from session
  int? get currentHailMary => state.value?.currentHailMary;

  /// Get session progress percentage
  int get progressPercent => state.value?.progressPercent ?? 0;
}

/// Provider for the session notifier (use this to control sessions)
final rosarySessionNotifierProvider =
    StateNotifierProvider<RosarySessionNotifier, AsyncValue<RosarySession?>>(
      (ref) => RosarySessionNotifier(ref.watch(rosarySessionServiceProvider)),
    );

/// Provider for whether there's an active session
final hasActiveSessionProvider = Provider<bool>((ref) {
  final sessionAsync = ref.watch(rosarySessionNotifierProvider);
  return sessionAsync.value?.isInProgress ?? false;
});

/// Provider for the mystery set of the current session
final sessionMysterySetProvider = Provider<MysterySet?>((ref) {
  final sessionAsync = ref.watch(rosarySessionNotifierProvider);
  return sessionAsync.value?.mysterySet;
});

/// Provider for the current session's mysteries
final sessionMysteriesProvider = Provider<List<Mystery>>((ref) {
  final set = ref.watch(sessionMysterySetProvider);
  if (set == null) return [];
  return ref.watch(mysteriesBySetProvider(set));
});

/// Provider for current session progress
final sessionProgressProvider = Provider<int>((ref) {
  final sessionAsync = ref.watch(rosarySessionNotifierProvider);
  return sessionAsync.value?.progressPercent ?? 0;
});

/// Provider for completed mysteries count in current session
final sessionCompletedCountProvider = Provider<int>((ref) {
  final sessionAsync = ref.watch(rosarySessionNotifierProvider);
  return sessionAsync.value?.completedCount ?? 0;
});

/// Provider for remaining mysteries in current session
final sessionRemainingCountProvider = Provider<int>((ref) {
  final completed = ref.watch(sessionCompletedCountProvider);
  return 5 - completed;
});

/// Notifier for tracking which prayers have been completed in current session
class CompletedPrayersNotifier extends StateNotifier<Set<String>> {
  CompletedPrayersNotifier() : super({});

  void markCompleted(String prayerId) {
    state = {...state, prayerId};
  }

  void markUncompleted(String prayerId) {
    state = state.where((id) => id != prayerId).toSet();
  }

  bool isCompleted(String prayerId) => state.contains(prayerId);

  void markPrayerTypeCompleted(PrayerType type, {int? mysteryNumber}) {
    final id = mysteryNumber != null
        ? '${type.name}_mystery_$mysteryNumber'
        : type.name;
    markCompleted(id);
  }

  void reset() {
    state = {};
  }

  int get count => state.length;
}

/// Provider for tracking completed prayers in current session
final completedPrayersProvider =
    StateNotifierProvider<CompletedPrayersNotifier, Set<String>>(
      (ref) => CompletedPrayersNotifier(),
    );

/// Provider for checking if a specific prayer is completed
final isPrayerCompletedProvider = Provider.family<bool, String>((
  ref,
  prayerId,
) {
  final completed = ref.watch(completedPrayersProvider);
  return completed.contains(prayerId);
});

/// Notifier for session timer
class SessionTimerNotifier extends StateNotifier<Duration> {
  DateTime? _startTime;

  SessionTimerNotifier() : super(Duration.zero);

  void start() {
    _startTime = DateTime.now();
    _update();
  }

  void stop() {
    _startTime = null;
  }

  void reset() {
    _startTime = null;
    state = Duration.zero;
  }

  void _update() {
    if (_startTime != null) {
      state = DateTime.now().difference(_startTime!);
    }
  }

  Duration get elapsed => _startTime != null
      ? DateTime.now().difference(_startTime!)
      : Duration.zero;
}

/// Provider for session timer
final sessionTimerProvider =
    StateNotifierProvider<SessionTimerNotifier, Duration>(
      (ref) => SessionTimerNotifier(),
    );
