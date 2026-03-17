import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/settings_state.dart';
import '../../providers/settings_provider.dart';
import '../../services/notification_service.dart';

/// Screen for configuring notification settings for the Rosary app.
/// Uses the unified RosaryAppSettingsProvider for settings persistence.
class NotificationSettingsScreen extends ConsumerWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(rosaryAppSettingsProvider);
    final notifier = ref.read(rosaryAppSettingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Settings'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Main notifications toggle
          Card(
            child: SwitchListTile(
              secondary: const Icon(Icons.notifications),
              title: const Text('Enable Notifications'),
              subtitle: const Text(
                'Allow the app to send you prayer reminders',
              ),
              value: settings.rosaryNotificationsEnabled,
              onChanged: (value) =>
                  notifier.setRosaryNotificationsEnabled(value),
            ),
          ),

          const SizedBox(height: 16),

          // Daily reminder section
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.schedule),
                  title: const Text('Daily Rosary Reminder'),
                  subtitle: Text(
                    settings.dailyReminderEnabled
                        ? 'Reminder set for ${settings.formattedReminderTime}'
                        : 'Get a daily reminder to pray the rosary',
                  ),
                ),
                if (settings.rosaryNotificationsEnabled)
                  SwitchListTile(
                    secondary: const SizedBox(width: 24),
                    title: const Text('Enable Daily Reminder'),
                    value: settings.dailyReminderEnabled,
                    onChanged: (value) =>
                        notifier.setDailyReminderEnabled(value),
                  ),
                if (settings.rosaryNotificationsEnabled &&
                    settings.dailyReminderEnabled)
                  ListTile(
                    leading: const SizedBox(width: 24),
                    title: const Text('Reminder Time'),
                    subtitle: Text(settings.formattedReminderTime),
                    trailing: const Icon(Icons.access_time),
                    onTap: () => _showTimePicker(context, ref, settings),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Test notification
          if (settings.rosaryNotificationsEnabled)
            Card(
              child: ListTile(
                leading: const Icon(Icons.notification_add),
                title: const Text('Test Notification'),
                subtitle: const Text('Send a test notification now'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () => _showTestNotification(context, ref),
              ),
            ),

          const SizedBox(height: 32),

          // Info section
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              'Daily reminders help you maintain a consistent prayer routine. '
              'You can change the time or disable reminders at any time.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  /// Show time picker for reminder time
  Future<void> _showTimePicker(
    BuildContext context,
    WidgetRef ref,
    RosaryAppSettings settings,
  ) async {
    final TimeOfDay initialTime = settings.dailyReminderTimeOfDay;

    final TimeOfDay? selectedTime = await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
          child: child!,
        );
      },
    );

    if (selectedTime != null) {
      await ref
          .read(rosaryAppSettingsProvider.notifier)
          .setDailyReminderTime(selectedTime);
    }
  }

  /// Show and send a test notification
  Future<void> _showTestNotification(
    BuildContext context,
    WidgetRef ref,
  ) async {
    await NotificationService.instance.showTestNotification();

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Test notification sent!'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }
}
