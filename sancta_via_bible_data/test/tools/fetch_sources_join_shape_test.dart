import 'package:test/test.dart';

import '../../tools/build_bibles/bin/fetch_sources.dart';

/// Unit checks for the per-file shape contract enforced by the DRB join in
/// `fetch_sources.dart` (no network: synthetic in-memory book maps only).
void main() {
  group('joinShapeViolation', () {
    test('accepts a well-formed {chapter: {verse: "text"}} book', () {
      final String? violation = joinShapeViolation(<String, dynamic>{
        '1': <String, dynamic>{'1': 'In the beginning God created heaven.'},
        '2': <String, dynamic>{
          '1': 'Verse one.',
          '2': 'In the *beginning God created heaven and earth.',
        },
      }, 'Genesis.json');
      expect(violation, isNull);
    });

    test('rejects a string metadata sibling key (charset-style)', () {
      final String? violation = joinShapeViolation(<String, dynamic>{
        'charset': 'UTF-8',
        '1': <String, dynamic>{'1': 'In the beginning.'},
      }, 'Book.json');
      expect(violation, isNotNull);
      expect(violation, contains('"charset"'));
    });

    test('rejects a string chapter value', () {
      final String? violation = joinShapeViolation(<String, dynamic>{
        '1': 'whole chapter as a single string',
      }, 'Book.json');
      expect(violation, isNotNull);
      expect(violation, contains('"1"'));
    });

    test('rejects a list chapter value', () {
      final String? violation = joinShapeViolation(<String, dynamic>{
        '1': <String>['verse text'],
      }, 'Book.json');
      expect(violation, isNotNull);
      expect(violation, contains('"1"'));
    });

    test('rejects non-string verse text', () {
      final String? violation = joinShapeViolation(<String, dynamic>{
        '1': <String, dynamic>{'1': 42},
      }, 'Book.json');
      expect(violation, isNotNull);
      expect(violation, contains('"1"'));
    });
  });
}
