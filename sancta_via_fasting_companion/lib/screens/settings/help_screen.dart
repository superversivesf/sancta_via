import 'package:flutter/material.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Help & Support'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Introduction
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
                      const SizedBox(width: 8),
                      Text(
                        'Welcome to Sancta Via Fasting',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'This app helps you track and maintain your fasting practice in accordance with Catholic tradition. Below you\'ll find answers to common questions and guidance on using the app.',
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Getting Started
          _buildSection(
            context,
            'Getting Started',
            Icons.play_circle_outline,
            [
              _HelpItem(
                question: 'How do I start a fast?',
                answer:
                    'Tap the "Start Fast" button on the home screen. Choose your fast type (Intermittent, 24-hour, Liturgical, etc.), set your target duration, and tap "Start Fasting". The app will begin tracking your fast immediately.',
              ),
              _HelpItem(
                question: 'What are the different fast types?',
                answer:
                    'The app supports several types of fasts:\n\n• Intermittent Fasting (16:8, 18:6, 20:4, etc.)\n• 24-Hour Fasts\n• Liturgical Fasts (Ash Wednesday, Good Friday, etc.)\n• Multi-Day Fasts (3-day, 7-day, 40-day)\n• Open-Ended Fasts (no set target)',
              ),
              _HelpItem(
                question: 'Can I customize my fast duration?',
                answer:
                    'Yes! When starting a fast, you can adjust the target duration using the hour and minute pickers. The app will track your progress toward this goal.',
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Managing Fasts
          _buildSection(
            context,
            'Managing Your Fasts',
            Icons.settings,
            [
              _HelpItem(
                question: 'How do I complete a fast?',
                answer:
                    'Go to your active fast screen and tap the "Complete Fast" button. You\'ll be asked to confirm before the fast is marked as completed. Completed fasts are saved to your history.',
              ),
              _HelpItem(
                question: 'What if I need to break my fast early?',
                answer:
                    'Tap the "Break Fast" button on the active fast screen. You can optionally add notes about why you broke the fast. The session will be saved to your history with a "broken" status.',
              ),
              _HelpItem(
                question: 'Can I add notes to my fasts?',
                answer:
                    'Yes! You can add notes when completing or breaking a fast, or later by viewing the fast details in your history and tapping the edit icon on the notes section.',
              ),
              _HelpItem(
                question: 'How do I view past fasts?',
                answer:
                    'Tap "History" from the home screen to see all your completed and broken fasts. You can filter by date range, fast type, and status using the filter icon.',
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Features
          _buildSection(
            context,
            'App Features',
            Icons.star_outline,
            [
              _HelpItem(
                question: 'What are the statistics shown?',
                answer:
                    'The home screen displays:\n\n• Total completed fasts\n• Total hours fasted\n• Current streak (consecutive days with fasting)\n• Longest streak achieved',
              ),
              _HelpItem(
                question: 'How do notifications work?',
                answer:
                    'The app sends notifications at key times:\n\n• When you reach your target duration\n• Hourly progress updates (if enabled)\n• Halfway point notifications\n• Custom reminder notifications\n\nYou can manage notification preferences in Settings.',
              ),
              _HelpItem(
                question: 'What is the liturgical calendar integration?',
                answer:
                    'The app displays the current liturgical day on the home screen, showing the celebration, season, and liturgical color. This helps align your fasting practice with the Church calendar.',
              ),
              _HelpItem(
                question: 'Can I export my fasting data?',
                answer:
                    'Currently, all data is stored locally on your device for privacy. Data export features may be added in future updates.',
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Catholic Fasting Guidance
          _buildSection(
            context,
            'Catholic Fasting Guidance',
            Icons.church,
            [
              _HelpItem(
                question: 'What are the Church\'s fasting requirements?',
                answer:
                    'The Catholic Church requires:\n\n• Ash Wednesday and Good Friday: Fasting (1 full meal, 2 small meals not equaling a full meal) and abstinence from meat\n• All Fridays in Lent: Abstinence from meat\n• Age requirements: Fasting for ages 18-59, abstinence from age 14\n\nConsult your pastor for specific guidance.',
              ),
              _HelpItem(
                question: 'Is fasting required for health reasons?',
                answer:
                    'No. The Church exempts those for whom fasting would be harmful to health. Always consult your doctor before beginning any fasting practice, especially extended fasts.',
              ),
              _HelpItem(
                question: 'Can I drink water while fasting?',
                answer:
                    'Yes! Catholic fasting allows water and other non-nutritive beverages. The focus is on abstaining from food. Check with your spiritual director for specific guidance.',
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Troubleshooting
          _buildSection(
            context,
            'Troubleshooting',
            Icons.help_outline,
            [
              _HelpItem(
                question: 'I\'m not receiving notifications',
                answer:
                    'Check that:\n\n1. Notifications are enabled in Settings\n2. Your device allows notifications from this app\n3. Battery saver mode isn\'t blocking notifications\n4. The app has background activity permissions',
              ),
              _HelpItem(
                question: 'My stats seem incorrect',
                answer:
                    'Try refreshing the home screen by pulling down. If the issue persists, your data is safely stored locally. Contact support for assistance.',
              ),
              _HelpItem(
                question: 'The app crashed or closed unexpectedly',
                answer:
                    'Your active fast data is saved automatically. When you reopen the app, your fast should continue from where it was. If not, check your history for the most recent session.',
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Contact
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.contact_support,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Need More Help?',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'For additional support or to report issues, please visit the Sancta Via website or contact us through the app store review section.',
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'God bless your fasting journey! 🙏',
                    style: TextStyle(
                      fontStyle: FontStyle.italic,
                      color: Colors.grey[700],
                    ),
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
    BuildContext context,
    String title,
    IconData icon,
    List<_HelpItem> items,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            children: [
              Icon(icon, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
        ),
        Card(
          child: Column(
            children: items
                .map((item) => _buildExpansionTile(context, item))
                .toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildExpansionTile(BuildContext context, _HelpItem item) {
    return ExpansionTile(
      tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      title: Text(
        item.question,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
        ),
      ),
      children: [
        Text(
          item.answer,
          style: TextStyle(
            color: Colors.grey[700],
            height: 1.5,
          ),
        ),
      ],
    );
  }
}

class _HelpItem {
  final String question;
  final String answer;

  const _HelpItem({
    required this.question,
    required this.answer,
  });
}
