// The Progress tab's placeholder screen (Plan 2, Task 14).
//
// Task 1 left the app's shell routes honest-but-stubbed; the Task 14 shell
// grew the remaining tabs, so this placeholder backs the Progress branch
// exactly the way the shell's other tabs work. The REAL progress surface —
// ordinals, phases, badges, intentions — is Task 16's, which creates this
// same file path and replaces the stub wholesale.
library;

import 'package:flutter/material.dart';

/// The honest Task-16 placeholder for the Progress tab.
class ProgressScreen extends StatelessWidget {
  /// Creates the placeholder screen.
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Progress')),
      body: const Center(
        child: Text('Progress tracking arrives with the next update.'),
      ),
    );
  }
}
