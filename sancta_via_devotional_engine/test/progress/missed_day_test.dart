import 'dart:convert';

import 'package:sancta_via_devotional_engine/sancta_via_devotional_engine.dart';
import 'package:test/test.dart';

/// The progressed commitment the brief pins: 5 of 9 ordinals fulfilled,
/// last fulfilled 2026-12-05, two repetitions recorded today, one badge
/// earned, and per-day items keyed `<item>:<yyyy-mm-dd>`.
ProgressState progressedState() => ProgressState(
  packId: 'first-saturdays',
  fulfilledOrdinals: 5,
  lastFulfilled: DateTime(2026, 12, 5),
  repetitionsToday: 2,
  completedItemsByDay: const <String, String>{
    'confession:2026-12-05': 'heard before the Saturday Mass',
    'communion:2026-12-05': 'received at the Saturday Mass',
  },
  badges: <BadgeRecord>[
    BadgeRecord(title: 'First Saturday kept', date: DateTime(2026, 12, 5)),
  ],
);

/// A state with nothing completed yet: no ordinals, no recorded items.
ProgressState freshState() => ProgressState(packId: 'first-saturdays');

void main() {
  group('MissedDayEvaluator', () {
    group('strict policy', () {
      test(
        'resets across a gap (state 5/9, gap between it and 2027-01-01)',
        () {
          expect(
            MissedDayEvaluator.evaluate(
              'strict',
              progressedState(),
              DateTime(2026, 12, 5),
              DateTime(2027, 1, 1),
            ),
            MissedDayVerdict.reset,
            reason:
                'Full calendar days lie strictly between 2026-12-05 and '
                '2027-01-01: under strict, the skipped span voids the series '
                'and the ordinals restart',
          );
        },
      );

      test(
        'resumes when next due directly follows the last fulfilled date',
        () {
          expect(
            MissedDayEvaluator.evaluate(
              'strict',
              progressedState(),
              DateTime(2026, 12, 31),
              DateTime(2027, 1, 1),
            ),
            MissedDayVerdict.resume,
            reason: 'No calendar day lies strictly between adjacent dates',
          );
        },
      );

      test('judges calendar dates, never time-of-day', () {
        expect(
          MissedDayEvaluator.evaluate(
            'strict',
            progressedState(),
            DateTime(2026, 12, 31, 23, 59),
            DateTime(2027, 1, 1, 0, 15),
          ),
          MissedDayVerdict.resume,
          reason:
              'The dates are adjacent calendar days; a span of hours never '
              'counts as a gap',
        );
      });
    });

    group('permissive policy', () {
      test('resumes across the same gap', () {
        expect(
          MissedDayEvaluator.evaluate(
            'permissive',
            progressedState(),
            DateTime(2026, 12, 5),
            DateTime(2027, 1, 1),
          ),
          MissedDayVerdict.resume,
          reason: 'Permissive continues across a skipped span',
        );
      });

      test('resumes when there is no gap', () {
        expect(
          MissedDayEvaluator.evaluate(
            'permissive',
            progressedState(),
            DateTime(2026, 12, 31),
            DateTime(2027, 1, 1),
          ),
          MissedDayVerdict.resume,
        );
      });
    });

    group('boundary: a state with nothing completed yet', () {
      test('asks the user — state 0, no completions, nothing to reset', () {
        expect(
          MissedDayEvaluator.evaluate(
            'strict',
            freshState(),
            DateTime(2026, 12, 5),
            DateTime(2027, 1, 1),
          ),
          MissedDayVerdict.askUser,
          reason: 'There is no streak to reset, so the user starts afresh',
        );
        expect(
          MissedDayEvaluator.evaluate(
            'permissive',
            freshState(),
            DateTime(2026, 12, 5),
            DateTime(2027, 1, 1),
          ),
          MissedDayVerdict.askUser,
          reason: 'There is no streak to continue either',
        );
      });
    });

    test('rejects an unknown policy', () {
      expect(
        () => MissedDayEvaluator.evaluate(
          'lenient',
          progressedState(),
          DateTime(2026, 12, 5),
          DateTime(2027, 1, 1),
        ),
        throwsArgumentError,
      );
    });
  });

  group('cadence scope (documented behavior, not a bug)', () {
    test('reads a wide span as a gap on an anchor-recurring cadence', () {
      expect(
        MissedDayEvaluator.evaluate(
          'strict',
          progressedState(),
          DateTime(2026, 12, 5),
          DateTime(2027, 1, 2),
        ),
        MissedDayVerdict.reset,
        reason:
            'DOCUMENTED behavior, not a bug: the gap rule counts calendar '
            'days only, so on an anchor-recurring cadence (First '
            'Saturdays, ~4 weeks apart) the span is always wide and '
            'strict reads reset even when every consecutive position was '
            'kept — CommitmentState.evaluate, not this evaluator, drives '
            'such commitments',
      );
    });

    test('CommitmentState.evaluate flags no gap for the kept same pair', () {
      // The real First-Saturdays spec from the Task 6 test patterns:
      final ConsecutiveCommitmentSpec spec = ConsecutiveCommitmentSpec(
        anchor: NthWeekdayOfMonthSpec(DateTime.saturday, 1),
        count: 5,
        policy: RestartPolicy.strict,
      );

      // The same pair as the degenerate case above (kept 2026-12-05,
      // next due 2027-01-02), judged by the strict commitment engine as
      // of the day before the next due date — nextDue itself is today's
      // due position, not an already-passed one:
      final CommitmentState state = CommitmentState.evaluate(spec, <DateTime>{
        DateTime(2026, 12, 5),
      }, DateTime(2027, 1, 1));

      expect(state.fulfilledOrdinals, equals(1));
      expect(
        state.labels,
        isEmpty,
        reason: 'Only one First Saturday has passed; none was skipped',
      );
      expect(state.lastFulfilledAnchor, equals(DateTime(2026, 12, 5)));
    });
  });

  group('BadgeRecord', () {
    test('rejects an empty title', () {
      expect(
        () => BadgeRecord(title: '', date: DateTime(2026, 12, 5)),
        throwsArgumentError,
      );
    });

    test('reduces the date to a local midnight calendar date', () {
      final BadgeRecord badge = BadgeRecord(
        title: 'First Saturday kept',
        date: DateTime(2026, 12, 5, 18, 30),
      );

      expect(badge.date, DateTime(2026, 12, 5));
    });

    test('toJson/fromJson round-trip preserves the title and date', () {
      final BadgeRecord badge = BadgeRecord(
        title: 'First Saturday kept',
        date: DateTime(2026, 12, 5),
      );
      final BadgeRecord reparsed = BadgeRecord.fromJson(
        jsonDecode(jsonEncode(badge.toJson())) as Map<String, dynamic>,
      );

      expect(reparsed.title, equals('First Saturday kept'));
      expect(reparsed.date, equals(DateTime(2026, 12, 5)));
    });
  });

  group('ProgressState', () {
    group('validation', () {
      test('rejects an empty packId', () {
        expect(
          () => ProgressState(packId: ''),
          throwsA(
            isA<ArgumentError>().having(
              (ArgumentError e) => e.message,
              'message',
              contains('packId'),
            ),
          ),
        );
      });

      test('rejects a badge whose title is empty', () {
        expect(
          () => ProgressState(
            packId: 'first-saturdays',
            badges: <BadgeRecord>[
              BadgeRecord(title: '', date: DateTime(2026, 12, 5)),
            ],
          ),
          throwsArgumentError,
        );
      });
    });

    group('collections', () {
      test('exposes unmodifiable collections', () {
        final ProgressState state = ProgressState(
          packId: 'first-saturdays',
          completedItemsByDay: <String, String>{
            'confession:2026-12-05': 'heard',
          },
          badges: <BadgeRecord>[
            BadgeRecord(title: 'kept', date: DateTime(2026, 12, 5)),
          ],
        );

        expect(
          () => state.completedItemsByDay['rosary:2026-12-06'] = 'decade',
          throwsUnsupportedError,
          reason: 'completedItemsByDay is backed by an unmodifiable map',
        );
        expect(
          () => state.badges.add(
            BadgeRecord(title: 'late', date: DateTime(2026, 12, 6)),
          ),
          throwsUnsupportedError,
          reason: 'badges is backed by an unmodifiable list',
        );
      });

      test('does not alias the caller-supplied collections', () {
        final Map<String, String> completions = <String, String>{
          'confession:2026-12-05': 'heard',
        };
        final List<BadgeRecord> badges = <BadgeRecord>[
          BadgeRecord(title: 'kept', date: DateTime(2026, 12, 5)),
        ];
        final ProgressState state = ProgressState(
          packId: 'first-saturdays',
          completedItemsByDay: completions,
          badges: badges,
        );

        completions['rosary:2026-12-06'] = 'decade';
        badges.add(BadgeRecord(title: 'late', date: DateTime(2026, 12, 6)));

        expect(state.completedItemsByDay.length, equals(1));
        expect(state.badges.length, equals(1));
      });
    });

    group('toJson/fromJson', () {
      test('writes date-only ISO strings and omits a null lastFulfilled', () {
        final Map<String, dynamic> json = progressedState().toJson();

        expect(json['packId'], equals('first-saturdays'));
        expect(json['fulfilledOrdinals'], equals(5));
        expect(json['lastFulfilled'], equals('2026-12-05'));
        expect(json['repetitionsToday'], equals(2));
        expect(json['completedItemsByDay'], <String, dynamic>{
          'confession:2026-12-05': 'heard before the Saturday Mass',
          'communion:2026-12-05': 'received at the Saturday Mass',
        });
        expect((json['badges'] as List<dynamic>).single, <String, dynamic>{
          'title': 'First Saturday kept',
          'date': '2026-12-05',
        });

        final Map<String, dynamic> fresh = freshState().toJson();
        expect(fresh.containsKey('lastFulfilled'), isFalse);
        expect(fresh['fulfilledOrdinals'], equals(0));
        expect(fresh['repetitionsToday'], equals(0));
        expect(fresh['completedItemsByDay'], isEmpty);
        expect(fresh['badges'], isEmpty);
      });

      test('fromJson(toJson(state)) round-trips a populated state', () {
        final ProgressState state = progressedState();
        final ProgressState reparsed = ProgressState.fromJson(
          jsonDecode(jsonEncode(state.toJson())) as Map<String, dynamic>,
        );

        expect(reparsed.packId, equals('first-saturdays'));
        expect(reparsed.fulfilledOrdinals, equals(5));
        expect(reparsed.lastFulfilled, equals(DateTime(2026, 12, 5)));
        expect(reparsed.repetitionsToday, equals(2));
        expect(reparsed.completedItemsByDay, equals(state.completedItemsByDay));
        expect(reparsed.badges.length, equals(1));
        expect(reparsed.badges.single.title, equals('First Saturday kept'));
        expect(reparsed.badges.single.date, equals(DateTime(2026, 12, 5)));
      });

      test('round-trips the zero state', () {
        final ProgressState reparsed = ProgressState.fromJson(
          jsonDecode(jsonEncode(freshState().toJson())) as Map<String, dynamic>,
        );

        expect(reparsed.packId, equals('first-saturdays'));
        expect(reparsed.fulfilledOrdinals, equals(0));
        expect(reparsed.lastFulfilled, isNull);
        expect(reparsed.repetitionsToday, equals(0));
        expect(reparsed.completedItemsByDay, isEmpty);
        expect(reparsed.badges, isEmpty);
      });

      test('defaults every field but packId to the zero state', () {
        final ProgressState state = ProgressState.fromJson(<String, dynamic>{
          'packId': 'first-saturdays',
        });

        expect(state.packId, equals('first-saturdays'));
        expect(state.fulfilledOrdinals, equals(0));
        expect(state.lastFulfilled, isNull);
        expect(state.repetitionsToday, equals(0));
        expect(state.completedItemsByDay, isEmpty);
        expect(state.badges, isEmpty);
      });

      test('accumulates every problem into one ContentValidationException', () {
        expect(
          () => ProgressState.fromJson(<String, dynamic>{
            'fulfilledOrdinals': 'five',
            'repetitionsToday': <int>[],
            'lastFulfilled': '2026-12-05T10:30:00Z',
            'completedItemsByDay': <String, dynamic>{
              'confession:2026-12-05': 3,
            },
            'badges': <Map<String, dynamic>>[
              <String, dynamic>{'title': '', 'date': '2026-12-05'},
              <String, dynamic>{'title': 'kept', 'date': 'not-a-date'},
            ],
          }),
          throwsA(
            isA<ContentValidationException>().having(
              (ContentValidationException e) => e.problems,
              'problems',
              containsAll(<String>[
                'packId must be a non-empty string',
                "'fulfilledOrdinals' must be an integer",
                "'repetitionsToday' must be an integer",
                "'lastFulfilled' must be a date-only string "
                    '(no time-zone designator)',
                'completedItemsByDay.confession:2026-12-05 must be a string',
                'badges[0]: title must not be empty',
                'badges[1]: date "not-a-date" is not an ISO date string',
              ]),
            ),
          ),
        );
      });

      test('reports an unparsable lastFulfilled date', () {
        expect(
          () => ProgressState.fromJson(<String, dynamic>{
            'packId': 'first-saturdays',
            'lastFulfilled': 'not-a-date',
          }),
          throwsA(
            isA<ContentValidationException>().having(
              (ContentValidationException e) => e.problems,
              'problems',
              contains(
                "'lastFulfilled' \"not-a-date\" is not an ISO date "
                'string',
              ),
            ),
          ),
        );
      });
    });
  });
}
