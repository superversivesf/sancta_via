// SqliteProgramRepository tests (Task 5): the persistence seam between the
// devotional engine and the app's SQLite store.
//
// Runs against in-memory databases through the `DevotionalsDatabase`
// open-factory seam and pins:
// - seed → loadPacks round trips and a stable pack order (the `packs` rows'
//   id order, stable across reads),
// - the enroll → saveProgress → progressFor → unenroll lifecycle, including
//   unenroll keeping the pack row while clearing progress, notifications,
//   and the enrollment,
// - re-seeding a new pack version replacing rows by id (no duplicates) and
//   re-stamping `meta.content_version`,
// - re-enrolling replacing the single enrollment row without touching
//   existing progress,
// - the `_packsCache` surface (`clearCache` forces a re-read; seeding
//   invalidates the cache),
// - the safe defaults on database errors (`[]` / null) plus `AppLogger.error`.
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sancta_via_devotional_engine_riverpod/sancta_via_devotional_engine_riverpod.dart';
import 'package:sancta_via_devotionals/database/database_migration_service.dart';
import 'package:sancta_via_devotionals/database/devotionals_database.dart';
import 'package:sancta_via_devotionals/repositories/program_repository.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Opens a fresh, isolated in-memory database backed by the FFI factory.
Future<Database> _openInMemory() {
  return openDatabase(inMemoryDatabasePath, singleInstance: false);
}

/// Builds a minimal valid [ContentPack] with the given [id] and [title].
///
/// Parsed through the engine's [PackLoader] so the test exercises the same
/// JSON round trip the app's content pipeline will seed through.
ContentPack _pack(String id, {String? title}) {
  final String packTitle = title ?? 'Pack $id';
  final Map<String, dynamic> json = <String, dynamic>{
    'id': id,
    'title': packTitle,
    'family': 'routine',
    'schedule': <String, dynamic>{
      'type': 'timeOfDay',
      'hour': 6,
      'minute': 0,
      'baseLabel': id,
    },
    'session': <String, dynamic>{
      'id': '$id-session',
      'steps': <Map<String, dynamic>>[
        <String, dynamic>{
          'type': 'prayer',
          'id': '$id-step',
          'title': 'Prayer',
          'contentRef': '$id-prayer',
        },
      ],
    },
    'content': <String, dynamic>{
      '$id-prayer': <String, dynamic>{
        'id': '$id-prayer',
        'text': 'Text for $id.',
        'source': 'Test source',
        'license': 'test',
      },
    },
  };
  return PackLoader.loadFromJsonString(jsonEncode(json));
}

/// A database whose reads fail, for the safe-default error paths.
class _ThrowingDevotionalsDatabase extends DevotionalsDatabase {
  _ThrowingDevotionalsDatabase()
    : super(open: () async => throw StateError('database unavailable'));

  @override
  Future<List<PackRow>> getAllPacks() async {
    throw StateError('packs read failed');
  }

  @override
  Future<ProgressRow?> getProgress(String packId) async {
    throw StateError('progress read failed');
  }

  @override
  Future<EnrollmentRow?> getEnrollment(String packId) async {
    throw StateError('enrollment read failed');
  }

  @override
  Future<String?> getMeta(String key) async {
    throw StateError('meta read failed');
  }
}

void main() {
  late DevotionalsDatabase database;
  late SqliteProgramRepository repository;
  late List<String> logs;
  late DebugPrintCallback originalDebugPrint;

  setUp(() {
    database = DevotionalsDatabase(open: _openInMemory);
    repository = SqliteProgramRepository(database: database);
    logs = <String>[];
    originalDebugPrint = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {
      if (message != null) {
        logs.add(message);
      }
    };
  });

  tearDown(() async {
    debugPrint = originalDebugPrint;
    await database.close();
  });

  group('corrupt rows', () {
    test('a corrupt packs row is skipped and logged while the good rows '
        'still load', () async {
      await repository.seedPacks(<ContentPack>[
        _pack('good-a'),
        _pack('good-b'),
      ], packVersion: '1.0.0');
      await database.upsertPack(
        id: 'broken-pack',
        json: '{not valid json',
        packVersion: '1.0.0',
        embeddedAt: '2026-11-12T00:00:00Z',
      );
      repository.clearCache();

      final List<ContentPack> loaded = await repository.loadPacks();
      expect(
        <String>[for (final ContentPack pack in loaded) pack.id],
        <String>['good-a', 'good-b'],
      );
      expect(
        logs.any(
          (String line) =>
              line.contains('Failed to parse pack row "broken-pack"'),
        ),
        isTrue,
      );
    });

    test('a corrupt progress state logs distinctly and still reads as '
        'absent', () async {
      await database.saveProgress(
        packId: 'broken-progress',
        stateJson: '{not valid json',
        updatedAt: '2026-11-12T00:00:00Z',
      );

      expect(await repository.progressFor('broken-progress'), isNull);
      expect(
        logs.any(
          (String line) =>
              line.contains('present but unparsable') &&
              line.contains('broken-progress'),
        ),
        isTrue,
      );
      // The row is left in place for Task 9 to reconcile; reading does not
      // delete or overwrite it.
      expect(await database.getProgress('broken-progress'), isNotNull);
    });
  });

  group('seedPacks and loadPacks', () {
    test('returns [] before any seed (the caller seeds first)', () async {
      expect(await repository.loadPacks(), isEmpty);
      expect(await repository.persistedPackVersion(), isNull);
    });

    test(
      'seeds packs and returns them in a stable id order across reads',
      () async {
        final ContentPack packC = _pack('c-pack', title: 'Third');
        final ContentPack packA = _pack('a-pack', title: 'First');
        final ContentPack packB = _pack('b-pack', title: 'Second');

        await repository.seedPacks(<ContentPack>[
          packC,
          packA,
          packB,
        ], packVersion: '1.0.0');

        final List<ContentPack> first = await repository.loadPacks();
        expect(
          <String>[for (final ContentPack pack in first) pack.id],
          <String>['a-pack', 'b-pack', 'c-pack'],
        );
        expect(first.first.toJson(), packA.toJson());
        expect(await repository.persistedPackVersion(), '1.0.0');

        // Every seeded row carries the version stamp.
        for (final PackRow row in await database.getAllPacks()) {
          expect(row.packVersion, '1.0.0');
          expect(row.embeddedAt, isNotEmpty);
        }

        // The cached read is the same stable order.
        final List<ContentPack> second = await repository.loadPacks();
        expect(
          <String>[for (final ContentPack pack in second) pack.id],
          <String>['a-pack', 'b-pack', 'c-pack'],
        );
      },
    );
  });

  group('enrollment and progress lifecycle', () {
    test('enroll stores params, saveProgress round trips, unenroll clears '
        'progress and notifications but keeps the pack row', () async {
      final ContentPack pack = _pack('lifecycle-pack');
      await repository.seedPacks(<ContentPack>[pack], packVersion: '1.0.0');

      await repository.enroll('lifecycle-pack', <String, dynamic>{
        'start': '2026-12-01',
        'intentions': <String>['for a friend'],
      });
      expect(
        await repository.enrollmentParamsFor('lifecycle-pack'),
        <String, dynamic>{
          'start': '2026-12-01',
          'intentions': <String>['for a friend'],
        },
      );

      final ProgressState state = ProgressState(
        packId: 'lifecycle-pack',
        fulfilledOrdinals: 2,
        lastFulfilled: DateTime(2026, 11, 11),
        repetitionsToday: 3,
        completedItemsByDay: <String, String>{'confession:2026-11-11': 'done'},
        badges: <BadgeRecord>[
          BadgeRecord(title: 'First week', date: DateTime(2026, 11, 10)),
        ],
      );
      await repository.saveProgress(state);

      final ProgressState? restored = await repository.progressFor(
        'lifecycle-pack',
      );
      expect(restored, isNotNull);
      expect(restored!.packId, 'lifecycle-pack');
      expect(restored.fulfilledOrdinals, 2);
      expect(restored.lastFulfilled, DateTime(2026, 11, 11));
      expect(restored.repetitionsToday, 3);
      expect(restored.completedItemsByDay, <String, String>{
        'confession:2026-11-11': 'done',
      });
      expect(restored.badges, hasLength(1));
      expect(restored.badges.single.title, 'First week');
      expect(restored.badges.single.date, DateTime(2026, 11, 10));

      await database.upsertNotification(
        id: 'n1',
        packId: 'lifecycle-pack',
        fireAt: '2026-11-12T06:30:00Z',
        title: 'Today',
        body: 'Day 3 is ready',
        deepLink: '/today',
        status: 'scheduled',
      );

      await repository.unenroll('lifecycle-pack');

      expect(await repository.enrollmentParamsFor('lifecycle-pack'), isNull);
      expect(await repository.progressFor('lifecycle-pack'), isNull);
      expect(await database.getNotificationsForPack('lifecycle-pack'), isEmpty);
      // The pack row is content, not user state: unenroll keeps it.
      expect(await database.getPack('lifecycle-pack'), isNotNull);
      expect(await repository.loadPacks(), hasLength(1));
    });

    test('re-enrolling replaces the single enrollment row without touching '
        'existing progress', () async {
      await repository.seedPacks(<ContentPack>[
        _pack('re-enroll-pack'),
      ], packVersion: '1.0.0');
      final ProgressState state = ProgressState(
        packId: 're-enroll-pack',
        fulfilledOrdinals: 1,
      );
      await repository.saveProgress(state);

      await repository.enroll('re-enroll-pack', <String, dynamic>{
        'start': '2026-12-01',
      });
      await repository.enroll('re-enroll-pack', <String, dynamic>{
        'start': '2026-12-08',
      });

      expect(
        await repository.enrollmentParamsFor('re-enroll-pack'),
        <String, dynamic>{'start': '2026-12-08'},
      );
      expect(await database.getAllEnrollments(), hasLength(1));
      expect(
        (await repository.progressFor('re-enroll-pack'))!.fulfilledOrdinals,
        1,
      );
    });
  });

  group('re-seeding', () {
    test('a new pack version replaces the rows of every pack id without '
        'duplicates', () async {
      await repository.seedPacks(<ContentPack>[
        _pack('first-pack', title: 'Old first'),
        _pack('second-pack', title: 'Old second'),
      ], packVersion: '1.0.0');

      await repository.seedPacks(<ContentPack>[
        _pack('first-pack', title: 'New first'),
        _pack('second-pack', title: 'New second'),
      ], packVersion: '1.1.0');

      final List<ContentPack> loaded = await repository.loadPacks();
      expect(
        <String>[for (final ContentPack pack in loaded) pack.id],
        <String>['first-pack', 'second-pack'],
      );
      expect(
        <String>[for (final ContentPack pack in loaded) pack.title],
        <String>['New first', 'New second'],
      );
      expect(await database.getAllPacks(), hasLength(2));
      expect((await database.getPack('first-pack'))!.packVersion, '1.1.0');
      expect(await repository.persistedPackVersion(), '1.1.0');
      expect(
        await database.getMeta(DatabaseMigrationService.contentVersionMetaKey),
        '1.1.0',
      );
    });
  });

  group('pack cache', () {
    test('clearCache forces a re-read of the packs rows', () async {
      await repository.seedPacks(<ContentPack>[
        _pack('cached-pack'),
      ], packVersion: '1.0.0');
      expect(await repository.loadPacks(), hasLength(1));

      // A direct row write bypasses the repository (and its cache).
      await database.upsertPack(
        id: 'bypass-pack',
        json: jsonEncode(_pack('bypass-pack').toJson()),
        packVersion: '1.0.0',
        embeddedAt: '2026-11-12T00:00:00Z',
      );
      expect(await repository.loadPacks(), hasLength(1));

      repository.clearCache();
      expect(await repository.loadPacks(), hasLength(2));
    });

    test('seedPacks invalidates the cache', () async {
      await repository.seedPacks(<ContentPack>[
        _pack('seed-a'),
      ], packVersion: '1.0.0');
      expect(await repository.loadPacks(), hasLength(1));

      await repository.seedPacks(<ContentPack>[
        _pack('seed-a'),
        _pack('seed-b'),
      ], packVersion: '2.0.0');

      expect(await repository.loadPacks(), hasLength(2));
    });
  });

  group('safe defaults on database errors', () {
    test('loadPacks returns [] and logs', () async {
      final SqliteProgramRepository failing = SqliteProgramRepository(
        database: _ThrowingDevotionalsDatabase(),
      );

      expect(await failing.loadPacks(), isEmpty);
      expect(
        logs.any(
          (String line) => line.contains('Failed to load program packs'),
        ),
        isTrue,
      );
    });

    test('progressFor returns null and logs', () async {
      final SqliteProgramRepository failing = SqliteProgramRepository(
        database: _ThrowingDevotionalsDatabase(),
      );

      expect(await failing.progressFor('any-pack'), isNull);
      expect(
        logs.any(
          (String line) =>
              line.contains('Failed to load progress for "any-pack"'),
        ),
        isTrue,
      );
    });

    test('enrollmentParamsFor returns null and logs', () async {
      final SqliteProgramRepository failing = SqliteProgramRepository(
        database: _ThrowingDevotionalsDatabase(),
      );

      expect(await failing.enrollmentParamsFor('any-pack'), isNull);
      expect(
        logs.any(
          (String line) =>
              line.contains('Failed to load enrollment params for "any-pack"'),
        ),
        isTrue,
      );
    });

    test('persistedPackVersion returns null and logs', () async {
      final SqliteProgramRepository failing = SqliteProgramRepository(
        database: _ThrowingDevotionalsDatabase(),
      );

      expect(await failing.persistedPackVersion(), isNull);
      expect(
        logs.any(
          (String line) =>
              line.contains('Failed to read persisted pack version'),
        ),
        isTrue,
      );
    });
  });
}
