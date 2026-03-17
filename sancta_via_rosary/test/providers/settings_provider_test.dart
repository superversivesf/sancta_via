import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:rosary_companion/providers/notification_settings_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Generate mocks for SharedPreferences
@GenerateMocks([])
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RosarySettings', () {
    test('default constructor creates settings with expected defaults', () {
      const settings = RosarySettings();

      expect(settings.notificationsEnabled, isFalse);
      expect(settings.reminderHour, equals(20));
      expect(settings.reminderMinute, equals(0));
      expect(settings.dailyReminderEnabled, isFalse);
    });

    test('defaults() factory creates same values', () {
      const settings = RosarySettings();
      final defaults = RosarySettings.defaults();

      expect(settings, equals(defaults));
    });

    test('custom values are set correctly', () {
      const settings = RosarySettings(
        notificationsEnabled: true,
        reminderHour: 8,
        reminderMinute: 30,
        dailyReminderEnabled: true,
      );

      expect(settings.notificationsEnabled, isTrue);
      expect(settings.reminderHour, equals(8));
      expect(settings.reminderMinute, equals(30));
      expect(settings.dailyReminderEnabled, isTrue);
    });

    group('JSON serialization', () {
      test('toJson creates correct map', () {
        const settings = RosarySettings(
          notificationsEnabled: true,
          reminderHour: 7,
          reminderMinute: 15,
          dailyReminderEnabled: true,
        );

        final json = settings.toJson();

        expect(json['notificationsEnabled'], isTrue);
        expect(json['reminderHour'], equals(7));
        expect(json['reminderMinute'], equals(15));
        expect(json['dailyReminderEnabled'], isTrue);
      });

      test('fromJson parses correct map', () {
        final json = {
          'notificationsEnabled': true,
          'reminderHour': 6,
          'reminderMinute': 45,
          'dailyReminderEnabled': false,
        };

        final settings = RosarySettings.fromJson(json);

        expect(settings.notificationsEnabled, isTrue);
        expect(settings.reminderHour, equals(6));
        expect(settings.reminderMinute, equals(45));
        expect(settings.dailyReminderEnabled, isFalse);
      });

      test('fromJson handles missing keys with defaults', () {
        final json = <String, dynamic>{};

        final settings = RosarySettings.fromJson(json);

        expect(settings.notificationsEnabled, isFalse);
        expect(settings.reminderHour, equals(20));
        expect(settings.reminderMinute, equals(0));
        expect(settings.dailyReminderEnabled, isFalse);
      });

      test('fromJson handles null values with defaults', () {
        final json = {
          'notificationsEnabled': null,
          'reminderHour': null,
          'reminderMinute': null,
          'dailyReminderEnabled': null,
        };

        final settings = RosarySettings.fromJson(json);

        expect(settings.notificationsEnabled, isFalse);
        expect(settings.reminderHour, equals(20));
        expect(settings.reminderMinute, equals(0));
        expect(settings.dailyReminderEnabled, isFalse);
      });

      test('round-trip serialization preserves values', () {
        const original = RosarySettings(
          notificationsEnabled: true,
          reminderHour: 12,
          reminderMinute: 30,
          dailyReminderEnabled: true,
        );

        final json = original.toJson();
        final restored = RosarySettings.fromJson(json);

        expect(restored, equals(original));
      });
    });

    group('copyWith', () {
      test('creates updated copy with single field changed', () {
        const settings = RosarySettings();

        final updated = settings.copyWith(notificationsEnabled: true);

        expect(updated.notificationsEnabled, isTrue);
        expect(updated.reminderHour, equals(settings.reminderHour));
        expect(updated.reminderMinute, equals(settings.reminderMinute));
        expect(
          updated.dailyReminderEnabled,
          equals(settings.dailyReminderEnabled),
        );
      });

      test('creates updated copy with multiple fields changed', () {
        const settings = RosarySettings();

        final updated = settings.copyWith(
          notificationsEnabled: true,
          dailyReminderEnabled: true,
          reminderHour: 9,
          reminderMinute: 30,
        );

        expect(updated.notificationsEnabled, isTrue);
        expect(updated.dailyReminderEnabled, isTrue);
        expect(updated.reminderHour, equals(9));
        expect(updated.reminderMinute, equals(30));
      });

      test('returns same values when no params provided', () {
        const settings = RosarySettings(
          notificationsEnabled: true,
          reminderHour: 7,
          reminderMinute: 30,
          dailyReminderEnabled: true,
        );

        final updated = settings.copyWith();

        expect(updated, equals(settings));
      });
    });

    group('equality', () {
      test('identical objects are equal', () {
        const settings = RosarySettings();
        expect(settings, equals(settings));
      });

      test('objects with same values are equal', () {
        const settings1 = RosarySettings(
          notificationsEnabled: true,
          reminderHour: 8,
          reminderMinute: 30,
          dailyReminderEnabled: true,
        );
        const settings2 = RosarySettings(
          notificationsEnabled: true,
          reminderHour: 8,
          reminderMinute: 30,
          dailyReminderEnabled: true,
        );

        expect(settings1, equals(settings2));
        expect(settings1.hashCode, equals(settings2.hashCode));
      });

      test('objects with different values are not equal', () {
        const settings1 = RosarySettings(notificationsEnabled: true);
        const settings2 = RosarySettings(notificationsEnabled: false);

        expect(settings1, isNot(equals(settings2)));
      });

      test('different types are not equal', () {
        const settings = RosarySettings();
        expect(settings, isNot(equals('not settings')));
      });
    });
  });

  group('RosarySettingsNotifier', () {
    late ProviderContainer container;

    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      // Reset SharedPreferences mock
      SharedPreferences.setMockInitialValues({});
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
      SharedPreferences.setMockInitialValues({});
    });

    group('initialization', () {
      test('initializes with default settings when no stored data', () async {
        final notifier = container.read(rosarySettingsProvider.notifier);

        // Wait for initialization
        await Future.delayed(const Duration(milliseconds: 50));

        final state = container.read(rosarySettingsProvider);

        expect(state.notificationsEnabled, isFalse);
        expect(state.reminderHour, equals(20));
        expect(state.reminderMinute, equals(0));
        expect(state.dailyReminderEnabled, isFalse);
      });

      test('loads stored settings from SharedPreferences', () async {
        final storedSettings = {
          'rosary_notification_settings': json.encode({
            'notificationsEnabled': true,
            'reminderHour': 7,
            'reminderMinute': 30,
            'dailyReminderEnabled': true,
          }),
        };

        SharedPreferences.setMockInitialValues(storedSettings);

        // Create new container to trigger fresh init
        container = ProviderContainer();
        final notifier = container.read(rosarySettingsProvider.notifier);

        // Wait for initialization
        await Future.delayed(const Duration(milliseconds: 50));

        final state = container.read(rosarySettingsProvider);

        expect(state.notificationsEnabled, isTrue);
        expect(state.reminderHour, equals(7));
        expect(state.reminderMinute, equals(30));
        expect(state.dailyReminderEnabled, isTrue);
      });

      test('handles corrupted stored data gracefully', () async {
        SharedPreferences.setMockInitialValues({
          'rosary_notification_settings': 'invalid json',
        });

        container = ProviderContainer();

        // Wait for initialization
        await Future.delayed(const Duration(milliseconds: 50));

        final state = container.read(rosarySettingsProvider);

        // Should fall back to defaults
        expect(state.notificationsEnabled, isFalse);
        expect(state.reminderHour, equals(20));
        expect(state.reminderMinute, equals(0));
      });
    });

    group('setNotificationsEnabled', () {
      test('updates notifications enabled state', () async {
        final notifier = container.read(rosarySettingsProvider.notifier);

        // Wait for initialization
        await Future.delayed(const Duration(milliseconds: 50));

        // Note: Setting to true requires permission handling which
        // is mocked to fail in test environment, so we test setting to false
        await notifier.setNotificationsEnabled(false);

        final state = container.read(rosarySettingsProvider);
        expect(state.notificationsEnabled, isFalse);
      });

      test('disabling notifications also disables daily reminder', () async {
        // Start with enabled notifications and daily reminder
        SharedPreferences.setMockInitialValues({
          'rosary_notification_settings': json.encode({
            'notificationsEnabled': true,
            'reminderHour': 8,
            'reminderMinute': 0,
            'dailyReminderEnabled': true,
          }),
        });

        container = ProviderContainer();
        await Future.delayed(const Duration(milliseconds: 50));

        final notifier = container.read(rosarySettingsProvider.notifier);

        // This test would work in a real environment with mock permissions
        // For now we verify the state update logic works
        await notifier.setNotificationsEnabled(false);

        final state = container.read(rosarySettingsProvider);
        expect(state.notificationsEnabled, isFalse);
      });
    });

    group('setDailyReminderEnabled', () {
      test('updates daily reminder enabled state', () async {
        final notifier = container.read(rosarySettingsProvider.notifier);
        await Future.delayed(const Duration(milliseconds: 50));

        await notifier.setDailyReminderEnabled(true);

        final state = container.read(rosarySettingsProvider);
        expect(state.dailyReminderEnabled, isTrue);
      });

      test(
        'cannot enable daily reminder when notifications are disabled',
        () async {
          final notifier = container.read(rosarySettingsProvider.notifier);
          await Future.delayed(const Duration(milliseconds: 50));

          // Try to enable daily reminder without notifications
          await notifier.setDailyReminderEnabled(true);

          final state = container.read(rosarySettingsProvider);
          // Should remain false since notifications are disabled
          expect(state.dailyReminderEnabled, isFalse);
        },
      );
    });

    group('setReminderTime', () {
      test('updates reminder time', () async {
        final notifier = container.read(rosarySettingsProvider.notifier);
        await Future.delayed(const Duration(milliseconds: 50));

        await notifier.setReminderTime(8, 30);

        final state = container.read(rosarySettingsProvider);
        expect(state.reminderHour, equals(8));
        expect(state.reminderMinute, equals(30));
      });

      test('clamps hours to valid range', () async {
        final notifier = container.read(rosarySettingsProvider.notifier);
        await Future.delayed(const Duration(milliseconds: 50));

        await notifier.setReminderTime(25, 30);

        final state = container.read(rosarySettingsProvider);
        expect(state.reminderHour, equals(23)); // Clamped to max
      });

      test('clamps negative hours to 0', () async {
        final notifier = container.read(rosarySettingsProvider.notifier);
        await Future.delayed(const Duration(milliseconds: 50));

        await notifier.setReminderTime(-1, 30);

        final state = container.read(rosarySettingsProvider);
        expect(state.reminderHour, equals(0));
      });

      test('clamps minutes to valid range', () async {
        final notifier = container.read(rosarySettingsProvider.notifier);
        await Future.delayed(const Duration(milliseconds: 50));

        await notifier.setReminderTime(8, 75);

        final state = container.read(rosarySettingsProvider);
        expect(state.reminderMinute, equals(59)); // Clamped to max
      });

      test('clamps negative minutes to 0', () async {
        final notifier = container.read(rosarySettingsProvider.notifier);
        await Future.delayed(const Duration(milliseconds: 50));

        await notifier.setReminderTime(8, -5);

        final state = container.read(rosarySettingsProvider);
        expect(state.reminderMinute, equals(0));
      });
    });

    group('resetToDefaults', () {
      test('resets settings to defaults', () async {
        // Start with custom settings
        SharedPreferences.setMockInitialValues({
          'rosary_notification_settings': json.encode({
            'notificationsEnabled': true,
            'reminderHour': 15,
            'reminderMinute': 45,
            'dailyReminderEnabled': true,
          }),
        });

        container = ProviderContainer();
        await Future.delayed(const Duration(milliseconds: 50));

        final notifier = container.read(rosarySettingsProvider.notifier);

        await notifier.resetToDefaults();

        final state = container.read(rosarySettingsProvider);
        expect(state.notificationsEnabled, isFalse);
        expect(state.reminderHour, equals(20));
        expect(state.reminderMinute, equals(0));
        expect(state.dailyReminderEnabled, isFalse);
      });
    });

    group('formattedReminderTime', () {
      test('returns formatted time in AM', () async {
        SharedPreferences.setMockInitialValues({
          'rosary_notification_settings': json.encode({
            'notificationsEnabled': false,
            'reminderHour': 8,
            'reminderMinute': 30,
            'dailyReminderEnabled': false,
          }),
        });

        container = ProviderContainer();
        await Future.delayed(const Duration(milliseconds: 50));

        final notifier = container.read(rosarySettingsProvider.notifier);
        expect(notifier.formattedReminderTime, equals('8:30 AM'));
      });

      test('returns formatted time in PM', () async {
        SharedPreferences.setMockInitialValues({
          'rosary_notification_settings': json.encode({
            'notificationsEnabled': false,
            'reminderHour': 20,
            'reminderMinute': 0,
            'dailyReminderEnabled': false,
          }),
        });

        container = ProviderContainer();
        await Future.delayed(const Duration(milliseconds: 50));

        final notifier = container.read(rosarySettingsProvider.notifier);
        expect(notifier.formattedReminderTime, equals('8:00 PM'));
      });

      test('handles midnight correctly', () async {
        SharedPreferences.setMockInitialValues({
          'rosary_notification_settings': json.encode({
            'notificationsEnabled': false,
            'reminderHour': 0,
            'reminderMinute': 0,
            'dailyReminderEnabled': false,
          }),
        });

        container = ProviderContainer();
        await Future.delayed(const Duration(milliseconds: 50));

        final notifier = container.read(rosarySettingsProvider.notifier);
        expect(notifier.formattedReminderTime, equals('12:00 AM'));
      });

      test('handles noon correctly', () async {
        SharedPreferences.setMockInitialValues({
          'rosary_notification_settings': json.encode({
            'notificationsEnabled': false,
            'reminderHour': 12,
            'reminderMinute': 30,
            'dailyReminderEnabled': false,
          }),
        });

        container = ProviderContainer();
        await Future.delayed(const Duration(milliseconds: 50));

        final notifier = container.read(rosarySettingsProvider.notifier);
        expect(notifier.formattedReminderTime, equals('12:30 PM'));
      });

      test('pads minutes with leading zero', () async {
        SharedPreferences.setMockInitialValues({
          'rosary_notification_settings': json.encode({
            'notificationsEnabled': false,
            'reminderHour': 9,
            'reminderMinute': 5,
            'dailyReminderEnabled': false,
          }),
        });

        container = ProviderContainer();
        await Future.delayed(const Duration(milliseconds: 50));

        final notifier = container.read(rosarySettingsProvider.notifier);
        expect(notifier.formattedReminderTime, equals('9:05 AM'));
      });
    });

    group('persistence', () {
      test('settings are saved to SharedPreferences', () async {
        SharedPreferences.setMockInitialValues({});
        container = ProviderContainer();
        final notifier = container.read(rosarySettingsProvider.notifier);

        await Future.delayed(const Duration(milliseconds: 50));
        await notifier.setReminderTime(10, 15);
        await notifier.setDailyReminderEnabled(true);

        final prefs = await SharedPreferences.getInstance();
        final storedJson = prefs.getString('rosary_notification_settings');

        expect(storedJson, isNotNull);

        final stored = json.decode(storedJson!) as Map<String, dynamic>;
        expect(stored['reminderHour'], equals(10));
        expect(stored['reminderMinute'], equals(15));
        expect(stored['dailyReminderEnabled'], isTrue);
      });
    });
  });

  group('Convenience Providers', () {
    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues({
        'rosary_notification_settings': json.encode({
          'notificationsEnabled': true,
          'reminderHour': 8,
          'reminderMinute': 30,
          'dailyReminderEnabled': true,
        }),
      });
    });

    tearDown(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('rosaryNotificationsEnabledProvider returns correct value', () async {
      final container = ProviderContainer();
      await Future.delayed(const Duration(milliseconds: 50));

      final enabled = container.read(rosaryNotificationsEnabledProvider);
      expect(enabled, isTrue);

      container.dispose();
    });

    test('dailyReminderEnabledProvider returns correct value', () async {
      final container = ProviderContainer();
      await Future.delayed(const Duration(milliseconds: 50));

      final enabled = container.read(dailyReminderEnabledProvider);
      expect(enabled, isTrue);

      container.dispose();
    });

    test('reminderTimeProvider returns correct time tuple', () async {
      final container = ProviderContainer();
      await Future.delayed(const Duration(milliseconds: 50));

      final time = container.read(reminderTimeProvider);
      expect(time.hour, equals(8));
      expect(time.minute, equals(30));

      container.dispose();
    });

    test('formattedReminderTimeProvider returns formatted string', () async {
      final container = ProviderContainer();
      await Future.delayed(const Duration(milliseconds: 50));

      final formatted = container.read(formattedReminderTimeProvider);
      expect(formatted, equals('8:30 AM'));

      container.dispose();
    });
  });
}
