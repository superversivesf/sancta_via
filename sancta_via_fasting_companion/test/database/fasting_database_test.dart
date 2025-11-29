import 'package:flutter_test/flutter_test.dart';
import 'package:sancta_via_fasting_companion/database/fasting_database.dart';
import 'package:sancta_via_fasting_companion/models/encouragement.dart';
import 'package:sancta_via_fasting_companion/models/encouragement_category.dart';
import 'package:sancta_via_fasting_companion/models/fast_session.dart';
import 'package:sancta_via_fasting_companion/models/fast_status.dart';
import 'package:sancta_via_fasting_companion/models/fast_type.dart';
import 'package:sancta_via_fasting_companion/models/fast_type_category.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Initialize FFI for testing
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late FastingDatabase database;
  int testCounter = 0;

  setUp(() async {
    // Use a unique database for each test to avoid locking issues
    database = FastingDatabase(
      testDatabaseName: 'test_db_${DateTime.now().microsecondsSinceEpoch}_${testCounter++}.db',
    );
    // Wait for database to initialize
    await database.database;
  });

  tearDown(() async {
    await database.clearAllData();
    await database.close();
  });

  group('FastType CRUD Operations', () {
    test('insertFastType should insert a fast type', () async {
      final fastType = FastType(
        id: 'test_16_8',
        name: '16:8 Fast',
        description: 'Test fast type',
        category: FastTypeCategory.intermittent,
        targetDurationHours: 16,
        milestoneMessages: {4: 'Quarter way!', 8: 'Halfway!'},
        associatedPrayers: ['prayer1', 'prayer2'],
      );

      await database.insertFastType(fastType);

      final result = await database.getFastTypeById('test_16_8');
      expect(result, isNotNull);
      expect(result!.id, 'test_16_8');
      expect(result.name, '16:8 Fast');
      expect(result.category, FastTypeCategory.intermittent);
      expect(result.targetDurationHours, 16);
      expect(result.milestoneMessages[4], 'Quarter way!');
      expect(result.associatedPrayers, ['prayer1', 'prayer2']);
    });

    test('getAllFastTypes should return all fast types', () async {
      final fastType1 = FastType(
        id: 'test_1',
        name: 'Test 1',
        description: 'First test',
        category: FastTypeCategory.intermittent,
      );
      final fastType2 = FastType(
        id: 'test_2',
        name: 'Test 2',
        description: 'Second test',
        category: FastTypeCategory.daily24hr,
      );

      await database.insertFastType(fastType1);
      await database.insertFastType(fastType2);

      final results = await database.getAllFastTypes();
      expect(results.length, 2);
      expect(results.map((ft) => ft.id), containsAll(['test_1', 'test_2']));
    });

    test('getFastTypesByCategory should filter by category', () async {
      final intermittent = FastType(
        id: 'int_1',
        name: 'Intermittent',
        description: 'Test',
        category: FastTypeCategory.intermittent,
      );
      final liturgical = FastType(
        id: 'lit_1',
        name: 'Liturgical',
        description: 'Test',
        category: FastTypeCategory.liturgical,
      );

      await database.insertFastType(intermittent);
      await database.insertFastType(liturgical);

      final results =
          await database.getFastTypesByCategory(FastTypeCategory.intermittent);
      expect(results.length, 1);
      expect(results.first.id, 'int_1');
      expect(results.first.category, FastTypeCategory.intermittent);
    });

    test('getFastTypeById should return null for non-existent ID', () async {
      final result = await database.getFastTypeById('non_existent');
      expect(result, isNull);
    });

    test('deleteFastType should remove a fast type', () async {
      final fastType = FastType(
        id: 'to_delete',
        name: 'Delete Me',
        description: 'Test',
        category: FastTypeCategory.intermittent,
      );

      await database.insertFastType(fastType);
      expect(await database.getFastTypeById('to_delete'), isNotNull);

      await database.deleteFastType('to_delete');
      expect(await database.getFastTypeById('to_delete'), isNull);
    });

    test('insertFastType should replace on conflict', () async {
      final original = FastType(
        id: 'replace_test',
        name: 'Original',
        description: 'Original description',
        category: FastTypeCategory.intermittent,
      );
      final updated = FastType(
        id: 'replace_test',
        name: 'Updated',
        description: 'Updated description',
        category: FastTypeCategory.daily24hr,
      );

      await database.insertFastType(original);
      await database.insertFastType(updated);

      final result = await database.getFastTypeById('replace_test');
      expect(result!.name, 'Updated');
      expect(result.description, 'Updated description');
    });
  });

  group('FastSession CRUD Operations', () {
    test('insertFastSession should insert a session', () async {
      final session = FastSession(
        id: 'session_1',
        fastTypeId: 'type_1',
        startTime: DateTime(2024, 1, 1, 10, 0),
        targetDurationMinutes: 960,
        status: FastStatus.active,
        notes: 'Test notes',
      );

      await database.insertFastSession(session);

      final result = await database.getFastSessionById('session_1');
      expect(result, isNotNull);
      expect(result!.id, 'session_1');
      expect(result.fastTypeId, 'type_1');
      expect(result.status, FastStatus.active);
      expect(result.notes, 'Test notes');
    });

    test('updateFastSession should update a session', () async {
      final session = FastSession(
        id: 'update_test',
        fastTypeId: 'type_1',
        startTime: DateTime(2024, 1, 1, 10, 0),
        targetDurationMinutes: 960,
        status: FastStatus.active,
      );

      await database.insertFastSession(session);

      final updated = session.copyWith(
        status: FastStatus.completed,
        endTime: DateTime(2024, 1, 2, 2, 0),
        notes: 'Completed successfully',
      );

      await database.updateFastSession(updated);

      final result = await database.getFastSessionById('update_test');
      expect(result!.status, FastStatus.completed);
      expect(result.endTime, isNotNull);
      expect(result.notes, 'Completed successfully');
    });

    test('getActiveFastSession should return only active session', () async {
      final active = FastSession(
        id: 'active',
        fastTypeId: 'type_1',
        startTime: DateTime(2024, 1, 1, 10, 0),
        targetDurationMinutes: 960,
        status: FastStatus.active,
      );
      final completed = FastSession(
        id: 'completed',
        fastTypeId: 'type_1',
        startTime: DateTime(2024, 1, 1, 10, 0),
        endTime: DateTime(2024, 1, 2, 2, 0),
        targetDurationMinutes: 960,
        status: FastStatus.completed,
      );

      await database.insertFastSession(completed);
      await database.insertFastSession(active);

      final result = await database.getActiveFastSession();
      expect(result, isNotNull);
      expect(result!.id, 'active');
      expect(result.status, FastStatus.active);
    });

    test('getActiveFastSession should return null when no active session',
        () async {
      final result = await database.getActiveFastSession();
      expect(result, isNull);
    });

    test('getFastSessions should return sessions ordered by start time',
        () async {
      final session1 = FastSession(
        id: 'session_1',
        fastTypeId: 'type_1',
        startTime: DateTime(2024, 1, 1, 10, 0),
        targetDurationMinutes: 960,
        status: FastStatus.completed,
      );
      final session2 = FastSession(
        id: 'session_2',
        fastTypeId: 'type_1',
        startTime: DateTime(2024, 1, 3, 10, 0),
        targetDurationMinutes: 960,
        status: FastStatus.completed,
      );
      final session3 = FastSession(
        id: 'session_3',
        fastTypeId: 'type_1',
        startTime: DateTime(2024, 1, 2, 10, 0),
        targetDurationMinutes: 960,
        status: FastStatus.completed,
      );

      await database.insertFastSession(session1);
      await database.insertFastSession(session2);
      await database.insertFastSession(session3);

      final results = await database.getFastSessions();
      expect(results.length, 3);
      // Should be in descending order (newest first)
      expect(results[0].id, 'session_2');
      expect(results[1].id, 'session_3');
      expect(results[2].id, 'session_1');
    });

    test('getFastSessions should filter by date range', () async {
      final session1 = FastSession(
        id: 'jan_1',
        fastTypeId: 'type_1',
        startTime: DateTime(2024, 1, 1, 10, 0),
        targetDurationMinutes: 960,
        status: FastStatus.completed,
      );
      final session2 = FastSession(
        id: 'jan_15',
        fastTypeId: 'type_1',
        startTime: DateTime(2024, 1, 15, 10, 0),
        targetDurationMinutes: 960,
        status: FastStatus.completed,
      );
      final session3 = FastSession(
        id: 'feb_1',
        fastTypeId: 'type_1',
        startTime: DateTime(2024, 2, 1, 10, 0),
        targetDurationMinutes: 960,
        status: FastStatus.completed,
      );

      await database.insertFastSession(session1);
      await database.insertFastSession(session2);
      await database.insertFastSession(session3);

      final results = await database.getFastSessions(
        startDate: DateTime(2024, 1, 10),
        endDate: DateTime(2024, 1, 20),
      );
      expect(results.length, 1);
      expect(results.first.id, 'jan_15');
    });

    test('getFastSessions should respect limit', () async {
      for (int i = 0; i < 10; i++) {
        await database.insertFastSession(
          FastSession(
            id: 'session_$i',
            fastTypeId: 'type_1',
            startTime: DateTime(2024, 1, i + 1, 10, 0),
            targetDurationMinutes: 960,
            status: FastStatus.completed,
          ),
        );
      }

      final results = await database.getFastSessions(limit: 5);
      expect(results.length, 5);
    });

    test('getCompletedFastsCount should count completed sessions', () async {
      await database.insertFastSession(
        FastSession(
          id: 'completed_1',
          fastTypeId: 'type_1',
          startTime: DateTime(2024, 1, 1),
          targetDurationMinutes: 960,
          status: FastStatus.completed,
        ),
      );
      await database.insertFastSession(
        FastSession(
          id: 'completed_2',
          fastTypeId: 'type_1',
          startTime: DateTime(2024, 1, 2),
          targetDurationMinutes: 960,
          status: FastStatus.completed,
        ),
      );
      await database.insertFastSession(
        FastSession(
          id: 'active',
          fastTypeId: 'type_1',
          startTime: DateTime(2024, 1, 3),
          targetDurationMinutes: 960,
          status: FastStatus.active,
        ),
      );
      await database.insertFastSession(
        FastSession(
          id: 'broken',
          fastTypeId: 'type_1',
          startTime: DateTime(2024, 1, 4),
          targetDurationMinutes: 960,
          status: FastStatus.broken,
        ),
      );

      final count = await database.getCompletedFastsCount();
      expect(count, 2);
    });

    test('deleteFastSession should remove a session', () async {
      final session = FastSession(
        id: 'to_delete',
        fastTypeId: 'type_1',
        startTime: DateTime(2024, 1, 1),
        targetDurationMinutes: 960,
        status: FastStatus.active,
      );

      await database.insertFastSession(session);
      expect(await database.getFastSessionById('to_delete'), isNotNull);

      await database.deleteFastSession('to_delete');
      expect(await database.getFastSessionById('to_delete'), isNull);
    });
  });

  group('Encouragement CRUD Operations', () {
    test('insertEncouragement should insert an encouragement', () async {
      final encouragement = Encouragement(
        id: 'test_enc',
        category: EncouragementCategory.scripture,
        triggerPoint: 'start',
        content: 'Test content',
        attribution: 'Test Attribution',
        relatedScripture: 'Test 1:1',
        categoryHint: 'test',
      );

      await database.insertEncouragement(encouragement);

      final results = await database.getAllEncouragements();
      expect(results.length, 1);
      expect(results.first.id, 'test_enc');
      expect(results.first.category, EncouragementCategory.scripture);
      expect(results.first.content, 'Test content');
    });

    test('getAllEncouragements should return all encouragements', () async {
      final enc1 = Encouragement(
        id: 'enc_1',
        category: EncouragementCategory.scripture,
        triggerPoint: 'start',
        content: 'Content 1',
      );
      final enc2 = Encouragement(
        id: 'enc_2',
        category: EncouragementCategory.prayer,
        triggerPoint: 'milestone',
        content: 'Content 2',
      );

      await database.insertEncouragement(enc1);
      await database.insertEncouragement(enc2);

      final results = await database.getAllEncouragements();
      expect(results.length, 2);
    });

    test('getEncouragementsByTrigger should filter by trigger point',
        () async {
      final startEnc = Encouragement(
        id: 'start_enc',
        category: EncouragementCategory.scripture,
        triggerPoint: 'start',
        content: 'Start content',
      );
      final hourlyEnc = Encouragement(
        id: 'hourly_enc',
        category: EncouragementCategory.prayer,
        triggerPoint: 'hourly',
        content: 'Hourly content',
      );

      await database.insertEncouragement(startEnc);
      await database.insertEncouragement(hourlyEnc);

      final results = await database.getEncouragementsByTrigger('start');
      expect(results.length, 1);
      expect(results.first.id, 'start_enc');
      expect(results.first.triggerPoint, 'start');
    });

    test(
        'getEncouragementsByTriggerAndSeason should filter by both trigger and season',
        () async {
      final lentStart = Encouragement(
        id: 'lent_start',
        category: EncouragementCategory.scripture,
        triggerPoint: 'start',
        liturgicalSeason: 'lent',
        content: 'Lent start',
      );
      final genericStart = Encouragement(
        id: 'generic_start',
        category: EncouragementCategory.scripture,
        triggerPoint: 'start',
        content: 'Generic start',
      );
      final adventStart = Encouragement(
        id: 'advent_start',
        category: EncouragementCategory.scripture,
        triggerPoint: 'start',
        liturgicalSeason: 'advent',
        content: 'Advent start',
      );

      await database.insertEncouragement(lentStart);
      await database.insertEncouragement(genericStart);
      await database.insertEncouragement(adventStart);

      final results = await database.getEncouragementsByTriggerAndSeason(
        'start',
        'lent',
      );

      // Should return lent-specific and generic (null season) encouragements
      expect(results.length, 2);
      expect(
        results.map((e) => e.id),
        containsAll(['lent_start', 'generic_start']),
      );
      expect(results.map((e) => e.id), isNot(contains('advent_start')));
    });

    test('getEncouragementsByTriggerAndSeason with null season', () async {
      final lentStart = Encouragement(
        id: 'lent_start',
        category: EncouragementCategory.scripture,
        triggerPoint: 'start',
        liturgicalSeason: 'lent',
        content: 'Lent start',
      );
      final genericStart = Encouragement(
        id: 'generic_start',
        category: EncouragementCategory.scripture,
        triggerPoint: 'start',
        content: 'Generic start',
      );

      await database.insertEncouragement(lentStart);
      await database.insertEncouragement(genericStart);

      final results = await database.getEncouragementsByTriggerAndSeason(
        'start',
        null,
      );

      expect(results.length, 2);
    });

    test('deleteEncouragement should remove an encouragement', () async {
      final encouragement = Encouragement(
        id: 'to_delete',
        category: EncouragementCategory.scripture,
        triggerPoint: 'start',
        content: 'Delete me',
      );

      await database.insertEncouragement(encouragement);
      expect((await database.getAllEncouragements()).length, 1);

      await database.deleteEncouragement('to_delete');
      expect((await database.getAllEncouragements()).length, 0);
    });
  });

  group('Encouragement History Operations', () {
    test('recordEncouragementShown should create history record', () async {
      await database.recordEncouragementShown('session_1', 'enc_1');

      final shown = await database.getShownEncouragementIds('session_1');
      expect(shown.length, 1);
      expect(shown.first, 'enc_1');
    });

    test('getShownEncouragementIds should return all shown encouragements',
        () async {
      await database.recordEncouragementShown('session_1', 'enc_1');
      await database.recordEncouragementShown('session_1', 'enc_2');
      await database.recordEncouragementShown('session_1', 'enc_3');

      final shown = await database.getShownEncouragementIds('session_1');
      expect(shown.length, 3);
      expect(shown, containsAll(['enc_1', 'enc_2', 'enc_3']));
    });

    test('getShownEncouragementIds should filter by session', () async {
      await database.recordEncouragementShown('session_1', 'enc_1');
      await database.recordEncouragementShown('session_2', 'enc_2');

      final shown1 = await database.getShownEncouragementIds('session_1');
      final shown2 = await database.getShownEncouragementIds('session_2');

      expect(shown1, ['enc_1']);
      expect(shown2, ['enc_2']);
    });

    test('getShownEncouragementIds should return empty list for unknown session',
        () async {
      final shown = await database.getShownEncouragementIds('unknown');
      expect(shown, isEmpty);
    });
  });

  group('Utility Methods', () {
    test('clearAllData should remove all data from all tables', () async {
      // Insert data into all tables
      await database.insertFastType(
        FastType(
          id: 'type_1',
          name: 'Test',
          description: 'Test',
          category: FastTypeCategory.intermittent,
        ),
      );
      await database.insertFastSession(
        FastSession(
          id: 'session_1',
          fastTypeId: 'type_1',
          startTime: DateTime.now(),
          targetDurationMinutes: 960,
          status: FastStatus.active,
        ),
      );
      await database.insertEncouragement(
        Encouragement(
          id: 'enc_1',
          category: EncouragementCategory.scripture,
          triggerPoint: 'start',
          content: 'Test',
        ),
      );
      await database.recordEncouragementShown('session_1', 'enc_1');

      // Verify data exists
      expect((await database.getAllFastTypes()).length, 1);
      expect((await database.getFastSessions()).length, 1);
      expect((await database.getAllEncouragements()).length, 1);
      expect(
        (await database.getShownEncouragementIds('session_1')).length,
        1,
      );

      // Clear all data
      await database.clearAllData();

      // Verify all tables are empty
      expect((await database.getAllFastTypes()).length, 0);
      expect((await database.getFastSessions()).length, 0);
      expect((await database.getAllEncouragements()).length, 0);
      expect(
        (await database.getShownEncouragementIds('session_1')).length,
        0,
      );
    });

    test('close should close database connection', () async {
      await database.close();
      // After closing, database should reinitialize on next access
      final types = await database.getAllFastTypes();
      expect(types, isEmpty);
    });
  });

  group('Data Persistence', () {
    test('data should persist between queries', () async {
      final fastType = FastType(
        id: 'persist_test',
        name: 'Persistence Test',
        description: 'Testing persistence',
        category: FastTypeCategory.intermittent,
        targetDurationHours: 16,
      );

      await database.insertFastType(fastType);

      // Query multiple times
      final result1 = await database.getFastTypeById('persist_test');
      final result2 = await database.getFastTypeById('persist_test');
      final result3 = await database.getAllFastTypes();

      expect(result1, isNotNull);
      expect(result2, isNotNull);
      expect(result3.length, 1);
      expect(result1!.name, 'Persistence Test');
      expect(result2!.name, 'Persistence Test');
    });

    test('complex data structures should round-trip correctly', () async {
      final fastType = FastType(
        id: 'complex_test',
        name: 'Complex Test',
        description: 'Testing complex data',
        category: FastTypeCategory.liturgical,
        targetDurationHours: 24,
        milestoneMessages: {
          6: 'Six hours',
          12: 'Twelve hours',
          18: 'Eighteen hours',
          24: 'Complete!',
        },
        associatedPrayers: [
          'our_father',
          'hail_mary',
          'glory_be',
        ],
      );

      await database.insertFastType(fastType);
      final result = await database.getFastTypeById('complex_test');

      expect(result!.milestoneMessages.length, 4);
      expect(result.milestoneMessages[6], 'Six hours');
      expect(result.milestoneMessages[12], 'Twelve hours');
      expect(result.milestoneMessages[18], 'Eighteen hours');
      expect(result.milestoneMessages[24], 'Complete!');
      expect(result.associatedPrayers.length, 3);
      expect(result.associatedPrayers, contains('our_father'));
    });
  });
}
