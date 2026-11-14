// Unit tests for `lib/src/utils/history_source.dart` (modern-saint-histories
// plan Task 1): the pinned source-class registry.
import 'package:flutter_test/flutter_test.dart';

import '../../lib/src/utils/history_source.dart';

void main() {
  group('sourceClasses registry', () {
    test('contains exactly the two contract classes', () {
      expect(sourceClasses.keys.toSet(), <String>{
        'catholic-encyclopedia-1907',
        'wikipedia',
      });
    });

    test('pins the exact attribution copy', () {
      expect(
        sourceClasses['catholic-encyclopedia-1907'],
        'Adapted from the Catholic Encyclopedia (1907–12)',
      );
      expect(sourceClasses['wikipedia'], 'Adapted from Wikipedia (CC BY-SA 4.0)');
    });
  });

  group('historySourcePatternFor', () {
    test('accepts the CE class with its pinned URL shape', () {
      final RegExp pattern = historySourcePatternFor(
        sourceClasses.keys,
      );
      expect(
        pattern.hasMatch(
          'catholic-encyclopedia-1907 '
          'https://www.newadvent.org/cathen/17721a.htm',
        ),
        isTrue,
      );
    });

    test('accepts the wikipedia class with an article URL', () {
      final RegExp pattern = historySourcePatternFor(sourceClasses.keys);
      expect(
        pattern
            .hasMatch('wikipedia https://en.wikipedia.org/wiki/Pope_John_Paul_II'),
        isTrue,
      );
    });

    test('rejects an unknown class prefix', () {
      final RegExp pattern = historySourcePatternFor(sourceClasses.keys);
      expect(
        pattern.hasMatch('random-site https://www.example.com/saint'),
        isFalse,
      );
    });

    test('rejects a wikipedia class with a non-wikipedia URL', () {
      final RegExp pattern = historySourcePatternFor(sourceClasses.keys);
      expect(
        pattern.hasMatch('wikipedia https://www.example.com/Pope_John_Paul_II'),
        isFalse,
      );
    });
  });

  group('attributionFor', () {
    test('returns the CE attribution line for a CE source', () {
      expect(
        attributionFor(
          'catholic-encyclopedia-1907 '
          'https://www.newadvent.org/cathen/06221a.htm',
        ),
        'Adapted from the Catholic Encyclopedia (1907–12)',
      );
    });

    test('returns the wikipedia attribution line for a wikipedia source', () {
      expect(
        attributionFor(
          'wikipedia https://en.wikipedia.org/wiki/Pope_John_Paul_II',
        ),
        'Adapted from Wikipedia (CC BY-SA 4.0)',
      );
    });

    test('throws on an unknown class', () {
      expect(
        () => attributionFor('random-site https://www.example.com/saint'),
        throwsArgumentError,
      );
    });
  });

  group('groundingDirFor', () {
    test('maps both classes to their grounding directories', () {
      expect(groundingDirFor('catholic-encyclopedia-1907'), 'data/grounding');
      expect(
        groundingDirFor('wikipedia'),
        'data/grounding_wikipedia',
      );
    });

    test('throws on an unknown class', () {
      expect(() => groundingDirFor('random-site'), throwsArgumentError);
    });
  });
}
