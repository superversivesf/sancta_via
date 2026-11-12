// The Today assembler's behaviour pins (Plan 2, Task 12).
//
// Every test runs the REAL production wiring — the app's SQLite repository,
// the content pipeline's seeded catalog (`contentLoadedProvider`), the
// wrapper's `programRepositoryOverride` chain, and the sibling date provider
// frozen with the workspace's `Stream.value` pattern. Nothing here stubs the
// assembly's inputs: the packs are the shipped fixtures, so a label, an
// ordinal, or a feast name changing in content fails a test here.
//
// Date seam (the monorepo gotcha): `currentDateProvider` is the ONLY date
// source. The frozen 2026-12-05 test proves the Angelus resolves its Advent
// label and the Five First Saturdays land in Commitments; the Eastertide
// dates prove the engine (not the test) relabels the Angelus `regina_caeli`
// and resolves the Divine Mercy novena's Easter-anchored day 8.
//
// Brief correction (recorded in the task report): the Divine Mercy novena is
// Easter-anchored, so 2026-04-20 (Easter + 15) is NOT its day 8 — day 8 of
// the 2026 window is Good Friday (2026-04-03) + 7 days = 2026-04-10, which is
// also Eastertide. The Eastertide label pin uses 2026-04-20 (the plan's Task
// 24 date) and the day-8 pin uses 2026-04-10.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sancta_via_devotional_engine/sancta_via_devotional_engine.dart';
import 'package:sancta_via_devotional_engine_riverpod/sancta_via_devotional_engine_riverpod.dart'
    show ProgramRepository, programRepositoryProvider;
import 'package:sancta_via_devotionals/database/devotionals_database.dart';
import 'package:sancta_via_devotionals/providers/app_settings_provider.dart';
import 'package:sancta_via_devotionals/providers/content_providers.dart';
import 'package:sancta_via_devotionals/providers/today_providers.dart';
import 'package:sancta_via_devotionals/repositories/program_repository.dart';
import 'package:sancta_via_liturgical_calendar_riverpod/sancta_via_liturgical_calendar_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// A fresh FFI in-memory store open factory (isolated per call).
Future<Database> _openInMemory() =>
    openDatabase(inMemoryDatabasePath, singleInstance: false);

/// The default anchor times the tests pin against (the app's settings
/// defaults: 6:00 / 12:00 / 18:00 / 15:00).
const AnchorTimes _defaultAnchors = (
  angelusMorning: TimeOfDay(hour: 6, minute: 0),
  angelusNoon: TimeOfDay(hour: 12, minute: 0),
  angelusEvening: TimeOfDay(hour: 18, minute: 0),
  mercyHour: TimeOfDay(hour: 15, minute: 0),
);

/// A minimal VALID pack document whose only schedule is a [TimeOfDaySpec],
/// parsed through the engine's own loader — the synthetic-anchor seam (the
/// shipped catalog carries only 6:00 and 15:00 anchors today; the noon and
/// evening anchors arrive with the Task 24 Angelus schedule).
ContentPack _timeOfDayPack({
  required String id,
  required String title,
  required int hour,
  required int minute,
  required String baseLabel,
}) {
  final String prayerId = '$id-prayer';
  return PackLoader.loadFromJsonString(
    jsonEncode(<String, dynamic>{
      'id': id,
      'title': title,
      'family': 'routine',
      'schedules': <Map<String, dynamic>>[
        <String, dynamic>{
          'type': 'timeOfDay',
          'hour': hour,
          'minute': minute,
          'baseLabel': baseLabel,
        },
      ],
      'session': <String, dynamic>{
        'id': '$id-session',
        'steps': <Map<String, dynamic>>[
          <String, dynamic>{
            'type': 'prayer',
            'id': '$id-step',
            'title': 'Prayer',
            'contentRef': prayerId,
          },
        ],
      },
      'content': <String, dynamic>{
        prayerId: <String, dynamic>{
          'id': prayerId,
          'text': 'Text for $id.',
          'source': 'Test source',
          'license': 'test',
        },
      },
    }),
  );
}

/// A container running the production wiring, with [today] frozen and the
/// shipped catalog seeded; then [enroll] packs and [progress] saved.
///
/// [anchorTimes] replaces the settings anchors (the real provider reads
/// SharedPreferences; the assembly only consumes the resolved [AnchorTimes]).
/// [extraPacks] are seeded AFTER the content pipeline so its removed-pack
/// reconciliation cannot prune them. With [seedFirst] false the store stays
/// unseeded, pinning the assembly's own first-launch migration.
Future<ProviderContainer> _container({
  required DateTime today,
  List<String> enroll = const <String>[],
  Map<String, int> progress = const <String, int>{},
  AnchorTimes anchorTimes = _defaultAnchors,
  List<ContentPack> extraPacks = const <ContentPack>[],
  bool seedFirst = true,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final DevotionalsDatabase database = DevotionalsDatabase(open: _openInMemory);
  final SqliteProgramRepository repository = SqliteProgramRepository(
    database: database,
  );
  final ProviderContainer container = ProviderContainer(
    overrides: <Override>[
      appProgramRepositoryProvider.overrideWithValue(repository),
      // The production chain from main.dart: the wrapper's catalog providers
      // read the app repository.
      programRepositoryOverride,
      currentDateProvider.overrideWith(
        (Ref ref) => Stream<DateTime>.value(today),
      ),
      anchorTimesProvider.overrideWithValue(anchorTimes),
    ],
  );
  addTearDown(container.dispose);

  // The real content pipeline seeds the shipped fixture catalog.
  if (seedFirst) {
    await container.read(contentLoadedProvider.future);
  }
  if (extraPacks.isNotEmpty) {
    await repository.seedPacks(
      extraPacks,
      packVersion: (await repository.persistedPackVersion())!,
    );
  }
  for (final String packId in enroll) {
    await repository.enroll(packId, <String, dynamic>{'via': 'test'});
  }
  for (final MapEntry<String, int> entry in progress.entries) {
    await repository.saveProgress(
      ProgressState(packId: entry.key, fulfilledOrdinals: entry.value),
    );
  }
  return container;
}

/// The assembled day for [container].
Future<TodayAssembly> _assembly(ProviderContainer container) {
  return container.read(todayAssemblyProvider.future);
}

/// The pack ids of [items], in assembly order.
List<String> _ids(List<TodayItem> items) => <String>[
  for (final TodayItem item in items) item.pack?.id ?? 'feast:${item.title}',
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'frozen 2026-12-05 assembles Morning, mercy, Commitments, and Feasts past today',
    () async {
      final ProviderContainer container = await _container(
        today: DateTime(2026, 12, 5),
        enroll: <String>[
          'angelus',
          'mercy_hour',
          'five_first_saturdays',
          'rosary',
          'novena_54_day',
        ],
      );

      final TodayAssembly assembly = await _assembly(container);

      // The assembly's day is the stream's day, reduced to local midnight.
      expect(assembly.date, DateTime(2026, 12, 5));

      // The Angelus' 6:00 TimeOfDaySpec surfaces in Morning, labelled by the
      // engine's own resolution — Advent is not Eastertide, so `angelus`.
      expect(_ids(assembly.morning), <String>['angelus']);
      final TodayItem angelus = assembly.morning.single;
      expect(angelus.title, 'The Angelus (Regina Caeli in Eastertide)');
      expect(angelus.label, 'angelus');
      expect(angelus.ordinalLabel, isNull);
      expect(angelus.anchor, DateTime(2026, 12, 5, 6));
      expect(
        angelus.deepLink,
        '/session/angelus?forDate=2026-12-05',
        reason: 'the deep link carries the assembled day, never the clock day',
      );

      // No 12:00 anchor ships yet; the 15:00 Hour of Mercy is its own
      // subsection of Anchors.
      expect(assembly.anchors, isEmpty);
      expect(_ids(assembly.mercy), <String>['mercy_hour']);
      expect(assembly.mercy.single.label, 'mercy_hour');
      expect(assembly.mercy.single.anchor, DateTime(2026, 12, 5, 15));
      expect(assembly.evening, isEmpty);

      // Due programs, in pack-id order — the First Saturday carries the
      // ordinal the wrapper's due resolution computed (streak + one).
      expect(_ids(assembly.commitments), <String>[
        'five_first_saturdays',
        'novena_54_day',
        'rosary',
      ]);
      final TodayItem firstSaturday = assembly.commitments.first;
      expect(firstSaturday.ordinalLabel, 'ordinal 1');
      expect(firstSaturday.resolution?.ordinal, 1);
      expect(
        firstSaturday.deepLink,
        '/session/five_first_saturdays?forDate=2026-12-05',
      );
      // A novena carries its day index instead of an ordinal.
      final TodayItem novena = assembly.commitments[1];
      expect(novena.ordinalLabel, isNull);
      expect(novena.resolution?.dayIndex, 26);

      // Upcoming feasts: the 14-day window from today, strictly AFTER today.
      expect(assembly.feastsComing.map((TodayItem i) => i.title), <String>[
        'Saint Ambrose, Bishop and Doctor',
        'Immaculate Conception',
        'Saint John of the Cross, Priest and Doctor',
      ]);
      for (final TodayItem feast in assembly.feastsComing) {
        expect(feast.pack, isNull);
        expect(feast.resolution, isNull);
        expect(feast.deepLink, isNull);
        expect(feast.anchor!.isAfter(assembly.date), isTrue);
      }
      expect(assembly.isEmpty, isFalse);
    },
  );

  test('a completed commitment is omitted from the day', () async {
    final ProviderContainer container = await _container(
      today: DateTime(2026, 12, 5),
      enroll: <String>['five_first_saturdays', 'rosary'],
      // The Five First Saturdays is fulfilled: every ordinal is complete, so
      // a completed program is not due (Review Focus 2's exclusion).
      progress: <String, int>{'five_first_saturdays': 5},
    );

    final TodayAssembly assembly = await _assembly(container);

    expect(_ids(assembly.commitments), <String>['rosary']);
    expect(
      assembly.commitments.any(
        (TodayItem item) => item.pack?.id == 'five_first_saturdays',
      ),
      isFalse,
    );
  });

  test('Eastertide relabels the Angelus regina_caeli', () async {
    final ProviderContainer container = await _container(
      today: DateTime(2026, 4, 20),
      enroll: <String>['angelus'],
    );

    final TodayAssembly assembly = await _assembly(container);

    expect(_ids(assembly.morning), <String>['angelus']);
    expect(
      assembly.morning.single.label,
      'regina_caeli',
      reason: 'the engine resolves the Eastertide season variant from the date',
    );
    expect(assembly.morning.single.resolution?.labels, <String>[
      'regina_caeli',
    ]);
  });

  test(
    'the Divine Mercy novena resolves to its Easter-anchored day 8',
    () async {
      // Day 8 = Good Friday + 7 = 2026-04-10 (Easter 2026 is 2026-04-05).
      final ProviderContainer container = await _container(
        today: DateTime(2026, 4, 10),
        enroll: <String>['divine_mercy_novena'],
      );

      final TodayAssembly assembly = await _assembly(container);

      expect(_ids(assembly.commitments), <String>['divine_mercy_novena']);
      expect(assembly.commitments.single.resolution?.dayIndex, 8);
      expect(assembly.commitments.single.ordinalLabel, isNull);
    },
  );

  test('time-of-day anchors land in the section matching their hour', () async {
    final ProviderContainer container = await _container(
      today: DateTime(2026, 12, 5),
      enroll: <String>['noon_anchor', 'evening_anchor', 'night_anchor'],
      extraPacks: <ContentPack>[
        _timeOfDayPack(
          id: 'noon_anchor',
          title: 'Noon Anchor',
          hour: 12,
          minute: 0,
          baseLabel: 'noon',
        ),
        _timeOfDayPack(
          id: 'night_anchor',
          title: 'Night Anchor',
          hour: 20,
          minute: 30,
          baseLabel: 'night',
        ),
        _timeOfDayPack(
          id: 'evening_anchor',
          title: 'Evening Anchor',
          hour: 18,
          minute: 0,
          baseLabel: 'evening',
        ),
      ],
    );

    final TodayAssembly assembly = await _assembly(container);

    expect(_ids(assembly.morning), isEmpty);
    expect(_ids(assembly.anchors), <String>['noon_anchor']);
    expect(assembly.anchors.single.anchor, DateTime(2026, 12, 5, 12));
    expect(_ids(assembly.mercy), isEmpty);
    // 18:00 and 20:30 both belong to the evening; pack id order within it.
    expect(_ids(assembly.evening), <String>['evening_anchor', 'night_anchor']);
    expect(assembly.evening.first.anchor, DateTime(2026, 12, 5, 18));
    expect(assembly.evening.last.anchor, DateTime(2026, 12, 5, 20, 30));
    // Time-of-day anchors are anchors, never due sessions.
    expect(assembly.commitments, isEmpty);
  });

  test('the settings anchor times set the anchor instants', () async {
    final ProviderContainer container = await _container(
      today: DateTime(2026, 12, 5),
      enroll: <String>['angelus', 'mercy_hour'],
      anchorTimes: (
        angelusMorning: const TimeOfDay(hour: 7, minute: 30),
        angelusNoon: const TimeOfDay(hour: 12, minute: 0),
        angelusEvening: const TimeOfDay(hour: 18, minute: 0),
        mercyHour: const TimeOfDay(hour: 15, minute: 30),
      ),
    );

    final TodayAssembly assembly = await _assembly(container);

    expect(assembly.morning.single.anchor, DateTime(2026, 12, 5, 7, 30));
    expect(assembly.mercy.single.anchor, DateTime(2026, 12, 5, 15, 30));
  });

  test('unenrolled packs never surface', () async {
    final ProviderContainer container = await _container(
      today: DateTime(2026, 12, 5),
      // The whole catalog is due today (Angelus always, Rosary daily, the
      // First Saturday on 2026-12-05) — only the enrolled pack may appear.
      enroll: <String>['angelus'],
    );

    final TodayAssembly assembly = await _assembly(container);

    expect(_ids(assembly.morning), <String>['angelus']);
    expect(assembly.commitments, isEmpty);
    expect(assembly.mercy, isEmpty);
    expect(assembly.evening, isEmpty);
    // Liturgical data is not enrollment state: the feast window still shows.
    expect(assembly.feastsComing, isNotEmpty);
  });

  test('an assembly with no enrolled devotions reports isEmpty', () async {
    final ProviderContainer container = await _container(
      today: DateTime(2026, 12, 5),
    );

    final TodayAssembly assembly = await _assembly(container);

    expect(assembly.isEmpty, isTrue);
    expect(assembly.feastsComing, isNotEmpty);
  });

  test('opening Today on a fresh store seeds the catalog through the '
      'assembly', () async {
    // No test-side seed: the assembly's own first-launch migration must run,
    // or a fresh install would render an empty day forever.
    final ProviderContainer container = await _container(
      today: DateTime(2026, 12, 5),
      enroll: <String>['angelus'],
      seedFirst: false,
    );

    final TodayAssembly assembly = await _assembly(container);

    expect(_ids(assembly.morning), <String>['angelus']);
  });

  test('the wrapper repository seam is the app repository', () async {
    // Guards the wiring the assembly relies on: without main.dart's override
    // the due list would flow from the wrapper's in-memory fixtures instead
    // of the seeded app store.
    final ProviderContainer container = await _container(
      today: DateTime(2026, 12, 5),
    );

    final ProgramRepository appRepository = container.read(
      appProgramRepositoryProvider,
    );
    expect(container.read(programRepositoryProvider), same(appRepository));
  });
}
