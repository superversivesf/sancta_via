import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sancta_via_shared_ui/sancta_via_shared_ui.dart';
import 'package:bible_data_riverpod/bible_data_riverpod.dart';

import '../../providers/app_providers.dart';
import '../../providers/text_scaling_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final settings = ref.watch(appSettingsProvider);
    final textScaling = ref.watch(textScaleProvider);
    final colorIntensity = ref.watch(colorIntensityProvider);

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
          _buildSectionHeader(context, textScaling, 'Appearance'),

          // Theme mode selection
          ListTile(
            leading: const Icon(Icons.brightness_6),
            title: Text('Theme Mode', style: textScaling.scaledBodyLarge(context)),
            trailing: DropdownButton<ThemeMode>(
              value: themeMode,
              onChanged: (ThemeMode? newValue) {
                if (newValue != null) {
                  ref.read(themeModeProvider.notifier).setThemeMode(newValue);
                }
              },
              items: [
                DropdownMenuItem(
                  value: ThemeMode.system,
                  child: Text('System', style: textScaling.scaledBodyMedium(context)),
                ),
                DropdownMenuItem(
                  value: ThemeMode.light,
                  child: Text('Light', style: textScaling.scaledBodyMedium(context)),
                ),
                DropdownMenuItem(
                  value: ThemeMode.dark,
                  child: Text('Dark', style: textScaling.scaledBodyMedium(context)),
                ),
              ],
            ),
          ),

          // Color intensity setting
          ListTile(
            leading: const Icon(Icons.palette),
            title: Text('Color Intensity', style: textScaling.scaledBodyLarge(context)),
            subtitle: Text('Choose between vibrant or muted colors', style: textScaling.scaledBodySmall(context)),
            trailing: DropdownButton<ColorIntensity>(
              value: colorIntensity,
              onChanged: (ColorIntensity? newValue) {
                if (newValue != null) {
                  ref.read(colorIntensityProvider.notifier).setColorIntensity(newValue);
                }
              },
              items: [
                DropdownMenuItem(
                  value: ColorIntensity.vibrant,
                  child: Text('Vibrant', style: textScaling.scaledBodyMedium(context)),
                ),
                DropdownMenuItem(
                  value: ColorIntensity.muted,
                  child: Text('Muted', style: textScaling.scaledBodyMedium(context)),
                ),
              ],
            ),
          ),

          const Divider(),

          // Bible Settings Section
          _buildSectionHeader(context, textScaling, 'Bible Settings'),

          // Bible translation selection
          ListTile(
            leading: const Icon(Icons.book),
            title: Text('Bible Translation', style: textScaling.scaledBodyLarge(context)),
            subtitle: Text(settings.selectedBibleTranslation.name, style: textScaling.scaledBodySmall(context)),
            trailing: DropdownButton<BibleTranslation>(
              value: settings.selectedBibleTranslation,
              onChanged: (BibleTranslation? newValue) {
                if (newValue != null) {
                  ref.read(appSettingsProvider.notifier).setBibleTranslation(newValue);
                }
              },
              items: BibleTranslation.values.map((translation) {
                return DropdownMenuItem(
                  value: translation,
                  child: Text(translation.abbreviation, style: textScaling.scaledBodyMedium(context)),
                );
              }).toList(),
            ),
          ),

          const Divider(),

          // Accessibility Section
          _buildSectionHeader(context, textScaling, 'Accessibility'),

          // Font size slider
          ListTile(
            leading: const Icon(Icons.text_fields),
            title: Text('Font Size', style: textScaling.scaledBodyLarge(context)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Slider(
                  value: settings.fontSize,
                  min: 12.0,
                  max: 28.0,
                  divisions: 16,
                  label: _getFontSizeLabel(settings.fontSize),
                  onChanged: (value) {
                    ref.read(appSettingsProvider.notifier).setFontSize(value);
                  },
                ),
                Text(
                  'Sample text: "In the beginning was the Word"',
                  style: textScaling.scaledBibleText(context),
                ),
              ],
            ),
          ),

          const Divider(),

          // About Section
          _buildSectionHeader(context, textScaling, 'About'),

          ListTile(
            leading: const Icon(Icons.info),
            title: Text('About Bible Reading App', style: textScaling.scaledBodyLarge(context)),
            onTap: () {
              showAboutDialog(
                context: context,
                applicationName: 'Bible Reading App',
                applicationVersion: '1.0.0',
                applicationLegalese: '© 2025 Sancta Via',
                children: [
                  const SizedBox(height: 16),
                  Text(
                    'A Catholic Bible reading app with liturgical calendar integration for daily spiritual reading.',
                    style: textScaling.scaledBodyMedium(context),
                  ),
                ],
              );
            },
          ),

          ListTile(
            leading: const Icon(Icons.code),
            title: Text('Version', style: textScaling.scaledBodyLarge(context)),
            subtitle: Text('1.0.0', style: textScaling.scaledBodySmall(context)),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, TextScaling textScaling, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: textScaling.scaledTitleMedium(context).copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  String _getFontSizeLabel(double value) {
    if (value <= 12) return 'Smallest';
    if (value <= 14) return 'Smaller';
    if (value <= 16) return 'Small';
    if (value <= 18) return 'Normal';
    if (value <= 20) return 'Large';
    if (value <= 24) return 'Larger';
    return 'Largest';
  }
}
