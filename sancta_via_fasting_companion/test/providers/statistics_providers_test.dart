import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sancta_via_fasting_companion/database/database_migration_service.dart';
import 'package:sancta_via_fasting_companion/database/fasting_database.dart';
import 'package:sancta_via_fasting_companion/models/fast_session.dart';
import 'package:sancta_via_fasting_companion/models/fast_status.dart';
import 'package:sancta_via_fasting_companion/providers/fast_type_providers.dart';
import 'package:sancta_via_fasting_companion/providers/statistics_providers.dart';
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
          'test_stats_${DateTime.now().microsecondsSinceEpoch}_${testCounter++}.db',
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

  group('Statistics Providers', () {
    setUp(() async {
      // Create test data - 5 completed fasts
      final now = DateTime.now();
      for (int i = 0; i < 5; i++) {
        final session = FastSession(
          id: 'test_$i',
          fastTypeId: 'intermittent_16_8',
          startTime: now.subtract(Duration(hours: 16, days: i)),
          endTime: now.subtract(Duration(days: i)),
          targetDurationMinutes: 960,
          status: FastStatus.completed,
        );
        await database.insertFastSession(session);
      }

      // Create 1 broken fast
      final broken = FastSession(
        id: 'broken',
        fastTypeId: 'daily_24hr',
        startTime: now.subtract(const Duration(hours: 10)),
        endTime: now.subtract(const Duration(hours: 2)),
        targetDurationMinutes: 1440,
        status: FastStatus.broken,
      );
      await database.insertFastSession(broken);
    });

    test('completedFastsCountProvider should return count', () async {
      final count = await container.read(completedFastsCountProvider.future);
      expect(count, 5);
    });

    test('totalHoursFastedProvider should calculate total', () async {
      final hours = await container.read(totalHoursFastedProvider.future);
      expect(hours, greaterThan(0));
      expect(hours, closeTo(80.0, 1.0)); // 5 fasts * 16 hours each
    });

    test('averageFastDurationProvider should calculate average', () async {
      final average =
          await container.read(averageFastDurationProvider.future);
      expect(average, greaterThan(0));
      expect(average, closeTo(16.0, 1.0)); // 16 hours average
    });

    test('completionRateProvider should calculate rate', () async {
      final rate = await container.read(completionRateProvider.future);
      expect(rate, closeTo(5 / 6, 0.01)); // 5 completed, 1 broken
    });

    test('currentStreakProvider should calculate streak', () async {
      final streak = await container.read(currentStreakProvider.future);
      expect(streak, greaterThanOrEqualTo(0));
    });

    test('longestStreakProvider should calculate longest streak', () async {
      final streak = await container.read(longestStreakProvider.future);
      expect(streak, greaterThanOrEqualTo(0));
    });

    test('mostCommonFastTypeProvider should return most common type',
        () async {
      final mostCommon =
          await container.read(mostCommonFastTypeProvider.future);
      expect(mostCommon, isNotNull);
      expect(mostCommon!.id, 'intermittent_16_8');
    });

    test('dashboardStatisticsProvider should combine all stats', () async {
      final stats = await container.read(dashboardStatisticsProvider.future);

      expect(stats.completedFastsCount, 5);
      expect(stats.totalHoursFasted, greaterThan(0));
      expect(stats.averageDuration, greaterThan(0));
      expect(stats.completionRate, greaterThan(0));
      expect(stats.mostCommonFastType, isNotNull);
    });
  });

  group('Statistics with No Data', () {
    test('should handle no completed fasts gracefully', () async {
      final count = await container.read(completedFastsCountProvider.future);
      expect(count, 0);

      final hours = await container.read(totalHoursFastedProvider.future);
      expect(hours, 0.0);

      final average =
          await container.read(averageFastDurationProvider.future);
      expect(average, 0.0);

      final rate = await container.read(completionRateProvider.future);
      expect(rate, 0.0);

      final currentStreak = await container.read(currentStreakProvider.future);
      expect(currentStreak, 0);

      final longestStreak = await container.read(longestStreakProvider.future);
      expect(longestStreak, 0);

      final mostCommon =
          await container.read(mostCommonFastTypeProvider.future);
      expect(mostCommon, isNull);
    });
  });

  group('Dashboard Statistics', () {
    test('DashboardStatistics should have all required fields', () {
      const stats = DashboardStatistics(
        completedFastsCount: 10,
        totalHoursFasted: 100.0,
        currentStreak: 5,
        longestStreak: 10,
        completionRate: 0.9,
        averageDuration: 10.0,
      );

      expect(stats.completedFastsCount, 10);
      expect(stats.totalHoursFasted, 100.0);
      expect(stats.currentStreak, 5);
      expect(stats.longestStreak, 10);
      expect(stats.completionRate, 0.9);
      expect(stats.averageDuration, 10.0);
      expect(stats.mostCommonFastType, isNull);
    });
  });
}
