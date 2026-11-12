import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:saint_data/saint_data.dart';
import 'package:sancta_via_shared_ui/sancta_via_shared_ui.dart';

import '../../models/saint_app_settings.dart';
import '../../providers/saint_app_settings_provider.dart';

/// Settings screen (spec §8): the shared settings widgets composed exactly
/// as the liturgical calendar app composes them, plus a Saint Companion
/// app-data section (favorites count, recents count, saints data version)
/// and the "About this dataset" credit paragraph (spec §12).
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // App data counts come from the settings provider's synchronous state —
    // watching it here keeps the counts live as favorites/recents change.
    final SaintAppSettings saintSettings = ref.watch(saintAppSettingsProvider);

    return FutureBuilder<PackageInfo>(
      future: PackageInfo.fromPlatform(),
      builder: (context, snapshot) {
        // App information for the unified screen
        final appInfo = AppInfo(
          appName: 'Sancta Via Saints',
          version: snapshot.hasData ? snapshot.data!.version : 'Loading...',
          description:
              'A searchable Catholic saints companion: need-based patronage '
              'lookup, feast-day celebrations, and prayers, themed by the '
              'liturgical year.',
          icon: const Icon(
            Icons.person_search,
            size: 48,
            color: Colors.blueGrey,
          ),
          onFeedback: () => _showComingSoon(context, 'Feedback'),
          onSupport: () => _showSupportDialog(context),
        );

        return Scaffold(
          appBar: AppBar(title: const Text('Settings')),
          body: ListView(
            children: [
              // ═══════════════════════════════════════
              // APPEARANCE SECTION (from shared UI)
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
              // ACCESSIBILITY SECTION (WITH working font size)
              // ═══════════════════════════════════════
              const AccessibilitySettings(
                fontPreviewText:
                    'Sample prayer text: "Hail Mary, full of grace..."',
                showFontSize: true,
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
              // APP DATA SECTION (Saint Companion specific)
              // ═══════════════════════════════════════
              _buildAppDataSection(saintSettings),
              const Divider(),

              // ═══════════════════════════════════════
              // DATASET CREDIT (spec §12)
              // ═══════════════════════════════════════
              _buildDatasetCreditSection(),
              const Divider(),

              // ═══════════════════════════════════════
              // ABOUT SECTION
              // ═══════════════════════════════════════
              AppInfoSection(appInfo: appInfo),
            ],
          ),
        );
      },
    );
  }

  /// Favorites count, recents count, and the saints data version. Counts
  /// come from the settings provider's synchronous state; the data version
  /// is the saints schema version the bundled database is stamped with
  /// (`PRAGMA user_version = $saintsSchemaVersion`). The copy on disk can
  /// differ only transiently — an interrupted refresh is auto-healed by the
  /// version-checked re-copy before the repository opens it, so the bundled
  /// constant is the honest display value.
  Widget _buildAppDataSection(SaintAppSettings saintSettings) {
    return Column(
      key: const Key('app_data_section'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SettingsSectionHeader(title: 'App Data'),
        ListTile(
          leading: const Icon(Icons.favorite),
          title: const Text('Favorites'),
          subtitle: Text(
            '${saintSettings.favoriteSlugs.length} saints saved',
            key: const Key('app_data_favorites_count'),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.history),
          title: const Text('Recently Viewed'),
          subtitle: Text(
            '${saintSettings.recentSlugs.length} saints viewed recently',
            key: const Key('app_data_recents_count'),
          ),
        ),
        const ListTile(
          leading: Icon(Icons.storage),
          title: Text('Saints Database Version'),
          subtitle: Text(
            'Data version $saintsSchemaVersion',
            key: Key('app_data_data_version'),
          ),
        ),
      ],
    );
  }

  /// "About this dataset" credit (spec §12): the dataset's origin is the
  /// sibling saint-for-that repo, and the web app's own credit — "inspired
  /// by *There Is a Saint for That* by Peter's Barque" — is carried into
  /// this about/settings info section. The upstream attribution link is
  /// plain text (no launcher, same convention as the detail sources tiles).
  Widget _buildDatasetCreditSection() {
    return const Column(
      key: Key('dataset_credit_section'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SettingsSectionHeader(title: 'About This Dataset'),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            'The saint dataset in this app comes from the open-source '
            'saint-for-that project, with per-saint sources and image '
            'attribution preserved throughout. Inspired by "There Is a '
            'Saint for That" by Peter\'s Barque.',
            key: Key('dataset_credit_text'),
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'https://www.youtube.com/watch?v=9lEUN28c0oc',
            key: Key('dataset_credit_url'),
          ),
        ),
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
        title: const Text('Support Sancta Via Saints'),
        content: const Text(
          'Sancta Via Saints is part of the Sancta Via ecosystem of Catholic '
          'applications.\n\n'
          'This app provides need-based patronage lookup across the '
          'communion of saints — helping you find the right saint for what '
          'you are praying for today.\n\n'
          'Your support helps us continue developing high-quality Catholic '
          'applications for the faithful.',
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
