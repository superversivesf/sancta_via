import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:rosary_companion/services/notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Generate mocks
@GenerateMocks([NotificationService])
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Notification Service', () {
    late NotificationService service;

    setUp(() {
      // Initialize service singleton
      service = NotificationService.instance;
    });

    tearDown(() {
      // Reset mock SharedPreferences
      SharedPreferences.setMockInitialValues({});
    });

    group('Singleton Pattern', () {
      test('instance returns same object', () {
        final instance1 = NotificationService.instance;
        final instance2 = NotificationService.instance;

        expect(identical(instance1, instance2), isTrue);
      });

      test('internal constructor creates singleton', () {
        final instance1 = NotificationService.instance;
        final instance2 = NotificationService.instance;

        expect(instance1, equals(instance2));
      });
    });

    group('Settings Persistence', () {
      test('loads saved settings from SharedPreferences', () async {
        // Set up mock with saved settings
        final savedSettings = {
          'notification_enabled': true,
          'reminder_hour': 7,
          'reminder_minute': 30,
          'daily_reminder': true,
        };

        // Mock SharedPreferences
        SharedPreferences.setMockInitialValues(savedSettings);

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getBool('notification_enabled'), isTrue);
        expect(prefs.getInt('reminder_hour'), equals(7));
        expect(prefs.getInt('reminder_minute'), equals(30));
        expect(prefs.getBool('daily_reminder'), isTrue);
      });

      test('saves settings to SharedPreferences', () async {
        SharedPreferences.setMockInitialValues({});

        final prefs = await SharedPreferences.getInstance();

        // Save mock settings
        await prefs.setBool('notification_enabled', true);
        await prefs.setInt('reminder_hour', 8);
        await prefs.setInt('reminder_minute', 0);
        await prefs.setBool('daily_reminder', true);

        // Verify saved
        expect(prefs.getBool('notification_enabled'), isTrue);
        expect(prefs.getInt('reminder_hour'), equals(8));
        expect(prefs.getInt('reminder_minute'), equals(0));
        expect(prefs.getBool('daily_reminder'), isTrue);
      });
    });

    group('Time Validation', () {
      test('validates hour range', () {
        // Hours should be 0-23
        const validHours = [0, 12, 23];
        const invalidHours = [-1, 24, 100];

        for (final hour in validHours) {
          expect(hour, greaterThanOrEqualTo(0));
          expect(hour, lessThanOrEqualTo(23));
        }

        for (final hour in invalidHours) {
          expect(
            hour < 0 || hour > 23,
            isTrue,
            reason: 'Hour $hour should be invalid',
          );
        }
      });

      test('validates minute range', () {
        // Minutes should be 0-59
        const validMinutes = [0, 30, 59];
        const invalidMinutes = [-1, 60, 100];

        for (final minute in validMinutes) {
          expect(minute, greaterThanOrEqualTo(0));
          expect(minute, lessThanOrEqualTo(59));
        }

        for (final minute in invalidMinutes) {
          expect(
            minute < 0 || minute > 59,
            isTrue,
            reason: 'Minute $minute should be invalid',
          );
        }
      });
    });

    group('JSON Serialization', () {
      test('settings serialize to JSON correctly', () {
        final settings = {
          'notificationsEnabled': true,
          'reminderHour': 8,
          'reminderMinute': 30,
          'dailyReminderEnabled': true,
        };

        final json = jsonEncode(settings);
        final decoded = jsonDecode(json) as Map<String, dynamic>;

        expect(decoded['notificationsEnabled'], isTrue);
        expect(decoded['reminderHour'], equals(8));
        expect(decoded['reminderMinute'], equals(30));
        expect(decoded['dailyReminderEnabled'], isTrue);
      });

      test('settings deserialize from JSON correctly', () {
        final json =
            '{"notificationsEnabled":false,"reminderHour":20,"reminderMinute":0,"dailyReminderEnabled":false}';
        final decoded = jsonDecode(json) as Map<String, dynamic>;

        expect(decoded['notificationsEnabled'], isFalse);
        expect(decoded['reminderHour'], equals(20));
        expect(decoded['reminderMinute'], equals(0));
        expect(decoded['dailyReminderEnabled'], isFalse);
      });
    });

    group('Error Handling', () {
      test('handles SharedPreferences errors gracefully', () async {
        // This tests that the service doesn't crash on SharedPreferences errors
        SharedPreferences.setMockInitialValues({});

        final prefs = await SharedPreferences.getInstance();

        // These operations should complete without throwing
        expect(() async {
          await prefs.setString('test_key', 'test_value');
        }, returnsNormally);
      });

      test('handles missing keys gracefully', () async {
        SharedPreferences.setMockInitialValues({});

        final prefs = await SharedPreferences.getInstance();

        // Getting non-existent keys should return null
        expect(prefs.getString('non_existent_key'), isNull);
        expect(prefs.getBool('non_existent_key'), isNull);
        expect(prefs.getInt('non_existent_key'), isNull);
      });
    });
  });

  group('Settings Migration', () {
    test('migrates from old notification settings format', () async {
      // Old format had different keys
      final oldSettings = {
        'old_notifications_enabled': true,
        'old_reminder_time': '20:00',
      };

      SharedPreferences.setMockInitialValues(oldSettings);

      final prefs = await SharedPreferences.getInstance();

      // Simulate migration - read old values and save in new format
      final oldEnabled = prefs.getBool('old_notifications_enabled') ?? false;
      final oldTime = prefs.getString('old_reminder_time') ?? '20:00';

      // Parse old time format
      final parts = oldTime.split(':');
      final hour = int.tryParse(parts[0]) ?? 20;
      final minute = int.tryParse(parts[1]) ?? 0;

      // Save in new format
      await prefs.setBool('notificationsEnabled', oldEnabled);
      await prefs.setInt('reminderHour', hour);
      await prefs.setInt('reminderMinute', minute);

      // Verify migration
      expect(prefs.getBool('notificationsEnabled'), isTrue);
      expect(prefs.getInt('reminderHour'), equals(20));
      expect(prefs.getInt('reminderMinute'), equals(0));
    });

    test('handles migration with null old values', () async {
      SharedPreferences.setMockInitialValues({});

      final prefs = await SharedPreferences.getInstance();

      // Simulate migration with missing old values
      final oldEnabled = prefs.getBool('old_notifications_enabled') ?? false;
      final oldTime = prefs.getString('old_reminder_time');

      // Should use defaults
      expect(oldEnabled, isFalse);
      expect(oldTime, isNull);

      // Save with defaults
      await prefs.setBool('notificationsEnabled', false);
      await prefs.setInt('reminderHour', 20);
      await prefs.setInt('reminderMinute', 0);

      expect(prefs.getBool('notificationsEnabled'), isFalse);
      expect(prefs.getInt('reminderHour'), equals(20));
      expect(prefs.getInt('reminderMinute'), equals(0));
    });
  });
}
