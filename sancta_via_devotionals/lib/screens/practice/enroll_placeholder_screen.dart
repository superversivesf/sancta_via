// The enrollment flow's placeholder screen (Plan 2, Task 14).
//
// The pinned Task-14 contract routes the detail screen's Enroll CTA to
// `/program/:packId/enroll` NOW, while the real enrollment flow page — the
// commitment-aware derive-and-enroll flow — belongs to Task 15, which will
// DELETE this file and own `enroll_screen.dart` at this route instead.
// Until then this honest stub keeps the CTA navigable end to end.
library;

import 'package:flutter/material.dart';

/// The honest Task-15 placeholder for the enrollment flow route.
class EnrollPlaceholderScreen extends StatelessWidget {
  /// Creates the placeholder screen.
  const EnrollPlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Enroll')),
      body: const Center(
        child: Column(
          key: Key('enroll_placeholder'),
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.hourglass_top_outlined, size: 48),
            SizedBox(height: 16),
            Text('The enrollment flow is coming soon.'),
          ],
        ),
      ),
    );
  }
}
