import 'package:sancta_via_devotional_engine/sancta_via_devotional_engine.dart';
import 'package:sancta_via_liturgical_calendar/sancta_via_liturgical_calendar.dart';
import 'package:test/test.dart';

LiturgicalDayData? dayFor(DateTime date) =>
    LiturgicalCalendarService.getDayForDate(date);

void main() {
  group('rosaryMysteriesFor', () {
    test(
      'maps Mon/Sat joyful, Tue/Fri sorrowful, Wed glorious, Thu luminous',
      () {
        // Advent weekdays of December 2026, each verified against the
        // embedded calendar data (all of seasonKey 'Advent').
        final Map<DateTime, MysterySet> goldens = <DateTime, MysterySet>{
          DateTime(2026, 12, 12): MysterySet.joyful, // Saturday
          DateTime(2026, 12, 14): MysterySet.joyful, // Monday (brief pin)
          DateTime(2026, 12, 15): MysterySet.sorrowful, // Tuesday
          DateTime(2026, 12, 16): MysterySet.glorious, // Wednesday (brief pin)
          DateTime(2026, 12, 17): MysterySet.luminous, // Thursday (brief pin)
          DateTime(2026, 12, 18): MysterySet.sorrowful, // Friday
        };

        goldens.forEach((DateTime date, MysterySet expected) {
          final LiturgicalDayData? day = dayFor(date);
          expect(
            day,
            isNotNull,
            reason: 'embedded calendar data must cover $date',
          );
          expect(
            rosaryMysteriesFor(date, day),
            equals(expected),
            reason: 'the rosary mysteries for $date must be $expected',
          );
        });
      },
    );

    test('overrides Sundays by seasonKey: Advent or Christmas to joyful', () {
      // Advent Sunday: 2026-12-20, 4th Sunday of Advent (brief pin).
      final LiturgicalDayData? adventSunday = dayFor(DateTime(2026, 12, 20));
      expect(
        adventSunday?.seasonKey,
        'Advent',
        reason: '2026-12-20 must be an Advent day in the embedded data',
      );
      expect(
        rosaryMysteriesFor(DateTime(2026, 12, 20), adventSunday),
        MysterySet.joyful,
      );

      // Christmas-season Sunday: 2026-01-04, Epiphany falls on a Sunday.
      final LiturgicalDayData? christmasSunday = dayFor(DateTime(2026, 1, 4));
      expect(
        christmasSunday?.seasonKey,
        'Christmastide',
        reason: '2026-01-04 must be a Christmas-season day in the data',
      );
      expect(
        rosaryMysteriesFor(DateTime(2026, 1, 4), christmasSunday),
        MysterySet.joyful,
      );
    });

    test('overrides Lenten Sundays with the sorrowful mysteries', () {
      // 2026-02-22, 1st Sunday of Lent (brief pin; seasonKey verbatim 'Lent').
      final LiturgicalDayData? lentSunday = dayFor(DateTime(2026, 2, 22));
      expect(
        lentSunday?.seasonKey,
        'Lent',
        reason: '2026-02-22 must carry seasonKey Lent in the embedded data',
      );
      expect(
        rosaryMysteriesFor(DateTime(2026, 2, 22), lentSunday),
        MysterySet.sorrowful,
      );
    });

    test(
      'keeps glorious mysteries for Ordinary-Time Sundays and null data',
      () {
        // Ordinary-Time Sunday: the glorious set remains the default.
        final LiturgicalDayData? ordinarySunday = dayFor(DateTime(2026, 7, 5));
        expect(ordinarySunday, isNotNull);
        expect(ordinarySunday?.seasonKey, 'Later Ordinary Time');
        expect(
          rosaryMysteriesFor(DateTime(2026, 7, 5), ordinarySunday),
          MysterySet.glorious,
        );

        // Without calendar data the weekday map still applies; a Sunday
        // defaults to the glorious mysteries. The 2040 dates are beyond the
        // embedded data range and their weekdays are: 2040-12-23 Sunday,
        // 2040-12-17 Monday, 2040-12-20 Thursday.
        expect(
          rosaryMysteriesFor(DateTime(2040, 12, 23), null), // Sunday
          MysterySet.glorious,
        );
        expect(
          rosaryMysteriesFor(DateTime(2040, 12, 17), null), // Monday
          MysterySet.joyful,
        );
        expect(
          rosaryMysteriesFor(DateTime(2040, 12, 20), null), // Thursday
          MysterySet.luminous,
        );
      },
    );
  });

  group('angelusPrayerFor', () {
    test("returns 'regina_caeli' from Easter through Pentecost", () {
      final Map<String, DateTime> reginaCaeliDates = <String, DateTime>{
        'Easter Sunday': DateTime(2026, 4, 5), // brief pin
        'within Easter': DateTime(2026, 4, 20),
        'Pentecost Sunday': DateTime(2026, 5, 24),
      };

      reginaCaeliDates.forEach((String label, DateTime date) {
        final LiturgicalDayData? day = dayFor(date);
        expect(day, isNotNull, reason: 'calendar data must cover $date');
        expect(angelusPrayerFor(date, day), 'regina_caeli', reason: label);
      });
    });

    test("returns 'angelus' outside the Easter season and without data", () {
      // 2026-01-06: Christmastide (brief pin).
      final LiturgicalDayData? epiphanyEra = dayFor(DateTime(2026, 1, 6));
      expect(epiphanyEra, isNotNull);
      expect(epiphanyEra?.seasonKey, 'Christmastide');
      expect(angelusPrayerFor(DateTime(2026, 1, 6), epiphanyEra), 'angelus');

      // The day after Pentecost closes the Regina Caeli window.
      final LiturgicalDayData? afterPentecost = dayFor(DateTime(2026, 5, 25));
      expect(afterPentecost, isNotNull);
      expect(
        angelusPrayerFor(DateTime(2026, 5, 25), afterPentecost),
        'angelus',
      );

      // Without calendar data, the Angelus remains the default.
      expect(angelusPrayerFor(DateTime(2040, 4, 5), null), 'angelus');
    });
  });

  group('marianAntiphonFor', () {
    test('follows the brief-pinned date windows', () {
      final Map<DateTime, String> goldens = <DateTime, String>{
        // Advent weekday in December (brief pin).
        DateTime(2026, 12, 18): 'alma_redemptoris_mater',
        // Ash Wednesday 2027: Lent after February 2 (brief pin).
        DateTime(2027, 2, 10): 'ave_regina_caelorum',
        // Mid-Easter weekday (brief pin).
        DateTime(2026, 4, 20): 'regina_caeli',
        // Ordinary Time in high summer (brief pin).
        DateTime(2026, 7, 5): 'salve_regina',
      };

      goldens.forEach((DateTime date, String expected) {
        final LiturgicalDayData? day = dayFor(date);
        expect(
          day,
          isNotNull,
          reason: 'embedded calendar data must cover $date',
        );
        expect(
          marianAntiphonFor(day),
          equals(expected),
          reason: 'the Marian antiphon for $date must be $expected',
        );
      });
    });

    test('swaps from alma to ave exactly at Candlemas (Feb 2 inclusive)', () {
      final LiturgicalDayData? candlemas = dayFor(DateTime(2026, 2, 2));
      expect(candlemas, isNotNull);
      expect(marianAntiphonFor(candlemas), 'alma_redemptoris_mater');

      final LiturgicalDayData? afterCandlemas = dayFor(DateTime(2026, 2, 3));
      expect(afterCandlemas, isNotNull);
      expect(marianAntiphonFor(afterCandlemas), 'ave_regina_caelorum');

      // Christmas itself (Dec 25) sits inside the Alma window.
      final LiturgicalDayData? christmas = dayFor(DateTime(2026, 12, 25));
      expect(christmas, isNotNull);
      expect(marianAntiphonFor(christmas), 'alma_redemptoris_mater');
    });

    test('gives alma to November days of Advent, before December', () {
      // 2025-11-30, 1st Sunday of Advent: month rule alone cannot cover
      // Advent days that fall in late November.
      final LiturgicalDayData? adventSunday = dayFor(DateTime(2025, 11, 30));
      expect(adventSunday, isNotNull);
      expect(adventSunday?.seasonKey, 'Advent');
      expect(marianAntiphonFor(adventSunday), 'alma_redemptoris_mater');
    });

    test('gives salve to Ordinary Time before Advent I', () {
      final LiturgicalDayData? beforeAdvent = dayFor(DateTime(2025, 11, 27));
      expect(beforeAdvent, isNotNull);
      expect(beforeAdvent?.seasonKey, 'Later Ordinary Time');
      expect(marianAntiphonFor(beforeAdvent), 'salve_regina');
    });

    test("returns no antiphon during Holy Week and the Triduum", () {
      // Palm Sunday and Holy Saturday 2026 both carry seasonKey 'Holy Week'.
      final LiturgicalDayData? palmSunday = dayFor(DateTime(2026, 3, 29));
      expect(palmSunday, isNotNull);
      expect(palmSunday?.seasonKey, 'Holy Week');
      expect(marianAntiphonFor(palmSunday), '');

      final LiturgicalDayData? holySaturday = dayFor(DateTime(2026, 4, 4));
      expect(holySaturday, isNotNull);
      expect(holySaturday?.seasonKey, 'Holy Week');
      expect(marianAntiphonFor(holySaturday), '');
    });

    test('defaults to salve without calendar data', () {
      expect(marianAntiphonFor(null), 'salve_regina');
    });
  });
}
