import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sancta_via_shared_ui/sancta_via_shared_ui.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../providers/novena_app_settings_provider.dart';
import '../widgets/novena_settings_section.dart';
import '../widgets/security_settings_section.dart';
import '../services/settings_error_handler.dart';

/// Clean, focused settings screen using modular components
class NovenaSettingsScreen extends ConsumerWidget {
  const NovenaSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<PackageInfo>(
      future: PackageInfo.fromPlatform(),
      builder: (context, snapshot) {
        // App information for the unified screen
        final appInfo = AppInfo(
          appName: 'Novena Companion',
          version: snapshot.hasData ? snapshot.data!.version : 'Loading...',
          description:
              'Catholic novena companion app with traditional nine-day prayer devotions and liturgical integration for spiritual growth.',
          icon: const Icon(
            Icons.auto_stories,
            size: 48,
            color: Colors.deepPurple,
          ),
          onFeedback: () => _showComingSoon(context, 'Feedback'),
          onSupport: () => _showSupportDialog(context),
        );

        // Build app-specific settings sections
        final appSpecificSettings = Column(
          children: [
            // Novena-specific settings
            const NovenaSettingsSection(),
            const SizedBox(height: 16),
          ],
        );

        return UnifiedSettingsScreen(
          appInfo: appInfo,
          appSpecificSettings: appSpecificSettings,
          customNotifications: [
            CatholicNotificationOptions.novenas(
              enabled: ref.watch(novenaNotificationsEnabledProvider),
              onChanged: (enabled) {
                _toggleNovenaNotifications(context, ref, enabled);
              },
            ),
            CatholicNotificationOptions.liturgicalCalendar(
              enabled: false, // TODO: Connect to liturgical notifications
              onChanged: (enabled) {
                _showComingSoon(context, 'Liturgical calendar notifications');
              },
            ),
          ],
        );
      },
    );
  }

  /// Build current theme color display
  Widget _buildCurrentThemeColor(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.info),
      title: const Text('Current Theme Color'),
      trailing: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Theme.of(context).colorScheme.outline),
        ),
      ),
    );
  }

  /// Toggle novena notifications with error handling
  Future<void> _toggleNovenaNotifications(
    BuildContext context,
    WidgetRef ref,
    bool enabled,
  ) async {
    try {
      await ref
          .read(novenaAppSettingsProvider.notifier)
          .updateNovenaNotificationsEnabled(enabled);
      if (context.mounted) {
        SettingsErrorHandler.showSuccess(
          context,
          enabled
              ? 'Novena notifications enabled'
              : 'Novena notifications disabled',
        );
      }
    } catch (e) {
      if (context.mounted) {
        SettingsErrorHandler.handleError(
          context,
          e as Exception,
          operation: 'toggling novena notifications',
        );
      }
    }
  }

  /// Show coming soon message
  void _showComingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature - Coming Soon'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Show support dialog
  void _showSupportDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Support Novena Companion'),
        content: const Text(
          'Novena Companion is part of the Sancta Via ecosystem of Catholic applications.\n\n'
          'This app provides access to traditional nine-day prayer devotions, '
          'with liturgical calendar integration for seasonal novena recommendations.\n\n'
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
}
