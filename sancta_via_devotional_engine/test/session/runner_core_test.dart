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

  final SessionScript script = SessionScript(
    id: 'sample-session',
    steps: <SessionStep>[
      PrayerStep(id: 'opening-prayer', title: 'Opening prayer', text: memorare),
      VerseStep(
        id: 'versicle',
        versicle: 'Lord, open my lips.',
        response: 'And my mouth shall proclaim your praise.',
        closing: memorare,
      ),
      const ReflectionStep(
        id: 'reflection',
        title: 'Meditation',
        duration: Duration(minutes: 15),
      ),
      const CheckpointStep(
        id: 'communion',
        title: 'Communion',
        item: 'communion',
        requiredForCompletion: true,
      ),
      IntercessionStep(
        id: 'intentions',
        prompt: 'For the intentions of the Holy Father',
      ),
    ],
  );

  group('SessionScript', () {
    test('throws ArgumentError mentioning steps when steps are empty', () {
      expect(
        () => SessionScript(id: 'empty-session', steps: <SessionStep>[]),
        throwsA(
          isA<ArgumentError>().having(
            (ArgumentError e) => e.message,
            'message',
            contains('steps'),
          ),
        ),
      );
    });

    test('steps is unmodifiable at the consumer surface', () {
      expect(
        () => script.steps.add(
          IntercessionStep(id: 'late-addition', prompt: 'must not appear'),
        ),
        throwsUnsupportedError,
        reason: 'steps is backed by an unmodifiable list',
      );
    });

    test('steps does not alias the caller-supplied list', () {
      final List<SessionStep> callerList = <SessionStep>[
        PrayerStep(
          id: 'opening-prayer',
          title: 'Opening prayer',
          text: memorare,
        ),
      ];
      final SessionScript local = SessionScript(
        id: 'no-aliasing',
        steps: callerList,
      );
      expect(local.steps.length, equals(1));

      // Mutating the input list after construction must not change steps.
      callerList.add(
        IntercessionStep(id: 'late-addition', prompt: 'must not appear'),
      );

      expect(local.steps.length, equals(1));
      expect(local.steps.first.id, equals('opening-prayer'));
    });
  });

  group('SessionRunner', () {
    test('forState starts fresh: stepIndex 0, not complete', () {
      final SessionState state = SessionRunner.forState(script);

      expect(state.scriptId, equals('sample-session'));
      expect(state.stepIndex, equals(0));
      expect(state.isComplete, isFalse);
      expect(state.recordedCounts, isEmpty);
      expect(state.completedAt, isEmpty);
    });

    test('completing steps 1..N marks completedAt and ends complete', () {
      SessionState state = SessionRunner.forState(script);

      for (int i = 0; i < script.steps.length; i++) {
        expect(state.stepIndex, equals(i));
        expect(state.isComplete, isFalse);
        expect(state.completedAt.containsKey(i), isFalse);

        state = SessionRunner.completeCurrent(state);

        // The just-completed step carries a completion timestamp.
        expect(state.completedAt[i], isNotNull);
      }

      expect(state.stepIndex, equals(script.steps.length));
      expect(state.isComplete, isTrue);
      expect(state.completedAt.length, equals(script.steps.length));
    });

    test('record accumulates into the current step counter only', () {
      SessionState state = SessionRunner.forState(script);
      // Advance past the prayer and verse steps to the reflection (index 2).
      state = SessionRunner.completeCurrent(state);
      state = SessionRunner.completeCurrent(state);

      expect(state.stepIndex, equals(2));

      state = SessionRunner.record(state, 1);
      expect(state.recordedCounts[2], equals(1));

      state = SessionRunner.record(state, 2);
      expect(state.recordedCounts[2], equals(3));
      expect(state.recordedCounts.keys, equals(<int>[2]));

      // Completing does not disturb the recorded counts.
      state = SessionRunner.completeCurrent(state);
      expect(state.stepIndex, equals(3));
      expect(state.recordedCounts[2], equals(3));
    });

    test('completeCurrent throws StateError when already complete', () {
      SessionState state = SessionRunner.forState(script);
      for (int i = 0; i < script.steps.length; i++) {
        state = SessionRunner.completeCurrent(state);
      }
      expect(state.isComplete, isTrue);

      expect(() => SessionRunner.completeCurrent(state), throwsStateError);
    });

    test('record throws StateError when already complete', () {
      SessionState state = SessionRunner.forState(script);
      for (int i = 0; i < script.steps.length; i++) {
        state = SessionRunner.completeCurrent(state);
      }
      expect(state.isComplete, isTrue);

      expect(() => SessionRunner.record(state, 1), throwsStateError);
    });

    test('fromJson(toJson(state)) round-trips a mid-session state', () {
      SessionState state = SessionRunner.forState(script);
      state = SessionRunner.record(state, 1);
      state = SessionRunner.record(state, 2);
      state = SessionRunner.completeCurrent(state);
      state = SessionRunner.completeCurrent(state);

      final SessionState resumed = SessionState.fromJson(state.toJson());

      expect(resumed.scriptId, equals(state.scriptId));
      expect(resumed.stepIndex, equals(state.stepIndex));
      expect(resumed.isComplete, equals(state.isComplete));
      expect(resumed.recordedCounts, equals(state.recordedCounts));
      expect(resumed.completedAt.keys, equals(state.completedAt.keys));
      expect(
        resumed.completedAt[0],
        equals(state.completedAt[0]),
        reason: 'completion timestamps survive the resume round-trip',
      );
      expect(resumed.completedAt[1], equals(state.completedAt[1]));
    });

    test('fromJson(toJson(state)) round-trips completion of the last step', () {
      SessionState state = SessionRunner.forState(script);
      state = SessionRunner.record(state, 4);
      for (int i = 0; i < script.steps.length; i++) {
        state = SessionRunner.completeCurrent(state);
      }
      expect(state.isComplete, isTrue);

      final SessionState resumed = SessionState.fromJson(state.toJson());

      expect(resumed.stepIndex, equals(script.steps.length));
      expect(resumed.isComplete, isTrue);
      expect(resumed.recordedCounts[0], equals(4));
      expect(resumed.completedAt.length, equals(script.steps.length));

      // The resumed state knows the session is over.
      expect(() => SessionRunner.completeCurrent(resumed), throwsStateError);
    });

    test('forState and transitions do not expose mutable session state', () {
      final SessionState fresh = SessionRunner.forState(script);
      expect(
        () => fresh.recordedCounts[0] = 5,
        throwsUnsupportedError,
        reason: 'recordedCounts is an unmodifiable view',
      );
      expect(
        () => fresh.completedAt[0] = DateTime.now(),
        throwsUnsupportedError,
        reason: 'completedAt is an unmodifiable view',
      );
    });
  });
}
