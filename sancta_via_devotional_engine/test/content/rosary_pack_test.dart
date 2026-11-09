import 'package:sancta_via_devotional_engine/sancta_via_devotional_engine.dart';
import 'package:sancta_via_liturgical_calendar/sancta_via_liturgical_calendar.dart';
import 'package:test/test.dart';

/// Fixture directory the content packs live in (tasks 14–17).
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

/// The embedded calendar data's day record for [date] (the same input the
/// app layer hands the engine authority).
LiturgicalDayData? dayFor(DateTime date) =>
    LiturgicalCalendarService.getDayForDate(date);

/// The 20 mysteries of the Rosary the pack's opaque `variants` list carries,
/// keyed by set (`setTitle`): each set holds five `[mystery, fruit]` pairs in
/// decade order, so `index` N means pairs[N - 1].
///
/// Attribution convention (all entries): the 2002 Rosarium Virginis Mariae
/// mystery set for the Luminous mysteries; the sets pre-dating that letter
/// (joyful, sorrowful, glorious) are traditional.
const Map<String, List<List<String>>> twentyMysteries =
    <String, List<List<String>>>{
      'joyful': <List<String>>[
        <String>['The Annunciation', 'Humility'],
        <String>['The Visitation', 'Love of Neighbor'],
        <String>['The Nativity', 'Poverty'],
        <String>['The Presentation', 'Obedience'],
        <String>['The Finding in the Temple', 'Joy in Finding Jesus'],
      ],
      'sorrowful': <List<String>>[
        <String>['The Agony in the Garden', 'Contrition'],
        <String>['The Scourging at the Pillar', 'Purity'],
        <String>['The Crowning with Thorns', 'Moral Courage'],
        <String>['The Carrying of the Cross', 'Patience'],
        <String>['The Crucifixion', 'Perseverance'],
      ],
      'glorious': <List<String>>[
        <String>['The Resurrection', 'Faith'],
        <String>['The Ascension', 'Hope'],
        <String>['The Descent of the Holy Spirit', 'Love of God'],
        <String>['The Assumption', 'Devotion to Mary'],
        <String>['The Coronation', 'Eternal Love'],
      ],
      'luminous': <List<String>>[
        <String>['The Baptism in the Jordan', 'Openness to the Holy Spirit'],
        <String>['The Wedding Feast at Cana', 'To Jesus through Mary'],
        <String>[
          'The Proclamation of the Kingdom of God',
          'Repentance and Trust in God',
        ],
        <String>['The Transfiguration', 'Desire for Holiness'],
        <String>['The Institution of the Eucharist', 'Eucharistic Adoration'],
      ],
    };

/// The [MysterySet] the day's session prays, resolved the way the app layer
/// must: read the pack's engine-opaque `mysterySource` pointer and dispatch
/// to the engine authority it names. The pack itself carries no season
/// logic — the pointer is its entire mystery-selection contract.
MysterySet resolveDaySet(ContentPack pack, DateTime date) {
  expect(
    pack.reminders['mysterySource'],
    'rosaryMysteriesFor',
    reason: 'the pack must point the app layer at the engine authority',
  );
  return rosaryMysteriesFor(date, dayFor(date));
}

void main() {
  group('rosary pack', () {
    test('loads from the fixtures directory', () {
      final ContentPack pack = loadPack('rosary');
      expect(pack.id, 'rosary');
      expect(pack.family, PackFamily.routine);
      expect(pack.title, isNotEmpty);
    });

    test('schedules a weeklyLoop across all seven weekdays', () {
      final ContentPack pack = loadPack('rosary');
      expect(pack.schedules, hasLength(1));
      expect(pack.schedule, same(pack.schedules.first));
      expect(pack.schedules.single, isA<WeeklyLoopSpec>());
      final WeeklyLoopSpec loop = pack.schedules.single as WeeklyLoopSpec;
      expect(loop.weekdays, <int>{1, 2, 3, 4, 5, 6, 7});
      expect(loop.skipMonths, isNull);
    });

    test('pack resolves daily: every day of 2026 is due', () {
      final ContentPack pack = loadPack('rosary');
      for (int month = 1; month <= 12; month++) {
        final int lastDay = DateTime(2026, month + 1, 0).day;
        for (int day = 1; day <= lastDay; day++) {
          final ScheduleResult result = pack.schedule.resolve(
            DateTime(2026, month, day),
            const ScheduleContext(),
          );
          expect(result.due, isTrue, reason: '2026-$month-$day');
        }
      }
    });

    test('mystery-source hook returns the weekday sets for the '
        '2026-12-14..17 run', () {
      final ContentPack pack = loadPack('rosary');

      // The weekday map is engine-fixed: Monday joyful, Tuesday sorrowful,
      // Wednesday glorious, Thursday luminous (the fourth set) — regardless
      // of the season the calendar data reports for the date.
      final Map<DateTime, MysterySet> run = <DateTime, MysterySet>{
        DateTime(2026, 12, 14): MysterySet.joyful,
        DateTime(2026, 12, 15): MysterySet.sorrowful,
        DateTime(2026, 12, 16): MysterySet.glorious,
        DateTime(2026, 12, 17): MysterySet.luminous,
        // The same week's Friday and Saturday (ferial map: sorrowful,
        // joyful), for the full week.
        DateTime(2026, 12, 18): MysterySet.sorrowful,
        DateTime(2026, 12, 19): MysterySet.joyful,
      };
      run.forEach((DateTime date, MysterySet expected) {
        final LiturgicalDayData? day = dayFor(date);
        expect(day, isNotNull, reason: 'calendar data must cover $date');
        expect(date.weekday, isNot(DateTime.sunday), reason: '$date');
        expect(resolveDaySet(pack, date), expected, reason: '$date');
        // Parity with the engine authority called directly.
        expect(rosaryMysteriesFor(date, day), expected, reason: '$date');
      });
    });

    test('Advent-Sunday override yields joyful with no pack changes '
        '(2026-12-20)', () {
      final ContentPack pack = loadPack('rosary');

      // The data guard: a Sunday, reported by the embedded calendar as an
      // Advent day — and the engine override keys on that season, never on
      // a pack field. The pin proves the override is engine-side.
      final DateTime sunday = DateTime(2026, 12, 20);
      expect(sunday.weekday, DateTime.sunday);
      final LiturgicalDayData? day = dayFor(sunday);
      expect(day, isNotNull);
      expect(day!.seasonKey, 'Advent');
      expect(resolveDaySet(pack, sunday), MysterySet.joyful);
      expect(rosaryMysteriesFor(sunday, day), MysterySet.joyful);

      // No pack changes: the pack carries no season logic of its own — the
      // only opaque reminder is the mystery-source pointer, and every
      // variant is mystery data (no season-keyed display variants).
      expect(pack.schedules.single, isA<WeeklyLoopSpec>());
      expect(pack.reminders.keys, <String>['mysterySource']);
      for (final Map<String, dynamic> variant in pack.variants) {
        expect(variant.containsKey('seasons'), isFalse, reason: '$variant');
        expect(variant.containsKey('months'), isFalse, reason: '$variant');
      }

      // Engine parity on an Ordinary-Time Sunday (no override): the
      // glorious set, straight from the function the pack points at.
      final DateTime ordinarySunday = DateTime(2026, 11, 15);
      expect(ordinarySunday.weekday, DateTime.sunday);
      expect(
        dayFor(ordinarySunday)!.seasonKey,
        isNot(anyOf('Advent', 'Christmastide', 'Christmas')),
      );
      expect(resolveDaySet(pack, ordinarySunday), MysterySet.glorious);
    });

    test('session: opening, five BeadGroupSteps with day-set placeholders, '
        'closing', () {
      final ContentPack pack = loadPack('rosary');
      final List<SessionStep> steps = pack.session.steps;
      expect(pack.session.id, 'rosary-session');
      expect(steps, hasLength(12));

      // Opening: the Sign of the Cross as a verse exchange (convention from
      // the Divine Mercy pack), then Creed, Our Father, three Hail Marys
      // (one repetition step), Glory Be.
      expect(steps[0], isA<VerseStep>());
      final VerseStep signOfTheCross = steps[0] as VerseStep;
      expect(
        signOfTheCross.versicle,
        'In the name of the Father, and of the Son, and of the Holy Spirit.',
      );
      expect(signOfTheCross.response, 'Amen.');

      expect((steps[1] as PrayerStep).text.id, 'apostles-creed');
      expect((steps[2] as PrayerStep).text.id, 'our-father');
      expect(steps[3], isA<RepetitionStep>());
      final RepetitionStep hailMarys = steps[3] as RepetitionStep;
      expect(hailMarys.text.id, 'hail-mary');
      expect(hailMarys.count, 3);
      expect((steps[4] as PrayerStep).text.id, 'glory-be');

      // Five decades as five BeadGroupSteps: each carries ten beads, the
      // Fatima-prayer flag, and the day-set placeholders in the opaque
      // mystery fields — the app layer substitutes the placeholders by
      // mysterySource. No static mystery title may leak into the fields.
      final List<BeadGroupStep> decades = steps
          .whereType<BeadGroupStep>()
          .toList();
      expect(decades, hasLength(5));
      for (int i = 0; i < 5; i++) {
        final BeadGroupStep decade = decades[i];
        expect(decade.id, 'rosary-decade-${i + 1}', reason: 'decade $i');
        expect(decade.hailMaryCount, 10, reason: decade.id);
        expect(decade.includeFatimaPrayer, isTrue, reason: decade.id);
        expect(decade.mysteryTitle, '{{mysteryTitle}}', reason: decade.id);
        expect(decade.mysteryFruit, '{{mysteryFruit}}', reason: decade.id);
      }
      expect(steps[5], same(decades.first));
      expect(steps[9], same(decades.last));

      // The Fatima prayer lives in the pack as content the app shows when
      // includeFatimaPrayer is set; it is deliberately not its own step.
      expect(pack.content['fatima-prayer'], isNotNull);

      // Closing: Hail Holy Queen, then the closing collect (the 'Pray for
      // us, O holy Mother of God' exchange folded into the collect text,
      // per the accepted angelus pattern).
      expect(steps[10], isA<PrayerStep>());
      expect((steps[10] as PrayerStep).text.id, 'hail-holy-queen');
      expect(steps[11], isA<PrayerStep>());
      expect((steps[11] as PrayerStep).text.id, 'rosary-closing-collect');
    });

    test('every contentRef resolves, content complete and attributed', () {
      final ContentPack pack = loadPack('rosary');

      // The seven content entries (the 20 mystery variants are opaque, not
      // content).
      final Set<String> expectedKeys = <String>{
        'apostles-creed',
        'our-father',
        'hail-mary',
        'glory-be',
        'fatima-prayer',
        'hail-holy-queen',
        'rosary-closing-collect',
      };
      expect(pack.content.keys, expectedKeys);

      for (final SessionStep step in pack.session.steps) {
        switch (step) {
          case PrayerStep(:final PrayerText text):
            expect(pack.content[text.id], text, reason: text.id);
          case RepetitionStep(:final PrayerText text):
            expect(pack.content[text.id], text, reason: text.id);
          case BeadGroupStep() || VerseStep():
            continue;
          default:
            fail('unexpected step type ${step.runtimeType}');
        }
      }

      // Every text carries source and license.
      for (final PrayerText entry in pack.content.values) {
        expect(entry.source, isNotEmpty, reason: entry.id);
        expect(entry.license, isNotEmpty, reason: entry.id);
      }

      // The Fatima prayer verbatim, with its own attribution.
      expect(
        pack.content['fatima-prayer']!.text,
        'O my Jesus, forgive us our sins, save us from the fires of hell, '
        'lead all souls to Heaven, especially those in most need of Thy '
        'mercy. Amen.',
      );
      expect(
        pack.content['fatima-prayer']!.source,
        'Fatima prayer tradition (1910s)',
      );
      expect(pack.content['fatima-prayer']!.license, 'public-domain');

      // The core traditional prayers carry the repository's public-domain
      // convention and the canonical wording (the Creed with 'I believe in
      // God...', not the sign-of-cross formula).
      for (final String key in expectedKeys.where(
        (String key) => key != 'fatima-prayer',
      )) {
        expect(
          pack.content[key]!.source,
          'Traditional Roman devotion',
          reason: key,
        );
        expect(pack.content[key]!.license, 'public-domain', reason: key);
      }
      expect(
        pack.content['apostles-creed']!.text,
        startsWith('I believe in God, the Father Almighty'),
      );
      expect(
        pack.content['our-father']!.text,
        startsWith('Our Father, Who art in heaven'),
      );
      expect(
        pack.content['hail-mary']!.text,
        'Hail Mary, full of grace, the Lord is with thee; blessed art thou '
        'amongst women, and blessed is the fruit of thy womb, Jesus. '
        'Holy Mary, Mother of God, pray for us sinners, now and at the '
        'hour of our death. Amen.',
      );
      expect(
        pack.content['glory-be']!.text,
        'Glory be to the Father, and to the Son, and to the Holy Spirit. As '
        'it was in the beginning, is now, and ever shall be, world '
        'without end. Amen.',
      );
    });

    test('closing: Hail Holy Queen and the collect with the folded '
        'Pray-for-us exchange', () {
      final ContentPack pack = loadPack('rosary');

      expect(
        pack.content['hail-holy-queen']!.text,
        'Hail, Holy Queen, Mother of Mercy, our life, our sweetness and our '
        'hope. To thee do we cry, poor banished children of Eve. To '
        'thee do we send up our sighs, mourning and weeping in this '
        'valley of tears. Turn then, most gracious Advocate, thine eyes '
        'of mercy toward us, and after this our exile show unto us the '
        'blessed fruit of thy womb, Jesus. O clement, O loving, O sweet '
        'Virgin Mary.',
      );
      // HHQ itself stops at the salutation; the exchange belongs to the
      // collect (folded, one prayer entry).
      expect(
        pack.content['hail-holy-queen']!.text,
        isNot(contains('Pray for us, O holy Mother of God')),
      );

      final String collect = pack.content['rosary-closing-collect']!.text;
      expect(
        collect,
        startsWith(
          'V. Pray for us, O holy Mother of God.\nR. That we may '
          'be made worthy of the promises of Christ.',
        ),
      );
      expect(
        collect,
        contains(
          'O God, whose only-begotten Son, by His life, death, and '
          'resurrection, has purchased for us the rewards of eternal life',
        ),
      );
      expect(
        collect,
        contains(
          'meditating upon these mysteries of the most Holy Rosary of the '
          'Blessed Virgin Mary, we may imitate what they contain and obtain '
          'what they promise',
        ),
      );
      expect(collect, endsWith('through the same Christ our Lord. Amen.'));
    });

    test('the 20 mystery variants: opaque, app-readable, complete, '
        'attributed', () {
      final ContentPack pack = loadPack('rosary');
      expect(pack.variants, hasLength(20));

      // In-band shape: each entry keys itself by setTitle + index, so the
      // app layer groups by set and orders by index; the list order is the
      // canonical joyful-sorrowful-glorious-luminous enumeration, resolved
      // by keys, never by position.
      final List<String> variantIds = <String>[
        for (final Map<String, dynamic> variant in pack.variants)
          variant['id']! as String,
      ];
      expect(variantIds, <String>[
        for (final String setTitle in MysterySet.values.map(
          (MysterySet set) => set.name,
        )) ...<String>[for (int i = 1; i <= 5; i++) '$setTitle-$i'],
      ]);

      for (final MysterySet set in MysterySet.values) {
        final String setTitle = set.name;
        for (int index = 1; index <= 5; index++) {
          final List<Map<String, dynamic>> matches = pack.variants
              .where(
                (Map<String, dynamic> variant) =>
                    variant['setTitle'] == setTitle &&
                    variant['index'] == index,
              )
              .toList();
          final Map<String, dynamic> variant = matches.single;

          expect(variant['id'], '$setTitle-$index', reason: '$setTitle-$index');
          expect(
            variant['mystery'],
            twentyMysteries[setTitle]![index - 1][0],
            reason: '$setTitle-$index',
          );
          expect(
            variant['fruit'],
            twentyMysteries[setTitle]![index - 1][1],
            reason: '$setTitle-$index',
          );
          expect(
            variant['source'],
            'Rosarium Virginis Mariae (JPII 2002); traditional for '
            'pre-Luminous sets',
            reason: '$setTitle-$index',
          );
          expect(
            variant['license'],
            'public-domain (Rosarium Virginis Mariae 2002 mystery set)',
            reason: '$setTitle-$index',
          );
        }
      }

      // The dispatch-pinned data point lands verbatim: first joyful
      // decade is the Annunciation, fruit Humility.
      expect(pack.variants.first['mystery'], 'The Annunciation');
      expect(pack.variants.first['fruit'], 'Humility');
    });

    test('round trip: the opaque app-layer hooks survive serialization', () {
      final ContentPack pack = loadPack('rosary');
      final Map<String, dynamic> json = pack.toJson();
      expect(json['reminders']['mysterySource'], 'rosaryMysteriesFor');
      expect(json['variants'], hasLength(20));

      final ContentPack reloaded = PackLoader.load(json);
      expect(reloaded.reminders['mysterySource'], 'rosaryMysteriesFor');
      expect(reloaded.variants, hasLength(20));
      expect(reloaded.session.steps, hasLength(12));
      final BeadGroupStep decade = reloaded.session.steps
          .whereType<BeadGroupStep>()
          .first;
      expect(decade.mysteryTitle, '{{mysteryTitle}}');
      expect(decade.mysteryFruit, '{{mysteryFruit}}');
    });

    test('PackValidator passes for fixture year 2026', () {
      expect(PackValidator.problems(loadPack('rosary'), 2026), isEmpty);
    });
  });
}
