import 'package:sancta_via_devotional_engine/sancta_via_devotional_engine.dart';
import 'package:test/test.dart';

void main() {
  final PrayerText memorare = PrayerText(
    id: 'memorare',
    text: 'Remember, O most gracious Virgin Mary...',
    latin: 'Memorare, O piissima Virgo Maria...',
    source: 'Traditional',
    license: 'public-domain',
  );

  group('step validation', () {
    test('RepetitionStep throws ArgumentError when count is below 1', () {
      expect(
        () => RepetitionStep(id: 'bad-repetition', text: memorare, count: 0),
        throwsA(
          isA<ArgumentError>().having(
            (ArgumentError e) => e.message,
            'message',
            contains('count'),
          ),
        ),
      );
    });

    test(
      'BeadGroupStep throws ArgumentError when hailMaryCount is below 1',
      () {
        expect(
          () => BeadGroupStep(
            id: 'bad-bead-group',
            hailMaryCount: 0,
            includeFatimaPrayer: false,
          ),
          throwsA(
            isA<ArgumentError>().having(
              (ArgumentError e) => e.message,
              'message',
              contains('hailMaryCount'),
            ),
          ),
        );
      },
    );

    test('BeadGroupStep accepts chaplet counts other than ten', () {
      final BeadGroupStep chapletGroup = BeadGroupStep(
        id: 'chaplet-beads',
        title: 'Chaplet of Divine Mercy beads',
        hailMaryCount: 3,
        includeFatimaPrayer: false,
      );
      expect(chapletGroup.hailMaryCount, equals(3));
    });

    test('LitanyStep throws ArgumentError when invocations are empty', () {
      expect(
        () => LitanyStep(
          id: 'bad-litany',
          invocations: <String>[],
          response: 'Pray for us.',
          groupedResponse: true,
        ),
        throwsA(
          isA<ArgumentError>().having(
            (ArgumentError e) => e.message,
            'message',
            contains('invocations'),
          ),
        ),
      );
    });
  });

  group('RepetitionStep in SessionRunner', () {
    final SessionScript rosaryRepetition = SessionScript(
      id: 'rosary-repetition',
      steps: <SessionStep>[
        RepetitionStep(
          id: 'litany-repetition',
          title: 'Litany repetition',
          text: memorare,
          count: 15,
        ),
      ],
    );

    test('14 of 15 records block completion, the 15th advances', () {
      SessionState state = SessionRunner.forState(rosaryRepetition);

      for (int i = 0; i < 14; i++) {
        state = SessionRunner.record(state, 1);
      }
      expect(state.stepIndex, equals(0));
      expect(state.recordedCounts[0], equals(14));

      // The target is not reached yet: completion is refused and the state
      // it refused to move stays untouched.
      expect(
        () => SessionRunner.completeCurrent(state, script: rosaryRepetition),
        throwsStateError,
      );
      expect(state.stepIndex, equals(0));
      expect(state.recordedCounts[0], equals(14));
      expect(state.completedAt, isEmpty);

      // The 15th record reaches the target and completion advances.
      state = SessionRunner.record(state, 1);
      expect(state.recordedCounts[0], equals(15));

      state = SessionRunner.completeCurrent(state, script: rosaryRepetition);
      expect(state.stepIndex, equals(1));
      expect(state.isComplete, isTrue);
      expect(state.completedAt[0], isNotNull);
    });

    test('a record reaching the count in one call suffices', () {
      SessionState state = SessionRunner.forState(rosaryRepetition);

      state = SessionRunner.record(state, 15);
      state = SessionRunner.completeCurrent(state, script: rosaryRepetition);

      expect(state.isComplete, isTrue);
    });

    test('without a script the target check is best-effort', () {
      SessionState state = SessionRunner.forState(rosaryRepetition);

      state = SessionRunner.record(state, 4);
      state = SessionRunner.completeCurrent(state);

      expect(state.isComplete, isTrue);
    });
  });

  group('LitanyStep in SessionRunner', () {
    final SessionScript holyName = SessionScript(
      id: 'litany-of-the-holy-name',
      steps: <SessionStep>[
        LitanyStep(
          id: 'holy-name-invocations',
          title: 'Litany of the Holy Name',
          invocations: <String>[
            'God, come to my assistance.',
            'Lord, make haste to help me.',
            'Jesus, hear us.',
            'Jesus, graciously hear us.',
            'Lamb of God, you take away the sins of the world.',
          ],
          response: 'Spare us, O Lord.',
          groupedResponse: true,
        ),
      ],
    );

    test('completes in one action, no records needed', () {
      SessionState state = SessionRunner.forState(holyName);

      state = SessionRunner.completeCurrent(state, script: holyName);

      expect(state.stepIndex, equals(1));
      expect(state.isComplete, isTrue);
      expect(state.completedAt[0], isNotNull);
      expect(state.recordedCounts, isEmpty);
    });

    test(
      'invocations, response, and groupedResponse are data for the app layer',
      () {
        final LitanyStep litany = holyName.steps.first as LitanyStep;

        expect(litany.invocations.length, equals(5));
        expect(litany.response, equals('Spare us, O Lord.'));
        expect(litany.groupedResponse, isTrue);
      },
    );

    test('invocations is unmodifiable at the consumer surface', () {
      final LitanyStep litany = holyName.steps.first as LitanyStep;

      expect(
        () => litany.invocations.add('late invocation'),
        throwsUnsupportedError,
        reason: 'invocations is backed by an unmodifiable list',
      );
    });
  });

  group('BeadGroupStep in SessionRunner', () {
    final SessionScript annunciationDecade = SessionScript(
      id: 'rosary-decade',
      steps: <SessionStep>[
        BeadGroupStep(
          id: 'decade-the-annunciation',
          title: 'First decade',
          mysteryTitle: 'The Annunciation',
          mysteryFruit: 'Humility',
          hailMaryCount: 10,
          includeFatimaPrayer: true,
        ),
      ],
    );

    test('completing before any beads is blocked', () {
      final SessionState state = SessionRunner.forState(annunciationDecade);

      expect(
        () => SessionRunner.completeCurrent(state, script: annunciationDecade),
        throwsStateError,
      );
    });

    test('records decade count 10 then advances', () {
      SessionState state = SessionRunner.forState(annunciationDecade);

      for (int i = 0; i < 10; i++) {
        state = SessionRunner.record(state, 1);
      }
      expect(state.stepIndex, equals(0));
      expect(state.recordedCounts[0], equals(10));

      state = SessionRunner.completeCurrent(state, script: annunciationDecade);

      expect(state.stepIndex, equals(1));
      expect(state.isComplete, isTrue);
      expect(state.recordedCounts[0], equals(10));
      expect(state.completedAt[0], isNotNull);
    });

    test('a record reaching hailMaryCount in one call suffices', () {
      SessionState state = SessionRunner.forState(annunciationDecade);

      state = SessionRunner.record(state, 10);
      state = SessionRunner.completeCurrent(state, script: annunciationDecade);

      expect(state.isComplete, isTrue);
    });

    test('without a script the target check is best-effort', () {
      SessionState state = SessionRunner.forState(annunciationDecade);

      state = SessionRunner.record(state, 2);
      state = SessionRunner.completeCurrent(state);

      expect(state.isComplete, isTrue);
    });

    test(
      'mystery and Fatima flags are step data, carried without state machinery',
      () {
        final BeadGroupStep decade =
            annunciationDecade.steps.first as BeadGroupStep;

        expect(decade.mysteryTitle, equals('The Annunciation'));
        expect(decade.mysteryFruit, equals('Humility'));
        expect(decade.hailMaryCount, equals(10));
        expect(decade.includeFatimaPrayer, isTrue);
      },
    );
  });

  group('a mixed script walk', () {
    final SessionScript walk = SessionScript(
      id: 'mixed-walk',
      steps: <SessionStep>[
        PrayerStep(
          id: 'opening-prayer',
          title: 'Opening prayer',
          text: memorare,
        ),
        BeadGroupStep(
          id: 'first-decade',
          mysteryTitle: 'The Annunciation',
          mysteryFruit: 'Humility',
          hailMaryCount: 10,
          includeFatimaPrayer: true,
        ),
        RepetitionStep(
          id: 'repetition',
          title: 'Repetition',
          text: memorare,
          count: 3,
        ),
        LitanyStep(
          id: 'litany',
          invocations: <String>['Saint Michael, pray for us.'],
          response: 'Pray for us.',
          groupedResponse: false,
        ),
      ],
    );

    test(
      'target steps enforce their count, target-free steps complete directly',
      () {
        SessionState state = SessionRunner.forState(walk);

        // Step 0 is a target-free prayer: one completion advances.
        state = SessionRunner.completeCurrent(state, script: walk);
        expect(state.stepIndex, equals(1));

        // Step 1 is the bead group: not a bead recorded yet, blocked.
        expect(
          () => SessionRunner.completeCurrent(state, script: walk),
          throwsStateError,
        );
        state = SessionRunner.record(state, 10);
        state = SessionRunner.completeCurrent(state, script: walk);
        expect(state.stepIndex, equals(2));

        // Step 2 is the repetition: below its count, blocked.
        expect(
          () => SessionRunner.completeCurrent(state, script: walk),
          throwsStateError,
        );
        state = SessionRunner.record(state, 2);
        expect(
          () => SessionRunner.completeCurrent(state, script: walk),
          throwsStateError,
        );
        state = SessionRunner.record(state, 1);
        state = SessionRunner.completeCurrent(state, script: walk);
        expect(state.stepIndex, equals(3));

        // Step 3 is the litany: completes in one action.
        state = SessionRunner.completeCurrent(state, script: walk);
        expect(state.isComplete, isTrue);
      },
    );
  });
}
