import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

/// Privacy Policy screen component for Sancta Via apps
class PrivacyPolicyScreen extends StatelessWidget {
  final String appName;
  final String? supportEmail;
  final DateTime? lastUpdated;

  const PrivacyPolicyScreen({
    super.key,
    required this.appName,
    this.supportEmail = 'support@superversive.net',
    this.lastUpdated,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lastUpdatedDate = lastUpdated ?? DateTime(2025, 7, 9);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy Policy'),
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: theme.colorScheme.onSurface,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Privacy Policy for $appName',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Last updated: ${_formatDate(lastUpdatedDate)}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 24),
            _buildSection(
              context,
              'Our Commitment to Your Privacy',
              'At Sancta Via, we are committed to protecting your privacy. This Privacy Policy explains how $appName handles your information.',
            ),
            _buildSection(
              context,
              'Data Collection and Storage',
              'All data in $appName is stored locally on your device. We do not collect, transmit, or share any personal information or usage data with third parties. Your prayers, notes, settings, and all other app data remain completely private and under your control.',
            ),
            _buildSection(
              context,
              'Local Data Storage',
              'The app stores the following data locally on your device:\n'
                  '• App preferences and settings\n'
                  '• Your personal notes and reflections\n'
                  '• Reading history and bookmarks\n'
                  '• Customization choices\n\n'
                  'This data is never transmitted outside of your device.',
            ),
            _buildSection(
              context,
              'No Third-Party Analytics',
              'We do not use any third-party analytics, tracking, or advertising services. Your usage of the app is completely private.',
            ),
            _buildSection(
              context,
              'No Account Required',
              'The app does not require you to create an account or provide any personal information to use its features.',
            ),
            _buildSection(
              context,
              'Data Security',
              'Since all data is stored locally on your device, the security of your data depends on your device\'s security settings. We recommend using device lock screens and keeping your device updated.',
            ),
            _buildSection(
              context,
              'Changes to This Policy',
              'We may update this Privacy Policy from time to time. Any changes will be reflected in the app and indicated by the "Last updated" date above.',
            ),
            if (supportEmail != null) ...[
              _buildSection(
                context,
                'Contact Us',
                'If you have any questions about this Privacy Policy, please contact us at:',
              ),
              GestureDetector(
                onTap: () => _launchEmail(supportEmail!),
                child: Text(
                  supportEmail!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(BuildContext context, String title, String content) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: theme.textTheme.bodyMedium?.copyWith(
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year}';
  }

  void _launchEmail(String email) async {
    final uri = Uri.parse('mailto:$email');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }
}

/// Simple privacy policy dialog for quick access
class PrivacyPolicyDialog extends StatelessWidget {
  final String appName;

  const PrivacyPolicyDialog({
    super.key,
    required this.appName,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Privacy Policy'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Text(
            'All data in $appName is stored locally on your device. '
            'We do not collect, transmit, or share any personal information '
            'or usage data with third parties. Your data remains completely '
            'private and under your control.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => PrivacyPolicyScreen(appName: appName),
              ),
            );
          },
          child: const Text('View Full Policy'),
        ),
      ],
    );
  }
}
