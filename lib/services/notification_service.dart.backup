import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:permission_handler/permission_handler.dart';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kDebugMode;

import '../models/reading_plan.dart';

/// Service for managing local notifications for reading plan reminders
class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications = 
      FlutterLocalNotificationsPlugin();
  
  static bool _isInitialized = false;
  static bool _permissionsRequested = false; // Track if we've requested permissions

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

  /// Check if notification permissions are already granted
  static Future<bool> hasPermissions() async {
    if (!_isInitialized) await initialize();

    if (Platform.isIOS) {
      // Use flutter_local_notifications for iOS permission checking
      final iosPlugin = _notifications
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      
      if (iosPlugin != null) {
        final iosPermissions = await iosPlugin.checkPermissions();
        debugPrint('iOS notification permissions: $iosPermissions');
        
        // If permissions are denied but we're on simulator, be more lenient
        // iOS simulator often reports incorrect permission states
        if (iosPermissions?.isEnabled == true) {
          return true;
        } else {
          // On iOS simulator in debug mode, if we've already requested permissions,
          // assume they're granted (simulator limitation workaround)
          if (kDebugMode && Platform.isIOS && _permissionsRequested) {
            debugPrint('iOS simulator detected with previous permission request - assuming granted');
            return true;
          }
          debugPrint('iOS permissions check failed, might be simulator limitation');
          return false; // We'll let requestPermissions handle this
        }
      } else {
        debugPrint('Could not get iOS notification plugin');
        return false;
      }
    } else {
      // Use permission_handler for Android
      final permission = await Permission.notification.status;
      debugPrint('Android notification permission status: ${permission.name}');
      
      if (!permission.isGranted) {
        return false;
      }
      
      // For Android 12+ (API 31+), also check exact alarm permission
      try {
        final exactAlarmPermission = await Permission.scheduleExactAlarm.status;
        debugPrint('Exact alarm permission status: ${exactAlarmPermission.name}');
        return exactAlarmPermission.isGranted;
      } catch (e) {
        // If exact alarm permission is not available, basic permission is sufficient
        debugPrint('Exact alarm permission not available: $e');
        return permission.isGranted;
      }
    }
  }

  /// Request notification permissions
  static Future<bool> requestPermissions() async {
    if (!_isInitialized) await initialize();

    debugPrint('Requesting notification permissions...');
    
    if (Platform.isIOS) {
      // Use flutter_local_notifications for iOS permission requests
      final iosPlugin = _notifications
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      
      if (iosPlugin != null) {
        final granted = await iosPlugin.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        debugPrint('iOS notification permission request result: $granted');
        _permissionsRequested = true;
        
        // iOS simulator often returns false even when permissions are granted
        // If we're in debug mode (likely simulator), be more lenient
        if (granted == true) {
          return true;
        } else if (kDebugMode && Platform.isIOS) {
          debugPrint('iOS simulator detected - assuming permission granted despite false result');
          return true; // Assume granted on simulator
        } else {
          return false;
        }
      } else {
        debugPrint('Could not get iOS notification plugin');
        return false;
      }
    } else {
      // Use permission_handler for Android
      final permission = await Permission.notification.request();
      debugPrint('Android notification permission request result: ${permission.name}');
      
      if (!permission.isGranted) {
        return false;
      }
      
      // For Android 12+ (API 31+), also request exact alarm permission
      try {
        debugPrint('Requesting exact alarm permission for Android...');
        final exactAlarmPermission = await Permission.scheduleExactAlarm.request();
        debugPrint('Exact alarm permission request result: ${exactAlarmPermission.name}');
        return exactAlarmPermission.isGranted;
      } catch (e) {
        // If exact alarm permission is not available, continue with basic permission
        debugPrint('Exact alarm permission not available: $e');
        return permission.isGranted;
      }
    }
  }

  /// Schedule daily reminder for a reading plan
  static Future<void> scheduleReadingReminder(ReadingPlan plan) async {
    if (!plan.remindersEnabled || plan.reminderTime == null) {
      debugPrint('Skipping notification scheduling for plan ${plan.name}: reminders disabled or no time set');
      return;
    }
    
    if (!_isInitialized) await initialize();

    debugPrint('Scheduling notifications for plan: ${plan.name}');
    
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
    
    debugPrint('Scheduled ${plan.scheduledDays.length} notifications for plan ${plan.name}');
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
    
    debugPrint('Scheduling notification ID $notificationId for ${dayOfWeek.displayName} at ${time.hour}:${time.minute.toString().padLeft(2, '0')} - next occurrence: $scheduledDate');
    
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

    try {
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
      
      debugPrint('Successfully scheduled notification ID $notificationId');
    } catch (e) {
      debugPrint('Error scheduling notification ID $notificationId: $e');
    }
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
