import 'package:flutter/material.dart';

/// Empty state widget shown when no statistics exist yet
///
/// Displays a friendly message encouraging the user to start
/// their first rosary to begin tracking progress.
class EmptyStatistics extends StatelessWidget {
  /// Callback when the user taps to start their first rosary
  final VoidCallback? onStartPraying;

  const EmptyStatistics({this.onStartPraying, super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.auto_awesome,
                size: 56,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'Begin Your Journey',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'Complete your first rosary to start tracking your prayer statistics. '
              'Watch your streak grow and see your dedication over time.',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            if (onStartPraying != null)
              ElevatedButton.icon(
                onPressed: onStartPraying,
                icon: const Icon(Icons.play_arrow),
                label: const Text('Start Praying'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
