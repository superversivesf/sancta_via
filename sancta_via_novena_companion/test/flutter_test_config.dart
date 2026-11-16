// Test-run configuration shared by every novena test: route the sqflite
// plugin calls through the FFI database factory so the '/novenas' route's
// real database initialization works in the test zone.
import 'dart:async';

import 'package:sqflite_common/sqlite_api.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// flutter_test discovers `testExecutable` in this file and wraps every
/// test run with it.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  await testMain();
}
