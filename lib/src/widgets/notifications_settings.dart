import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/base_settings_provider.dart';
import 'settings_section_header.dart';

/// Standardized notifications settings for all Sancta Via apps
class NotificationsSettings extends ConsumerWidget {
  final bool showHeader;
  final String? title;
  final String? subtitle;
  final List<NotificationOption>? customOptions;
  final VoidCallback? onConfigureNotifications;

  const NotificationsSettings({
    super.key,
    this.showHeader = true,
    this.title,
    this.subtitle,
    this.customOptions,
    this.onConfigureNotifications,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsEnabled = ref.watch(notificationsEnabledProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        if (showHeader)
          const SettingsSectionHeader(title: 'Notifications'),

        // Main notifications toggle
        SwitchListTile(
          secondary: const Icon(Icons.notifications),
          title: Text(title ?? 'Notifications'),
          subtitle: Text(subtitle ?? 'Enable app notifications'),
          value: notificationsEnabled,
          onChanged: (bool value) {
            ref.read(baseSettingsProvider.notifier).setNotificationsEnabled(value);
          },
        ),

        // Configure notifications (if enabled)
        if (notificationsEnabled && onConfigureNotifications != null)
          ListTile(
            leading: const SizedBox(width: 24), // Align with toggle
            title: const Text('Configure Notifications'),
            subtitle: const Text('Manage notification types and timing'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: onConfigureNotifications,
          ),

        // Custom notification options
        if (notificationsEnabled && customOptions != null)
          ...customOptions!.map((option) => NotificationOptionTile(option: option)),

        // Notification info (if disabled)
        if (!notificationsEnabled)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Text(
              'Enable notifications to receive reminders and updates.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          ),
      ],
    );
  }
}

/// Configuration for a notification option
class NotificationOption {
  final String title;
  final String? subtitle;
  final IconData? icon;
  final bool enabled;
  final ValueChanged<bool>? onChanged;

  const NotificationOption({
    required this.title,
    this.subtitle,
    this.icon,
    this.enabled = false,
    this.onChanged,
  });
}

/// Individual notification option tile
class NotificationOptionTile extends StatelessWidget {
  final NotificationOption option;

  const NotificationOptionTile({
    super.key,
    required this.option,
  });

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      secondary: Icon(option.icon ?? Icons.notifications_outlined),
      title: Text(option.title),
      subtitle: option.subtitle != null ? Text(option.subtitle!) : null,
      value: option.enabled,
      onChanged: option.onChanged,
    );
  }
}

/// Compact notifications toggle
class NotificationsToggle extends ConsumerWidget {
  final String? label;

  const NotificationsToggle({
    super.key,
    this.label,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsEnabled = ref.watch(notificationsEnabledProvider);

    return Row(
      children: [
        const Icon(Icons.notifications),
        const SizedBox(width: 8),
        Text(label ?? 'Notifications'),
        const Spacer(),
        Switch(
          value: notificationsEnabled,
          onChanged: (value) {
            ref.read(baseSettingsProvider.notifier).setNotificationsEnabled(value);
          },
        ),
      ],
    );
  }
}

/// Notification permission helper
class NotificationPermissionHelper extends StatelessWidget {
  final VoidCallback? onRequestPermission;

  const NotificationPermissionHelper({
    super.key,
    this.onRequestPermission,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.notifications_off,
                  color: Theme.of(context).colorScheme.secondary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Notification Permission Required',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'To receive prayer reminders and other notifications, please grant notification permission in your device settings.',
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () {
                    // Could open app settings here
                  },
                  child: const Text('Settings'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: onRequestPermission,
                  child: const Text('Request Permission'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Predefined notification options for Catholic apps
class CatholicNotificationOptions {
  static NotificationOption prayerReminders({
    bool enabled = false,
    ValueChanged<bool>? onChanged,
  }) {
    return NotificationOption(
      title: 'Prayer Reminders',
      subtitle: 'Daily prayer notifications',
      icon: Icons.schedule,
      enabled: enabled,
      onChanged: onChanged,
    );
  }

  static NotificationOption liturgicalCalendar({
    bool enabled = false,
    ValueChanged<bool>? onChanged,
  }) {
    return NotificationOption(
      title: 'Liturgical Calendar',
      subtitle: 'Feast days and special observances',
      icon: Icons.calendar_today,
      enabled: enabled,
      onChanged: onChanged,
    );
  }

  static NotificationOption examinations({
    bool enabled = false,
    ValueChanged<bool>? onChanged,
  }) {
    return NotificationOption(
      title: 'Examination Reminders',
      subtitle: 'Regular examination of conscience',
      icon: Icons.self_improvement,
      enabled: enabled,
      onChanged: onChanged,
    );
  }

  static NotificationOption novenas({
    bool enabled = false,
    ValueChanged<bool>? onChanged,
  }) {
    return NotificationOption(
      title: 'Novena Reminders',
      subtitle: 'Daily novena prayer notifications',
      icon: Icons.auto_stories,
      enabled: enabled,
      onChanged: onChanged,
    );
  }
}
