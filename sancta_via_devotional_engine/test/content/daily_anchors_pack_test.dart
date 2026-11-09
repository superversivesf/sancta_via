import 'package:sancta_via_devotional_engine/sancta_via_devotional_engine.dart';
import 'package:sancta_via_liturgical_calendar/sancta_via_liturgical_calendar.dart';
import 'package:test/test.dart';

/// Fixture directory the daily-anchors pack lives in (task 14).
const String fixtureDir = 'test/fixtures/packs';

/// The daily-anchors pack fixture, loaded once for this suite.
ContentPack loadAnchorsPack() {
  final List<ContentPack> packs = PackLoader.loadFixturesIn(fixtureDir);
  return packs.firstWhere(
    (ContentPack pack) => pack.id == 'daily_anchors',
    orElse: () => throw StateError(
      'test/fixtures/packs must contain a daily_anchors pack; '
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

void main() {
  group('load', () {
    test('loads the daily_anchors pack from the fixtures directory', () {
      final ContentPack pack = loadAnchorsPack();
      expect(pack.id, 'daily_anchors');
      expect(pack.family, PackFamily.routine);
      expect(pack.title, isNotEmpty);
    });
  });

  group('schedule resolution', () {
    test('the pack schedule is the 6:00 angelus timeOfDay spec', () {
      final ContentPack pack = loadAnchorsPack();
      expect(pack.schedule, isA<TimeOfDaySpec>());
      final TimeOfDaySpec schedule = pack.schedule as TimeOfDaySpec;
      expect(schedule.hour, 6);
      expect(schedule.minute, 0);
      expect(schedule.baseLabel, 'angelus');
    });

    test(
      'resolves 2026-01-20 label angelus and 2026-04-20 label regina_caeli',
      () {
        final ContentPack pack = loadAnchorsPack();

        // The embedded calendar data must cover both pins.
        final LiturgicalDayData? january =
            LiturgicalCalendarService.getDayForDate(DateTime(2026, 1, 20));
        final LiturgicalDayData? april =
            LiturgicalCalendarService.getDayForDate(DateTime(2026, 4, 20));
        expect(january, isNotNull, reason: 'data must cover 2026-01-20');
        expect(april, isNotNull, reason: 'data must cover 2026-04-20');

        // Through the pack: TimeOfDaySpec resolve with the real seasonKeys.
        expect(
          pack.schedule
              .resolve(DateTime(2026, 1, 20), contextFor(DateTime(2026, 1, 20)))
              .labels,
          <String>['angelus'],
        );
        expect(
          pack.schedule
              .resolve(DateTime(2026, 4, 20), contextFor(DateTime(2026, 4, 20)))
              .labels,
          <String>['regina_caeli'],
        );

        // Parity with the engine's own season rule.
        expect(angelusPrayerFor(DateTime(2026, 1, 20), january), 'angelus');
        expect(angelusPrayerFor(DateTime(2026, 4, 20), april), 'regina_caeli');
      },
    );

    test('the pack schedule is due every day (timeOfDay cadence)', () {
      final ContentPack pack = loadAnchorsPack();
      expect(
        pack.schedule
            .resolve(DateTime(2026, 1, 20), const ScheduleContext())
            .due,
        isTrue,
      );
      expect(
        pack.schedule
            .resolve(DateTime(2026, 4, 20), const ScheduleContext())
            .due,
        isTrue,
      );
    });
  });

  group('mercy hour anchor', () {
    test('the pack carries the 15:00 mercy_hour anchor', () {
      final ContentPack pack = loadAnchorsPack();
      final Object? entry = pack.reminders['mercy_hour'];
      expect(entry, isA<Map<String, dynamic>>());
      final Map<String, dynamic> reminder = entry! as Map<String, dynamic>;
      expect(reminder['type'], 'timeOfDay');
      expect(reminder['hour'], 15);
      expect(reminder['minute'], 0);
      expect(reminder['baseLabel'], 'mercy_hour');
    });

    test("resolves label 'mercy_hour' on any date", () {
      final ContentPack pack = loadAnchorsPack();

      // Build the engine spec the pack's anchor describes.
      final Map<String, dynamic> reminder =
          pack.reminders['mercy_hour']! as Map<String, dynamic>;
      final TimeOfDaySpec anchor = TimeOfDaySpec(
        reminder['hour']! as int,
        reminder['minute']! as int,
        baseLabel: reminder['baseLabel']! as String,
      );

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

    test('the session carries separate mercy-hour steps', () {
      final ContentPack pack = loadAnchorsPack();
      final List<SessionStep> steps = pack.session.steps;

      // Step 4 of 6: the Hour of Mercy prayer.
      expect(steps[4], isA<PrayerStep>());
      final PrayerStep mercyPrayer = steps[4] as PrayerStep;
      expect(mercyPrayer.text.id, 'mercy_hour_prayer');
      expect(mercyPrayer.title, 'The Hour of Mercy');

      // Step 5 of 6: "O Blood and Water..." repeated three times.
      expect(steps[5], isA<RepetitionStep>());
      final RepetitionStep mercyRepetition = steps[5] as RepetitionStep;
      expect(mercyRepetition.text.id, 'mercy_hour_repetition');
      expect(mercyRepetition.count, 3);
    });

    test('carries the short invocations verbatim, not Diary translations', () {
      final ContentPack pack = loadAnchorsPack();

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
  });

  group('session structure', () {
    test('three verse steps then the angelus collect prayer', () {
      final ContentPack pack = loadAnchorsPack();
      final List<SessionStep> steps = pack.session.steps;
      expect(steps, hasLength(6));

      // The three versicle/response pairs of the Angelus.
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
      expect(pack.session.steps.whereType<VerseStep>().length, 3);
    });

    test('session id identifies the daily-anchors script', () {
      final ContentPack pack = loadAnchorsPack();
      expect(pack.session.id, 'daily-anchors-session');
    });
  });

  group('content integrity', () {
    test('content carries both Marian texts', () {
      final ContentPack pack = loadAnchorsPack();
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
      expect(pack.content['angelus_collect']!.source, isNotEmpty);
      expect(pack.content['angelus_collect']!.license, isNotEmpty);
      expect(pack.content['regina_caeli_collect']!.source, isNotEmpty);
      expect(pack.content['regina_caeli_collect']!.license, isNotEmpty);
    });

    test('the Regina Caeli texts carry no Hail Marys', () {
      final ContentPack pack = loadAnchorsPack();
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
      final ContentPack pack = loadAnchorsPack();
      for (final SessionStep step in pack.session.steps) {
        switch (step) {
          case PrayerStep(:final PrayerText text):
            expect(pack.content[text.id], text, reason: text.id);
          case RepetitionStep(:final PrayerText text):
            expect(pack.content[text.id], text, reason: text.id);
          case VerseStep():
            continue;
          default:
            fail('unexpected step type ${step.runtimeType}');
        }
      }
    });

    test('PackValidator passes for fixture year 2026', () {
      final ContentPack pack = loadAnchorsPack();
      expect(PackValidator.problems(pack, 2026), isEmpty);
    });
  });
}
