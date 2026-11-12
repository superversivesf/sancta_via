// The series day's phase banner (Plan 2, Task 16).
//
// One line per series row — the day's phase label beside the day's position,
// e.g. 'Petition · day 6 of 54'. The label comes from the pack's OWN day
// variant data (`VariantService.dayVariant` keyed on the series schedule's
// day index — nothing is hardcoded in the app); the position reading mirrors
// the session player's own day resolution, so the banner and the player
// always describe the same day. The consecration and the 54-day novena are
// the shipped shapes with phase-labelled variants.
library;

import 'package:flutter/material.dart';

/// The phase banner of a series program's day: `<phase> · day <n> of <m>`.
///
/// [phase] is the capitalized phase label resolved from the pack's variant
/// (the provider resolves it — this widget stays presentation-only); the
/// position is [dayIndex] of [lengthDays].
class PhaseBanner extends StatelessWidget {
  /// Creates the banner.
  const PhaseBanner({
    required this.phase,
    required this.dayIndex,
    required this.lengthDays,
    super.key,
  });

  /// The day's phase label (already capitalized).
  final String phase;

  /// The series day's 1-based index (the schedule's own resolution).
  final int dayIndex;

  /// The series' total length in days.
  final int lengthDays;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: <Widget>[
          Icon(Icons.auto_stories, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$phase · day $dayIndex of $lengthDays',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
