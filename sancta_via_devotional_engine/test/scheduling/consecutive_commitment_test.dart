import 'package:sancta_via_devotional_engine/sancta_via_devotional_engine.dart';
import 'package:test/test.dart';

const ScheduleContext _context = ScheduleContext();

/// The dates in [start, end] on which [spec] resolves as due, by walking the
/// calendar day by day — the same discipline CommitmentState.evaluate applies
/// when deriving the anchor dates a commitment recurs on.
List<DateTime> _anchorsBetween(
  ScheduleSpec spec,
  DateTime start,
  DateTime end,
) {
  final List<DateTime> anchors = <DateTime>[];
  for (
    DateTime d = DateTime(start.year, start.month, start.day);
    !d.isAfter(end);
    d = DateTime(d.year, d.month, d.day + 1)
  ) {
    if (spec.resolve(d, _context).due) {
      anchors.add(d);
    }
  }
  return anchors;
}

void main() {
  const ScheduleContext context = ScheduleContext();

  group('ConsecutiveCommitmentSpec', () {
    group('validation', () {
      test('rejects a count below 1', () {
        expect(
          () => ConsecutiveCommitmentSpec(
            anchor: NthWeekdayOfMonthSpec(DateTime.saturday, 1),
            count: 0,
            policy: RestartPolicy.strict,
          ),
          throwsArgumentError,
        );
      });
    });

    group('resolution', () {
      test('resolves due exactly as its anchor spec resolves', () {
        final ConsecutiveCommitmentSpec spec = ConsecutiveCommitmentSpec(
          anchor: NthWeekdayOfMonthSpec(DateTime.saturday, 1),
          count: 5,
          policy: RestartPolicy.strict,
        );

        expect(
          spec.resolve(DateTime(2026, 9, 5), context).due,
          isTrue,
          reason:
              'September 2026 opens on a Tuesday; the 1st Saturday is '
              'September 5, so the anchor is due and so is the commitment',
        );
        expect(
          spec.resolve(DateTime(2026, 9, 6), context).due,
          isFalse,
          reason: 'The commitment is due only where its anchor is due',
        );
        expect(
          spec.resolve(DateTime(2026, 9, 12), context).due,
          isFalse,
          reason: 'September 12 is the 2nd Saturday, not the 1st',
        );
      });
    });
  });

  group('GraceWindow', () {
    group('admits', () {
      test(
        'admits completions inside the inclusive window around the anchor',
        () {
          final GraceWindow window = GraceWindow(
            item: 'confession',
            beforeDays: 8,
            afterDays: 8,
          );

          expect(
            window.admits(DateTime(2026, 11, 7), DateTime(2026, 11, 7)),
            isTrue,
            reason: 'A completion on the anchor day itself admits',
          );
          expect(
            window.admits(DateTime(2026, 11, 7), DateTime(2026, 10, 30)),
            isTrue,
            reason: 'October 30 is exactly 8 days before the anchor',
          );
          expect(
            window.admits(DateTime(2026, 11, 7), DateTime(2026, 11, 15)),
            isTrue,
            reason: 'November 15 is exactly 8 days after the anchor',
          );
        },
      );

      test('rejects completions beyond the window edges', () {
        final GraceWindow window = GraceWindow(
          item: 'confession',
          beforeDays: 8,
          afterDays: 8,
        );

        expect(
          window.admits(DateTime(2026, 11, 7), DateTime(2026, 10, 29)),
          isFalse,
          reason: 'October 29 is 9 days before the anchor',
        );
        expect(
          window.admits(DateTime(2026, 11, 7), DateTime(2026, 11, 16)),
          isFalse,
          reason: 'November 16 is 9 days after the anchor',
        );
      });

      test('honours asymmetric before and after days', () {
        final GraceWindow window = GraceWindow(
          item: 'rosary',
          beforeDays: 3,
          afterDays: 1,
        );

        expect(
          window.admits(DateTime(2026, 11, 7), DateTime(2026, 11, 4)),
          isTrue,
          reason: 'Exactly 3 days before is the edge of the window',
        );
        expect(
          window.admits(DateTime(2026, 11, 7), DateTime(2026, 11, 3)),
          isFalse,
        );
        expect(
          window.admits(DateTime(2026, 11, 7), DateTime(2026, 11, 8)),
          isTrue,
          reason: 'Exactly 1 day after is the edge of the window',
        );
        expect(
          window.admits(DateTime(2026, 11, 7), DateTime(2026, 11, 9)),
          isFalse,
        );
      });
    });

    group('validation', () {
      test('rejects an empty item', () {
        expect(
          () => GraceWindow(item: '', beforeDays: 8, afterDays: 8),
          throwsArgumentError,
        );
      });

      test('rejects negative beforeDays and afterDays', () {
        expect(
          () => GraceWindow(item: 'confession', beforeDays: -1, afterDays: 8),
          throwsArgumentError,
        );
        expect(
          () => GraceWindow(item: 'confession', beforeDays: 8, afterDays: -1),
          throwsArgumentError,
        );
      });
    });
  });

  group('CommitmentState.evaluate', () {
    test('the brief dates are the recurrence dates of their anchor specs', () {
      final List<DateTime> saturdays = _anchorsBetween(
        NthWeekdayOfMonthSpec(DateTime.saturday, 1),
        DateTime(2026, 9, 1),
        DateTime(2027, 1, 31),
      );
      final List<DateTime> fridays = _anchorsBetween(
        NthWeekdayOfMonthSpec(DateTime.friday, 1),
        DateTime(2026, 2, 1),
        DateTime(2027, 1, 31),
      );

      expect(saturdays, <DateTime>[
        DateTime(2026, 9, 5),
        DateTime(2026, 10, 3),
        DateTime(2026, 11, 7),
        DateTime(2026, 12, 5),
        DateTime(2027, 1, 2),
      ], reason: 'The 1st Saturdays from September 2026 through January 2027');
      expect(fridays, <DateTime>[
        DateTime(2026, 2, 6),
        DateTime(2026, 3, 6),
        DateTime(2026, 4, 3),
        DateTime(2026, 5, 1),
        DateTime(2026, 6, 5),
        DateTime(2026, 7, 3),
        DateTime(2026, 8, 7),
        DateTime(2026, 9, 4),
        DateTime(2026, 10, 2),
        DateTime(2026, 11, 6),
        DateTime(2026, 12, 4),
        DateTime(2027, 1, 1),
      ], reason: 'The 1st Fridays from February 2026 through January 2027');
    });

    test('empty completions yield a zero state', () {
      final ConsecutiveCommitmentSpec spec = ConsecutiveCommitmentSpec(
        anchor: NthWeekdayOfMonthSpec(DateTime.saturday, 1),
        count: 5,
        policy: RestartPolicy.strict,
      );

      final CommitmentState state = CommitmentState.evaluate(
        spec,
        <DateTime>{},
        DateTime(2026, 11, 8),
      );

      expect(state.fulfilledOrdinals, 0);
      expect(state.lastFulfilledAnchor, isNull);
      expect(state.labels, isEmpty);
      expect(state.nextOrdinal, isNull);
    });

    test('three of the Five First Saturdays evaluates as the 3rd, Nov 7', () {
      final ConsecutiveCommitmentSpec spec = ConsecutiveCommitmentSpec(
        anchor: NthWeekdayOfMonthSpec(DateTime.saturday, 1),
        count: 5,
        policy: RestartPolicy.strict,
      );
      final Set<DateTime> completed = <DateTime>{
        DateTime(2026, 9, 5),
        DateTime(2026, 10, 3),
        DateTime(2026, 11, 7),
      };

      final CommitmentState state = CommitmentState.evaluate(
        spec,
        completed,
        DateTime(2026, 11, 8),
      );

      expect(state.fulfilledOrdinals, 3);
      expect(state.lastFulfilledAnchor, DateTime(2026, 11, 7));
      expect(
        state.labels,
        isEmpty,
        reason: 'A clean run carries no gap labels',
      );
      expect(
        state.nextOrdinal,
        isNull,
        reason: 'November 8 is not a First Saturday anchor date',
      );
    });

    test('the same holds under the permissive policy', () {
      final ConsecutiveCommitmentSpec spec = ConsecutiveCommitmentSpec(
        anchor: NthWeekdayOfMonthSpec(DateTime.saturday, 1),
        count: 5,
        policy: RestartPolicy.permissive,
      );
      final Set<DateTime> completed = <DateTime>{
        DateTime(2026, 9, 5),
        DateTime(2026, 10, 3),
        DateTime(2026, 11, 7),
      };

      final CommitmentState state = CommitmentState.evaluate(
        spec,
        completed,
        DateTime(2026, 11, 8),
      );

      expect(state.fulfilledOrdinals, 3);
      expect(state.lastFulfilledAnchor, DateTime(2026, 11, 7));
    });

    test('a missed anchor is never silently rolled forward', () {
      // The December 5, 2026 anchor is missed: even today, on the anchor
      // date itself, the strict count drops to 0 and the miss is labelled.
      final Set<DateTime> completed = <DateTime>{
        DateTime(2026, 9, 5),
        DateTime(2026, 10, 3),
        DateTime(2026, 11, 7),
      };

      final CommitmentState strictState = CommitmentState.evaluate(
        ConsecutiveCommitmentSpec(
          anchor: NthWeekdayOfMonthSpec(DateTime.saturday, 1),
          count: 5,
          policy: RestartPolicy.strict,
        ),
        completed,
        DateTime(2026, 12, 5),
      );

      expect(
        strictState.fulfilledOrdinals,
        0,
        reason: 'The series restarts at the first missed anchor',
      );
      expect(strictState.labels, <String>['gap: 2026-12-05']);
      expect(
        strictState.nextOrdinal,
        1,
        reason: 'Today completes the 1st of the restarted series',
      );

      final CommitmentState permissiveState = CommitmentState.evaluate(
        ConsecutiveCommitmentSpec(
          anchor: NthWeekdayOfMonthSpec(DateTime.saturday, 1),
          count: 5,
          policy: RestartPolicy.permissive,
        ),
        completed,
        DateTime(2026, 12, 5),
      );

      expect(
        permissiveState.fulfilledOrdinals,
        3,
        reason: 'Ordinals continue across the gap',
      );
      expect(permissiveState.labels, <String>['gap: 2026-12-05']);
      expect(permissiveState.nextOrdinal, 4);
    });

    test(
      'strict restarts after the December gap; permissive continues to 4',
      () {
        // Completing January 2, 2027 after having skipped the December 5,
        // 2026 First Saturday.
        final Set<DateTime> completed = <DateTime>{
          DateTime(2026, 9, 5),
          DateTime(2026, 10, 3),
          DateTime(2026, 11, 7),
          DateTime(2027, 1, 2),
        };
        final DateTime today = DateTime(2027, 1, 2);

        final CommitmentState strictState = CommitmentState.evaluate(
          ConsecutiveCommitmentSpec(
            anchor: NthWeekdayOfMonthSpec(DateTime.saturday, 1),
            count: 5,
            policy: RestartPolicy.strict,
          ),
          completed,
          today,
        );

        expect(
          strictState.fulfilledOrdinals,
          1,
          reason:
              'Strict counts only from the December gap: the series '
              'restarts with the January 2 completion',
        );
        expect(strictState.lastFulfilledAnchor, DateTime(2027, 1, 2));
        expect(
          strictState.labels,
          <String>['gap: 2026-12-05'],
          reason: 'The restart is never silent: the missed anchor is labelled',
        );
        expect(strictState.nextOrdinal, 2);

        final CommitmentState permissiveState = CommitmentState.evaluate(
          ConsecutiveCommitmentSpec(
            anchor: NthWeekdayOfMonthSpec(DateTime.saturday, 1),
            count: 5,
            policy: RestartPolicy.permissive,
          ),
          completed,
          today,
        );

        expect(
          permissiveState.fulfilledOrdinals,
          4,
          reason: 'Permissive ordinals continue across the gap to the 4th',
        );
        expect(permissiveState.lastFulfilledAnchor, DateTime(2027, 1, 2));
        expect(permissiveState.labels, <String>[
          'gap: 2026-12-05',
        ], reason: 'Permissive continuity is flagged with a gap label');
        expect(permissiveState.nextOrdinal, 5);
      },
    );

    test('nine First Fridays: strict counts the clean run to the 6th by '
        '2027-01-01; permissive continues with the gap labelled', () {
      // Five First Fridays completed, then the July 3, 2026 anchor missed,
      // then a clean run reaching 2027-01-01 as its 6th.
      final Set<DateTime> completed = <DateTime>{
        DateTime(2026, 2, 6),
        DateTime(2026, 3, 6),
        DateTime(2026, 4, 3),
        DateTime(2026, 5, 1),
        DateTime(2026, 6, 5),
        DateTime(2026, 8, 7),
        DateTime(2026, 9, 4),
        DateTime(2026, 10, 2),
        DateTime(2026, 11, 6),
        DateTime(2026, 12, 4),
        DateTime(2027, 1, 1),
      };
      final DateTime today = DateTime(2027, 1, 2);

      final CommitmentState strictState = CommitmentState.evaluate(
        ConsecutiveCommitmentSpec(
          anchor: NthWeekdayOfMonthSpec(DateTime.friday, 1),
          count: 9,
          policy: RestartPolicy.strict,
        ),
        completed,
        today,
      );

      expect(
        strictState.fulfilledOrdinals,
        6,
        reason:
            '2027-01-01 is the 6th of the clean run that begins '
            'after the July gap',
      );
      expect(strictState.lastFulfilledAnchor, DateTime(2027, 1, 1));
      expect(strictState.labels, <String>['gap: 2026-07-03']);
      expect(
        strictState.nextOrdinal,
        isNull,
        reason: '2027-01-02 is a Saturday, not a First Friday',
      );

      final CommitmentState permissiveState = CommitmentState.evaluate(
        ConsecutiveCommitmentSpec(
          anchor: NthWeekdayOfMonthSpec(DateTime.friday, 1),
          count: 9,
          policy: RestartPolicy.permissive,
        ),
        completed,
        today,
      );

      expect(
        permissiveState.fulfilledOrdinals,
        11,
        reason: 'Ordinals continue across the gap: 5 before, 6 after',
      );
      expect(permissiveState.lastFulfilledAnchor, DateTime(2027, 1, 1));
      expect(permissiveState.labels, <String>['gap: 2026-07-03']);
    });

    test(
      'a grace window admits a completion near an otherwise-missed anchor',
      () {
        // The First Saturday confession may be made within 8 days of the
        // anchor: a November 14 completion admits the November 7 anchor.
        final ConsecutiveCommitmentSpec spec = ConsecutiveCommitmentSpec(
          anchor: NthWeekdayOfMonthSpec(DateTime.saturday, 1),
          count: 5,
          policy: RestartPolicy.strict,
          windows: <GraceWindow>[
            GraceWindow(item: 'confession', beforeDays: 8, afterDays: 8),
          ],
        );

        final CommitmentState state = CommitmentState.evaluate(spec, <DateTime>{
          DateTime(2026, 9, 5),
          DateTime(2026, 10, 3),
          DateTime(2026, 11, 14),
        }, DateTime(2026, 11, 15));

        expect(
          state.fulfilledOrdinals,
          3,
          reason:
              'The November 7 anchor is admitted by the November 14 '
              'completion, 7 days after it and inside the window',
        );
        expect(state.lastFulfilledAnchor, DateTime(2026, 11, 7));
        expect(state.labels, isEmpty);
      },
    );

    test('a completion outside the grace window leaves the anchor missed', () {
      // November 16 is 9 days after the anchor: even with the ±8 window,
      // the November 7 anchor stays missed and is labelled.
      final CommitmentState strictState = CommitmentState.evaluate(
        ConsecutiveCommitmentSpec(
          anchor: NthWeekdayOfMonthSpec(DateTime.saturday, 1),
          count: 5,
          policy: RestartPolicy.strict,
          windows: <GraceWindow>[
            GraceWindow(item: 'confession', beforeDays: 8, afterDays: 8),
          ],
        ),
        <DateTime>{
          DateTime(2026, 9, 5),
          DateTime(2026, 10, 3),
          DateTime(2026, 11, 16),
        },
        DateTime(2026, 11, 17),
      );

      expect(
        strictState.fulfilledOrdinals,
        0,
        reason:
            'The November 7 anchor stays missed, so strict restarts '
            'the series — the window does not paper over the gap',
      );
      expect(strictState.labels, <String>['gap: 2026-11-07']);
      expect(strictState.lastFulfilledAnchor, DateTime(2026, 10, 3));

      final CommitmentState permissiveState = CommitmentState.evaluate(
        ConsecutiveCommitmentSpec(
          anchor: NthWeekdayOfMonthSpec(DateTime.saturday, 1),
          count: 5,
          policy: RestartPolicy.permissive,
          windows: <GraceWindow>[
            GraceWindow(item: 'confession', beforeDays: 8, afterDays: 8),
          ],
        ),
        <DateTime>{
          DateTime(2026, 9, 5),
          DateTime(2026, 10, 3),
          DateTime(2026, 11, 16),
        },
        DateTime(2026, 11, 17),
      );

      expect(permissiveState.fulfilledOrdinals, 2);
      expect(permissiveState.labels, <String>['gap: 2026-11-07']);
    });

    test('evaluates completions date-only, ignoring time-of-day', () {
      final ConsecutiveCommitmentSpec spec = ConsecutiveCommitmentSpec(
        anchor: NthWeekdayOfMonthSpec(DateTime.saturday, 1),
        count: 5,
        policy: RestartPolicy.strict,
      );

      final CommitmentState state = CommitmentState.evaluate(spec, <DateTime>{
        DateTime(2026, 11, 7, 18, 30),
      }, DateTime(2026, 11, 8));

      expect(state.fulfilledOrdinals, 1);
      expect(state.lastFulfilledAnchor, DateTime(2026, 11, 7));
    });

    test('completions after today are ignored', () {
      final ConsecutiveCommitmentSpec spec = ConsecutiveCommitmentSpec(
        anchor: NthWeekdayOfMonthSpec(DateTime.saturday, 1),
        count: 5,
        policy: RestartPolicy.strict,
      );

      final CommitmentState state = CommitmentState.evaluate(spec, <DateTime>{
        DateTime(2026, 10, 3),
      }, DateTime(2026, 7, 15));

      expect(state.fulfilledOrdinals, 0);
      expect(state.lastFulfilledAnchor, isNull);
      expect(state.labels, isEmpty);
      expect(
        state.nextOrdinal,
        isNull,
        reason: 'July 15, 2026 is not a First Saturday anchor date',
      );
    });
  });
}
