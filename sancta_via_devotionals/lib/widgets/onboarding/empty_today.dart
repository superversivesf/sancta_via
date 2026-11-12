import 'package:flutter/material.dart';

/// The Today screen's onboarding empty state: shown when the day carries no
/// devotional item because nothing is enrolled.
///
/// The call-to-action routes to `/onboarding` (Task 13 stub route — the real
/// walkthrough lands in Task 19). The copy adapts to [onboardingComplete]:
/// a first-visit user is invited to get started, a returning user whose day
/// emptied out is invited to re-open onboarding.
class EmptyToday extends StatelessWidget {
  /// Creates the empty state.
  const EmptyToday({
    required this.onboardingComplete,
    required this.onStartOnboarding,
    super.key,
  });

  /// Whether the settings' onboarding walkthrough has completed — only the
  /// CTA copy changes with it.
  final bool onboardingComplete;

  /// Called when the onboarding CTA is pressed.
  final VoidCallback onStartOnboarding;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.self_improvement,
              size: 48,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'Nothing to pray yet',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              onboardingComplete
                  ? 'Nothing is enrolled for today. Onboarding lets you set '
                        'up your anchors and commitments again.'
                  : 'Onboarding walks you through your first anchors and '
                        'daily commitments.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              key: const Key('onboarding_cta'),
              onPressed: onStartOnboarding,
              icon: const Icon(Icons.compass_calibration),
              label: Text(
                onboardingComplete ? 'Set up your day' : 'Get started',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
