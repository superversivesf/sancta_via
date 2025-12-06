import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../config/routes.dart';
import '../models/fast_session.dart';
import '../providers/settings_provider.dart';
import '../services/encouragement_service.dart';
import '../utils/app_logger.dart';

/// Types of notifications that can be scheduled
enum NotificationType {
  hourly,
  milestone,
  completion,
}

/// Result of scheduling notifications
class NotificationScheduleResult {
  final bool success;
  final String? errorMessage;
  final bool needsNotificationPermission;
  final bool needsExactAlarmPermission;

  const NotificationScheduleResult({
    required this.success,
    this.errorMessage,
    this.needsNotificationPermission = false,
    this.needsExactAlarmPermission = false,
  });

  factory NotificationScheduleResult.success() {
    return const NotificationScheduleResult(success: true);
  }

  factory NotificationScheduleResult.notificationPermissionDenied() {
    return const NotificationScheduleResult(
      success: false,
      errorMessage: 'Notification permissions are required to receive reminders during your fast.',
      needsNotificationPermission: true,
    );
  }

  factory NotificationScheduleResult.exactAlarmPermissionDenied() {
    return const NotificationScheduleResult(
      success: false,
      errorMessage: 'Exact alarm permission is required for timely notifications. Please enable it in system settings.',
      needsExactAlarmPermission: true,
    );
  }

  factory NotificationScheduleResult.error(String message) {
    return NotificationScheduleResult(
      success: false,
      errorMessage: message,
    );
  }
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
  final EncouragementService? encouragementService;
  final List<ScheduledNotification> _scheduledNotifications = [];

  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  NotificationService(this.settings, {this.encouragementService});

  /// Initialize notification service and request permissions
  Future<bool> initialize() async {
    if (_initialized) return true;

    try {
      // Initialize timezone data
      tz.initializeTimeZones();

      // Android initialization settings
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

      // iOS initialization settings
      final iosSettings = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
        onDidReceiveLocalNotification: _onDidReceiveLocalNotification,
      );

      // Initialize the plugin
      final initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
        macOS: iosSettings,
      );

      final initialized = await _notifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationResponse,
      );

      _initialized = initialized ?? false;

      if (_initialized) {
        // Create notification channels for Android
        if (Platform.isAndroid) {
          const fastingChannel = AndroidNotificationChannel(
            'fasting_progress',
            'Fasting Progress',
            description: 'Notifications about your fasting progress',
            importance: Importance.high,
            playSound: true,
            enableVibration: true,
          );

          const achievementsChannel = AndroidNotificationChannel(
            'achievements',
            'Achievements',
            description: 'Notifications for earned achievements and badges',
            importance: Importance.high,
            playSound: true,
            enableVibration: true,
          );

          final androidPlugin = _notifications
              .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin>();

          await androidPlugin?.createNotificationChannel(fastingChannel);
          await androidPlugin?.createNotificationChannel(achievementsChannel);

          AppLogger.info('Android notification channels created', 'NotificationService');
        }

        AppLogger.info('Notification service initialized', 'NotificationService');
      } else {
        AppLogger.warning('Notification service failed to initialize', 'NotificationService');
      }

      return _initialized;
    } catch (e, stack) {
      AppLogger.error('Error initializing notifications', e, stack, 'NotificationService');
      return false;
    }
  }

  /// Check if notification permissions are granted (doesn't request)
  Future<bool> areNotificationsEnabled() async {
    try {
      if (Platform.isAndroid) {
        final androidPlugin = _notifications
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();

        if (androidPlugin == null) {
          AppLogger.warning('Android plugin not available', 'NotificationService');
          return false;
        }

        final permitted = await androidPlugin.areNotificationsEnabled();
        AppLogger.debug(
          'Android notifications enabled: $permitted',
          'NotificationService',
        );
        return permitted ?? false;
      } else if (Platform.isIOS || Platform.isMacOS) {
        // iOS/macOS - we can't check directly, assume true if initialized
        return _initialized;
      }

      return false;
    } catch (e, stack) {
      AppLogger.error(
        'Error checking notification permissions',
        e,
        stack,
        'NotificationService',
      );
      return false;
    }
  }

  /// Request notification permissions from the user
  Future<bool> requestPermissions() async {
    try {
      AppLogger.info('Requesting notification permissions...', 'NotificationService');

      // Request iOS permissions
      final iosGranted = await _notifications
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );

      // Request macOS permissions
      final macosGranted = await _notifications
          .resolvePlatformSpecificImplementation<
              MacOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );

      // Request Android 13+ permissions
      final androidGranted = await _notifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();

      final granted = iosGranted ?? macosGranted ?? androidGranted ?? true;

      if (granted) {
        AppLogger.info('✅ Notification permissions granted', 'NotificationService');
      } else {
        AppLogger.warning('❌ Notification permissions denied', 'NotificationService');
      }

      return granted;
    } catch (e, stack) {
      AppLogger.error('Error requesting permissions', e, stack, 'NotificationService');
      return false;
    }
  }

  /// Check if exact alarm permissions are granted (Android 12+ / API 31+)
  /// Returns true if granted or not required, false if denied
  Future<bool> canScheduleExactAlarms() async {
    if (!Platform.isAndroid) {
      return true; // Not applicable on non-Android platforms
    }

    try {
      final androidPlugin = _notifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      if (androidPlugin == null) {
        AppLogger.warning(
          'Android plugin not available for exact alarm check',
          'NotificationService',
        );
        return false;
      }

      // Check if exact alarms can be scheduled
      final canSchedule = await androidPlugin.canScheduleExactNotifications();

      if (canSchedule == true) {
        AppLogger.info('Exact alarm permission granted', 'NotificationService');
      } else {
        AppLogger.warning(
          'Exact alarm permission not granted. User needs to enable in system settings.',
          'NotificationService',
        );
      }

      return canSchedule ?? false;
    } catch (e, stack) {
      AppLogger.error(
        'Error checking exact alarm permissions',
        e,
        stack,
        'NotificationService',
      );
      return false;
    }
  }

  /// Request exact alarm permissions (opens system settings on Android 12+)
  Future<void> requestExactAlarmPermission() async {
    if (!Platform.isAndroid) {
      return;
    }

    try {
      final androidPlugin = _notifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      if (androidPlugin != null) {
        await androidPlugin.requestExactAlarmsPermission();
        AppLogger.info(
          'Opened system settings for exact alarm permission',
          'NotificationService',
        );
      }
    } catch (e, stack) {
      AppLogger.error(
        'Error requesting exact alarm permission',
        e,
        stack,
        'NotificationService',
      );
    }
  }

  /// Handle notification received while app is in foreground (iOS)
  void _onDidReceiveLocalNotification(
    int id,
    String? title,
    String? body,
    String? payload,
  ) {
    AppLogger.debug('Received local notification: $title', 'NotificationService');
  }

  /// Handle notification tap
  void _onNotificationResponse(NotificationResponse response) {
    AppLogger.debug('Notification tapped: ${response.payload}', 'NotificationService');

    final payload = response.payload;
    if (payload == null) return;

    try {
      // Parse notification payload to determine destination
      // Payload format: {type}_{sessionId}_{additional}
      // Examples:
      //   - hourly_{session.id}_{hours}
      //   - milestone_{session.id}_{percentage}
      //   - completion_{session.id}

      if (payload.startsWith('hourly_') ||
          payload.startsWith('milestone_') ||
          payload.startsWith('completion_')) {
        // All fast-related notifications navigate to the active fast screen
        appRouter.go('/active-fast');
        AppLogger.debug('Navigating to active fast screen', 'NotificationService');
      } else {
        // Default fallback - go to home
        appRouter.go('/');
        AppLogger.debug('Navigating to home screen (fallback)', 'NotificationService');
      }
    } catch (e, stack) {
      AppLogger.error(
        'Error handling notification tap',
        e,
        stack,
        'NotificationService',
      );
      // Fallback to home screen on error
      appRouter.go('/');
    }
  }

  /// Schedule all notifications for an active fast session
  Future<NotificationScheduleResult> scheduleNotificationsForFast(FastSession session) async {
    AppLogger.info(
      'scheduleNotificationsForFast called for session ${session.id}',
      'NotificationService',
    );

    if (!settings.notificationsEnabled) {
      AppLogger.info('Notifications disabled in settings', 'NotificationService');
      return NotificationScheduleResult.success();
    }

    try {
      // Ensure notification service is initialized
      if (!_initialized) {
        AppLogger.info('Initializing notification service...', 'NotificationService');
        final initialized = await initialize();
        if (!initialized) {
          AppLogger.error(
            'Failed to initialize notification service',
            null,
            null,
            'NotificationService',
          );
          return NotificationScheduleResult.error(
            'Failed to initialize notification service',
          );
        }
      }

      // Check basic notification permissions
      AppLogger.info('Checking notification permissions...', 'NotificationService');
      final hasNotificationPermission = await requestPermissions();
      if (!hasNotificationPermission) {
        AppLogger.warning('Notification permissions denied', 'NotificationService');
        return NotificationScheduleResult.notificationPermissionDenied();
      }

      // Check exact alarm permissions (Android 12+)
      if (Platform.isAndroid) {
        AppLogger.info('Checking exact alarm permissions...', 'NotificationService');
        final canScheduleExact = await canScheduleExactAlarms();
        if (!canScheduleExact) {
          AppLogger.warning('Exact alarm permissions denied', 'NotificationService');
          return NotificationScheduleResult.exactAlarmPermissionDenied();
        }
      }

      // Cancel any existing notifications first
      await cancelAllNotifications();

      // Schedule hourly reminders if enabled
      if (settings.hourlyReminders) {
        AppLogger.info('Scheduling hourly reminders...', 'NotificationService');
        await _scheduleHourlyReminders(session);
      }

      // Schedule milestone reminders if enabled
      if (settings.milestoneReminders) {
        AppLogger.info('Scheduling milestone reminders...', 'NotificationService');
        await _scheduleMilestoneReminders(session);
      }

      // Schedule completion reminder if enabled
      if (settings.completionReminders) {
        AppLogger.info('Scheduling completion reminder...', 'NotificationService');
        await _scheduleCompletionReminder(session);
      }

      AppLogger.info(
        '✅ Successfully scheduled ${_scheduledNotifications.length} notifications for session ${session.id}',
        'NotificationService',
      );
      return NotificationScheduleResult.success();
    } catch (e, stack) {
      AppLogger.error(
        'Error scheduling notifications for fast',
        e,
        stack,
        'NotificationService',
      );
      return NotificationScheduleResult.error(
        'Failed to schedule notifications: ${e.toString()}',
      );
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
    int notificationIndex = 0;

    while (nextHour.isBefore(endTime) && notificationIndex < 48) {
      // Limit to 48 hours max
      final elapsedHours = nextHour.difference(session.startTime).inHours;

      // Get encouragement for this hour if available
      String body = '$elapsedHours ${elapsedHours == 1 ? 'hour' : 'hours'} into your fast. Keep going!';

      if (encouragementService != null) {
        final encouragement =
            await encouragementService!.checkForAutoEncouragement();
        if (encouragement != null) {
          body = encouragement.content;
        }
      }

      final notification = ScheduledNotification(
        id: 'hourly_${session.id}_$elapsedHours',
        type: NotificationType.hourly,
        scheduledTime: nextHour,
        title: 'Fasting Progress - Hour $elapsedHours',
        body: body,
      );

      await _scheduleNotification(notification);
      nextHour = nextHour.add(const Duration(hours: 1));
      notificationIndex++;
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
    if (!_initialized) {
      await initialize();
    }

    try {
      // Store the notification for tracking
      _scheduledNotifications.add(notification);

      // Convert notification ID to integer hash
      final notificationId = notification.id.hashCode.abs() % 2147483647;

      // Android notification details
      const androidDetails = AndroidNotificationDetails(
        'fasting_progress',
        'Fasting Progress',
        channelDescription: 'Notifications about your fasting progress',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      );

      // iOS notification details
      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
        macOS: iosDetails,
      );

      // Schedule the notification
      await _notifications.zonedSchedule(
        notificationId,
        notification.title,
        notification.body,
        tz.TZDateTime.from(notification.scheduledTime, tz.local),
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: notification.id,
      );

      AppLogger.debug(
        'Scheduled notification: ${notification.title} at ${notification.scheduledTime}',
        'NotificationService',
      );
    } catch (e, stack) {
      AppLogger.error(
        'Error scheduling notification: ${notification.id}',
        e,
        stack,
        'NotificationService',
      );
    }
  }

  /// Cancel all scheduled notifications
  Future<void> cancelAllNotifications() async {
    try {
      await _notifications.cancelAll();
      _scheduledNotifications.clear();
      AppLogger.info('All notifications cancelled', 'NotificationService');
    } catch (e, stack) {
      AppLogger.error(
        'Error cancelling notifications',
        e,
        stack,
        'NotificationService',
      );
    }
  }

  /// Cancel notifications for a specific fast session
  Future<void> cancelNotificationsForFast(String sessionId) async {
    try {
      final toRemove = _scheduledNotifications
          .where((notification) => notification.id.contains(sessionId))
          .toList();

      for (final notification in toRemove) {
        final notificationId = notification.id.hashCode.abs() % 2147483647;
        await _notifications.cancel(notificationId);
      }

      _scheduledNotifications.removeWhere(
        (notification) => notification.id.contains(sessionId),
      );

      AppLogger.debug(
        'Cancelled ${toRemove.length} notifications for session: $sessionId',
        'NotificationService',
      );
    } catch (e, stack) {
      AppLogger.error(
        'Error cancelling session notifications',
        e,
        stack,
        'NotificationService',
      );
    }
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

  /// Send an immediate test notification to verify the system is working
  Future<bool> sendTestNotification() async {
    try {
      // Ensure notification service is initialized
      if (!_initialized) {
        final initialized = await initialize();
        if (!initialized) {
          AppLogger.error(
            'Cannot send test notification - service not initialized',
            null,
            null,
            'NotificationService',
          );
          return false;
        }
      }

      AppLogger.info('Sending test notification...', 'NotificationService');

      // Check permissions first
      final hasPermission = await areNotificationsEnabled();
      AppLogger.info(
        'Notification permission status: $hasPermission',
        'NotificationService',
      );

      if (!hasPermission) {
        AppLogger.warning(
          'Attempting to send test notification without permissions',
          'NotificationService',
        );
        // Try to request permissions
        final granted = await requestPermissions();
        if (!granted) {
          return false;
        }
      }

      // Android notification details
      const androidDetails = AndroidNotificationDetails(
        'fasting_progress',
        'Fasting Progress',
        channelDescription: 'Notifications about your fasting progress',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        playSound: true,
        enableVibration: true,
      );

      // iOS notification details
      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
        macOS: iosDetails,
      );

      // Send immediate notification
      await _notifications.show(
        999999, // Use a unique ID for test notifications
        'Test Notification',
        'If you see this, notifications are working! 🎉',
        notificationDetails,
        payload: 'test_notification',
      );

      AppLogger.info('✅ Test notification sent successfully', 'NotificationService');
      return true;
    } catch (e, stack) {
      AppLogger.error(
        'Error sending test notification',
        e,
        stack,
        'NotificationService',
      );
      return false;
    }
  }

  /// Get detailed permission status for debugging
  Future<Map<String, dynamic>> getPermissionStatus() async {
    final status = <String, dynamic>{
      'initialized': _initialized,
      'settingsEnabled': settings.notificationsEnabled,
      'notificationsEnabled': false,
      'exactAlarmsEnabled': false,
      'platform': Platform.operatingSystem,
    };

    try {
      status['notificationsEnabled'] = await areNotificationsEnabled();

      if (Platform.isAndroid) {
        status['exactAlarmsEnabled'] = await canScheduleExactAlarms();
      }
    } catch (e, stack) {
      AppLogger.error(
        'Error getting permission status',
        e,
        stack,
        'NotificationService',
      );
      status['error'] = e.toString();
    }

    return status;
  }
}

/// Provider for notification service
final notificationServiceProvider = Provider<NotificationService>((ref) {
  final settings = ref.watch(fastingSettingsProvider);
  final encouragementService = ref.watch(encouragementServiceProvider);
  return NotificationService(settings, encouragementService: encouragementService);
});
