import 'package:sancta_via_devotional_engine/sancta_via_devotional_engine.dart';
import 'package:test/test.dart';

void main() {
  group('easterSundayFor', () {
    test('returns golden dates for representative and boundary years', () {
      // 1900 and 2400 pin the lower/upper bounds of the documented range.
      // 2024-2027 and 2033 pin ordinary representative years.
      final Map<int, DateTime> goldens = <int, DateTime>{
        1900: DateTime(1900, 4, 15),
        2024: DateTime(2024, 3, 31),
        2025: DateTime(2025, 4, 20),
        2026: DateTime(2026, 4, 5),
        2027: DateTime(2027, 3, 28),
        2033: DateTime(2033, 4, 17),
        2400: DateTime(2400, 4, 16),
      };

      goldens.forEach((int year, DateTime expected) {
        expect(
          easterSundayFor(year),
          equals(expected),
          reason:
              'Easter Sunday $year must fall on '
              '${expected.year}-'
              '${expected.month.toString().padLeft(2, '0')}-'
              '${expected.day.toString().padLeft(2, '0')}',
        );
      });
    });

    test(
      'returns golden dates for the Meeus/Jones/Butcher exception years',
      () {
        // These years exercise the algorithm's epact-correction branches (the
        // 30-day paschal-cycle edge cases); pinning them guards against a
        // subtly-wrong transcription of the Meeus/Jones/Butcher algorithm.
        final Map<int, DateTime> goldens = <int, DateTime>{
          1954: DateTime(1954, 4, 18),
          2049: DateTime(2049, 4, 18),
          2076: DateTime(2076, 4, 19),
        };

        goldens.forEach((int year, DateTime expected) {
          expect(
            easterSundayFor(year),
            equals(expected),
            reason:
                'Easter Sunday $year must fall on April '
                '${expected.day}',
          );
        });
      },
    );

    test('returns a local midnight date (no UTC drift)', () {
      final DateTime easter = easterSundayFor(2024);

      expect(easter.isUtc, isFalse);
      expect(easter.hour, equals(0));
      expect(easter.minute, equals(0));
      expect(easter.second, equals(0));
      expect(easter.millisecond, equals(0));
      expect(easter.microsecond, equals(0));
    });

    test('throws ArgumentError for years before 1900', () {
      expect(() => easterSundayFor(1899), throwsArgumentError);
    });

    test('throws ArgumentError for years after 2400', () {
      expect(() => easterSundayFor(2401), throwsArgumentError);
    });
  });
}
