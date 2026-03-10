import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sancta_via_shared_ui/sancta_via_shared_ui.dart';

/// Main settings screen for the Rosary app.
/// Provides access to all app settings including notifications.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings'), centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        children: [
          // Notification settings
          _buildSection(
            context,
            title: 'Notifications',
            icon: Icons.notifications,
            subtitle: 'Configure daily prayer reminders',
            onTap: () => context.push('/settings/notifications'),
          ),

          const Divider(),

          // Theme settings
          _buildSection(
            context,
            title: 'Appearance',
            icon: Icons.palette,
            subtitle: 'Theme, colors, and display options',
            onTap: () => _showAppearanceSettings(context, ref),
          ),

          const Divider(),

          // Prayer settings
          _buildSection(
            context,
            title: 'Prayer Preferences',
            icon: Icons.self_improvement,
            subtitle: 'Font size, language, and other prayer settings',
            onTap: () => _showPrayerSettings(context, ref),
          ),

          const Divider(),

          // Statistics
          _buildSection(
            context,
            title: 'Statistics',
            icon: Icons.bar_chart,
            subtitle: 'View your prayer history and progress',
            onTap: () => context.push('/statistics'),
          ),

          const Divider(),

          // About section
          _buildSection(
            context,
            title: 'About',
            icon: Icons.info,
            subtitle: 'App information and support',
            onTap: () => _showAboutDialog(context),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required IconData icon,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: onTap,
    );
  }

  void _showAppearanceSettings(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.8,
        expand: false,
        builder: (context, scrollController) {
          return SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const SettingsSectionHeader(title: 'Theme Mode'),
                const ThemeModeSelector(),
                const SizedBox(height: 24),
                const SettingsSectionHeader(title: 'Color Intensity'),
                const ColorIntensitySelector(),
                const SizedBox(height: 24),
                const SettingsSectionHeader(title: 'Font Size'),
                const FontSizeSelector(),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showPrayerSettings(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.8,
        expand: false,
        builder: (context, scrollController) {
          return SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const SettingsSectionHeader(title: 'Language'),
                const LanguageSelector(),
                const SizedBox(height: 24),
                const SettingsSectionHeader(title: 'Accessibility'),
                const AccessibilitySettings(),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'Sancta Via Rosary',
      applicationVersion: '1.0.0',
      applicationIcon: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.favorite, color: Colors.white, size: 40),
      ),
      applicationLegalese:
          '© 2024 Sancta Via. All rights reserved.\n\n'
          'A Catholic prayer companion app to help you meditate on the Holy Rosary.',
    );
  }
}
