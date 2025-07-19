import 'package:flutter_test/flutter_test.dart';
import 'package:archive/archive.dart';
import 'dart:convert';

void main() {
  group('Bible JSON Compression Tests', () {
    
    test('should be able to decompress gzipped JSON files', () async {
      // This test verifies that our compressed files can be decompressed
      // Note: This test will need asset loading to work properly in a real environment
      
      // Test the decompression logic with sample data
      final originalData = {'test': 'data', 'books': [{'name': 'Genesis'}]};
      final originalJson = json.encode(originalData);
      final originalBytes = utf8.encode(originalJson);
      
      // Compress the data
      final compressedBytes = GZipEncoder().encode(originalBytes);
      
      // Decompress the data (simulating our loading process)
      final decompressedBytes = GZipDecoder().decodeBytes(compressedBytes!);
      final decompressedJson = utf8.decode(decompressedBytes);
      final decompressedData = json.decode(decompressedJson);
      
      expect(decompressedData, equals(originalData));
    });

    test('should handle compression errors gracefully', () async {
      // Test with invalid compressed data
      final invalidData = [1, 2, 3, 4, 5]; // Not gzipped data
      
      expect(() => GZipDecoder().decodeBytes(invalidData), throwsException);
    });

    test('should achieve significant compression ratio', () {
      // Test compression efficiency with Bible-like data
      final mockBibleData = {
        'translation': 'Test Translation',
        'metadata': {'name': 'Test Bible', 'books': 66},
        'books': List.generate(5, (i) => {
          'name': 'Book ${i + 1}',
          'chapters': List.generate(10, (j) => {
            'chapter': j + 1,
            'verses': List.generate(20, (k) => {
              'verse': k + 1,
              'text': 'This is verse ${k + 1} of chapter ${j + 1} in book ${i + 1}. ' * 3,
            })
          })
        })
      };
      
      final originalJson = json.encode(mockBibleData);
      final originalBytes = utf8.encode(originalJson);
      final compressedBytes = GZipEncoder().encode(originalBytes);
      
      final originalSize = originalBytes.length;
      final compressedSize = compressedBytes!.length;
      final compressionRatio = (1 - compressedSize / originalSize) * 100;
      
      print('Original size: $originalSize bytes');
      print('Compressed size: $compressedSize bytes');
      print('Compression ratio: ${compressionRatio.toStringAsFixed(1)}%');
      
      // Should achieve at least 50% compression with repetitive Bible text
      expect(compressionRatio, greaterThan(50.0));
    });
  });
}
