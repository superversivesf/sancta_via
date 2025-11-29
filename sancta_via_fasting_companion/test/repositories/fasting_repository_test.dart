import 'package:flutter_test/flutter_test.dart';
import 'package:sancta_via_fasting_companion/database/database_migration_service.dart';
import 'package:sancta_via_fasting_companion/database/fasting_database.dart';
import 'package:sancta_via_fasting_companion/models/encouragement.dart';
import 'package:sancta_via_fasting_companion/models/encouragement_category.dart';
import 'package:sancta_via_fasting_companion/models/fast_session.dart';
import 'package:sancta_via_fasting_companion/models/fast_status.dart';
import 'package:sancta_via_fasting_companion/models/fast_type.dart';
import 'package:sancta_via_fasting_companion/models/fast_type_category.dart';
import 'package:sancta_via_fasting_companion/repositories/fasting_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Initialize FFI for testing
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late FastingDatabase database;
  late DatabaseMigrationService migrationService;
  late FastingRepository repository;
  int testCounter = 0;

  setUp(() async {
    // Use unique database for each test
    database = FastingDatabase(
      testDatabaseName:
          'test_repo_${DateTime.now().microsecondsSinceEpoch}_${testCounter++}.db',
    );
    await database.database;
    migrationService = DatabaseMigrationService(database);
    repository = FastingRepository.forTesting(database, migrationService);
  });

  tearDown(() async {
    await database.clearAllData();
    await database.close();
  });

  group('Singleton Pattern', () {
    test('instance should return singleton', () {
      final instance1 = FastingRepository.instance;
      final instance2 = FastingRepository.instance;
      expect(identical(instance1, instance2), isTrue);
    });
  });

  group('Migration Handling', () {
    test('should perform migration on first data access', () async {
      final fastTypes = await repository.getAllFastTypes();
      expect(fastTypes.isNotEmpty, isTrue);

      // Verify migration happened
      final dbTypes = await database.getAllFastTypes();
      expect(dbTypes.length, fastTypes.length);
    });

    test('should only migrate once', () async {
      // First access triggers migration
      await repository.getAllFastTypes();
      final count1 = (await database.getAllFastTypes()).length;

      // Second access should not duplicate data
      await repository.getAllFastTypes();
      final count2 = (await database.getAllFastTypes()).length;

      expect(count1, count2);
    });

    test('forceMigration should re-import data', () async {
      await repository.getAllFastTypes();
      await repository.forceMigration();

      final fastTypes = await repository.getAllFastTypes();
      expect(fastTypes.isNotEmpty, isTrue);
    });
  });

  group('Fast Type Operations', () {
    test('getAllFastTypes should return cached data on second call', () async {
      final types1 = await repository.getAllFastTypes();
      final types2 = await repository.getAllFastTypes();

      expect(types1.length, types2.length);
      expect(identical(types1, types2), isTrue); // Same cached instance
    });

    test('getFastTypesByCategory should filter correctly', () async {
      final intermittent = await repository.getFastTypesByCategory(
        FastTypeCategory.intermittent,
      );
      expect(intermittent.isNotEmpty, isTrue);
      for (final type in intermittent) {
        expect(type.category, FastTypeCategory.intermittent);
      }
    });

    test('getFastTypeById should return correct type', () async {
      final allTypes = await repository.getAllFastTypes();
      final firstId = allTypes.first.id;

      final found = await repository.getFastTypeById(firstId);
      expect(found, isNotNull);
      expect(found!.id, firstId);
    });

    test('getFastTypeById should return null for unknown ID', () async {
      final found = await repository.getFastTypeById('unknown_id');
      expect(found, isNull);
    });

    test('addFastType should invalidate cache', () async {
      // Get initial cached data
      final initial = await repository.getAllFastTypes();
      final initialCount = initial.length;

      // Add new type
      final newType = FastType(
        id: 'custom_fast',
        name: 'Custom Fast',
        description: 'Test',
        category: FastTypeCategory.intermittent,
      );
      await repository.addFastType(newType);

      // Cache should be invalidated and new data loaded
      final updated = await repository.getAllFastTypes();
      expect(updated.length, initialCount + 1);
      expect(updated.map((t) => t.id), contains('custom_fast'));
    });

    test('deleteFastType should invalidate cache', () async {
      final initial = await repository.getAllFastTypes();
      final firstId = initial.first.id;

      await repository.deleteFastType(firstId);

      final updated = await repository.getAllFastTypes();
      expect(updated.length, initial.length - 1);
      expect(updated.map((t) => t.id), isNot(contains(firstId)));
    });
  });

  group('Encouragement Operations', () {
    test('getAllEncouragements should return cached data', () async {
      final enc1 = await repository.getAllEncouragements();
      final enc2 = await repository.getAllEncouragements();

      expect(enc1.length, enc2.length);
      expect(identical(enc1, enc2), isTrue);
    });

    test('getEncouragementForContext should return appropriate encouragement',
        () async {
      final encouragement = await repository.getEncouragementForContext(
        triggerPoint: 'start',
      );

      expect(encouragement, isNotNull);
      expect(encouragement!.triggerPoint, 'start');
    });

    test('getEncouragementForContext should filter by liturgical season',
        () async {
      // Add season-specific encouragement
      await database.insertEncouragement(
        Encouragement(
          id: 'lent_test',
          category: EncouragementCategory.scripture,
          triggerPoint: 'start',
          liturgicalSeason: 'lent',
          content: 'Lent content',
        ),
      );

      final encouragement = await repository.getEncouragementForContext(
        triggerPoint: 'start',
        liturgicalSeason: 'lent',
      );

      expect(encouragement, isNotNull);
      // Could be lent-specific or generic (null season)
      expect(encouragement!.triggerPoint, 'start');
    });

    test('getEncouragementForContext should exclude shown encouragements',
        () async {
      // Create a session
      final session = await repository.startFast(
        fastTypeId: 'intermittent_16_8',
        targetDurationMinutes: 960,
      );

      // Get encouragement and mark as shown
      final enc1 = await repository.getEncouragementForContext(
        triggerPoint: 'start',
        sessionId: session.id,
      );
      await repository.markEncouragementShown(session.id, enc1!.id);

      // Get another encouragement
      final enc2 = await repository.getEncouragementForContext(
        triggerPoint: 'start',
        sessionId: session.id,
      );

      // Should be different (unless only one exists)
      final allStart = await database.getEncouragementsByTrigger('start');
      if (allStart.length > 1) {
        expect(enc2!.id, isNot(enc1.id));
      }
    });

    test('getEncouragementForContext should allow repeats when all shown',
        () async {
      final session = await repository.startFast(
        fastTypeId: 'intermittent_16_8',
        targetDurationMinutes: 960,
      );

      // Get all available start encouragements
      final allStart = await database.getEncouragementsByTrigger('start');

      // Mark all as shown
      for (final enc in allStart) {
        await repository.markEncouragementShown(session.id, enc.id);
      }

      // Should still return one even though all have been shown
      final encouragement = await repository.getEncouragementForContext(
        triggerPoint: 'start',
        sessionId: session.id,
      );

      expect(encouragement, isNotNull);
      expect(encouragement!.triggerPoint, 'start');
      // Should be one of the start encouragements
      expect(allStart.map((e) => e.id), contains(encouragement.id));
    });

    test('addEncouragement should invalidate cache', () async {
      final initial = await repository.getAllEncouragements();
      final initialCount = initial.length;

      await repository.addEncouragement(
        Encouragement(
          id: 'custom_enc',
          category: EncouragementCategory.prayer,
          triggerPoint: 'start',
          content: 'Custom content',
        ),
      );

      final updated = await repository.getAllEncouragements();
      expect(updated.length, initialCount + 1);
    });
  });

  group('Fast Session Lifecycle', () {
    test('startFast should create active session', () async {
      final session = await repository.startFast(
        fastTypeId: 'intermittent_16_8',
        targetDurationMinutes: 960,
        notes: 'Test fast',
      );

      expect(session.status, FastStatus.active);
      expect(session.fastTypeId, 'intermittent_16_8');
      expect(session.targetDurationMinutes, 960);
      expect(session.notes, 'Test fast');

      final active = await repository.getActiveFastSession();
      expect(active, isNotNull);
      expect(active!.id, session.id);
    });

    test('startFast should fail if active session exists', () async {
      await repository.startFast(
        fastTypeId: 'intermittent_16_8',
        targetDurationMinutes: 960,
      );

      expect(
        () => repository.startFast(
          fastTypeId: 'daily_24hr',
          targetDurationMinutes: 1440,
        ),
        throwsStateError,
      );
    });

    test('completeFast should mark session as completed', () async {
      await repository.startFast(
        fastTypeId: 'intermittent_16_8',
        targetDurationMinutes: 960,
      );

      final completed = await repository.completeFast(notes: 'Finished!');

      expect(completed.status, FastStatus.completed);
      expect(completed.endTime, isNotNull);
      expect(completed.notes, 'Finished!');

      final active = await repository.getActiveFastSession();
      expect(active, isNull);
    });

    test('completeFast should fail if no active session', () async {
      expect(
        () => repository.completeFast(),
        throwsStateError,
      );
    });

    test('breakFast should mark session as broken', () async {
      await repository.startFast(
        fastTypeId: 'intermittent_16_8',
        targetDurationMinutes: 960,
      );

      final broken = await repository.breakFast(notes: 'Could not finish');

      expect(broken.status, FastStatus.broken);
      expect(broken.endTime, isNotNull);
      expect(broken.notes, 'Could not finish');

      final active = await repository.getActiveFastSession();
      expect(active, isNull);
    });

    test('breakFast should fail if no active session', () async {
      expect(
        () => repository.breakFast(),
        throwsStateError,
      );
    });

    test('updateFastSession should persist changes', () async {
      final session = await repository.startFast(
        fastTypeId: 'intermittent_16_8',
        targetDurationMinutes: 960,
      );

      final updated = session.copyWith(notes: 'Updated notes');
      await repository.updateFastSession(updated);

      final fetched = await repository.getFastSessionById(session.id);
      expect(fetched!.notes, 'Updated notes');
    });

    test('getFastHistory should return past sessions', () async {
      // Create and complete a session
      await repository.startFast(
        fastTypeId: 'intermittent_16_8',
        targetDurationMinutes: 960,
      );
      await repository.completeFast();

      final history = await repository.getFastHistory();
      expect(history.length, 1);
      expect(history.first.status, FastStatus.completed);
    });

    test('getFastHistory should filter by date range', () async {
      // Create sessions
      await repository.startFast(
        fastTypeId: 'intermittent_16_8',
        targetDurationMinutes: 960,
      );
      await repository.completeFast();

      final history = await repository.getFastHistory(
        startDate: DateTime.now().subtract(const Duration(days: 1)),
        endDate: DateTime.now().add(const Duration(days: 1)),
      );

      expect(history.isNotEmpty, isTrue);
    });

    test('deleteFastSession should remove session', () async {
      final session = await repository.startFast(
        fastTypeId: 'intermittent_16_8',
        targetDurationMinutes: 960,
      );

      await repository.deleteFastSession(session.id);

      final fetched = await repository.getFastSessionById(session.id);
      expect(fetched, isNull);
    });
  });

  group('Statistics', () {
    setUp(() async {
      // Create some test sessions with actual elapsed time
      final now = DateTime.now();

      for (int i = 0; i < 5; i++) {
        final session = FastSession(
          id: 'stats_session_$i',
          fastTypeId: 'intermittent_16_8',
          startTime: now.subtract(Duration(hours: 16, days: i)),
          endTime: now.subtract(Duration(days: i)),
          targetDurationMinutes: 960,
          status: FastStatus.completed,
        );
        await database.insertFastSession(session);
      }

      // Create a broken session
      final brokenSession = FastSession(
        id: 'broken_session',
        fastTypeId: 'daily_24hr',
        startTime: now.subtract(const Duration(hours: 10)),
        endTime: now.subtract(const Duration(hours: 2)),
        targetDurationMinutes: 1440,
        status: FastStatus.broken,
      );
      await database.insertFastSession(brokenSession);
    });

    test('getCompletedFastsCount should return correct count', () async {
      final count = await repository.getCompletedFastsCount();
      expect(count, 5);
    });

    test('getTotalHoursFasted should calculate total', () async {
      final hours = await repository.getTotalHoursFasted();
      expect(hours, greaterThan(0));
    });

    test('getAverageFastDuration should calculate average', () async {
      final average = await repository.getAverageFastDuration();
      expect(average, greaterThan(0));
    });

    test('getCompletionRate should calculate rate', () async {
      final rate = await repository.getCompletionRate();
      expect(rate, closeTo(5 / 6, 0.01)); // 5 completed, 1 broken
    });

    test('getMostCommonFastType should return correct type', () async {
      final mostCommon = await repository.getMostCommonFastType();
      expect(mostCommon, isNotNull);
      expect(mostCommon!.id, 'intermittent_16_8');
    });

    test('getMostCommonFastType should return null if no completed',
        () async {
      await database.clearAllData();
      final mostCommon = await repository.getMostCommonFastType();
      expect(mostCommon, isNull);
    });
  });

  group('Streak Calculations', () {
    test('getCurrentStreak should calculate current streak', () async {
      // Create sessions for consecutive days
      final now = DateTime.now();
      for (int i = 0; i < 3; i++) {
        final session = FastSession(
          id: 'streak_$i',
          fastTypeId: 'intermittent_16_8',
          startTime: now.subtract(Duration(days: i)),
          endTime: now.subtract(Duration(days: i)),
          targetDurationMinutes: 960,
          status: FastStatus.completed,
        );
        await database.insertFastSession(session);
      }

      final streak = await repository.getCurrentStreak();
      expect(streak, greaterThanOrEqualTo(1));
    });

    test('getCurrentStreak should return 0 if no completed fasts', () async {
      final streak = await repository.getCurrentStreak();
      expect(streak, 0);
    });

    test('getLongestStreak should calculate longest streak', () async {
      // Create sessions with a gap
      final now = DateTime.now();

      // First streak: 3 days
      for (int i = 0; i < 3; i++) {
        final session = FastSession(
          id: 'streak1_$i',
          fastTypeId: 'intermittent_16_8',
          startTime: now.subtract(Duration(days: 10 - i)),
          endTime: now.subtract(Duration(days: 10 - i)),
          targetDurationMinutes: 960,
          status: FastStatus.completed,
        );
        await database.insertFastSession(session);
      }

      // Second streak: 2 days (current)
      for (int i = 0; i < 2; i++) {
        final session = FastSession(
          id: 'streak2_$i',
          fastTypeId: 'intermittent_16_8',
          startTime: now.subtract(Duration(days: 1 - i)),
          endTime: now.subtract(Duration(days: 1 - i)),
          targetDurationMinutes: 960,
          status: FastStatus.completed,
        );
        await database.insertFastSession(session);
      }

      final longest = await repository.getLongestStreak();
      expect(longest, greaterThanOrEqualTo(2));
    });

    test('getLongestStreak should return 0 if no completed fasts', () async {
      final streak = await repository.getLongestStreak();
      expect(streak, 0);
    });
  });

  group('Utility Methods', () {
    test('clearCache should invalidate all cached data', () async {
      // Load cached data
      final types1 = await repository.getAllFastTypes();
      final enc1 = await repository.getAllEncouragements();

      // Clear cache
      repository.clearCache();

      // Load again (should be new instances)
      final types2 = await repository.getAllFastTypes();
      final enc2 = await repository.getAllEncouragements();

      expect(identical(types1, types2), isFalse);
      expect(identical(enc1, enc2), isFalse);
    });

    test('close should close database', () async {
      await repository.getAllFastTypes();
      await repository.close();
      // Database should be closed
    });
  });

  group('Edge Cases', () {
    test('should handle database with migration data', () async {
      // After migration, database should have default data
      final types = await repository.getAllFastTypes();
      expect(types.isNotEmpty, isTrue);

      final encouragements = await repository.getAllEncouragements();
      expect(encouragements.isNotEmpty, isTrue);
    });

    test('getEncouragementForContext should return null if none match',
        () async {
      final encouragement = await repository.getEncouragementForContext(
        triggerPoint: 'nonexistent_trigger_point',
      );

      expect(encouragement, isNull);
    });

    test('statistics should handle no sessions gracefully', () async {
      // No sessions created yet, only migrated data exists
      expect(await repository.getCompletedFastsCount(), 0);
      expect(await repository.getTotalHoursFasted(), 0.0);
      expect(await repository.getAverageFastDuration(), 0.0);
      expect(await repository.getCompletionRate(), 0.0);
      expect(await repository.getCurrentStreak(), 0);
      expect(await repository.getLongestStreak(), 0);
      expect(await repository.getMostCommonFastType(), isNull);
    });

    test('should handle concurrent access gracefully', () async {
      // Test concurrent reads
      final futures = <Future>[];
      for (int i = 0; i < 5; i++) {
        futures.add(repository.getAllFastTypes());
        futures.add(repository.getAllEncouragements());
      }

      final results = await Future.wait(futures);
      expect(results.length, 10);
    });
  });
}
