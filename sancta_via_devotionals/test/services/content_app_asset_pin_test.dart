// App asset pin for the content pipeline (Plan 2, Task 6; mirrors the saint
// companion's app_asset_pin_test pattern).
//
// Regresses the trap that ships a silently blank app: the app pubspec failing
// to declare the content assets (or the committed copies drifting from their
// sources). Sources come in two flavors:
//
// * `sancta_via_devotional_engine/test/fixtures/packs/` — the single source
//   of truth for the EIGHT engine-fixture packs; the committed copies under
//   `assets/content/packs/` must be byte-for-byte identical.
// * The six Task-21 routine packs (offering, examen, lectio, meal/night,
//   fixed morning/night) — AUTHORED in this app's assets, not copied from
//   the engine; `test/content/routine_packs_test.dart` pins their shape, and
//   the committed import mapping under `assets/content/prayers/`.
//
// The REAL rootBundle (not a test fake) must resolve every declared path the
// pipeline keys off:
//
//   1. `AssetManifest.loadFromAssetBundle(rootBundle)` lists exactly the
//      fourteen `assets/content/packs/*.json` keys (the pubspec declares the
//      directory),
//   2. each key loads through the real bundle and parses as a pack,
//   3. every engine-fixture-origin committed copy is byte-identical to its
//      engine fixture.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sancta_via_devotional_engine/sancta_via_devotional_engine.dart';

/// The committed pack assets, in filename order (the pins' order).
const List<String> _packFilenames = <String>[
  'angelus.json',
  'daily_examen.json',
  'divine_mercy_novena.json',
  'five_first_saturdays.json',
  'fixed_prayers_morning.json',
  'fixed_prayers_night.json',
  'lectio_divina.json',
  'meal_night_prayers.json',
  'mercy_hour.json',
  'morning_offering.json',
  'nine_first_fridays.json',
  'novena_54_day.json',
  'rosary.json',
  'total_consecration.json',
];

/// The engine-fixture-origin pack assets (byte-for-byte copies). The Task-21
/// routine packs are absent here on purpose: they are authored in the app's
/// assets, not copied from the engine fixtures.
const List<String> _engineFixtureFilenames = <String>[
  'angelus.json',
  'divine_mercy_novena.json',
  'five_first_saturdays.json',
  'mercy_hour.json',
  'nine_first_fridays.json',
  'novena_54_day.json',
  'rosary.json',
  'total_consecration.json',
];

/// Relative path of the engine fixtures the app assets were copied from.
const String _engineFixturesDir =
    '../sancta_via_devotional_engine/test/fixtures/packs';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'the real rootBundle declares and serves assets/content/packs/*.json',
    () async {
      final AssetManifest manifest = await AssetManifest.loadFromAssetBundle(
        rootBundle,
      );
      final List<String> declared =
          manifest.listAssets().where(_isPackAsset).toList()..sort();

      expect(
        declared,
        <String>[
          for (final String name in _packFilenames)
            'assets/content/packs/$name',
        ],
        reason:
            'the app pubspec must declare assets/content/packs/ so the '
            'content pipeline finds the catalog',
      );
      for (final String key in declared) {
        final ByteData data = await rootBundle.load(key);
        final ContentPack pack = PackLoader.loadFromJsonString(
          utf8.decode(Uint8List.sublistView(data)),
        );
        expect(
          pack.id,
          key.substring('assets/content/packs/'.length, key.length - 5),
          reason: '$key must parse as a pack (filename == pack id stem here)',
        );
      }
    },
  );

  test('committed pack assets are byte-identical to the engine fixtures', () {
    for (final String name in _engineFixtureFilenames) {
      final List<int> committed = File(
        'assets/content/packs/$name',
      ).readAsBytesSync();
      final List<int> engine = File(
        '$_engineFixturesDir/$name',
      ).readAsBytesSync();
      expect(
        committed,
        engine,
        reason:
            '$name must be a byte-for-byte copy of the engine fixture '
            '(single source of truth = the engine fixtures; regenerate via '
            'copy whenever they change)',
      );
    }
  });
}

bool _isPackAsset(String key) =>
    key.startsWith('assets/content/packs/') && key.endsWith('.json');
