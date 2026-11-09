import 'package:sancta_via_devotional_engine/sancta_via_devotional_engine.dart';
import 'package:test/test.dart';

void main() {
  const ScheduleContext context = ScheduleContext();

  group('NthWeekdayOfMonthSpec', () {
    group('resolution', () {
      test('is due on the 1st Saturday of December 2026, the 5th', () {
        final NthWeekdayOfMonthSpec spec = NthWeekdayOfMonthSpec(
          DateTime.saturday,
          1,
        );

        final ScheduleResult result = spec.resolve(
          DateTime(2026, 12, 5),
          context,
        );

        expect(
          result.due,
          isTrue,
          reason:
              'December 2026 opens on a Tuesday; its first Saturday is '
              'December 5',
        );
      });

      test('is due on the 1st Friday of January 2027, the New Year edge', () {
        // January 1, 2027 is itself a Friday, so the first occurrence is
        // the month's opening day.
        final NthWeekdayOfMonthSpec spec = NthWeekdayOfMonthSpec(
          DateTime.friday,
          1,
        );

        final ScheduleResult result = spec.resolve(
          DateTime(2027, 1, 1),
          context,
        );

        expect(
          result.due,
          isTrue,
          reason: 'January 2027 opens on a Friday; the 1st Friday is Jan 1',
        );
      });

      test('is due on the 2nd Sunday of November 2026, the 8th', () {
        final NthWeekdayOfMonthSpec spec = NthWeekdayOfMonthSpec(
          DateTime.sunday,
          2,
        );

        final ScheduleResult result = spec.resolve(
          DateTime(2026, 11, 8),
          context,
        );

        expect(
          result.due,
          isTrue,
          reason: 'November 2026 opens on a Sunday; its 2nd Sunday is the 8th',
        );
      });

      test('is due only on the nth occurrence, not adjacent days', () {
        // The 1st-Saturday-of-the-month spec is not due on the preceding
        // Friday (not a Saturday) nor on the second Saturday of the month.
        final NthWeekdayOfMonthSpec spec = NthWeekdayOfMonthSpec(
          DateTime.saturday,
          1,
        );

        expect(
          spec.resolve(DateTime(2026, 12, 11), context).due,
          isFalse,
          reason: '2026-12-11 is a Friday, not a Saturday',
        );
        expect(
          spec.resolve(DateTime(2026, 12, 12), context).due,
          isFalse,
          reason:
              '2026-12-12 is the 2nd Saturday of December 2026, not the 1st',
        );
      });

      test('is not due when a four-week month has no nth occurrence', () {
        // February 2026 opens on a Sunday and has 28 days — exactly four
        // of every weekday, so no fifth occurrence exists to resolve to.
        final NthWeekdayOfMonthSpec fifthSunday = NthWeekdayOfMonthSpec(
          DateTime.sunday,
          5,
        );
        final NthWeekdayOfMonthSpec fifthSaturday = NthWeekdayOfMonthSpec(
          DateTime.saturday,
          5,
        );

        expect(
          fifthSunday.resolve(DateTime(2026, 2, 22), context).due,
          isFalse,
          reason:
              'February 2026 has four Sundays (1, 8, 15, 22); a fifth would '
              'fall on the non-existent February 29',
        );
        expect(
          fifthSaturday.resolve(DateTime(2026, 2, 28), context).due,
          isFalse,
          reason:
              'February 2026 has four Saturdays (7, 14, 21, 28); the spec '
              'never invents a fifth date',
        );
      });

      test('reports no window position (dayIndex and ordinal are null)', () {
        final NthWeekdayOfMonthSpec spec = NthWeekdayOfMonthSpec(
          DateTime.saturday,
          1,
        );

        final ScheduleResult result = spec.resolve(
          DateTime(2026, 12, 5),
          context,
        );

        expect(result.dayIndex, isNull);
        expect(result.ordinal, isNull);
      });
    });

    group('validation', () {
      test('rejects a weekday outside 1 (Monday) through 7 (Sunday)', () {
        expect(() => NthWeekdayOfMonthSpec(0, 1), throwsArgumentError);
        expect(() => NthWeekdayOfMonthSpec(8, 1), throwsArgumentError);
      });

      test('rejects a non-positive nth', () {
        expect(
          () => NthWeekdayOfMonthSpec(DateTime.monday, 0),
          throwsArgumentError,
        );
      });
    });
  });
}
