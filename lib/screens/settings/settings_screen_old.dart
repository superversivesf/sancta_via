import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sancta_via_shared_ui/sancta_via_shared_ui.dart';
import '../../providers/app_settings_provider.dart';
import '../../providers/text_scaling_provider.dart';
import '../../widgets/font_size_slider.dart' as local_widgets;
import '../../config/constants.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textScaling = ref.watch(textScaleProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Settings',
          style: textScaling.scaledTitleLarge(context),
        ),
      ),
      body: ListView(
        children: [
          // Appearance Section
          const SettingsSectionHeader(title: 'Appearance'),

          // Theme mode selection
          const ThemeModeSelector(),

          // Color intensity setting
          const ColorIntensitySelector(),

          // Preview liturgical colors
          const LiturgicalColorPreview(),

          const Divider(),

          // Font Size Section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.text_fields),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        'Font Size',
                        style: textScaling.scaledTitleMedium(context).copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const local_widgets.FontSizeSlider(),
              ],
            ),
          ),

          const Divider(),

          // Examination Settings Section
          const SettingsSectionHeader(title: 'Examination Settings'),

          Consumer(
            builder: (context, ref, child) {
              final textScaling = ref.watch(textScaleProvider);
              final settings = ref.watch(appSettingsProvider);
              return ListTile(
                leading: const Icon(Icons.language),
                title: Text(
                  'Default Language',
                  style: textScaling.scaledTitleMedium(context),
                ),
                subtitle: Text(
                  'Choose examination language preference',
                  style: textScaling.scaledBodyMedium(context),
                ),
                trailing: DropdownButton<String>(
                  value: settings.defaultLanguage,
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      ref.read(appSettingsNotifierProvider).updateDefaultLanguage(newValue);
                    }
                  },
                  items: ['English', 'Latin', 'Spanish'].map((String language) {
                    return DropdownMenuItem(
                      value: language,
                      child: Text(language),
                    );
                  }).toList(),
                ),
              );
            },
          ),

          Consumer(
            builder: (context, ref, child) {
              final textScaling = ref.watch(textScaleProvider);
              final settings = ref.watch(appSettingsProvider);
              return SwitchListTile(
                secondary: const Icon(Icons.notifications),
                title: Text(
                  'Reminder Notifications',
                  style: textScaling.scaledTitleMedium(context),
                ),
                subtitle: Text(
                  'Get reminders for regular examination of conscience',
                  style: textScaling.scaledBodyMedium(context),
                ),
                value: settings.notificationsEnabled,
                onChanged: (bool value) {
                  ref.read(appSettingsNotifierProvider).updateNotifications(value);
                },
              );
            },
          ),

          const Divider(),

          // Data & Storage Section
          const SettingsSectionHeader(title: 'Data & Privacy'),

          Consumer(
            builder: (context, ref, child) {
              final textScaling = ref.watch(textScaleProvider);
              return ListTile(
                leading: const Icon(Icons.sync),
                title: Text(
                  'Sync Settings',
                  style: textScaling.scaledTitleMedium(context),
                ),
                subtitle: Text(
                  'Backup and sync your preferences',
                  style: textScaling.scaledBodyMedium(context),
                ),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(
                      'Sync settings - Coming Soon',
                      style: textScaling.scaledBodyMedium(context),
                    )),
                  );
                },
              );
            },
          ),

          Consumer(
            builder: (context, ref, child) {
              final textScaling = ref.watch(textScaleProvider);
              return ListTile(
                leading: const Icon(Icons.delete),
                title: Text(
                  'Clear Data',
                  style: textScaling.scaledTitleMedium(context),
                ),
                subtitle: Text(
                  'Remove all stored examination data',
                  style: textScaling.scaledBodyMedium(context),
                ),
                onTap: () {
                  _showClearDataDialog(context, ref);
                },
              );
            },
          ),

          const Divider(),

          // About Section
          const SettingsSectionHeader(title: 'About'),

          Consumer(
            builder: (context, ref, child) {
              final textScaling = ref.watch(textScaleProvider);
              return ListTile(
                leading: const Icon(Icons.info),
                title: Text(
                  'About ${AppConstants.appName}',
                  style: textScaling.scaledTitleMedium(context),
                ),
                onTap: () {
                  _showAboutDialog(context);
                },
              );
            },
          ),

          Consumer(
            builder: (context, ref, child) {
              final textScaling = ref.watch(textScaleProvider);
              return ListTile(
                leading: const Icon(Icons.code),
                title: Text(
                  'Version',
                  style: textScaling.scaledTitleMedium(context),
                ),
                subtitle: Text(
                  AppConstants.appVersion,
                  style: textScaling.scaledBodyMedium(context),
                ),
              );
            },
          ),

          Consumer(
            builder: (context, ref, child) {
              final textScaling = ref.watch(textScaleProvider);
              return ListTile(
                leading: const Icon(Icons.feedback),
                title: Text(
                  'Send Feedback',
                  style: textScaling.scaledTitleMedium(context),
                ),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(
                      'Feedback - Coming Soon',
                      style: textScaling.scaledBodyMedium(context),
                    )),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Consumer(
        builder: (context, ref, child) {
          final textScaling = ref.watch(textScaleProvider);
          return AlertDialog(
            title: Text(
              'About ${AppConstants.appName}',
              style: textScaling.scaledTitleLarge(context),
            ),
            content: Text(
              '${AppConstants.appName} is part of the Sancta Via ecosystem of Catholic apps.\n\n'
              'This app provides guided examinations of conscience to help faithful Catholics '
              'prepare for the Sacrament of Confession with proper reflection and prayer.\n\n'
              'Features include liturgical calendar integration for seasonal preparation, '
              'multiple examination formats for different audiences, and secure storage of '
              'your spiritual progress.\n\n'
              'Your support helps us continue developing high-quality Catholic applications for the faithful.',
              style: textScaling.scaledBodyMedium(context),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  'Close',
                  style: textScaling.scaledLabelLarge(context),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showClearDataDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => Consumer(
        builder: (context, ref, child) {
          final textScaling = ref.watch(textScaleProvider);
          return AlertDialog(
            title: Text(
              'Clear All Data',
              style: textScaling.scaledTitleLarge(context),
            ),
            content: Text(
              'This will permanently delete all your examination history and progress. '
              'Your app preferences will be preserved.\n\n'
              'This action cannot be undone. Do you want to continue?',
              style: textScaling.scaledBodyMedium(context),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  'Cancel',
                  style: textScaling.scaledLabelLarge(context),
                ),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.of(context).pop();
                  // TODO: Implement data clearing
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(
                      'Data clearing - Coming Soon',
                      style: textScaling.scaledBodyMedium(context),
                    )),
                  );
                },
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                ),
                child: Text(
                  'Clear Data',
                  style: textScaling.scaledLabelLarge(context),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
