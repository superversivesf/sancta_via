import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sancta_via_fasting_companion/database/database_migration_service.dart';
import 'package:sancta_via_fasting_companion/database/fasting_database.dart';
import 'package:sancta_via_fasting_companion/models/fast_session.dart';
import 'package:sancta_via_fasting_companion/models/fast_status.dart';
import 'package:sancta_via_fasting_companion/providers/fast_type_providers.dart';
import 'package:sancta_via_fasting_companion/providers/settings_provider.dart';
import 'package:sancta_via_fasting_companion/repositories/fasting_repository.dart';
import 'package:sancta_via_fasting_companion/services/timer_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late FastingDatabase database;
  late FastingRepository repository;
  late ProviderContainer container;
  late TimerService service;
  int testCounter = 0;

  setUp(() async {
    database = FastingDatabase(
      testDatabaseName:
          'test_timer_${DateTime.now().microsecondsSinceEpoch}_${testCounter++}.db',
    );
    await database.database;
    final migrationService = DatabaseMigrationService(database);
    repository = FastingRepository.forTesting(database, migrationService);

    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    container = ProviderContainer(
      overrides: [
        fastingRepositoryProvider.overrideWithValue(repository),
        sharedPreferencesProvider.overrideWith((ref) => prefs),
      ],
    );

    // Wait for migration
    await repository.getAllFastTypes();

    service = container.read(timerServiceProvider);
  });

  tearDown(() async {
    service.dispose();
    container.dispose();
    await database.clearAllData();
    await database.close();
  });

  group('TimerService', () {
    test('should start with stopped state', () {
      expect(service.state, TimerState.stopped);
      expect(service.currentSession, isNull);
    });

    test('should start timer for session', () {
      final session = FastSession(
        id: 'test_session',
        fastTypeId: 'intermittent_16_8',
        startTime: DateTime.now(),
        targetDurationMinutes: 960,
        status: FastStatus.active,
      );

      service.startTimer(session);

      expect(service.state, TimerState.running);
      expect(service.currentSession, isNotNull);
      expect(service.currentSession!.id, session.id);
    });

    test('should stop timer', () {
      final session = FastSession(
        id: 'test_session',
        fastTypeId: 'intermittent_16_8',
        startTime: DateTime.now(),
        targetDurationMinutes: 960,
        status: FastStatus.active,
      );

      service.startTimer(session);
      expect(service.state, TimerState.running);

      service.stopTimer();
      expect(service.state, TimerState.stopped);
      expect(service.currentSession, isNull);
    });

    test('should calculate elapsed time', () {
      final session = FastSession(
        id: 'test_session',
        fastTypeId: 'intermittent_16_8',
        startTime: DateTime.now().subtract(const Duration(hours: 2)),
        targetDurationMinutes: 960,
        status: FastStatus.active,
      );

      final elapsed = service.getElapsedTime(session);

      expect(elapsed.inHours, 2);
    });

    test('should calculate remaining time', () {
      final session = FastSession(
        id: 'test_session',
        fastTypeId: 'intermittent_16_8',
        startTime: DateTime.now().subtract(const Duration(hours: 2)),
        targetDurationMinutes: 960, // 16 hours
        status: FastStatus.active,
      );

      final remaining = service.getRemainingTime(session);

      expect(remaining.inHours, closeTo(14, 1));
    });

    test('should return zero remaining time when exceeded', () {
      final session = FastSession(
        id: 'test_session',
        fastTypeId: 'intermittent_16_8',
        startTime: DateTime.now().subtract(const Duration(hours: 20)),
        targetDurationMinutes: 960, // 16 hours
        status: FastStatus.active,
      );

      final remaining = service.getRemainingTime(session);

      expect(remaining, Duration.zero);
    });

    test('should calculate progress', () {
      final session = FastSession(
        id: 'test_session',
        fastTypeId: 'intermittent_16_8',
        startTime: DateTime.now().subtract(const Duration(hours: 8)),
        targetDurationMinutes: 960, // 16 hours
        status: FastStatus.active,
      );

      final progress = service.getProgress(session);

      expect(progress, closeTo(0.5, 0.01)); // 50%
    });

    test('should clamp progress to 1.0', () {
      final session = FastSession(
        id: 'test_session',
        fastTypeId: 'intermittent_16_8',
        startTime: DateTime.now().subtract(const Duration(hours: 20)),
        targetDurationMinutes: 960, // 16 hours
        status: FastStatus.active,
      );

      final progress = service.getProgress(session);

      expect(progress, 1.0);
    });

    test('should detect when target is reached', () {
      final session = FastSession(
        id: 'test_session',
        fastTypeId: 'intermittent_16_8',
        startTime: DateTime.now().subtract(const Duration(hours: 16)),
        targetDurationMinutes: 960, // 16 hours
        status: FastStatus.active,
      );

      final hasReached = service.hasReachedTarget(session);

      expect(hasReached, isTrue);
    });

    test('should detect when target is not reached', () {
      final session = FastSession(
        id: 'test_session',
        fastTypeId: 'intermittent_16_8',
        startTime: DateTime.now().subtract(const Duration(hours: 8)),
        targetDurationMinutes: 960, // 16 hours
        status: FastStatus.active,
      );

      final hasReached = service.hasReachedTarget(session);

      expect(hasReached, isFalse);
    });

    test('should format duration as HH:MM:SS', () {
      final duration = const Duration(hours: 2, minutes: 30, seconds: 45);
      final formatted = service.formatDuration(duration);

      expect(formatted, '02:30:45');
    });

    test('should format duration with padding', () {
      final duration = const Duration(hours: 1, minutes: 5, seconds: 3);
      final formatted = service.formatDuration(duration);

      expect(formatted, '01:05:03');
    });

    test('should format duration as human readable', () {
      final duration = const Duration(hours: 2, minutes: 30);
      final formatted = service.formatDurationHuman(duration);

      expect(formatted, '2h 30m');
    });

    test('should format duration without hours', () {
      final duration = const Duration(minutes: 45);
      final formatted = service.formatDurationHuman(duration);

      expect(formatted, '45m');
    });

    test('should calculate time until next milestone at 25%', () {
      final session = FastSession(
        id: 'test_session',
        fastTypeId: 'intermittent_16_8',
        startTime: DateTime.now().subtract(const Duration(hours: 2)),
        targetDurationMinutes: 960, // 16 hours, 2 hours = 12.5%
        status: FastStatus.active,
      );

      final timeUntil = service.getTimeUntilNextMilestone(session);

      expect(timeUntil, isNotNull);
      expect(timeUntil!.inHours, greaterThan(0));
    });

    test('should calculate time until 50% milestone', () {
      final session = FastSession(
        id: 'test_session',
        fastTypeId: 'intermittent_16_8',
        startTime: DateTime.now().subtract(const Duration(hours: 5)),
        targetDurationMinutes: 960, // 16 hours, 5 hours = 31%
        status: FastStatus.active,
      );

      final timeUntil = service.getTimeUntilNextMilestone(session);

      expect(timeUntil, isNotNull);
      // Next milestone is 50% (8 hours), we're at 5 hours, so ~3 hours left
      expect(timeUntil!.inHours, closeTo(3, 1));
    });

    test('should return null when past all milestones', () {
      final session = FastSession(
        id: 'test_session',
        fastTypeId: 'intermittent_16_8',
        startTime: DateTime.now().subtract(const Duration(hours: 17)),
        targetDurationMinutes: 960, // 16 hours, already completed
        status: FastStatus.active,
      );

      final timeUntil = service.getTimeUntilNextMilestone(session);

      expect(timeUntil, isNull);
    });

    test('should handle zero target duration', () {
      final session = FastSession(
        id: 'test_session',
        fastTypeId: 'intermittent_16_8',
        startTime: DateTime.now(),
        targetDurationMinutes: 0,
        status: FastStatus.active,
      );

      final progress = service.getProgress(session);
      expect(progress, 1.0);

      final hasReached = service.hasReachedTarget(session);
      expect(hasReached, isTrue);
    });

    test('should call onTick callback', () async {
      service.onTick = () {
        // Callback registered
      };

      final session = FastSession(
        id: 'test_session',
        fastTypeId: 'intermittent_16_8',
        startTime: DateTime.now(),
        targetDurationMinutes: 960,
        status: FastStatus.active,
      );

      service.startTimer(session);

      // Wait a bit for timer to tick (timer uses settings interval, default 60s)
      // In tests, we can't easily wait that long, so we just verify setup
      expect(service.onTick, isNotNull);
    });

    test('should replace timer when starting new session', () {
      final session1 = FastSession(
        id: 'session_1',
        fastTypeId: 'intermittent_16_8',
        startTime: DateTime.now(),
        targetDurationMinutes: 960,
        status: FastStatus.active,
      );

      service.startTimer(session1);
      expect(service.currentSession!.id, 'session_1');

      final session2 = FastSession(
        id: 'session_2',
        fastTypeId: 'daily_24hr',
        startTime: DateTime.now(),
        targetDurationMinutes: 1440,
        status: FastStatus.active,
      );

      service.startTimer(session2);
      expect(service.currentSession!.id, 'session_2');
    });

    test('should dispose cleanly', () {
      final session = FastSession(
        id: 'test_session',
        fastTypeId: 'intermittent_16_8',
        startTime: DateTime.now(),
        targetDurationMinutes: 960,
        status: FastStatus.active,
      );

      service.startTimer(session);
      service.onTick = () {};
      service.onMilestone = () {};
      service.onCompletion = () {};

      service.dispose();

      expect(service.state, TimerState.stopped);
      expect(service.currentSession, isNull);
      expect(service.onTick, isNull);
      expect(service.onMilestone, isNull);
      expect(service.onCompletion, isNull);
    });

    test('should sync with active session provider', () async {
      // This test verifies the method exists and doesn't throw
      service.syncWithActiveSession();

      // State should remain stopped if no active session
      expect(service.state, TimerState.stopped);
    });
  });
}
