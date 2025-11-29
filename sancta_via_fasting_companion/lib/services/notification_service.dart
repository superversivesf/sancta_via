import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/fast_session.dart';
import '../providers/settings_provider.dart';

/// Types of notifications that can be scheduled
enum NotificationType {
  hourly,
  milestone,
  completion,
}

/// Scheduled notification information
class ScheduledNotification {
  final String id;
  final NotificationType type;
  final DateTime scheduledTime;
  final String title;
  final String body;

  const ScheduledNotification({
    required this.id,
    required this.type,
    required this.scheduledTime,
    required this.title,
    required this.body,
  });
}

/// Service for managing fast-related notifications
class NotificationService {
  final FastingSettings settings;
  final List<ScheduledNotification> _scheduledNotifications = [];

  NotificationService(this.settings);

  /// Initialize notification service and request permissions
  Future<bool> initialize() async {
    // TODO: Phase 3 - Initialize flutter_local_notifications
    // For now, return true to indicate ready
    return true;
  }

  /// Request notification permissions from the user
  Future<bool> requestPermissions() async {
    // TODO: Phase 3 - Request actual platform permissions
    // For now, return settings value
    return settings.notificationsEnabled;
  }

  /// Schedule all notifications for an active fast session
  Future<void> scheduleNotificationsForFast(FastSession session) async {
    if (!settings.notificationsEnabled) {
      return;
    }

    // Cancel any existing notifications first
    await cancelAllNotifications();

    // Schedule hourly reminders if enabled
    if (settings.hourlyReminders) {
      await _scheduleHourlyReminders(session);
    }

    // Schedule milestone reminders if enabled
    if (settings.milestoneReminders) {
      await _scheduleMilestoneReminders(session);
    }

    // Schedule completion reminder if enabled
    if (settings.completionReminders) {
      await _scheduleCompletionReminder(session);
    }
  }

  /// Schedule hourly reminders during the fast
  Future<void> _scheduleHourlyReminders(FastSession session) async {
    final now = DateTime.now();
    final endTime = session.startTime.add(
      Duration(minutes: session.targetDurationMinutes),
    );

    // Schedule a notification for each hour until completion
    DateTime nextHour = _getNextHourMark(session.startTime, now);

    while (nextHour.isBefore(endTime)) {
      final elapsedHours = nextHour.difference(session.startTime).inHours;

      final notification = ScheduledNotification(
        id: 'hourly_${session.id}_$elapsedHours',
        type: NotificationType.hourly,
        scheduledTime: nextHour,
        title: 'Fasting Progress',
        body: '$elapsedHours ${elapsedHours == 1 ? 'hour' : 'hours'} into your fast. Keep going!',
      );

      await _scheduleNotification(notification);
      nextHour = nextHour.add(const Duration(hours: 1));
    }
  }

  /// Schedule milestone reminders at significant points (25%, 50%, 75%)
  Future<void> _scheduleMilestoneReminders(FastSession session) async {
    final milestones = [0.25, 0.50, 0.75];
    final totalDuration = Duration(minutes: session.targetDurationMinutes);

    for (final milestone in milestones) {
      final milestoneTime = session.startTime.add(
        Duration(minutes: (totalDuration.inMinutes * milestone).round()),
      );

      // Only schedule if milestone is in the future
      if (milestoneTime.isAfter(DateTime.now())) {
        final percentage = (milestone * 100).toInt();
        final notification = ScheduledNotification(
          id: 'milestone_${session.id}_$percentage',
          type: NotificationType.milestone,
          scheduledTime: milestoneTime,
          title: 'Milestone Reached!',
          body: 'You\'re $percentage% through your fast. Well done!',
        );

        await _scheduleNotification(notification);
      }
    }
  }

  /// Schedule reminder when fast target is reached
  Future<void> _scheduleCompletionReminder(FastSession session) async {
    final completionTime = session.startTime.add(
      Duration(minutes: session.targetDurationMinutes),
    );

    // Only schedule if completion is in the future
    if (completionTime.isAfter(DateTime.now())) {
      final notification = ScheduledNotification(
        id: 'completion_${session.id}',
        type: NotificationType.completion,
        scheduledTime: completionTime,
        title: 'Fast Complete!',
        body: 'Congratulations! You\'ve reached your fasting target.',
      );

      await _scheduleNotification(notification);
    }
  }

  /// Schedule a single notification
  Future<void> _scheduleNotification(ScheduledNotification notification) async {
    // Store the notification for tracking
    _scheduledNotifications.add(notification);

    // TODO: Phase 3 - Use flutter_local_notifications to schedule
    // For now, just track in memory
  }

  /// Cancel all scheduled notifications
  Future<void> cancelAllNotifications() async {
    _scheduledNotifications.clear();
    // TODO: Phase 3 - Cancel actual platform notifications
  }

  /// Cancel notifications for a specific fast session
  Future<void> cancelNotificationsForFast(String sessionId) async {
    _scheduledNotifications.removeWhere(
      (notification) => notification.id.contains(sessionId),
    );
    // TODO: Phase 3 - Cancel actual platform notifications by ID
  }

  /// Get the next hour mark after current time (e.g., if now is 10:23, return 11:00)
  DateTime _getNextHourMark(DateTime startTime, DateTime currentTime) {
    DateTime nextHour = DateTime(
      currentTime.year,
      currentTime.month,
      currentTime.day,
      currentTime.hour + 1,
    );

    // Make sure we don't schedule before the fast started
    if (nextHour.isBefore(startTime)) {
      nextHour = startTime.add(const Duration(hours: 1));
    }

    return nextHour;
  }

  /// Get all currently scheduled notifications (for testing/debugging)
  List<ScheduledNotification> getScheduledNotifications() {
    return List.unmodifiable(_scheduledNotifications);
  }
}

/// Provider for notification service
final notificationServiceProvider = Provider<NotificationService>((ref) {
  final settings = ref.watch(fastingSettingsProvider);
  return NotificationService(settings);
});
