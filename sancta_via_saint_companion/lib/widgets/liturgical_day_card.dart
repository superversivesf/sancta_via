import 'package:flutter/material.dart';
import 'package:sancta_via_liturgical_calendar/sancta_via_liturgical_calendar.dart';
import 'package:sancta_via_shared_ui/sancta_via_shared_ui.dart';

/// A compact card describing today's liturgical celebration.
///
/// Renders nothing ([SizedBox.shrink]) when [day] is null; otherwise shows
/// the celebration name, its rank label, and a colored dot taken from the
/// celebration's liturgical color.
class LiturgicalDayCard extends StatelessWidget {
  const LiturgicalDayCard({required this.day, super.key});

  /// Today's liturgical day, or null when the calendar has no answer.
  final LiturgicalDayData? day;

  @override
  Widget build(BuildContext context) {
    final LiturgicalDayData? data = day;
    if (data == null) {
      return const SizedBox.shrink();
    }
    // Maps the celebration's color code (e.g. 'RED') onto the shared
    // liturgical palette, with a safe default for unknown codes.
    final Color dotColor = data.celebration.color.toLiturgicalColor();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: <Widget>[
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    data.celebration.name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    data.celebration.rankEnum.displayName,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
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
