import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sancta_via_fasting_companion/database/database_migration_service.dart';
import 'package:sancta_via_fasting_companion/database/fasting_database.dart';
import 'package:sancta_via_fasting_companion/models/fast_status.dart';
import 'package:sancta_via_fasting_companion/providers/fast_session_providers.dart';
import 'package:sancta_via_fasting_companion/providers/fast_type_providers.dart';
import 'package:sancta_via_fasting_companion/repositories/fasting_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late FastingDatabase database;
  late FastingRepository repository;
  late ProviderContainer container;
  int testCounter = 0;

  setUp(() async {
    database = FastingDatabase(
      testDatabaseName:
          'test_session_${DateTime.now().microsecondsSinceEpoch}_${testCounter++}.db',
    );
    await database.database;
    final migrationService = DatabaseMigrationService(database);
    repository = FastingRepository.forTesting(database, migrationService);

    container = ProviderContainer(
      overrides: [
        fastingRepositoryProvider.overrideWithValue(repository),
      ],
    );

    // Wait for migration
    await repository.getAllFastTypes();
  });

  tearDown(() async {
    container.dispose();
    await database.clearAllData();
    await database.close();
  });

  group('Active Fast Session Provider', () {
    test('should initially have no active session', () async {
      final sessionAsync = container.read(activeFastSessionProvider);
      final session = sessionAsync.when(
        data: (data) => data,
        loading: () => null,
        error: (error, stack) => null,
      );

      expect(session, isNull);
    });

    test('should start a new fast', () async {
      final notifier = container.read(activeFastSessionProvider.notifier);

      await notifier.startFast(
        fastTypeId: 'intermittent_16_8',
        targetDurationMinutes: 960,
        notes: 'Test fast',
      );

      final state = container.read(activeFastSessionProvider);
      final session = state.when(
        data: (data) => data,
        loading: () => null,
        error: (error, stack) => null,
      );

      expect(session, isNotNull);
      expect(session!.fastTypeId, 'intermittent_16_8');
      expect(session.targetDurationMinutes, 960);
      expect(session.notes, 'Test fast');
      expect(session.status, FastStatus.active);
    });

    test('should not allow starting fast when one is active', () async {
      final notifier = container.read(activeFastSessionProvider.notifier);

      await notifier.startFast(
        fastTypeId: 'intermittent_16_8',
        targetDurationMinutes: 960,
      );

      expect(
        () => notifier.startFast(
          fastTypeId: 'daily_24hr',
          targetDurationMinutes: 1440,
        ),
        throwsStateError,
      );
    });

    test('should complete an active fast', () async {
      final notifier = container.read(activeFastSessionProvider.notifier);

      await notifier.startFast(
        fastTypeId: 'intermittent_16_8',
        targetDurationMinutes: 960,
      );

      final completed = await notifier.completeFast(notes: 'Completed!');

      expect(completed.status, FastStatus.completed);
      expect(completed.endTime, isNotNull);
      expect(completed.notes, 'Completed!');

      final state = container.read(activeFastSessionProvider);
      final session = state.when(
        data: (data) => data,
        loading: () => null,
        error: (error, stack) => null,
      );
      expect(session, isNull);
    });

    test('should break an active fast', () async {
      final notifier = container.read(activeFastSessionProvider.notifier);

      await notifier.startFast(
        fastTypeId: 'intermittent_16_8',
        targetDurationMinutes: 960,
      );

      final broken = await notifier.breakFast(notes: 'Had to stop');

      expect(broken.status, FastStatus.broken);
      expect(broken.endTime, isNotNull);
      expect(broken.notes, 'Had to stop');

      final state = container.read(activeFastSessionProvider);
      final session = state.when(
        data: (data) => data,
        loading: () => null,
        error: (error, stack) => null,
      );
      expect(session, isNull);
    });

    test('should update session', () async {
      final notifier = container.read(activeFastSessionProvider.notifier);

      await notifier.startFast(
        fastTypeId: 'intermittent_16_8',
        targetDurationMinutes: 960,
      );

      final currentState = container.read(activeFastSessionProvider);
      final currentSession = currentState.when(
        data: (data) => data,
        loading: () => null,
        error: (error, stack) => null,
      );

      final updated = currentSession!.copyWith(notes: 'Updated notes');
      await notifier.updateSession(updated);

      final fetchedState = container.read(activeFastSessionProvider);
      final fetched = fetchedState.when(
        data: (data) => data,
        loading: () => null,
        error: (error, stack) => null,
      );
      expect(fetched!.notes, 'Updated notes');
    });

    test('should refresh session from database', () async {
      final notifier = container.read(activeFastSessionProvider.notifier);

      await notifier.startFast(
        fastTypeId: 'intermittent_16_8',
        targetDurationMinutes: 960,
      );

      await notifier.refresh();

      final state = container.read(activeFastSessionProvider);
      final session = state.when(
        data: (data) => data,
        loading: () => null,
        error: (error, stack) => null,
      );
      expect(session, isNotNull);
    });
  });

  group('Derived Providers', () {
    test('hasActiveFastProvider should reflect active state', () async {
      final notifier = container.read(activeFastSessionProvider.notifier);

      // Initially no active fast
      expect(container.read(hasActiveFastProvider), isFalse);

      // Start a fast
      await notifier.startFast(
        fastTypeId: 'intermittent_16_8',
        targetDurationMinutes: 960,
      );

      expect(container.read(hasActiveFastProvider), isTrue);

      // Complete the fast
      await notifier.completeFast();

      expect(container.read(hasActiveFastProvider), isFalse);
    });

    test('currentElapsedTimeProvider should return elapsed duration', () async {
      final notifier = container.read(activeFastSessionProvider.notifier);

      await notifier.startFast(
        fastTypeId: 'intermittent_16_8',
        targetDurationMinutes: 960,
      );

      final elapsed = container.read(currentElapsedTimeProvider);
      expect(elapsed, isNotNull);
      expect(elapsed!.inSeconds, greaterThanOrEqualTo(0));
    });

    test('currentProgressProvider should calculate progress', () async {
      final notifier = container.read(activeFastSessionProvider.notifier);

      await notifier.startFast(
        fastTypeId: 'intermittent_16_8',
        targetDurationMinutes: 960,
      );

      final progress = container.read(currentProgressProvider);
      expect(progress, greaterThanOrEqualTo(0.0));
      expect(progress, lessThanOrEqualTo(1.0));
    });

    test('remainingTimeProvider should calculate remaining time', () async {
      final notifier = container.read(activeFastSessionProvider.notifier);

      await notifier.startFast(
        fastTypeId: 'intermittent_16_8',
        targetDurationMinutes: 960,
      );

      final remaining = container.read(remainingTimeProvider);
      expect(remaining, isNotNull);
      expect(remaining!.inMinutes, lessThanOrEqualTo(960));
    });

    test('hasReachedTargetProvider should detect target reached', () async {
      final notifier = container.read(activeFastSessionProvider.notifier);

      await notifier.startFast(
        fastTypeId: 'intermittent_16_8',
        targetDurationMinutes: 0, // Immediate target
      );

      final hasReached = container.read(hasReachedTargetProvider);
      expect(hasReached, isTrue);
    });
  });

  group('Fast History Provider', () {
    test('should return past sessions', () async {
      final notifier = container.read(activeFastSessionProvider.notifier);

      // Create and complete a fast
      await notifier.startFast(
        fastTypeId: 'intermittent_16_8',
        targetDurationMinutes: 960,
      );
      await notifier.completeFast();

      final history = await container.read(fastHistoryProvider.future);
      expect(history.length, 1);
      expect(history.first.status, FastStatus.completed);
    });

    test('should filter history by date range', () async {
      final notifier = container.read(activeFastSessionProvider.notifier);

      // Create and complete a fast
      await notifier.startFast(
        fastTypeId: 'intermittent_16_8',
        targetDurationMinutes: 960,
      );
      await notifier.completeFast();

      final now = DateTime.now();
      final history = await container.read(
        fastHistoryByDateProvider((
          startDate: now.subtract(const Duration(days: 1)),
          endDate: now.add(const Duration(days: 1)),
        )).future,
      );

      expect(history.isNotEmpty, isTrue);
    });
  });

  group('Error Handling', () {
    test('should handle errors when completing without active fast', () async {
      final notifier = container.read(activeFastSessionProvider.notifier);

      expect(
        () => notifier.completeFast(),
        throwsStateError,
      );
    });

    test('should handle errors when breaking without active fast', () async {
      final notifier = container.read(activeFastSessionProvider.notifier);

      expect(
        () => notifier.breakFast(),
        throwsStateError,
      );
    });
  });
}
