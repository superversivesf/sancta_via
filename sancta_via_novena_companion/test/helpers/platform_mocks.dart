import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Platform-channel mocks for the plugins the app touches after the first
/// route pushes (path_provider for the database location; flutter_secure_
/// storage for auth/session state). Without these the database init spins
/// and pumpAndSettle never settles.
void installNovenaPlatformMocks(TestDefaultBinaryMessengerBinding binding) {
  final dir = Directory.systemTemp.createTempSync('novena_test');

  binding.defaultBinaryMessenger.setMockMethodCallHandler(
    const MethodChannel('plugins.flutter.io/path_provider'),
    (call) async {
      switch (call.method) {
        case 'getApplicationDocumentsDirectory':
        case 'getApplicationSupportDirectory':
          return dir.path;
        case 'getTemporaryDirectory':
          return Directory.systemTemp.createTempSync('novena_tmp').path;
      }
      return null;
    },
  );

  final secureStorage = <String, String>{};
  binding.defaultBinaryMessenger.setMockMethodCallHandler(
    const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
    (call) async {
      switch (call.method) {
        case 'write':
          final args = call.arguments as Map;
          secureStorage[args['key'] as String? ?? ''] =
              args['value'] as String? ?? '';
          return null;
        case 'read':
          return secureStorage[call.arguments as String? ?? ''];
        case 'readAll':
          return Map<String, String>.from(secureStorage);
        case 'delete':
          secureStorage.remove(call.arguments as String? ?? '');
          return null;
        case 'deleteAll':
          secureStorage.clear();
          return null;
      }
      return null;
    },
  );
}
