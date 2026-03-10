import 'package:flutter_test/flutter_test.dart';
import 'package:rosary_companion/models/mystery_set.dart';
import 'package:rosary_companion/models/rosary_session.dart';

void main() {
  group('RosarySession Model', () {
    final testStartTime = DateTime(2025, 3, 9, 10, 0, 0);
    final testEndTime = DateTime(2025, 3, 9, 10, 30, 0);

    RosarySession createTestSession({
      String id = 'test-session-1',
      DateTime? startTime,
      DateTime? endTime,
      MysterySet mysterySet = MysterySet.joyful,
      List<int> mysteriesCompleted = const [],
      bool completed = false,
      int? currentPosition,
      int? currentMysteryNumber,
      int? currentHailMary,
      String? notes,
    }) {
      return RosarySession(
        id: id,
        startTime: startTime ?? testStartTime,
        endTime: endTime,
        mysterySet: mysterySet,
        mysteriesCompleted: mysteriesCompleted,
        completed: completed,
        currentPosition: currentPosition,
        currentMysteryNumber: currentMysteryNumber,
        currentHailMary: currentHailMary,
        notes: notes,
      );
    }

    group('Creation', () {
      test('can be created with required fields', () {
        final session = createTestSession();

        expect(session.id, equals('test-session-1'));
        expect(session.startTime, equals(testStartTime));
        expect(session.endTime, isNull);
        expect(session.mysterySet, equals(MysterySet.joyful));
        expect(session.mysteriesCompleted, isEmpty);
        expect(session.completed, isFalse);
        expect(session.currentPosition, isNull);
        expect(session.currentMysteryNumber, isNull);
        expect(session.currentHailMary, isNull);
        expect(session.notes, isNull);
      });

      test('can be created with all optional fields', () {
        final session = createTestSession(
          endTime: testEndTime,
          mysteriesCompleted: const [1, 2, 3],
          completed: true,
          currentPosition: 5,
          currentMysteryNumber: 3,
          currentHailMary: 7,
          notes: 'Test notes',
        );

        expect(session.endTime, equals(testEndTime));
        expect(session.mysteriesCompleted, equals(const [1, 2, 3]));
        expect(session.completed, isTrue);
        expect(session.currentPosition, equals(5));
        expect(session.currentMysteryNumber, equals(3));
        expect(session.currentHailMary, equals(7));
        expect(session.notes, equals('Test notes'));
      });

      test('createToday creates session for today', () {
        final beforeCreation = DateTime.now();
        final session = RosarySession.createToday(
          mysterySet: MysterySet.glorious,
        );
        final afterCreation = DateTime.now();

        expect(
          session.startTime.isAfter(beforeCreation) ||
              session.startTime.isAtSameMomentAs(beforeCreation),
          isTrue,
        );
        expect(
          session.startTime.isBefore(afterCreation) ||
              session.startTime.isAtSameMomentAs(afterCreation),
          isTrue,
        );
        expect(session.mysterySet, equals(MysterySet.glorious));
        expect(session.completed, isFalse);
        expect(session.endTime, isNull);
      });

      test('createToday uses custom id when provided', () {
        final session = RosarySession.createToday(id: 'custom-id');
        expect(session.id, equals('custom-id'));
      });

      test('createToday generates unique id when not provided', () {
        final session1 = RosarySession.createToday();
        final session2 = RosarySession.createToday();

        expect(session1.id, isNot(equals(session2.id)));
        expect(session1.id, isNotEmpty);
        expect(session2.id, isNotEmpty);
      });
    });

    group('JSON Serialization', () {
      test('serializes to JSON correctly', () {
        final session = createTestSession(
          endTime: testEndTime,
          mysteriesCompleted: const [1, 2],
          completed: true,
          notes: 'Session notes',
        );

        final json = session.toJson();

        expect(json['id'], equals('test-session-1'));
        expect(json['startTime'], equals(testStartTime.toIso8601String()));
        expect(json['endTime'], equals(testEndTime.toIso8601String()));
        expect(json['mysterySet'], equals('joyful'));
        expect(json['mysteriesCompleted'], equals([1, 2]));
        expect(json['completed'], isTrue);
        expect(json['notes'], equals('Session notes'));
      });

      test('serializes null values correctly', () {
        final session = createTestSession();
        final json = session.toJson();

        expect(json['endTime'], isNull);
        expect(json['currentPosition'], isNull);
        expect(json['currentMysteryNumber'], isNull);
        expect(json['currentHailMary'], isNull);
        expect(json['notes'], isNull);
      });

      test('deserializes from JSON correctly', () {
        final json = {
          'id': 'session-123',
          'startTime': '2025-03-09T15:30:00.000',
          'endTime': '2025-03-09T16:15:00.000',
          'mysterySet': 'sorrowful',
          'mysteriesCompleted': [1, 2, 3, 4, 5],
          'completed': true,
          'currentPosition': null,
          'currentMysteryNumber': null,
          'currentHailMary': null,
          'notes': 'Completed rosary',
        };

        final session = RosarySession.fromJson(json);

        expect(session.id, equals('session-123'));
        expect(session.startTime, equals(DateTime(2025, 3, 9, 15, 30)));
        expect(session.endTime, equals(DateTime(2025, 3, 9, 16, 15)));
        expect(session.mysterySet, equals(MysterySet.sorrowful));
        expect(session.mysteriesCompleted, equals([1, 2, 3, 4, 5]));
        expect(session.completed, isTrue);
        expect(session.notes, equals('Completed rosary'));
      });

      test('deserializes with null values', () {
        final json = {
          'id': 'session-456',
          'startTime': '2025-03-09T10:00:00.000',
          'endTime': null,
          'mysterySet': 'luminous',
          'mysteriesCompleted': null,
          'completed': false,
          'currentPosition': 10,
          'currentMysteryNumber': 2,
          'currentHailMary': 5,
          'notes': null,
        };

        final session = RosarySession.fromJson(json);

        expect(session.endTime, isNull);
        expect(session.mysteriesCompleted, isEmpty);
        expect(session.currentPosition, equals(10));
        expect(session.currentMysteryNumber, equals(2));
        expect(session.currentHailMary, equals(5));
        expect(session.notes, isNull);
      });

      test('round-trip serialization preserves data', () {
        final original = createTestSession(
          endTime: testEndTime,
          mysteriesCompleted: const [1, 2, 3],
          currentPosition: 15,
          currentMysteryNumber: 2,
          currentHailMary: 8,
          notes: 'Test notes',
        );

        final json = original.toJson();
        final restored = RosarySession.fromJson(json);

        expect(restored.id, equals(original.id));
        expect(restored.startTime, equals(original.startTime));
        expect(restored.endTime, equals(original.endTime));
        expect(restored.mysterySet, equals(original.mysterySet));
        expect(
          restored.mysteriesCompleted,
          equals(original.mysteriesCompleted),
        );
        expect(restored.completed, equals(original.completed));
        expect(restored.currentPosition, equals(original.currentPosition));
        expect(
          restored.currentMysteryNumber,
          equals(original.currentMysteryNumber),
        );
        expect(restored.currentHailMary, equals(original.currentHailMary));
        expect(restored.notes, equals(original.notes));
      });
    });

    group('Progress Tracking', () {
      test('completeMystery adds mystery to completed list', () {
        final session = createTestSession();
        final updated = session.completeMystery(1);

        expect(updated.mysteriesCompleted, contains(1));
        expect(updated.mysteriesCompleted.length, equals(1));
      });

      test('completeMystery does not duplicate mysteries', () {
        final session = createTestSession(mysteriesCompleted: const [1, 2]);
        final updated = session.completeMystery(2);

        expect(updated.mysteriesCompleted, equals([1, 2]));
      });

      test('completeMystery sorts completed mysteries', () {
        final session = createTestSession(mysteriesCompleted: const [3, 1]);
        final updated = session.completeMystery(2);

        expect(updated.mysteriesCompleted, equals([1, 2, 3]));
      });

      test('completeMystery clears current mystery and hail mary', () {
        final session = createTestSession(
          currentMysteryNumber: 2,
          currentHailMary: 5,
        );
        final updated = session.completeMystery(1);

        expect(updated.currentMysteryNumber, isNull);
        expect(updated.currentHailMary, isNull);
      });

      test('completeMystery validates mystery number', () {
        final session = createTestSession();

        expect(() => session.completeMystery(0), throwsArgumentError);
        expect(() => session.completeMystery(6), throwsArgumentError);
        expect(() => session.completeMystery(-1), throwsArgumentError);
      });

      test('updatePosition updates current position', () {
        final session = createTestSession();
        final updated = session.updatePosition(position: 10);

        expect(updated.currentPosition, equals(10));
      });

      test('updatePosition can include mystery and hail mary', () {
        final session = createTestSession();
        final updated = session.updatePosition(
          position: 15,
          mysteryNumber: 2,
          hailMary: 7,
        );

        expect(updated.currentPosition, equals(15));
        expect(updated.currentMysteryNumber, equals(2));
        expect(updated.currentHailMary, equals(7));
      });

      test('finish marks session complete with end time', () {
        final beforeFinish = DateTime.now();
        final session = createTestSession();
        final finished = session.finish();
        final afterFinish = DateTime.now();

        expect(finished.completed, isTrue);
        expect(finished.endTime, isNotNull);
        expect(
          finished.endTime!.isAfter(beforeFinish) ||
              finished.endTime!.isAtSameMomentAs(beforeFinish),
          isTrue,
        );
        expect(finished.currentPosition, isNull);
        expect(finished.currentMysteryNumber, isNull);
        expect(finished.currentHailMary, isNull);
      });
    });

    group('Statistics Calculation', () {
      test('completedCount returns number of mysteries completed', () {
        final session0 = createTestSession(mysteriesCompleted: const []);
        expect(session0.completedCount, equals(0));

        final session2 = createTestSession(mysteriesCompleted: const [1, 2]);
        expect(session2.completedCount, equals(2));

        final session5 = createTestSession(
          mysteriesCompleted: const [1, 2, 3, 4, 5],
        );
        expect(session5.completedCount, equals(5));
      });

      test('progressPercent calculates percentage correctly', () {
        final session0 = createTestSession(mysteriesCompleted: const []);
        expect(session0.progressPercent, equals(0));

        final session1 = createTestSession(mysteriesCompleted: const [1]);
        expect(session1.progressPercent, equals(20));

        final session2 = createTestSession(mysteriesCompleted: const [1, 2]);
        expect(session2.progressPercent, equals(40));

        final session5 = createTestSession(
          mysteriesCompleted: const [1, 2, 3, 4, 5],
        );
        expect(session5.progressPercent, equals(100));
      });

      test('isComplete returns true when all mysteries done', () {
        final session4 = createTestSession(
          mysteriesCompleted: const [1, 2, 3, 4],
        );
        expect(session4.isComplete, isFalse);

        final session5 = createTestSession(
          mysteriesCompleted: const [1, 2, 3, 4, 5],
        );
        expect(session5.isComplete, isTrue);
      });

      test('durationMinutes calculates elapsed time', () {
        final session = createTestSession(
          startTime: testStartTime,
          endTime: testEndTime,
        );

        expect(session.durationMinutes, equals(30));
      });

      test('durationMinutes returns null for incomplete session', () {
        final session = createTestSession(endTime: null);
        expect(session.durationMinutes, isNull);
      });
    });

    group('Session Status', () {
      test('isInProgress returns true for active session', () {
        final session = createTestSession(completed: false, endTime: null);
        expect(session.isInProgress, isTrue);
      });

      test('isInProgress returns false for completed session', () {
        final session = createTestSession(
          completed: true,
          endTime: testEndTime,
        );
        expect(session.isInProgress, isFalse);
      });

      test('isInProgress returns false for abandoned session', () {
        final session = createTestSession(
          completed: false,
          endTime: testEndTime,
        );
        expect(session.isInProgress, isFalse);
      });

      test('isAbandoned returns true for abandoned session', () {
        final session = createTestSession(
          completed: false,
          endTime: testEndTime,
        );
        expect(session.isAbandoned, isTrue);
      });

      test('isAbandoned returns false for completed session', () {
        final session = createTestSession(
          completed: true,
          endTime: testEndTime,
        );
        expect(session.isAbandoned, isFalse);
      });

      test('isAbandoned returns false for in-progress session', () {
        final session = createTestSession(completed: false, endTime: null);
        expect(session.isAbandoned, isFalse);
      });
    });

    group('Copy With', () {
      test('creates copy with updated fields', () {
        final session = createTestSession();
        final updated = session.copyWith(
          mysterySet: MysterySet.glorious,
          notes: 'Updated notes',
        );

        expect(updated.id, equals(session.id));
        expect(updated.startTime, equals(session.startTime));
        expect(updated.mysterySet, equals(MysterySet.glorious));
        expect(updated.notes, equals('Updated notes'));
      });

      test('preserves original values when not specified', () {
        final session = createTestSession(
          mysteriesCompleted: const [1, 2],
          notes: 'Original notes',
        );
        final updated = session.copyWith(completed: true);

        expect(updated.mysteriesCompleted, equals([1, 2]));
        expect(updated.notes, equals('Original notes'));
      });
    });

    group('Equality', () {
      test('sessions with same id are equal', () {
        final session1 = createTestSession(
          id: 'same-id',
          mysterySet: MysterySet.joyful,
        );
        final session2 = createTestSession(
          id: 'same-id',
          mysterySet: MysterySet.sorrowful,
        );

        expect(session1, equals(session2));
        expect(session1.hashCode, equals(session2.hashCode));
      });

      test('sessions with different ids are not equal', () {
        final session1 = createTestSession(id: 'id-1');
        final session2 = createTestSession(id: 'id-2');

        expect(session1, isNot(equals(session2)));
      });
    });

    group('To String', () {
      test('toString returns formatted string', () {
        final session = createTestSession(
          id: 'test-id',
          mysterySet: MysterySet.joyful,
          mysteriesCompleted: const [1, 2],
          completed: false,
        );

        final str = session.toString();
        expect(str, contains('test-id'));
        expect(str, contains('Joyful'));
        expect(str, contains('completed: 2/5'));
        expect(str, contains('done: false'));
      });
    });
  });
}
