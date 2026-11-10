import 'package:sancta_via_devotional_engine/sancta_via_devotional_engine.dart';
import 'package:test/test.dart';

void main() {
  const ScheduleContext context = ScheduleContext();

  group('FixedDateSpec', () {
    group('single-date form', () {
      test('is due on the feast day and not on the following day', () {
        final FixedDateSpec spec = FixedDateSpec(12, 17);

        final ScheduleResult onFeast = spec.resolve(
          DateTime(2026, 12, 17),
          context,
        );
        final ScheduleResult nextDay = spec.resolve(
          DateTime(2026, 12, 18),
          context,
        );

        expect(
          onFeast.due,
          isTrue,
          reason: 'FixedDateSpec(12, 17) must be due on 2026-12-17',
        );
        expect(
          nextDay.due,
          isFalse,
          reason: '2026-12-18 must not be due for a single-date spec',
        );
      });

      test('reports no dayIndex (a lone date has no window position)', () {
        final FixedDateSpec spec = FixedDateSpec(12, 17);

        final ScheduleResult result = spec.resolve(
          DateTime(2026, 12, 17),
          context,
        );

        expect(result.due, isTrue);
        expect(result.dayIndex, isNull);
      });
    });

    group('window form', () {
      test('is due across the inclusive window with a 1-based dayIndex', () {
        // November 1 through November 8, inclusive.
        final FixedDateSpec spec = FixedDateSpec(11, 1, untilDay: 8);

        expect(
          spec.resolve(DateTime(2026, 11, 3), context).due,
          isTrue,
          reason: '2026-11-03 is inside the November 1-8 window',
        );
        expect(
          spec.resolve(DateTime(2026, 11, 3), context).dayIndex,
          equals(3),
          reason: 'November 3 is the 3rd day of the November 1-8 window',
        );
        expect(
          spec.resolve(DateTime(2026, 11, 1), context).dayIndex,
          equals(1),
        );
        expect(
          spec.resolve(DateTime(2026, 11, 8), context).dayIndex,
          equals(8),
        );
      });

      test('is not due before the window start or after the window end', () {
        final FixedDateSpec spec = FixedDateSpec(11, 1, untilDay: 8);

        expect(spec.resolve(DateTime(2026, 10, 31), context).due, isFalse);
        expect(spec.resolve(DateTime(2026, 11, 9), context).due, isFalse);
      });

      test('supports a same-month window given only untilDay', () {
        final FixedDateSpec spec = FixedDateSpec(3, 19, untilDay: 25);

        expect(
          spec.resolve(DateTime(2026, 3, 25), context).dayIndex,
          equals(7),
        );
        expect(spec.resolve(DateTime(2026, 3, 26), context).due, isFalse);
      });
    });

    group('validation', () {
      test('rejects untilMonth without untilDay', () {
        expect(() => FixedDateSpec(11, 1, untilMonth: 11), throwsArgumentError);
      });

      test('rejects out-of-scope month and day components', () {
        expect(() => FixedDateSpec(13, 1), throwsArgumentError);
        expect(() => FixedDateSpec(0, 15), throwsArgumentError);
        expect(() => FixedDateSpec(1, 0), throwsArgumentError);
        expect(() => FixedDateSpec(1, 32), throwsArgumentError);
        expect(
          () => FixedDateSpec(1, 1, untilMonth: 13, untilDay: 8),
          throwsArgumentError,
        );
        expect(
          () => FixedDateSpec(1, 1, untilMonth: 1, untilDay: 32),
          throwsArgumentError,
        );
      });

      test('rejects a window whose end precedes its start', () {
        expect(
          () => FixedDateSpec(12, 25, untilMonth: 1, untilDay: 1),
          throwsArgumentError,
        );
      });

      test('rejects a reversed same-month window (untilDay before day)', () {
        // FixedDateSpec(11, 8, untilDay: 1) passes no cross-month
        // ordering check, but resolves not-due on every date: a
        // reversed window is a pack-author typo, so it must fail at
        // construction instead of silently never firing.
        expect(() => FixedDateSpec(11, 8, untilDay: 1), throwsArgumentError);
      });

      test('keeps untilDay == day legal (a single-day window)', () {
        final FixedDateSpec spec = FixedDateSpec(11, 8, untilDay: 8);

        expect(spec.resolve(DateTime(2026, 11, 8), context).due, isTrue);
        expect(spec.resolve(DateTime(2026, 11, 7), context).due, isFalse);
        expect(spec.resolve(DateTime(2026, 11, 9), context).due, isFalse);
      });
    });
  });

  group('EasterOffsetSpec', () {
    test('is due from Good Friday through the 9th day in Easter 2026', () {
      // The Divine Mercy Novena: startOffset -2 (Good Friday) and 9 days.
      // Easter 2026 falls on April 5, so the window is April 3..11 inclusive.
      final EasterOffsetSpec spec = EasterOffsetSpec(-2, 9);

      final ScheduleResult goodFriday = spec.resolve(
        DateTime(2026, 4, 3),
        context,
      );
      final ScheduleResult ninthDay = spec.resolve(
        DateTime(2026, 4, 11),
        context,
      );

      expect(
        goodFriday.due,
        isTrue,
        reason:
            'Easter 2026 is April 5; startOffset -2 lands on Good Friday, April 3',
      );
      expect(goodFriday.dayIndex, equals(1));
      expect(
        ninthDay.due,
        isTrue,
        reason: 'A 9-day window makes April 11 the last due day',
      );
      expect(ninthDay.dayIndex, equals(9));
    });

    test('is not due the day before or the day after the window', () {
      final EasterOffsetSpec spec = EasterOffsetSpec(-2, 9);

      expect(spec.resolve(DateTime(2026, 4, 2), context).due, isFalse);
      expect(
        spec.resolve(DateTime(2026, 4, 12), context).due,
        isFalse,
        reason: 'The window ends on April 11',
      );
    });

    test('anchors the window to Easter of the calendar year of that date', () {
      // Easter 2027 falls on March 28, so startOffset -2 lands on March 26.
      final EasterOffsetSpec spec = EasterOffsetSpec(-2, 9);

      final ScheduleResult result = spec.resolve(
        DateTime(2027, 3, 26),
        context,
      );

      expect(
        result.due,
        isTrue,
        reason: 'Easter 2027 is March 28; -2 is March 26',
      );
      expect(result.dayIndex, equals(1));
    });

    test('rejects non-positive window lengths', () {
      expect(() => EasterOffsetSpec(-2, 0), throwsArgumentError);
    });
  });

  group('UTC-drift guard', () {
    test(
      'resolves a parsed date-only input by its local-shifted calendar self',
      () {
        // A date-only DateTime.parse call yields local midnight on every
        // host (no time-zone designator, so isUtc stays false) — the
        // parsed input and the locally-constructed normalization below are
        // the same instant by definition, making this guard documentation
        // of the contract rather than an active drift detector. The
        // load-bearing anti-UTC-drift enforcement is the boundary pins
        // above, which construct every calendar value via
        // DateTime(year, month, day), and ScheduleSpec._dateOnly, which
        // resolves every input by its LOCAL calendar components and never
        // by the input's UTC rendering.
        final DateTime parsed = DateTime.parse('2026-12-17');
        final DateTime localSelf = DateTime(
          parsed.year,
          parsed.month,
          parsed.day,
        );
        final FixedDateSpec spec = FixedDateSpec(12, 17);

        expect(
          spec.resolve(parsed, context).due,
          equals(spec.resolve(localSelf, context).due),
        );
      },
    );
  });
}
