// Grace-window checkpoint credit for consecutive commitments (Plan 2,
// Task 8).
//
// A consecutive commitment's anchor dates admit completions made inside the
// pack's grace windows (e.g. a First Saturday confession made within 8 days
// of the anchor, the engine's `GraceWindow.admits`). This service turns a
// pack's completion records (`ProgressState.completedItemsByDay`, keyed by
// the engine's documented `<item>:<yyyy-mm-dd>` convention) into per-anchor
// checkpoint credits: which completion date satisfies which grace-window
// item for which anchor — the map the Task 9 ProgressService consumes to
// judge anchors fulfilled.
//
// Shape of the service (documented choice): `creditCheckpointsForAnchors`
// is the authoritative evaluation — it resolves ALL anchors of one
// evaluation together, because the first-come credit lock is a
// CROSS-ANCHOR rule the pinned single-anchor signature cannot see. One
// confession made between two First Saturdays must credit exactly the
// nearer anchor; evaluated one anchor at a time, both would claim it.
// `creditCheckpoints` (the pinned Task 9 interface, one anchor per call,
// `Map<String, DateTime>` item → credited completion date) is the
// one-anchor view of the same computation. Callers evaluating a whole
// commitment (anchors resolved out of `spec.anchor`) MUST go through
// `creditCheckpointsForAnchors` to get locked credits; the per-anchor
// signature is for callers that genuinely hold a single anchor in scope.
//
// What the service credits — the "required items" question: the spec's
// GraceWindow list is the ONLY item-keyed shape on
// `ConsecutiveCommitmentSpec` (the engine has no required/optional item
// concept there; `CheckpointStep.requiredForCompletion` lives in the pack
// session script, outside this service's inputs). The service therefore
// credits exactly the spec's grace-window items and nothing else: anchor-day
// items without a window (First-Saturday communion, the rosary) are exact-
// anchor-day completions whose credit is the session layer's concern. A
// window item missing from the returned map is unsatisfied; the map never
// invents entries.
//
// Resolution rules (all deterministic, pinned by the tests):
//
// 1. Exact-day first: a completion keyed `'<item>:<anchor's own yyyy-mm-dd>'`
//    claims that anchor's slot for the item (the pinned "exact-day
//    completion by that key" path), even when a date-earlier in-window
//    completion also exists.
// 2. Every other completion of a window item is then resolved greedily in
//    first-come date order (earliest completion first; ties broken by item
//    name): it locks to the NEAREST anchor with an empty slot whose window
//    admits it, tie → the earlier anchor. The nearest-empty-slot choice is
//    what routes a second confession to the farther First Saturday after
//    the first locked the nearer one.
// 3. The lock is per completion record (item + completion date): once a
//    completion credits an anchor it can never credit a second anchor, and
//    a filled slot takes no further completions — a completion admitting
//    only filled slots stays uncredited entirely.
// 4. Keys not matching the zero-padded `<item>:<yyyy-mm-dd>` convention are
//    ignored (progress keys are app-authored; a malformed key must never
//    throw or invent a credit).
//
// Pinned date-only discipline, as in the engine: anchor and completion
// dates are reduced to local midnights (`DateTime(year, month, day)`) and
// compared by whole calendar days, never by time-of-day or a UTC rendering;
// day differences use the UTC-re-anchored difference (mirroring the
// engine's private `ScheduleSpec._wholeCalendarDays`) so DST transitions
// cannot shift a window edge. The service is pure: no clock reads, no
// "today" — callers pass anchors resolved through the current date and
// completions recorded through it (the engine's evaluation already ignores
// completions dated after today).
library;

import 'package:sancta_via_devotional_engine/sancta_via_devotional_engine.dart';

/// Zero-padded `yyyy-mm-dd` shape for a progress key's date remainder.
final RegExp _dayShape = RegExp(r'^\d{4}-\d{2}-\d{2}$');

/// Static grace-window checkpoint credit for [ConsecutiveCommitmentSpec]
/// schedules.
class GraceWindowService {
  const GraceWindowService._();

  /// The checkpoint credits for ONE anchor of [spec]: checkpoint item →
  /// the completed date crediting it for [anchor], resolved from
  /// [completedItemsByDay] (keys `'<item>:<yyyy-mm-dd>'`, the engine's
  /// documented completion-key convention). Only the spec's grace-window
  /// items can appear — a missing entry is an unsatisfied checkpoint.
  ///
  /// This is the pinned single-anchor view: stateless per call, so it
  /// carries no cross-anchor lock. Evaluating several anchors of one
  /// commitment with this signature would let one in-window completion
  /// credit two anchors — resolve the commitment's anchors together with
  /// [creditCheckpointsForAnchors] and read one anchor's entry from that
  /// map instead.
  ///
  /// [anchor] is judged date-only (its local calendar components, reduced
  /// to a local midnight); the returned dates are local midnights too —
  /// the exact-day credit is [anchor]'s own date, a window-only credit is
  /// the completion's date.
  static Map<String, DateTime> creditCheckpoints({
    required ConsecutiveCommitmentSpec spec,
    required DateTime anchor,
    required Map<String, String> completedItemsByDay,
  }) {
    final DateTime anchorDate = _dateOnly(anchor);
    return creditCheckpointsForAnchors(
          spec: spec,
          anchors: <DateTime>[anchorDate],
          completedItemsByDay: completedItemsByDay,
        )[anchorDate] ??
        const <String, DateTime>{};
  }

  /// The checkpoint credits for ALL of [anchors] of [spec] under the
  /// first-come credit lock: anchor → (checkpoint item → the completion
  /// date crediting it for that anchor). Every requested anchor has an
  /// entry (empty when nothing credits it — unsatisfied checkpoints are
  /// exactly the absent entries). Duplicate anchors collapse; the map is
  /// keyed by the anchors' local-midnight dates and returned unmodifiable,
  /// as are the per-anchor maps.
  ///
  /// The resolution is the two-phase documented rule (exact-day claims,
  /// then first-come greedy date order to the nearest empty-slot admitting
  /// anchor, ties to the earlier anchor) — see the library docs.
  ///
  /// Callers resolve [anchors] out of `spec.anchor`'s due dates themselves
  /// (the service does not walk the calendar); [completedItemsByDay] is the
  /// pack's completion records keyed `'<item>:<yyyy-mm-dd>'`, whose
  /// non-conforming keys are ignored.
  static Map<DateTime, Map<String, DateTime>> creditCheckpointsForAnchors({
    required ConsecutiveCommitmentSpec spec,
    required List<DateTime> anchors,
    required Map<String, String> completedItemsByDay,
  }) {
    // Normalize and dedupe the anchors, ascending: date-only local
    // midnights, compared by calendar day — never a UTC rendering.
    final Map<DateTime, bool> seenAnchors = <DateTime, bool>{};
    final List<DateTime> orderedAnchors = <DateTime>[];
    for (final DateTime anchor in anchors) {
      final DateTime normalized = _dateOnly(anchor);
      if (!seenAnchors.containsKey(normalized)) {
        seenAnchors[normalized] = true;
        orderedAnchors.add(normalized);
      }
    }
    orderedAnchors.sort((DateTime a, DateTime b) => a.compareTo(b));

    // The result scaffold: every requested anchor present, empty until
    // credited — an absent entry always means "unsatisfied", never "not
    // evaluated".
    final Map<DateTime, Map<String, DateTime>> credited =
        <DateTime, Map<String, DateTime>>{
          for (final DateTime anchor in orderedAnchors)
            anchor: <String, DateTime>{},
        };

    // The spec's grace-window items — the only checkpoint items this
    // service credits (see the library docs on required/optional).
    final Map<String, List<GraceWindow>> windowsByItem =
        <String, List<GraceWindow>>{};
    for (final GraceWindow window in spec.windows) {
      windowsByItem.putIfAbsent(window.item, () => <GraceWindow>[]).add(window);
    }
    if (orderedAnchors.isEmpty || windowsByItem.isEmpty) {
      return _unmodifiableCredits(credited);
    }

    // The completions that could ever credit an anchor: per window item,
    // the completion dates parsed out of the `<item>:<yyyy-mm-dd>` keys.
    // Keys for other items (no spec window), for empty items, or with a
    // non-conforming date remainder are ignored.
    final Map<String, Set<DateTime>> completionsByItem =
        <String, Set<DateTime>>{};
    for (final MapEntry<String, String> entry in completedItemsByDay.entries) {
      final (String item, DateTime day)? completion = _parseCompletionKey(
        entry.key,
      );
      if (completion == null) {
        continue;
      }
      if (!windowsByItem.containsKey(completion.$1)) {
        continue;
      }
      completionsByItem
          .putIfAbsent(completion.$1, () => <DateTime>{})
          .add(completion.$2);
    }

    // Phase 1 — exact-day claims: a completion keyed with an anchor's own
    // zero-padded date claims that anchor's slot for the item and is
    // consumed (it can never credit a second anchor).
    final List<String> windowItems = windowsByItem.keys.toList()..sort();
    for (final DateTime anchor in orderedAnchors) {
      for (final String item in windowItems) {
        if (completedItemsByDay.containsKey('$item:${_stamp(anchor)}')) {
          credited[anchor]![item] = anchor;
          completionsByItem[item]?.remove(anchor);
        }
      }
    }

    // Phase 2 — first-come greedy resolution in date order: each remaining
    // completion locks to the nearest anchor with an empty slot whose
    // window admits it (ties → the earlier anchor; admission is the
    // engine's own GraceWindow.admits).
    final List<(String, DateTime)> pending = <(String, DateTime)>[];
    for (final MapEntry<String, Set<DateTime>> entry
        in completionsByItem.entries) {
      for (final DateTime day in entry.value) {
        pending.add((entry.key, day));
      }
    }
    pending.sort(((String, DateTime) a, (String, DateTime) b) {
      final int byDay = a.$2.compareTo(b.$2);
      if (byDay != 0) {
        return byDay;
      }
      return a.$1.compareTo(b.$1);
    });

    for (final (String, DateTime) completion in pending) {
      final String item = completion.$1;
      final DateTime completed = completion.$2;
      final List<GraceWindow> windows = windowsByItem[item]!;
      DateTime? nearest;
      int nearestDistance = 0;
      for (final DateTime anchor in orderedAnchors) {
        if (credited[anchor]!.containsKey(item)) {
          continue; // The anchor's slot for this item is already filled.
        }
        final bool admitted = windows.any(
          (GraceWindow window) => window.admits(anchor, completed),
        );
        if (!admitted) {
          continue;
        }
        final int distance = _wholeCalendarDays(completed, anchor).abs();
        if (nearest == null || distance < nearestDistance) {
          nearest = anchor;
          nearestDistance = distance;
        }
      }
      // No empty-slot anchor admits the completion: it stays uncredited —
      // the lock means it can never be reconsidered for another anchor.
      if (nearest != null) {
        credited[nearest]![item] = completed;
      }
    }

    return _unmodifiableCredits(credited);
  }

  /// Parses one completion key into its item and date-only completion
  /// date, or null when the key does not follow the zero-padded
  /// `<item>:<yyyy-mm-dd>` convention (the item may be any non-empty text
  /// before the first colon; the remainder must be exactly a zero-padded
  /// local date — `DateTime.parse` of that shape yields the local
  /// midnight).
  static (String, DateTime)? _parseCompletionKey(String key) {
    final int separator = key.indexOf(':');
    if (separator <= 0) {
      return null;
    }
    final String rawDay = key.substring(separator + 1);
    if (!_dayShape.hasMatch(rawDay)) {
      return null;
    }
    final DateTime parsed;
    try {
      parsed = DateTime.parse(rawDay);
    } on FormatException {
      // The shape regexp cannot reject a non-calendar date like
      // 2026-99-99: DateTime.parse does, and such a key carries no credit.
      return null;
    }
    return (key.substring(0, separator), _dateOnly(parsed));
  }

  /// Reduces [d] to a local midnight date (a `DateTime(year, month, day)`
  /// construction), preserving the local calendar components — the engine's
  /// date-only discipline for every date crossing this service.
  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  /// The zero-padded `yyyy-mm-dd` rendering of the local date [d] — the
  /// exact-day completion-key convention.
  static String _stamp(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  /// Counts whole calendar days between local midnight date-only values,
  /// immune to DST shifts — mirrors the engine's private
  /// `ScheduleSpec._wholeCalendarDays`: the UTC re-anchoring exists only
  /// so the difference is exact; no local-time meaning is ever converted.
  static int _wholeCalendarDays(DateTime start, DateTime end) {
    return DateTime.utc(
      end.year,
      end.month,
      end.day,
    ).difference(DateTime.utc(start.year, start.month, start.day)).inDays;
  }

  /// Wraps the resolved credits in unmodifiable maps (outer and per-anchor).
  static Map<DateTime, Map<String, DateTime>> _unmodifiableCredits(
    Map<DateTime, Map<String, DateTime>> credited,
  ) {
    return Map<DateTime, Map<String, DateTime>>.unmodifiable(
      <DateTime, Map<String, DateTime>>{
        for (final MapEntry<DateTime, Map<String, DateTime>> entry
            in credited.entries)
          entry.key: Map<String, DateTime>.unmodifiable(entry.value),
      },
    );
  }
}
