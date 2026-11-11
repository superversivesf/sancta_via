import 'package:flutter/material.dart';

/// Placeholder saint detail screen.
///
/// Replaced by the real saint detail screen in a later task.
class SaintDetailScreen extends StatefulWidget {
  const SaintDetailScreen({required this.slug, super.key});

  final String slug;

  @override
  State<SaintDetailScreen> createState() => _SaintDetailScreenState();
}

class _SaintDetailScreenState extends State<SaintDetailScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Saint Detail')),
      body: Center(child: Text(widget.slug)),
    );
  }
}
