import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sancta_via_shared_ui/sancta_via_shared_ui.dart';
import 'package:bible_data/bible_data.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../providers/bible_app_settings_provider.dart';

/// Unified settings screen for Bible Reading App using standardized components
class BibleSettingsScreen extends ConsumerWidget {
  const BibleSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<PackageInfo>(
      future: PackageInfo.fromPlatform(),
      builder: (context, snapshot) {
        // App information for the unified screen
        final appInfo = AppInfo(
          appName: 'Bible Reading App',
          version: snapshot.hasData ? snapshot.data!.version : 'Loading...',
          description: 'A Catholic Bible reading app with liturgical calendar integration for daily spiritual reading.',
          icon: const Icon(Icons.book, size: 48, color: Colors.blue),
          onFeedback: () => _showComingSoon(context, 'Feedback'),
          onSupport: () => _showSupportDialog(context),
        );

        // Bible-specific settings section
        final bibleSpecificSettings = _buildBibleSpecificSettings(context, ref);

        return UnifiedSettingsScreen(
          appInfo: appInfo,
          appSpecificSettings: bibleSpecificSettings,
          customNotifications: [
            CatholicNotificationOptions.liturgicalCalendar(
              enabled: ref.watch(bibleNotificationsEnabledProvider),
              onChanged: (enabled) {
                ref.read(bibleAppSettingsProvider.notifier).setNotificationsEnabled(enabled);
              },
            ),
            NotificationOption(
              title: 'Daily Reading Reminders',
              subtitle: 'Notifications for daily liturgical readings',
              icon: Icons.schedule_outlined,
              enabled: ref.watch(dailyReadingNotificationsEnabledProvider),
              onChanged: (enabled) {
                ref.read(bibleAppSettingsProvider.notifier).setDailyReadingNotificationsEnabled(enabled);
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildBibleSpecificSettings(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(bibleAppSettingsProvider);
    
    return Column(
      children: [
        // Bible Settings Section
        const SettingsSectionHeader(title: 'Bible Settings'),

        // Bible Translation Selector
        ListTile(
          leading: const Icon(Icons.book),
          title: const Text('Bible Translation'),
          subtitle: Text(
            '${settings.selectedBibleTranslation.name} (${settings.selectedBibleTranslation.abbreviation})',
          ),
          trailing: DropdownButton<BibleTranslation>(
            value: settings.selectedBibleTranslation,
            onChanged: (BibleTranslation? newValue) {
              if (newValue != null) {
                ref.read(bibleAppSettingsProvider.notifier).setBibleTranslation(newValue);
              }
            },
            items: BibleTranslation.values.map((translation) {
              return DropdownMenuItem(
                value: translation,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      translation.abbreviation,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      translation.name,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),

        // Reading Experience Settings
        const SettingsSectionHeader(title: 'Reading Experience'),

        // Show Verse Numbers
        SwitchListTile(
          secondary: const Icon(Icons.format_list_numbered),
          title: const Text('Show Verse Numbers'),
          subtitle: const Text('Display verse numbers in Bible text'),
          value: settings.showVerseNumbers,
          onChanged: (bool value) {
            ref.read(bibleAppSettingsProvider.notifier).setShowVerseNumbers(value);
          },
        ),

        // Highlight Current Verse (for future audio features)
        SwitchListTile(
          secondary: const Icon(Icons.highlight),
          title: const Text('Highlight Current Verse'),
          subtitle: const Text('Highlight verse during audio playback'),
          value: settings.highlightCurrentVerse,
          onChanged: (bool value) {
            ref.read(bibleAppSettingsProvider.notifier).setHighlightCurrentVerse(value);
          },
        ),

        // Reading Plan (placeholder for future feature)
        ListTile(
          leading: const Icon(Icons.calendar_view_day),
          title: const Text('Reading Plan'),
          subtitle: Text(
            settings.activeReadingPlan ?? 'None selected',
          ),
          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
          onTap: () {
            _showComingSoon(context, 'Reading plans');
          },
        ),

        // Preview Section with current settings
        const SettingsSectionHeader(title: 'Preview'),
        
        _buildBibleTextPreview(context, ref),

        const Divider(),
      ],
    );
  }

  Widget _buildBibleTextPreview(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(bibleAppSettingsProvider);
    
    return Container(
      margin: const EdgeInsets.all(16.0),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Bible Text Preview',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          
          // Sample Bible verse with formatting
          RichText(
            text: TextSpan(
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontSize: settings.fontSize,
                height: 1.5,
              ),
              children: [
                if (settings.showVerseNumbers)
                  TextSpan(
                    text: '1 ',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                      fontSize: settings.fontSize * 0.9,
                    ),
                  ),
                const TextSpan(
                  text: 'In the beginning was the Word, and the Word was with God, and the Word was God.',
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 8),
          
          // Settings summary
          Text(
            'Font: ${settings.fontSize.round()}pt • '
            'Scale: ${settings.effectiveTextScaleFactor.toStringAsFixed(2)}x • '
            'Translation: ${settings.selectedBibleTranslation.abbreviation}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
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
        title: const Text('Support Bible Reading App'),
        content: const Text(
          'Bible Reading App is part of the Sancta Via ecosystem of Catholic applications.\n\n'
          'Your support helps us continue providing high-quality Biblical resources and tools '
          'to help the faithful grow in their understanding of Sacred Scripture.\n\n'
          'Thank you for supporting Catholic app development!',
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
