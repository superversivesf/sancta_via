import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
/// Test-run configuration shared by every prayer companion test: route the
/// sqflite plugin calls through the FFI database factory and mock the
/// path_provider channels so the home screen's database-backed providers
/// resolve in the test zone.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('plugins.flutter.io/path_provider'),
    (call) async {
      final dir = Directory.systemTemp.createTempSync('prayer_test');
      return dir.path;
    },
  );

  await testMain();
}
