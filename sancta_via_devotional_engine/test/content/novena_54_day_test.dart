import 'package:sancta_via_devotional_engine/sancta_via_devotional_engine.dart';
import 'package:test/test.dart';

/// Fixture directory the content packs live in (tasks 14-19).
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

/// The 54-Day Rosary Novena pack, loaded once per test group helper.
ContentPack pack() => loadPack('novena_54_day');

/// The brief's phase mapping: days 1-27 petition, 28-54 thanksgiving.
String phaseFor(int dayIndex) {
  if (dayIndex < 1 || dayIndex > 54) {
    throw ArgumentError.value(dayIndex, 'dayIndex', 'must be 1..54');
  }
  return dayIndex <= 27 ? 'petition' : 'thanksgiving';
}

/// The brief's daily mystery cycle: `dayIndex % 3` (1→joyful, 2→sorrowful,
/// 0→glorious) — the tradition's J-S-G rotation (each of the six novenas
/// prays each set three times in that order, so the mapping is one set per
/// day in continuous J-S-G rotation; the traditional text's schedule
/// confirms day 27 Glorious, day 28 Joyful).
String mysterySetFor(int dayIndex) {
  switch (dayIndex % 3) {
    case 1:
      return 'joyful';
    case 2:
      return 'sorrowful';
    default:
      return 'glorious';
  }
}

/// The traditional per-decade "binding" formula of the day's first chosen
/// mystery, per mystery set and phase (petition / thanksgiving word differ;
/// the flower follows the set: snow-white buds = joyful, blood red roses =
/// sorrowful, full-blown roses = glorious). The widely circulated 54-day
/// novena text's decade formulas, verbatim, virtues included.
const Map<String, Map<String, String>> decadeFormulas = <String, Map<String, String>>{
  'joyful': <String, String>{
    'petition':
        'I bind these snow-white buds with a petition for the virtue of '
        'humility and humbly lay this bouquet at thy feet.',
    'thanksgiving':
        'I bind these snow-white buds with a thanksgiving for the virtue '
        'of humility and humbly lay this bouquet at thy feet.',
  },
  'sorrowful': <String, String>{
    'petition':
        'I bind these blood red roses with a petition for the virtue of '
        'resignation to the will of God and humbly lay this bouquet at '
        'thy feet.',
    'thanksgiving':
        'I bind these blood red roses with a thanksgiving for the virtue '
        'of resignation to the will of God and humbly lay this bouquet '
        'at thy feet.',
  },
  'glorious': <String, String>{
    'petition':
        'I bind these full-blown roses with a petition for the virtue of '
        'faith and humbly lay this bouquet at thy feet.',
    'thanksgiving':
        'I bind these full-blown roses with a thanksgiving for the virtue '
        'of faith and humbly lay this bouquet at thy feet.',
  },
};

/// The traditional virtue caption of the day's first chosen mystery, per
/// mystery set (identical across the two phases).
const Map<String, String> decadeVirtues = <String, String>{
  'joyful': 'humility',
  'sorrowful': 'resignation to the will of God',
  'glorious': 'faith',
};

/// The key-based lookup of one day variant (never by list position).
Map<String, dynamic> dayVariant(int day) {
  return pack().variants.singleWhere(
    (Map<String, dynamic> variant) => variant['dayIndex'] == day,
    orElse: () =>
        throw StateError('pack.variants must carry a day-$day variant'),
  );
}

/// Walks the pack session from a fresh state to completion, recording the
/// counted bead targets as the runner requires.
SessionState walkSession(ContentPack pack, {required int day}) {
  SessionState state = SessionRunner.forState(pack.session);
  while (!state.isComplete) {
    final SessionStep step = pack.session.steps[state.stepIndex];
    if (step is BeadGroupStep) {
      state = SessionRunner.record(state, step.hailMaryCount);
    }
    state = SessionRunner.completeCurrent(state, script: pack.session);
  }
  return state;
}

void main() {
  group('54-day rosary novena pack', () {
    test('loads from the fixtures directory', () {
      final ContentPack p = pack();
      expect(p.id, 'novena_54_day');
      expect(p.family, PackFamily.novena);
      expect(p.title, isNotEmpty);
    });

    test('ships the user-picked-start sessionSeries fixture '
        '(startDate 2026-11-10, length 54)', () {
      final ContentPack p = pack();
      expect(p.schedules, hasLength(1));
      expect(p.schedule, same(p.schedules.first));
      expect(p.schedules.single, isA<SessionSeriesSpec>());
      final SessionSeriesSpec series = p.schedules.single as SessionSeriesSpec;
      // The concrete fixture form (the enrollment contract recomputes the
      // start: a 54-day novena starts on whatever day the user picks, so
      // no anchor feast metadata rides along — the reminders.startAnchor
      // block below documents that convention).
      expect(series.startDate, DateTime(2026, 11, 10));
      expect(series.lengthDays, 54);

      // The startAnchor metadata rides in the pack's opaque reminders
      // map — the same hook shape as the consecration pack's feastAnchor
      // — and documents that startDate is a user-picked enrollment
      // parameter whose fixture value is a placeholder.
      expect(p.reminders.keys, <String>['startAnchor']);
      final Map<String, dynamic> startAnchor =
          p.reminders['startAnchor']! as Map<String, dynamic>;
      expect(startAnchor['pickedBy'], 'user');
      final String note = startAnchor['note']! as String;
      expect(note, contains('user-picked'));
      expect(note, contains('placeholder'));

      // Day 1 (2026-11-10) and day 54 (2027-01-02) are due with their
      // 1-based day indexes; the series end resolves 54, not 55.
      final ScheduleResult first = p.schedule.resolve(
        DateTime(2026, 11, 10),
        const ScheduleContext(),
      );
      expect(first.due, isTrue);
      expect(first.dayIndex, 1);
      final ScheduleResult last = p.schedule.resolve(
        DateTime(2027, 1, 2),
        const ScheduleContext(),
      );
      expect(last.due, isTrue);
      expect(last.dayIndex, 54);
      // Day 55 is not due (Review Focus 4's not-due edge).
      expect(
        p.schedule.resolve(DateTime(2027, 1, 3), const ScheduleContext()).due,
        isFalse,
      );
      // And the day before day 1 is likewise not due.
      expect(
        p.schedule.resolve(DateTime(2026, 11, 9), const ScheduleContext()).due,
        isFalse,
      );
    });

    test('year edge: the series spans 2026 into 2027 '
        '(52 due dates in 2026, 2 in 2027)', () {
      final ContentPack p = pack();
      int dueIn(int year) {
        int count = 0;
        for (int month = 1; month <= 12; month++) {
          final int lastDay = DateTime(year, month + 1, 0).day;
          for (int day = 1; day <= lastDay; day++) {
            if (p.schedule
                .resolve(DateTime(year, month, day), const ScheduleContext())
                .due) {
              count++;
            }
          }
        }
        return count;
      }

      // Nov 10..Dec 31 is 52 days; Jan 1..2 2027 are the last two.
      expect(dueIn(2026), 52);
      expect(dueIn(2027), 2);
    });

    test('carries exactly the 54 in-band day variants plus the pinned '
        'restart-policy and luminous variants', () {
      final ContentPack p = pack();
      // 54 day variants first, in day order, then the three documentation
      // variants the brief pins.
      expect(p.variants, hasLength(57));

      final List<Map<String, dynamic>> dayVariants = p.variants
          .where((Map<String, dynamic> variant) => variant.containsKey('dayIndex'))
          .toList();
      expect(dayVariants, hasLength(54));

      // In-band mapping: every entry carries its own dayIndex, and the 54
      // indexes appear exactly 1..54, in list order (positions 0..53).
      for (int i = 0; i < 54; i++) {
        expect(p.variants[i]['dayIndex'], i + 1, reason: 'variants[$i]');
      }
      final Set<int> indexes = <int>{
        for (final Map<String, dynamic> variant in dayVariants)
          variant['dayIndex']! as int,
      };
      expect(indexes, <int>{for (int i = 1; i <= 54; i++) i});

      // The three documentation variants ride last, without a dayIndex.
      final List<String> trailingIds = <String>[
        for (int i = 54; i < p.variants.length; i++) p.variants[i]['id']! as String,
      ];
      expect(trailingIds, <String>['strict', 'permissive', 'include-luminous']);
      for (int i = 54; i < p.variants.length; i++) {
        expect(
          p.variants[i].containsKey('dayIndex'),
          isFalse,
          reason: 'variants[$i] is a documentation variant',
        );
      }

      // Policy variants: engine-vocabulary policy mirror + a doc note.
      final Map<String, dynamic> strict = p.variants[54];
      expect(strict['policy'], 'strict');
      expect(strict['note'], isNotEmpty);
      final Map<String, dynamic> permissive = p.variants[55];
      expect(permissive['policy'], 'permissive');
      expect(permissive['note'], isNotEmpty);

      // The Luminous variant is set-optional app documentation only.
      final Map<String, dynamic> luminous = p.variants[56];
      expect(luminous.containsKey('policy'), isFalse);
      expect(luminous['note'], isNotEmpty);
    });

    test('phase mapping and per-day mystery cycle sweep across all 54 days',
        () {
      for (int day = 1; day <= 54; day++) {
        final Map<String, dynamic> variant = dayVariant(day);
        expect(variant['id'], 'day-$day', reason: 'day $day');
        expect(variant['phase'], phaseFor(day), reason: 'day $day');
        expect(variant['mysterySet'], mysterySetFor(day), reason: 'day $day');
        // The day's traditional decade formula follows its set and phase,
        // and its virtue caption follows its set.
        expect(
          variant['petition'],
          decadeFormulas[mysterySetFor(day)]![phaseFor(day)],
          reason: 'day $day petition formula',
        );
        expect(
          variant['virtue'],
          decadeVirtues[mysterySetFor(day)],
          reason: 'day $day virtue caption',
        );
        // Variant texts stay token-free: the sanctioned {{day}} token is
        // not needed (the day rides the dayIndex) and no other token is
        // ever invented.
        expect(
          variant['petition']! as String,
          isNot(contains('{{')),
          reason: 'day $day petition must be token-free',
        );
      }
    });

    test('Review Focus 4: day 27 petition / day 28 thanksgiving boundary, '
        'day 54 series end, day 55 not due', () {
      // Boundary: the last petition day and the first thanksgiving day
      // swap the phase labels the app renders.
      final Map<String, dynamic> day27 = dayVariant(27);
      expect(day27['phase'], 'petition');
      final Map<String, dynamic> day28 = dayVariant(28);
      expect(day28['phase'], 'thanksgiving');
      expect(day28['dayIndex'], 28);

      // The mysteries follow the brief's cycle formula (dayIndex % 3:
      // 1 joyful, 2 sorrowful, 0 glorious — the traditional J-S-G rotation
      // with day 1 joyful). Day 27 is the petition phase's ninth and last
      // GLORIOUS day, and day 28 opens thanksgiving with the JOYFUL set:
      // the plan's Review-Focus bullet names day 27 "Joyful" and day 28
      // "Sorrowful", which contradicts the brief's own pinned formula and
      // the traditional schedule (petitions end joyful→sorrowful→glorious;
      // novenaprayer.com's table prints Day 27 as Glorious, Day 28 as
      // Joyful). The formula governs; see the task report's reconciliation.
      expect(day27['mysterySet'], 'glorious');
      expect(day27['petition'], decadeFormulas['glorious']!['petition']);
      expect(day27['virtue'], 'faith');
      expect(day28['mysterySet'], 'joyful');
      expect(day28['petition'], decadeFormulas['joyful']!['thanksgiving']);
      expect(day28['virtue'], 'humility');

      // Day 54: the thanksgiving phase's last day, gloriously set.
      final Map<String, dynamic> day54 = dayVariant(54);
      expect(day54['phase'], 'thanksgiving');
      expect(day54['mysterySet'], 'glorious');
      expect(day54['petition'], decadeFormulas['glorious']!['thanksgiving']);

      // Series end: day 54 is due as dayIndex 54 and day 55 is not due —
      // no index overflow.
      expect(
        pack()
            .schedule
            .resolve(DateTime(2027, 1, 2), const ScheduleContext())
            .dayIndex,
        54,
      );
      expect(
        pack()
            .schedule
            .resolve(DateTime(2027, 1, 3), const ScheduleContext())
            .due,
        isFalse,
      );
    });

    test('day 27 and day 54 sessions complete through the SessionRunner '
        '(no index overflow; the static script is the same every day)', () {
      final ContentPack p = pack();
      for (final int day in <int>[27, 54]) {
        final SessionState state = walkSession(p, day: day);
        expect(state.scriptId, p.session.id, reason: 'day $day');
        expect(state.stepCount, p.session.steps.length, reason: 'day $day');
        expect(
          state.stepIndex,
          p.session.steps.length,
          reason: 'day $day must complete every step',
        );
        expect(state.isComplete, isTrue, reason: 'day $day');
      }
    });

    test('session: sign of the cross, both phase openings, three '
        'placeholder decades, closing verse pair, both phase closings, '
        'collect', () {
      final ContentPack p = pack();
      final List<SessionStep> steps = p.session.steps;
      expect(p.session.id, 'novena-54-day-session');
      expect(steps, hasLength(10));

      // The sign of the cross as an opening verse exchange.
      final VerseStep signOfTheCross = steps[0] as VerseStep;
      expect(signOfTheCross.id, 'novena-54-sign-of-cross');
      expect(
        signOfTheCross.versicle,
        'In the name of the Father, and of the Son, and of the Holy '
        'Spirit.',
      );
      expect(signOfTheCross.response, 'Amen.');

      // The phase opening pair: the petition phase text is the static
      // session's default; the thanksgiving phase opening ships beside it
      // and the app swaps via the day's variant phase (the static schema
      // cannot branch per day — the same ruling as the consecration
      // pack's day-34 step).
      final PrayerStep petitionOpening = steps[1] as PrayerStep;
      expect(petitionOpening.id, 'novena-54-petition-opening');
      expect(petitionOpening.title, 'Petition phase opening (days 1-27)');
      expect(petitionOpening.text.id, 'petition-opening');

      final PrayerStep thanksgivingOpening = steps[2] as PrayerStep;
      expect(thanksgivingOpening.id, 'novena-54-thanksgiving-opening');
      expect(
        thanksgivingOpening.title,
        'Thanksgiving phase opening (days 28-54)',
      );
      expect(thanksgivingOpening.text.id, 'thanksgiving-opening');

      // Three BeadGroupSteps, one per chosen mystery of the day's set:
      // counted tens with the Fatima flag, mystery fields carrying the
      // Task 17 substitution placeholders (never static mystery text).
      final List<BeadGroupStep> decades = steps
          .whereType<BeadGroupStep>()
          .toList();
      expect(decades, hasLength(3));
      for (int i = 0; i < 3; i++) {
        final BeadGroupStep decade = decades[i];
        expect(decade.id, 'novena-54-decade-${i + 1}', reason: 'decade $i');
        expect(decade.hailMaryCount, 10, reason: decade.id);
        expect(decade.includeFatimaPrayer, isTrue, reason: decade.id);
        expect(decade.mysteryTitle, '{{mysteryTitle}}', reason: decade.id);
        expect(decade.mysteryFruit, '{{mysteryFruit}}', reason: decade.id);
      }
      expect(steps[3], same(decades[0]));
      expect(steps[5], same(decades[2]));
      expect(
        steps.indexOf(decades[1]),
        4,
        reason: 'decades sit between the openings and the closing block',
      );

      // The closing verse pair (the traditional lead-out exchange).
      final VerseStep finalVerse = steps[6] as VerseStep;
      expect(finalVerse.id, 'novena-54-final-verse');
      expect(finalVerse.versicle, 'V. Pray for us, O holy Mother of God.');
      expect(
        finalVerse.response,
        'R. That we may be made worthy of the promises of Christ.',
      );

      // The phase-closing pair after the verse pair, mirroring the
      // openings (petition default + thanksgiving alternative).
      final PrayerStep petitionClosing = steps[7] as PrayerStep;
      expect(petitionClosing.text.id, 'petition-closing');
      expect(petitionClosing.title, 'Petition phase closing (days 1-27)');
      final PrayerStep thanksgivingClosing = steps[8] as PrayerStep;
      expect(thanksgivingClosing.text.id, 'thanksgiving-closing');
      expect(
        thanksgivingClosing.title,
        'Thanksgiving phase closing (days 28-54)',
      );

      // The terminal collect of the traditional day.
      expect(steps[9], isA<PrayerStep>());
      final PrayerStep collect = steps[9] as PrayerStep;
      expect(collect.text.id, 'novena-closing');
      expect(steps.last, same(collect));
    });

    test('every contentRef resolves; the content map is complete '
        'and attributed', () {
      final ContentPack p = pack();

      // Exactly the five prayer texts the session references.
      expect(p.content.keys, <String>{
        'petition-opening',
        'thanksgiving-opening',
        'petition-closing',
        'thanksgiving-closing',
        'novena-closing',
      });

      int referenced = 0;
      for (final SessionStep step in p.session.steps) {
        switch (step) {
          case PrayerStep(:final PrayerText text):
            expect(p.content[text.id], text, reason: text.id);
            referenced++;
          case VerseStep():
            continue;
          case BeadGroupStep(): // amended under Task 19 rulings (see ledger)
            continue;
          default:
            fail('unexpected step type ${step.runtimeType}');
        }
      }
      expect(referenced, 5); // amended under Task 19 rulings (see ledger)

      // Every text carries a non-empty source and license.
      for (final PrayerText entry in p.content.values) {
        expect(entry.source, isNotEmpty, reason: entry.id);
        expect(entry.license, 'public-domain', reason: entry.id);
      }

      // The traditional novena texts carry the tradition's attribution;
      // the collect is the rosary's traditional Roman prayer.
      for (final String key in <String>[
        'petition-opening',
        'thanksgiving-opening',
        'petition-closing',
        'thanksgiving-closing',
      ]) {
        expect(
          p.content[key]!.source,
          // amended under Task 19 rulings (see ledger)
          'Traditional 54-day Rosary Novena (Pompeii, 1884 tradition; '
          'widely circulated public-domain-era text; '
          'rose-color clause of the offering stanza omitted)',
          reason: key,
        );
      }
      expect(
        p.content['novena-closing']!.source,
        'Traditional Roman devotion',
        reason: 'novena-closing',
      );

      // The openings omit only the per-set rose-color clause; the source
      // string must document that adaptation.
      expect(
        p.content['petition-opening']!.source,
        contains('rose-color clause of the offering stanza omitted'),
      );
    });

    test('texts: the traditional 54-day formulas, petition and '
        'thanksgiving forms, verbatim with their placeholders', () {
      final ContentPack p = pack();

      // Petition opening: the offering stanza (set-neutral) and the
      // petition stanza asking for the favor.
      final String petitionOpening = p.content['petition-opening']!.text;
      expect(
        petitionOpening,
        'Hail, Queen of the Most Holy Rosary, my Mother Mary, hail! At thy '
        'feet I humbly kneel to offer thee a Crown of Roses, each rose '
        'recalling to thee a holy mystery, each 10 bound together with my '
        'petition for a particular grace.\n\n'
        'O Holy Queen, dispenser of God\'s graces, and Mother of all who '
        'invoke thee! Thou canst not look upon my gift and fail to see its '
        'binding. As thou receivest my gift, so wilt thou receive my '
        'petition; from thy bounty thou wilt give me the favor I so '
        'earnestly and trustingly seek. I despair of nothing that I ask of '
        'thee. Show thyself my Mother!',
      );

      // Thanksgiving opening: the same crown offered gratefully, asking
      // now to receive thanksgiving for the favor already given.
      final String thanksgivingOpening = p
          .content['thanksgiving-opening']!.text;
      expect(
        thanksgivingOpening,
        'Hail, Queen of the Most Holy Rosary, my Mother Mary, hail! At thy '
        'feet I gratefully kneel to offer thee a Crown of Roses, each rose '
        'recalling to thee a holy mystery, each 10 bound together with my '
        'petition for a particular grace.\n\n'
        'O Holy Queen, dispenser of God\'s graces, and Mother of all who '
        'invoke thee! Thou canst not look upon my gift and fail to see its '
        'binding. As thou receivest my gift, so wilt thou receive my '
        'thanksgiving; from thy bounty thou hast given me the favor I so '
        'earnestly and trustingly sought. I despaired not of what I asked '
        'of thee, and thou hast truly shown thyself my Mother.',
      );

      // The phase closings: the tradition's Sweet-Mother-Mary formulas;
      // "(specify request)" is the printed text's own placeholder.
      final String petitionClosing = p.content['petition-closing']!.text;
      expect(
        petitionClosing,
        'Sweet Mother Mary, I offer thee this spiritual communion to bind '
        'my bouquets in a wreath to place upon thy brow. O my Mother! '
        'Look with favor upon my gift, and in thy love obtain for me '
        '(specify request). Amen.',
      );
      final String thanksgivingClosing = p
          .content['thanksgiving-closing']!.text;
      expect(
        thanksgivingClosing,
        'Sweet Mother Mary, I offer thee this Spiritual Communion to bind '
        'my bouquets in a wreath to place upon thy brow in thanksgiving '
        'for (specify request) which thou in thy love hast obtained for '
        'me. Amen.',
      );

      // The collect: the rosary's traditional closing prayer (the 54-day
      // text's final closing prayer), without the folded V./R. exchange
      // (which the session's own verse pair carries).
      final String collect = p.content['novena-closing']!.text;
      expect(collect, startsWith('Let us pray. O God, whose only-begotten '
          'Son, by His life, death, and resurrection, has purchased for us '
          'the rewards of eternal life'));
      expect(
        collect,
        contains('meditating upon these mysteries of the most Holy Rosary '
            'of the Blessed Virgin Mary, we may imitate what they contain '
            'and obtain what they promise'),
      );
      expect(collect, endsWith('through the same Christ our Lord. Amen.'));
      expect(collect, isNot(contains('Pray for us')));
    });

    test('no substitution tokens beyond the sanctioned mystery placeholders',
        () {
      final ContentPack p = pack();
      // The {{day}} token's place in this pack is the variant dayIndex;
      // the token is deliberately absent everywhere, and no invented
      // token ({{phase}}, {{virtue}}, ...) may leak into any text.
      for (final PrayerText entry in p.content.values) {
        expect(entry.text, isNot(contains('{{')), reason: entry.id);
      }
      for (final Map<String, dynamic> variant in p.variants) {
        for (final String key in variant.keys) {
          final Object? value = variant[key];
          if (value is String) {
            expect(value, isNot(contains('{{')), reason: '$key in $variant');
          }
        }
      }
    });

    test('restart-policy variants are live MissedDayEvaluator inputs '
        '(the engine consumes the policy)', () {
      final ContentPack p = pack();
      final Map<String, dynamic> strict = p.variants.singleWhere(
        (Map<String, dynamic> variant) => variant['id'] == 'strict',
      );
      final Map<String, dynamic> permissive = p.variants.singleWhere(
        (Map<String, dynamic> variant) => variant['id'] == 'permissive',
      );

      // The policy names the app reads off the variants are exactly the
      // engine's MissedDayEvaluator vocabulary; a policy string that
      // failed to match would throw ArgumentError from the evaluator.
      final ProgressState state = ProgressState(
        packId: p.id,
        fulfilledOrdinals: 3,
      );
      // A daily-cadence gap: two days between last fulfilled and next due.
      final DateTime last = DateTime(2026, 11, 12);
      final DateTime nextDue = DateTime(2026, 11, 14);
      expect(
        MissedDayEvaluator.evaluate(
          strict['policy']! as String,
          state,
          last,
          nextDue,
        ),
        MissedDayVerdict.reset,
      );
      expect(
        MissedDayEvaluator.evaluate(
          permissive['policy']! as String,
          state,
          last,
          nextDue,
        ),
        MissedDayVerdict.resume,
      );
      // With no ordinals fulfilled yet, either policy defers to the user.
      final ProgressState fresh = ProgressState(packId: p.id);
      expect(
        MissedDayEvaluator.evaluate('strict', fresh, last, nextDue),
        MissedDayVerdict.askUser,
      );
    });

    test('round trip: schedule, variants, and content survive '
        'serialization', () {
      final ContentPack p = pack();
      final Map<String, dynamic> json = p.toJson();

      // The sessionSeries schedule round-trips to its exact dispatch JSON.
      expect(json['schedule'], <String, dynamic>{
        'type': 'sessionSeries',
        'startDate': '2026-11-10',
        'lengthDays': 54,
      });
      expect(json['variants'], hasLength(57));
      expect(
        json['content']['petition-closing']['text'],
        startsWith('Sweet Mother Mary'),
      );

      final ContentPack reloaded = PackLoader.load(json);
      expect(reloaded.id, 'novena_54_day');
      expect(reloaded.family, PackFamily.novena);
      final SessionSeriesSpec series =
          reloaded.schedules.single as SessionSeriesSpec;
      expect(series.startDate, DateTime(2026, 11, 10));
      expect(series.lengthDays, 54);

      expect(reloaded.variants, hasLength(57));
      final Map<String, dynamic> day27 = reloaded.variants.singleWhere(
        (Map<String, dynamic> variant) => variant['dayIndex'] == 27,
      );
      expect(day27['id'], 'day-27');
      expect(day27['phase'], 'petition');
      expect(day27['mysterySet'], 'glorious');
      expect(
        day27['petition'],
        'I bind these full-blown roses with a petition for the virtue of '
        'faith and humbly lay this bouquet at thy feet.',
      );
      expect(day27['virtue'], 'faith');

      final Map<String, dynamic> strict = reloaded.variants.singleWhere(
        (Map<String, dynamic> variant) => variant['id'] == 'strict',
      );
      expect(strict['policy'], 'strict');
      final Map<String, dynamic> luminous = reloaded.variants.singleWhere(
        (Map<String, dynamic> variant) => variant['id'] == 'include-luminous',
      );
      expect(luminous['note'], isNotEmpty);

      expect(reloaded.session.steps, hasLength(10));
      final BeadGroupStep decade = reloaded.session.steps
          .whereType<BeadGroupStep>()
          .first;
      expect(decade.mysteryTitle, '{{mysteryTitle}}');
      expect(decade.mysteryFruit, '{{mysteryFruit}}');
      expect(reloaded.content.keys, p.content.keys);
    });

    test('PackValidator passes for fixture year 2026 '
        '(and for 2027: the series crosses the year end)', () {
      // The sweep requires at least one due date in the fixture year —
      // 2026-11-10..2026-12-31 supplies 52. The series' last two days
      // (2027-01-01/02) make the 2027 sweep pass too, documenting the
      // year edge the user-picked start rides over.
      expect(PackValidator.problems(pack(), 2026), isEmpty);
      expect(PackValidator.problems(pack(), 2027), isEmpty);
    });
  });
}
