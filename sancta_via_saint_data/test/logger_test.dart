import 'package:flutter_test/flutter_test.dart';
import 'package:saint_data/saint_data.dart';

void main() {
  group('SaintLogger', () {
    test('error does not throw', () {
      expect(
        () => SaintLogger.error(
          'x',
          Exception('smoke test error'),
          StackTrace.current,
          tag: 'SAINT_DATA',
        ),
        returnsNormally,
      );
    });
  });
}
