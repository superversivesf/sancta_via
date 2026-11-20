import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import '../models/novena.dart';
import '../../../utils/logger.dart';

/// Navigation callback type for handling notification taps
typedef NotificationNavigationCallback = void Function(String payload);

/// Completion check callback - returns true if the specified day is complete
typedef CompletionCheckCallback = bool Function(int day);

/// Notification service specifically for novena reminders and updates
/// Enhanced with better permission handling and debugging capabilities
class NovenaNotificationService {
  static final NovenaNotificationService _instance =
      NovenaNotificationService._internal();
  factory NovenaNotificationService() => _instance;
  NovenaNotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;
  bool _hasPermission = false;
  bool _permissionsRequested = false; // Track if we've requested permissions
  String? _lastError;
  NotificationNavigationCallback? _navigationCallback;
  CompletionCheckCallback? _completionCheckCallback;

  // Notification ID scheme for novenas
  static const int _baseReminderIdDaily = 2000; // 2000-2008 for daily reminders
  static const int _baseReminderIdFollowUp = 2100; // 2100-2108 for follow-ups
  static const int _baseProgressId = 2200; // 2200+ for progress notifications
  static const int _completionId = 2300; // 2300 for completion

  /// Get current service status
  bool get isInitialized => _isInitialized;
  bool get hasPermission => _hasPermission;
  String? get lastError => _lastError;
  bool get isReady => _isInitialized && _hasPermission;

  /// Set navigation callback for handling notification taps
  void setNavigationCallback(NotificationNavigationCallback callback) {
    _navigationCallback = callback;
  }

  /// Set completion check callback to verify if days are complete
  void setCompletionCheckCallback(CompletionCheckCallback callback) {
    _completionCheckCallback = callback;
  }

  /// Initialize the notification service
  Future<bool> initialize() async {
    try {
      _lastError = null;
      AppLogger.debug(
        'Initializing novena notification service...',
        'NOTIFICATION',
      );

      // Initialize timezone
      await _initializeTimezone();

      // Setup notification plugin
      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iOS = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: false, // We don't want badge numbers
        requestSoundPermission: true,
      );

      const settings = InitializationSettings(android: android, iOS: iOS);

      final initialized = await _plugin.initialize(
        settings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      if (initialized != true) {
        throw Exception('Failed to initialize notification plugin');
      }

      _isInitialized = true;

      // Request permissions
      _hasPermission = await _requestPermissions();

      AppLogger.info(
        'Notification service initialized successfully',
        'NOTIFICATION',
      );
      AppLogger.debug(
        'Has notification permission: $_hasPermission',
        'NOTIFICATION',
      );
      return true;
    } catch (e) {
      _lastError = e.toString();
      AppLogger.error(
        'Failed to initialize notification service',
        e,
        null,
        'NOTIFICATION',
      );
      return false;
    }
  }

  /// Enhanced timezone initialization with better error handling
  Future<void> _initializeTimezone() async {
    try {
      tz.initializeTimeZones();

      // Try to set local timezone, fallback to UTC if it fails
      try {
        tz.setLocalLocation(tz.local);
        AppLogger.debug(
          'Timezone set to local: ${tz.local.name}',
          'NOTIFICATION',
        );
      } catch (e) {
        AppLogger.warning(
          'Failed to set local timezone, using UTC: $e',
          'NOTIFICATION',
        );
        tz.setLocalLocation(tz.UTC);
      }
    } catch (e) {
      AppLogger.error(
        'Timezone initialization failed',
        e,
        null,
        'NOTIFICATION',
      );
      // Don't rethrow - continue with basic functionality
    }
  }

  /// Enhanced permission request with iOS simulator support and Android 12+ compatibility
  Future<bool> _requestPermissions() async {
    try {
      AppLogger.debug('Requesting notification permissions...', 'NOTIFICATION');

      if (Platform.isIOS) {
        // Use flutter_local_notifications for iOS permission requests
        final iosPlugin = _plugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >();

        if (iosPlugin != null) {
          final granted = await iosPlugin.requestPermissions(
            alert: true,
            badge: false, // Keep false for spiritual context
            sound: true,
          );
          AppLogger.debug(
            'iOS notification permission request result: $granted',
            'NOTIFICATION',
          );
          _permissionsRequested = true;

          // iOS simulator often returns false even when permissions are granted
          if (granted == true) {
            return true;
          } else if (kDebugMode && Platform.isIOS) {
            AppLogger.debug(
              'iOS simulator detected - assuming permission granted despite false result',
              'NOTIFICATION',
            );
            return true; // Assume granted on simulator
          } else {
            return false;
          }
        } else {
          AppLogger.error(
            'Could not get iOS notification plugin',
            null,
            null,
            'NOTIFICATION',
          );
          return false;
        }
      } else {
        // Enhanced Android permission handling
        final permission = await Permission.notification.request();
        AppLogger.debug(
          'Android notification permission request result: ${permission.name}',
          'NOTIFICATION',
        );

        if (!permission.isGranted) {
          return false;
        }

        // Exact-alarm permission deliberately not requested: reminders use
        // AndroidScheduleMode.inexactAllowWhileIdle (see the zonedSchedule
        // call), which needs no SCHEDULE_EXACT_ALARM grant and no Play
        // alarm/clock declaration.
        return permission.isGranted;
      }
    } catch (e) {
      AppLogger.error('Permission request failed', e, null, 'NOTIFICATION');
      return false;
    }
  }

  /// Enhanced permission checking with iOS simulator support
  Future<bool> hasPermissions() async {
    if (!_isInitialized) await initialize();

    AppLogger.debug('Checking notification permissions...', 'NOTIFICATION');

    if (Platform.isIOS) {
      // Use flutter_local_notifications for iOS permission checking
      final iosPlugin = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();

      if (iosPlugin != null) {
        final iosPermissions = await iosPlugin.checkPermissions();
        AppLogger.debug(
          'iOS notification permissions: $iosPermissions',
          'NOTIFICATION',
        );

        // If permissions are denied but we're on simulator, be more lenient
        if (iosPermissions?.isEnabled == true) {
          return true;
        } else {
          // On iOS simulator in debug mode, if we've already requested permissions,
          // assume they're granted (simulator limitation workaround)
          if (kDebugMode && Platform.isIOS && _permissionsRequested) {
            AppLogger.debug(
              'iOS simulator detected with previous permission request - assuming granted',
              'NOTIFICATION',
            );
            return true;
          }
          AppLogger.debug(
            'iOS permissions check failed, might be simulator limitation',
            'NOTIFICATION',
          );
          return false;
        }
      } else {
        AppLogger.error(
          'Could not get iOS notification plugin',
          null,
          null,
          'NOTIFICATION',
        );
        return false;
      }
    } else {
      // Use permission_handler for Android
      final permission = await Permission.notification.status;
      AppLogger.debug(
        'Android notification permission status: ${permission.name}',
        'NOTIFICATION',
      );

      if (!permission.isGranted) {
        return false;
      }

      // For Android 12+ (API 31+), also check exact alarm permission
      try {
        final exactAlarmPermission = await Permission.scheduleExactAlarm.status;
        AppLogger.debug(
          'Exact alarm permission status: ${exactAlarmPermission.name}',
          'NOTIFICATION',
        );
        return exactAlarmPermission.isGranted;
      } catch (e) {
        // If exact alarm permission is not available, basic permission is sufficient
        AppLogger.debug(
          'Exact alarm permission not available: $e',
          'NOTIFICATION',
        );
        return permission.isGranted;
      }
    }
  }

  /// Get pending notifications for debugging
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    if (!_isInitialized) await initialize();
    try {
      final pending = await _plugin.pendingNotificationRequests();
      AppLogger.debug(
        'Found ${pending.length} pending notifications',
        'NOTIFICATION',
      );

      // Log details of each pending notification for debugging
      for (final notification in pending) {
        AppLogger.debug(
          'Pending notification - ID: ${notification.id}, Title: ${notification.title}, Body: ${notification.body}',
          'NOTIFICATION',
        );
      }

      return pending;
    } catch (e) {
      AppLogger.error(
        'Failed to get pending notifications',
        e,
        null,
        'NOTIFICATION',
      );
      return [];
    }
  }

  /// Debug method to log notification scheduling details
  void _logNotificationSchedule(
    int id,
    String title,
    DateTime scheduledTime, {
    String? payload,
  }) {
    final now = DateTime.now();
    final timeUntil = scheduledTime.difference(now);

    AppLogger.debug(
      'Scheduling notification:\n'
          '  ID: $id\n'
          '  Title: "$title"\n'
          '  Scheduled: ${scheduledTime.toString()}\n'
          '  Time until: ${timeUntil.inMinutes} minutes\n'
          '  Payload: ${payload ?? "none"}',
      'NOTIFICATION',
    );
  }

  /// Validate notification service health
  Future<ServiceHealthReport> checkServiceHealth() async {
    final report = ServiceHealthReport();

    // Check initialization
    report.isInitialized = _isInitialized;

    // Check permissions
    try {
      report.hasPermissions = await hasPermissions();
    } catch (e) {
      report.permissionError = e.toString();
    }

    // Check pending notifications
    try {
      final pending = await getPendingNotifications();
      report.pendingNotificationCount = pending.length;
    } catch (e) {
      report.pendingNotificationError = e.toString();
    }

    // Check timezone
    try {
      tz.TZDateTime.now(tz.local); // Test timezone functionality
      report.timezoneStatus = 'OK (${tz.local.name})';
    } catch (e) {
      report.timezoneStatus = 'Error: $e';
    }

    AppLogger.debug(
      'Service health check completed: ${report.toString()}',
      'NOTIFICATION',
    );
    return report;
  }

  /// Schedule complete notification system for a novena
  Future<NotificationScheduleResult> scheduleNovenaNotifications(
    ActiveNovena activeNovena,
    String novenaTitle,
  ) async {
    if (!isReady) {
      return NotificationScheduleResult.failure(
        'Notification service not ready',
      );
    }

    try {
      AppLogger.debug(
        'Scheduling notifications for novena: $novenaTitle',
        'NOTIFICATION',
      );

      // Clear any existing notifications first
      await cancelAllNovenaNotifications();

      int scheduledCount = 0;
      final errors = <String>[];

      // Schedule daily reminders only for incomplete days
      for (int day = 1; day <= 9; day++) {
        // Skip if this day is already completed
        if (activeNovena.isDayComplete(day)) {
          AppLogger.debug(
            'Day $day is already complete, skipping notifications',
            'NOTIFICATION',
          );
          continue;
        }

        // Only schedule for days that are accessible (up to spiritual day)
        if (day > activeNovena.spiritualDay) {
          AppLogger.debug(
            'Day $day is not yet accessible (spiritual day: ${activeNovena.spiritualDay}), skipping',
            'NOTIFICATION',
          );
          continue;
        }

        final result = await _scheduleDayReminders(
          activeNovena,
          novenaTitle,
          day,
        );
        if (result.success) {
          scheduledCount += result.count;
        } else if (!result.skipped) {
          errors.add('Day $day: ${result.error}');
        }
      }

      AppLogger.info(
        'Scheduled $scheduledCount notifications for incomplete days',
        'NOTIFICATION',
      );

      if (scheduledCount == 0 && errors.isEmpty) {
        return NotificationScheduleResult.success(0); // All days complete
      } else if (errors.isNotEmpty) {
        return NotificationScheduleResult.partial(scheduledCount, errors);
      } else {
        return NotificationScheduleResult.success(scheduledCount);
      }
    } catch (e, stackTrace) {
      _lastError = e.toString();
      AppLogger.error(
        'Failed to schedule notifications',
        e,
        stackTrace,
        'NOTIFICATION',
      );
      return NotificationScheduleResult.failure(e.toString());
    }
  }

  /// Update notifications when novena progress changes
  Future<void> updateNotificationsForProgress(
    ActiveNovena activeNovena,
    String novenaTitle,
    int completedDay,
  ) async {
    if (!isReady) return;

    try {
      AppLogger.debug(
        'Updating notifications after completing day $completedDay',
        'NOTIFICATION',
      );

      // Cancel notifications for the completed day
      await cancelDayNotifications(completedDay);

      // If we've advanced to a new spiritual day, schedule notifications for it
      final currentSpiritualDay = activeNovena.spiritualDay;
      if (currentSpiritualDay <= 9 &&
          !activeNovena.isDayComplete(currentSpiritualDay)) {
        // Check if we need to schedule notifications for today
        final result = await _scheduleDayReminders(
          activeNovena,
          novenaTitle,
          currentSpiritualDay,
        );
        if (result.success) {
          AppLogger.debug(
            'Scheduled notifications for new spiritual day $currentSpiritualDay',
            'NOTIFICATION',
          );
        }
      }

      // Send progress notification
      await sendProgressNotification(
        title: '✅ Day $completedDay Complete!',
        body: _getProgressNotificationBody(activeNovena, completedDay),
        payload: 'progress_$completedDay',
      );
    } catch (e, stackTrace) {
      AppLogger.error(
        'Failed to update notifications for progress',
        e,
        stackTrace,
        'NOTIFICATION',
      );
    }
  }

  /// Schedule daily reminder + follow-ups for a specific day
  Future<DayScheduleResult> _scheduleDayReminders(
    ActiveNovena activeNovena,
    String novenaTitle,
    int day,
  ) async {
    try {
      final dayDate = activeNovena.startDate.add(Duration(days: day - 1));
      final reminderTime = DateTime(
        dayDate.year,
        dayDate.month,
        dayDate.day,
        activeNovena.reminderTime.hour,
        activeNovena.reminderTime.minute,
      );

      // Skip if the time is in the past
      if (reminderTime.isBefore(DateTime.now())) {
        return DayScheduleResult.skipped(
          'Day $day reminder time is in the past',
        );
      }

      int scheduledCount = 0;

      // 1. Schedule main daily reminder with completion check
      await _scheduleSmartNotification(
        id: _baseReminderIdDaily + day - 1,
        title: _getDailyReminderTitle(novenaTitle, day),
        body: _getDailyReminderBody(day),
        scheduledTime: reminderTime,
        payload: 'daily_reminder_$day',
        isDaily: true,
        dayToCheck: day,
      );
      scheduledCount++;

      // 2. Schedule follow-up reminders based on frequency
      final followUpTimes = _calculateFollowUpTimes(
        reminderTime,
        activeNovena.reminderFrequency,
      );
      for (int i = 0; i < followUpTimes.length; i++) {
        await _scheduleSmartNotification(
          id: _baseReminderIdFollowUp + day - 1 + (i * 10), // Unique IDs
          title: _getFollowUpTitle(novenaTitle),
          body: _getFollowUpBody(day),
          scheduledTime: followUpTimes[i],
          payload: 'follow_up_${day}_$i',
          isDaily: false,
          dayToCheck: day,
        );
        scheduledCount++;
      }

      AppLogger.debug(
        'Scheduled $scheduledCount smart notifications for day $day',
        'NOTIFICATION',
      );
      return DayScheduleResult.success(scheduledCount);
    } catch (e) {
      AppLogger.error('Failed to schedule day $day', e, null, 'NOTIFICATION');
      return DayScheduleResult.failure(e.toString());
    }
  }

  /// Calculate follow-up reminder times based on frequency
  List<DateTime> _calculateFollowUpTimes(
    DateTime initialTime,
    ReminderInterval frequency,
  ) {
    final times = <DateTime>[];
    final endOfDay = DateTime(
      initialTime.year,
      initialTime.month,
      initialTime.day,
      22,
      0,
    ); // Stop at 10 PM

    var nextTime = initialTime.add(Duration(hours: frequency.hours));

    // Add follow-ups until end of day, max 3 follow-ups
    int count = 0;
    while (nextTime.isBefore(endOfDay) && count < 3) {
      times.add(nextTime);
      nextTime = nextTime.add(Duration(hours: frequency.hours));
      count++;
    }

    return times;
  }

  /// Enhanced schedule individual notification with better logging and validation
  Future<void> _scheduleSmartNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
    required String payload,
    required bool isDaily,
    required int dayToCheck,
  }) async {
    try {
      // Validate that the scheduled time is in the future
      final now = DateTime.now();
      if (scheduledTime.isBefore(now)) {
        AppLogger.warning(
          'Attempted to schedule notification $id for past time: $scheduledTime (now: $now)',
          'NOTIFICATION',
        );
        return;
      }

      // Create a wrapper payload that includes the day to check
      final smartPayload = '$payload|check_day:$dayToCheck';

      // Log scheduling details for debugging
      _logNotificationSchedule(id, title, scheduledTime, payload: smartPayload);

      final tzDateTime = tz.TZDateTime.from(scheduledTime, tz.local);

      await _plugin.zonedSchedule(
        id,
        title,
        body,
        tzDateTime,
        _getNotificationDetails(isDaily),
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: smartPayload,
        // Inexact on purpose: needs no SCHEDULE_EXACT_ALARM permission (denied
        // by default on Android 13+, Play-restricted for prayer apps), and a
        // minutes-level delay for a daily prayer reminder is fine. Mirrors
        // sancta_via_devotionals.
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );

      AppLogger.debug(
        'Successfully scheduled smart notification $id',
        'NOTIFICATION',
      );
    } catch (e) {
      AppLogger.error(
        'Failed to schedule smart notification $id',
        e,
        null,
        'NOTIFICATION',
      );
      rethrow;
    }
  }

  /// Get notification styling details
  NotificationDetails _getNotificationDetails(bool isDaily) {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        isDaily ? 'novena_daily_reminders' : 'novena_follow_ups',
        isDaily ? 'Daily Novena Reminders' : 'Novena Follow-up Reminders',
        channelDescription: isDaily
            ? 'Daily reminders for your novena prayers'
            : 'Gentle follow-up reminders for novena prayers',
        importance: isDaily ? Importance.high : Importance.defaultImportance,
        priority: isDaily ? Priority.high : Priority.defaultPriority,
        icon: '@mipmap/ic_launcher',
        color: const Color(0xFF6750A4), // Material 3 primary color
        styleInformation: const BigTextStyleInformation(''),
      ),
      iOS: DarwinNotificationDetails(
        sound: isDaily ? 'default.caf' : null, // Sound only for main reminders
        presentAlert: true,
        presentBadge: false, // No badge numbers
        presentSound: isDaily,
      ),
    );
  }

  /// Send immediate notification (for progress/completion)
  Future<bool> sendProgressNotification({
    required String title,
    required String body,
    String? payload,
    bool isCompletion = false,
  }) async {
    if (!isReady) return false;

    try {
      final id = isCompletion
          ? _completionId
          : _baseProgressId + DateTime.now().millisecond;

      await _plugin.show(
        id,
        title,
        body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'novena_progress',
            'Novena Progress',
            channelDescription: 'Progress updates and celebrations for novenas',
            importance: Importance.defaultImportance,
            color: isCompletion
                ? const Color(0xFFFFD700)
                : const Color(0xFF4CAF50), // Gold for completion
            icon: '@mipmap/ic_launcher',
          ),
          iOS: const DarwinNotificationDetails(
            sound: 'default.caf',
            presentAlert: true,
            presentBadge: false,
          ),
        ),
        payload: payload,
      );
      return true;
    } catch (e) {
      AppLogger.error(
        'Failed to send progress notification',
        e,
        null,
        'NOTIFICATION',
      );
      return false;
    }
  }

  /// Cancel notifications for a specific day (when completed)
  Future<void> cancelDayNotifications(int day) async {
    if (!_isInitialized) return;

    try {
      // Cancel daily reminder
      await _plugin.cancel(_baseReminderIdDaily + day - 1);

      // Cancel follow-ups (up to 3 follow-ups)
      for (int i = 0; i < 3; i++) {
        await _plugin.cancel(_baseReminderIdFollowUp + day - 1 + (i * 10));
      }

      AppLogger.debug(
        'Cancelled notifications for completed day $day',
        'NOTIFICATION',
      );
    } catch (e) {
      AppLogger.error(
        'Failed to cancel day $day notifications',
        e,
        null,
        'NOTIFICATION',
      );
    }
  }

  /// Cancel all novena notifications
  Future<void> cancelAllNovenaNotifications() async {
    if (!_isInitialized) return;

    try {
      // Cancel all daily reminders
      for (int day = 1; day <= 9; day++) {
        await _plugin.cancel(_baseReminderIdDaily + day - 1);

        // Cancel follow-ups
        for (int i = 0; i < 3; i++) {
          await _plugin.cancel(_baseReminderIdFollowUp + day - 1 + (i * 10));
        }
      }

      // Cancel progress/completion notifications
      await _plugin.cancel(_completionId);

      AppLogger.debug('Cancelled all novena notifications', 'NOTIFICATION');
    } catch (e) {
      AppLogger.error(
        'Failed to cancel notifications',
        e,
        null,
        'NOTIFICATION',
      );
    }
  }

  /// Handle notification tap
  void _onNotificationTapped(NotificationResponse response) {
    AppLogger.debug('Notification tapped: ${response.payload}', 'NOTIFICATION');

    if (response.payload != null) {
      // Parse smart payload to check if day is complete before navigating
      final payload = response.payload!;
      if (payload.contains('|check_day:')) {
        final parts = payload.split('|check_day:');
        final originalPayload = parts[0];
        final dayToCheck = int.tryParse(parts[1]);

        // Check if this day is now complete
        if (dayToCheck != null && _completionCheckCallback != null) {
          final isComplete = _completionCheckCallback!(dayToCheck);
          if (isComplete) {
            AppLogger.debug(
              'Day $dayToCheck is already complete, showing completion message instead of navigation',
              'NOTIFICATION',
            );
            // Could show a different notification or just return
            return;
          }
        }

        // Day is not complete, proceed with normal navigation
        if (_navigationCallback != null) {
          _navigationCallback!(originalPayload);
        }
      } else {
        // Normal payload without completion checking
        if (_navigationCallback != null) {
          _navigationCallback!(payload);
        }
      }
    } else {
      AppLogger.warning(
        'No navigation callback set or payload is null',
        'NOTIFICATION',
      );
    }
  }

  // Notification text generation
  String _getDailyReminderTitle(String novenaTitle, int day) {
    return '🙏 Time for Prayer - Day $day';
  }

  String _getDailyReminderBody(int day) {
    return 'Your novena prayer for day $day is ready. Take a moment to connect with God.';
  }

  String _getFollowUpTitle(String novenaTitle) {
    return '✨ Gentle Reminder';
  }

  String _getFollowUpBody(int day) {
    return 'Your day $day prayer is still waiting for you whenever you\'re ready.';
  }

  String _getProgressNotificationBody(
    ActiveNovena activeNovena,
    int completedDay,
  ) {
    final remaining = 9 - activeNovena.accessibleCompletedCount;
    if (remaining == 0) {
      return 'Congratulations! You have completed your novena. 🎉';
    } else {
      return '$remaining days remaining. Keep going! 💪';
    }
  }
}

/// Service health report for debugging
class ServiceHealthReport {
  bool isInitialized = false;
  bool hasPermissions = false;
  String? permissionError;
  int pendingNotificationCount = 0;
  String? pendingNotificationError;
  String? timezoneStatus;

  bool get isHealthy =>
      isInitialized && hasPermissions && permissionError == null;

  @override
  String toString() {
    return 'ServiceHealthReport(\n'
        '  initialized: $isInitialized\n'
        '  permissions: $hasPermissions\n'
        '  permissionError: $permissionError\n'
        '  pendingNotifications: $pendingNotificationCount\n'
        '  timezone: $timezoneStatus\n'
        '  healthy: $isHealthy\n'
        ')';
  }
}

/// Result classes for better error handling
class NotificationScheduleResult {
  final bool success;
  final int scheduledCount;
  final String? error;
  final List<String> errors;

  NotificationScheduleResult._({
    required this.success,
    required this.scheduledCount,
    this.error,
    this.errors = const [],
  });

  factory NotificationScheduleResult.success(int count) =>
      NotificationScheduleResult._(success: true, scheduledCount: count);

  factory NotificationScheduleResult.failure(String error) =>
      NotificationScheduleResult._(
        success: false,
        scheduledCount: 0,
        error: error,
      );

  factory NotificationScheduleResult.partial(int count, List<String> errors) =>
      NotificationScheduleResult._(
        success: true,
        scheduledCount: count,
        errors: errors,
      );
}

class DayScheduleResult {
  final bool success;
  final int count;
  final String? error;
  final bool skipped;

  DayScheduleResult._({
    required this.success,
    required this.count,
    this.error,
    this.skipped = false,
  });

  factory DayScheduleResult.success(int count) =>
      DayScheduleResult._(success: true, count: count);
  factory DayScheduleResult.failure(String error) =>
      DayScheduleResult._(success: false, count: 0, error: error);
  factory DayScheduleResult.skipped(String reason) => DayScheduleResult._(
    success: false,
    count: 0,
    error: reason,
    skipped: true,
  );
}
