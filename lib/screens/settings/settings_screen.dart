import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sancta_via_shared_ui/sancta_via_shared_ui.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // App information for the unified screen
    final appInfo = AppInfo(
      appName: 'Sancta Via Calendar',
      version: '1.0.0',
      description: 'A focused Catholic liturgical calendar app with beautiful interface and detailed feast information.',
      icon: const Icon(Icons.calendar_month, size: 48, color: Colors.deepPurple),
      onFeedback: () => _showComingSoon(context, 'Feedback'),
      onSupport: () => _showSupportDialog(context),
    );

    // Calendar-specific settings section
    final calendarSpecificSettings = _buildCalendarSpecificSettings(context, ref);

    return UnifiedSettingsScreen(
      appInfo: appInfo,
      appSpecificSettings: calendarSpecificSettings,
      customNotifications: [
        CatholicNotificationOptions.liturgicalCalendar(
          enabled: false, // TODO: Connect to liturgical notifications when implemented
          onChanged: (enabled) {
            _showComingSoon(context, 'Liturgical calendar notifications');
          },
        ),
      ],
    );
  }

  Widget _buildCalendarSpecificSettings(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        // ═══════════════════════════════════════
        // CALENDAR SETTINGS SECTION
        // ═══════════════════════════════════════
        const SettingsSectionHeader(title: 'Calendar Settings'),

        // Calendar view preferences (future feature)
        ListTile(
          leading: const Icon(Icons.calendar_view_month),
          title: const Text('Default View'),
          subtitle: const Text('Month view (more options coming soon)'),
          onTap: () => _showComingSoon(context, 'Calendar view options'),
        ),

        // Show/hide optional memorials (future feature)
        const SwitchListTile(
          secondary: Icon(Icons.visibility),
          title: Text('Show Optional Memorials'),
          subtitle: Text('Display optional memorial celebrations'),
          value: true, // Default for now
          onChanged: null, // Disabled for now
        ),

        const Divider(),
      ],
    );
  }

  void _showComingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature - Coming Soon'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSupportDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Support Sancta Via Calendar'),
        content: const Text(
          'Sancta Via Calendar is part of the Sancta Via ecosystem of Catholic applications.\n\n'
          'This app provides access to the complete liturgical calendar with detailed feast information, '
          'helping Catholics stay connected to the Church\'s liturgical rhythm throughout the year.\n\n'
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
