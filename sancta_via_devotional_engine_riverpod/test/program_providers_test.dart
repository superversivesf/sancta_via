import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sancta_via_devotional_engine_riverpod/sancta_via_devotional_engine_riverpod.dart';
import 'package:sancta_via_liturgical_calendar_riverpod/sancta_via_liturgical_calendar_riverpod.dart';

/// The first Saturday of December 2026, in Advent.
final DateTime firstSaturday2026 = DateTime(2026, 12, 5);

/// The first Friday of December 2026.
final DateTime firstFriday2026 = DateTime(2026, 12, 4);

/// A minimal hand-built pack, so repository tests need not depend on the
/// embedded fixture set.
ContentPack bedtimePack() {
  return ContentPack(
    id: 'bedtime_prayers',
    title: 'Bedtime Prayers',
    family: PackFamily.routine,
    schedule: TimeOfDaySpec(21, 0, baseLabel: 'bedtime'),
    session: SessionScript(
      id: 'bedtime-session',
      steps: <SessionStep>[
        PrayerStep(
          id: 'memorare',
          text: PrayerText(
            id: 'memorare',
            text: 'Remember, O most gracious Virgin Mary...',
            source: 'Traditional',
            license: 'public-domain',
          ),
        ),
      ],
    ),
  );
}

void main() {
  group('InMemoryProgramRepository', () {
    test('loadPacks ships the engine fixture set in fixture order', () async {
      final InMemoryProgramRepository repository = InMemoryProgramRepository();
      final List<ContentPack> packs = await repository.loadPacks();

      expect(packs, hasLength(8));
      expect(
        packs.map((ContentPack pack) => pack.id).toList(),
        equals(<String>[
          'angelus',
          'divine_mercy_novena',
          'five_first_saturdays',
          'mercy_hour',
          'nine_first_fridays',
          'novena_54_day',
          'rosary',
          'total_consecration',
        ]),
        reason:
            'the embedded packs mirror the engine fixture packs, embedded '
            'in sorted filename order',
      );
    });

    test('accepts injected packs alongside progress and enrollment', () async {
      final InMemoryProgramRepository repository = InMemoryProgramRepository(
        packs: <ContentPack>[bedtimePack()],
      );

      expect((await repository.loadPacks()).single.id, 'bedtime_prayers');
      expect(await repository.progressFor('bedtime_prayers'), isNull);

      await repository.saveProgress(
        ProgressState(packId: 'bedtime_prayers', fulfilledOrdinals: 1),
      );
      expect(
        await repository.progressFor('bedtime_prayers'),
        isA<ProgressState>().having(
          (ProgressState state) => state.fulfilledOrdinals,
          'fulfilledOrdinals',
          1,
        ),
      );

      await repository.enroll('bedtime_prayers', <String, dynamic>{
        'startedAt': '2026-12-05',
      });
      expect(
        repository.enrollmentParams['bedtime_prayers']!['startedAt'],
        '2026-12-05',
      );
    });

    test(
      'progressFor reads back the exact state saveProgress stored',
      () async {
        final InMemoryProgramRepository repository =
            InMemoryProgramRepository();
        final ProgressState state = ProgressState(
          packId: 'five_first_saturdays',
          fulfilledOrdinals: 3,
          lastFulfilled: DateTime(2026, 11, 7),
        );

        expect(await repository.progressFor('five_first_saturdays'), isNull);
        await repository.saveProgress(state);
        expect(
          await repository.progressFor('five_first_saturdays'),
          same(state),
        );
      },
    );

    test('write seams reject unknown packs', () async {
      final InMemoryProgramRepository repository = InMemoryProgramRepository();

      expect(
        repository.saveProgress(ProgressState(packId: 'not_a_pack')),
        throwsArgumentError,
      );
      expect(
        repository.enroll('not_a_pack', <String, dynamic>{}),
        throwsArgumentError,
      );
    });

    test('enrollment params stay opaque through storage', () async {
      final InMemoryProgramRepository repository = InMemoryProgramRepository();
      final Map<String, dynamic> params = <String, dynamic>{
        'startDate': '2027-02-20',
        'feastAnchor': <String, dynamic>{
          'date': <String, dynamic>{'month': 3, 'day': 25},
        },
      };

      await repository.enroll('total_consecration', params);

      expect(repository.enrollmentParams['total_consecration'], equals(params));
    });
  });

  group('program providers', () {
    /// A container with [repository] wired in and the sibling
    /// [currentDateProvider] overridden to [date] — the test-override
    /// pattern the workspace's date providers support (the real
    /// provider's periodic timer never completes inside a test).
    ProviderContainer containerFor(
      ProgramRepository repository,
      DateTime date,
    ) {
      return ProviderContainer(
        overrides: <Override>[
          currentDateProvider.overrideWith(
            (ref) => Stream<DateTime>.value(date),
          ),
          programRepositoryProvider.overrideWithValue(repository),
        ],
      );
    }

    test(
      'enrolledProgramsProvider pairs every pack with its progress',
      () async {
        final InMemoryProgramRepository repository =
            InMemoryProgramRepository();
        await repository.saveProgress(ProgressState(packId: 'rosary'));

        final ProviderContainer container = containerFor(
          repository,
          firstSaturday2026,
        );
        addTearDown(container.dispose);

        final List<EnrolledProgram> programs = await container.read(
          enrolledProgramsProvider.future,
        );

        expect(programs, hasLength(8));
        final Map<String, ProgressState?> progressById =
            <String, ProgressState?>{
              for (final EnrolledProgram program in programs)
                program.pack.id: program.progress,
            };
        expect(progressById['rosary'], isA<ProgressState>());
        expect(progressById['angelus'], isNull);
      },
    );

    test('todayProgramsProvider marks Five First Saturdays due with ordinal 1 '
        'on the first Saturday', () async {
      final InMemoryProgramRepository repository = InMemoryProgramRepository();
      await repository.saveProgress(
        ProgressState(packId: 'five_first_saturdays'),
      );

      final ProviderContainer container = containerFor(
        repository,
        firstSaturday2026,
      );
      addTearDown(container.dispose);

      final List<DueToday> due = await container.read(
        todayProgramsProvider.future,
      );

      expect(
        due.map((DueToday program) => program.pack.id).toList(),
        equals(<String>[
          'angelus',
          'five_first_saturdays',
          'mercy_hour',
          'novena_54_day',
          'rosary',
        ]),
        reason:
            '2026-12-05: the daily anchors and the rosary are due every '
            'day, the 54-day novena is inside its series, and the first '
            'Saturday is a Five First Saturdays anchor; the Easter '
            'novena, the first Friday, and the consecration series are '
            'not due',
      );

      final DueToday firstSaturdays = due.firstWhere(
        (DueToday program) => program.pack.id == 'five_first_saturdays',
      );
      expect(firstSaturdays.schedule.due, isTrue);
      expect(
        firstSaturdays.schedule.ordinal,
        equals(1),
        reason: 'progress 0: today takes the first commitment position',
      );
    });

    test(
      'todayProgramsProvider wires the liturgical season into resolution',
      () async {
        final InMemoryProgramRepository repository =
            InMemoryProgramRepository();

        final ProviderContainer container = containerFor(
          repository,
          firstSaturday2026,
        );
        addTearDown(container.dispose);

        final List<DueToday> due = await container.read(
          todayProgramsProvider.future,
        );

        // 2026-12-05 falls in Advent, so the Angelus pack keeps its base
        // label (only the Easter season selects Regina Caeli), and a
        // routine pack carries no commitment ordinal.
        final DueToday angelus = due.firstWhere(
          (DueToday program) => program.pack.id == 'angelus',
        );
        expect(angelus.schedule.labels, equals(<String>['angelus']));
        expect(angelus.schedule.ordinal, isNull);

        final DueToday mercyHour = due.firstWhere(
          (DueToday program) => program.pack.id == 'mercy_hour',
        );
        expect(mercyHour.schedule.labels, equals(<String>['mercy_hour']));
      },
    );

    test('todayProgramsProvider carries the series day index', () async {
      final InMemoryProgramRepository repository = InMemoryProgramRepository();

      final ProviderContainer container = containerFor(
        repository,
        firstSaturday2026,
      );
      addTearDown(container.dispose);

      final List<DueToday> due = await container.read(
        todayProgramsProvider.future,
      );

      // The 54-day novena began 2026-11-10; 2026-12-05 is its 26th day.
      final DueToday novena = due.firstWhere(
        (DueToday program) => program.pack.id == 'novena_54_day',
      );
      expect(novena.schedule.dayIndex, equals(26));
    });

    test(
      'todayProgramsProvider follows the overridden date onto the first Friday',
      () async {
        final InMemoryProgramRepository repository =
            InMemoryProgramRepository();

        final ProviderContainer container = containerFor(
          repository,
          firstFriday2026,
        );
        addTearDown(container.dispose);

        final List<DueToday> due = await container.read(
          todayProgramsProvider.future,
        );

        expect(
          due.map((DueToday program) => program.pack.id).toList(),
          equals(<String>[
            'angelus',
            'mercy_hour',
            'nine_first_fridays',
            'novena_54_day',
            'rosary',
          ]),
          reason:
              '2026-12-04: the first Friday is a Nine First Fridays anchor '
              'and the first Saturday is not',
        );

        final DueToday firstFridays = due.firstWhere(
          (DueToday program) => program.pack.id == 'nine_first_fridays',
        );
        expect(firstFridays.schedule.ordinal, equals(1));
      },
    );

    test(
      'todayProgramsProvider selects the Easter-season Angelus variant',
      () async {
        final InMemoryProgramRepository repository =
            InMemoryProgramRepository();

        // 2026-04-10 falls in the Easter season: the Angelus pack's season
        // variant selects Regina Caeli through the schedule context.
        final ProviderContainer container = containerFor(
          repository,
          DateTime(2026, 4, 10),
        );
        addTearDown(container.dispose);

        final List<DueToday> due = await container.read(
          todayProgramsProvider.future,
        );

        final DueToday angelus = due.firstWhere(
          (DueToday program) => program.pack.id == 'angelus',
        );
        expect(angelus.schedule.labels, equals(<String>['regina_caeli']));

        // Easter Sunday 2026 was April 5; the novena window opened two
        // days earlier, so April 10 is its eighth day.
        final DueToday divineMercy = due.firstWhere(
          (DueToday program) => program.pack.id == 'divine_mercy_novena',
        );
        expect(divineMercy.schedule.dayIndex, equals(8));
      },
    );

    test(
      'programDetailProvider surfaces commitment policy and projection',
      () async {
        final InMemoryProgramRepository repository =
            InMemoryProgramRepository();
        await repository.saveProgress(
          ProgressState(packId: 'five_first_saturdays'),
        );

        final ProviderContainer container = containerFor(
          repository,
          firstSaturday2026,
        );
        addTearDown(container.dispose);

        final ProgramDetail detail = await container.read(
          programDetailProvider('five_first_saturdays').future,
        );

        expect(detail.pack.id, 'five_first_saturdays');
        expect(detail.progress, isA<ProgressState>());
        expect(detail.restartPolicy, equals('strict'));
        expect(
          detail.remainingDates,
          equals(<DateTime>[
            DateTime(2026, 12, 5),
            DateTime(2027, 1, 2),
            DateTime(2027, 2, 6),
            DateTime(2027, 3, 6),
            DateTime(2027, 4, 3),
          ]),
          reason:
              'with no ordinals fulfilled, the projection lists the next '
              'five first Saturdays from today inclusive',
        );
      },
    );

    test(
      'programDetailProvider carries no commitment data for non-commitment packs',
      () async {
        final InMemoryProgramRepository repository =
            InMemoryProgramRepository();

        final ProviderContainer container = containerFor(
          repository,
          firstSaturday2026,
        );
        addTearDown(container.dispose);

        final ProgramDetail detail = await container.read(
          programDetailProvider('angelus').future,
        );

        expect(detail.pack.id, 'angelus');
        expect(detail.restartPolicy, isNull);
        expect(detail.remainingDates, isEmpty);
      },
    );

    test('programDetailProvider rejects unknown pack ids', () async {
      final InMemoryProgramRepository repository = InMemoryProgramRepository();

      final ProviderContainer container = containerFor(
        repository,
        firstSaturday2026,
      );
      addTearDown(container.dispose);

      await expectLater(
        container.read(programDetailProvider('not_a_pack').future),
        throwsA(isA<StateError>()),
      );
    });
  });
}
