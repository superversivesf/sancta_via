import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sancta_via_shared_ui/sancta_via_shared_ui.dart';

import '../../providers/settings_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(fastingSettingsProvider);
    final themeMode = ref.watch(themeModeProvider);
    final colorIntensity = ref.watch(colorIntensityProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // App Information
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'App Information',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Sancta Via Fasting Companion',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Version 0.1.0',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'A Catholic fasting companion app with liturgical calendar integration.',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Theme Settings
          _SectionHeader(title: 'Appearance'),
          const SizedBox(height: 12),

          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.brightness_6),
                  title: const Text('Theme Mode'),
                  subtitle: Text(
                    themeMode == ThemeMode.system
                        ? 'System'
                        : themeMode == ThemeMode.light
                            ? 'Light'
                            : 'Dark',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showThemeModeDialog(context, ref, themeMode),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.palette),
                  title: const Text('Color Intensity'),
                  subtitle: Text(
                    colorIntensity == ColorIntensity.vibrant
                        ? 'Vibrant'
                        : 'Muted',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () =>
                      _showColorIntensityDialog(context, ref, colorIntensity),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Notification Settings
          _SectionHeader(title: 'Notifications'),
          const SizedBox(height: 12),

          Card(
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.notifications),
                  title: const Text('Enable Notifications'),
                  subtitle: const Text('Get notified about fast milestones'),
                  value: settings.notificationsEnabled,
                  onChanged: (value) {
                    ref
                        .read(fastingSettingsProvider.notifier)
                        .setNotificationsEnabled(value);
                  },
                ),
                const Divider(height: 1),
                SwitchListTile(
                  secondary: const Icon(Icons.favorite),
                  title: const Text('Hourly Reminders'),
                  subtitle: const Text('Receive hourly encouragements'),
                  value: settings.hourlyReminders,
                  onChanged: settings.notificationsEnabled
                      ? (value) {
                          ref
                              .read(fastingSettingsProvider.notifier)
                              .setHourlyReminders(value);
                        }
                      : null,
                ),
                const Divider(height: 1),
                SwitchListTile(
                  secondary: const Icon(Icons.check_circle),
                  title: const Text('Milestone Reminders'),
                  subtitle: const Text('Get notified at 25%, 50%, 75%'),
                  value: settings.milestoneReminders,
                  onChanged: settings.notificationsEnabled
                      ? (value) {
                          ref
                              .read(fastingSettingsProvider.notifier)
                              .setMilestoneReminders(value);
                        }
                      : null,
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Timer Settings
          _SectionHeader(title: 'Timer'),
          const SizedBox(height: 12),

          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.timer),
                  title: const Text('Timer Update Interval'),
                  subtitle: Text(
                    '${settings.timerUpdateInterval} seconds',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showTimerIntervalDialog(context, ref, settings),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  secondary: const Icon(Icons.vibration),
                  title: const Text('Vibration'),
                  subtitle: const Text('Device vibrates when reaching milestones'),
                  value: settings.vibrationEnabled,
                  onChanged: (value) {
                    ref
                        .read(fastingSettingsProvider.notifier)
                        .setVibrationEnabled(value);
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // About & Support
          _SectionHeader(title: 'About & Support'),
          const SizedBox(height: 12),

          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.privacy_tip),
                  title: const Text('Privacy Policy'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    // TODO: Show privacy policy
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Privacy Policy coming soon!'),
                      ),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.help),
                  title: const Text('Help & Support'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    // TODO: Show help
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Help coming soon!'),
                      ),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.church),
                  title: const Text('About Sancta Via'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    _showAboutDialog(context);
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  void _showThemeModeDialog(
    BuildContext context,
    WidgetRef ref,
    ThemeMode currentMode,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Theme Mode'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<ThemeMode>(
              title: const Text('System'),
              subtitle: const Text('Follow device theme'),
              value: ThemeMode.system,
              groupValue: currentMode,
              onChanged: (value) {
                ref.read(themeModeProvider.notifier).setThemeMode(value!);
                Navigator.of(context).pop();
              },
            ),
            RadioListTile<ThemeMode>(
              title: const Text('Light'),
              subtitle: const Text('Always use light theme'),
              value: ThemeMode.light,
              groupValue: currentMode,
              onChanged: (value) {
                ref.read(themeModeProvider.notifier).setThemeMode(value!);
                Navigator.of(context).pop();
              },
            ),
            RadioListTile<ThemeMode>(
              title: const Text('Dark'),
              subtitle: const Text('Always use dark theme'),
              value: ThemeMode.dark,
              groupValue: currentMode,
              onChanged: (value) {
                ref.read(themeModeProvider.notifier).setThemeMode(value!);
                Navigator.of(context).pop();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showColorIntensityDialog(
    BuildContext context,
    WidgetRef ref,
    ColorIntensity currentIntensity,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Color Intensity'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<ColorIntensity>(
              title: const Text('Vibrant'),
              subtitle: const Text('Bright, saturated colors'),
              value: ColorIntensity.vibrant,
              groupValue: currentIntensity,
              onChanged: (value) {
                ref
                    .read(colorIntensityProvider.notifier)
                    .setColorIntensity(value!);
                Navigator.of(context).pop();
              },
            ),
            RadioListTile<ColorIntensity>(
              title: const Text('Muted'),
              subtitle: const Text('Soft, subdued colors'),
              value: ColorIntensity.muted,
              groupValue: currentIntensity,
              onChanged: (value) {
                ref
                    .read(colorIntensityProvider.notifier)
                    .setColorIntensity(value!);
                Navigator.of(context).pop();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showTimerIntervalDialog(
    BuildContext context,
    WidgetRef ref,
    FastingSettings settings,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Timer Update Interval'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<int>(
              title: const Text('1 second'),
              value: 1,
              groupValue: settings.timerUpdateInterval,
              onChanged: (value) {
                ref
                    .read(fastingSettingsProvider.notifier)
                    .setTimerUpdateInterval(value!);
                Navigator.of(context).pop();
              },
            ),
            RadioListTile<int>(
              title: const Text('5 seconds'),
              value: 5,
              groupValue: settings.timerUpdateInterval,
              onChanged: (value) {
                ref
                    .read(fastingSettingsProvider.notifier)
                    .setTimerUpdateInterval(value!);
                Navigator.of(context).pop();
              },
            ),
            RadioListTile<int>(
              title: const Text('10 seconds'),
              value: 10,
              groupValue: settings.timerUpdateInterval,
              onChanged: (value) {
                ref
                    .read(fastingSettingsProvider.notifier)
                    .setTimerUpdateInterval(value!);
                Navigator.of(context).pop();
              },
            ),
            RadioListTile<int>(
              title: const Text('30 seconds'),
              value: 30,
              groupValue: settings.timerUpdateInterval,
              onChanged: (value) {
                ref
                    .read(fastingSettingsProvider.notifier)
                    .setTimerUpdateInterval(value!);
                Navigator.of(context).pop();
              },
            ),
            RadioListTile<int>(
              title: const Text('60 seconds (saves battery)'),
              value: 60,
              groupValue: settings.timerUpdateInterval,
              onChanged: (value) {
                ref
                    .read(fastingSettingsProvider.notifier)
                    .setTimerUpdateInterval(value!);
                Navigator.of(context).pop();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('About Sancta Via'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sancta Via Fasting Companion',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'Part of the Sancta Via ecosystem of Catholic mobile applications.',
            ),
            SizedBox(height: 16),
            Text(
              'Features:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 4),
            Text('• Multiple fasting protocols'),
            Text('• Liturgical calendar integration'),
            Text('• Catholic prayers and encouragements'),
            Text('• Progress tracking and statistics'),
            Text('• Milestone notifications'),
            SizedBox(height: 16),
            Text(
              'May your fasting draw you closer to God.',
              style: TextStyle(fontStyle: FontStyle.italic),
            ),
          ],
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
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
    );
  }
}
