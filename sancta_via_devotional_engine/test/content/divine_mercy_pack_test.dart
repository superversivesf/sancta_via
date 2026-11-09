import 'package:sancta_via_devotional_engine/sancta_via_devotional_engine.dart';
import 'package:test/test.dart';

/// Fixture directory the content packs live in (tasks 14-16).
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

/// The nine daily novena intentions (the classic widely-reproduced summary
/// list of St. Faustina's nine requests), indexed by novena day: day N means
/// the list's Nth item.
const List<String> nineDailyIntentions = <String>[
  'All mankind, especially sinners: that the whole world may come to know '
      'the mercy of God and trust in it.',
  'Priests and religious: that, drawn from the abyss of His mercy, they may '
      'bring His pardon to every soul entrusted to them.',
  'Devout and faithful souls: that the mercy of God may accompany them on '
      'every path of their life.',
  'Those who do not believe in God and those who do not yet know Him: that '
      'the light of His mercy may shine upon their darkness.',
  'Souls separated from the Church: that the charity of God may gather '
      'every straying soul back into one fold.',
  'Meek and humble souls and the souls of little children: that their '
      'innocence may draw down the mercy of God upon the whole world.',
  'Souls who venerate His mercy: that, dwelling in the merciful Heart of '
      'Jesus, they may draw from it all that they need.',
  'Souls in purgatory: that the mercy of God may refresh them in their '
      'trial and open heaven to them in due time.',
  'Lukewarm souls: that, kindled by the fire of His mercy, they may make an '
      'act of perfect trust in Jesus.',
];

/// The chaplet's Divine-Mercy-specific formulas, attributed to the chaplet
/// tradition as universally reproduced (no Diary translations).
const List<String> chapletFormulaKeys = <String>[
  'dmn_you_expired',
  'dmn_blood_water',
  'dmn_eternal_father',
  'dmn_for_the_sake',
  'dmn_holy_god',
  'dmn_jesus_trust',
];

/// The traditional Roman prayers the chaplet interweaves (public domain).
const List<String> traditionalPrayerKeys = <String>[
  'dmn_our_father',
  'dmn_hail_mary',
  'dmn_apostles_creed',
  'dmn_glory_be',
];

void main() {
  group('divine mercy novena pack', () {
    test('loads from the fixtures directory', () {
      final ContentPack pack = loadPack('divine_mercy_novena');
      expect(pack.id, 'divine_mercy_novena');
      expect(pack.family, PackFamily.novena);
      expect(pack.title, isNotEmpty);
    });

    test('schedules the Easter-anchored nine-day window (-2, 9)', () {
      final ContentPack pack = loadPack('divine_mercy_novena');
      expect(pack.schedules, hasLength(1));
      expect(pack.schedule, same(pack.schedules.first));
      expect(pack.schedules.single, isA<EasterOffsetSpec>());
      final EasterOffsetSpec novena = pack.schedules.single as EasterOffsetSpec;
      expect(novena.startOffset, -2);
      expect(novena.lengthDays, 9);
    });

    test('resolves Good Friday 2026-04-03..2026-04-11 (9 dates), '
        'computus Easter Apr 5 2026', () {
      final ContentPack pack = loadPack('divine_mercy_novena');
      final ScheduleSpec novena = pack.schedule;

      // The computus pin: Easter is exactly 2026-04-05, so Good Friday is a
      // real Friday and the window starts two days before Easter.
      expect(easterSundayFor(2026), DateTime(2026, 4, 5));
      expect(DateTime(2026, 4, 3).weekday, DateTime.friday);

      // Day N of the novena falls on 2026-04-(2 + N): Good Friday .. Apr 11.
      for (int day = 3; day <= 11; day++) {
        final ScheduleResult result = novena.resolve(
          DateTime(2026, 4, day),
          const ScheduleContext(),
        );
        expect(result.due, isTrue, reason: '2026-04-$day must be due');
        expect(
          result.dayIndex,
          day - 2,
          reason: '2026-04-$day is day ${day - 2}',
        );
      }

      // Exactly the 9-day window: the days on either edge are not due, and
      // the whole month of April 2026 holds only those nine due dates.
      expect(
        novena.resolve(DateTime(2026, 4, 2), const ScheduleContext()).due,
        isFalse,
      );
      expect(
        novena.resolve(DateTime(2026, 4, 12), const ScheduleContext()).due,
        isFalse,
      );
      int dueCount = 0;
      for (int day = 1; day <= 30; day++) {
        if (novena
            .resolve(DateTime(2026, 4, day), const ScheduleContext())
            .due) {
          dueCount++;
        }
      }
      expect(dueCount, 9);
    });

    test('day-intention mapping returns intention list item N '
        '(pack.variants indexed by day)', () {
      final ContentPack pack = loadPack('divine_mercy_novena');
      expect(pack.variants, hasLength(9));

      for (int dayNumber = 1; dayNumber <= 9; dayNumber++) {
        // The session day index for 2026 walks from the schedule itself:
        // novena day N falls on April (2 + N), 2026.
        final ScheduleResult dayResult = pack.schedule.resolve(
          DateTime(2026, 4, 2 + dayNumber),
          const ScheduleContext(),
        );
        expect(
          dayResult.dayIndex,
          dayNumber,
          reason: 'day $dayNumber of the novena',
        );

        final Map<String, dynamic> variant = pack.variants[dayNumber - 1];
        expect(
          variant['id'],
          'day-$dayNumber',
          reason: 'variant index ${dayNumber - 1}',
        );
        expect(variant['title'], 'Day $dayNumber');
        expect(
          variant['intention'],
          nineDailyIntentions[dayNumber - 1],
          reason: 'day $dayNumber must carry intention item $dayNumber',
        );
        expect(
          variant['source'],
          'Chaplet novena tradition (St. Faustina request summaries)',
        );
        expect(variant['license'], 'public-domain summary');
      }
    });

    test('session: novena intention, opening prayers, Divine Mercy decades, '
        'Holy God x3, closing', () {
      final ContentPack pack = loadPack('divine_mercy_novena');
      final List<SessionStep> steps = pack.session.steps;
      expect(pack.session.id, 'divine-mercy-novena-session');
      expect(steps, hasLength(26));

      // The leading intercession step carries the day-N placeholder the app
      // layer substitutes with the pack's variant texts by session day
      // index (see Pack.variants and the report note).
      expect(steps[0], isA<IntercessionStep>());
      final IntercessionStep novenaIntention = steps[0] as IntercessionStep;
      expect(
        novenaIntention.prompt,
        "Offer today's novena intention for: Day N of the Divine Mercy "
        'Novena',
      );

      // Opening: the Sign of the Cross as a verse exchange...
      expect(steps[1], isA<VerseStep>());
      final VerseStep signOfTheCross = steps[1] as VerseStep;
      expect(
        signOfTheCross.versicle,
        'In the name of the Father, and of the Son, and of the Holy Spirit.',
      );
      expect(signOfTheCross.response, 'Amen.');

      // ...the Hour-of-Mercy-style opening invocation...
      expect(steps[2], isA<PrayerStep>());
      expect((steps[2] as PrayerStep).text.id, 'dmn_you_expired');

      // ...and the threefold 'O Blood and Water' invocation.
      expect(steps[3], isA<RepetitionStep>());
      final RepetitionStep bloodAndWater = steps[3] as RepetitionStep;
      expect(bloodAndWater.text.id, 'dmn_blood_water');
      expect(bloodAndWater.count, 3);

      // On the crucifix: Our Father; on the first three beads: three Hail
      // Marys as one prayer step per bead; then the Apostles' Creed.
      expect((steps[4] as PrayerStep).text.id, 'dmn_our_father');
      for (int i = 5; i <= 7; i++) {
        expect(steps[i], isA<PrayerStep>(), reason: 'steps[$i]');
        expect((steps[i] as PrayerStep).text.id, 'dmn_hail_mary');
      }
      expect((steps[8] as PrayerStep).text.id, 'dmn_apostles_creed');

      // Five decades, three steps each in order: Eternal Father (prayer),
      // 'For the sake of His sorrowful Passion' (repetition x10), Glory Be
      // (prayer). The Divine Mercy decade is NOT a Rosary BeadGroupStep.
      expect(steps.whereType<BeadGroupStep>(), isEmpty);
      for (int decade = 1; decade <= 5; decade++) {
        final int base = 9 + (decade - 1) * 3;
        expect(steps[base], isA<PrayerStep>(), reason: 'decade $decade');
        final PrayerStep eternalFather = steps[base] as PrayerStep;
        expect(eternalFather.id, 'dmn-decade-$decade-eternal-father');
        expect(eternalFather.text.id, 'dmn_eternal_father');

        expect(
          steps[base + 1],
          isA<RepetitionStep>(),
          reason: 'decade $decade',
        );
        final RepetitionStep forTheSake = steps[base + 1] as RepetitionStep;
        expect(forTheSake.id, 'dmn-decade-$decade-for-the-sake');
        expect(forTheSake.text.id, 'dmn_for_the_sake');
        expect(forTheSake.count, 10);

        expect(steps[base + 2], isA<PrayerStep>(), reason: 'decade $decade');
        final PrayerStep gloryBe = steps[base + 2] as PrayerStep;
        expect(gloryBe.id, 'dmn-decade-$decade-glory-be');
        expect(gloryBe.text.id, 'dmn_glory_be');
      }
      // The decades occupy exactly steps 9..23 of the session, in order.
      for (int i = 9; i <= 23; i++) {
        expect(
          steps[i],
          anyOf(isA<PrayerStep>(), isA<RepetitionStep>()),
          reason: 'steps[$i]',
        );
      }

      // Closing: the threefold Holy God antiphon, then 'Jesus, I trust in
      // You!'.
      expect(steps[24], isA<RepetitionStep>());
      final RepetitionStep holyGod = steps[24] as RepetitionStep;
      expect(holyGod.text.id, 'dmn_holy_god');
      expect(holyGod.count, 3);
      expect(steps[25], isA<PrayerStep>());
      expect((steps[25] as PrayerStep).text.id, 'dmn_jesus_trust');
    });

    test('every contentRef resolves into the content map', () {
      final ContentPack pack = loadPack('divine_mercy_novena');
      int referencedTexts = 0;
      for (final SessionStep step in pack.session.steps) {
        switch (step) {
          case PrayerStep(:final PrayerText text):
            expect(pack.content[text.id], text, reason: text.id);
            referencedTexts++;
          case RepetitionStep(:final PrayerText text):
            expect(pack.content[text.id], text, reason: text.id);
            referencedTexts++;
          case VerseStep():
            continue;
          case IntercessionStep():
            continue;
          default:
            fail('unexpected step type ${step.runtimeType}');
        }
      }
      // The 10 content entries are all reached by the session's refs: Our
      // Father, one Hail Mary text over three steps, each other formula.
      expect(referencedTexts, 24);
      expect(
        pack.content.keys,
        hasLength(chapletFormulaKeys.length + traditionalPrayerKeys.length),
      );
    });

    test('every text has source and license, and no Diary translations', () {
      final ContentPack pack = loadPack('divine_mercy_novena');
      for (final PrayerText entry in pack.content.values) {
        expect(entry.source, isNotEmpty, reason: entry.id);
        expect(entry.license, isNotEmpty, reason: entry.id);
      }

      // Chaplet formulas: chaplet-tradition attribution, public-domain gate.
      for (final String key in chapletFormulaKeys) {
        expect(
          pack.content[key]!.source,
          'Chaplet of the Divine Mercy tradition (reproduced e.g. by the '
          'USCCB)',
          reason: key,
        );
        expect(
          pack.content[key]!.license,
          'public-domain (universally reproduced; attribution: '
          'USCCB/MARIANS wording)',
          reason: key,
        );
      }

      // Traditional Roman prayers: repository-wide public-domain convention.
      for (final String key in traditionalPrayerKeys) {
        expect(
          pack.content[key]!.source,
          'Traditional Roman devotion',
          reason: key,
        );
        expect(pack.content[key]!.license, 'public-domain', reason: key);
      }

      // The core chaplet formulas verbatim.
      expect(
        pack.content['dmn_eternal_father']!.text,
        'Eternal Father, I offer You the Body and Blood, Soul and Divinity '
        'of Your Dearly Beloved Son, Our Lord Jesus Christ, in atonement '
        'for our sins and those of the whole world.',
      );
      expect(
        pack.content['dmn_for_the_sake']!.text,
        'For the sake of His sorrowful Passion, have mercy on us and on the '
        'whole world.',
      );
      expect(
        pack.content['dmn_holy_god']!.text,
        'Holy God, Holy Mighty One, Holy Immortal One, have mercy on us and '
        'on the whole world.',
      );
      expect(pack.content['dmn_jesus_trust']!.text, 'Jesus, I trust in You!');
      expect(
        pack.content['dmn_blood_water']!.text,
        'O Blood and Water, which gushed forth from the Heart of Jesus as a '
        'fountain of mercy for us, I trust in You.',
      );

      // No Diary translation texts anywhere (content or variants): the
      // first-person novena translation formulas are excluded.
      final String allContent = <String>[
        for (final PrayerText entry in pack.content.values) entry.text,
        for (final Map<String, dynamic> variant in pack.variants)
          variant['intention']! as String,
      ].join('\n');
      expect(allContent, isNot(contains('Today bring to Me')));
      expect(allContent, isNot(contains('ocean of My mercy')));
      expect(allContent, isNot(contains('entreat My mercy')));
    });

    test('PackValidator passes for fixture year 2026', () {
      expect(
        PackValidator.problems(loadPack('divine_mercy_novena'), 2026),
        isEmpty,
      );
    });
  });
}
