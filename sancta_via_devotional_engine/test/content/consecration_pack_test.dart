import 'package:sancta_via_devotional_engine/sancta_via_devotional_engine.dart';
import 'package:test/test.dart';

/// Fixture directory the content packs live in (tasks 14-18).
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

/// The Total Consecration pack, loaded once per test group helper.
ContentPack pack() => loadPack('total_consecration');

/// The de Montfort preparation's day-by-phase mapping (the brief's pins):
/// days 1-12 emptying (renouncing the spirit of the world), 13-19 self
/// (knowledge of self), 20-26 mary (knowledge of Mary), 27-33 jesus
/// (knowledge of Jesus Christ), 34 the consecration day itself.
String phaseFor(int dayIndex) {
  if (dayIndex < 1 || dayIndex > 34) {
    throw ArgumentError.value(dayIndex, 'dayIndex', 'must be 1..34');
  }
  if (dayIndex <= 12) {
    return 'emptying';
  }
  if (dayIndex <= 19) {
    return 'self';
  }
  if (dayIndex <= 26) {
    return 'mary';
  }
  if (dayIndex <= 33) {
    return 'jesus';
  }
  return 'consecration';
}

/// The per-phase daily prompt the pack's variants carry (prompt is
/// phase-keyed: every day of a phase renders the same prompt; the app knows
/// the day from the variant's dayIndex). Prompts are `{{day}}`-free by
/// ruling; the phase variant carries everything.
const Map<String, String> phasePrompts = <String, String>{
  'emptying':
      "Renounce the spirit of the world: sit with the day's reading and "
      "ask for detachment from the world's vanity.",
  'self':
      'Ask the Holy Spirit for light to know yourself: your misery and '
      'your capacity for grace.',
  'mary':
      "Ask the Holy Spirit for a true knowledge of Mary: who she is in "
      "God's plan and in your soul.",
  'jesus':
      'Ask the Holy Spirit for the knowledge of Jesus Christ crucified, '
      'living in Mary: your sovereign King.',
  'consecration':
      'Make today the Act of Consecration to Jesus through Mary, and '
      'resolve to renew it daily.',
};

/// The day-by-day public-domain reading titles of the classic de Montfort
/// 33-day preparation (scripture, Imitation of Christ, and de Montfort's own
/// True Devotion to Mary / Secret of Mary excerpts as the preparation
/// assigns them), indexed by day - list day - 1.
const List<String> dayReadings = <String>[
  'Matthew 5:1-19 — the Beatitudes: poor in spirit, meek, clean of heart',
  'Matthew 5:48, 6:1-15 — on perfection, justice in secret, and the '
      'Our Father',
  'Matthew 7:1-14 — judge not, and enter by the narrow gate',
  'Imitation of Christ Bk. III, chs. 7 and 40 — that man has no good of '
      'himself',
  'Imitation of Christ Bk. III, ch. 40 — casting away the consolations of '
      'creatures',
  'Imitation of Christ Bk. I, ch. 18 — on the examples of the holy Fathers',
  'Imitation of Christ Bk. I, ch. 18 (conclusion) — outward want, inward '
      'peace',
  'Imitation of Christ Bk. I, ch. 13 — of resisting temptations',
  'Imitation of Christ Bk. I, ch. 13 (conclusion) — fire tries iron: '
      'temptation tries the just man',
  'Imitation of Christ Bk. III, ch. 10 — that it is sweet to despise the '
      'world and to serve God',
  'Imitation of Christ Bk. I, ch. 25 — on the fervent amendment of our '
      'whole life',
  'Imitation of Christ Bk. I, ch. 25 (conclusion) — the eager amendment of '
      'our whole life',
  'Litany of the Holy Spirit — opening the week of knowledge of self',
  'Imitation of Christ Bk. III, ch. 13 — of the obedience of one in humble '
      'subjection',
  'Luke 13:1-5 — examples inviting repentance',
  'True Devotion to Mary §228 — on the preparatory exercises',
  'Imitation of Christ Bk. I, ch. 24 — of judgment and the punishment of '
      'sinners',
  'Luke 17:1-10 — woe to scandals; faith, humility, and duty',
  'Luke 18:15-30 — let the children come; the danger of riches',
  'Litany of Loreto — opening the week of knowledge of the Blessed Virgin',
  'Secret of Mary §§23-24 — true devotion to our Blessed Lady',
  'True Devotion to Mary §§106-110 — marks of authentic devotion to Our '
      'Lady',
  'True Devotion to Mary §§120-121 — the nature of perfect devotion and '
      'consecration to Jesus through Mary',
  'True Devotion to Mary §§152-164 — a smooth, short, perfect and sure way',
  'True Devotion to Mary §§213-225 — the wonderful effects of this '
      'devotion',
  'True Devotion to Mary §§12-38 — understanding the Mother through the '
      'Son',
  'Litany of the Holy Name of Jesus — opening the week of knowledge of '
      'Jesus Christ',
  'Matthew 26:1, 26-29, 36-46 — the Last Supper and the Agony in Gethsemani',
  'Imitation of Christ Bk. I, ch. 1 — of the imitation of Christ and '
      'contempt for all the vanities of the world',
  'Matthew 27:36-44 — the Crucifixion',
  'Imitation of Christ Bk. IV, ch. 2 — the great goodness and love of God '
      'shown us in this Sacrament',
  'Imitation of Christ Bk. II, ch. 7 — of the love of Jesus above all '
      'things',
  'Imitation of Christ Bk. IV, ch. 11 — that the Blood of Christ and the '
      'Holy Scriptures are most necessary',
  'The Act of Consecration, True Devotion §§225-233 — with the renewal of '
      'baptismal vows',
];

void main() {
  group('total consecration pack', () {
    test('loads from the fixtures directory', () {
      final ContentPack p = pack();
      expect(p.id, 'total_consecration');
      expect(p.family, PackFamily.commitment);
      expect(p.title, isNotEmpty);
    });

    test('ships the pinned pre-fixed sessionSeries schedule '
        '(Task 7 ledger ruling)', () {
      final ContentPack p = pack();
      expect(p.schedules, hasLength(1));
      expect(p.schedule, same(p.schedules.first));
      expect(p.schedules.single, isA<SessionSeriesSpec>());
      final SessionSeriesSpec series = p.schedules.single as SessionSeriesSpec;
      // The pre-pinned fixture form: 2027-02-20 for 34 days (day 34 being
      // the Annunciation 2027-03-25 across a non-leap February).
      expect(series.startDate, DateTime(2027, 2, 20));
      expect(series.lengthDays, 34);

      // Day 1 (2027-02-20) and day 34 (2027-03-25) are due with their
      // 1-based day indexes; the day after the consecration is not due.
      final ScheduleResult first = series.resolve(
        DateTime(2027, 2, 20),
        const ScheduleContext(),
      );
      expect(first.due, isTrue);
      expect(first.dayIndex, 1);
      final ScheduleResult consecration = series.resolve(
        DateTime(2027, 3, 25),
        const ScheduleContext(),
      );
      expect(consecration.due, isTrue);
      expect(consecration.dayIndex, 34);
      expect(
        series.resolve(DateTime(2027, 3, 26), const ScheduleContext()).due,
        isFalse,
      );
    });

    test('enrollment for feast 2027-03-25 yields start 2027-02-20 '
        '(ConsecrationPlanner through the pack feastAnchor metadata)', () {
      final ContentPack p = pack();

      // The opaque feastAnchor metadata rides in the pack's one opaque
      // map (reminders) - the same hook shape as task 17's mysterySource.
      expect(p.reminders.keys, <String>['feastAnchor']);
      final Object? anchor = p.reminders['feastAnchor'];
      expect(anchor, isA<Map<String, dynamic>>());
      final Map<String, dynamic> feastAnchor = anchor! as Map<String, dynamic>;
      expect(feastAnchor['feast'], 'annunciation');
      expect(feastAnchor['date'], '03-25');

      // The app's enrollment math: resolve the anchor's month-day against
      // the enrollment year, then plan the start through the engine.
      final List<String> parts = (feastAnchor['date']! as String).split('-');
      final DateTime feast = DateTime(
        2027,
        int.parse(parts[0]),
        int.parse(parts[1]),
      );
      expect(feast, DateTime(2027, 3, 25));
      final DateTime start = ConsecrationPlanner.startFor(feast);
      expect(start, DateTime(2027, 2, 20));

      // Coherence: the fixture's pinned series start IS the planner's
      // result for the anchor feast.
      expect((p.schedules.single as SessionSeriesSpec).startDate, start);

      // The ledger's leap-year reminder rides the same anchor: a Feb 29 in
      // the preparation shifts the start to 2028-02-21.
      expect(
        ConsecrationPlanner.startFor(DateTime(2028, 3, 25)),
        DateTime(2028, 2, 21),
      );
    });

    test('feastAnchor survives the round trip and replans the same start', () {
      final ContentPack p = pack();
      final ContentPack reloaded = PackLoader.load(p.toJson());

      expect(reloaded.id, 'total_consecration');
      expect(reloaded.reminders['feastAnchor'], <String, dynamic>{
        'feast': 'annunciation',
        'date': '03-25',
      });

      final Map<String, dynamic> anchor =
          reloaded.reminders['feastAnchor']! as Map<String, dynamic>;
      final List<String> parts = (anchor['date']! as String).split('-');
      final DateTime feast = DateTime(
        2027,
        int.parse(parts[0]),
        int.parse(parts[1]),
      );
      final SessionSeriesSpec series =
          reloaded.schedules.single as SessionSeriesSpec;
      expect(ConsecrationPlanner.startFor(feast), series.startDate);
      // The pinned ISO date round-trips through the loader's date-only
      // parse without a time-zone designator.
      expect(series.startDate, DateTime(2027, 2, 20));
      expect(series.lengthDays, 34);
    });

    test('carries exactly 34 day variants, keyed by dayIndex '
        '(in-band, never by list position)', () {
      final ContentPack p = pack();
      expect(p.variants, hasLength(34));

      // In-band mapping: every entry carries its own dayIndex, and the 34
      // indexes appear exactly 1..34, in order.
      final Set<int> indexes = <int>{
        for (final Map<String, dynamic> variant in p.variants)
          variant['dayIndex']! as int,
      };
      expect(indexes, <int>{for (int i = 1; i <= 34; i++) i});
      for (int i = 0; i < p.variants.length; i++) {
        expect(p.variants[i]['dayIndex'], i + 1, reason: 'variants[$i]');
      }

      for (int day = 1; day <= 34; day++) {
        // Key-based lookup by the explicit dayIndex, never by position.
        final Map<String, dynamic> variant = p.variants.singleWhere(
          (Map<String, dynamic> variant) => variant['dayIndex'] == day,
          orElse: () =>
              throw StateError('pack.variants must carry a day-$day variant'),
        );
        expect(variant['id'], 'day-$day', reason: 'day $day');
        expect(
          variant['phase'],
          phaseFor(day),
          reason: 'day $day phase mapping',
        );
        expect(variant['reading'], dayReadings[day - 1], reason: 'day $day');
        expect(
          variant['prompt'],
          phasePrompts[phaseFor(day)],
          reason: 'day $day prompt (phase-keyed)',
        );

        // Variant prompts are day-free by ruling: the {{day}} substitution
        // belongs to the session's reflection text, never to the variants.
        expect(
          variant['prompt']! as String,
          isNot(contains('{{day}}')),
          reason: 'day $day prompt must not carry the {{day}} token',
        );

        // The Act of Consecration flag and badge are day-34 app data only.
        if (day == 34) {
          expect(variant['actOfConsecration'], isTrue);
          expect(variant['badge'], isNotEmpty, reason: 'day 34 badge');
        } else {
          expect(
            variant.containsKey('actOfConsecration'),
            isFalse,
            reason: 'day $day',
          );
          expect(variant.containsKey('badge'), isFalse, reason: 'day $day');
        }
      }

      // Brief pins: the boundary days land exactly.
      final Map<int, String> expectedPhases = <int, String>{
        1: 'emptying',
        12: 'emptying',
        13: 'self',
        19: 'self',
        20: 'mary',
        26: 'mary',
        27: 'jesus',
        33: 'jesus',
        34: 'consecration',
      };
      expectedPhases.forEach((int day, String phase) {
        final Map<String, dynamic> variant = p.variants.singleWhere(
          (Map<String, dynamic> variant) => variant['dayIndex'] == day,
        );
        expect(variant['phase'], phase, reason: 'day $day phase boundary');
        expect(variant['id'], 'day-$day');
      });
    });

    test('session: opening prayers, Latin hymns, reflection, daily renewal, '
        'and the terminal Act-of-Consecration step', () {
      final ContentPack p = pack();
      final List<SessionStep> steps = p.session.steps;
      expect(p.session.id, 'total-consecration-session');
      expect(steps, hasLength(7));

      // Opening prayer: Come, Holy Spirit (antiphon + collect).
      expect(steps[0], isA<PrayerStep>());
      final PrayerStep comeHolySpirit = steps[0] as PrayerStep;
      expect(comeHolySpirit.id, 'tc-come-holy-spirit');
      expect(comeHolySpirit.title, 'Come, Holy Spirit');
      expect(comeHolySpirit.text.id, 'come-holy-spirit');

      // The three daily hymn prayers: vernacular text + Latin rendering in
      // the PrayerText latin field.
      final PrayerStep veniCreator = steps[1] as PrayerStep;
      expect(veniCreator.title, 'Veni Creator Spiritus');
      expect(veniCreator.text.id, 'veni-creator-spiritus');

      final PrayerStep aveMarisStella = steps[2] as PrayerStep;
      expect(aveMarisStella.title, 'Ave Maris Stella');
      expect(aveMarisStella.text.id, 'ave-maris-stella');

      final PrayerStep magnificat = steps[3] as PrayerStep;
      expect(magnificat.title, 'Magnificat');
      expect(magnificat.text.id, 'magnificat');

      // Latin-bearing prayers carry a non-empty latin field that is not
      // the vernacular text.
      for (final PrayerStep step in <PrayerStep>[
        veniCreator,
        aveMarisStella,
        magnificat,
      ]) {
        expect(step.text.latin, isNotEmpty, reason: step.text.id);
        expect(step.text.latin, isNot(step.text.text), reason: step.text.id);
      }
      expect(veniCreator.text.latin, startsWith('Veni, Creator Spiritus'));
      expect(aveMarisStella.text.latin, startsWith('Ave, maris stella'));
      expect(magnificat.text.latin, startsWith('Magnificat anima mea'));

      // The reflection placeholder step: the {{day}}-carrying prompt text
      // and the 10-minute duration.
      expect(steps[4], isA<ReflectionStep>());
      final ReflectionStep reflection = steps[4] as ReflectionStep;
      expect(reflection.text!.id, 'daily-reading-prompt');
      expect(reflection.duration, const Duration(seconds: 600));

      // Closing prayer: the daily renewal line (True Devotion, §233).
      expect(steps[5], isA<PrayerStep>());
      final PrayerStep renewal = steps[5] as PrayerStep;
      expect(renewal.title, 'Daily Renewal of Consecration');
      expect(renewal.text.id, 'daily-renewal');

      // Terminal step: the Act of Consecration, referenced by a prayer
      // step at the very end of the session. The app renders it on day 34
      // only - the day-34 variant's actOfConsecration flag governs; for
      // days 1-33 the flag is absent and the app skips the step.
      expect(steps[6], isA<PrayerStep>());
      final PrayerStep act = steps[6] as PrayerStep;
      expect(act.title, 'Act of Consecration (consecration day)');
      expect(act.text.id, 'act-of-consecration');
      expect(steps.last, same(act));

      // No day substitution in the session script itself besides the
      // reflection prompt's single {{day}}.
      expect(
        p.content['daily-reading-prompt']!.text,
        "Day {{day}} of the 33-day preparation — read today's assigned "
        "pages (see the day's variant for the reading title and daily "
        'prompt).',
      );
    });

    test('every contentRef resolves into the content map', () {
      final ContentPack p = pack();
      int referencedTexts = 0;
      for (final SessionStep step in p.session.steps) {
        switch (step) {
          case PrayerStep(:final PrayerText text):
            expect(p.content[text.id], text, reason: text.id);
            referencedTexts++;
          case ReflectionStep(:final PrayerText? text):
            expect(p.content[text!.id], text, reason: text.id);
            referencedTexts++;
          case VerseStep():
            continue;
          default:
            fail('unexpected step type ${step.runtimeType}');
        }
      }
      // Come Holy Spirit, Veni Creator, Ave Maris Stella, Magnificat,
      // the daily prompt (reflection), the renewal, the act.
      expect(referencedTexts, 7);
      // The content map carries exactly the seven session texts.
      expect(p.content.keys, <String>{
        'come-holy-spirit',
        'veni-creator-spiritus',
        'ave-maris-stella',
        'magnificat',
        'daily-reading-prompt',
        'daily-renewal',
        'act-of-consecration',
      });
    });

    test('texts attributed: PD de-Montfort sources and licenses', () {
      final ContentPack p = pack();

      const String montfortSource =
          'St. Louis de Montfort, True Devotion to Mary / Secret of Mary '
          '(public-domain English translations)';
      const String license = 'public-domain';

      // Every text carries a non-empty source and license.
      for (final PrayerText entry in p.content.values) {
        expect(entry.source, isNotEmpty, reason: entry.id);
        expect(entry.license, license, reason: entry.id);
      }

      // The de-Montfort-preparation texts carry the pack's blanket
      // de Montfort source verbatim.
      for (final String key in <String>[
        'daily-reading-prompt',
        'act-of-consecration',
      ]) {
        expect(p.content[key]!.source, montfortSource, reason: key);
      }

      // The daily renewal line is pinned to its exact section source.
      expect(
        p.content['daily-renewal']!.source,
        'True Devotion to Mary, '
        '§233',
      );
      expect(
        p.content['daily-renewal']!.text,
        'I am all yours and all I have is yours, O dear Jesus, through '
        'Mary, your holy Mother.',
      );

      // The traditional Roman prayers the preparation prescribes carry the
      // repository-wide attribution convention.
      for (final String key in <String>[
        'come-holy-spirit',
        'veni-creator-spiritus',
        'ave-maris-stella',
        'magnificat',
      ]) {
        expect(
          p.content[key]!.source,
          'Traditional Roman devotion',
          reason: key,
        );
        expect(p.content[key]!.license, license, reason: key);
      }

      // The Come Holy Spirit opening: antiphon, versicle exchange, and
      // collect, vernacular with Latin rendering.
      final String opening = p.content['come-holy-spirit']!.text;
      expect(
        opening,
        startsWith(
          'Come, O Holy Spirit, fill the hearts of Thy faithful, and '
          'kindle in them the fire of Thy love.',
        ),
      );
      expect(
        opening,
        contains(
          'V. Send forth Your Spirit, and they shall '
          'be created.',
        ),
      );
      expect(opening, endsWith('Through Christ our Lord. Amen.'));
      expect(
        p.content['come-holy-spirit']!.latin,
        startsWith('Veni, Sancte Spiritus'),
      );

      // The Act of Consecration is the de Montfort formula itself (True
      // Devotion §§225-233): the baptismal-vow renewal and the total
      // gift of self.
      final String act = p.content['act-of-consecration']!.text;
      expect(act, isNotEmpty);
      expect(act, contains('O Eternal and Incarnate Wisdom'));
      expect(
        act,
        contains(
          'I give myself entirely to Jesus Christ, the Incarnate Wisdom, '
          'to carry my cross',
        ),
      );
      expect(
        act,
        contains('I choose thee this day for my Mother and Mistress.'),
      );
      expect(
        act,
        contains(
          'I deliver and consecrate to thee, as thy slave, my body and '
          'soul',
        ),
      );
    });

    test('round trip: schedule, feastAnchor, variants, and session '
        'survive serialization', () {
      final ContentPack p = pack();
      final Map<String, dynamic> json = p.toJson();

      // The sessionSeries schedule round-trips to its exact dispatch JSON.
      expect(json['schedule'], <String, dynamic>{
        'type': 'sessionSeries',
        'startDate': '2027-02-20',
        'lengthDays': 34,
      });
      expect(json['variants'], hasLength(34));
      expect(
        json['content']['daily-renewal']['source'],
        'True Devotion to Mary, §233',
      );

      final ContentPack reloaded = PackLoader.load(json);
      expect(reloaded.schedules.single, isA<SessionSeriesSpec>());
      final SessionSeriesSpec series =
          reloaded.schedules.single as SessionSeriesSpec;
      expect(series.startDate, DateTime(2027, 2, 20));
      expect(series.lengthDays, 34);
      expect(reloaded.variants, hasLength(34));
      expect(reloaded.session.steps, hasLength(7));
      final Map<String, dynamic> day34 = reloaded.variants.last;
      expect(day34['id'], 'day-34');
      expect(day34['phase'], 'consecration');
      expect(day34['actOfConsecration'], isTrue);
      expect(reloaded.reminders['feastAnchor']['feast'], 'annunciation');
    });

    test('PackValidator passes for fixture year 2027 '
        '(and the absolute start keeps other years empty)', () {
      // The series starts 2027-02-20: the sweep must find due dates in
      // 2027 and none in 2028 (the start date is pinned, not recomputed).
      expect(PackValidator.problems(pack(), 2027), isEmpty);
      expect(PackValidator.problems(pack(), 2028), hasLength(1));
      expect(
        PackValidator.problems(pack(), 2028).single,
        contains('zero due dates in 2028'),
      );
    });
  });
}
