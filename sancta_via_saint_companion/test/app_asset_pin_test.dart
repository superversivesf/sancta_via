// Final-review fix wave asset pin (ruling d).
//
// Regresses the exact trap that shipped a silently blank app:
// `SaintRepository.ensureLoaded` opens the LITERAL asset key
// `assets/saints.db`, which resolves against THIS app's own asset bundle —
// package assets from a dependency resolve only under
// `packages/saint_data/...` and are never requested. This test would have
// caught the entire trap, so it must always hold in the app's test
// environment:
//
//   1. `rootBundle.load('assets/saints.db')` succeeds (the app pubspec
//      declares the bundled database);
//   2. a prewarm of the production `SaintRepository.instance` — the genuine
//      first-load path (asset refresh + open) — loads real saints
//      (`getFeaturedSaints()` non-empty).
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saint_data/saint_data.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'the app bundles assets/saints.db and the production repository loads it',
    (WidgetTester tester) async {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;

      late ByteData assetData;
      late List<Saint> featured;

      // All real-I/O work runs in the real-time zone: the asset load and the
      // FFI-backed open must not land inside the fake-async test zone.
      await tester.runAsync(() async {
        // 1. The literal production key resolves against the app bundle.
        assetData = await rootBundle.load('assets/saints.db');
        expect(assetData.lengthInBytes, greaterThan(0));

        // 2. A real prewarm of the production singleton loads the saints.
        // The on-device copy is redirected to a temp directory so the test
        // never reads or writes the user's databases path.
        final String previousDatabasesPath = await databaseFactory
            .getDatabasesPath();
        final Directory tempDir = await Directory.systemTemp.createTemp(
          'saints_app_asset_pin_',
        );
        await databaseFactory.setDatabasesPath(tempDir.path);
        try {
          await SaintRepository.instance.ensureLoaded();
          featured = await SaintRepository.instance.getFeaturedSaints();
        } finally {
          await databaseFactory.setDatabasesPath(previousDatabasesPath);
        }
        await tempDir.delete(recursive: true);
      });

      expect(
        assetData.lengthInBytes,
        greaterThan(0),
        reason:
            'the app pubspec must declare the bundled saints database '
            'under the literal key the repository opens',
      );
      expect(
        featured,
        isNotEmpty,
        reason:
            'a real SaintRepository.instance prewarm must load the '
            'committed featured saints through the bundled asset',
      );
    },
  );
}
