import 'package:flutter/material.dart';

/// Placeholder home screen.
///
/// Replaced by the real saints home screen in a later task.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Saints')),
      body: const Center(child: Text('Saints home')),
    );
  }
}
