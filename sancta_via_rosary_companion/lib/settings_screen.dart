import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'providers/rosary_providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(rosarySettingsProvider);
    final settingsNotifier = ref.read(rosarySettingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/home'),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Prayer Settings',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('Show Full Prayer Text'),
                    value: settings.showFullText,
                    onChanged: (value) {
                      settingsNotifier.toggleShowFullText();
                    },
                  ),
                  SwitchListTile(
                    title: const Text('Auto-Advance'),
                    value: settings.autoAdvance,
                    onChanged: (value) {
                      settingsNotifier.toggleAutoAdvance();
                    },
                  ),
                  SwitchListTile(
                    title: const Text('Enable Bead Counter'),
                    value: settings.enableBeadCounter,
                    onChanged: (value) {
                      settingsNotifier.toggleBeadCounter();
                    },
                  ),
                  SwitchListTile(
                    title: const Text('Show Imagery'),
                    value: settings.showImagery,
                    onChanged: (value) {
                      settingsNotifier.toggleShowImagery();
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Display Settings',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    title: const Text('Text Size'),
                    subtitle: Text('${settings.fontSize.toInt()} pt'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove),
                          onPressed: () {
                            final newSize = settings.fontSize - 1.0;
                            if (newSize >= 12.0) {
                              settingsNotifier.updateFontSize(newSize);
                            }
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.add),
                          onPressed: () {
                            final newSize = settings.fontSize + 1.0;
                            if (newSize <= 24.0) {
                              settingsNotifier.updateFontSize(newSize);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                  SwitchListTile(
                    title: const Text('Use Daily Schedule'),
                    value: settings.useDailySchedule,
                    onChanged: (value) {
                      settingsNotifier.toggleDailySchedule();
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'App Information',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    leading: const Icon(Icons.info),
                    title: const Text('Version'),
                    subtitle: const Text('1.0.2'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.favorite),
                    title: const Text('Support'),
                    subtitle: const Text('sancta.via.app@gmail.com'),
                    onTap: () {
                      // TODO: Open email
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.privacy_tip),
                    title: const Text('Privacy Policy'),
                    onTap: () {
                      // TODO: Show privacy policy
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
