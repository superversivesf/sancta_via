import 'dart:async';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<void> testExecutable(FutureOr<void> Function() main) async {
  // Initialize FFI
  sqfliteFfiInit();
  // Set the database factory to the FFI implementation
  databaseFactory = databaseFactoryFfi;
  await main();
}
