import 'package:flutter/material.dart';

/// One time-grouped card on the Today screen (Spec §7's Morning · Angelus
/// times · 3pm · Evening · Commitments · Upcoming Feasts).
///
/// Renders a titled header row (icon + [title]) over the [children] — the
/// screen builds the `TodayItemTile`s, the card stays presentation-only.
class TodaySectionCard extends StatelessWidget {
  /// Creates a section card.
  const TodaySectionCard({
    required this.title,
    required this.icon,
    required this.children,
    super.key,
  });

  /// The section's display title (the §7 group name).
  final String title;

  /// The section's leading icon.
  final IconData icon;

  /// The section's item tiles, already built by the screen.
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(icon, size: 20, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            ...children,
          ],
        ),
      ),
    );
  }
}
