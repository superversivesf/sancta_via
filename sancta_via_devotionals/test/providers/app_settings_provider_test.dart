import 'dart:convert';

import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_test/flutter_test.dart';

import 'package:sancta_via_devotionals/models/app_settings.dart';
import 'package:sancta_via_devotionals/providers/app_settings_provider.dart';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:sancta_via_shared_ui/sancta_via_shared_ui.dart';

/// Lets the notifier's un-awaited async load (and the queued writes chained
/// behind it) complete before asserting.
Future<void> settle() async {
  for (var i = 0; i < 10; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

Future<Map<String, dynamic>> storedSettingsJson() async {
  final prefs = await SharedPreferences.getInstance();
  return json.decode(
        prefs.getString(DevotionsSettingsNotifier.storageKey) ?? '{}',
      )
      as Map<String, dynamic>;
}

void main() {
  group('DevotionsSettingsNotifier', () {
    test('uses the pinned storage key', () {
      expect(DevotionsSettingsNotifier.storageKey, 'devotionals_app_settings');
    });

    test('restores persisted settings on a fresh container', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        DevotionsSettingsNotifier.storageKey:
            '{"angelusMorning":{"hour":7,"minute":30},'
            '"missedDayDefaultPolicy":"strict","onboardingComplete":true}',
      });
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(devotionsSettingsProvider);
      await settle();

      final state = container.read(devotionsSettingsProvider);
      expect(state.angelusMorning, const TimeOfDay(hour: 7, minute: 30));
      expect(state.missedDayDefaultPolicy, 'strict');
      expect(state.onboardingComplete, isTrue);
    });

    test(
      'restore uses the live base settings, not our stored snapshot',
      () async {
        SharedPreferences.setMockInitialValues(<String, Object>{
          DevotionsSettingsNotifier.storageKey:
              '{"baseSettings":{"fontSize":22},"latinDisplayEnabled":false}',
          // Deliberately NO value under the shared base-settings key: the
          // authoritative provider sits at defaults, so a stale snapshot of
          // fontSize 22 must not be resurrected on restore.
        });
        final container = ProviderContainer();
        addTearDown(container.dispose);

        container.read(devotionsSettingsProvider);
        await settle();

        final state = container.read(devotionsSettingsProvider);
        expect(
          state.baseSettings,
          container.read(baseSettingsProvider),
          reason:
              'baseSettingsProvider is authoritative over our JSON snapshot',
        );
        expect(state.baseSettings.fontSize, 18.0);
        expect(state.latinDisplayEnabled, isFalse);
      },
    );

    test('base settings sync replaces baseSettings and persists it', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(devotionsSettingsProvider);
      await settle();

      await container.read(baseSettingsProvider.notifier).setFontSize(20.0);
      await settle();

      expect(
        container.read(devotionsSettingsProvider).baseSettings.fontSize,
        20.0,
      );
      final stored = await storedSettingsJson();
      expect(
        (stored['baseSettings'] as Map<String, dynamic>)['fontSize'],
        20.0,
      );
    });

    test(
      'base settings sync does not clobber user devotional fields',
      () async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final notifier = container.read(devotionsSettingsProvider.notifier);
        await settle();

        // User mutates a devotional field, then base settings change.
        await notifier.setLatinDisplayEnabled(false);
        await container.read(baseSettingsProvider.notifier).setFontSize(20.0);
        await settle();

        final state = container.read(devotionsSettingsProvider);
        expect(state.latinDisplayEnabled, isFalse);
        expect(state.baseSettings.fontSize, 20.0);

        final stored = await storedSettingsJson();
        expect(stored['latinDisplayEnabled'], isFalse);
        expect(
          (stored['baseSettings'] as Map<String, dynamic>)['fontSize'],
          20.0,
        );
      },
    );

    test('mutation racing the async load is merged, not clobbered', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        DevotionsSettingsNotifier.storageKey:
            '{"morningReminderEnabled":true,"latinDisplayEnabled":false,'
            '"missedDayDefaultPolicy":"strict"}',
      });
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Mutate BEFORE the un-awaited load resolves, exactly like a UI tap
      // racing app startup.
      final notifier = container.read(devotionsSettingsProvider.notifier);
      final mutation = notifier.setNightItemsEnabled(true);
      await mutation;
      await settle();

      // The raced mutation survived…
      expect(notifier.state.nightItemsEnabled, isTrue);
      // …and the stored customizations survived too.
      expect(notifier.state.morningReminderEnabled, isTrue);
      expect(notifier.state.latinDisplayEnabled, isFalse);
      expect(notifier.state.missedDayDefaultPolicy, 'strict');

      // The merged state is re-persisted so disk keeps the union.
      final stored = await storedSettingsJson();
      expect(stored['nightItemsEnabled'], isTrue);
      expect(stored['morningReminderEnabled'], isTrue);
      expect(stored['latinDisplayEnabled'], isFalse);
      expect(stored['missedDayDefaultPolicy'], 'strict');
    });

    test('two rapid mutations persist in order so disk ends final', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(devotionsSettingsProvider.notifier);
      await settle();

      // Fire-and-forget, no awaits between: overlapping write requests.
      final first = notifier.setLatinDisplayEnabled(false);
      final second = notifier.setLatinDisplayEnabled(true);
      await first;
      await second;

      final stored = await storedSettingsJson();
      expect(
        stored['latinDisplayEnabled'],
        container.read(devotionsSettingsProvider).latinDisplayEnabled,
      );
      expect(stored['latinDisplayEnabled'], isTrue);
    });

    test(
      'corrupt stored JSON falls back to defaults without throwing',
      () async {
        SharedPreferences.setMockInitialValues(<String, Object>{
          DevotionsSettingsNotifier.storageKey: 'not json',
        });
        final container = ProviderContainer();
        addTearDown(container.dispose);

        container.read(devotionsSettingsProvider);
        await settle();

        final state = container.read(devotionsSettingsProvider);
        expect(state, DevotionsAppSettings.defaults());
        expect(state.missedDayDefaultPolicy, 'permissive');
        expect(state.onboardingComplete, isFalse);
      },
    );
  });

  group('convenience providers', () {
    test(
      'anchor times, policy, Latin display and onboarding are exposed',
      () async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        final container = ProviderContainer();
        addTearDown(container.dispose);

        container.read(devotionsSettingsProvider);
        await settle();

        final anchors = container.read(anchorTimesProvider);
        expect(anchors.angelusMorning, const TimeOfDay(hour: 6, minute: 0));
        expect(anchors.angelusNoon, const TimeOfDay(hour: 12, minute: 0));
        expect(anchors.angelusEvening, const TimeOfDay(hour: 18, minute: 0));
        expect(anchors.mercyHour, const TimeOfDay(hour: 15, minute: 0));
        expect(container.read(missedDayDefaultPolicyProvider), 'permissive');
        expect(container.read(latinDisplayProvider), isTrue);
        expect(container.read(onboardingCompleteProvider), isFalse);

        await container
            .read(devotionsSettingsProvider.notifier)
            .setOnboardingComplete(true);
        expect(container.read(onboardingCompleteProvider), isTrue);
        expect(
          container.read(missedDayDefaultPolicyProvider),
          container.read(devotionsSettingsProvider).missedDayDefaultPolicy,
        );
      },
    );
  });
}
