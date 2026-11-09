import 'package:sancta_via_devotional_engine/sancta_via_devotional_engine.dart';
import 'package:test/test.dart';

/// Fixture directory the commitment packs live in (task 15); one pack per
/// devotion (task 14 ruling).
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

/// The first date in the given [year]/[month] on which the pack's
/// commitment [anchor] resolves as due — the resolved anchor date for that
/// month, walked out of the spec itself rather than assumed.
DateTime dueDayInMonth(ScheduleSpec anchor, int year, int month) {
  final int lastDay = DateTime(year, month + 1, 0).day;
  for (int day = 1; day <= lastDay; day++) {
    final DateTime d = DateTime(year, month, day);
    if (anchor.resolve(d, const ScheduleContext()).due) {
      return d;
    }
  }
  throw StateError('the anchor resolves to no due date in $year-$month');
}

void main() {
  group('nine first fridays pack', () {
    test('loads from the fixtures directory', () {
      final ContentPack pack = loadPack('nine_first_fridays');
      expect(pack.id, 'nine_first_fridays');
      expect(pack.family, PackFamily.commitment);
      expect(pack.title, isNotEmpty);
    });

    test('schedules nine strict commitments anchored to the first Friday', () {
      final ContentPack pack = loadPack('nine_first_fridays');
      expect(pack.schedules, hasLength(1));
      expect(pack.schedule, same(pack.schedules.first));
      expect(pack.schedules.single, isA<ConsecutiveCommitmentSpec>());
      final ConsecutiveCommitmentSpec commitment =
          pack.schedules.single as ConsecutiveCommitmentSpec;
      expect(commitment.count, 9);
      expect(commitment.policy, RestartPolicy.strict);
      expect(commitment.windows, isEmpty);
      expect(commitment.anchor, isA<NthWeekdayOfMonthSpec>());
      final NthWeekdayOfMonthSpec anchor =
          commitment.anchor as NthWeekdayOfMonthSpec;
      expect(anchor.weekday, DateTime.friday);
      expect(anchor.nth, 1);
    });

    test(
      'resolves 2027-01-01 — the New Year edge, first Friday of Jan 2027',
      () {
        final ContentPack pack = loadPack('nine_first_fridays');
        final ScheduleSpec anchor = pack.schedules.single;

        // January 1, 2027 is itself a Friday: the first Friday of the month
        // falls on New Year's Day, and the anchor must be due exactly there.
        expect(
          dueDayInMonth(anchor, 2027, DateTime.january),
          DateTime(2027, 1),
        );
        expect(
          anchor.resolve(DateTime(2027, 1, 1), const ScheduleContext()).due,
          isTrue,
        );
        // The second Friday of January 2027 is not an anchor.
        expect(
          anchor.resolve(DateTime(2027, 1, 8), const ScheduleContext()).due,
          isFalse,
        );
        // The commitment resolves wherever its anchor is due.
        expect(
          (pack.schedules.single as ConsecutiveCommitmentSpec)
              .resolve(DateTime(2027, 1, 1), const ScheduleContext())
              .due,
          isTrue,
        );
      },
    );

    test(
      'session: offering prayer, communion checkpoint, reparation prayer',
      () {
        final ContentPack pack = loadPack('nine_first_fridays');
        final List<SessionStep> steps = pack.session.steps;
        expect(pack.session.id, 'nine-first-fridays-session');
        expect(steps, hasLength(3));

        expect(steps[0], isA<PrayerStep>());
        final PrayerStep offering = steps[0] as PrayerStep;
        expect(offering.title, 'Act of Offering');
        expect(offering.text.id, 'nff_act_of_offering');

        expect(steps[1], isA<CheckpointStep>());
        final CheckpointStep communion = steps[1] as CheckpointStep;
        expect(communion.item, 'communion');
        expect(communion.requiredForCompletion, isTrue);

        expect(steps[2], isA<PrayerStep>());
        final PrayerStep reparation = steps[2] as PrayerStep;
        expect(reparation.title, 'Act of Reparation');
        expect(reparation.text.id, 'nff_act_of_reparation');

        // Exactly one checkpoint; nothing else.
        expect(
          steps.whereType<CheckpointStep>().map((CheckpointStep s) => s.item),
          <String>['communion'],
        );
      },
    );

    test('content: Sacred Heart texts attributed and traditional', () {
      final ContentPack pack = loadPack('nine_first_fridays');
      expect(
        pack.content.keys,
        containsAll(<String>['nff_act_of_offering', 'nff_act_of_reparation']),
      );
      for (final PrayerText entry in pack.content.values) {
        expect(
          entry.source,
          'Traditional Sacred Heart devotions (19th-century collections)',
          reason: entry.id,
        );
        expect(entry.license, 'public-domain', reason: entry.id);
      }
      expect(
        pack.content['nff_act_of_offering']!.text,
        contains('nine First Fridays'),
      );
      expect(
        pack.content['nff_act_of_reparation']!.text,
        contains('Heart of Jesus, offended by our sins, have mercy on us'),
      );
    });

    test('PackValidator passes for fixture year 2026', () {
      expect(
        PackValidator.problems(loadPack('nine_first_fridays'), 2026),
        isEmpty,
      );
    });
  });

  group('five first saturdays pack', () {
    test('loads from the fixtures directory', () {
      final ContentPack pack = loadPack('five_first_saturdays');
      expect(pack.id, 'five_first_saturdays');
      expect(pack.family, PackFamily.commitment);
      expect(pack.title, isNotEmpty);
    });

    test(
      'schedules five strict commitments with the confession grace window',
      () {
        final ContentPack pack = loadPack('five_first_saturdays');
        expect(pack.schedules, hasLength(1));
        expect(pack.schedule, same(pack.schedules.first));
        expect(pack.schedules.single, isA<ConsecutiveCommitmentSpec>());
        final ConsecutiveCommitmentSpec commitment =
            pack.schedules.single as ConsecutiveCommitmentSpec;
        expect(commitment.count, 5);
        expect(commitment.policy, RestartPolicy.strict);
        expect(commitment.anchor, isA<NthWeekdayOfMonthSpec>());
        final NthWeekdayOfMonthSpec anchor =
            commitment.anchor as NthWeekdayOfMonthSpec;
        expect(anchor.weekday, DateTime.saturday);
        expect(anchor.nth, 1);
        expect(commitment.windows, hasLength(1));
        final GraceWindow window = commitment.windows.single;
        expect(window.item, 'confession');
        expect(window.beforeDays, 8);
        expect(window.afterDays, 8);
      },
    );

    test(
      'grace window admits 2026-11-30 for anchor 2026-12-05, not 2026-11-20',
      () {
        final ContentPack pack = loadPack('five_first_saturdays');
        final ConsecutiveCommitmentSpec commitment =
            pack.schedules.single as ConsecutiveCommitmentSpec;
        final GraceWindow window = commitment.windows.single;

        // The resolved anchor date for 2026-12, walked out of the pack's
        // own NthWeekdayOfMonthSpec: the first Saturday of December 2026.
        final DateTime anchor = dueDayInMonth(commitment.anchor, 2026, 12);
        expect(anchor, DateTime(2026, 12, 5));

        // Confession five days before the First Saturday counts for it...
        expect(window.admits(anchor, DateTime(2026, 11, 30)), isTrue);
        // ...but fifteen days before is outside the eight-day window.
        expect(window.admits(anchor, DateTime(2026, 11, 20)), isFalse);
      },
    );

    test('evaluate: three consecutive completions give three ordinals, '
        'series not yet complete', () {
      final ContentPack pack = loadPack('five_first_saturdays');
      final ConsecutiveCommitmentSpec commitment =
          pack.schedules.single as ConsecutiveCommitmentSpec;

      final CommitmentState state = CommitmentState.evaluate(
        commitment,
        <DateTime>{
          DateTime(2026, 9, 5),
          DateTime(2026, 10, 3),
          DateTime(2026, 11, 7),
        },
        DateTime(2026, 11, 7),
      );
      expect(state.fulfilledOrdinals, 3);
      expect(state.count, 5);
      expect(state.isComplete, isFalse);
    });

    test('session: confession and communion checkpoints, five Joyful decades, '
        'fifteen-minute meditation', () {
      final ContentPack pack = loadPack('five_first_saturdays');
      final List<SessionStep> steps = pack.session.steps;
      expect(pack.session.id, 'five-first-saturdays-session');
      expect(steps, hasLength(8));

      // The confession checkpoint is not required for completion: it can
      // land in the grace window instead of the session itself.
      expect(steps[0], isA<CheckpointStep>());
      final CheckpointStep confession = steps[0] as CheckpointStep;
      expect(confession.item, 'confession');
      expect(confession.requiredForCompletion, isFalse);

      // Holy Communion, however, is essential to the devotion.
      expect(steps[1], isA<CheckpointStep>());
      final CheckpointStep communion = steps[1] as CheckpointStep;
      expect(communion.item, 'communion');
      expect(communion.requiredForCompletion, isTrue);

      // Five decades over the Joyful mysteries, in the Rosary's own order.
      final List<BeadGroupStep> decades = steps
          .whereType<BeadGroupStep>()
          .toList();
      expect(decades, hasLength(5));
      final List<String> mysteries = <String>[
        for (final BeadGroupStep decade in decades) decade.mysteryTitle!,
      ];
      expect(mysteries, <String>[
        'The Annunciation',
        'The Visitation',
        'The Nativity',
        'The Presentation',
        'The Finding in the Temple',
      ]);
      final List<String> fruits = <String>[
        for (final BeadGroupStep decade in decades) decade.mysteryFruit!,
      ];
      expect(fruits, <String>[
        'Humility',
        'Charity',
        'Poverty of spirit',
        'Obedience',
        'Seeking God',
      ]);
      for (final BeadGroupStep decade in decades) {
        expect(decade.hailMaryCount, 10, reason: decade.id);
        expect(decade.includeFatimaPrayer, isTrue, reason: decade.id);
      }
      // Decades occupy exactly steps 2..6 of the session, in order.
      for (int i = 2; i <= 6; i++) {
        expect(steps[i], isA<BeadGroupStep>(), reason: 'steps[$i]');
      }

      // The fifteen-minute meditation closes the session.
      expect(steps[7], isA<ReflectionStep>());
      final ReflectionStep meditation = steps[7] as ReflectionStep;
      expect(meditation.duration, const Duration(seconds: 900));
      expect(meditation.text, isNotNull);
      expect(meditation.text!.id, 'ffs_meditation');
    });

    test('content: the meditation prompt attributed to the Fatima request', () {
      final ContentPack pack = loadPack('five_first_saturdays');
      final PrayerText meditation = pack.content['ffs_meditation']!;
      expect(meditation.source, 'Fatima 1917 request');
      expect(
        meditation.license,
        "public-domain (Our Lady's First Saturday "
        'request)',
      );
      expect(meditation.text, contains('fifteen minutes'));
      expect(meditation.text, contains('reparation'));
      expect(pack.content.keys, contains('ffs_meditation'));
    });

    test('PackValidator passes for fixture year 2026', () {
      expect(
        PackValidator.problems(loadPack('five_first_saturdays'), 2026),
        isEmpty,
      );
    });
  });

  group('commitment packs fixture set', () {
    test('both devotions load as one commitment pack each', () {
      final List<ContentPack> packs = PackLoader.loadFixturesIn(fixtureDir);
      final Map<String, PackFamily> commitmentPacks = <String, PackFamily>{
        for (final ContentPack pack in packs)
          if (pack.family == PackFamily.commitment) pack.id: pack.family,
      };
      expect(
        commitmentPacks.keys,
        containsAll(<String>['nine_first_fridays', 'five_first_saturdays']),
      );
    });
  });
}
