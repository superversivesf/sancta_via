import 'package:sancta_via_devotional_engine/sancta_via_devotional_engine.dart';
import 'package:sancta_via_liturgical_calendar/sancta_via_liturgical_calendar.dart';
import 'package:test/test.dart';

/// Fixture directory the daily-anchor packs live in (task 14).
const String fixtureDir = 'test/fixtures/packs';

/// Loads the fixture pack with the given [id] (one devotion per pack).
ContentPack loadPack(String id) {
  final List<ContentPack> packs = PackLoader.loadFixturesIn(fixtureDir);
  return packs.firstWhere(
    (ContentPack pack) => pack.id == id,
    orElse: () => throw StateError(
      'test/fixtures/packs must contain a $id pack; '
      'loaded ids: ${packs.map((ContentPack p) => p.id).toList()}',
    ),
  );
}

/// A [ScheduleContext] carrying the real embedded calendar data's seasonKey
/// for [date], as the loader contract requires for label resolution.
ScheduleContext contextFor(DateTime date) {
  final LiturgicalDayData? day = LiturgicalCalendarService.getDayForDate(date);
  return ScheduleContext(seasonKeyValue: day?.seasonKey);
}

/// The Easter-season SeasonVariant the engine authority `angelusPrayerFor`
/// implements (`_isEasterSeason`: Easter, Eastertide, Pentecost) — keyed
/// purely by season, with no month match that could leak into Lent or the
/// post-Pentecost stretch.
const List<int> reginaCaeliMonths = <int>[];

/// A hand-built pack shell for validator checks: caller-chosen schedules,
/// no content, one content-free step.
ContentPack shellPack(List<ScheduleSpec> schedules) => ContentPack(
  id: 'schedules-shell',
  title: 'Schedules Shell',
  family: PackFamily.routine,
  schedules: schedules,
  session: SessionScript(
    id: 'schedules-shell-session',
    steps: <SessionStep>[IntercessionStep(id: 's-1', prompt: 'Pray.')],
  ),
);

void main() {
  group('angelus pack', () {
    test('loads from the fixtures directory', () {
      final ContentPack pack = loadPack('angelus');
      expect(pack.id, 'angelus');
      expect(pack.family, PackFamily.routine);
      expect(pack.title, isNotEmpty);
    });

    test('schedules the 6:00, 12:00, and 18:00 anchors, each with the '
        'season-pure regina_caeli variant', () {
      final ContentPack pack = loadPack('angelus');
      // The task-24 contract: the back-compat `schedules` list with the
      // three daily Angelus anchors (noon and evening joining the 6:00).
      expect(pack.schedules, hasLength(3));
      expect(pack.schedule, same(pack.schedules.first));
      final List<TimeOfDaySpec> anchors = <TimeOfDaySpec>[
        for (final ScheduleSpec spec in pack.schedules)
          if (spec is TimeOfDaySpec) spec,
      ];
      expect(
        anchors,
        hasLength(pack.schedules.length),
        reason: 'every angelus schedule is a time-of-day anchor',
      );
      final List<int> anchorHours = <int>[
        for (final TimeOfDaySpec anchor in anchors) anchor.hour,
      ];
      expect(anchorHours, <int>[6, 12, 18]);
      for (final TimeOfDaySpec anchor in anchors) {
        expect(anchor.minute, 0);
        expect(anchor.baseLabel, 'angelus');
        expect(anchor.variants.single.variantId, 'regina_caeli');
        expect(anchor.variants.single.months, reginaCaeliMonths);
        expect(anchor.variants.single.seasons, <String>{
          'Easter',
          'Eastertide',
          'Pentecost',
        });
      }
    });

    test('every anchor is due on any day, labelled by its base label', () {
      final ContentPack pack = loadPack('angelus');
      final List<TimeOfDaySpec> anchors = <TimeOfDaySpec>[
        for (final ScheduleSpec spec in pack.schedules)
          if (spec is TimeOfDaySpec) spec,
      ];
      expect(anchors, hasLength(3));

      // 2026-01-20 (Ordinary Time): all three anchors are due, all labelled
      // by the base label — the pack's schedule list must never leave one of
      // the three daily anchors silently not-due.
      final DateTime day = DateTime(2026, 1, 20);
      expect(
        LiturgicalCalendarService.getDayForDate(day)!.seasonKey,
        isNot(anyOf('Easter', 'Eastertide', 'Pentecost')),
      );
      for (final TimeOfDaySpec anchor in anchors) {
        final ScheduleResult result = anchor.resolve(day, contextFor(day));
        expect(result.due, isTrue, reason: 'the ${anchor.hour}:00 anchor');
        expect(result.labels, <String>['angelus']);
      }
    });

    test('resolves regina_caeli only across the Easter season, at every '
        'anchor', () {
      final ContentPack pack = loadPack('angelus');
      final List<TimeOfDaySpec> anchors = <TimeOfDaySpec>[
        for (final ScheduleSpec spec in pack.schedules)
          if (spec is TimeOfDaySpec) spec,
      ];
      expect(anchors, hasLength(3));

      // The embedded calendar data must cover every pin.
      final Map<DateTime, String> goldens = <DateTime, String>{
        DateTime(2026, 1, 20): 'angelus',
        DateTime(2026, 3, 25): 'angelus', // Lent: no month match may leak in
        DateTime(2026, 4, 20): 'regina_caeli',
        DateTime(2026, 5, 30): 'angelus', // post-Pentecost Ordinary Time
      };
      goldens.forEach((DateTime date, String expected) {
        final LiturgicalDayData? day = LiturgicalCalendarService.getDayForDate(
          date,
        );
        expect(day, isNotNull, reason: 'calendar data must cover $date');
        for (final TimeOfDaySpec anchor in anchors) {
          expect(anchor.resolve(date, contextFor(date)).labels, <String>[
            expected,
          ], reason: 'the ${anchor.hour}:00 anchor must label $date');
        }
        // Parity with the engine authority on the same date.
        expect(angelusPrayerFor(date, day), expected, reason: '$date');
      });

      // The guard dates hold because of the data, not by luck: Lent for the
      // Annunciation, post-Pentecost Ordinary Time for May 30.
      expect(
        LiturgicalCalendarService.getDayForDate(
          DateTime(2026, 3, 25),
        )!.seasonKey,
        'Lent',
      );
      expect(
        LiturgicalCalendarService.getDayForDate(
          DateTime(2026, 5, 30),
        )!.seasonKey,
        isNot(anyOf('Easter', 'Eastertide', 'Pentecost')),
      );
    });

    test('session: three verse steps then the collect prayer', () {
      final ContentPack pack = loadPack('angelus');
      final List<SessionStep> steps = pack.session.steps;
      expect(pack.session.id, 'angelus-session');
      expect(steps, hasLength(4));

      expect(steps[0], isA<VerseStep>());
      expect(steps[1], isA<VerseStep>());
      expect(steps[2], isA<VerseStep>());
      final VerseStep first = steps[0] as VerseStep;
      final VerseStep second = steps[1] as VerseStep;
      final VerseStep third = steps[2] as VerseStep;
      expect(first.versicle, 'The Angel of the Lord declared unto Mary.');
      expect(first.response, 'And she conceived of the Holy Spirit.');
      expect(second.versicle, 'Behold the handmaid of the Lord.');
      expect(second.response, 'Be it done unto me according to Thy word.');
      expect(third.versicle, 'And the Word was made flesh.');
      expect(third.response, 'And dwelt among us.');

      // Then one prayer: the collect, resolved from the content map.
      expect(steps[3], isA<PrayerStep>());
      final PrayerStep collect = steps[3] as PrayerStep;
      expect(collect.text, pack.content['angelus_collect']);
      expect(
        collect.text.text,
        contains(
          'Pour forth, we beseech Thee, O Lord, Thy grace into our hearts',
        ),
      );

      // Exactly three verse steps carry the Angelus exchange.
      expect(steps.whereType<VerseStep>().length, 3);
    });

    test('content: both Marian texts, self-contained and attributed', () {
      final ContentPack pack = loadPack('angelus');
      // Angelus (the pack default shown in the session) and Regina Caeli
      // (the Eastertide swap the app layer resolves by label).
      expect(
        pack.content.keys,
        containsAll(<String>[
          'angelus_collect',
          'regina_caeli_collect',
          'regina_caeli_versicles',
        ]),
      );
      for (final PrayerText entry in pack.content.values) {
        expect(entry.source, isNotEmpty, reason: entry.id);
        expect(entry.license, isNotEmpty, reason: entry.id);
      }
      expect(
        pack.content['angelus_collect']!.source,
        'Traditional Roman devotion',
      );
      expect(pack.content['regina_caeli_collect']!.license, 'public-domain');
    });

    test('the Regina Caeli texts carry no Hail Marys', () {
      final ContentPack pack = loadPack('angelus');
      final String versicles = pack.content['regina_caeli_versicles']!.text;
      expect(versicles, contains('Queen of Heaven, rejoice, alleluia.'));
      expect(versicles, contains('For the Lord hath truly risen, alleluia.'));
      expect(versicles, isNot(contains('Hail Mary')));
      expect(
        pack.content['regina_caeli_collect']!.text,
        contains('O God, who by the Resurrection'),
      );
    });

    test('every step contentRef resolves into the content map', () {
      final ContentPack pack = loadPack('angelus');
      for (final SessionStep step in pack.session.steps) {
        switch (step) {
          case PrayerStep(:final PrayerText text):
            expect(pack.content[text.id], text, reason: text.id);
          case VerseStep():
            continue;
          default:
            fail('unexpected step type ${step.runtimeType}');
        }
      }
    });

    test('PackValidator passes for fixture year 2026', () {
      expect(PackValidator.problems(loadPack('angelus'), 2026), isEmpty);
    });
  });

  group('mercy hour pack', () {
    test('loads from the fixtures directory', () {
      final ContentPack pack = loadPack('mercy_hour');
      expect(pack.id, 'mercy_hour');
      expect(pack.family, PackFamily.routine);
      expect(pack.title, isNotEmpty);
    });

    test('schedules the 15:00 mercy_hour anchor', () {
      final ContentPack pack = loadPack('mercy_hour');
      expect(pack.schedules, hasLength(1));
      expect(pack.schedule, same(pack.schedules.first));
      expect(pack.schedules.single, isA<TimeOfDaySpec>());
      final TimeOfDaySpec mercyHour = pack.schedules.single as TimeOfDaySpec;
      expect(mercyHour.hour, 15);
      expect(mercyHour.minute, 0);
      expect(mercyHour.baseLabel, 'mercy_hour');
      expect(mercyHour.variants, isEmpty);
    });

    test("resolves label 'mercy_hour' on any date", () {
      final ContentPack pack = loadPack('mercy_hour');
      final TimeOfDaySpec anchor = pack.schedules.single as TimeOfDaySpec;

      // Any date, any context: the label never strays from 'mercy_hour'.
      final List<DateTime> dates = <DateTime>[
        for (int month = 1; month <= 12; month++) DateTime(2026, month, 15),
        DateTime(2040, 4, 5), // beyond embedded data coverage
      ];
      final Map<DateTime, ScheduleContext> contexts =
          <DateTime, ScheduleContext>{
            DateTime(2026, 1, 15): contextFor(DateTime(2026, 1, 20)),
            DateTime(2026, 4, 15): contextFor(DateTime(2026, 4, 20)),
          };
      for (final DateTime date in dates) {
        final ScheduleResult result = anchor.resolve(
          date,
          contexts[date] ?? const ScheduleContext(),
        );
        expect(result.labels, <String>[
          'mercy_hour',
        ], reason: 'the 15:00 anchor must label $date as mercy_hour');
        expect(result.due, isTrue, reason: 'the 15:00 anchor is due daily');
      }
    });

    test('session: the hour-of-mercy prayer then the threefold invocation', () {
      final ContentPack pack = loadPack('mercy_hour');
      final List<SessionStep> steps = pack.session.steps;
      expect(pack.session.id, 'mercy-hour-session');
      expect(steps, hasLength(2));

      expect(steps[0], isA<PrayerStep>());
      final PrayerStep mercyPrayer = steps[0] as PrayerStep;
      expect(mercyPrayer.text.id, 'mercy_hour_prayer');
      expect(mercyPrayer.title, 'The Hour of Mercy');

      expect(steps[1], isA<RepetitionStep>());
      final RepetitionStep mercyRepetition = steps[1] as RepetitionStep;
      expect(mercyRepetition.text.id, 'mercy_hour_repetition');
      expect(mercyRepetition.count, 3);
      expect(mercyRepetition.title, 'O Blood and Water');
    });

    test('carries the short invocations verbatim, not Diary translations', () {
      final ContentPack pack = loadPack('mercy_hour');

      final String? hourText = pack.content['mercy_hour_prayer']?.text;
      expect(
        hourText,
        'You expired, Jesus, but the source of life gushed forth for souls, '
        'and an ocean of mercy opened up for the whole world. O Blood and '
        'Water, which gushed forth from the Heart of Jesus as a fountain of '
        'mercy for us, I trust in You.',
      );
      expect(
        hourText,
        isNot(contains('eternal Father, I offer You')), // no Diary translation
      );

      expect(
        pack.content['mercy_hour_repetition']?.text,
        'O Blood and Water, which gushed forth from the Heart of Jesus as a '
        'fountain of mercy for us, I trust in You.',
      );

      for (final String key in <String>[
        'mercy_hour_prayer',
        'mercy_hour_repetition',
      ]) {
        expect(
          pack.content[key]!.source,
          'The Diary of St. Faustina (short invocations)',
        );
        expect(
          pack.content[key]!.license,
          'short-phrase (attributed, widely-reproduced)',
        );
      }
    });

    test('PackValidator passes for fixture year 2026', () {
      expect(PackValidator.problems(loadPack('mercy_hour'), 2026), isEmpty);
    });
  });

  group('schedules list schema', () {
    test("the loader rejects both 'schedule' and 'schedules' together", () {
      final Map<String, dynamic> json = <String, dynamic>{
        'id': 'both-forms',
        'title': 'Both Forms',
        'family': 'routine',
        'schedule': <String, dynamic>{
          'type': 'fixedDate',
          'month': 11,
          'day': 2,
        },
        'schedules': <Map<String, dynamic>>[
          <String, dynamic>{'type': 'fixedDate', 'month': 11, 'day': 2},
        ],
        'session': <String, dynamic>{
          'id': 'both-forms-session',
          'steps': <Map<String, dynamic>>[
            <String, dynamic>{
              'type': 'intercession',
              'id': 's-1',
              'prompt': 'Pray.',
            },
          ],
        },
      };

      expect(
        () => PackLoader.load(json),
        throwsA(
          isA<ContentValidationException>().having(
            (e) => e.problems,
            'problems',
            anyElement(contains("'schedule' and 'schedules' must not both")),
          ),
        ),
      );
    });

    test("'schedules' entries dispatch like the single form", () {
      final ContentPack pack = PackLoader.load(<String, dynamic>{
        'id': 'list-form',
        'title': 'List Form',
        'family': 'routine',
        'schedules': <Map<String, dynamic>>[
          <String, dynamic>{'type': 'fixedDate', 'month': 11, 'day': 2},
          <String, dynamic>{'type': 'timeOfDay', 'hour': 15, 'minute': 0},
        ],
        'session': <String, dynamic>{
          'id': 'list-form-session',
          'steps': <Map<String, dynamic>>[
            <String, dynamic>{
              'type': 'intercession',
              'id': 's-1',
              'prompt': 'Pray.',
            },
          ],
        },
      });

      expect(pack.schedules, hasLength(2));
      expect(pack.schedule, same(pack.schedules.first));
      expect(pack.schedules[0], isA<FixedDateSpec>());
      expect(pack.schedules[1], isA<TimeOfDaySpec>());

      // The pack keeps the form it was loaded in: the list form round-trips
      // as a list.
      expect(pack.toJson().containsKey('schedule'), isFalse);
      expect(pack.toJson()['schedules'], hasLength(2));
    });

    test('PackValidator sweeps every schedule for due dates', () {
      // Both anchors resolve in 2026 → no problems.
      expect(
        PackValidator.problems(
          shellPack(<ScheduleSpec>[
            FixedDateSpec(12, 17),
            TimeOfDaySpec(15, 0, baseLabel: 'mercy_hour'),
          ]),
          2026,
        ),
        isEmpty,
      );

      // One zero-due schedule among the anchors is one problem.
      final List<String> problems = PackValidator.problems(
        shellPack(<ScheduleSpec>[
          FixedDateSpec(12, 17),
          SessionSeriesSpec(startDate: DateTime(2027, 2, 14), lengthDays: 45),
        ]),
        2026,
      );
      expect(problems, hasLength(1));
      expect(problems.single, contains('zero due dates in 2026'));
    });
  });
}
