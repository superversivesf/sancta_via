// The attribution bottom sheet for the session player (Plan 2, Task 11).
//
// Pack content carries its source/license metadata on every prayer text
// (Plan-1 packs ship it byte-for-byte); the sheet lists the attribution of
// the text the player has VIEWED so far — the steps walked up to and
// including the current one, de-duplicated by prayer id in appearance
// order. [showAttributionSheet] is the open action the player's app bar
// carries; [attributionEntriesFor] is the pure collector the screen hands
// it (and the seam a later review round pins if new step types appear —
// the sealed switch there stays exhaustive).
library;

import 'package:flutter/material.dart';
import 'package:sancta_via_devotional_engine/sancta_via_devotional_engine.dart';

/// One viewed text's attribution row.
class AttributionEntry {
  /// Creates an entry for the prayer [prayerId].
  const AttributionEntry({
    required this.prayerId,
    required this.source,
    required this.license,
  });

  /// The prayer text's id (its content key in the pack).
  final String prayerId;

  /// The text's source attribution.
  final String source;

  /// The text's license.
  final String license;
}

/// The attribution entries of [script]'s steps 0..[throughStepIndex]
/// (inclusive), de-duplicated by prayer id in appearance order.
///
/// A `throughStepIndex` outside the script's bounds yields every step's
/// entries (the completed walk's case).
List<AttributionEntry> attributionEntriesFor(
  SessionScript script,
  int throughStepIndex,
) {
  final Map<String, AttributionEntry> entries = <String, AttributionEntry>{};
  for (int i = 0; i < script.steps.length; i++) {
    if (i > throughStepIndex) {
      break;
    }
    for (final PrayerText text in _viewedTexts(script.steps[i])) {
      entries.putIfAbsent(
        text.id,
        () => AttributionEntry(
          prayerId: text.id,
          source: text.source,
          license: text.license,
        ),
      );
    }
  }
  return entries.values.toList();
}

/// The prayer texts [step] displays, in render order.
Iterable<PrayerText> _viewedTexts(SessionStep step) {
  return switch (step) {
    PrayerStep(:final PrayerText text) => <PrayerText>[text],
    VerseStep(:final PrayerText? closing) =>
      closing == null ? const <PrayerText>[] : <PrayerText>[closing],
    ReflectionStep(:final PrayerText? text) =>
      text == null ? const <PrayerText>[] : <PrayerText>[text],
    RepetitionStep(:final PrayerText text) => <PrayerText>[text],
    CheckpointStep() ||
    IntercessionStep() ||
    BeadGroupStep() ||
    LitanyStep() => const <PrayerText>[],
  };
}

/// Opens the attribution sheet for [entries].
///
/// The sheet lists each viewed text's id, source, and license; without any
/// viewed text it says so honestly (the verses of the Angelus, for one,
/// carry no attributed content).
Future<void> showAttributionSheet(
  BuildContext context,
  List<AttributionEntry> entries,
) {
  return showModalBottomSheet<void>(
    context: context,
    builder: (BuildContext sheetContext) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
              child: Row(
                children: <Widget>[
                  Text(
                    'Attribution',
                    style: Theme.of(sheetContext).textTheme.titleMedium,
                  ),
                  const Spacer(),
                  IconButton(
                    key: const Key('session_attribution_close'),
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(sheetContext).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            if (entries.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('No attributed prayer text has been viewed yet.'),
              )
            else
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: <Widget>[
                    for (final AttributionEntry entry in entries)
                      ListTile(
                        title: Text(entry.prayerId),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(entry.source),
                            Text(entry.license),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      );
    },
  );
}
