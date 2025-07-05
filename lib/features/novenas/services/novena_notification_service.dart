import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import '../models/novena.dart';
import '../../../utils/logger.dart';

/// Navigation callback type for handling notification taps
typedef NotificationNavigationCallback = void Function(String payload);

/// Notification service specifically for novena reminders and updates
class NovenaNotificationService {
  static final NovenaNotificationService _instance = NovenaNotificationService._internal();
  factory NovenaNotificationService() => _instance;
  NovenaNotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  
  bool _isInitialized = false;
  bool _hasPermission = false;
  String? _lastError;
  NotificationNavigationCallback? _navigationCallback;

  // Notification ID scheme for novenas
  static const int _baseReminderIdDaily = 2000;      // 2000-2008 for daily reminders
  static const int _baseReminderIdFollowUp = 2100;   // 2100-2108 for follow-ups
  static const int _baseProgressId = 2200;           // 2200+ for progress notifications
  static const int _completionId = 2300;             // 2300 for completion

  /// Get current service status
  bool get isInitialized => _isInitialized;
  bool get hasPermission => _hasPermission;
  String? get lastError => _lastError;
  bool get isReady => _isInitialized && _hasPermission;
  
  /// Set navigation callback for handling notification taps
  void setNavigationCallback(NotificationNavigationCallback callback) {
    _navigationCallback = callback;
  }

  /// Initialize the notification service
  Future<bool> initialize() async {
    try {
      _lastError = null;
      AppLogger.debug('Initializing novena notification service...', 'NOTIFICATION');

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
      
      AppLogger.info('Notification service initialized successfully', 'NOTIFICATION');
      AppLogger.debug('Has notification permission: $_hasPermission', 'NOTIFICATION');
      return true;

    } catch (e) {
      _lastError = e.toString();
      AppLogger.error('Failed to initialize notification service', e, null, 'NOTIFICATION');
      return false;
    }
  }

  /// Initialize timezone with fallback
  Future<void> _initializeTimezone() async {
    try {
      tz.initializeTimeZones();
      
      // Try to set local timezone, fallback to UTC if it fails
      try {
        tz.setLocalLocation(tz.local);
        AppLogger.debug('Timezone set to local', 'NOTIFICATION');
      } catch (e) {
        AppLogger.warning('Failed to set local timezone, using UTC: $e', 'NOTIFICATION');
        tz.setLocalLocation(tz.UTC);
      }
    } catch (e) {
      AppLogger.error('Timezone initialization failed', e, null, 'NOTIFICATION');
    }
  }

  /// Request notification permissions
  Future<bool> _requestPermissions() async {
    try {
      if (Platform.isAndroid) {
        // Android 13+ requires notification permission
        final status = await Permission.notification.request();
        return status.isGranted;
      } else if (Platform.isIOS) {
        final granted = await _plugin
            .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
            ?.requestPermissions(
              alert: true,
              badge: false, // No badge numbers for spiritual context
              sound: true,
            );
        return granted ?? false;
      }
      return true;
    } catch (e) {
      AppLogger.error('Permission request failed', e, null, 'NOTIFICATION');
      return false;
    }
  }

  /// Schedule complete notification system for a novena
  Future<NotificationScheduleResult> scheduleNovenaNotifications(
    ActiveNovena activeNovena,
    String novenaTitle,
  ) async {
    if (!isReady) {
      return NotificationScheduleResult.failure('Notification service not ready');
    }

    try {
      AppLogger.debug('Scheduling notifications for novena: $novenaTitle', 'NOTIFICATION');
      
      // Clear any existing notifications first
      await cancelAllNovenaNotifications();
      
      int scheduledCount = 0;
      final errors = <String>[];
      
      // Schedule daily reminders for each day
      for (int day = 1; day <= 9; day++) {
        final result = await _scheduleDayReminders(activeNovena, novenaTitle, day);
        if (result.success) {
          scheduledCount += result.count;
        } else {
          errors.add('Day $day: ${result.error}');
        }
      }
      
      AppLogger.info('Scheduled $scheduledCount notifications', 'NOTIFICATION');
      
      if (scheduledCount == 0) {
        return NotificationScheduleResult.failure('No notifications could be scheduled');
      } else if (errors.isNotEmpty) {
        return NotificationScheduleResult.partial(scheduledCount, errors);
      } else {
        return NotificationScheduleResult.success(scheduledCount);
      }
      
    } catch (e, stackTrace) {
      _lastError = e.toString();
      AppLogger.error('Failed to schedule notifications', e, stackTrace, 'NOTIFICATION');
      return NotificationScheduleResult.failure(e.toString());
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
        return DayScheduleResult.skipped('Day $day reminder time is in the past');
      }

      int scheduledCount = 0;

      // 1. Schedule main daily reminder
      await _scheduleNotification(
        id: _baseReminderIdDaily + day - 1,
        title: _getDailyReminderTitle(novenaTitle, day),
        body: _getDailyReminderBody(day),
        scheduledTime: reminderTime,
        payload: 'daily_reminder_$day',
        isDaily: true,
      );
      scheduledCount++;

      // 2. Schedule follow-up reminders based on frequency
      final followUpTimes = _calculateFollowUpTimes(reminderTime, activeNovena.reminderFrequency);
      for (int i = 0; i < followUpTimes.length; i++) {
        await _scheduleNotification(
          id: _baseReminderIdFollowUp + day - 1 + (i * 10), // Unique IDs
          title: _getFollowUpTitle(novenaTitle),
          body: _getFollowUpBody(day),
          scheduledTime: followUpTimes[i],
          payload: 'follow_up_${day}_$i',
          isDaily: false,
        );
        scheduledCount++;
      }

      AppLogger.debug('Scheduled $scheduledCount notifications for day $day', 'NOTIFICATION');
      return DayScheduleResult.success(scheduledCount);
      
    } catch (e) {
      AppLogger.error('Failed to schedule day $day', e, null, 'NOTIFICATION');
      return DayScheduleResult.failure(e.toString());
    }
  }

  /// Calculate follow-up reminder times based on frequency
  List<DateTime> _calculateFollowUpTimes(DateTime initialTime, ReminderInterval frequency) {
    final times = <DateTime>[];
    final endOfDay = DateTime(initialTime.year, initialTime.month, initialTime.day, 22, 0); // Stop at 10 PM
    
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

  /// Schedule individual notification
  Future<void> _scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
    required String payload,
    required bool isDaily,
  }) async {
    try {
      final tzDateTime = tz.TZDateTime.from(scheduledTime, tz.local);
      
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        tzDateTime,
        _getNotificationDetails(isDaily),
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload,
      );
      
    } catch (e) {
      AppLogger.warning('Failed to schedule notification $id: $e', 'NOTIFICATION');
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
      final id = isCompletion ? _completionId : _baseProgressId + DateTime.now().millisecond;
      
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
            color: isCompletion ? const Color(0xFFFFD700) : const Color(0xFF4CAF50), // Gold for completion
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
      AppLogger.error('Failed to send progress notification', e, null, 'NOTIFICATION');
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
      
      AppLogger.debug('Cancelled notifications for day $day', 'NOTIFICATION');
    } catch (e) {
      AppLogger.error('Failed to cancel day $day notifications', e, null, 'NOTIFICATION');
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
      AppLogger.error('Failed to cancel notifications', e, null, 'NOTIFICATION');
    }
  }

  /// Handle notification tap
  void _onNotificationTapped(NotificationResponse response) {
    AppLogger.debug('Notification tapped: ${response.payload}', 'NOTIFICATION');
    
    if (_navigationCallback != null && response.payload != null) {
      _navigationCallback!(response.payload!);
    } else {
      AppLogger.warning('No navigation callback set or payload is null', 'NOTIFICATION');
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
      NotificationScheduleResult._(success: false, scheduledCount: 0, error: error);

  factory NotificationScheduleResult.partial(int count, List<String> errors) =>
      NotificationScheduleResult._(success: true, scheduledCount: count, errors: errors);
}

class DayScheduleResult {
  final bool success;
  final int count;
  final String? error;
  final bool skipped;

  DayScheduleResult._({required this.success, required this.count, this.error, this.skipped = false});

  factory DayScheduleResult.success(int count) => DayScheduleResult._(success: true, count: count);
  factory DayScheduleResult.failure(String error) => 
      DayScheduleResult._(success: false, count: 0, error: error);
  factory DayScheduleResult.skipped(String reason) => 
      DayScheduleResult._(success: false, count: 0, error: reason, skipped: true);
}
