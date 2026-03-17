import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:sancta_via_shared_ui/sancta_via_shared_ui.dart';

import '../../providers/audio_provider.dart';
import '../../providers/notification_settings_provider.dart';

/// Rosary settings screen using the unified settings pattern.
///
/// Provides access to all app settings including:
/// - Appearance (theme, color intensity, font size)
/// - Accessibility (text scaling, reduce motion)
/// - Language (prayer language)
/// - Notifications (rosary reminders)
/// - App-specific settings (audio, auto-play)
/// - About (app info, support)
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<PackageInfo>(
      future: PackageInfo.fromPlatform(),
      builder: (context, snapshot) {
        // App information for the unified screen
        final appInfo = AppInfo(
          appName: 'Sancta Via Rosary',
          version: snapshot.hasData ? snapshot.data!.version : '1.0.0',
          description:
              'A Catholic prayer companion app to help you meditate on the Holy Rosary. '
              'Features guided audio prayers, mystery reflections, and daily reminders '
              'to support your devotional practice.',
          icon: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.favorite, color: Colors.white, size: 32),
          ),
          onSupport: () => _showSupportDialog(context),
        );

        // Rosary-specific settings section
        final rosarySpecificSettings = _buildRosarySpecificSettings(
          context,
          ref,
        );

        return UnifiedSettingsScreen(
          appInfo: appInfo,
          appSpecificSettings: rosarySpecificSettings,
          customNotifications: [
            CatholicNotificationOptions.prayerReminders(
              enabled: ref.watch(rosarySettingsProvider).dailyReminderEnabled,
              onChanged: (enabled) {
                ref
                    .read(rosarySettingsProvider.notifier)
                    .setDailyReminderEnabled(enabled);
              },
            ),
            CatholicNotificationOptions.liturgicalCalendar(
              enabled:
                  false, // TODO: Implement liturgical calendar notifications
              onChanged: (enabled) {
                _showComingSoon(context, 'Liturgical calendar notifications');
              },
            ),
          ],
        );
      },
    );
  }

  /// Builds the Rosary-specific settings section.
  ///
  /// Includes:
  /// - Audio settings (enable/disable, volume)
  /// - Auto-play prayers toggle
  /// - Haptic feedback toggle
  /// - Prayer language selector
  /// - Statistics navigation
  Widget _buildRosarySpecificSettings(BuildContext context, WidgetRef ref) {
    final rosarySettings = ref.watch(rosarySettingsProvider);
    final rosaryNotifier = ref.read(rosarySettingsProvider.notifier);
    final autoAdvanceEnabled = ref.watch(autoAdvanceProvider);
    final notificationsEnabled = rosarySettings.notificationsEnabled;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ═══════════════════════════════════════
        // AUDIO SETTINGS SECTION
        // ═══════════════════════════════════════
        const SettingsSectionHeader(title: 'Audio Settings'),

        // Auto-play prayers toggle
        SwitchListTile(
          secondary: const Icon(Icons.play_circle_outline),
          title: const Text('Auto-play Prayers'),
          subtitle: const Text('Automatically play audio when advancing'),
          value: autoAdvanceEnabled,
          onChanged: (value) {
            ref.read(autoAdvanceProvider.notifier).setEnabled(value);
          },
        ),

        // Haptic feedback toggle
        Consumer(
          builder: (context, ref, child) {
            final hapticEnabled = ref.watch(
              baseSettingsProvider.select((s) => s.hapticFeedbackEnabled),
            );
            return SwitchListTile(
              secondary: const Icon(Icons.vibration),
              title: const Text('Haptic Feedback'),
              subtitle: const Text('Vibrate on prayer transitions'),
              value: hapticEnabled,
              onChanged: (value) {
                ref
                    .read(baseSettingsProvider.notifier)
                    .setHapticFeedbackEnabled(value);
              },
            );
          },
        ),

        const Divider(),

        // ═══════════════════════════════════════
        // NOTIFICATION SETTINGS SECTION
        // ═══════════════════════════════════════
        const SettingsSectionHeader(title: 'Rosary Reminders'),

        // Main notifications toggle
        SwitchListTile(
          secondary: const Icon(Icons.notifications),
          title: const Text('Enable Notifications'),
          subtitle: const Text('Allow daily prayer reminders'),
          value: notificationsEnabled,
          onChanged: (value) {
            rosaryNotifier.setNotificationsEnabled(value);
          },
        ),

        // Daily reminder toggle
        if (notificationsEnabled)
          SwitchListTile(
            secondary: const SizedBox(width: 24),
            title: const Text('Daily Rosary Reminder'),
            subtitle: const Text('Get reminded to pray the rosary'),
            value: rosarySettings.dailyReminderEnabled,
            onChanged: (value) {
              rosaryNotifier.setDailyReminderEnabled(value);
            },
          ),

        // Reminder time selector
        if (notificationsEnabled && rosarySettings.dailyReminderEnabled)
          ListTile(
            leading: const SizedBox(width: 24),
            title: const Text('Reminder Time'),
            subtitle: Text(rosaryNotifier.formattedReminderTime),
            trailing: const Icon(Icons.access_time),
            onTap: () => _showTimePicker(context, ref, rosarySettings),
          ),

        // Configure notifications link
        if (notificationsEnabled)
          ListTile(
            leading: const SizedBox(width: 24),
            title: const Text('Advanced Notification Settings'),
            subtitle: const Text('Test notifications and more options'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => context.push('/settings/notifications'),
          ),

        const Divider(),

        // ═══════════════════════════════════════
        // STATISTICS SECTION
        // ═══════════════════════════════════════
        const SettingsSectionHeader(title: 'Statistics'),

        ListTile(
          leading: const Icon(Icons.bar_chart),
          title: const Text('View Statistics'),
          subtitle: const Text('See your prayer history and progress'),
          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
          onTap: () => context.push('/statistics'),
        ),

        const Divider(),
      ],
    );
  }

  /// Show time picker for reminder time
  Future<void> _showTimePicker(
    BuildContext context,
    WidgetRef ref,
    RosarySettings settings,
  ) async {
    final TimeOfDay initialTime = TimeOfDay(
      hour: settings.reminderHour,
      minute: settings.reminderMinute,
    );

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
          .read(rosarySettingsProvider.notifier)
          .setReminderTime(selectedTime.hour, selectedTime.minute);
    }
  }

  /// Show support dialog
  void _showSupportDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Support Sancta Via Rosary'),
        content: const Text(
          'Sancta Via Rosary is part of the Sancta Via ecosystem of Catholic applications.\n\n'
          'This app helps Catholics meditate on the Holy Rosary with guided audio prayers, '
          'mystery reflections, and daily reminders to support your devotional practice.\n\n'
          'Your support helps us continue developing high-quality Catholic applications for the faithful.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  /// Show coming soon snackbar
  void _showComingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature - Coming Soon'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
