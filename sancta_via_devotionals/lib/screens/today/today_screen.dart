import 'package:flutter/material.dart';

/// Placeholder Today screen rendered at the root route.
///
/// The real Today pipeline (assembly, progress, settings) arrives with later
/// tasks; this shell exists so the app builds and launches from day one.
class TodayScreen extends StatelessWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sancta Via Devotionals')),
      body: const Center(child: Text('Today — placeholder')),
    );
  }
}
