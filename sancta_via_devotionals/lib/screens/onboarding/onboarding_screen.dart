import 'package:flutter/material.dart';

/// Onboarding placeholder rendered at the `/onboarding` route (Task 13 stub).
///
/// The real walkthrough — claim existing progress, baseline routine, reminder
/// permission — arrives with Task 19; this shell exists so Task 13's empty-
/// state CTA can route somewhere real today.
class OnboardingScreen extends StatelessWidget {
  /// Creates the stub screen.
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Onboarding')),
      body: const Center(child: Text('Onboarding — coming soon')),
    );
  }
}
