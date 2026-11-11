import 'package:flutter/material.dart';

/// A keyed error card with a retry button, shown when a repository-backed
/// provider fails. Each screen section passes [stateKey]
/// (`load_error_state_<section>` on home, `<section>_error_state` since
/// Task 12) so keyed lookups target one section's error state.
///
/// Established by the home screen (Task 11 ruling 1: the error state must
/// be reachable, with a retry affordance); shared since Task 12 so the
/// category screens render the identical card.
class LoadErrorCard extends StatelessWidget {
  const LoadErrorCard({
    required this.stateKey,
    required this.onRetry,
    super.key,
  });

  /// Key for the rendered card, e.g. `Key('load_error_state_today')`.
  final Key stateKey;

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      key: stateKey,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: <Widget>[
            const Icon(Icons.error_outline, size: 32),
            const SizedBox(height: 8),
            Text(
              'Could not load saints.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
