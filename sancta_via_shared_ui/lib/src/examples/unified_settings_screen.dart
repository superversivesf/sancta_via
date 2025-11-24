import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/settings_section_header.dart';
import '../widgets/theme_mode_selector.dart';
import '../widgets/color_intensity_selector.dart';
import '../widgets/liturgical_color_preview.dart';
import '../widgets/font_size_selector.dart';
import '../widgets/language_selector.dart';
import '../widgets/accessibility_settings.dart';
import '../widgets/notifications_settings.dart';
import '../widgets/app_info_section.dart';
import '../models/base_settings_model.dart';

/// Example unified settings screen showing how to use all standardized components
/// 
/// This demonstrates the recommended structure for settings screens across all
/// Sancta Via apps. Apps can:
/// 1. Use this as-is for basic settings
/// 2. Extend with app-specific settings sections
/// 3. Customize individual components as needed
class UnifiedSettingsScreen extends ConsumerWidget {
  final AppInfo appInfo;
  final Widget? appSpecificSettings;
  final List<NotificationOption>? customNotifications;

  const UnifiedSettingsScreen({
    super.key,
    required this.appInfo,
    this.appSpecificSettings,
    this.customNotifications,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: SafeArea(
        top: false, // Let AppBar handle top
        child: ListView(
          children: [
          // ═══════════════════════════════════════
          // APPEARANCE SECTION
          // ═══════════════════════════════════════
          const SettingsSectionHeader(title: 'Appearance'),
          
          // Theme mode selection (Light/Dark/System)
          const ThemeModeSelector(),
          
          // Color intensity selection (Vibrant/Muted)
          const ColorIntensitySelector(),
          
          // Liturgical color preview
          const LiturgicalColorPreview(),
          
          const Divider(),

          // ═══════════════════════════════════════
          // ACCESSIBILITY SECTION
          // ═══════════════════════════════════════
          const AccessibilitySettings(
            fontPreviewText: 'Sample prayer text: "Hail Mary, full of grace..."',
          ),
          
          const Divider(),

          // ═══════════════════════════════════════
          // LANGUAGE & LOCALIZATION
          // ═══════════════════════════════════════
          const SettingsSectionHeader(title: 'Language & Localization'),
          
          const LanguageSelector(
            subtitle: 'Choose language for prayers and interface',
          ),
          
          const Divider(),

          // ═══════════════════════════════════════
          // NOTIFICATIONS SECTION
          // ═══════════════════════════════════════
          NotificationsSettings(
            subtitle: 'Prayer reminders and liturgical notifications',
            customOptions: customNotifications ?? [
              CatholicNotificationOptions.prayerReminders(),
              CatholicNotificationOptions.liturgicalCalendar(),
            ],
          ),
          
          const Divider(),

          // ═══════════════════════════════════════
          // APP-SPECIFIC SETTINGS
          // ═══════════════════════════════════════
          if (appSpecificSettings != null) ...[
            appSpecificSettings!,
            const Divider(),
          ],

          // ═══════════════════════════════════════
          // ABOUT SECTION
          // ═══════════════════════════════════════
            AppInfoSection(
              appInfo: appInfo,
            ),
          ],
        ),
      ),
    );
  }
}

/// Example of how individual apps would create their settings screen
class ExampleBibleAppSettingsScreen extends ConsumerWidget {
  const ExampleBibleAppSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // App-specific info
    final appInfo = AppInfo(
      appName: 'Bible Reading App',
      version: '1.0.0',
      description: 'A Catholic Bible reading app with liturgical calendar integration for daily spiritual reading.',
      icon: const Icon(Icons.book, size: 48),
    );

    // App-specific settings section
    final bibleSpecificSettings = Column(
      children: [
        const SettingsSectionHeader(title: 'Bible Settings'),
        
        // Bible translation selector (app-specific)
        ListTile(
          leading: const Icon(Icons.book),
          title: const Text('Bible Translation'),
          subtitle: const Text('Choose your preferred translation'),
          trailing: DropdownButton<String>(
            value: 'CPDV',
            items: ['CPDV', 'DRA', 'Vulgate'].map((translation) {
              return DropdownMenuItem(
                value: translation,
                child: Text(translation),
              );
            }).toList(),
            onChanged: (value) {
              // Handle translation change
            },
          ),
        ),
        
        // Reading mode (app-specific)
        SwitchListTile(
          secondary: const Icon(Icons.auto_stories),
          title: const Text('Liturgical Reading Mode'),
          subtitle: const Text('Follow daily liturgical readings'),
          value: true,
          onChanged: (value) {
            // Handle reading mode change
          },
        ),
      ],
    );

    return UnifiedSettingsScreen(
      appInfo: appInfo,
      appSpecificSettings: bibleSpecificSettings,
      customNotifications: [
        CatholicNotificationOptions.liturgicalCalendar(),
        // Custom notification for this app
        NotificationOption(
          title: 'Daily Reading Reminders',
          subtitle: 'Notifications for daily Bible readings',
          icon: Icons.schedule_outlined,
        ),
      ],
    );
  }
}

/// Example of how prayer app would create their settings screen
class ExamplePrayerAppSettingsScreen extends ConsumerWidget {
  const ExamplePrayerAppSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appInfo = AppInfo(
      appName: 'Prayer Companion',
      version: '1.0.0',
      description: 'Traditional and contemporary Catholic prayers with liturgical calendar integration.',
      icon: const Icon(Icons.church, size: 48),
    );

    final prayerSpecificSettings = Column(
      children: [
        const SettingsSectionHeader(title: 'Prayer Settings'),
        
        // Prayer reading mode
        ListTile(
          leading: const Icon(Icons.auto_stories),
          title: const Text('Reading Mode'),
          subtitle: const Text('Choose prayer display style'),
          trailing: DropdownButton<String>(
            value: 'Normal',
            items: ['Normal', 'Contemplative', 'Immersive'].map((mode) {
              return DropdownMenuItem(
                value: mode,
                child: Text(mode),
              );
            }).toList(),
            onChanged: (value) {
              // Handle reading mode change
            },
          ),
        ),
        
        // Verse highlighting
        SwitchListTile(
          secondary: const Icon(Icons.touch_app),
          title: const Text('Verse Highlighting'),
          subtitle: const Text('Tap verses to follow along while praying'),
          value: false,
          onChanged: (value) {
            // Handle verse highlighting toggle
          },
        ),
      ],
    );

    return UnifiedSettingsScreen(
      appInfo: appInfo,
      appSpecificSettings: prayerSpecificSettings,
      customNotifications: [
        CatholicNotificationOptions.prayerReminders(),
        CatholicNotificationOptions.liturgicalCalendar(),
      ],
    );
  }
}

/// Migration helper: How to convert existing settings screens
/// 
/// BEFORE (individual app implementation):
/// ```dart
/// class OldSettingsScreen extends ConsumerWidget {
///   Widget build(context, ref) {
///     return Scaffold(
///       appBar: AppBar(title: Text('Settings')),
///       body: ListView(
///         children: [
///           // Custom theme mode selector
///           ListTile(/* theme mode code */),
///           // Custom font size slider
///           ListTile(/* font size code */),
///           // Custom about section
///           ListTile(/* about code */),
///         ],
///       ),
///     );
///   }
/// }
/// ```
/// 
/// AFTER (using unified components):
/// ```dart
/// class NewSettingsScreen extends ConsumerWidget {
///   Widget build(context, ref) {
///     return UnifiedSettingsScreen(
///       appInfo: AppInfo(
///         appName: 'My App',
///         version: '1.0.0',
///         description: 'App description...',
///       ),
///       appSpecificSettings: Column(
///         children: [
///           // Only app-specific settings here
///           // All common settings handled automatically
///         ],
///       ),
///     );
///   }
/// }
/// ```
class SettingsMigrationExample extends StatelessWidget {
  const SettingsMigrationExample({super.key});

  @override
  Widget build(BuildContext context) {
    return const Placeholder(
      child: Text('See comments above for migration examples'),
    );
  }
}
