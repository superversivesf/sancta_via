import 'package:sancta_via_devotional_engine/sancta_via_devotional_engine.dart';
import 'package:test/test.dart';

void main() {
  const ScheduleContext context = ScheduleContext();

  group('WeeklyLoopSpec', () {
    group('resolution', () {
      test('is due every Tuesday of December 2026 and only on those days', () {
        // December 2026 opens on a Tuesday, so its Tuesdays are 1, 8, 15,
        // 22, 29 — every other day of the month must be not due.
        final WeeklyLoopSpec spec = WeeklyLoopSpec(
          weekdays: <int>{DateTime.tuesday},
        );
        final List<int> tuesdays = <int>[1, 8, 15, 22, 29];

        for (int day = 1; day <= 31; day++) {
          final ScheduleResult result = spec.resolve(
            DateTime(2026, 12, day),
            context,
          );
          expect(
            result.due,
            tuesdays.contains(day),
            reason:
                '2026-12-$day must ${tuesdays.contains(day) ? '' : 'not'} '
                'be due for an every-Tuesday loop',
          );
        }
      });

      test('is due on every listed weekday', () {
        // December 2026: Saturdays are 5, 12, 19, 26; Sundays are 6, 13,
        // 20, 27.
        final WeeklyLoopSpec spec = WeeklyLoopSpec(
          weekdays: <int>{DateTime.saturday, DateTime.sunday},
        );

        expect(
          spec.resolve(DateTime(2026, 12, 5), context).due,
          isTrue,
          reason: '2026-12-05 is a Saturday in the weekend loop',
        );
        expect(
          spec.resolve(DateTime(2026, 12, 6), context).due,
          isTrue,
          reason: '2026-12-06 is a Sunday in the weekend loop',
        );
        expect(
          spec.resolve(DateTime(2026, 12, 7), context).due,
          isFalse,
          reason: '2026-12-07 is a Monday, not in the weekend loop',
        );
        expect(
          spec.resolve(DateTime(2026, 12, 4), context).due,
          isFalse,
          reason: '2026-12-04 is a Friday, not in the weekend loop',
        );
      });

      test('suppresses the whole month listed in skipMonths', () {
        final WeeklyLoopSpec spec = WeeklyLoopSpec(
          weekdays: <int>{DateTime.friday},
          skipMonths: <int>[12],
        );

        expect(
          spec.resolve(DateTime(2026, 12, 11), context).due,
          isFalse,
          reason:
              '2026-12-11 is a Friday, but December is listed in '
              'skipMonths, so the loop is suppressed for the whole month',
        );
        expect(
          spec.resolve(DateTime(2026, 11, 20), context).due,
          isTrue,
          reason: '2026-11-20 is a Friday outside any skipped month',
        );
      });

      test('suppresses each of the listed months', () {
        final WeeklyLoopSpec spec = WeeklyLoopSpec(
          weekdays: <int>{DateTime.friday},
          skipMonths: <int>[1, 7],
        );

        expect(
          spec.resolve(DateTime(2026, 1, 16), context).due,
          isFalse,
          reason: '2026-01-16 is a Friday in skipped January',
        );
        expect(
          spec.resolve(DateTime(2026, 7, 31), context).due,
          isFalse,
          reason: '2026-07-31 is a Friday in skipped July',
        );
        expect(
          spec.resolve(DateTime(2026, 8, 28), context).due,
          isTrue,
          reason: '2026-08-28 is a Friday in August, not skipped',
        );
      });

      test('treats an empty skipMonths like null (no suppression)', () {
        final WeeklyLoopSpec spec = WeeklyLoopSpec(
          weekdays: <int>{DateTime.friday},
          skipMonths: <int>[],
        );

        expect(
          spec.resolve(DateTime(2026, 12, 11), context).due,
          isTrue,
          reason: 'An empty suppression list suppresses nothing',
        );
      });

      test('reports no window position and no labels', () {
        final WeeklyLoopSpec spec = WeeklyLoopSpec(
          weekdays: <int>{DateTime.tuesday},
        );

        final ScheduleResult result = spec.resolve(
          DateTime(2026, 12, 8),
          context,
        );

        expect(result.due, isTrue);
        expect(result.dayIndex, isNull);
        expect(result.ordinal, isNull);
        expect(result.labels, isEmpty);
      });
    });

    group('validation', () {
      test('rejects an empty weekday set', () {
        expect(() => WeeklyLoopSpec(weekdays: <int>{}), throwsArgumentError);
      });

      test('rejects weekdays outside 1 (Monday) through 7 (Sunday)', () {
        expect(
          () => WeeklyLoopSpec(weekdays: <int>{DateTime.monday, 0}),
          throwsArgumentError,
        );
        expect(() => WeeklyLoopSpec(weekdays: <int>{8}), throwsArgumentError);
      });

      test('rejects skipMonths outside 1 through 12', () {
        expect(
          () => WeeklyLoopSpec(
            weekdays: <int>{DateTime.friday},
            skipMonths: <int>[0],
          ),
          throwsArgumentError,
        );
        expect(
          () => WeeklyLoopSpec(
            weekdays: <int>{DateTime.friday},
            skipMonths: <int>[13],
          ),
          throwsArgumentError,
        );
      });
    });
  });

  group('TimeOfDaySpec', () {
    group('resolution', () {
      test('is due on any date with a zero-padded HH:mm label', () {
        final TimeOfDaySpec spec = TimeOfDaySpec(15, 0);

        final ScheduleResult result = spec.resolve(
          DateTime(2026, 7, 15),
          context,
        );

        expect(result.due, isTrue, reason: 'A TimeOfDaySpec is due every day');
        expect(result.labels, equals(<String>['15:00']));
        expect(result.dayIndex, isNull);
        expect(result.ordinal, isNull);

        expect(
          spec.resolve(DateTime(2026, 2, 28), context).due,
          isTrue,
          reason: 'Due on a second, unrelated date',
        );
      });

      test('zero-pads single-digit hour and minute components', () {
        final TimeOfDaySpec spec = TimeOfDaySpec(6, 0);

        final ScheduleResult result = spec.resolve(
          DateTime(2026, 1, 20),
          context,
        );

        expect(result.due, isTrue);
        expect(result.labels, equals(<String>['06:00']));
      });

      test('is due regardless of the context season', () {
        final ScheduleResult result = TimeOfDaySpec(
          15,
          0,
        ).resolve(DateTime(2026, 4, 20), context);

        expect(result.due, isTrue);
      });
    });

    group('season variants', () {
      // The Regina Caeli replaces the Angelus in Eastertide. The variant
      // lists both a crude month window (April, May) and the season key it
      // really keys on, so selection can come from either source.
      final TimeOfDaySpec spec = TimeOfDaySpec(
        6,
        0,
        baseLabel: 'angelus',
        variants: <SeasonVariant>[
          SeasonVariant(
            months: <int>[4, 5],
            seasons: <String>{'eastertide'},
            variantId: 'regina_caeli',
          ),
        ],
      );

      test('uses the variant id when the date month matches', () {
        final ScheduleResult result = spec.resolve(
          DateTime(2026, 4, 20),
          ScheduleContext(seasonKeyValue: 'Eastertide'),
        );

        expect(result.due, isTrue);
        expect(result.labels, equals(<String>['regina_caeli']));
      });

      test(
        'uses the variant id when the context season matches, even off-month',
        () {
          // January is outside the variant's months, but the context says the
          // date is Eastertide, which the variant keys on.
          final ScheduleResult eastertide = spec.resolve(
            DateTime(2026, 1, 20),
            ScheduleContext(seasonKeyValue: 'Eastertide'),
          );

          expect(eastertide.due, isTrue);
          expect(eastertide.labels, equals(<String>['regina_caeli']));
        },
      );

      test('falls back to the base label when nothing matches', () {
        final ScheduleResult christmas = spec.resolve(
          DateTime(2026, 1, 20),
          ScheduleContext(seasonKeyValue: 'Christmas'),
        );

        expect(
          christmas.labels,
          equals(<String>['angelus']),
          reason:
              'January is not a variant month and the Christmas season '
              'does not match, so the base label applies',
        );
        expect(christmas.due, isTrue);

        final ScheduleResult noSeason = spec.resolve(
          DateTime(2026, 1, 20),
          context,
        );

        expect(
          noSeason.labels,
          equals(<String>['angelus']),
          reason: 'A context without a season key can never match by season',
        );
      });

      test('matches season keys case-insensitively', () {
        // March misses the month window; the variant must be selected by
        // the season key alone, compared without case sensitivity.
        final ScheduleResult result = spec.resolve(
          DateTime(2026, 3, 20),
          ScheduleContext(seasonKeyValue: 'EASTERtide'),
        );

        expect(result.labels, equals(<String>['regina_caeli']));
      });

      test('uses the first matching variant', () {
        final TimeOfDaySpec first = TimeOfDaySpec(
          18,
          0,
          baseLabel: 'evening_prayer',
          variants: <SeasonVariant>[
            SeasonVariant(months: <int>[4], variantId: 'first_match'),
            SeasonVariant(
              months: <int>[4],
              seasons: <String>{'eastertide'},
              variantId: 'second_match',
            ),
          ],
        );

        final ScheduleResult result = first.resolve(
          DateTime(2026, 4, 10),
          ScheduleContext(seasonKeyValue: 'Eastertide'),
        );

        expect(
          result.labels,
          equals(<String>['first_match']),
          reason: 'The first variant listing a match wins',
        );
      });

      test('matches a seasons-only variant by season alone', () {
        final TimeOfDaySpec seasonsOnly = TimeOfDaySpec(
          6,
          0,
          baseLabel: 'angelus',
          variants: <SeasonVariant>[
            SeasonVariant(
              months: <int>[],
              seasons: <String>{'lent'},
              variantId: 'lent_version',
            ),
          ],
        );

        final ScheduleResult result = seasonsOnly.resolve(
          DateTime(2026, 2, 18),
          ScheduleContext(seasonKeyValue: 'lent'),
        );

        expect(result.labels, equals(<String>['lent_version']));
      });
    });

    group('validation', () {
      test('rejects an out-of-range hour', () {
        expect(() => TimeOfDaySpec(24, 0), throwsArgumentError);
        expect(() => TimeOfDaySpec(-1, 0), throwsArgumentError);
      });

      test('rejects an out-of-range minute', () {
        expect(() => TimeOfDaySpec(0, 60), throwsArgumentError);
        expect(() => TimeOfDaySpec(0, -1), throwsArgumentError);
      });

      test('rejects variant months outside 1 through 12', () {
        expect(
          () => SeasonVariant(months: <int>[0], variantId: 'regina_caeli'),
          throwsArgumentError,
        );
        expect(
          () => SeasonVariant(months: <int>[13], variantId: 'regina_caeli'),
          throwsArgumentError,
        );
      });

      test('rejects an empty variant id', () {
        expect(
          () => SeasonVariant(months: <int>[4, 5], variantId: ''),
          throwsArgumentError,
        );
      });

      test('rejects a variant that can never match', () {
        // Neither a month window nor a season key: no date could ever
        // select this variant.
        expect(
          () => SeasonVariant(months: <int>[], variantId: 'regina_caeli'),
          throwsArgumentError,
        );
      });
    });
  });
}
