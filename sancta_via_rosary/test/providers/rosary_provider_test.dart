import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rosary_companion/models/models.dart';
import 'package:rosary_companion/providers/rosary_session_provider.dart';

void main() {
  group('Rosary Session Provider', () {
    testWidgets(
      'rosarySessionProvider creates notifier with correct mystery set',
      (tester) async {
        final container = ProviderContainer();

        final notifier = container.read(
          rosarySessionProvider(MysterySet.joyful).notifier,
        );

        expect(notifier, isA<RosaryPrayerNotifier>());
        expect(notifier.state.mysterySet, equals(MysterySet.joyful));
        expect(notifier.state.currentMystery, equals(0));
        expect(notifier.state.isComplete, isFalse);

        container.dispose();
      },
    );

    testWidgets('rosarySessionProvider state changes with next', (
      tester,
    ) async {
      final container = ProviderContainer();

      final notifier = container.read(
        rosarySessionProvider(MysterySet.joyful).notifier,
      );

      // Initial state
      expect(notifier.state.currentMystery, equals(0));
      expect(notifier.state.currentDecadePosition, equals(0));

      // Advance
      notifier.next();
      expect(notifier.state.currentDecadePosition, equals(1));

      // Continue advancing
      notifier.next();
      expect(notifier.state.currentDecadePosition, equals(2));

      container.dispose();
    });

    testWidgets('rosarySessionProvider previous goes back', (tester) async {
      final container = ProviderContainer();

      final notifier = container.read(
        rosarySessionProvider(MysterySet.joyful).notifier,
      );

      // Advance twice
      notifier.next();
      notifier.next();
      expect(notifier.state.currentDecadePosition, equals(2));

      // Go back
      notifier.previous();
      expect(notifier.state.currentDecadePosition, equals(1));

      container.dispose();
    });

    testWidgets('rosarySessionProvider can jump to specific mystery', (
      tester,
    ) async {
      final container = ProviderContainer();

      final notifier = container.read(
        rosarySessionProvider(MysterySet.joyful).notifier,
      );

      notifier.goToMystery(3);

      expect(notifier.state.currentMystery, equals(3));
      expect(notifier.state.currentDecadePosition, equals(0));
      expect(notifier.state.showClosing, isFalse);

      container.dispose();
    });

    testWidgets('rosarySessionProvider goToMystery validates bounds', (
      tester,
    ) async {
      final container = ProviderContainer();

      final notifier = container.read(
        rosarySessionProvider(MysterySet.joyful).notifier,
      );

      // Invalid mystery numbers should be ignored
      notifier.goToMystery(0);
      expect(notifier.state.currentMystery, equals(0));

      notifier.goToMystery(6);
      expect(notifier.state.currentMystery, equals(0));

      notifier.goToMystery(-1);
      expect(notifier.state.currentMystery, equals(0));

      container.dispose();
    });

    testWidgets('rosarySessionProvider reset returns to initial state', (
      tester,
    ) async {
      final container = ProviderContainer();

      final notifier = container.read(
        rosarySessionProvider(MysterySet.joyful).notifier,
      );

      // Advance and go to mystery
      notifier.next();
      notifier.goToMystery(3);
      notifier.next();

      // Reset
      notifier.reset();

      expect(notifier.state.currentMystery, equals(0));
      expect(notifier.state.currentDecadePosition, equals(0));
      expect(notifier.state.isComplete, isFalse);
      expect(notifier.state.showClosing, isFalse);

      container.dispose();
    });

    testWidgets('rosarySessionProvider can complete rosary', (tester) async {
      final container = ProviderContainer();

      final notifier = container.read(
        rosarySessionProvider(MysterySet.joyful).notifier,
      );

      // Simulate completing all 5 decades (simplified)
      for (var i = 0; i < 5; i++) {
        notifier.goToMystery(i + 1);
        // Skip through the decade
        for (var j = 0; j < 14; j++) {
          notifier.next();
        }
      }

      // Show closing
      notifier.next();
      expect(notifier.state.showClosing, isTrue);

      // Complete
      notifier.next();
      expect(notifier.state.isComplete, isTrue);

      container.dispose();
    });

    testWidgets('RosaryPrayerState currentStep reflects position', (
      tester,
    ) async {
      final container = ProviderContainer();

      final notifier = container.read(
        rosarySessionProvider(MysterySet.joyful).notifier,
      );

      // Opening
      expect(notifier.state.currentStep, equals(PrayerStep.opening));

      // Advance through opening
      notifier.next();
      notifier.next();
      notifier.next();
      notifier.next();

      // First mystery
      expect(notifier.state.currentMystery, equals(1));
      expect(notifier.state.currentStep, equals(PrayerStep.announceMystery));

      container.dispose();
    });

    testWidgets('RosaryPrayerState calculates hail mary number', (
      tester,
    ) async {
      final container = ProviderContainer();

      final notifier = container.read(
        rosarySessionProvider(MysterySet.joyful).notifier,
      );

      // Go to first mystery
      notifier.goToMystery(1);

      // Start Hail Marys
      notifier.next(); // Announcement
      notifier.next(); // Our Father
      notifier.next(); // Hail Mary 1

      expect(notifier.state.currentStep, equals(PrayerStep.hailMary));
      expect(notifier.state.hailMaryNumber, equals(1));

      // Continue
      notifier.next();
      expect(notifier.state.hailMaryNumber, equals(2));

      container.dispose();
    });

    testWidgets('RosaryPrayerState totalProgress increases', (tester) async {
      final container = ProviderContainer();

      final notifier = container.read(
        rosarySessionProvider(MysterySet.joyful).notifier,
      );

      final initialProgress = notifier.state.totalProgress;

      // Advance should increase progress
      notifier.next();
      expect(notifier.state.totalProgress, greaterThan(initialProgress));

      // Complete should be 100
      notifier.goToMystery(5);
      for (var i = 0; i < 14; i++) {
        notifier.next();
      }
      notifier.next(); // Show closing
      notifier.next(); // Complete

      expect(notifier.state.totalProgress, equals(100));

      container.dispose();
    });

    testWidgets('different mystery sets have separate state', (tester) async {
      final container = ProviderContainer();

      final joyfulNotifier = container.read(
        rosarySessionProvider(MysterySet.joyful).notifier,
      );
      final sorrowfulNotifier = container.read(
        rosarySessionProvider(MysterySet.sorrowful).notifier,
      );

      // Advance joyful
      joyfulNotifier.next();
      joyfulNotifier.next();

      // Sorrowful should be at initial position
      expect(sorrowfulNotifier.state.currentMystery, equals(0));
      expect(sorrowfulNotifier.state.currentDecadePosition, equals(0));

      // Joyful should be advanced
      expect(joyfulNotifier.state.currentDecadePosition, equals(2));

      container.dispose();
    });
  });

  group('RosaryPrayerState', () {
    testWidgets('copyWith creates updated state', (tester) async {
      const state = RosaryPrayerState(
        mysterySet: MysterySet.joyful,
        currentMystery: 1,
        currentDecadePosition: 5,
      );

      final updated = state.copyWith(currentDecadePosition: 6);

      expect(updated.mysterySet, equals(MysterySet.joyful));
      expect(updated.currentMystery, equals(1));
      expect(updated.currentDecadePosition, equals(6));
    });

    testWidgets('complete state has 100 percent progress', (tester) async {
      const state = RosaryPrayerState(
        mysterySet: MysterySet.joyful,
        isComplete: true,
      );

      expect(state.totalProgress, equals(100));
      expect(state.currentStep, equals(PrayerStep.complete));
    });

    testWidgets('closing state has high progress', (tester) async {
      const state = RosaryPrayerState(
        mysterySet: MysterySet.joyful,
        showClosing: true,
      );

      expect(state.totalProgress, equals(95));
      expect(state.currentStep, equals(PrayerStep.closing));
    });

    testWidgets('bead position tracks Hail Marys', (tester) async {
      final container = ProviderContainer();
      final notifier = container.read(
        rosarySessionProvider(MysterySet.joyful).notifier,
      );

      // Go to first mystery
      notifier.goToMystery(1);
      notifier.next(); // Announcement
      notifier.next(); // Our Father
      notifier.next(); // Hail Mary 1

      // Should be tracking bead 0 (0-indexed)
      expect(notifier.state.beadPosition, equals(0));

      // Continue
      notifier.next(); // Hail Mary 2
      expect(notifier.state.beadPosition, equals(1));

      // Hail Mary 10
      for (var i = 0; i < 8; i++) {
        notifier.next();
      }
      expect(notifier.state.beadPosition, equals(9));

      // After Hail Marys, bead position resets
      notifier.next(); // Glory Be
      expect(notifier.state.beadPosition, equals(-1));

      container.dispose();
    });
  });
}
