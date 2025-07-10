import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sancta_via_shared_ui/sancta_via_shared_ui.dart';

import '../../providers/prayer_app_settings_provider.dart';
import '../../providers/text_scaling_provider.dart';
import '../../widgets/font_size_selector.dart' as local_widgets;
import '../../widgets/enhanced_prayer_text.dart';

/// Unified settings screen for Prayer Companion using standardized components
class PrayerSettingsScreen extends ConsumerWidget {
  const PrayerSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // App information for the unified screen
    final appInfo = AppInfo(
      appName: 'Prayer Companion',
      version: '1.0.0',
      description: 'Traditional and contemporary Catholic prayers with liturgical calendar integration for daily spiritual reading.',
      icon: const Icon(Icons.church, size: 48, color: Colors.indigo),
      onFeedback: () => _showComingSoon(context, 'Feedback'),
      onSupport: () => _showSupportDialog(context),
    );

    // Prayer-specific settings section
    final prayerSpecificSettings = _buildPrayerSpecificSettings(context, ref);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        centerTitle: true,
      ),
      body: UnifiedSettingsScreen(
        appInfo: appInfo,
        appSpecificSettings: prayerSpecificSettings,
        customNotifications: [
          CatholicNotificationOptions.prayerReminders(
            enabled: false, // TODO: Connect to actual notifications
            onChanged: (enabled) {
              _showComingSoon(context, 'Prayer reminders');
            },
          ),
          CatholicNotificationOptions.liturgicalCalendar(
            enabled: false, // TODO: Connect to liturgical notifications
            onChanged: (enabled) {
              _showComingSoon(context, 'Liturgical calendar notifications');
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPrayerSpecificSettings(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(prayerAppSettingsProvider);
    final textScaling = ref.watch(textScaleProvider);
    
    return Column(
      children: [
        // ═══════════════════════════════════════
        // PRAYER SETTINGS SECTION
        // ═══════════════════════════════════════
        const SettingsSectionHeader(title: 'Prayer Settings'),

        // Default Language (reusing unified language selector)
        Consumer(
          builder: (context, ref, child) {
            return ListTile(
              leading: const Icon(Icons.language),
              title: Text(
                'Prayer Language',
                style: textScaling.scaledTitleMedium(context),
              ),
              subtitle: Text(
                'Choose language preference for prayers',
                style: textScaling.scaledBodyMedium(context),
              ),
              trailing: DropdownButton<AppLanguage>(
                value: settings.defaultLanguage,
                onChanged: (AppLanguage? newValue) {
                  if (newValue != null) {
                    final languageString = newValue == AppLanguage.latin ? 'Latin' :
                                          newValue == AppLanguage.spanish ? 'Spanish' : 'English';
                    ref.read(prayerAppSettingsProvider.notifier).updateDefaultLanguage(languageString);
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
              const local_widgets.FontSizeSlider(), // Use enhanced custom slider
            ],
          ),
        ),

        const Divider(),

        // ═══════════════════════════════════════
        // READING EXPERIENCE SECTION
        // ═══════════════════════════════════════
        const SettingsSectionHeader(title: 'Reading Experience'),

        // Reading Mode Selection
        Consumer(
          builder: (context, ref, child) {
            return ListTile(
              leading: const Icon(Icons.auto_stories),
              title: Text(
                'Reading Mode',
                style: textScaling.scaledTitleMedium(context),
              ),
              subtitle: Text(
                _getReadingModeDescription(settings.readingMode),
                style: textScaling.scaledBodyMedium(context),
              ),
              trailing: DropdownButton<PrayerReadingMode>(
                value: settings.readingMode,
                onChanged: (PrayerReadingMode? newValue) {
                  if (newValue != null) {
                    ref.read(prayerAppSettingsProvider.notifier).updateReadingMode(newValue);
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

        // Verse Highlighting
        Consumer(
          builder: (context, ref, child) {
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
              value: settings.verseHighlighting,
              onChanged: (bool value) {
                ref.read(prayerAppSettingsProvider.notifier).updateVerseHighlighting(value);
              },
            );
          },
        ),

        const Divider(),

        // ═══════════════════════════════════════
        // PRAYER LIBRARY SECTION
        // ═══════════════════════════════════════
        const SettingsSectionHeader(title: 'Prayer Library'),

        // Favorites Management
        Consumer(
          builder: (context, ref, child) {
            final favoriteCount = settings.favoritePrayerIds.length;
            return ListTile(
              leading: const Icon(Icons.favorite),
              title: Text(
                'Favorite Prayers',
                style: textScaling.scaledTitleMedium(context),
              ),
              subtitle: Text(
                favoriteCount > 0 
                    ? '$favoriteCount prayer${favoriteCount == 1 ? '' : 's'} favorited'
                    : 'No favorite prayers yet',
                style: textScaling.scaledBodyMedium(context),
              ),
              trailing: favoriteCount > 0 
                  ? TextButton(
                      onPressed: () => _showClearFavoritesDialog(context, ref),
                      child: const Text('Clear'),
                    )
                  : null,
            );
          },
        ),

        // Recent Prayers Management
        Consumer(
          builder: (context, ref, child) {
            final recentCount = settings.recentPrayerIds.length;
            return ListTile(
              leading: const Icon(Icons.history),
              title: Text(
                'Recent Prayers',
                style: textScaling.scaledTitleMedium(context),
              ),
              subtitle: Text(
                recentCount > 0 
                    ? '$recentCount recent prayer${recentCount == 1 ? '' : 's'} (max ${settings.maxRecentPrayers})'
                    : 'No recent prayers yet',
                style: textScaling.scaledBodyMedium(context),
              ),
              trailing: recentCount > 0 
                  ? TextButton(
                      onPressed: () => _showClearRecentsDialog(context, ref),
                      child: const Text('Clear'),
                    )
                  : null,
            );
          },
        ),

        const Divider(),

        // ═══════════════════════════════════════
        // DATA & STORAGE SECTION
        // ═══════════════════════════════════════
        const SettingsSectionHeader(title: 'Data & Storage'),

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
                'Backup and sync your prayer preferences',
                style: textScaling.scaledBodyMedium(context),
              ),
              onTap: () {
                _showComingSoon(context, 'Settings sync');
              },
            );
          },
        ),

        // Clear Cache
        Consumer(
          builder: (context, ref, child) {
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

        // ═══════════════════════════════════════
        // PREVIEW SECTION
        // ═══════════════════════════════════════
        const SettingsSectionHeader(title: 'Preview'),
        
        _buildPrayerTextPreview(context, ref),

        const Divider(),
      ],
    );
  }

  Widget _buildPrayerTextPreview(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(prayerAppSettingsProvider);
    
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
            'Prayer Text Preview',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          
          // Sample prayer text with current formatting
          EnhancedPrayerText(
            text: 'Our Father, who art in heaven,\nhallowed be thy name.\nThy kingdom come,\nthy will be done,\non earth as it is in heaven.',
            language: settings.defaultLanguage.displayName,
            readingMode: settings.readingMode,
            enableVerseHighlighting: settings.verseHighlighting,
          ),
          
          const SizedBox(height: 12),
          
          // Settings summary
          Text(
            'Font: ${settings.fontSize.round()}pt • '
            'Scale: ${settings.effectiveTextScaleFactor.toStringAsFixed(2)}x • '
            'Mode: ${_getReadingModeLabel(settings.readingMode)} • '
            'Language: ${settings.defaultLanguage.displayName}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.6),
            ),
          ),
        ],
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
        title: const Text('Support Prayer Companion'),
        content: const Text(
          'Prayer Companion is part of the Sancta Via ecosystem of Catholic applications.\n\n'
          'This app provides access to traditional and contemporary Catholic prayers, '
          'with liturgical calendar integration for seasonal prayer recommendations.\n\n'
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

  void _showClearFavoritesDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Favorites'),
        content: const Text(
          'This will remove all prayers from your favorites list.\n\n'
          'This action cannot be undone. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              // TODO: Implement clear favorites
              _showComingSoon(context, 'Clear favorites');
            },
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  void _showClearRecentsDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Recent Prayers'),
        content: const Text(
          'This will remove all prayers from your recent prayers list.\n\n'
          'This action cannot be undone. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              // TODO: Implement clear recents  
              _showComingSoon(context, 'Clear recent prayers');
            },
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  void _showClearCacheDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Cache'),
        content: const Text(
          'This will clear cached prayer data and may require re-downloading content. '
          'Your preferences and favorites will be preserved.\n\n'
          'Do you want to continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Cache cleared successfully')),
              );
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }
}
