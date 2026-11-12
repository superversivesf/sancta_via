// Test bootstrap for the devotionals app: points sqflite at the FFI
// implementation so database tests run on the host (mirrors the
// bible-reading-app test config).
import 'dart:async';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<void> testExecutable(FutureOr<void> Function() main) async {
  // Initialize FFI.
  sqfliteFfiInit();
  // Set the database factory to the FFI implementation.
  databaseFactory = databaseFactoryFfi;
  await main();
}
