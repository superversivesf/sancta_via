// ContentAssetService tests (Plan 2, Task 6): the app-local content asset
// pipeline + first-launch migration.
//
// The engine fixtures are copied byte-for-byte into `assets/content/packs/`
// (the pin test `content_app_asset_pin_test.dart` guards that); the unit tests
// here stage the same documents in a fake `AssetBundle` that serves the
// manifest and bytes the way the real bundle does, backed by FFI in-memory
// SQLite stores through the pinned `DevotionalsDatabase` open seam.
//
// Pins:
// - a fresh store is seeded with the whole asset catalog (repository id
//   order) and `meta.content_version` is stamped, equal to every seeded
//   row's `pack_version`,
// - the content version is stable: two fresh stores with the same assets
//   compute the same version,
// - a second `ensureContentLoaded` with unchanged assets does not re-seed
//   (seed-call counter) and leaves every seeded row untouched,
// - a bumped fixture asset changes the version and re-seeds,
// - a malformed asset (broken JSON syntax / structurally invalid pack)
//   throws `ContentValidationException` naming the file, carrying the engine
//   problems, and seeds nothing,
// - two assets declaring the same pack id are an authoring error,
// - a bundle with no pack assets is an authoring error,
// - reconciliation prunes store rows absent from the bundle BEFORE the
//   version stamp (fix round 1): a failed prune leaves the version
//   unadvanced (the next call retries) and the prune-before-stamp order
//   keeps the post-prune catalog authoritative,
// - the seeded catalog reads back whole through the repository.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sancta_via_devotional_engine/sancta_via_devotional_engine.dart';
import 'package:sancta_via_devotionals/database/database_migration_service.dart';
import 'package:sancta_via_devotionals/database/devotionals_database.dart';
import 'package:sancta_via_devotionals/repositories/program_repository.dart';
import 'package:sancta_via_devotionals/services/content_asset_service.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// The committed pack assets, in filename order (filename == pack id stem for
/// the engine fixture set).
const List<String> _packFilenames = <String>[
  'angelus.json',
  'divine_mercy_novena.json',
  'five_first_saturdays.json',
  'mercy_hour.json',
  'nine_first_fridays.json',
  'novena_54_day.json',
  'rosary.json',
  'total_consecration.json',
];

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

/// A fake [AssetBundle] serving a StandardMessageCodec-encoded
/// `AssetManifest.bin` (what [AssetManifest.loadFromAssetBundle] reads) plus
/// the UTF-8 bytes of each staged asset — the two surfaces the content
/// pipeline reads.
class _FakeAssetBundle extends AssetBundle {
  _FakeAssetBundle({
    required Map<String, String> assets,
    List<String>? declaredKeys,
  }) : _assets = assets,
       _declaredKeys = List<String>.unmodifiable(
         (declaredKeys ?? assets.keys.toList())..sort(),
       );

  final Map<String, String> _assets;
  final List<String> _declaredKeys;

  static ByteData _encodeManifest(List<String> keys) {
    final Map<Object?, Object?> data = <Object?, Object?>{
      for (final String key in keys)
        key: <Map<Object?, Object?>>[
          <Object?, Object?>{'asset': key},
        ],
    };
    return const StandardMessageCodec().encodeMessage(data)!;
  }

  @override
  Future<ByteData> load(String key) async {
    if (key == 'AssetManifest.bin') {
      return _FakeAssetBundle._encodeManifest(_declaredKeys);
    }
    final String? content = _assets[key];
    if (content == null) {
      throw StateError('asset not staged: $key');
    }
    return ByteData.sublistView(utf8.encode(content));
  }
}

/// Reads the committed pack assets (regenerated there by copy whenever the
/// engine fixtures change) into a fake-bundle staging map keyed by bundle
/// path, optionally adding [extra] staged entries.
Map<String, String> _stagedAssets({
  Map<String, String> extra = const <String, String>{},
}) {
  return <String, String>{
    for (final String name in _packFilenames)
      'assets/content/packs/$name': File(
        'assets/content/packs/$name',
      ).readAsStringSync(),
    ...extra,
  };
}

/// Re-encodes the angelus fixture with a bumped title — different bytes, so a
/// different content version.
Map<String, String> _stagedAssetsWithBumpedAngelus() {
  final Map<String, String> staged = _stagedAssets();
  const String key = 'assets/content/packs/angelus.json';
  final Map<String, dynamic> decoded =
      jsonDecode(staged[key]!) as Map<String, dynamic>;
  decoded['title'] = '${decoded['title']} (bumped)';
  staged[key] = jsonEncode(decoded);
  return staged;
}

/// A syntactically broken JSON document (throws from the JSON decoder).
const String _brokenSyntaxJson = '{"id": "broken", "unterminated": ';

/// A syntactically valid JSON document that fails the engine's content
/// validation (no schedule, no session, no content).
const String _structurallyInvalidJson = '{"id": "broken", "title": "Broken"}';

/// A minimal VALID pack document, for pre-seeding a store row that no longer
/// exists in the bundle (the removed-pack reconciliation case).
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

/// A repository that counts [SqliteProgramRepository.seedPacks] calls, so the
/// no-re-seed pin is observable without weakening the concrete class.
class _SeedCountingRepository extends SqliteProgramRepository {
  _SeedCountingRepository({required super.database});

  int seedPacksCalls = 0;

  @override
  Future<void> seedPacks(
    List<ContentPack> packs, {
    required String packVersion,
  }) {
    seedPacksCalls++;
    return super.seedPacks(packs, packVersion: packVersion);
  }
}

/// A fresh FFI in-memory store open factory (isolated per call).
Future<Database> _openInMemory() =>
    openDatabase(inMemoryDatabasePath, singleInstance: false);

/// A store whose `deletePack` fails until [pruneBroken] flips — the retry pin
/// for prune-before-stamp reconciliation (fix round 1).
class _PruneSwitchDatabase extends DevotionalsDatabase {
  _PruneSwitchDatabase({required super.open});

  bool pruneBroken = true;

  @override
  Future<bool> deletePack(String id) async {
    if (pruneBroken) {
      throw StateError('prune unavailable');
    }
    return super.deletePack(id);
  }
}

/// The harness built by [_openService]: a fresh in-memory store, the seed
/// counter, and the service wired to both.
typedef _ServiceHarness = (
  DevotionalsDatabase,
  _SeedCountingRepository,
  ContentAssetService,
);

/// Builds a service wired to a fresh in-memory store over the given staged
/// assets.
Future<_ServiceHarness> _openService(Map<String, String> staged) async {
  final DevotionalsDatabase database = DevotionalsDatabase(open: _openInMemory);
  final _SeedCountingRepository repository = _SeedCountingRepository(
    database: database,
  );
  return (
    database,
    repository,
    ContentAssetService(
      assets: _FakeAssetBundle(assets: staged),
      repository: repository,
      database: database,
    ),
  );
}

void main() {
  group('ContentAssetService', () {
    test(
      'fresh store seeds the whole asset catalog and stamps the content version',
      () async {
        final (
          DevotionalsDatabase database,
          _SeedCountingRepository repository,
          ContentAssetService service,
        ) = await _openService(
          _stagedAssets(),
        );

        final List<ContentPack> catalog = await service.ensureContentLoaded();

        expect(repository.seedPacksCalls, 1);
        expect(catalog, hasLength(_packFilenames.length));
        expect(catalog.map((ContentPack p) => p.id), _packIds);

        // The seed stamped meta.content_version and every pack row carries it.
        final String? version = await repository.persistedPackVersion();
        expect(version, isNotNull);
        expect(version, isNot(isEmpty));
        final List<PackRow> rows = await database.getAllPacks();
        expect(rows, hasLength(_packFilenames.length));
        expect(
          rows.map((PackRow row) => row.packVersion),
          everyElement(version!),
        );

        // The catalog reads back from the store, not just from the bundle.
        final List<ContentPack> stored = await repository.loadPacks();
        expect(stored.map((ContentPack p) => p.id), _packIds);
      },
    );

    test(
      'same assets compute the same content version on a fresh store',
      () async {
        Future<String> seedAndVersion() async {
          final (
            _,
            _SeedCountingRepository repository,
            ContentAssetService service,
          ) = await _openService(
            _stagedAssets(),
          );
          await service.ensureContentLoaded();
          return (await repository.persistedPackVersion())!;
        }

        final String first = await seedAndVersion();
        final String second = await seedAndVersion();
        expect(second, first);
      },
    );

    test('second call with unchanged assets does not re-seed', () async {
      final (
        DevotionalsDatabase database,
        _SeedCountingRepository repository,
        ContentAssetService service,
      ) = await _openService(
        _stagedAssets(),
      );

      final List<ContentPack> first = await service.ensureContentLoaded();
      expect(repository.seedPacksCalls, 1);
      final List<PackRow> before = await database.getAllPacks();

      final List<ContentPack> second = await service.ensureContentLoaded();

      expect(repository.seedPacksCalls, 1, reason: 'no re-seed');
      final List<PackRow> after = await database.getAllPacks();
      expect(
        after.map((PackRow row) => row.embeddedAt),
        before.map((PackRow row) => row.embeddedAt),
        reason: 'seeded rows stay untouched when the version matches',
      );
      expect(
        second.map((ContentPack p) => p.id),
        first.map((ContentPack p) => p.id),
      );
    });

    test('a bumped fixture asset changes the version and re-seeds', () async {
      final (
        DevotionalsDatabase database,
        _SeedCountingRepository repository,
        ContentAssetService service,
      ) = await _openService(
        _stagedAssets(),
      );
      await service.ensureContentLoaded();
      final String? oldVersion = await repository.persistedPackVersion();

      final ContentAssetService bumpedService = ContentAssetService(
        assets: _FakeAssetBundle(assets: _stagedAssetsWithBumpedAngelus()),
        repository: repository,
        database: database,
      );
      final List<ContentPack> catalog = await bumpedService
          .ensureContentLoaded();

      expect(repository.seedPacksCalls, 2, reason: 'bumped assets re-seed');
      final String? newVersion = await repository.persistedPackVersion();
      expect(newVersion, isNotNull);
      expect(newVersion, isNot(equals(oldVersion)));
      final ContentPack angelus = catalog.singleWhere(
        (ContentPack p) => p.id == 'angelus',
      );
      expect(angelus.title, contains('(bumped)'));
      final PackRow row = (await database.getPack('angelus'))!;
      expect(row.packVersion, newVersion);
    });

    test(
      'malformed asset throws ContentValidationException naming the file and seeds nothing',
      () async {
        final (
          _,
          _SeedCountingRepository repository,
          ContentAssetService service,
        ) = await _openService(
          _stagedAssets(
            extra: <String, String>{
              'assets/content/packs/broken.json': _brokenSyntaxJson,
            },
          ),
        );

        await expectLater(
          service.ensureContentLoaded(),
          throwsA(
            isA<ContentValidationException>().having(
              (ContentValidationException e) => e.message,
              'message',
              contains('assets/content/packs/broken.json'),
            ),
          ),
        );
        expect(repository.seedPacksCalls, 0);
        expect(await repository.persistedPackVersion(), isNull);
      },
    );

    test(
      'structurally invalid pack throws ContentValidationException naming the file with the engine problems',
      () async {
        final (
          _,
          _SeedCountingRepository repository,
          ContentAssetService service,
        ) = await _openService(
          _stagedAssets(
            extra: <String, String>{
              'assets/content/packs/broken.json': _structurallyInvalidJson,
            },
          ),
        );

        await expectLater(
          service.ensureContentLoaded(),
          throwsA(
            isA<ContentValidationException>()
                .having(
                  (ContentValidationException e) => e.message,
                  'message',
                  contains('assets/content/packs/broken.json'),
                )
                .having(
                  (ContentValidationException e) => e.problems,
                  'problems',
                  everyElement(contains('assets/content/packs/broken.json')),
                ),
          ),
        );
        expect(repository.seedPacksCalls, 0);
      },
    );

    test(
      'two assets declaring the same pack id are an authoring error',
      () async {
        final (
          _,
          _SeedCountingRepository repository,
          ContentAssetService service,
        ) = await _openService(
          _stagedAssets(
            extra: <String, String>{
              'assets/content/packs/angelus_copy.json': File(
                'assets/content/packs/angelus.json',
              ).readAsStringSync(),
            },
          ),
        );

        await expectLater(
          service.ensureContentLoaded(),
          throwsA(
            isA<ContentValidationException>().having(
              (ContentValidationException e) => e.message,
              'message',
              contains('angelus'),
            ),
          ),
        );
        expect(repository.seedPacksCalls, 0);
      },
    );

    test('a bundle with no pack assets is an authoring error', () async {
      final (
        _,
        _SeedCountingRepository repository,
        ContentAssetService service,
      ) = await _openService(
        <String, String>{},
      );

      await expectLater(
        service.ensureContentLoaded(),
        throwsA(
          isA<ContentValidationException>().having(
            (ContentValidationException e) => e.message,
            'message',
            contains('assets/content/packs'),
          ),
        ),
      );
      expect(repository.seedPacksCalls, 0);
    });

    test(
      'a failed prune aborts before the stamp and is retried on the next call',
      () async {
        final _PruneSwitchDatabase database = _PruneSwitchDatabase(
          open: _openInMemory,
        );
        await database.upsertPack(
          id: 'zombie_pack',
          json: _minimalPackJson('zombie_pack'),
          packVersion: 'v-old',
          embeddedAt: '2026-01-01T00:00:00Z',
        );
        // The store carries a previous migration's stamp, so this call is a
        // real version advance — a failed prune must leave it unadvanced.
        await database.setMeta(
          DatabaseMigrationService.contentVersionMetaKey,
          'v-old',
        );
        final _SeedCountingRepository repository = _SeedCountingRepository(
          database: database,
        );
        final ContentAssetService service = ContentAssetService(
          assets: _FakeAssetBundle(assets: _stagedAssets()),
          repository: repository,
          database: database,
        );

        await expectLater(
          service.ensureContentLoaded(),
          throwsStateError,
          reason: 'a prune failure aborts the migration',
        );
        expect(repository.seedPacksCalls, 0, reason: 'no seed before an abort');
        expect(
          await repository.persistedPackVersion(),
          'v-old',
          reason:
              'the version must NOT advance past a failed prune, '
              'or the zombie row is permanent',
        );
        expect(await database.getPack('zombie_pack'), isNotNull);

        // The next launch's retry: reconciliation completes, the zombie is
        // pruned, and only then does the version advance.
        database.pruneBroken = false;
        final List<ContentPack> catalog = await service.ensureContentLoaded();
        expect(repository.seedPacksCalls, 1);
        expect(await database.getPack('zombie_pack'), isNull);
        expect(catalog.map((ContentPack p) => p.id), _packIds);
        expect(await repository.persistedPackVersion(), isNot(equals('v-old')));
        final List<PackRow> rows = await database.getAllPacks();
        expect(
          rows.map((PackRow row) => row.packVersion),
          everyElement((await repository.persistedPackVersion())!),
        );
      },
    );

    test(
      'seeding prunes store rows whose id is absent from the bundle',
      () async {
        final DevotionalsDatabase database = DevotionalsDatabase(
          open: _openInMemory,
        );
        await database.upsertPack(
          id: 'zombie_pack',
          json: _minimalPackJson('zombie_pack'),
          packVersion: 'v0',
          embeddedAt: '2026-01-01T00:00:00Z',
        );
        final _SeedCountingRepository repository = _SeedCountingRepository(
          database: database,
        );
        final ContentAssetService service = ContentAssetService(
          assets: _FakeAssetBundle(assets: _stagedAssets()),
          repository: repository,
          database: database,
        );

        // Warm the loadPacks cache with the pre-prune catalog: the
        // reconciliation must not leave that cached view in place (the
        // seed's cache invalidation follows the prune — fix round 1).
        final List<ContentPack> prePrune = await repository.loadPacks();
        expect(prePrune.map((ContentPack p) => p.id), contains('zombie_pack'));

        final List<ContentPack> catalog = await service.ensureContentLoaded();

        expect(await database.getPack('zombie_pack'), isNull);
        expect(catalog.map((ContentPack p) => p.id), _packIds);
        expect(
          (await repository.loadPacks()).map((ContentPack p) => p.id),
          _packIds,
        );
        expect(repository.seedPacksCalls, 1);
      },
    );
  });
}
