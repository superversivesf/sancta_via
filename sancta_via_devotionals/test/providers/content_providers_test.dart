// End-to-end wiring test for the content providers (Plan 2, Task 6, fix
// round 1 — review finding 4: the production wiring had zero coverage).
//
// Pumps the REAL override chain `main.dart` installs —
// `programRepositoryOverride` routing the wrapper's program providers through
// `appProgramRepositoryProvider` — in a plain `ProviderContainer`, with the
// REAL rootBundle asset seam (the app pubspec declares the committed fixture
// copies; `content_app_asset_pin_test.dart` pins that) and an FFI in-memory
// store for the app repository.
//
// Pins:
// - `programRepositoryProvider` resolves to the identical app repository
//   instance the container was given,
// - watching `contentLoadedProvider` runs the first-launch migration against
//   the app repository AND prunes a bundle-absent stale row through the
//   repository's OWN store seam (`repository.database`, review finding 3 —
//   a `DevotionalsDatabase.instance` hardcode cannot even reach it under the
//   FFI factory: it would throw instead of pruning),
// - the wrapper's catalog surfaces (`enrolledProgramsProvider`,
//   `todayProgramsProvider`) read the seeded app repository, with the
//   sibling date provider overridden via the workspace's `Stream.value`
//   test pattern.
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sancta_via_devotional_engine_riverpod/sancta_via_devotional_engine_riverpod.dart';
import 'package:sancta_via_devotionals/database/devotionals_database.dart';
import 'package:sancta_via_devotionals/providers/content_providers.dart';
import 'package:sancta_via_devotionals/repositories/program_repository.dart';
import 'package:sancta_via_liturgical_calendar_riverpod/sancta_via_liturgical_calendar_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// The pack ids in repository order (`packs.id ASC`).
const List<String> _packIds = <String>[
  'angelus',
  'divine_mercy_novena',
  'five_first_saturdays',
  'mercy_hour',
  'nine_first_fridays',
  'novena_54_day',
  'rosary',
  'total_consecration',
];

/// A fresh FFI in-memory store open factory (isolated per call).
Future<Database> _openInMemory() =>
    openDatabase(inMemoryDatabasePath, singleInstance: false);

/// A minimal VALID pack document, for pre-seeding a store row that no longer
/// exists in the bundle (the store-seam pin).
String _minimalPackJson(String id) {
  return jsonEncode(<String, dynamic>{
    'id': id,
    'title': 'Pack $id',
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
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'the production override chain seeds the app repository and routes the wrapper providers to it',
    () async {
      final DevotionalsDatabase database = DevotionalsDatabase(
        open: _openInMemory,
      );
      // A row absent from the bundle pins the store seam: the migration must
      // prune it through the repository's own database.
      await database.upsertPack(
        id: 'zombie_pack',
        json: _minimalPackJson('zombie_pack'),
        packVersion: 'v0',
        embeddedAt: '2026-01-01T00:00:00Z',
      );
      final SqliteProgramRepository appRepository = SqliteProgramRepository(
        database: database,
      );

      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          // The app's own repository seam, as a real app install would
          // configure it (main.dart leaves the default resolution; the
          // override here stands in for the runtime store).
          appProgramRepositoryProvider.overrideWithValue(appRepository),
          // The production chain from main.dart.
          programRepositoryOverride,
          // The workspace date-provider test pattern: the real current
          // date's periodic timer never completes inside a test.
          currentDateProvider.overrideWith(
            (Ref ref) => Stream<DateTime>.value(DateTime(2026, 11, 12)),
          ),
        ],
      );
      addTearDown(container.dispose);

      // The wrapper's repository seam IS the app repository instance.
      expect(container.read(programRepositoryProvider), same(appRepository));

      // Watching the catalog runs the first-launch migration against the
      // app repository and its own store.
      final List<ContentPack> catalog = await container.read(
        contentLoadedProvider.future,
      );
      expect(catalog.map((ContentPack p) => p.id), _packIds);
      expect(await appRepository.persistedPackVersion(), isNot(isEmpty));
      expect(
        await database.getPack('zombie_pack'),
        isNull,
        reason:
            'the stale bundle-absent row is pruned through '
            'repository.database, not a separately-opened store',
      );

      // The wrapper's catalog surfaces flow from the seeded app repository.
      final List<EnrolledProgram> enrolled = await container.read(
        enrolledProgramsProvider.future,
      );
      expect(enrolled.map((EnrolledProgram p) => p.pack.id), _packIds);

      final List<DueToday> due = await container.read(
        todayProgramsProvider.future,
      );
      expect(
        due.map((DueToday d) => d.pack.id),
        contains('rosary'),
        reason: 'todayProgramsProvider must read the seeded app repository',
      );
    },
  );

  test(
    'the app repository store flows current intentions through intentionsProvider',
    () async {
      // Fix round 1 (review finding 1): the intercession card's intentions
      // readout was override-tested only; this pins the REAL production
      // wiring — appProgramRepositoryProvider → repository.database
      // .getAllIntentions() — with rows seeded into the app-repository
      // store itself.
      final DevotionalsDatabase database = DevotionalsDatabase(
        open: _openInMemory,
      );
      final SqliteProgramRepository appRepository = SqliteProgramRepository(
        database: database,
      );
      await database.insertIntention(
        id: 'i1',
        kind: 'intention',
        text: 'For the sick',
        createdAt: '2026-01-01T00:00:00Z',
      );
      await database.insertIntention(
        id: 'i2',
        kind: 'soul',
        text: 'For grandpa',
        createdAt: '2026-01-02T00:00:00Z',
      );

      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          appProgramRepositoryProvider.overrideWithValue(appRepository),
        ],
      );
      addTearDown(container.dispose);

      final List<IntentionRow> rows = await container.read(
        intentionsProvider.future,
      );
      // Oldest-first, both kinds (the readout renders every current
      // intention).
      expect(rows.map((IntentionRow r) => r.text), <String>[
        'For the sick',
        'For grandpa',
      ]);
      expect(rows.map((IntentionRow r) => r.kind), <String>[
        'intention',
        'soul',
      ]);
    },
  );
}
