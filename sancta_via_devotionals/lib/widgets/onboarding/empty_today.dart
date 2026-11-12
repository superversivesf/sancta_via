import 'package:flutter/material.dart';

/// The Today screen's empty state: shown when nothing resolves due today —
/// which is NOT the same as "nothing enrolled" (fix round 1): an enrolled
/// program that is not due today leaves every section empty too, so the copy
/// carries nothing-due-today semantics and never claims enrollment is absent
/// while a program is enrolled.
///
/// The call-to-action routes to `/onboarding` (Task 13 stub route — the real
/// walkthrough lands in Task 19); it serves both jobs, starting the
/// walkthrough on a fresh install and taking up a devotion on any other
/// empty day. The copy adapts to [hasEnrolledPrograms] (the assembly's
/// enrollment signal) and [onboardingComplete].
class EmptyToday extends StatelessWidget {
  /// Creates the empty state.
  const EmptyToday({
    required this.hasEnrolledPrograms,
    required this.onboardingComplete,
    required this.onStartOnboarding,
    super.key,
  });

  /// Whether any program is enrolled — the [TodayAssembly.hasEnrolledPrograms]
  /// signal. Gates the CTA label and keeps the body from claiming enrollment
  /// is absent when it is not.
  final bool hasEnrolledPrograms;

  /// Whether the settings' onboarding walkthrough has completed.
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
              'Nothing scheduled right now',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _bodyText,
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
              label: Text(_ctaLabel),
            ),
          ],
        ),
      ),
    );
  }

  /// The body copy — honest for both kinds of empty day: active programs
  /// with nothing due, and a genuinely empty install.
  String get _bodyText {
    if (hasEnrolledPrograms) {
      return 'Your devotions have nothing due right now — they appear here '
          'as their day arrives.';
    }
    return onboardingComplete
        ? 'Nothing is enrolled yet. Onboarding lets you set up your anchors '
              'and commitments again.'
        : 'Onboarding walks you through your first anchors and daily '
              'commitments.';
  }

  /// The CTA label — a fresh install gets walked in; everyone else is
  /// offered a devotion to take up (the walkthrough serves that too).
  String get _ctaLabel {
    if (hasEnrolledPrograms) {
      return 'Take up a devotion';
    }
    return onboardingComplete ? 'Set up your day' : 'Get started';
  }
}
