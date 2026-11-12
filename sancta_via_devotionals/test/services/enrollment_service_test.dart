// Enrollment service tests (Plan 2, Task 15).
//
// Pins the commitment-aware derive-and-enroll contract over the REAL shipped
// pack assets and the REAL Task-5 SQLite repository (isolated in-memory FFI
// store), never a hand-shaped stand-in:
//
// 1. the consecration derive patches `schedule.startDate` to
//    `ConsecrationPlanner.startFor(feast)` — 2027-03-25 → 2027-02-20 and the
//    leap-day case 2028-03-25 → 2028-02-21 — while every opaque reminder block
//    survives;
// 2. the 54-day derive patches `startDate` and leaves `startAnchor` (and the
//    rest of the pack) intact;
// 3. enrollment params round-trip through the repository as JSON with dates
//    carried as ISO strings (Task 5's encodability pin);
// 4. re-enrolling (Review Focus 5) replaces the pack row and the params while
//    keeping the single enrollment row and the user's progress;
// 5. commitments enroll as-is with empty params;
// 6. after enrolling, the derived series is due from its own start date on
//    Today through the app's provider chain, and the seeded content version is
//    untouched (no re-seed, no derived-pack clobber).
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sancta_via_devotional_engine/sancta_via_devotional_engine.dart';
import 'package:sancta_via_devotional_engine_riverpod/sancta_via_devotional_engine_riverpod.dart'
    show DueToday, todayProgramsProvider;
import 'package:sancta_via_devotionals/database/devotionals_database.dart';
import 'package:sancta_via_devotionals/providers/content_providers.dart'
    show appProgramRepositoryProvider, programRepositoryOverride;
import 'package:sancta_via_devotionals/repositories/program_repository.dart';
import 'package:sancta_via_devotionals/services/enrollment_service.dart';
import 'package:sancta_via_liturgical_calendar_riverpod/sancta_via_liturgical_calendar_riverpod.dart'
    show currentDateProvider;
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Opens a fresh, isolated in-memory database backed by the FFI factory.
Future<Database> _openInMemory() =>
    openDatabase(inMemoryDatabasePath, singleInstance: false);

/// The real shipped pack asset with [name] (the file stem).
ContentPack _assetPack(String name) {
  return PackLoader.loadFromJsonString(
    File('assets/content/packs/$name.json').readAsStringSync(),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DevotionalsDatabase database;
  late SqliteProgramRepository repository;
  late EnrollmentService service;
  late ContentPack consecration;
  late ContentPack novena;
  late ContentPack commitment;

  setUp(() async {
    database = DevotionalsDatabase(open: _openInMemory);
    repository = SqliteProgramRepository(database: database);
    consecration = _assetPack('total_consecration');
    novena = _assetPack('novena_54_day');
    commitment = _assetPack('five_first_saturdays');
    await repository.seedPacks(<ContentPack>[
      consecration,
      novena,
      commitment,
    ], packVersion: 'seeded-v1');
    service = EnrollmentService(repository: repository);
  });

  group('EnrollmentService.derivePack', () {
    test(
      'consecration patches Day 1 to 33 days before the feast — leap-safe',
      () async {
        // The engine's ConsecrationPlanner startFor pin: 33 calendar days
        // before the nominal feast. 2028 is a leap year, so the same March 25
        // feast starts one day later in February.
        final ContentPack ordinary = await service.derivePack(
          pack: consecration,
          params: <String, dynamic>{'feast': '2027-03-25'},
        );
        final SessionSeriesSpec ordinarySpec =
            ordinary.schedule as SessionSeriesSpec;
        expect(ordinarySpec.startDate, DateTime(2027, 2, 20));
        expect(ordinarySpec.lengthDays, 34);

        final ContentPack leap = await service.derivePack(
          pack: consecration,
          params: <String, dynamic>{'feast': '2028-03-25'},
        );
        final SessionSeriesSpec leapSpec = leap.schedule as SessionSeriesSpec;
        expect(leapSpec.startDate, DateTime(2028, 2, 21));

        // Everything else — the reminder blocks, the days, the session —
        // survives the JSON round trip through PackLoader untouched.
        expect(leap.id, consecration.id);
        expect(leap.title, consecration.title);
        expect(jsonEncode(leap.reminders), jsonEncode(consecration.reminders));
        expect(leap.variants.length, consecration.variants.length);
        expect(leap.session.steps.length, consecration.session.steps.length);
      },
    );

    test(
      '54-day patches startDate and keeps the startAnchor reminder block',
      () async {
        final ContentPack derived = await service.derivePack(
          pack: novena,
          params: <String, dynamic>{
            'startDate': '2026-12-01',
            'restartPolicy': 'strict',
          },
        );

        final SessionSeriesSpec spec = derived.schedule as SessionSeriesSpec;
        expect(spec.startDate, DateTime(2026, 12, 1));
        expect(spec.lengthDays, 54);
        expect(derived.reminders['startAnchor'], isA<Map<String, dynamic>>());
        expect(
          jsonEncode(derived.reminders),
          jsonEncode(novena.reminders),
          reason: 'startAnchor is app metadata and must survive derivation',
        );
        expect(derived.variants.length, novena.variants.length);
      },
    );

    test('commitments derive as-is (nothing to patch)', () async {
      final ContentPack derived = await service.derivePack(
        pack: commitment,
        params: <String, dynamic>{},
      );

      expect(identical(derived, commitment), isTrue);
      expect(derived.schedule, isA<ConsecutiveCommitmentSpec>());
    });
  });

  group('EnrollmentService.enroll', () {
    test(
      'stores JSON-encodable consecration params alongside the derived pack',
      () async {
        await service.enroll(
          pack: consecration,
          params: <String, dynamic>{'feast': '2027-03-25'},
        );

        final Map<String, dynamic>? params = await repository
            .enrollmentParamsFor('total_consecration');
        expect(params, <String, dynamic>{
          'feast': '2027-03-25',
          'startDate': '2027-02-20',
          'day34': '2027-03-25',
        });
        // Task 5's encodability pin: the stored params survive a re-encode.
        expect(jsonEncode(params), isNotEmpty);

        final ContentPack stored = (await repository.loadPacks()).firstWhere(
          (ContentPack pack) => pack.id == 'total_consecration',
        );
        final SessionSeriesSpec spec = stored.schedule as SessionSeriesSpec;
        expect(spec.startDate, DateTime(2027, 2, 20));
        expect(
          jsonEncode(stored.reminders),
          jsonEncode(consecration.reminders),
        );
      },
    );

    test(
      '54-day params carry startDate and the restartPolicy vocabulary',
      () async {
        await service.enroll(
          pack: novena,
          params: <String, dynamic>{
            'startDate': '2026-12-01',
            'restartPolicy': 'permissive',
          },
        );

        expect(
          await repository.enrollmentParamsFor('novena_54_day'),
          <String, dynamic>{
            'startDate': '2026-12-01',
            'restartPolicy': 'permissive',
          },
        );
        final ContentPack stored = (await repository.loadPacks()).firstWhere(
          (ContentPack pack) => pack.id == 'novena_54_day',
        );
        expect(
          (stored.schedule as SessionSeriesSpec).startDate,
          DateTime(2026, 12, 1),
        );
      },
    );

    test(
      're-enrolling replaces the pack and params, keeps progress, and leaves '
      'one enrollment row',
      () async {
        await repository.saveProgress(
          ProgressState(
            packId: 'novena_54_day',
            fulfilledOrdinals: 3,
            lastFulfilled: DateTime(2026, 11, 12),
          ),
        );

        await service.enroll(
          pack: novena,
          params: <String, dynamic>{
            'startDate': '2026-12-01',
            'restartPolicy': 'strict',
          },
        );
        await service.enroll(
          pack: novena,
          params: <String, dynamic>{
            'startDate': '2027-01-05',
            'restartPolicy': 'permissive',
          },
        );

        expect(
          await repository.enrollmentParamsFor('novena_54_day'),
          <String, dynamic>{
            'startDate': '2027-01-05',
            'restartPolicy': 'permissive',
          },
        );
        final ContentPack stored = (await repository.loadPacks()).firstWhere(
          (ContentPack pack) => pack.id == 'novena_54_day',
        );
        expect(
          (stored.schedule as SessionSeriesSpec).startDate,
          DateTime(2027, 1, 5),
        );

        // Progress is user state, not enrollment state: re-enrolling never
        // rewrites it (the repository's `enroll` only upserts the enrollment).
        final ProgressState? after = await repository.progressFor(
          'novena_54_day',
        );
        expect(after, isNotNull);
        expect(after!.fulfilledOrdinals, 3);
        expect(after.lastFulfilled, DateTime(2026, 11, 12));

        final List<EnrollmentRow> enrollments = await database
            .getAllEnrollments();
        expect(enrollments.length, 1);
      },
    );

    test('commitments enroll with empty params and no progress', () async {
      await service.enroll(pack: commitment, params: <String, dynamic>{});

      expect(
        await repository.enrollmentParamsFor('five_first_saturdays'),
        isEmpty,
      );
      expect(
        await repository.progressFor('five_first_saturdays'),
        isNull,
        reason: 'a fresh enrollment starts with no persisted progress',
      );
      final ContentPack stored = (await repository.loadPacks()).firstWhere(
        (ContentPack pack) => pack.id == 'five_first_saturdays',
      );
      expect(jsonEncode(stored.toJson()), jsonEncode(commitment.toJson()));
    });

    test('a derived series is due from its start date on Today, and the seeded '
        'content version is unchanged', () async {
      await service.enroll(
        pack: consecration,
        params: <String, dynamic>{'feast': '2028-03-25'},
      );

      // The seeded version is untouched: enrollment is user state, not a
      // content re-seed (the derived pack row keeps the seeded
      // `pack_version`).
      expect(await repository.persistedPackVersion(), 'seeded-v1');
      final PackRow? row = await database.getPack('total_consecration');
      expect(row, isNotNull);
      expect(row!.packVersion, 'seeded-v1');

      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          appProgramRepositoryProvider.overrideWithValue(repository),
          programRepositoryOverride,
          currentDateProvider.overrideWith(
            (Ref ref) => Stream<DateTime>.value(DateTime(2028, 2, 21)),
          ),
        ],
      );
      addTearDown(container.dispose);

      final List<DueToday> due = await container.read(
        todayProgramsProvider.future,
      );
      final DueToday consecrationToday = due.firstWhere(
        (DueToday entry) => entry.pack.id == 'total_consecration',
      );
      expect(consecrationToday.schedule.due, isTrue);
      expect(consecrationToday.schedule.dayIndex, 1);

      // Day 34 resolves on the feast itself.
      final ContentPack stored = consecrationToday.pack;
      final ScheduleResult day34 = stored.schedule.resolve(
        DateTime(2028, 3, 25),
        const ScheduleContext(),
      );
      expect(day34.due, isTrue);
      expect(day34.dayIndex, 34);
    });

    test(
      'unusable dates and policies are refused, never silently defaulted',
      () async {
        await expectLater(
          service.derivePack(
            pack: consecration,
            params: <String, dynamic>{'feast': '2026-13-05'},
          ),
          throwsArgumentError,
        );
        await expectLater(
          service.derivePack(
            pack: novena,
            params: <String, dynamic>{
              'startDate': '2026-12-01',
              'restartPolicy': 'sometimes',
            },
          ),
          throwsArgumentError,
        );
      },
    );
  });
}
