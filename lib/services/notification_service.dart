import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:permission_handler/permission_handler.dart';

import '../models/reading_plan.dart';

/// Service for managing local notifications for reading plan reminders
class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications = 
      FlutterLocalNotificationsPlugin();
  
  static bool _isInitialized = false;

  /// Initialize the notification service
  static Future<void> initialize() async {
    if (_isInitialized) return;

    // Initialize timezone data
    tz.initializeTimeZones();
    
    // Android settings
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    
    // iOS settings
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    _isInitialized = true;
  }

  /// Handle notification tap
  static void _onNotificationTapped(NotificationResponse response) {
    // TODO: Navigate to reading plan or continue reading screen
    // This would need access to navigation context
    debugPrint('Notification tapped: ${response.payload}');
  }

  /// Request notification permissions
  static Future<bool> requestPermissions() async {
    if (!_isInitialized) await initialize();

    // Request permission for notifications
    final permission = await Permission.notification.request();
    
    // For exact alarms on Android 12+
    if (permission.isGranted) {
      final exactAlarmPermission = await Permission.scheduleExactAlarm.request();
      return exactAlarmPermission.isGranted;
    }
    
    return permission.isGranted;
  }

  /// Schedule daily reminder for a reading plan
  static Future<void> scheduleReadingReminder(ReadingPlan plan) async {
    if (!plan.remindersEnabled || plan.reminderTime == null) return;
    
    if (!_isInitialized) await initialize();

    // Cancel existing notifications for this plan
    await cancelPlanNotifications(plan.id);

    // Get the reminder time
    final reminderTime = plan.reminderTime!;
    
    // Schedule for each day the plan is active
    for (final dayOfWeek in plan.scheduledDays) {
      await _scheduleDailyNotification(
        plan: plan,
        dayOfWeek: dayOfWeek,
        time: reminderTime,
      );
    }
  }

  /// Schedule a notification for a specific day of the week
  static Future<void> _scheduleDailyNotification({
    required ReadingPlan plan,
    required DayOfWeek dayOfWeek,
    required TimeOfDay time,
  }) async {
    // Create unique ID for this plan + day combination
    final notificationId = _generateNotificationId(plan.id, dayOfWeek);
    
    // Get next occurrence of this day at the specified time
    final scheduledDate = _getNextScheduledDate(dayOfWeek, time);
    
    // Create notification details
    const androidDetails = AndroidNotificationDetails(
      'reading_reminders',
      'Reading Reminders',
      channelDescription: 'Daily Bible reading reminders',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );
    
    const iosDetails = DarwinNotificationDetails();
    
    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    // Schedule the notification
    await _notifications.zonedSchedule(
      notificationId,
      'Time for Bible Reading! 📖',
      'Your ${plan.name} reading plan is ready.',
      scheduledDate,
      notificationDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: 
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      payload: plan.id,
    );
  }

  /// Generate unique notification ID
  static int _generateNotificationId(String planId, DayOfWeek dayOfWeek) {
    // Combine plan ID hash with day of week to create unique ID
    return planId.hashCode + dayOfWeek.value;
  }

  /// Get next scheduled date for a day of week and time
  static tz.TZDateTime _getNextScheduledDate(DayOfWeek dayOfWeek, TimeOfDay time) {
    final now = tz.TZDateTime.now(tz.local);
    final targetDay = dayOfWeek.value; // 1 = Monday, 7 = Sunday
    
    // Calculate days until target day
    int daysUntilTarget = targetDay - now.weekday;
    if (daysUntilTarget <= 0) {
      daysUntilTarget += 7; // Move to next week
    }
    
    // If it's today and the time hasn't passed, schedule for today
    if (daysUntilTarget == 7) {
      final todayAtTime = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        time.hour,
        time.minute,
      );
      
      if (todayAtTime.isAfter(now)) {
        return todayAtTime;
      }
    }
    
    // Schedule for the target day
    final targetDate = now.add(Duration(days: daysUntilTarget));
    return tz.TZDateTime(
      tz.local,
      targetDate.year,
      targetDate.month,
      targetDate.day,
      time.hour,
      time.minute,
    );
  }

  /// Cancel all notifications for a specific plan
  static Future<void> cancelPlanNotifications(String planId) async {
    if (!_isInitialized) await initialize();

    // Cancel notifications for all days of the week
    for (final dayOfWeek in DayOfWeek.values) {
      final notificationId = _generateNotificationId(planId, dayOfWeek);
      await _notifications.cancel(notificationId);
    }
  }

  /// Update notifications for a plan (cancel old ones and schedule new ones)
  static Future<void> updatePlanNotifications(ReadingPlan plan) async {
    await cancelPlanNotifications(plan.id);
    if (plan.remindersEnabled && plan.isActive) {
      await scheduleReadingReminder(plan);
    }
  }

  /// Cancel all notifications
  static Future<void> cancelAllNotifications() async {
    if (!_isInitialized) await initialize();
    await _notifications.cancelAll();
  }

  /// Get pending notifications (for debugging)
  static Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    if (!_isInitialized) await initialize();
    return await _notifications.pendingNotificationRequests();
  }
}
