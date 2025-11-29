import 'package:flutter_test/flutter_test.dart';
import 'package:sancta_via_fasting_companion/database/database_migration_service.dart';
import 'package:sancta_via_fasting_companion/database/fasting_database.dart';
import 'package:sancta_via_fasting_companion/models/fast_type_category.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Initialize FFI for testing
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late FastingDatabase database;
  late DatabaseMigrationService migrationService;
  int testCounter = 0;

  setUp(() async {
    // Use a unique database for each test to avoid locking issues
    database = FastingDatabase(
      testDatabaseName: 'test_migration_${DateTime.now().microsecondsSinceEpoch}_${testCounter++}.db',
    );
    await database.database;
    migrationService = DatabaseMigrationService(database);
  });

  tearDown(() async {
    await database.clearAllData();
    await database.close();
  });

  group('Migration Status Check', () {
    test('isMigrationNeeded should return true when database is empty',
        () async {
      final needed = await migrationService.isMigrationNeeded();
      expect(needed, isTrue);
    });

    test('isMigrationNeeded should return false when database has data',
        () async {
      // Perform migration
      await migrationService.performMigration();

      // Check again
      final needed = await migrationService.isMigrationNeeded();
      expect(needed, isFalse);
    });
  });

  group('Migration Execution', () {
    test('performMigration should populate fast types from JSON', () async {
      await migrationService.performMigration();

      final fastTypes = await database.getAllFastTypes();
      expect(fastTypes.isNotEmpty, isTrue);

      // Verify we have the expected fast types from JSON
      final ids = fastTypes.map((ft) => ft.id).toList();
      expect(ids, contains('intermittent_16_8'));
      expect(ids, contains('intermittent_18_6'));
      expect(ids, contains('daily_24hr'));
      expect(ids, contains('lenten_fast'));
      expect(ids, contains('ash_wednesday'));
      expect(ids, contains('good_friday'));
    });

    test('performMigration should populate encouragements from JSON',
        () async {
      await migrationService.performMigration();

      final encouragements = await database.getAllEncouragements();
      expect(encouragements.isNotEmpty, isTrue);

      // Verify we have various categories
      final categories = encouragements.map((e) => e.category).toSet();
      expect(categories.length, greaterThan(1));

      // Verify we have various trigger points
      final triggers = encouragements.map((e) => e.triggerPoint).toSet();
      expect(triggers, contains('start'));
      expect(triggers, contains('hourly'));
      expect(triggers, contains('milestone'));
      expect(triggers, contains('difficulty'));
      expect(triggers, contains('completion'));
    });

    test('performMigration should migrate fast types with all fields',
        () async {
      await migrationService.performMigration();

      final fastType = await database.getFastTypeById('intermittent_16_8');
      expect(fastType, isNotNull);
      expect(fastType!.name, '16:8 Intermittent Fast');
      expect(fastType.description, isNotEmpty);
      expect(fastType.category, FastTypeCategory.intermittent);
      expect(fastType.targetDurationHours, 16);
      expect(fastType.milestoneMessages, isNotEmpty);
    });

    test('performMigration should migrate encouragements with all fields',
        () async {
      await migrationService.performMigration();

      final encouragements = await database.getAllEncouragements();
      final scripture =
          encouragements.firstWhere((e) => e.id == 'start_matthew_6_16');

      expect(scripture.content, isNotEmpty);
      expect(scripture.attribution, 'Matthew 6:16-18');
      expect(scripture.relatedScripture, 'Matthew 6:16-18');
      expect(scripture.categoryHint, 'humility');
      expect(scripture.triggerPoint, 'start');
    });

    test('performMigration should handle liturgical season data', () async {
      await migrationService.performMigration();

      final encouragements = await database.getAllEncouragements();

      // Check for non-liturgical (null season)
      final generic = encouragements.where(
        (e) => e.liturgicalSeason == null && e.triggerPoint == 'start',
      );
      expect(generic.isNotEmpty, isTrue);

      // Check for lent-specific
      final lent = encouragements.where((e) => e.liturgicalSeason == 'lent');
      expect(lent.isNotEmpty, isTrue);

      // Check for advent-specific
      final advent =
          encouragements.where((e) => e.liturgicalSeason == 'advent');
      expect(advent.isNotEmpty, isTrue);
    });
  });

  group('Force Migration', () {
    test('forceMigration should clear existing data and re-import', () async {
      // First migration
      await migrationService.performMigration();
      final originalFastTypes = await database.getAllFastTypes();
      final originalEncouragements = await database.getAllEncouragements();

      expect(originalFastTypes.isNotEmpty, isTrue);
      expect(originalEncouragements.isNotEmpty, isTrue);

      // Force migration
      await migrationService.forceMigration();

      // Verify data is still there (re-imported)
      final newFastTypes = await database.getAllFastTypes();
      final newEncouragements = await database.getAllEncouragements();

      expect(newFastTypes.length, originalFastTypes.length);
      expect(newEncouragements.length, originalEncouragements.length);
    });

    test('forceMigration should handle multiple calls', () async {
      await migrationService.forceMigration();
      await migrationService.forceMigration();
      await migrationService.forceMigration();

      final fastTypes = await database.getAllFastTypes();
      final encouragements = await database.getAllEncouragements();

      expect(fastTypes.isNotEmpty, isTrue);
      expect(encouragements.isNotEmpty, isTrue);
    });
  });

  group('Data Validation', () {
    test('migrated fast types should have valid categories', () async {
      await migrationService.performMigration();

      final fastTypes = await database.getAllFastTypes();
      for (final fastType in fastTypes) {
        expect(
          [
            FastTypeCategory.intermittent,
            FastTypeCategory.daily24hr,
            FastTypeCategory.multiDay,
            FastTypeCategory.liturgical,
          ],
          contains(fastType.category),
        );
      }
    });

    test('migrated fast types should have valid durations', () async {
      await migrationService.performMigration();

      final fastTypes = await database.getAllFastTypes();
      for (final fastType in fastTypes) {
        if (fastType.targetDurationHours != null) {
          expect(fastType.targetDurationHours! > 0, isTrue);
          expect(fastType.targetDurationHours! <= 168, isTrue); // Max 1 week
        }
      }
    });

    test('migrated encouragements should have required fields', () async {
      await migrationService.performMigration();

      final encouragements = await database.getAllEncouragements();
      for (final encouragement in encouragements) {
        expect(encouragement.id, isNotEmpty);
        expect(encouragement.content, isNotEmpty);
        expect(encouragement.triggerPoint, isNotEmpty);
      }
    });

    test('migrated milestone messages should have valid hour keys', () async {
      await migrationService.performMigration();

      final fastTypes = await database.getAllFastTypes();
      for (final fastType in fastTypes) {
        for (final hour in fastType.milestoneMessages.keys) {
          expect(hour >= 0, isTrue);
          if (fastType.targetDurationHours != null) {
            expect(hour <= fastType.targetDurationHours!, isTrue);
          }
        }
      }
    });
  });

  group('Migration Idempotency', () {
    test('running migration twice should not duplicate data', () async {
      // First migration
      await migrationService.performMigration();
      final count1 = (await database.getAllFastTypes()).length;

      // Try to migrate again (should not duplicate)
      final needed = await migrationService.isMigrationNeeded();
      expect(needed, isFalse);

      if (!needed) {
        // Should not migrate again
        final count2 = (await database.getAllFastTypes()).length;
        expect(count2, count1);
      }
    });

    test('migration check after migration should return false', () async {
      expect(await migrationService.isMigrationNeeded(), isTrue);

      await migrationService.performMigration();

      expect(await migrationService.isMigrationNeeded(), isFalse);
    });
  });

  group('Edge Cases', () {
    test('migration should handle fast types with no milestones', () async {
      await migrationService.performMigration();

      final lentFast = await database.getFastTypeById('lenten_fast');
      expect(lentFast, isNotNull);
      expect(lentFast!.milestoneMessages, isEmpty);
    });

    test('migration should handle fast types with null target duration',
        () async {
      await migrationService.performMigration();

      final lentFast = await database.getFastTypeById('lenten_fast');
      expect(lentFast, isNotNull);
      expect(lentFast!.targetDurationHours, isNull);
    });

    test('migration should handle encouragements without optional fields',
        () async {
      await migrationService.performMigration();

      final encouragements = await database.getAllEncouragements();

      // Find encouragements with null optional fields
      final withNullSeason =
          encouragements.where((e) => e.liturgicalSeason == null);
      expect(withNullSeason.isNotEmpty, isTrue);
    });
  });
}
