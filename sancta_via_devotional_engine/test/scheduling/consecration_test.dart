import 'package:sancta_via_devotional_engine/sancta_via_devotional_engine.dart';
import 'package:test/test.dart';

void main() {
  const ScheduleContext context = ScheduleContext();

  group('ConsecrationPlanner', () {
    group('startFor', () {
      test(
        'returns February 20 for a March 25 consecration in a non-leap year',
        () {
          final DateTime start = ConsecrationPlanner.startFor(
            DateTime(2027, 3, 25),
          );

          expect(
            start,
            equals(DateTime(2027, 2, 20)),
            reason: 'Non-leap year: Feb 20 + 33 days = Mar 25',
          );
        },
      );

      test(
        'returns February 21 for a March 25 consecration in a leap year',
        () {
          final DateTime start = ConsecrationPlanner.startFor(
            DateTime(2028, 3, 25),
          );

          expect(
            start,
            equals(DateTime(2028, 2, 21)),
            reason: 'Leap year: Feb 21 + 33 days = Mar 25',
          );
        },
      );
    });
  });

  group('SessionSeriesSpec', () {
    test(
      'is due on day 1 and mid-series with a 1-based dayIndex across a month boundary',
      () {
        final DateTime start = ConsecrationPlanner.startFor(
          DateTime(2027, 3, 25), // 2027-02-20
        );
        final SessionSeriesSpec spec = SessionSeriesSpec(
          startDate: start,
          lengthDays: 34,
        );

        final ScheduleResult firstDay = spec.resolve(
          DateTime(2027, 2, 20),
          context,
        );

        expect(
          firstDay.due,
          isTrue,
          reason: 'The start date is day 1 of the series',
        );
        expect(firstDay.dayIndex, equals(1));
        expect(
          spec.resolve(DateTime(2027, 3, 6), context).dayIndex,
          equals(15),
        );
      },
    );

    test('day 34 is the consecration day itself: due with dayIndex 34', () {
      final DateTime start = ConsecrationPlanner.startFor(
        DateTime(2027, 3, 25), // 2027-02-20
      );
      final SessionSeriesSpec spec = SessionSeriesSpec(
        startDate: start,
        lengthDays: 34,
      );

      final ScheduleResult consecrationDay = spec.resolve(
        DateTime(2027, 3, 25),
        context,
      );

      expect(
        consecrationDay.due,
        isTrue,
        reason: 'Day 34 is the consecration day itself',
      );
      expect(consecrationDay.dayIndex, equals(34));
    });

    test('day 35 is not due', () {
      final DateTime start = ConsecrationPlanner.startFor(
        DateTime(2027, 3, 25), // 2027-02-20
      );
      final SessionSeriesSpec spec = SessionSeriesSpec(
        startDate: start,
        lengthDays: 34,
      );

      final ScheduleResult dayAfter = spec.resolve(
        DateTime(2027, 3, 26),
        context,
      );

      expect(
        dayAfter.due,
        isFalse,
        reason:
            'A 34-day series ends on the consecration day; 2027-03-26 is day 35',
      );
    });

    test('is not due before the start date', () {
      final DateTime start = ConsecrationPlanner.startFor(
        DateTime(2028, 3, 25), // 2028-02-21 (leap year)
      );
      final SessionSeriesSpec spec = SessionSeriesSpec(
        startDate: start,
        lengthDays: 34,
      );

      final ScheduleResult dayBefore = spec.resolve(
        DateTime(2028, 2, 20),
        context,
      );

      expect(
        dayBefore.due,
        isFalse,
        reason: '2028-02-20 precedes the start date 2028-02-21',
      );
    });

    test('rejects non-positive series lengths', () {
      expect(
        () =>
            SessionSeriesSpec(startDate: DateTime(2027, 2, 20), lengthDays: 0),
        throwsArgumentError,
      );
    });
  });
}
