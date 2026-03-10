import 'package:flutter/material.dart';

/// A reusable card widget for displaying statistics
///
/// Features:
/// - Icon with background color
/// - Title and value display
/// - Subtitle for additional context
/// - Consistent styling with the app theme
class StatCard extends StatelessWidget {
  /// The icon to display
  final IconData icon;

  /// The title/label for this stat
  final String title;

  /// The main value to display
  final String value;

  /// Optional subtitle text
  final String? subtitle;

  /// Color for the icon background
  final Color? iconColor;

  /// Color for the icon itself
  final Color? iconForegroundColor;

  /// Optional callback when tapped
  final VoidCallback? onTap;

  const StatCard({
    required this.icon,
    required this.title,
    required this.value,
    this.subtitle,
    this.iconColor,
    this.iconForegroundColor,
    this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final bgColor = iconColor ?? colorScheme.primaryContainer;
    final fgColor = iconForegroundColor ?? colorScheme.onPrimaryContainer;

    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8.0),
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    child: Icon(icon, color: fgColor, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          value,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 8),
                Text(
                  subtitle!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A compact stat card for use in grids
class CompactStatCard extends StatelessWidget {
  /// The icon to display
  final IconData icon;

  /// The title/label for this stat
  final String title;

  /// The main value to display
  final String value;

  /// Color for the icon
  final Color? iconColor;

  const CompactStatCard({
    required this.icon,
    required this.title,
    required this.value,
    this.iconColor,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: iconColor ?? colorScheme.primary, size: 28),
            const SizedBox(height: 8),
            Text(
              value,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
