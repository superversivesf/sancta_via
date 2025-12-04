import 'package:flutter/material.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy Policy'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Sancta Via Fasting Companion',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Privacy Policy',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
          const SizedBox(height: 4),
          Text(
            'Last Updated: December 2024',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[500],
                ),
          ),
          const SizedBox(height: 24),

          _buildSection(
            context,
            title: 'Our Commitment to Your Privacy',
            content:
                'At Sancta Via, we are committed to protecting your privacy and ensuring your personal spiritual journey remains private. This app is designed with privacy-first principles, storing all data locally on your device.',
          ),

          _buildSection(
            context,
            title: 'Information We Collect',
            content:
                'The Fasting Companion app stores the following information locally on your device:\n\n'
                '• Fast session history (start time, end time, duration, type, status)\n'
                '• Personal notes you add to fasting sessions\n'
                '• App settings and preferences (theme, notifications, timer settings)\n'
                '• Statistics derived from your fasting history\n\n'
                'This data never leaves your device unless you explicitly choose to export it.',
          ),

          _buildSection(
            context,
            title: 'Local Storage Only',
            content:
                'All your fasting data is stored exclusively in a local SQLite database on your device. We do not:\n\n'
                '• Transmit your data to any servers\n'
                '• Create user accounts\n'
                '• Track your usage patterns\n'
                '• Share your information with third parties\n'
                '• Use analytics or tracking services',
          ),

          _buildSection(
            context,
            title: 'Permissions',
            content:
                'The app requires the following permissions:\n\n'
                '• Notifications: To send you optional reminders and encouragements during your fast\n'
                '• Vibration: To provide haptic feedback for milestone notifications\n\n'
                'All permissions are optional, and the app functions without them (though with reduced features).',
          ),

          _buildSection(
            context,
            title: 'Data Security',
            content:
                'Your data is protected by your device\'s built-in security features. We recommend:\n\n'
                '• Using device-level encryption (enabled by default on modern devices)\n'
                '• Setting a strong device passcode\n'
                '• Keeping your device operating system updated',
          ),

          _buildSection(
            context,
            title: 'Data Deletion',
            content:
                'You have complete control over your data:\n\n'
                '• Delete individual fast sessions from the History screen\n'
                '• Uninstalling the app removes all local data from your device\n'
                '• No data remains on any servers since none is ever uploaded',
          ),

          _buildSection(
            context,
            title: 'Third-Party Services',
            content:
                'This app does not integrate with any third-party analytics, advertising, or tracking services. The liturgical calendar data is embedded in the app and requires no external connections.',
          ),

          _buildSection(
            context,
            title: 'Children\'s Privacy',
            content:
                'This app does not knowingly collect any information from users of any age. All data is stored locally, and we have no access to any user information.',
          ),

          _buildSection(
            context,
            title: 'Changes to This Policy',
            content:
                'We may update this privacy policy from time to time. Changes will be reflected in the app with an updated "Last Updated" date. Continued use of the app after changes constitutes acceptance of the updated policy.',
          ),

          _buildSection(
            context,
            title: 'Catholic Content',
            content:
                'The app includes Catholic prayers, Scripture verses, and encouragements from the saints. This content is provided for spiritual edification and is drawn from the Church\'s rich tradition.',
          ),

          _buildSection(
            context,
            title: 'Contact Us',
            content:
                'If you have questions about this privacy policy or your data, you can contact us through the app store page or our website at sanctavia.app (if available).',
          ),

          const SizedBox(height: 16),

          Card(
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Icon(
                    Icons.security,
                    size: 48,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Your Privacy is Sacred',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your spiritual journey is between you and God. We built this app to support your fasting practice while respecting your privacy completely.',
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required String content,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          content,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                height: 1.5,
              ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}
