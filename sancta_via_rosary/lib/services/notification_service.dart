import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../utils/logger.dart';

/// Service for managing local notifications in the Rosary app.
/// Handles initialization, permission requests, and daily reminder scheduling.
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  static NotificationService get instance => _instance;

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  NotificationService._internal();

  /// Whether the notification service has been initialized.
  bool get isInitialized => _isInitialized;

  /// Initialize the notification service.
  /// Must be called before using any other notification methods.
  Future<void> initialize() async {
    if (_isInitialized) {
      return;
    }

    // Initialize timezone data
    tz.initializeTimeZones();

    // Request permissions on iOS
    if (Platform.isIOS) {
      await _notificationsPlugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    }

    // Android initialization settings
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS initialization settings
    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        );

    // Combined initialization settings
    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    // Initialize the plugin
    await _notificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    _isInitialized = true;
    AppLogger.info('Notification service initialized', 'NOTIFICATION');
  }

  /// Request notification permissions from the user.
  /// Returns true if permission is granted.
  Future<bool> requestPermissions() async {
    if (!_isInitialized) {
      await initialize();
    }

    if (Platform.isIOS) {
      final bool? granted = await _notificationsPlugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true);
      return granted ?? false;
    }

    // On Android, permissions are requested at initialization for newer versions
    // For older versions, check if notifications are enabled
    return await areNotificationsEnabled();
  }

  /// Check if notifications are enabled/supported.
  Future<bool> areNotificationsEnabled() async {
    if (!_isInitialized) {
      return false;
    }

    final bool? granted = await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.areNotificationsEnabled();

    // On iOS, we rely on initialization success as a proxy
    if (Platform.isIOS) {
      return true;
    }

    return granted ?? false;
  }

  /// Schedule a daily notification at a specific time.
  /// [hour] and [minute] define the time of day (24-hour format).
  /// [id] is the unique identifier for the notification.
  /// [title] and [body] are the notification content.
  /// [payload] is optional data sent when notification is tapped.
  Future<void> scheduleDailyNotification({
    required int id,
    required int hour,
    required int minute,
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    // Create notification details
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'rosary_daily_reminder',
          'Daily Rosary Reminder',
          channelDescription: 'Reminds you to pray the rosary daily',
          importance: Importance.high,
          priority: Priority.high,
          showWhen: false,
        );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    // Get local timezone
    final location = tz.local;

    // Schedule for the next occurrence of this time
    final now = DateTime.now();
    var scheduledDate = DateTime(now.year, now.month, now.day, hour, minute);

    // If the time has already passed today, schedule for tomorrow
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    await _notificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(scheduledDate, location),
      notificationDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: payload,
    );

    AppLogger.info(
      'Scheduled daily notification at $hour:$minute',
      'NOTIFICATION',
    );
  }

  /// Cancel a specific notification by ID.
  Future<void> cancelNotification(int id) async {
    if (!_isInitialized) {
      return;
    }
    await _notificationsPlugin.cancel(id);
    AppLogger.info('Cancelled notification $id', 'NOTIFICATION');
  }

  /// Cancel all scheduled notifications.
  Future<void> cancelAllNotifications() async {
    if (!_isInitialized) {
      return;
    }
    await _notificationsPlugin.cancelAll();
    AppLogger.info('Cancelled all notifications', 'NOTIFICATION');
  }

  /// Show an immediate test notification.
  Future<void> showTestNotification() async {
    if (!_isInitialized) {
      await initialize();
    }

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'rosary_test',
          'Test Notification',
          channelDescription: 'Test notification for rosary reminders',
          importance: Importance.high,
          priority: Priority.high,
        );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails();

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notificationsPlugin.show(
      0,
      'Test Notification',
      'Your rosary reminder is working!',
      notificationDetails,
      payload: 'test',
    );

    AppLogger.info('Shown test notification', 'NOTIFICATION');
  }

  /// Schedule the daily rosary reminder.
  /// Convenience method with preset notification content.
  Future<void> scheduleDailyRosaryReminder({
    required int hour,
    required int minute,
  }) async {
    await scheduleDailyNotification(
      id: 1, // Fixed ID for daily reminder
      hour: hour,
      minute: minute,
      title: 'Time for your daily rosary',
      body: 'Take a moment to pray with the Sancta Via Rosary',
      payload: 'rosary_reminder',
    );
  }

  /// Cancel the daily rosary reminder.
  Future<void> cancelDailyRosaryReminder() async {
    await cancelNotification(1);
  }

  /// Handle notification tap.
  void _onNotificationTapped(NotificationResponse response) {
    final String? payload = response.payload;
    AppLogger.info(
      'Notification tapped with payload: $payload',
      'NOTIFICATION',
    );

    // The payload can be used by the app to navigate to specific screens
    // Navigation is handled by the app's router based on payload
  }
}
