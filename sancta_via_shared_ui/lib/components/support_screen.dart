import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

/// Support screen component for Sancta Via apps
class SupportScreen extends StatelessWidget {
  final String appName;
  final String? githubUrl;
  final String? sponsorUrl;
  final String? contactEmail;

  const SupportScreen({
    super.key,
    required this.appName,
    this.githubUrl,
    this.sponsorUrl = 'https://github.com/sponsors/superversive-ca',
    this.contactEmail = 'support@superversive.net',
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Support Sancta Via'),
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: theme.colorScheme.onSurface,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.favorite,
                          color: theme.colorScheme.primary,
                          size: 24,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Support Our Mission',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Sancta Via apps are created to serve the Catholic community. '
                      'All apps are free and contain no ads. Your support helps us '
                      'continue developing and maintaining these spiritual tools.',
                      style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Financial Support
            if (sponsorUrl != null) ...[
              _buildSupportOption(
                context,
                icon: Icons.volunteer_activism,
                title: 'Financial Support',
                description: 'Support development through GitHub Sponsors',
                actionText: 'Become a Sponsor',
                onTap: () => _launchUrl(sponsorUrl!),
              ),
              const SizedBox(height: 16),
            ],

            // GitHub/Development Support
            if (githubUrl != null) ...[
              _buildSupportOption(
                context,
                icon: Icons.code,
                title: 'Contribute Code',
                description: 'Help improve the app on GitHub',
                actionText: 'View on GitHub',
                onTap: () => _launchUrl(githubUrl!),
              ),
              const SizedBox(height: 16),
            ],

            // Prayer Support
            _buildSupportOption(
              context,
              icon: Icons.church,
              title: 'Pray for Us',
              description: 'The most valuable support you can offer',
              actionText: 'Learn More',
              onTap: () => _showPrayerDialog(context),
            ),
            const SizedBox(height: 16),

            // Share the App
            _buildSupportOption(
              context,
              icon: Icons.share,
              title: 'Share the App',
              description: 'Help others discover these Catholic tools',
              actionText: 'Share',
              onTap: () => _shareApp(context),
            ),
            const SizedBox(height: 16),

            // Feedback
            if (contactEmail != null) ...[
              _buildSupportOption(
                context,
                icon: Icons.feedback,
                title: 'Send Feedback',
                description: 'Help us improve with your suggestions',
                actionText: 'Contact Us',
                onTap: () => _launchEmail(contactEmail!),
              ),
              const SizedBox(height: 16),
            ],

            // App Rating
            _buildSupportOption(
              context,
              icon: Icons.star,
              title: 'Rate the App',
              description: 'Leave a review in the app store',
              actionText: 'Rate Now',
              onTap: () => _rateApp(context),
            ),

            const SizedBox(height: 32),

            // Thank you message
            Card(
              color: theme.colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Icon(
                      Icons.favorite,
                      color: theme.colorScheme.onPrimaryContainer,
                      size: 32,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Thank You',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Your support helps keep these Catholic spiritual tools '
                      'free and available to all. May God bless you for your generosity.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSupportOption(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
    required String actionText,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);

    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primaryContainer,
          child: Icon(
            icon,
            color: theme.colorScheme.onPrimaryContainer,
          ),
        ),
        title: Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(description),
        trailing: TextButton(
          onPressed: onTap,
          child: Text(actionText),
        ),
      ),
    );
  }

  void _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _launchEmail(String email) async {
    final uri = Uri.parse('mailto:$email?subject=Feedback for $appName');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  void _shareApp(BuildContext context) {
    // This would typically use the share package
    // For now, we'll show a dialog with share suggestions
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Share the App'),
        content: const Text(
          'Help spread the word about this Catholic app! '
          'Share it with your family, friends, parish community, '
          'or on social media.',
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

  void _rateApp(BuildContext context) {
    // This would typically open the app store
    // For now, we'll show instructions
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rate the App'),
        content: const Text(
          'Please visit the App Store or Google Play Store '
          'to leave a review. Your feedback helps other Catholics '
          'discover this spiritual tool.',
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

  void _showPrayerDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pray for Sancta Via'),
        content: const Text(
          'The most valuable support you can offer is your prayers. '
          'Please pray that these tools may help Catholics grow closer '
          'to God and serve His greater glory.\n\n'
          'May the Sacred Heart of Jesus be everywhere loved!',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Amen'),
          ),
        ],
      ),
    );
  }
}

/// Quick support action button widget
class SupportActionButton extends StatelessWidget {
  final String appName;
  final String? githubUrl;
  final String? sponsorUrl;

  const SupportActionButton({
    super.key,
    required this.appName,
    this.githubUrl,
    this.sponsorUrl,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.favorite),
      tooltip: 'Support Sancta Via',
      onPressed: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => SupportScreen(
              appName: appName,
              githubUrl: githubUrl,
              sponsorUrl: sponsorUrl,
            ),
          ),
        );
      },
    );
  }
}
