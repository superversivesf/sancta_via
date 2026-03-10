import 'package:flutter_test/flutter_test.dart';
import 'package:rosary_companion/models/models.dart';
import 'package:rosary_companion/services/rosary_session_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('RosarySessionService', () {
    late RosarySessionService service;

    setUp(() {
      service = RosarySessionService.instance;
      // Clear any existing sessions
      SharedPreferences.setMockInitialValues({});
    });

    tearDown(() {
      SharedPreferences.setMockInitialValues({});
    });

    group('Singleton Pattern', () {
      test('instance returns same object', () {
        final instance1 = RosarySessionService.instance;
        final instance2 = RosarySessionService.instance;

        expect(identical(instance1, instance2), isTrue);
      });
    });

    group('Session Lifecycle', () {
      test('startSession creates new session', () async {
        final session = await service.startSession(MysterySet.joyful);

        expect(session.mysterySet, equals(MysterySet.joyful));
        expect(session.completed, isFalse);
        expect(session.endTime, isNull);
        expect(session.startTime.isBefore(DateTime.now()), isTrue);
      });

      test('startSession clears existing session', () async {
        await service.startSession(MysterySet.joyful);
        final newSession = await service.startSession(MysterySet.sorrowful);

        expect(newSession.mysterySet, equals(MysterySet.sorrowful));
      });

      test('getCurrentSession returns active session', () async {
        await service.startSession(MysterySet.glorious);
        final current = await service.getCurrentSession();

        expect(current, isNotNull);
        expect(current!.mysterySet, equals(MysterySet.glorious));
      });

      test('getCurrentSession returns null when no session', () async {
        final current = await service.getCurrentSession();
        expect(current, isNull);
      });

      test('resumeSession returns current session', () async {
        await service.startSession(MysterySet.luminous);
        final resumed = await service.resumeSession();

        expect(resumed, isNotNull);
        expect(resumed!.mysterySet, equals(MysterySet.luminous));
      });

      test('finishSession marks session complete', () async {
        await service.startSession(MysterySet.joyful);
        final completed = await service.finishSession();

        expect(completed, isNotNull);
        expect(completed!.completed, isTrue);
        expect(completed.endTime, isNotNull);
      });

      test('finishSession returns null when no session', () async {
        final completed = await service.finishSession();
        expect(completed, isNull);
      });

      test('abandonSession marks session abandoned', () async {
        await service.startSession(MysterySet.joyful);
        await service.abandonSession();

        final current = await service.getCurrentSession();
        expect(current, isNull); // Cleared after abandonment
      });

      test('abandonSession handles no active session gracefully', () async {
        await service.abandonSession();
        expect(true, isTrue); // Should not throw
      });
    });

    group('Prayer Progress', () {
      test('recordPrayerCompletion updates position', () async {
        await service.startSession(MysterySet.joyful);

        await service.recordPrayerCompletion(PrayerType.signOfCross);
        var current = await service.getCurrentSession();
        expect(current!.currentPosition, equals(1));

        await service.recordPrayerCompletion(PrayerType.ourFather);
        current = await service.getCurrentSession();
        expect(current!.currentPosition, equals(2));
      });

      test('recordPrayerCompletion does nothing without session', () async {
        await service.recordPrayerCompletion(PrayerType.signOfCross);
        expect(true, isTrue); // Should not throw
      });

      test('completeMystery adds to completed list', () async {
        await service.startSession(MysterySet.joyful);
        await service.completeMystery(1);

        final current = await service.getCurrentSession();
        expect(current!.mysteriesCompleted, contains(1));
        expect(current.completedCount, equals(1));
      });

      test('completeMystery validates mystery number', () async {
        await service.startSession(MysterySet.joyful);

        await service.completeMystery(0); // Invalid
        await service.completeMystery(6); // Invalid
        await service.completeMystery(-1); // Invalid

        final current = await service.getCurrentSession();
        expect(current!.mysteriesCompleted, isEmpty);
      });

      test('updateProgress sets position values', () async {
        await service.startSession(MysterySet.joyful);
        await service.updateProgress(
          position: 10,
          mysteryNumber: 2,
          hailMary: 5,
        );

        final current = await service.getCurrentSession();
        expect(current!.currentPosition, equals(10));
        expect(current.currentMysteryNumber, equals(2));
        expect(current.currentHailMary, equals(5));
      });
    });

    group('Session History', () {
      test('getSessionHistory returns empty list initially', () async {
        final history = await service.getSessionHistory();
        expect(history, isEmpty);
      });

      test('completed session appears in history', () async {
        await service.startSession(MysterySet.joyful);
        await service.finishSession();

        final history = await service.getSessionHistory();
        expect(history.length, equals(1));
        expect(history.first.completed, isTrue);
      });

      test('abandoned session appears in history', () async {
        await service.startSession(MysterySet.joyful);
        await service.abandonSession();

        final history = await service.getSessionHistory();
        expect(history.length, equals(1));
        expect(history.first.completed, isFalse);
        expect(history.first.endTime, isNotNull);
      });

      test('getCompletedSessions filters completed only', () async {
        await service.startSession(MysterySet.joyful);
        await service.finishSession();

        await service.startSession(MysterySet.sorrowful);
        await service.abandonSession();

        final completed = await service.getCompletedSessions();
        expect(completed.length, equals(1));
        expect(completed.first.mysterySet, equals(MysterySet.joyful));
      });

      test('getSessionsInRange filters by date', () async {
        await service.startSession(MysterySet.joyful);
        await service.finishSession();

        final now = DateTime.now();
        final start = now.subtract(const Duration(days: 1));
        final end = now.add(const Duration(days: 1));

        final sessions = await service.getSessionsInRange(start, end);
        expect(sessions.length, equals(1));

        final pastRange = await service.getSessionsInRange(
          now.add(const Duration(days: 1)),
          now.add(const Duration(days: 2)),
        );
        expect(pastRange, isEmpty);
      });

      test('clearHistory removes all sessions', () async {
        await service.startSession(MysterySet.joyful);
        await service.finishSession();

        await service.clearHistory();

        final history = await service.getSessionHistory();
        expect(history, isEmpty);
      });

      test('clearHistory can be called on empty history', () async {
        await service.clearHistory();
        expect(true, isTrue); // Should not throw
      });

      test('history is sorted by start time (newest first)', () async {
        // Create first session
        await service.startSession(MysterySet.joyful);
        final session1 = await service.finishSession();

        // Wait a moment and create second session
        await Future.delayed(const Duration(milliseconds: 10));
        await service.startSession(MysterySet.sorrowful);
        final session2 = await service.finishSession();

        final history = await service.getSessionHistory();
        expect(history.length, equals(2));
        expect(history.first.startTime.isAfter(history.last.startTime), isTrue);
      });
    });

    group('Statistics', () {
      test('getStatistics returns empty initially', () async {
        final stats = await service.getStatistics();

        expect(stats.totalCompletedRosaries, equals(0));
        expect(stats.totalHailMarys, equals(0));
        expect(stats.currentStreak, equals(0));
        expect(stats.longestStreak, equals(0));
        expect(stats.totalSessions, equals(0));
      });

      test('getTotalRosaries returns 0 initially', () async {
        final total = await service.getTotalRosaries();
        expect(total, equals(0));
      });

      test('getCurrentStreak returns 0 initially', () async {
        final streak = await service.getCurrentStreak();
        expect(streak, equals(0));
      });

      test('getLongestStreak returns 0 initially', () async {
        final streak = await service.getLongestStreak();
        expect(streak, equals(0));
      });

      test('getTotalHailMarys returns 0 initially', () async {
        final total = await service.getTotalHailMarys();
        expect(total, equals(0));
      });

      test('statistics update after completing session', () async {
        await service.startSession(MysterySet.joyful);
        await service.completeMystery(1);
        await service.completeMystery(2);
        await service.completeMystery(3);
        await service.completeMystery(4);
        await service.completeMystery(5);
        await service.finishSession();

        final stats = await service.getStatistics();
        expect(stats.totalSessions, equals(1));
        expect(stats.totalCompletedRosaries, greaterThan(0));
        expect(stats.totalHailMarys, greaterThan(0));
      });
    });

    group('RosaryStatistics', () {
      test('empty factory creates zeroed stats', () {
        final stats = RosaryStatistics.empty();

        expect(stats.totalCompletedRosaries, equals(0));
        expect(stats.totalHailMarys, equals(0));
        expect(stats.currentStreak, equals(0));
        expect(stats.longestStreak, equals(0));
        expect(stats.totalSessions, equals(0));
      });

      test('fullRosaries calculates complete rosaries', () {
        const stats = RosaryStatistics(
          totalCompletedRosaries: 12,
          totalHailMarys: 120,
          currentStreak: 2,
          longestStreak: 5,
          totalSessions: 3,
        );

        expect(stats.fullRosaries, equals(2));
      });

      test('extraMysteries calculates remainder', () {
        const stats = RosaryStatistics(
          totalCompletedRosaries: 12,
          totalHailMarys: 120,
          currentStreak: 2,
          longestStreak: 5,
          totalSessions: 3,
        );

        expect(stats.extraMysteries, equals(2));
      });

      test('JSON serialization round-trip', () {
        const stats = RosaryStatistics(
          totalCompletedRosaries: 15,
          totalHailMarys: 150,
          currentStreak: 3,
          longestStreak: 10,
          totalSessions: 5,
        );

        final json = stats.toJson();
        final restored = RosaryStatistics.fromJson(json);

        expect(restored.totalCompletedRosaries, equals(15));
        expect(restored.totalHailMarys, equals(150));
        expect(restored.currentStreak, equals(3));
        expect(restored.longestStreak, equals(10));
        expect(restored.totalSessions, equals(5));
      });

      test('fromJson handles null values', () {
        final json = <String, dynamic>{};
        final stats = RosaryStatistics.fromJson(json);

        expect(stats.totalCompletedRosaries, equals(0));
        expect(stats.totalHailMarys, equals(0));
        expect(stats.currentStreak, equals(0));
        expect(stats.longestStreak, equals(0));
        expect(stats.totalSessions, equals(0));
      });
    });
  });
}
