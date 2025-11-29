import 'package:flutter_test/flutter_test.dart';
import 'package:sancta_via_fasting_companion/models/fast_session.dart';
import 'package:sancta_via_fasting_companion/models/fast_status.dart';

void main() {
  group('FastSession', () {
    final now = DateTime(2024, 1, 15, 12, 0, 0);
    final startTime = DateTime(2024, 1, 15, 8, 0, 0); // 4 hours ago

    test('should create with required fields', () {
      final session = FastSession(
        id: 'session1',
        fastTypeId: 'fast1',
        startTime: startTime,
        targetDurationMinutes: 960, // 16 hours
        status: FastStatus.active,
      );

      expect(session.id, 'session1');
      expect(session.fastTypeId, 'fast1');
      expect(session.startTime, startTime);
      expect(session.endTime, isNull);
      expect(session.targetDurationMinutes, 960);
      expect(session.status, FastStatus.active);
      expect(session.notes, isNull);
      expect(session.encouragementsShown, isEmpty);
    });

    test('should create with all fields', () {
      final endTime = DateTime(2024, 1, 16, 0, 0, 0);
      final session = FastSession(
        id: 'session2',
        fastTypeId: 'fast2',
        startTime: startTime,
        endTime: endTime,
        targetDurationMinutes: 1440, // 24 hours
        status: FastStatus.completed,
        notes: 'Offered for my family',
        encouragementsShown: ['enc1', 'enc2', 'enc3'],
      );

      expect(session.id, 'session2');
      expect(session.endTime, endTime);
      expect(session.status, FastStatus.completed);
      expect(session.notes, 'Offered for my family');
      expect(session.encouragementsShown, ['enc1', 'enc2', 'enc3']);
    });

    test('toJson should serialize correctly', () {
      final endTime = DateTime(2024, 1, 15, 20, 0, 0);
      final session = FastSession(
        id: 'session3',
        fastTypeId: 'fast3',
        startTime: startTime,
        endTime: endTime,
        targetDurationMinutes: 720,
        status: FastStatus.broken,
        notes: 'Test notes',
        encouragementsShown: ['enc4'],
      );

      final json = session.toJson();

      expect(json['id'], 'session3');
      expect(json['fastTypeId'], 'fast3');
      expect(json['startTime'], startTime.toIso8601String());
      expect(json['endTime'], endTime.toIso8601String());
      expect(json['targetDurationMinutes'], 720);
      expect(json['status'], 'broken');
      expect(json['notes'], 'Test notes');
      expect(json['encouragementsShown'], ['enc4']);
    });

    test('toJson should handle null endTime', () {
      final session = FastSession(
        id: 'session4',
        fastTypeId: 'fast4',
        startTime: startTime,
        targetDurationMinutes: 960,
        status: FastStatus.active,
      );

      final json = session.toJson();

      expect(json['endTime'], isNull);
    });

    test('fromJson should deserialize correctly', () {
      final json = {
        'id': 'session5',
        'fastTypeId': 'fast5',
        'startTime': startTime.toIso8601String(),
        'endTime': null,
        'targetDurationMinutes': 1080,
        'status': 'active',
        'notes': 'Test',
        'encouragementsShown': ['enc5', 'enc6'],
      };

      final session = FastSession.fromJson(json);

      expect(session.id, 'session5');
      expect(session.fastTypeId, 'fast5');
      expect(session.startTime, startTime);
      expect(session.endTime, isNull);
      expect(session.targetDurationMinutes, 1080);
      expect(session.status, FastStatus.active);
      expect(session.notes, 'Test');
      expect(session.encouragementsShown, ['enc5', 'enc6']);
    });

    test('fromJson should handle null optional fields', () {
      final json = {
        'id': 'session6',
        'fastTypeId': 'fast6',
        'startTime': startTime.toIso8601String(),
        'endTime': null,
        'targetDurationMinutes': 960,
        'status': 'active',
        'notes': null,
        'encouragementsShown': null,
      };

      final session = FastSession.fromJson(json);

      expect(session.notes, isNull);
      expect(session.encouragementsShown, isEmpty);
    });

    test('should roundtrip through JSON', () {
      final endTime = DateTime(2024, 1, 15, 18, 30, 0);
      final original = FastSession(
        id: 'session7',
        fastTypeId: 'fast7',
        startTime: startTime,
        endTime: endTime,
        targetDurationMinutes: 600,
        status: FastStatus.completed,
        notes: 'Roundtrip test',
        encouragementsShown: ['a', 'b', 'c'],
      );

      final json = original.toJson();
      final roundtripped = FastSession.fromJson(json);

      expect(roundtripped, equals(original));
    });

    test('copyWith should create modified copy', () {
      final original = FastSession(
        id: 'session8',
        fastTypeId: 'fast8',
        startTime: startTime,
        targetDurationMinutes: 960,
        status: FastStatus.active,
        notes: 'Original',
      );

      final modified = original.copyWith(
        status: FastStatus.completed,
        endTime: now,
        notes: 'Modified',
      );

      expect(modified.id, original.id);
      expect(modified.fastTypeId, original.fastTypeId);
      expect(modified.startTime, original.startTime);
      expect(modified.status, FastStatus.completed);
      expect(modified.endTime, now);
      expect(modified.notes, 'Modified');
    });

    test('elapsedDuration should calculate correctly for active fast', () {
      final session = FastSession(
        id: 'session9',
        fastTypeId: 'fast9',
        startTime: startTime,
        targetDurationMinutes: 960,
        status: FastStatus.active,
      );

      // Since endTime is null, it uses DateTime.now()
      // We can't test exact duration, but we can verify it's reasonable
      final elapsed = session.elapsedDuration;
      expect(elapsed.inMinutes, greaterThan(0));
    });

    test('elapsedDuration should use endTime when present', () {
      final endTime = startTime.add(const Duration(hours: 8));
      final session = FastSession(
        id: 'session10',
        fastTypeId: 'fast10',
        startTime: startTime,
        endTime: endTime,
        targetDurationMinutes: 960,
        status: FastStatus.completed,
      );

      expect(session.elapsedDuration, const Duration(hours: 8));
      expect(session.elapsedMinutes, 480);
      expect(session.elapsedHours, 8);
    });

    test('targetEndTime should calculate correctly', () {
      final session = FastSession(
        id: 'session11',
        fastTypeId: 'fast11',
        startTime: startTime,
        targetDurationMinutes: 960, // 16 hours
        status: FastStatus.active,
      );

      final expectedEndTime = startTime.add(const Duration(hours: 16));
      expect(session.targetEndTime, expectedEndTime);
    });

    test('remainingDuration should calculate correctly', () {
      // Create a session that started 4 hours ago with 16 hour target
      final session = FastSession(
        id: 'session12',
        fastTypeId: 'fast12',
        startTime: DateTime.now().subtract(const Duration(hours: 4)),
        targetDurationMinutes: 960, // 16 hours
        status: FastStatus.active,
      );

      // Should have ~12 hours remaining
      final remaining = session.remainingDuration;
      expect(remaining.inHours, greaterThanOrEqualTo(11));
      expect(remaining.inHours, lessThanOrEqualTo(13));
    });

    test('remainingDuration should be zero when target reached', () {
      // Create a session that started 20 hours ago with 16 hour target
      final session = FastSession(
        id: 'session13',
        fastTypeId: 'fast13',
        startTime: DateTime.now().subtract(const Duration(hours: 20)),
        targetDurationMinutes: 960, // 16 hours
        status: FastStatus.active,
      );

      expect(session.remainingDuration, Duration.zero);
      expect(session.remainingMinutes, 0);
    });

    test('progressPercentage should calculate correctly', () {
      final halfwayTime = startTime.add(const Duration(hours: 8));
      final session = FastSession(
        id: 'session14',
        fastTypeId: 'fast14',
        startTime: startTime,
        endTime: halfwayTime,
        targetDurationMinutes: 960, // 16 hours
        status: FastStatus.active,
      );

      expect(session.progressPercentage, closeTo(0.5, 0.01));
    });

    test('progressPercentage should clamp at 1.0', () {
      final overtimeEndTime = startTime.add(const Duration(hours: 20));
      final session = FastSession(
        id: 'session15',
        fastTypeId: 'fast15',
        startTime: startTime,
        endTime: overtimeEndTime,
        targetDurationMinutes: 960, // 16 hours
        status: FastStatus.completed,
      );

      expect(session.progressPercentage, 1.0);
    });

    test('progressPercentage should handle zero duration', () {
      final session = FastSession(
        id: 'session16',
        fastTypeId: 'fast16',
        startTime: startTime,
        targetDurationMinutes: 0,
        status: FastStatus.active,
      );

      expect(session.progressPercentage, 0.0);
    });

    test('hasReachedTarget should be true when target met', () {
      final endTime = startTime.add(const Duration(hours: 16));
      final session = FastSession(
        id: 'session17',
        fastTypeId: 'fast17',
        startTime: startTime,
        endTime: endTime,
        targetDurationMinutes: 960, // 16 hours
        status: FastStatus.completed,
      );

      expect(session.hasReachedTarget, isTrue);
    });

    test('hasReachedTarget should be false when target not met', () {
      final earlyEndTime = startTime.add(const Duration(hours: 8));
      final session = FastSession(
        id: 'session18',
        fastTypeId: 'fast18',
        startTime: startTime,
        endTime: earlyEndTime,
        targetDurationMinutes: 960, // 16 hours
        status: FastStatus.broken,
      );

      expect(session.hasReachedTarget, isFalse);
    });

    test('hasShownEncouragement should check correctly', () {
      final session = FastSession(
        id: 'session19',
        fastTypeId: 'fast19',
        startTime: startTime,
        targetDurationMinutes: 960,
        status: FastStatus.active,
        encouragementsShown: ['enc1', 'enc2', 'enc3'],
      );

      expect(session.hasShownEncouragement('enc1'), isTrue);
      expect(session.hasShownEncouragement('enc2'), isTrue);
      expect(session.hasShownEncouragement('enc4'), isFalse);
    });

    test('equality should work correctly', () {
      final session1 = FastSession(
        id: 'session20',
        fastTypeId: 'fast20',
        startTime: startTime,
        targetDurationMinutes: 960,
        status: FastStatus.active,
        notes: 'Same',
      );

      final session2 = FastSession(
        id: 'session20',
        fastTypeId: 'fast20',
        startTime: startTime,
        targetDurationMinutes: 960,
        status: FastStatus.active,
        notes: 'Same',
      );

      final session3 = FastSession(
        id: 'session21',
        fastTypeId: 'fast20',
        startTime: startTime,
        targetDurationMinutes: 960,
        status: FastStatus.active,
        notes: 'Same',
      );

      expect(session1, equals(session2));
      expect(session1, isNot(equals(session3)));
    });

    test('equality should check encouragementsShown', () {
      final session1 = FastSession(
        id: 'session22',
        fastTypeId: 'fast22',
        startTime: startTime,
        targetDurationMinutes: 960,
        status: FastStatus.active,
        encouragementsShown: ['a', 'b'],
      );

      final session2 = FastSession(
        id: 'session22',
        fastTypeId: 'fast22',
        startTime: startTime,
        targetDurationMinutes: 960,
        status: FastStatus.active,
        encouragementsShown: ['a', 'b'],
      );

      final session3 = FastSession(
        id: 'session22',
        fastTypeId: 'fast22',
        startTime: startTime,
        targetDurationMinutes: 960,
        status: FastStatus.active,
        encouragementsShown: ['a', 'c'],
      );

      expect(session1, equals(session2));
      expect(session1, isNot(equals(session3)));
    });

    test('hashCode should be consistent', () {
      final session1 = FastSession(
        id: 'session23',
        fastTypeId: 'fast23',
        startTime: startTime,
        targetDurationMinutes: 960,
        status: FastStatus.active,
      );

      final session2 = FastSession(
        id: 'session23',
        fastTypeId: 'fast23',
        startTime: startTime,
        targetDurationMinutes: 960,
        status: FastStatus.active,
      );

      expect(session1.hashCode, equals(session2.hashCode));
    });

    test('toString should return meaningful representation', () {
      final session = FastSession(
        id: 'session24',
        fastTypeId: 'fast24',
        startTime: startTime,
        targetDurationMinutes: 960,
        status: FastStatus.active,
      );

      final str = session.toString();

      expect(str, contains('FastSession'));
      expect(str, contains('session24'));
      expect(str, contains('fast24'));
    });
  });
}
