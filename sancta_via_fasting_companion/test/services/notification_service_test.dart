import 'package:flutter_test/flutter_test.dart';
import 'package:sancta_via_fasting_companion/models/fast_session.dart';
import 'package:sancta_via_fasting_companion/models/fast_status.dart';
import 'package:sancta_via_fasting_companion/providers/settings_provider.dart';
import 'package:sancta_via_fasting_companion/services/notification_service.dart';

void main() {
  group('NotificationService', () {
    late NotificationService service;
    late FastingSettings settings;

    setUp(() {
      settings = const FastingSettings(
        notificationsEnabled: true,
        hourlyReminders: true,
        milestoneReminders: true,
        completionReminders: true,
      );
      service = NotificationService(settings);
    });

    test('should initialize successfully', () async {
      final result = await service.initialize();
      expect(result, isTrue);
    });

    test('should request permissions based on settings', () async {
      final result = await service.requestPermissions();
      expect(result, isTrue);
    });

    test('should not request permissions when disabled', () async {
      final disabledSettings = const FastingSettings(
        notificationsEnabled: false,
      );
      final disabledService = NotificationService(disabledSettings);

      final result = await disabledService.requestPermissions();
      expect(result, isFalse);
    });

    test('should schedule notifications for active fast', () async {
      final session = FastSession(
        id: 'test_session',
        fastTypeId: 'intermittent_16_8',
        startTime: DateTime.now(),
        targetDurationMinutes: 960, // 16 hours
        status: FastStatus.active,
      );

      await service.scheduleNotificationsForFast(session);

      final scheduled = service.getScheduledNotifications();
      expect(scheduled.isNotEmpty, isTrue);
    });

    test('should not schedule when notifications disabled', () async {
      final disabledSettings = const FastingSettings(
        notificationsEnabled: false,
      );
      final disabledService = NotificationService(disabledSettings);

      final session = FastSession(
        id: 'test_session',
        fastTypeId: 'intermittent_16_8',
        startTime: DateTime.now(),
        targetDurationMinutes: 960,
        status: FastStatus.active,
      );

      await disabledService.scheduleNotificationsForFast(session);

      final scheduled = disabledService.getScheduledNotifications();
      expect(scheduled.isEmpty, isTrue);
    });

    test('should schedule hourly reminders', () async {
      final session = FastSession(
        id: 'test_session',
        fastTypeId: 'intermittent_16_8',
        startTime: DateTime.now(),
        targetDurationMinutes: 960, // 16 hours
        status: FastStatus.active,
      );

      await service.scheduleNotificationsForFast(session);

      final scheduled = service.getScheduledNotifications();
      final hourlyNotifications = scheduled.where(
        (n) => n.type == NotificationType.hourly,
      );

      expect(hourlyNotifications.isNotEmpty, isTrue);
    });

    test('should not schedule hourly when disabled', () async {
      final noHourlySettings = const FastingSettings(
        notificationsEnabled: true,
        hourlyReminders: false,
        milestoneReminders: true,
        completionReminders: true,
      );
      final noHourlyService = NotificationService(noHourlySettings);

      final session = FastSession(
        id: 'test_session',
        fastTypeId: 'intermittent_16_8',
        startTime: DateTime.now(),
        targetDurationMinutes: 960,
        status: FastStatus.active,
      );

      await noHourlyService.scheduleNotificationsForFast(session);

      final scheduled = noHourlyService.getScheduledNotifications();
      final hourlyNotifications = scheduled.where(
        (n) => n.type == NotificationType.hourly,
      );

      expect(hourlyNotifications.isEmpty, isTrue);
    });

    test('should schedule milestone reminders at 25%, 50%, 75%', () async {
      final futureStart = DateTime.now().add(const Duration(minutes: 10));
      final session = FastSession(
        id: 'test_session',
        fastTypeId: 'intermittent_16_8',
        startTime: futureStart,
        targetDurationMinutes: 960,
        status: FastStatus.active,
      );

      await service.scheduleNotificationsForFast(session);

      final scheduled = service.getScheduledNotifications();
      final milestoneNotifications = scheduled.where(
        (n) => n.type == NotificationType.milestone,
      );

      // Should have 3 milestones (25%, 50%, 75%)
      expect(milestoneNotifications.length, 3);
    });

    test('should not schedule past milestones', () async {
      // Start time 10 hours ago (past 25% and 50% of a 16-hour fast)
      final pastStart = DateTime.now().subtract(const Duration(hours: 10));
      final session = FastSession(
        id: 'test_session',
        fastTypeId: 'intermittent_16_8',
        startTime: pastStart,
        targetDurationMinutes: 960,
        status: FastStatus.active,
      );

      await service.scheduleNotificationsForFast(session);

      final scheduled = service.getScheduledNotifications();
      final milestoneNotifications = scheduled.where(
        (n) => n.type == NotificationType.milestone,
      );

      // Should only have 75% milestone (25% and 50% are in the past)
      expect(milestoneNotifications.length, lessThan(3));
    });

    test('should schedule completion reminder', () async {
      final futureStart = DateTime.now().add(const Duration(minutes: 10));
      final session = FastSession(
        id: 'test_session',
        fastTypeId: 'intermittent_16_8',
        startTime: futureStart,
        targetDurationMinutes: 960,
        status: FastStatus.active,
      );

      await service.scheduleNotificationsForFast(session);

      final scheduled = service.getScheduledNotifications();
      final completionNotifications = scheduled.where(
        (n) => n.type == NotificationType.completion,
      );

      expect(completionNotifications.length, 1);
    });

    test('should not schedule completion in the past', () async {
      // Fast that ended 2 hours ago
      final pastStart = DateTime.now().subtract(const Duration(hours: 18));
      final session = FastSession(
        id: 'test_session',
        fastTypeId: 'intermittent_16_8',
        startTime: pastStart,
        targetDurationMinutes: 960,
        status: FastStatus.active,
      );

      await service.scheduleNotificationsForFast(session);

      final scheduled = service.getScheduledNotifications();
      final completionNotifications = scheduled.where(
        (n) => n.type == NotificationType.completion,
      );

      expect(completionNotifications.isEmpty, isTrue);
    });

    test('should cancel all notifications', () async {
      final session = FastSession(
        id: 'test_session',
        fastTypeId: 'intermittent_16_8',
        startTime: DateTime.now(),
        targetDurationMinutes: 960,
        status: FastStatus.active,
      );

      await service.scheduleNotificationsForFast(session);
      expect(service.getScheduledNotifications().isNotEmpty, isTrue);

      await service.cancelAllNotifications();
      expect(service.getScheduledNotifications().isEmpty, isTrue);
    });

    test('should cancel notifications for specific session', () async {
      final session1 = FastSession(
        id: 'session_1',
        fastTypeId: 'intermittent_16_8',
        startTime: DateTime.now(),
        targetDurationMinutes: 960,
        status: FastStatus.active,
      );

      await service.scheduleNotificationsForFast(session1);
      final initialCount = service.getScheduledNotifications().length;

      await service.cancelNotificationsForFast('session_1');
      expect(service.getScheduledNotifications().isEmpty, isTrue);

      // Verify we had notifications before
      expect(initialCount, greaterThan(0));
    });

    test('should replace notifications when scheduling new fast', () async {
      final session1 = FastSession(
        id: 'session_1',
        fastTypeId: 'intermittent_16_8',
        startTime: DateTime.now(),
        targetDurationMinutes: 960,
        status: FastStatus.active,
      );

      await service.scheduleNotificationsForFast(session1);
      final firstCount = service.getScheduledNotifications().length;

      final session2 = FastSession(
        id: 'session_2',
        fastTypeId: 'daily_24hr',
        startTime: DateTime.now(),
        targetDurationMinutes: 1440,
        status: FastStatus.active,
      );

      await service.scheduleNotificationsForFast(session2);
      final secondCount = service.getScheduledNotifications().length;

      // Should have cancelled previous and scheduled new
      final scheduled = service.getScheduledNotifications();
      final session1Notifications = scheduled.where(
        (n) => n.id.contains('session_1'),
      );
      final session2Notifications = scheduled.where(
        (n) => n.id.contains('session_2'),
      );

      expect(session1Notifications.isEmpty, isTrue);
      expect(session2Notifications.isNotEmpty, isTrue);
      expect(firstCount, greaterThan(0));
      expect(secondCount, greaterThan(0));
    });

    test('notification IDs should be unique', () async {
      final session = FastSession(
        id: 'test_session',
        fastTypeId: 'intermittent_16_8',
        startTime: DateTime.now(),
        targetDurationMinutes: 960,
        status: FastStatus.active,
      );

      await service.scheduleNotificationsForFast(session);

      final scheduled = service.getScheduledNotifications();
      final ids = scheduled.map((n) => n.id).toSet();

      // All IDs should be unique
      expect(ids.length, scheduled.length);
    });

    test('notification times should be in the future', () async {
      final futureStart = DateTime.now().add(const Duration(minutes: 10));
      final session = FastSession(
        id: 'test_session',
        fastTypeId: 'intermittent_16_8',
        startTime: futureStart,
        targetDurationMinutes: 960,
        status: FastStatus.active,
      );

      await service.scheduleNotificationsForFast(session);

      final scheduled = service.getScheduledNotifications();
      final now = DateTime.now();

      for (final notification in scheduled) {
        expect(notification.scheduledTime.isAfter(now), isTrue);
      }
    });
  });
}
