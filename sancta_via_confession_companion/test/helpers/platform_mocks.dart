import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Platform-channel mocks for the plugin services the examination repository
/// touches (path_provider documents dir, flutter_secure_storage). Without
/// them the list screen spins forever instead of falling back to bundled
/// sample data, and pumpAndSettle times out.
void installConfessionPlatformMocks(
  TestDefaultBinaryMessengerBinding binding,
) {
  final dir = Directory.systemTemp.createTempSync('confession_test');

  binding.defaultBinaryMessenger.setMockMethodCallHandler(
    const MethodChannel('plugins.flutter.io/path_provider'),
    (call) async {
      switch (call.method) {
        case 'getApplicationDocumentsDirectory':
        case 'getApplicationSupportDirectory':
          return dir.path;
        case 'getTemporaryDirectory':
          return Directory.systemTemp.createTempSync('confession_tmp').path;
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

/// Encodes a JSON payload the way SecureStorageService writes sessions.
String encodeSession(Map<String, dynamic> sessionJson) => jsonEncode(sessionJson);
