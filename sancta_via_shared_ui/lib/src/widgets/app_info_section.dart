import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'settings_section_header.dart';

/// Configuration for app information display
class AppInfo {
  final String appName;
  final String version;
  final String description;
  final String copyright;
  final Widget? icon;
  final VoidCallback? onFeedback;
  final VoidCallback? onPrivacyPolicy;
  final VoidCallback? onSupport;

  const AppInfo({
    required this.appName,
    required this.version,
    required this.description,
    this.copyright = '© 2025 Sancta Via',
    this.icon,
    this.onFeedback,
    this.onPrivacyPolicy,
    this.onSupport,
  });
}

/// Standardized app information section for all Sancta Via apps
class AppInfoSection extends ConsumerWidget {
  final AppInfo appInfo;
  final bool showHeader;
  final bool showVersion;
  final bool showAbout;
  final bool showFeedback;
  final bool showPrivacyPolicy;
  final bool showSupport;

  const AppInfoSection({
    super.key,
    required this.appInfo,
    this.showHeader = true,
    this.showVersion = true,
    this.showAbout = true,
    this.showFeedback = true,
    this.showPrivacyPolicy = false,
    this.showSupport = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        if (showHeader) const SettingsSectionHeader(title: 'About'),

        // About the app
        if (showAbout)
          ListTile(
            leading: const Icon(Icons.info),
            title: Text('About ${appInfo.appName}'),
            onTap: () {
              _showAboutDialog(context);
            },
          ),

        // Version information
        if (showVersion)
          ListTile(
            leading: const Icon(Icons.code),
            title: const Text('Version'),
            subtitle: Text(appInfo.version),
          ),

        // Send feedback
        if (showFeedback)
          ListTile(
            leading: const Icon(Icons.feedback),
            title: const Text('Send Feedback'),
            subtitle: const Text('Help us improve the app'),
            onTap: appInfo.onFeedback ??
                () {
                  _showComingSoonSnackBar(context, 'Feedback feature');
                },
          ),

        // Privacy policy
        if (showPrivacyPolicy)
          ListTile(
            leading: const Icon(Icons.privacy_tip),
            title: const Text('Privacy Policy'),
            subtitle: const Text('How we protect your data'),
            onTap: appInfo.onPrivacyPolicy ??
                () {
                  _showComingSoonSnackBar(context, 'Privacy policy');
                },
          ),

        // Support
        if (showSupport)
          ListTile(
            leading: const Icon(Icons.support),
            title: const Text('Support Development'),
            subtitle: const Text('Help us continue building Catholic apps'),
            onTap: appInfo.onSupport ??
                () {
                  _showSupportDialog(context);
                },
          ),
      ],
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AboutDialog(
        applicationName: appInfo.appName,
        applicationVersion: appInfo.version,
        applicationIcon: appInfo.icon,
        applicationLegalese: appInfo.copyright,
        children: [
          const SizedBox(height: 16),
          Text(appInfo.description),
          const SizedBox(height: 16),
          const Text(
            'Part of the Sancta Via ecosystem of Catholic applications for the faithful.',
          ),
        ],
      ),
    );
  }

  void _showSupportDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Support Development'),
        content: const Text(
          'Sancta Via creates high-quality Catholic applications to help the faithful in their spiritual journey.\n\n'
          'Your support helps us continue developing these tools for the Catholic community worldwide.\n\n'
          'Thank you for being part of our mission!',
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

  void _showComingSoonSnackBar(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature - Coming Soon'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

/// Compact app info card
class AppInfoCard extends ConsumerWidget {
  final AppInfo appInfo;

  const AppInfoCard({
    super.key,
    required this.appInfo,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (appInfo.icon != null) ...[
                  appInfo.icon!,
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        appInfo.appName,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        'Version ${appInfo.version}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              appInfo.description,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Text(
              appInfo.copyright,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.color
                        ?.withOpacity(0.6),
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

/// App logo with name and version
class AppHeader extends ConsumerWidget {
  final AppInfo appInfo;
  final double? iconSize;

  const AppHeader({
    super.key,
    required this.appInfo,
    this.iconSize,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          if (appInfo.icon != null)
            SizedBox(
              width: iconSize ?? 64,
              height: iconSize ?? 64,
              child: appInfo.icon!,
            ),
          const SizedBox(height: 16),
          Text(
            appInfo.appName,
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            'Version ${appInfo.version}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.color
                      ?.withOpacity(0.6),
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            appInfo.copyright,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.color
                      ?.withOpacity(0.6),
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
