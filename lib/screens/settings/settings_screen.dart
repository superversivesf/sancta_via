import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_ui/shared_ui.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          // Appearance Section
          const SettingsSectionHeader(title: 'Appearance'),

          // Theme mode selection - using shared component
          const ThemeModeSelector(),

          // Color intensity setting - using shared component
          const ColorIntensitySelector(),

          // Preview liturgical colors - using shared component
          const LiturgicalColorPreview(),

          const Divider(),

          // About Section
          const SettingsSectionHeader(title: 'About'),

          ListTile(
            leading: const Icon(Icons.info),
            title: const Text('About Sancta Via Calendar'),
            onTap: () {
              _showSupportDialog(context);
            },
          ),

          ListTile(
            leading: const Icon(Icons.code),
            title: const Text('Version'),
            subtitle: const Text('1.0.0'),
          ),
        ],
      ),
    );
  }


  void _showSupportDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Support Development'),
        content: const Text(
          'Sancta Via Calendar is part of a larger ecosystem of Catholic apps.\n\n'
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

}
