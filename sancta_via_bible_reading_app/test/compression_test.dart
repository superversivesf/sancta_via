import 'package:flutter_test/flutter_test.dart';
// import 'package:archive/archive.dart'; // Removed dependency - not used in shipped app
import 'dart:convert';

void main() {
  group('Bible JSON Compression Tests', () {
    // NOTE: Compression tests disabled because archive dependency was removed
    // These tests were for development-only compression verification
    // The shipped app uses pre-built SQLite database instead of compressed JSON

    test('should handle JSON encoding/decoding', () {
      // Basic JSON test that doesn't require compression
      final testData = {
        'test': 'data',
        'books': [
          {'name': 'Genesis'},
        ],
      };
      final jsonString = json.encode(testData);
      final decodedData = json.decode(jsonString);

      expect(decodedData, equals(testData));
    });

    // Compression tests commented out due to removed archive dependency
    /*
    test('should be able to decompress gzipped JSON files', () async {
      // Test disabled - archive package not available in production builds
    });

    test('should handle compression errors gracefully', () async {
      // Test disabled - archive package not available in production builds
    });

    test('should achieve significant compression ratio', () {
      // Test disabled - archive package not available in production builds
    });
    */
  });
}
