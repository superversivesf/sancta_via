import 'dart:math';

import '../database/database_migration_service.dart';
import '../database/fasting_database.dart';
import '../models/encouragement.dart';
import '../models/fast_session.dart';
import '../models/fast_status.dart';
import '../models/fast_type.dart';
import '../models/fast_type_category.dart';

/// Repository for fasting data - single source of truth
///
/// Manages all data access for the fasting app, providing:
/// - Cached access to fast types and encouragements
/// - Fast session lifecycle management
/// - Statistics and history queries
/// - Automatic database migration on first run
class FastingRepository {
  // Singleton pattern
  static final FastingRepository _instance = FastingRepository._internal();
  static FastingRepository get instance => _instance;

  final FastingDatabase _database;
  final DatabaseMigrationService _migrationService;

  // Cached data
  List<FastType>? _cachedFastTypes;
  List<Encouragement>? _cachedEncouragements;
  bool _migrationChecked = false;

  FastingRepository._internal()
      : _database = FastingDatabase(),
        _migrationService = DatabaseMigrationService(FastingDatabase());

  /// Constructor for testing with dependency injection
  FastingRepository.forTesting(
    FastingDatabase database,
    DatabaseMigrationService migrationService,
  )   : _database = database,
        _migrationService = migrationService;

  /// Ensure migration has been performed
  Future<void> _ensureMigration() async {
    if (_migrationChecked) return;

    final needsMigration = await _migrationService.isMigrationNeeded();
    if (needsMigration) {
      await _migrationService.performMigration();
    }
    _migrationChecked = true;
  }

  // ==================== Fast Types ====================

  /// Get all fast types (cached)
  Future<List<FastType>> getAllFastTypes() async {
    await _ensureMigration();

    if (_cachedFastTypes != null) return _cachedFastTypes!;

    _cachedFastTypes = await _database.getAllFastTypes();
    return _cachedFastTypes!;
  }

  /// Get fast types by category (cached)
  Future<List<FastType>> getFastTypesByCategory(
    FastTypeCategory category,
  ) async {
    final allTypes = await getAllFastTypes();
    return allTypes.where((type) => type.category == category).toList();
  }

  /// Get fast type by ID (cached)
  Future<FastType?> getFastTypeById(String id) async {
    final allTypes = await getAllFastTypes();
    try {
      return allTypes.firstWhere((type) => type.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Add custom fast type
  Future<void> addFastType(FastType fastType) async {
    await _ensureMigration();
    await _database.insertFastType(fastType);
    _cachedFastTypes = null; // Invalidate cache
  }

  /// Delete fast type
  Future<void> deleteFastType(String id) async {
    await _database.deleteFastType(id);
    _cachedFastTypes = null; // Invalidate cache
  }

  // ==================== Encouragements ====================

  /// Get all encouragements (cached)
  Future<List<Encouragement>> getAllEncouragements() async {
    await _ensureMigration();

    if (_cachedEncouragements != null) return _cachedEncouragements!;

    _cachedEncouragements = await _database.getAllEncouragements();
    return _cachedEncouragements!;
  }

  /// Get encouragement for current context
  ///
  /// Filters by trigger point and liturgical season, excluding
  /// encouragements already shown in this session.
  Future<Encouragement?> getEncouragementForContext({
    required String triggerPoint,
    String? liturgicalSeason,
    String? sessionId,
  }) async {
    await _ensureMigration();

    // Get appropriate encouragements
    final encouragements =
        await _database.getEncouragementsByTriggerAndSeason(
      triggerPoint,
      liturgicalSeason,
    );

    if (encouragements.isEmpty) return null;

    // Filter out already shown encouragements if session provided
    List<Encouragement> availableEncouragements = encouragements;
    if (sessionId != null) {
      final shownIds = await _database.getShownEncouragementIds(sessionId);
      availableEncouragements = encouragements
          .where((enc) => !shownIds.contains(enc.id))
          .toList();
    }

    // If all have been shown, allow repeats
    if (availableEncouragements.isEmpty) {
      availableEncouragements = encouragements;
    }

    // Return random encouragement from available pool
    final random = Random();
    return availableEncouragements[
        random.nextInt(availableEncouragements.length)];
  }

  /// Mark encouragement as shown for a session
  Future<void> markEncouragementShown(
    String sessionId,
    String encouragementId,
  ) async {
    await _database.recordEncouragementShown(sessionId, encouragementId);
  }

  /// Add custom encouragement
  Future<void> addEncouragement(Encouragement encouragement) async {
    await _ensureMigration();
    await _database.insertEncouragement(encouragement);
    _cachedEncouragements = null; // Invalidate cache
  }

  // ==================== Fast Sessions ====================

  /// Get currently active fast session
  Future<FastSession?> getActiveFastSession() async {
    await _ensureMigration();
    return await _database.getActiveFastSession();
  }

  /// Start a new fast
  Future<FastSession> startFast({
    required String fastTypeId,
    required int targetDurationMinutes,
    String? notes,
  }) async {
    await _ensureMigration();

    // Check for existing active session
    final existing = await getActiveFastSession();
    if (existing != null) {
      throw StateError('Cannot start new fast: active session already exists');
    }

    // Create new session
    final session = FastSession(
      id: 'session_${DateTime.now().millisecondsSinceEpoch}',
      fastTypeId: fastTypeId,
      startTime: DateTime.now(),
      targetDurationMinutes: targetDurationMinutes,
      status: FastStatus.active,
      notes: notes,
    );

    await _database.insertFastSession(session);
    return session;
  }

  /// Update fast session
  Future<void> updateFastSession(FastSession session) async {
    await _database.updateFastSession(session);
  }

  /// Complete the current fast
  Future<FastSession> completeFast({String? notes}) async {
    final active = await getActiveFastSession();
    if (active == null) {
      throw StateError('No active fast session to complete');
    }

    final completed = active.copyWith(
      status: FastStatus.completed,
      endTime: DateTime.now(),
      notes: notes ?? active.notes,
    );

    await _database.updateFastSession(completed);
    return completed;
  }

  /// Break/cancel the current fast
  Future<FastSession> breakFast({String? notes}) async {
    final active = await getActiveFastSession();
    if (active == null) {
      throw StateError('No active fast session to break');
    }

    final broken = active.copyWith(
      status: FastStatus.broken,
      endTime: DateTime.now(),
      notes: notes ?? active.notes,
    );

    await _database.updateFastSession(broken);
    return broken;
  }

  /// Get fast session by ID
  Future<FastSession?> getFastSessionById(String id) async {
    await _ensureMigration();
    return await _database.getFastSessionById(id);
  }

  /// Get fast session history
  Future<List<FastSession>> getFastHistory({
    int? limit,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    await _ensureMigration();
    return await _database.getFastSessions(
      limit: limit,
      startDate: startDate,
      endDate: endDate,
    );
  }

  /// Delete a fast session
  Future<void> deleteFastSession(String id) async {
    await _database.deleteFastSession(id);
  }

  // ==================== Statistics ====================

  /// Get total number of completed fasts
  Future<int> getCompletedFastsCount() async {
    await _ensureMigration();
    return await _database.getCompletedFastsCount();
  }

  /// Get total hours fasted (completed fasts only)
  Future<double> getTotalHoursFasted() async {
    await _ensureMigration();
    final sessions = await _database.getFastSessions();
    final completed =
        sessions.where((s) => s.status == FastStatus.completed);

    double totalMinutes = 0;
    for (final session in completed) {
      totalMinutes += session.elapsedMinutes.toDouble();
    }

    return totalMinutes / 60.0;
  }

  /// Get average fast duration in hours
  Future<double> getAverageFastDuration() async {
    await _ensureMigration();
    final sessions = await _database.getFastSessions();
    final completed =
        sessions.where((s) => s.status == FastStatus.completed).toList();

    if (completed.isEmpty) return 0.0;

    double totalMinutes = 0;
    for (final session in completed) {
      totalMinutes += session.elapsedMinutes.toDouble();
    }

    return (totalMinutes / completed.length) / 60.0;
  }

  /// Get current streak (consecutive days with completed fasts)
  Future<int> getCurrentStreak() async {
    await _ensureMigration();
    final sessions = await _database.getFastSessions();
    final completed = sessions
        .where((s) => s.status == FastStatus.completed)
        .toList()
      ..sort((a, b) => b.startTime.compareTo(a.startTime));

    if (completed.isEmpty) return 0;

    int streak = 0;
    DateTime currentDate = DateTime.now();

    for (final session in completed) {
      final sessionDate = DateTime(
        session.startTime.year,
        session.startTime.month,
        session.startTime.day,
      );
      final checkDate = DateTime(
        currentDate.year,
        currentDate.month,
        currentDate.day,
      );

      final difference = checkDate.difference(sessionDate).inDays;

      if (difference == streak) {
        streak++;
      } else if (difference > streak) {
        break;
      }
    }

    return streak;
  }

  /// Get longest streak
  Future<int> getLongestStreak() async {
    await _ensureMigration();
    final sessions = await _database.getFastSessions();
    final completed = sessions
        .where((s) => s.status == FastStatus.completed)
        .toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));

    if (completed.isEmpty) return 0;

    int longestStreak = 0;
    int currentStreak = 1;
    DateTime? lastDate;

    for (final session in completed) {
      final sessionDate = DateTime(
        session.startTime.year,
        session.startTime.month,
        session.startTime.day,
      );

      if (lastDate != null) {
        final difference = sessionDate.difference(lastDate).inDays;
        if (difference == 1) {
          currentStreak++;
        } else {
          longestStreak = max(longestStreak, currentStreak);
          currentStreak = 1;
        }
      }

      lastDate = sessionDate;
    }

    return max(longestStreak, currentStreak);
  }

  /// Get completion rate (completed / (completed + broken))
  Future<double> getCompletionRate() async {
    await _ensureMigration();
    final sessions = await _database.getFastSessions();
    final completed =
        sessions.where((s) => s.status == FastStatus.completed).length;
    final broken = sessions.where((s) => s.status == FastStatus.broken).length;

    final total = completed + broken;
    if (total == 0) return 0.0;

    return completed / total;
  }

  /// Get most common fast type
  Future<FastType?> getMostCommonFastType() async {
    await _ensureMigration();
    final sessions = await _database.getFastSessions();
    final completed =
        sessions.where((s) => s.status == FastStatus.completed);

    if (completed.isEmpty) return null;

    // Count occurrences of each fast type
    final Map<String, int> typeCounts = {};
    for (final session in completed) {
      typeCounts[session.fastTypeId] =
          (typeCounts[session.fastTypeId] ?? 0) + 1;
    }

    // Find most common
    String? mostCommonId;
    int maxCount = 0;
    typeCounts.forEach((typeId, count) {
      if (count > maxCount) {
        maxCount = count;
        mostCommonId = typeId;
      }
    });

    if (mostCommonId == null) return null;
    return await getFastTypeById(mostCommonId!);
  }

  // ==================== Utility Methods ====================

  /// Force re-migration (for development/testing)
  Future<void> forceMigration() async {
    await _migrationService.forceMigration();
    _cachedFastTypes = null;
    _cachedEncouragements = null;
    _migrationChecked = true;
  }

  /// Clear all cached data
  void clearCache() {
    _cachedFastTypes = null;
    _cachedEncouragements = null;
  }

  /// Close database connection
  Future<void> close() async {
    await _database.close();
  }
}
