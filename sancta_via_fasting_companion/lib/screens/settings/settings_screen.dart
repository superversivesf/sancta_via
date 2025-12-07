import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sancta_via_shared_ui/sancta_via_shared_ui.dart';

import '../../providers/achievement_providers.dart';
import '../../providers/export_import_providers.dart';
import '../../providers/fast_session_providers.dart';
import '../../providers/fast_type_providers.dart';
import '../../providers/settings_provider.dart';
import '../../providers/statistics_providers.dart';
import '../../services/export_import_service.dart';
import '../../services/notification_service.dart';

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

          // Notification Diagnostics Card
          _NotificationDiagnosticsCard(),

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
                const Divider(height: 1),
                SwitchListTile(
                  secondary: const Icon(Icons.flag),
                  title: const Text('Completion Reminders'),
                  subtitle: const Text('Get notified when fast target is reached'),
                  value: settings.completionReminders,
                  onChanged: settings.notificationsEnabled
                      ? (value) {
                          ref
                              .read(fastingSettingsProvider.notifier)
                              .setCompletionReminders(value);
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
                  secondary: const Icon(Icons.check_circle_outline),
                  title: const Text('Auto-End Fasts'),
                  subtitle: const Text(
                    'Automatically complete fasts when target is reached (default: manual)',
                  ),
                  value: settings.autoEndFasts,
                  onChanged: (value) {
                    ref
                        .read(fastingSettingsProvider.notifier)
                        .setAutoEndFasts(value);
                  },
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

          // Data Management
          _SectionHeader(title: 'Data Management'),
          const SizedBox(height: 12),

          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.file_download),
                  title: const Text('Export to CSV'),
                  subtitle: const Text('Export history as spreadsheet'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _exportToCSV(context, ref),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.backup),
                  title: const Text('Backup to JSON'),
                  subtitle: const Text('Complete backup with achievements'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _exportToJSON(context, ref),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.restore),
                  title: const Text('Restore from Backup'),
                  subtitle: const Text('Import from JSON backup file'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _importFromJSON(context, ref),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          Card(
            child: ListTile(
              leading: const Icon(Icons.delete_forever, color: Colors.red),
              title: const Text(
                'Clear All Data',
                style: TextStyle(color: Colors.red),
              ),
              subtitle: const Text(
                'Delete all fasts, history, and achievements',
              ),
              trailing: const Icon(Icons.chevron_right, color: Colors.red),
              onTap: () => _showClearDataDialog(context, ref),
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
                  leading: const Icon(Icons.bar_chart),
                  title: const Text('Statistics'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    context.push('/statistics');
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.emoji_events),
                  title: const Text('Achievements'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    context.push('/achievements');
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.privacy_tip),
                  title: const Text('Privacy Policy'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    context.push('/privacy-policy');
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.help),
                  title: const Text('Help & Support'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    context.push('/help');
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
        content: RadioGroup<ThemeMode>(
          groupValue: currentMode,
          onChanged: (value) {
            ref.read(themeModeProvider.notifier).setThemeMode(value!);
            Navigator.of(context).pop();
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<ThemeMode>(
                title: const Text('System'),
                subtitle: const Text('Follow device theme'),
                value: ThemeMode.system,
              ),
              RadioListTile<ThemeMode>(
                title: const Text('Light'),
                subtitle: const Text('Always use light theme'),
                value: ThemeMode.light,
              ),
              RadioListTile<ThemeMode>(
                title: const Text('Dark'),
                subtitle: const Text('Always use dark theme'),
                value: ThemeMode.dark,
              ),
            ],
          ),
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
        content: RadioGroup<ColorIntensity>(
          groupValue: currentIntensity,
          onChanged: (value) {
            ref
                .read(colorIntensityProvider.notifier)
                .setColorIntensity(value!);
            Navigator.of(context).pop();
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<ColorIntensity>(
                title: const Text('Vibrant'),
                subtitle: const Text('Bright, saturated colors'),
                value: ColorIntensity.vibrant,
              ),
              RadioListTile<ColorIntensity>(
                title: const Text('Muted'),
                subtitle: const Text('Soft, subdued colors'),
                value: ColorIntensity.muted,
              ),
            ],
          ),
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
        content: RadioGroup<int>(
          groupValue: settings.timerUpdateInterval,
          onChanged: (value) {
            ref
                .read(fastingSettingsProvider.notifier)
                .setTimerUpdateInterval(value!);
            Navigator.of(context).pop();
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<int>(
                title: const Text('1 second'),
                value: 1,
              ),
              RadioListTile<int>(
                title: const Text('5 seconds'),
                value: 5,
              ),
              RadioListTile<int>(
                title: const Text('10 seconds'),
                value: 10,
              ),
              RadioListTile<int>(
                title: const Text('30 seconds'),
                value: 30,
              ),
              RadioListTile<int>(
                title: const Text('60 seconds (saves battery)'),
                value: 60,
              ),
            ],
          ),
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

  Future<void> _exportToCSV(BuildContext context, WidgetRef ref) async {
    final exportService = ref.read(exportImportServiceProvider);

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Exporting to CSV...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final result = await exportService.exportToCSV();

      if (!context.mounted) return;
      Navigator.of(context).pop(); // Close loading dialog

      if (result.success && result.file != null) {
        // Share the file
        final shared = await exportService.shareExport(
          result.file!,
          ExportFormat.csv,
        );

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                shared
                    ? 'Exported ${result.recordCount} sessions to CSV'
                    : 'Export created but sharing cancelled',
              ),
              backgroundColor: shared ? Colors.green : Colors.orange,
            ),
          );
        }
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.errorMessage ?? 'Export failed'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error exporting: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _exportToJSON(BuildContext context, WidgetRef ref) async {
    final exportService = ref.read(exportImportServiceProvider);

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Creating backup...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final result = await exportService.exportToJSON();

      if (!context.mounted) return;
      Navigator.of(context).pop(); // Close loading dialog

      if (result.success && result.file != null) {
        // Share the file
        final shared = await exportService.shareExport(
          result.file!,
          ExportFormat.json,
        );

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                shared
                    ? 'Backup created with ${result.recordCount} sessions'
                    : 'Backup created but sharing cancelled',
              ),
              backgroundColor: shared ? Colors.green : Colors.orange,
            ),
          );
        }
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.errorMessage ?? 'Backup failed'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating backup: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _importFromJSON(BuildContext context, WidgetRef ref) async {
    // Show confirmation dialog first
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.restore, color: Colors.blue, size: 28),
            SizedBox(width: 12),
            Text('Restore from Backup?'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This will import data from a backup file.',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            Text('• Existing data will be preserved'),
            Text('• Duplicate sessions will be skipped'),
            Text('• Achievements will be merged'),
            SizedBox(height: 16),
            Text(
              'Choose a .json backup file to continue.',
              style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Choose File'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    final exportService = ref.read(exportImportServiceProvider);

    try {
      final result = await exportService.importFromJSON();

      if (!context.mounted) return;

      if (result.cancelled) {
        // User cancelled file picker
        return;
      }

      if (result.success) {
        // Invalidate providers to refresh UI
        ref.invalidate(activeFastSessionProvider);
        ref.invalidate(fastHistoryProvider);
        ref.invalidate(dashboardStatisticsProvider);
        ref.invalidate(earnedAchievementsProvider);
        ref.invalidate(totalAchievementPointsProvider);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Imported ${result.sessionsImported} sessions and ${result.achievementsImported} achievements',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.errorMessage ?? 'Import failed'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error importing: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showClearDataDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.red, size: 28),
            SizedBox(width: 12),
            Text('Clear All Data?'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This will permanently delete:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            Text('• All fast sessions (active and history)'),
            Text('• All achievements and progress'),
            Text('• All statistics and streaks'),
            SizedBox(height: 16),
            Text(
              'This action CANNOT be undone!',
              style: TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Settings and preferences will be preserved.',
              style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.of(dialogContext).pop();

              // Show loading indicator
              if (context.mounted) {
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (ctx) => const Center(
                    child: Card(
                      child: Padding(
                        padding: EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 16),
                            Text('Clearing data...'),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }

              try {
                // Clear repository data (fasts and history)
                final repository = ref.read(fastingRepositoryProvider);
                await repository.clearAllUserData();

                // Clear achievements
                final achievementService =
                    ref.read(achievementServiceProvider);
                await achievementService.clearAllAchievements();

                // Invalidate all providers to refresh UI
                ref.invalidate(activeFastSessionProvider);
                ref.invalidate(fastHistoryProvider);
                ref.invalidate(dashboardStatisticsProvider);
                ref.invalidate(earnedAchievementsProvider);
                ref.invalidate(totalAchievementPointsProvider);

                if (context.mounted) {
                  Navigator.of(context).pop(); // Close loading dialog

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('All data cleared successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  Navigator.of(context).pop(); // Close loading dialog

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error clearing data: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Delete Everything'),
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

class _NotificationDiagnosticsCard extends ConsumerStatefulWidget {
  @override
  ConsumerState<_NotificationDiagnosticsCard> createState() =>
      _NotificationDiagnosticsCardState();
}

class _NotificationDiagnosticsCardState
    extends ConsumerState<_NotificationDiagnosticsCard> {
  bool _isLoading = false;
  Map<String, dynamic>? _permissionStatus;
  String? _testResult;

  @override
  void initState() {
    super.initState();
    _loadPermissionStatus();
  }

  Future<void> _loadPermissionStatus() async {
    final notificationService = ref.read(notificationServiceProvider);
    final status = await notificationService.getPermissionStatus();
    if (mounted) {
      setState(() {
        _permissionStatus = status;
      });
    }
  }

  Future<void> _sendTestNotification() async {
    setState(() {
      _isLoading = true;
      _testResult = null;
    });

    final notificationService = ref.read(notificationServiceProvider);
    final success = await notificationService.sendTestNotification();

    if (mounted) {
      setState(() {
        _isLoading = false;
        _testResult = success
            ? 'Test notification sent! Check your notification tray.'
            : 'Failed to send test notification. Check permissions.';
      });

      // Reload permission status after test
      await _loadPermissionStatus();

      // Show snackbar
      if (mounted && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_testResult!),
            backgroundColor: success ? Colors.green : Colors.orange,
          ),
        );
      }
    }
  }

  Future<void> _requestPermissions() async {
    final notificationService = ref.read(notificationServiceProvider);

    setState(() {
      _isLoading = true;
    });

    final success = await notificationService.requestPermissions();

    if (Platform.isAndroid) {
      final exactAlarms = await notificationService.canScheduleExactAlarms();
      if (!exactAlarms) {
        await notificationService.requestExactAlarmPermission();
      }
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });

      await _loadPermissionStatus();

      if (mounted && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? 'Permissions granted!'
                  : 'Please enable notifications in system settings',
            ),
            backgroundColor: success ? Colors.green : Colors.orange,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_permissionStatus == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    final notificationsEnabled =
        _permissionStatus!['notificationsEnabled'] as bool? ?? false;
    final exactAlarmsEnabled =
        _permissionStatus!['exactAlarmsEnabled'] as bool? ?? false;
    final initialized = _permissionStatus!['initialized'] as bool? ?? false;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: Theme.of(context).colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Notification Status',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _StatusRow(
              label: 'Service Initialized',
              isEnabled: initialized,
            ),
            const SizedBox(height: 8),
            _StatusRow(
              label: 'Notifications Enabled',
              isEnabled: notificationsEnabled,
            ),
            if (Platform.isAndroid) ...[
              const SizedBox(height: 8),
              _StatusRow(
                label: 'Exact Alarms Enabled',
                isEnabled: exactAlarmsEnabled,
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isLoading ? null : _sendTestNotification,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send),
                    label: const Text('Send Test'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed:
                        (_isLoading || (notificationsEnabled && exactAlarmsEnabled))
                            ? null
                            : _requestPermissions,
                    icon: const Icon(Icons.security),
                    label: const Text('Request Permissions'),
                  ),
                ),
              ],
            ),
            if (_testResult != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      _testResult!.contains('sent')
                          ? Icons.check_circle
                          : Icons.warning,
                      size: 16,
                      color: _testResult!.contains('sent')
                          ? Colors.green
                          : Colors.orange,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _testResult!,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  final String label;
  final bool isEnabled;

  const _StatusRow({
    required this.label,
    required this.isEnabled,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          isEnabled ? Icons.check_circle : Icons.cancel,
          color: isEnabled ? Colors.green : Colors.red,
          size: 18,
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: isEnabled ? Colors.green[700] : Colors.red[700],
          ),
        ),
      ],
    );
  }
}
