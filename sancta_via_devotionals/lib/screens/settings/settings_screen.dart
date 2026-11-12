// The Settings tab's placeholder screen (Plan 2, Task 14).
//
// The Task 14 shell grew the four-tab structure; this placeholder backs the
// Settings branch until Task 20 builds the real settings surface at
// `lib/screens/settings/devotionals_settings_screen.dart` and repoints the
// route (this stub is then deleted, the Task 13 precedent).
library;

import 'package:flutter/material.dart';

/// The honest Task-20 placeholder for the Settings tab.
class SettingsScreen extends StatelessWidget {
  /// Creates the placeholder screen.
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: const Center(child: Text('Settings arrive with the next update.')),
    );
  }
}
