import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sancta_via_shared_ui/sancta_via_shared_ui.dart';

import '../../providers/confession_app_settings_provider.dart';
import '../../providers/text_scaling_provider.dart';
import '../../widgets/font_size_slider.dart' as local_widgets;
import '../../config/constants.dart';

/// Unified settings screen for Confession Companion using standardized components
class ConfessionSettingsScreen extends ConsumerWidget {
  const ConfessionSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // App information for the unified screen
    final appInfo = AppInfo(
      appName: AppConstants.appName,
      version: AppConstants.appVersion,
      description: 'A Catholic app providing guided examinations of conscience to help faithful Catholics '
          'prepare for the Sacrament of Confession with proper reflection and prayer.',
      icon: const Icon(Icons.self_improvement, size: 48, color: Colors.purple),
      onFeedback: () => _showComingSoon(context, 'Feedback'),
      onSupport: () => _showSupportDialog(context),
    );

    // Confession-specific settings section
    final confessionSpecificSettings = _buildConfessionSpecificSettings(context, ref);

    return UnifiedSettingsScreen(
      appInfo: appInfo,
      appSpecificSettings: confessionSpecificSettings,
      customNotifications: [
        CatholicNotificationOptions.examinations(
          enabled: ref.watch(confessionNotificationsEnabledProvider),
          onChanged: (enabled) {
            ref.read(confessionAppSettingsProvider.notifier).setNotificationsEnabled(enabled);
          },
        ),
        CatholicNotificationOptions.liturgicalCalendar(
          enabled: false, // TODO: Implement liturgical calendar notifications
          onChanged: (enabled) {
            _showComingSoon(context, 'Liturgical calendar notifications');
          },
        ),
      ],
    );
  }

  Widget _buildConfessionSpecificSettings(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(confessionAppSettingsProvider);
    final textScaling = ref.watch(textScaleProvider);
    
    return Column(
      children: [
        // ═══════════════════════════════════════
        // EXAMINATION SETTINGS SECTION
        // ═══════════════════════════════════════
        const SettingsSectionHeader(title: 'Examination Settings'),

        // Default Language (reusing from unified system but with examination context)
        Consumer(
          builder: (context, ref, child) {
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
              trailing: DropdownButton<AppLanguage>(
                value: settings.defaultLanguage,
                onChanged: (AppLanguage? newValue) {
                  if (newValue != null) {
                    ref.read(confessionAppSettingsProvider.notifier).setDefaultLanguage(newValue);
                  }
                },
                items: [AppLanguage.english, AppLanguage.latin, AppLanguage.spanish].map((AppLanguage language) {
                  return DropdownMenuItem(
                    value: language,
                    child: Text(language.displayName),
                  );
                }).toList(),
              ),
            );
          },
        ),

        // Guided Mode
        Consumer(
          builder: (context, ref, child) {
            return SwitchListTile(
              secondary: const Icon(Icons.quiz),
              title: Text(
                'Guided Mode',
                style: textScaling.scaledTitleMedium(context),
              ),
              subtitle: Text(
                'Step-by-step guidance through examinations',
                style: textScaling.scaledBodyMedium(context),
              ),
              value: settings.useGuidedMode,
              onChanged: (bool value) {
                ref.read(confessionAppSettingsProvider.notifier).setUseGuidedMode(value);
              },
            );
          },
        ),

        // Show Progress
        Consumer(
          builder: (context, ref, child) {
            return SwitchListTile(
              secondary: const Icon(Icons.timeline),
              title: Text(
                'Show Progress',
                style: textScaling.scaledTitleMedium(context),
              ),
              subtitle: Text(
                'Display completion progress during examinations',
                style: textScaling.scaledBodyMedium(context),
              ),
              value: settings.showProgress,
              onChanged: (bool value) {
                ref.read(confessionAppSettingsProvider.notifier).setShowProgress(value);
              },
            );
          },
        ),

        const Divider(),

        // ═══════════════════════════════════════
        // FONT SIZE SECTION (Custom Implementation)
        // ═══════════════════════════════════════
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
              const local_widgets.FontSizeSlider(), // Use existing custom slider
            ],
          ),
        ),

        const Divider(),

        // ═══════════════════════════════════════
        // DATA & PRIVACY SECTION
        // ═══════════════════════════════════════
        const SettingsSectionHeader(title: 'Data & Privacy'),

        // Save Examination History
        Consumer(
          builder: (context, ref, child) {
            return SwitchListTile(
              secondary: const Icon(Icons.history),
              title: Text(
                'Save Examination History',
                style: textScaling.scaledTitleMedium(context),
              ),
              subtitle: Text(
                'Keep record of completed examinations',
                style: textScaling.scaledBodyMedium(context),
              ),
              value: settings.saveExaminationHistory,
              onChanged: (bool value) {
                ref.read(confessionAppSettingsProvider.notifier).setSaveExaminationHistory(value);
              },
            );
          },
        ),

        // History Retention Period
        if (settings.saveExaminationHistory)
          Consumer(
            builder: (context, ref, child) {
              return ListTile(
                leading: const Icon(Icons.schedule),
                title: Text(
                  'History Retention',
                  style: textScaling.scaledTitleMedium(context),
                ),
                subtitle: Text(
                  'Keep examination history for ${settings.historyRetentionDays} days',
                  style: textScaling.scaledBodyMedium(context),
                ),
                trailing: DropdownButton<int>(
                  value: settings.historyRetentionDays,
                  onChanged: (int? newValue) {
                    if (newValue != null) {
                      ref.read(confessionAppSettingsProvider.notifier).setHistoryRetentionDays(newValue);
                    }
                  },
                  items: [7, 14, 30, 60, 90, 365].map((int days) {
                    return DropdownMenuItem(
                      value: days,
                      child: Text('$days days'),
                    );
                  }).toList(),
                ),
              );
            },
          ),

        // Sync Settings (placeholder)
        Consumer(
          builder: (context, ref, child) {
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
                _showComingSoon(context, 'Settings sync');
              },
            );
          },
        ),

        // Clear Data
        Consumer(
          builder: (context, ref, child) {
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

        // ═══════════════════════════════════════
        // EXAMINATION EXPERIENCE SECTION
        // ═══════════════════════════════════════
        const SettingsSectionHeader(title: 'Examination Experience'),

        // Favorite Examinations (placeholder for future feature)
        Consumer(
          builder: (context, ref, child) {
            final favoriteCount = settings.favoriteExaminationIds.length;
            return ListTile(
              leading: const Icon(Icons.favorite),
              title: Text(
                'Favorite Examinations',
                style: textScaling.scaledTitleMedium(context),
              ),
              subtitle: Text(
                favoriteCount > 0 
                    ? '$favoriteCount examination${favoriteCount == 1 ? '' : 's'} favorited'
                    : 'No favorite examinations yet',
                style: textScaling.scaledBodyMedium(context),
              ),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                _showComingSoon(context, 'Favorite examinations management');
              },
            );
          },
        ),

        // Default Examination
        Consumer(
          builder: (context, ref, child) {
            final defaultExam = settings.defaultExaminationId;
            return ListTile(
              leading: const Icon(Icons.home),
              title: Text(
                'Default Examination',
                style: textScaling.scaledTitleMedium(context),
              ),
              subtitle: Text(
                defaultExam ?? 'None selected',
                style: textScaling.scaledBodyMedium(context),
              ),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                _showComingSoon(context, 'Default examination selection');
              },
            );
          },
        ),

        const Divider(),
      ],
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
        title: const Text('Support Confession Companion'),
        content: const Text(
          'Confession Companion is part of the Sancta Via ecosystem of Catholic applications.\n\n'
          'This app provides guided examinations of conscience to help faithful Catholics '
          'prepare for the Sacrament of Confession with proper reflection and prayer.\n\n'
          'Your support helps us continue developing high-quality Catholic applications for the faithful.',
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
