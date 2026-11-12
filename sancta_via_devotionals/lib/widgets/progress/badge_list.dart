// The badges list (Plan 2, Task 16): one program's dated completion entries.
//
// Badges are the engine's `BadgeRecord` history — one badge per finished
// session is the completion writer's own rule (Task 9), and badges survive
// strict resets (the ruled reset keeps the history), so this list is the
// user's lifetime record: the header's lifetime count is exactly the sum of
// these lengths, documented at [ProgressAssembly]. Entries render the
// record's own data — its title and its local calendar date as the
// zero-padded `yyyy-mm-dd` stamp (the house date discipline).
library;

import 'package:flutter/material.dart';
import 'package:sancta_via_devotional_engine/sancta_via_devotional_engine.dart'
    show BadgeRecord;

/// The zero-padded `yyyy-mm-dd` rendering of a local badge date.
String badgeStamp(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// The dated badge entries of one program's progress.
///
/// An empty [badges] renders [emptyText] (the honest nothing-yet state)
/// instead of an empty section.
class BadgeList extends StatelessWidget {
  /// Creates the list.
  const BadgeList({
    required this.badges,
    this.emptyText = 'No completions yet.',
    super.key,
  });

  /// The program's earned badges, in earning order (the state's own order).
  final List<BadgeRecord> badges;

  /// The empty-state text.
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    if (badges.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text(emptyText, style: theme.textTheme.bodySmall),
      );
    }
    return Column(
      children: <Widget>[
        for (int i = 0; i < badges.length; i++)
          ListTile(
            key: ValueKey<String>('badge_${i}_${badgeStamp(badges[i].date)}'),
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              Icons.workspace_premium_outlined,
              size: 20,
              color: theme.colorScheme.primary,
            ),
            title: Text(badges[i].title, style: theme.textTheme.bodyMedium),
            trailing: Text(
              badgeStamp(badges[i].date),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }
}
