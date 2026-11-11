import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:saint_companion/models/saint_app_settings.dart';
import 'package:saint_companion/providers/saint_app_settings_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Lets the notifier's un-awaited async load complete before asserting.
Future<void> settle() async {
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  group('SaintAppSettingsNotifier', () {
    test('toggleFavorite adds then removes and persists the slug', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final notifier = SaintAppSettingsNotifier();
      await settle();

      // Appears after first toggle
      await notifier.toggleFavorite('st-bernard');
      expect(notifier.isFavorite('st-bernard'), isTrue);
      expect(notifier.state.favoriteSlugs, <String>['st-bernard']);

      // Persisted mock store contains the slug under the storage key
      final prefs = await SharedPreferences.getInstance();
      final stored =
          json.decode(
                prefs.getString(SaintAppSettingsNotifier.storageKey) ?? '{}',
              )
              as Map<String, dynamic>;
      expect(
        (stored['favoriteSlugs'] as List<dynamic>).contains('st-bernard'),
        isTrue,
      );

      // Disappears after second toggle
      await notifier.toggleFavorite('st-bernard');
      expect(notifier.isFavorite('st-bernard'), isFalse);
      expect(notifier.state.favoriteSlugs, isEmpty);
    });

    test('addRecent keeps most-recent-first with dedupe', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final notifier = SaintAppSettingsNotifier();
      await settle();

      await notifier.addRecent('a');
      await notifier.addRecent('b');
      await notifier.addRecent('a');

      expect(notifier.state.recentSlugs, <String>['a', 'b']);
    });

    test('addRecent caps the list at 50 entries', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final notifier = SaintAppSettingsNotifier();
      await settle();

      for (var i = 0; i < 60; i++) {
        await notifier.addRecent('slug-$i');
      }

      expect(notifier.state.recentSlugs, hasLength(50));
      // Most recent stays first, oldest 10 fall off the end
      expect(notifier.state.recentSlugs.first, 'slug-59');
      expect(notifier.state.recentSlugs.last, 'slug-10');
    });

    test('a reloaded instance restores persisted state', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final first = SaintAppSettingsNotifier();
      await settle();
      await first.toggleFavorite('st-george');
      await first.addRecent('st-george');
      await first.addRecent('st-michael');

      final second = SaintAppSettingsNotifier();
      await settle();

      expect(second.state.favoriteSlugs, <String>['st-george']);
      expect(second.state.recentSlugs, <String>['st-michael', 'st-george']);
    });
    test('mutation racing the async load is never clobbered or lost', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        SaintAppSettingsNotifier.storageKey:
            '{"favoriteSlugs":["st-joan"],"recentSlugs":["st-joan"]}',
      });
      final notifier = SaintAppSettingsNotifier();

      // Fire-and-forget mutations BEFORE the un-awaited load resolves,
      // exactly like UI taps racing app startup.
      final firstMutation = notifier.toggleFavorite('st-peter');
      final secondMutation = notifier.addRecent('st-peter');
      await firstMutation;
      await secondMutation;
      await settle();

      // Both the user's tap and the stored favorite are present (union).
      expect(notifier.isFavorite('st-peter'), isTrue);
      expect(notifier.isFavorite('st-joan'), isTrue);
      // Recents: current first, then loaded history.
      expect(notifier.state.recentSlugs, <String>['st-peter', 'st-joan']);

      // The merged state is re-persisted so disk keeps the union too.
      final prefs = await SharedPreferences.getInstance();
      final stored =
          json.decode(
                prefs.getString(SaintAppSettingsNotifier.storageKey) ?? '{}',
              )
              as Map<String, dynamic>;
      expect(
        (stored['favoriteSlugs'] as List<dynamic>),
        containsAll(<String>['st-peter', 'st-joan']),
      );
    });

    test(
      'two rapid toggles persist in order so disk ends with final state',
      () async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        final notifier = SaintAppSettingsNotifier();
        await settle();

        // Fire-and-forget, no awaits between: overlapping write requests.
        final firstMutation = notifier.toggleFavorite('st-a');
        final secondMutation = notifier.toggleFavorite('st-b');
        await firstMutation;
        await secondMutation;

        final prefs = await SharedPreferences.getInstance();
        final stored =
            json.decode(
                  prefs.getString(SaintAppSettingsNotifier.storageKey) ?? '{}',
                )
                as Map<String, dynamic>;
        expect(stored['favoriteSlugs'], notifier.state.favoriteSlugs);
        expect(stored['favoriteSlugs'], <String>['st-a', 'st-b']);
      },
    );

    test(
      'corrupt stored JSON falls back to defaults without throwing',
      () async {
        SharedPreferences.setMockInitialValues(<String, Object>{
          SaintAppSettingsNotifier.storageKey: 'not json',
        });

        final notifier = SaintAppSettingsNotifier();
        await settle();

        expect(notifier.state.favoriteSlugs, isEmpty);
        expect(notifier.state.recentSlugs, isEmpty);
        expect(notifier.isFavorite('st-anything'), isFalse);
      },
    );
  });

  group('SaintAppSettings', () {
    test('defaults are empty and toJson/fromJson round-trip', () {
      final settings = SaintAppSettings.defaults();
      expect(settings.favoriteSlugs, isEmpty);
      expect(settings.recentSlugs, isEmpty);

      final restored = SaintAppSettings.fromJson(
        settings
            .copyWith(favoriteSlugs: ['x'], recentSlugs: ['y', 'x'])
            .toJson(),
      );
      expect(restored.favoriteSlugs, <String>['x']);
      expect(restored.recentSlugs, <String>['y', 'x']);
      expect(restored.isFavorite('x'), isTrue);
    });
  });
}
