import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sancta_via_shared_ui/sancta_via_shared_ui.dart';
import '../../providers/prayer_providers.dart';
import '../../providers/text_scaling_provider.dart';
import '../../widgets/font_size_selector.dart';
import '../../widgets/enhanced_prayer_text.dart';

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
          // Appearance Section - with text scaling applied
          MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaleFactor: textScaling.scaleFactor,
            ),
            child: const SettingsSectionHeader(title: 'Appearance'),
          ),

          // Theme mode selection - with text scaling applied
          MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaleFactor: textScaling.scaleFactor,
            ),
            child: const ThemeModeSelector(),
          ),

          // Color intensity setting - with text scaling applied
          MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaleFactor: textScaling.scaleFactor,
            ),
            child: const ColorIntensitySelector(),
          ),

          // Preview liturgical colors - with text scaling applied
          MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaleFactor: textScaling.scaleFactor,
            ),
            child: const LiturgicalColorPreview(),
          ),

          const Divider(),

          // Prayer Settings Section - with text scaling applied
          MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaleFactor: textScaling.scaleFactor,
            ),
            child: const SettingsSectionHeader(title: 'Prayer Settings'),
          ),

          Consumer(
            builder: (context, ref, child) {
              final textScaling = ref.watch(textScaleProvider);
              return ListTile(
                leading: const Icon(Icons.notifications),
                title: Text(
                  'Prayer Reminders',
                  style: textScaling.scaledTitleMedium(context),
                ),
                subtitle: Text(
                  'Set daily prayer notifications',
                  style: textScaling.scaledBodyMedium(context),
                ),
                trailing: Switch(
                  value: false, // TODO: Connect to settings provider
                  onChanged: (value) {
                    // TODO: Implement reminder settings
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(
                        'Prayer reminders - Coming Soon',
                        style: textScaling.scaledBodyMedium(context),
                      )),
                    );
                  },
                ),
              );
            },
          ),

          Consumer(
            builder: (context, ref, child) {
              final defaultLanguage = ref.watch(defaultLanguageProvider);
              return ListTile(
                leading: const Icon(Icons.language),
                title: const Text('Default Language'),
                subtitle: const Text('Choose prayer language preference'),
                trailing: DropdownButton<String>(
                  value: defaultLanguage,
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      ref.read(prayerPreferencesProvider.notifier).updateDefaultLanguage(newValue);
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
                const FontSizeSlider(),
              ],
            ),
          ),

          // Reading Experience Section
          Consumer(
            builder: (context, ref, child) {
              final textScaling = ref.watch(textScaleProvider);
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  'Reading Experience',
                  style: textScaling.scaledTitleMedium(context).copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              );
            },
          ),

          Consumer(
            builder: (context, ref, child) {
              final textScaling = ref.watch(textScaleProvider);
              final preferences = ref.watch(prayerPreferencesProvider);
              
              return ListTile(
                leading: const Icon(Icons.auto_stories),
                title: Text(
                  'Reading Mode',
                  style: textScaling.scaledTitleMedium(context),
                ),
                subtitle: Text(
                  _getReadingModeDescription(preferences.readingMode),
                  style: textScaling.scaledBodyMedium(context),
                ),
                trailing: DropdownButton<PrayerReadingMode>(
                  value: preferences.readingMode,
                  onChanged: (PrayerReadingMode? newValue) {
                    if (newValue != null) {
                      ref.read(prayerPreferencesProvider.notifier).updateReadingMode(newValue);
                    }
                  },
                  items: PrayerReadingMode.values.map((PrayerReadingMode mode) {
                    return DropdownMenuItem(
                      value: mode,
                      child: Text(_getReadingModeLabel(mode)),
                    );
                  }).toList(),
                ),
              );
            },
          ),

          Consumer(
            builder: (context, ref, child) {
              final textScaling = ref.watch(textScaleProvider);
              final preferences = ref.watch(prayerPreferencesProvider);
              
              return SwitchListTile(
                secondary: const Icon(Icons.touch_app),
                title: Text(
                  'Verse Highlighting',
                  style: textScaling.scaledTitleMedium(context),
                ),
                subtitle: Text(
                  'Tap verses to follow along while praying',
                  style: textScaling.scaledBodyMedium(context),
                ),
                value: preferences.verseHighlighting,
                onChanged: (bool value) {
                  ref.read(prayerPreferencesProvider.notifier).updateVerseHighlighting(value);
                },
              );
            },
          ),


          // Data & Storage Section - with text scaling applied
          MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaleFactor: textScaling.scaleFactor,
            ),
            child: const SettingsSectionHeader(title: 'Data & Storage'),
          ),

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
                  // TODO: Navigate to sync settings
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
                leading: const Icon(Icons.storage),
                title: Text(
                  'Clear Cache',
                  style: textScaling.scaledTitleMedium(context),
                ),
                subtitle: Text(
                  'Free up storage space',
                  style: textScaling.scaledBodyMedium(context),
                ),
                onTap: () {
                  _showClearCacheDialog(context);
                },
              );
            },
          ),

          const Divider(),

          // About Section - with text scaling applied
          MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaleFactor: textScaling.scaleFactor,
            ),
            child: const SettingsSectionHeader(title: 'About'),
          ),

          Consumer(
            builder: (context, ref, child) {
              final textScaling = ref.watch(textScaleProvider);
              return ListTile(
                leading: const Icon(Icons.info),
                title: Text(
                  'About Prayer Companion',
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
                  '1.0.0',
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
              'About Prayer Companion',
              style: textScaling.scaledTitleLarge(context),
            ),
            content: Text(
              'Prayer Companion is part of the Sancta Via ecosystem of Catholic apps.\n\n'
              'This app provides access to traditional and contemporary Catholic prayers, '
              'with liturgical calendar integration for seasonal prayer recommendations.\n\n'
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

  void _showClearCacheDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Consumer(
        builder: (context, ref, child) {
          final textScaling = ref.watch(textScaleProvider);
          return AlertDialog(
            title: Text(
              'Clear Cache',
              style: textScaling.scaledTitleLarge(context),
            ),
            content: Text(
              'This will clear cached prayer data and may require re-downloading content. '
              'Your preferences and favorites will be preserved.\n\n'
              'Do you want to continue?',
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
                onPressed: () {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(
                      'Cache cleared successfully',
                      style: textScaling.scaledBodyMedium(context),
                    )),
                  );
                },
                child: Text(
                  'Clear',
                  style: textScaling.scaledLabelLarge(context),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _getReadingModeLabel(PrayerReadingMode mode) {
    switch (mode) {
      case PrayerReadingMode.normal:
        return 'Normal';
      case PrayerReadingMode.contemplative:
        return 'Contemplative';
      case PrayerReadingMode.immersive:
        return 'Immersive';
    }
  }

  String _getReadingModeDescription(PrayerReadingMode mode) {
    switch (mode) {
      case PrayerReadingMode.normal:
        return 'Standard reading layout with enhanced typography';
      case PrayerReadingMode.contemplative:
        return 'Centered text with generous spacing for meditation';
      case PrayerReadingMode.immersive:
        return 'Minimal UI for distraction-free prayer focus';
    }
  }
}