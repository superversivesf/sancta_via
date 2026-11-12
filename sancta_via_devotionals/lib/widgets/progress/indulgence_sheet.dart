// The indulgence conditions sheet (Plan 2, Task 16).
//
// A STATIC explainer — the Church's general conditions for gaining a plenary
// indulgence, shown as a checklist, plus the one-per-day plenary cap note.
// Nothing here is stateful and nothing is per-pack: the sheet explains what
// the user's devout work asks for every time. (Which item carries which
// grace-window in a specific pack is that pack's own business — the detail
// screen explains its windows; this sheet is the general norm.)
library;

import 'package:flutter/material.dart';

/// The general conditions for gaining a plenary indulgence (the classic
/// norms), one per checklist row.
const List<String> indulgenceConditions = <String>[
  'Perform the indulgenced work (this devotion) while in a state of grace.',
  'Receive sacramental confession in the days surrounding the work.',
  'Receive Holy Communion.',
  'Pray for the intentions of the Supreme Pontiff (one Our Father and one '
      'Hail Mary suffice, or any other prayer of one\'s choice).',
  'Be fully detached from attachment to all sin, even venial.',
];

/// The one-per-day plenary cap note (the Church's own norm).
const String indulgenceDailyCap =
    'Church norms grant a plenary indulgence at most once per day; any '
    'further devout work on the same day gains a partial indulgence.';

/// Opens the static conditions checklist as a modal bottom sheet.
Future<void> showIndulgenceSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (BuildContext context) {
      final ThemeData theme = Theme.of(context);
      return SafeArea(
        child: Container(
          key: const Key('indulgence_sheet'),
          constraints: const BoxConstraints(maxHeight: 520),
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Icon(
                      Icons.church_outlined,
                      size: 22,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Indulgence conditions',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      key: const Key('close_indulgence_sheet'),
                      icon: const Icon(Icons.close),
                      tooltip: 'Close',
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Column(
                  key: const Key('indulgence_conditions'),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    for (final String condition in indulgenceConditions)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Icon(
                              Icons.check_box_outline_blank,
                              size: 18,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                condition,
                                style: theme.textTheme.bodyMedium,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    indulgenceDailyCap,
                    key: const Key('indulgence_daily_cap'),
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
