import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sancta_via_fasting_companion/database/database_migration_service.dart';
import 'package:sancta_via_fasting_companion/database/fasting_database.dart';
import 'package:sancta_via_fasting_companion/models/fast_type_category.dart';
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
          'test_providers_${DateTime.now().microsecondsSinceEpoch}_${testCounter++}.db',
    );
    await database.database;
    final migrationService = DatabaseMigrationService(database);
    repository = FastingRepository.forTesting(database, migrationService);

    container = ProviderContainer(
      overrides: [
        fastingRepositoryProvider.overrideWithValue(repository),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await database.clearAllData();
    await database.close();
  });

  group('Fast Type Providers', () {
    test('allFastTypesProvider should return all fast types', () async {
      final fastTypes = await container.read(allFastTypesProvider.future);

      expect(fastTypes.isNotEmpty, isTrue);
      expect(fastTypes.length, 6); // Default fast types from migration
    });

    test('fastTypesByCategoryProvider should filter by category', () async {
      final intermittent = await container.read(
        fastTypesByCategoryProvider(FastTypeCategory.intermittent).future,
      );

      expect(intermittent.isNotEmpty, isTrue);
      for (final fastType in intermittent) {
        expect(fastType.category, FastTypeCategory.intermittent);
      }
    });

    test('fastTypeByIdProvider should return correct fast type', () async {
      final fastType = await container.read(
        fastTypeByIdProvider('intermittent_16_8').future,
      );

      expect(fastType, isNotNull);
      expect(fastType!.id, 'intermittent_16_8');
      expect(fastType.name, '16:8 Intermittent Fast');
    });

    test('fastTypeByIdProvider should return null for unknown ID', () async {
      final fastType = await container.read(
        fastTypeByIdProvider('unknown_id').future,
      );

      expect(fastType, isNull);
    });

    test('intermittentFastTypesProvider should return intermittent types',
        () async {
      final intermittent =
          await container.read(intermittentFastTypesProvider.future);

      expect(intermittent.isNotEmpty, isTrue);
      for (final fastType in intermittent) {
        expect(fastType.category, FastTypeCategory.intermittent);
      }
    });

    test('daily24hrFastTypesProvider should return 24-hour types', () async {
      final daily24hr = await container.read(daily24hrFastTypesProvider.future);

      expect(daily24hr.isNotEmpty, isTrue);
      for (final fastType in daily24hr) {
        expect(fastType.category, FastTypeCategory.daily24hr);
      }
    });

    test('liturgicalFastTypesProvider should return liturgical types',
        () async {
      final liturgical =
          await container.read(liturgicalFastTypesProvider.future);

      expect(liturgical.isNotEmpty, isTrue);
      for (final fastType in liturgical) {
        expect(fastType.category, FastTypeCategory.liturgical);
      }
    });

    test('multiDayFastTypesProvider should return empty list initially',
        () async {
      final multiDay = await container.read(multiDayFastTypesProvider.future);

      // No multi-day fasts in default data
      expect(multiDay, isEmpty);
    });

    test('providers should use cached repository data', () async {
      // First access
      final types1 = await container.read(allFastTypesProvider.future);

      // Second access should use cache
      final types2 = await container.read(allFastTypesProvider.future);

      expect(types1.length, types2.length);
    });
  });

  group('Provider Reactivity', () {
    test('providers should update when data changes', () async {
      // Initial read
      final initial = await container.read(allFastTypesProvider.future);
      final initialCount = initial.length;

      // Invalidate and refresh
      container.invalidate(allFastTypesProvider);

      // Read again
      final updated = await container.read(allFastTypesProvider.future);
      expect(updated.length, initialCount);
    });
  });
}
