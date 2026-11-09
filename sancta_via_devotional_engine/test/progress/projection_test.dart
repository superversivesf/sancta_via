import 'package:sancta_via_devotional_engine/sancta_via_devotional_engine.dart';
import 'package:test/test.dart';

void main() {
  group('Projection.remainingDates', () {
    test('2 of the Five First Saturdays fulfilled lists the next 3 anchor '
        'dates exactly, from 2026-11-20', () {
      final ConsecutiveCommitmentSpec spec = ConsecutiveCommitmentSpec(
        anchor: NthWeekdayOfMonthSpec(DateTime.saturday, 1),
        count: 5,
        policy: RestartPolicy.strict,
      );

      final List<DateTime> dates = Projection.remainingDates(
        spec,
        2,
        DateTime(2026, 11, 20),
      );

      expect(dates, <DateTime>[
        DateTime(2026, 12, 5),
        DateTime(2027, 1, 2),
        DateTime(2027, 2, 6),
      ], reason: 'The Three First Saturdays after 2026-11-20, exactly');
      expect(dates, hasLength(3));
    });

    test(
      'a program whose ordinals have reached its count projects nothing',
      () {
        final ConsecutiveCommitmentSpec spec = ConsecutiveCommitmentSpec(
          anchor: NthWeekdayOfMonthSpec(DateTime.saturday, 1),
          count: 5,
          policy: RestartPolicy.strict,
        );

        expect(
          Projection.remainingDates(spec, 5, DateTime(2026, 11, 20)),
          isEmpty,
          reason: 'At the count the program is complete and stable',
        );
        expect(
          Projection.remainingDates(spec, 6, DateTime(2026, 11, 20)),
          isEmpty,
          reason: 'Ordinals beyond the count cannot extend the program',
        );
      },
    );

    test('an anchor falling on from itself is a remaining date', () {
      final ConsecutiveCommitmentSpec spec = ConsecutiveCommitmentSpec(
        anchor: NthWeekdayOfMonthSpec(DateTime.saturday, 1),
        count: 5,
        policy: RestartPolicy.strict,
      );

      final List<DateTime> dates = Projection.remainingDates(
        spec,
        2,
        DateTime(2026, 11, 7),
      );

      expect(
        dates,
        <DateTime>[
          DateTime(2026, 11, 7),
          DateTime(2026, 12, 5),
          DateTime(2027, 1, 2),
        ],
        reason:
            'The walk opens on from itself; the November anchor '
            'is still completable on that date',
      );
    });

    test('projects date-only, ignoring time-of-day in from', () {
      final ConsecutiveCommitmentSpec spec = ConsecutiveCommitmentSpec(
        anchor: NthWeekdayOfMonthSpec(DateTime.saturday, 1),
        count: 5,
        policy: RestartPolicy.strict,
      );

      final List<DateTime> dates = Projection.remainingDates(
        spec,
        2,
        DateTime(2026, 11, 20, 18, 30),
      );

      expect(
        dates,
        <DateTime>[
          DateTime(2026, 12, 5),
          DateTime(2027, 1, 2),
          DateTime(2027, 2, 6),
        ],
        reason:
            'From is reduced to local midnight, and the projected '
            'dates are local midnight dates',
      );
    });

    test(
      'the projected dates complete the program CommitmentState evaluated',
      () {
        final ConsecutiveCommitmentSpec spec = ConsecutiveCommitmentSpec(
          anchor: NthWeekdayOfMonthSpec(DateTime.saturday, 1),
          count: 5,
          policy: RestartPolicy.permissive,
        );
        final CommitmentState state = CommitmentState.evaluate(spec, <DateTime>{
          DateTime(2026, 9, 5),
          DateTime(2026, 10, 3),
        }, DateTime(2026, 11, 20));
        expect(state.fulfilledOrdinals, 2);

        final List<DateTime> dates = Projection.remainingDates(
          spec,
          state.fulfilledOrdinals,
          DateTime(2026, 11, 20),
        );

        expect(
          dates,
          <DateTime>[
            DateTime(2026, 12, 5),
            DateTime(2027, 1, 2),
            DateTime(2027, 2, 6),
          ],
          reason:
              'The projection enumerates the positions the remaining '
              'fulfillments can take',
        );
      },
    );
  });
}
