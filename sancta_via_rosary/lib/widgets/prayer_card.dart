import 'package:flutter/material.dart';

import '../models/models.dart';

/// Card displaying the current prayer with nice typography
class PrayerCard extends StatelessWidget {
  final RosaryPrayer prayer;
  final int? currentRepeat;
  final VoidCallback? onTap;

  const PrayerCard({
    super.key,
    required this.prayer,
    this.currentRepeat,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: colorScheme.shadow.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Prayer title
            Row(
              children: [
                Icon(
                  _getPrayerIcon(prayer.type),
                  color: colorScheme.primary,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    prayer.title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            // Prayer text
            if (prayer.isPartial && prayer.partialRepeat != null)
              _buildPartialPrayerContent(theme, colorScheme)
            else
              Text(
                prayer.text,
                style: theme.textTheme.bodyLarge?.copyWith(
                  height: 1.6,
                  letterSpacing: 0.3,
                  color: colorScheme.onSurface,
                ),
              ),
            // Description if available
            if (prayer.description != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.5,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  prayer.description!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPartialPrayerContent(ThemeData theme, ColorScheme colorScheme) {
    final buffer = StringBuffer();

    // Opening
    if (prayer.partialStart != null && prayer.partialStart!.isNotEmpty) {
      buffer.writeln(prayer.partialStart);
      buffer.writeln();
    }

    // Current repetition
    if (currentRepeat != null && currentRepeat! > 0) {
      buffer.writeln('$currentRepeat. ${prayer.partialRepeat}');
    } else {
      buffer.writeln(prayer.partialRepeat);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (prayer.partialStart != null && prayer.partialStart!.isNotEmpty) ...[
          Text(
            prayer.partialStart!,
            style: theme.textTheme.bodyLarge?.copyWith(
              height: 1.6,
              letterSpacing: 0.3,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),
        ],
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: colorScheme.primary.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (currentRepeat != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: colorScheme.primary,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Prayer $currentRepeat of ${prayer.repeatCount}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.onPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              Text(
                prayer.partialRepeat ?? '',
                style: theme.textTheme.bodyLarge?.copyWith(
                  height: 1.6,
                  letterSpacing: 0.3,
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        if (prayer.partialEnd != null && prayer.partialEnd!.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            prayer.partialEnd!,
            style: theme.textTheme.bodyLarge?.copyWith(
              height: 1.6,
              letterSpacing: 0.3,
              color: colorScheme.onSurfaceVariant,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ],
    );
  }

  IconData _getPrayerIcon(PrayerType type) {
    switch (type) {
      case PrayerType.signOfCross:
      case PrayerType.apostlesCreed:
      case PrayerType.openingOurFather:
      case PrayerType.openingHailMary:
        return Icons.play_arrow;
      case PrayerType.mystery:
        return Icons.star;
      case PrayerType.ourFather:
        return Icons.handshake;
      case PrayerType.hailMary:
        return Icons.favorite;
      case PrayerType.gloryBe:
        return Icons.celebration;
      case PrayerType.fatimaPrayer:
        return Icons.favorite_border;
      case PrayerType.closing:
        return Icons.check_circle;
    }
  }
}

/// Card for displaying mystery meditation
class MysteryCard extends StatelessWidget {
  final Mystery mystery;
  final VoidCallback? onTap;

  const MysteryCard({super.key, required this.mystery, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colorScheme.primaryContainer,
              colorScheme.primaryContainer.withValues(alpha: 0.7),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: colorScheme.shadow.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.auto_stories,
                  color: colorScheme.onPrimaryContainer,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Mystery ${mystery.number}',
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onPrimaryContainer,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Text(
              mystery.name,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              mystery.scripture,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onPrimaryContainer.withValues(alpha: 0.8),
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              mystery.description,
              style: theme.textTheme.bodyLarge?.copyWith(
                height: 1.6,
                color: colorScheme.onPrimaryContainer.withValues(alpha: 0.9),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.eco,
                    size: 16,
                    color: colorScheme.onPrimaryContainer,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Fruit: ${mystery.fruit}',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
