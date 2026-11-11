import 'package:flutter/material.dart';

/// Centered spinner used for a section's loading state while a
/// repository-backed provider is resolving. Established by the home screen
/// and shared since Task 12.
class SectionSpinner extends StatelessWidget {
  const SectionSpinner({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: CircularProgressIndicator(),
      ),
    );
  }
}
