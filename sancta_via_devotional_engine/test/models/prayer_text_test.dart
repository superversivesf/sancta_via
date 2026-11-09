import 'package:sancta_via_devotional_engine/sancta_via_devotional_engine.dart';
import 'package:test/test.dart';

void main() {
  group('PrayerText', () {
    test(
      'throws ContentValidationException mentioning source when source is empty',
      () {
        expect(
          () => PrayerText(
            id: 'memorare',
            text: 'Remember, O most gracious Virgin Mary...',
            source: '',
            license: 'public-domain',
          ),
          throwsA(
            isA<ContentValidationException>()
                .having((e) => e.message, 'message', contains('source'))
                .having(
                  (e) => e.problems,
                  'problems',
                  anyElement(contains('source')),
                ),
          ),
        );
      },
    );

    test('throws ContentValidationException when license is empty', () {
      expect(
        () => PrayerText(
          id: 'memorare',
          text: 'Remember, O most gracious Virgin Mary...',
          source: 'Traditional',
          license: '',
        ),
        throwsA(isA<ContentValidationException>()),
      );
    });

    test('allows null latin', () {
      final PrayerText prayer = PrayerText(
        id: 'memorare',
        text: 'Remember, O most gracious Virgin Mary...',
        source: 'Traditional',
        license: 'public-domain',
      );

      expect(prayer.latin, isNull);
      expect(prayer.id, equals('memorare'));
    });

    test('toJson/fromJson round-trip preserves all fields', () {
      final PrayerText original = PrayerText(
        id: 'memorare',
        text: 'Remember, O most gracious Virgin Mary...',
        latin: 'Memorare, O piissima Virgo Maria...',
        source: 'Traditional',
        license: 'public-domain',
      );

      final Map<String, dynamic> json = original.toJson();
      final PrayerText roundTrip = PrayerText.fromJson(json);

      expect(roundTrip, equals(original));
      expect(roundTrip.toJson(), equals(json));
    });

    test('toJson/fromJson round-trip preserves fields when latin is null', () {
      final PrayerText original = PrayerText(
        id: 'ave-maria',
        text: 'Hail Mary, full of grace...',
        source: 'Traditional',
        license: 'public-domain',
      );

      final PrayerText roundTrip = PrayerText.fromJson(original.toJson());

      expect(roundTrip, equals(original));
      expect(roundTrip.latin, isNull);
    });
  });

  group('ContentValidationException', () {
    test('exposes message and problems', () {
      const ContentValidationException exception = ContentValidationException(
        message: 'Invalid content',
        problems: <String>['source is empty'],
      );

      expect(exception.message, equals('Invalid content'));
      expect(exception.problems, equals(<String>['source is empty']));
      expect(exception.toString(), contains('Invalid content'));
    });
  });
}
