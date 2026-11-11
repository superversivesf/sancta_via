import 'package:flutter/material.dart';

/// Placeholder category detail screen.
///
/// Replaced by the real category detail screen in a later task.
class CategoryDetailScreen extends StatefulWidget {
  const CategoryDetailScreen({required this.categoryId, super.key});

  final String categoryId;

  @override
  State<CategoryDetailScreen> createState() => _CategoryDetailScreenState();
}

class _CategoryDetailScreenState extends State<CategoryDetailScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Category Detail')),
      body: Center(child: Text(widget.categoryId)),
    );
  }
}
