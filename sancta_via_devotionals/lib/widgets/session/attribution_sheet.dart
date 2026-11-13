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
//
// Task-23 fix round 1: a LitanyStep's invocation list has no per-line
// license slot in the engine, so a litany pack records its text's source
// and license at the pack level (reminders.schedule_note). With the pack
// passed, the collector adds ONE pack-level provenance row, keyed to the
// pack id, whenever the viewed set contains a litany step, so the sheet
// renders the litany text's attribution too.
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
///
/// With [pack] supplied, a viewed `LitanyStep` adds the pack's OWN litany
/// attribution: one [AttributionEntry] keyed to the pack id, sourced from
/// `reminders.schedule_note` (`invocation_source` / `invocation_license`).
/// That pack-level record carries the invocation text, which the engine's
/// step fields cannot license per line. Packs without such a note (and the
/// pack-less caller) contribute no row: the collector never invents
/// attribution data.
List<AttributionEntry> attributionEntriesFor(
  SessionScript script,
  int throughStepIndex, {
  ContentPack? pack,
}) {
  final Map<String, AttributionEntry> entries = <String, AttributionEntry>{};
  final AttributionEntry? litanyEntry = _litanyAttribution(pack);
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
    if (script.steps[i] is LitanyStep && litanyEntry != null) {
      entries.putIfAbsent(litanyEntry.prayerId, () => litanyEntry);
    }
  }
  return entries.values.toList();
}

/// The pack-level attribution of [pack]'s litany text, or null when the
/// pack ships none: the record lives in `reminders.schedule_note` under
/// `invocation_source` / `invocation_license`, and a missing or empty
/// field means the collector renders nothing rather than guessing.
AttributionEntry? _litanyAttribution(ContentPack? pack) {
  if (pack == null) {
    return null;
  }
  final Object? note = pack.reminders['schedule_note'];
  if (note is! Map<String, dynamic>) {
    return null;
  }
  final Object? sourceText = note['invocation_source'];
  final Object? licenseText = note['invocation_license'];
  if (sourceText is! String ||
      sourceText.isEmpty ||
      licenseText is! String ||
      licenseText.isEmpty) {
    return null;
  }
  return AttributionEntry(
    prayerId: pack.id,
    source: sourceText,
    license: licenseText,
  );
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
