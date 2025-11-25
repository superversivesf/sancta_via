import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../config/constants.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy Policy'),
        actions: [
          IconButton(
            icon: const Icon(Icons.open_in_browser),
            onPressed: () => _openOnlinePolicy(context),
            tooltip: 'View Online Version',
          ),
          IconButton(
            icon: const Icon(Icons.copy),
            onPressed: () => _copyPrivacyPolicy(context),
            tooltip: 'Copy to Clipboard',
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'share') {
                _sharePrivacyPolicy(context);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'share',
                child: Row(
                  children: [
                    Icon(Icons.share),
                    SizedBox(width: 8),
                    Text('Share Policy'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min, // Prevent overflow
            children: [
              _buildSection(
                context,
                'Privacy Policy for ${AppConstants.appName}',
                'Last Updated: December 2024',
                isHeader: true,
              ),

              _buildSection(
                context,
                'Our Sacred Commitment to Your Privacy',
                'At Sancta Via, we recognize that your spiritual journey is deeply personal and sacred. This privacy policy explains how we protect your privacy and ensure that your religious practices, examinations of conscience, and personal reflections remain completely private and secure.',
              ),

              // Online version notice
              Card(
                color: Theme.of(context).colorScheme.primaryContainer,
                margin: const EdgeInsets.only(bottom: 16.0),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'This privacy policy is also available online at sancta-via.app/privacy for your reference.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                      TextButton(
                        onPressed: () => _openOnlinePolicy(context),
                        child: const Text('View Online'),
                      ),
                    ],
                  ),
                ),
              ),

              // Quick summary card
              Card(
                color: Theme.of(context).colorScheme.secondaryContainer,
                margin: const EdgeInsets.only(bottom: 24.0),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.shield_outlined,
                            color: Theme.of(context).colorScheme.secondary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Privacy Summary',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.secondary,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Your spiritual data stays on your device. We don\'t collect, transmit, or store any personal information. Your examinations of conscience, prayers, and notes remain completely private.',
                        style: Theme.of(context).textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),

              _buildSection(
                context,
                'Our Privacy Promise',
                '''• Your data never leaves your device
• No internet connection required for core functionality
• No user accounts or registration needed
• No tracking or analytics
• Complete local control of your spiritual data''',
              ),

              _buildSection(
                context,
                'Data We Handle',
                '''• Examination of Conscience Responses: Your answers to examination questions
• Personal Notes: Any notes you add during examinations
• Prayer Preferences: Your favorite prayers and settings
• App Settings: Theme preferences, font size, and liturgical color settings
• Security Data: PIN codes (if enabled) stored securely with encryption''',
              ),

              _buildSection(
                context,
                'How We Protect Your Data',
                '''• LOCAL STORAGE ONLY: All your data remains on your device and never leaves it
• NO INTERNET TRANSMISSION: We do not send any personal data to servers
• NO TRACKING: We do not track your usage or behavior
• NO ANALYTICS: We do not collect analytics data about your prayers or examinations
• SECURE ENCRYPTION: Sensitive data like examination responses are encrypted using industry-standard security
• NO THIRD-PARTY ACCESS: We do not share data with any third parties''',
              ),

              _buildSection(
                context,
                'What We Don\'t Collect',
                '''• We do not collect your name, email, or contact information
• We do not access your location
• We do not access your contacts or other apps
• We do not collect browsing history
• We do not use cookies or tracking technologies''',
              ),

              _buildSection(
                context,
                'Your Complete Control Over Your Data',
                '''• Delete individual examination sessions at any time
• Clear all examination history with one action
• Reset all app settings to defaults
• Disable PIN security whenever you choose
• Export your prayer favorites (coming soon)
• Uninstalling the app permanently deletes all data''',
              ),

              _buildSection(
                context,
                'Data Retention and Deletion',
                '''Since all data is stored locally on your device:
• Data persists only as long as the app is installed
• Completed examination sessions are kept until you delete them
• App settings remain until manually reset
• Clearing app data through device settings removes everything
• No data recovery is possible once deleted (no cloud backup)''',
              ),

              _buildSection(
                context,
                'App Permissions',
                '''The app requests minimal permissions:
• Secure Storage: To protect your examination responses and PIN codes
• Biometric Authentication: Only if you choose to enable PIN protection
• No network permissions for data transmission''',
              ),

              _buildSection(
                context,
                'Religious Content',
                '''• Prayer texts and examination content are included in the app and do not require internet access
• Liturgical calendar calculations are performed locally
• All religious content is sourced from traditional Catholic teachings and properly attributed''',
              ),

              _buildSection(
                context,
                'Age Requirements',
                'This app is suitable for users of all ages. However, children under 13 should use this app with parental guidance, especially when setting up security features like PIN codes.',
              ),

              _buildSection(
                context,
                'International Users',
                'This app is designed to comply with privacy laws including GDPR (European Union) and CCPA (California). Since all data remains on your device, there are no international data transfers to worry about.',
              ),

              _buildSection(
                context,
                'Changes to This Policy',
                'If we make changes to this privacy policy, we will update the app and notify users through app updates. We will always maintain our commitment to local-only data storage. Continued use of the app constitutes acceptance of any changes.',
              ),

              _buildSection(
                context,
                'Contact Information',
                '''If you have questions about this privacy policy or our data practices, please contact us:

Privacy Questions: privacy@sancta-via.app
Technical Support: support@sancta-via.app
General Contact: contact@sancta-via.app

We are committed to addressing any privacy concerns you may have and will respond within 48 hours.''',
              ),

              const SizedBox(height: 32),

              // Wrap the card in Flexible to prevent overflow
              Card(
                color: Theme.of(context).colorScheme.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisSize: MainAxisSize
                        .min, // Add this to prevent taking excess space
                    children: [
                      Icon(
                        Icons.security,
                        size: 48,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Your Privacy is Sacred',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Your spiritual journey is between you and God. We ensure your examinations of conscience, prayers, and personal reflections remain completely private and secure on your device.',
                        style: Theme.of(context).textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),

              // Add extra padding at the bottom to prevent content cutoff
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  void _copyPrivacyPolicy(BuildContext context) {
    const policyText = '''
Privacy Policy for Sancta Via

Last Updated: December 2024

Our Sacred Commitment to Your Privacy:
At Sancta Via, we recognize that your spiritual journey is deeply personal and sacred. This privacy policy explains how we protect your privacy and ensure that your religious practices, examinations of conscience, and personal reflections remain completely private and secure.

Our Privacy Promise:
• Your data never leaves your device
• No internet connection required for core functionality  
• No user accounts or registration needed
• No tracking or analytics
• Complete local control of your spiritual data

For full details, please view the complete privacy policy in the app.
    ''';

    Clipboard.setData(const ClipboardData(text: policyText));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Privacy policy summary copied to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _openOnlinePolicy(BuildContext context) async {
    const url =
        'https://yourusername.github.io/sancta-via-privacy/'; // Update this with your actual URL
    try {
      final uri = Uri.parse(url);
      // Using url_launcher which is already in pubspec.yaml
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && context.mounted) {
        _showUrlError(context, url);
      }
    } catch (e) {
      if (context.mounted) {
        _showUrlError(context, url);
      }
    }
  }

  void _showUrlError(BuildContext context, String url) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Could not open $url'),
        action: SnackBarAction(
          label: 'Copy URL',
          onPressed: () {
            Clipboard.setData(ClipboardData(text: url));
          },
        ),
      ),
    );
  }

  void _sharePrivacyPolicy(BuildContext context) {
    // Since we can't use share_plus without adding it as a dependency,
    // let's show a dialog with shareable text
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Share Privacy Policy'),
        content: const Text(
          'Our app keeps all your spiritual data completely private and local to your device. '
          'No data is ever transmitted or shared. Download Sancta Via for a truly private Catholic spiritual experience.\n\n'
          'Full privacy policy: https://yourusername.github.io/sancta-via-privacy/',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _copyPrivacyPolicy(context);
            },
            child: const Text('Copy Text'),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(
    BuildContext context,
    String title,
    String content, {
    bool isHeader = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: isHeader
                ? Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  )
                : Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
          ),
          const SizedBox(height: 12),
          // Better formatting for bullet points
          if (content.contains('•'))
            ...content
                .split('\n')
                .map((line) => line.trim())
                .where((line) => line.isNotEmpty)
                .map((line) {
                  if (line.startsWith('•')) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8.0, left: 8.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '• ',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              line.substring(2),
                              style: Theme.of(
                                context,
                              ).textTheme.bodyMedium?.copyWith(height: 1.4),
                            ),
                          ),
                        ],
                      ),
                    );
                  } else {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Text(
                        line,
                        style: Theme.of(
                          context,
                        ).textTheme.bodyMedium?.copyWith(height: 1.4),
                      ),
                    );
                  }
                })
          else
            Text(
              content,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(height: 1.5),
            ),
        ],
      ),
    );
  }
}
