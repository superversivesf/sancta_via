// Missed-day flow and the session-completion writer (Plan 2, Task 9).
//
// Two app-layer contracts live here; every decision they consume is the
// engine's:
//
// 1. **The missed-day flow** (Review Focus 6). [ProgressService.missedVerdict]
//    is the engine's `MissedDayEvaluator.evaluateTyped` over the PERSISTED
//    progress (the state's own `lastFulfilled`), so `askUser` surfaces before
//    anything new lands, and [ProgressService.applyMissedDay] applies only a
//    decided verdict: `reset` zeroes the streak (`fulfilledOrdinals` and
//    `lastFulfilled`) while keeping the earned badge history — badges are
//    dated completions, not streak state, and the lifetime count is their
//    count — `resume` keeps the state untouched, and `askUser` is refused: it
//    is the user's choice to make, never a verdict the service may apply on
//    its own. The evaluator is scoped to DAILY-cadence series (the engine's
//    documented cadence guard): anchor-recurring commitments must be driven by
//    `CommitmentState` through [ProgressService.persistCompletion], never by
//    this verdict.
//
// 2. **The checkpoint gate** — Plan-2 contract (a). [ProgressService
//    .completeSession] runs after `SessionRunner` has walked the script and
//    finalizes the completion only when every `CheckpointStep` with
//    `requiredForCompletion: true` is present and true in the session's
//    checkpoint map. Otherwise the PRE-FINAL `SessionState` comes back
//    unchanged and nothing is persisted: the player keeps the walked session
//    and renders what is missing (see [ProgressService.missingRequiredItems]).
//
// [ProgressService.persistCompletion] derives the next `ProgressState` and
// saves it. Two separate questions are answered by two separate authorities,
// and they must not be conflated:
//
// * **The ordinal is streak arithmetic.** Every finished session advances the
//   persisted streak by one (`persisted.fulfilledOrdinals + 1`) — the same
//   position `DueToday.schedule.ordinal` reports, which the program providers
//   document as the persisted streak plus one. A caller's claimed progress
//   therefore advances one position per completion even when no completion
//   records exist (e.g. a pack claimed during onboarding).
// * **Anchor fulfillment is the item composition**, exposed as
//   [ProgressService.fulfilledAnchorDates]: which past anchor dates the
//   completion records actually satisfy, from the union of the two rules the
//   engine and Task 8's service split between them:
//
//   - grace-window items (e.g. the First Saturdays confession, ±8 days) are
//     credited by `GraceWindowService.creditCheckpointsForAnchors` — the
//     multi-anchor evaluation, because the per-anchor view would let one
//     in-window completion credit two overlapping anchors;
//   - anchor-day items (e.g. First Saturdays communion, First Fridays
//     communion) get NO credit from that service, exactly as the engine's own
//     anchor-day rule has it: they count only when their
//     `<item>:<yyyy-mm-dd anchor>` record exists.
//
//   An anchor is fulfilled when every checkpoint item of the pack's session is
//   satisfied that way; packs whose session declares no checkpoint fall back
//   to the engine's documented date rule (the anchor day completed, or a
//   grace window admitting a completion date). This composition is what the
//   app surfaces (the player can warn that a session completes while its
//   anchor still asks for an item; the progress surface shows the credit); it
//   never rewrites the stored ordinal. Corrections to a streak that fell behind
//   its true position — a gap under a strict policy — are
//   [ProgressService.applyMissedDay]'s job.
//
// Date discipline: local midnights only, as everywhere in the engine — dates
// are reduced with `DateTime(year, month, day)` and rendered zero-padded, and
// the grace-window service's maps are keyed on exactly those normalized local
// midnights (they are looked up through the same normalization, never by raw
// `DateTime` identity from another source). Completions dated AFTER the
// evaluation day are filtered out before any evaluation: the engine ignores
// them (`commitment_state.dart`: completions dated after `today` are dropped
// at the normalize step) and the grace-window service does no filtering of
// its own, so this service does it once, before both.
library;

import 'package:sancta_via_devotional_engine/sancta_via_devotional_engine.dart';
import 'package:sancta_via_devotional_engine_riverpod/sancta_via_devotional_engine_riverpod.dart'
    show ProgramRepository;

import '../utils/logger.dart';
import 'grace_window_service.dart';

/// Reduces [d] to a local midnight date (a `DateTime(year, month, day)`
/// construction), preserving the local calendar components — the engine's
/// date-only discipline.
DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// The zero-padded `yyyy-mm-dd` rendering of the local date [d] — the
/// engine's documented `completedItemsByDay` key convention.
String _stamp(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// The zero-padded `yyyy-mm-dd` shape a completion key's date remainder must
/// carry — the convention the engine documents and the grace-window service
/// reads.
final RegExp _dayShape = RegExp(r'^\d{4}-\d{2}-\d{2}$');

/// The local-midnight date of one `<item>:<yyyy-mm-dd>` completion key, or
/// null when the key does not follow that convention (progress keys are
/// app-authored: a malformed key must never throw, and it carries no date).
DateTime? _completionDay(String key) {
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
    // The shape regexp cannot reject a non-calendar date like 2026-99-99.
    return null;
  }
  return _dateOnly(parsed);
}

/// Whether [key] carries a completion date on or before [day]. Keys without a
/// readable date are kept: no evaluation reads them, so dropping them would
/// only lose history.
bool _isOnOrBefore(String key, DateTime day) {
  final DateTime? completed = _completionDay(key);
  return completed == null || !completed.isAfter(day);
}

/// The missed-day flow and the session-completion writer for devotional
/// packs.
///
/// The service is stateless except for the [repository] it reads and writes
/// through: the missed-day verdict and the checkpoint gate are pure
/// decisions, and only [applyMissedDay], [completeSession] and
/// [persistCompletion] touch the store. No provider is consulted here — the
/// missed-day policy arrives as the engine's own policy string, so a caller
/// passes the app setting (`missedDayDefaultPolicyProvider`) itself.
class ProgressService {
  /// Creates a [ProgressService] over [repository] (the app's
  /// `SqliteProgramRepository`, or a test double).
  const ProgressService({required this.repository});

  /// The store the service reads progress from and writes it to.
  final ProgramRepository repository;

  /// The missed-day verdict for [state] when [today] is its next due date,
  /// under the pack's missed-day [policy] (`'strict'` or `'permissive'`).
  ///
  /// A pure decision delegating to `MissedDayEvaluator.evaluateTyped`, with
  /// the policy string resolved to its enum form here (an unknown policy
  /// throws an [ArgumentError], never a silent default):
  ///
  /// * `askUser` surfaces first when the state holds no fulfilled ordinals
  ///   (nothing to continue or reset) — the engine's own rule, and it wins
  ///   over the policy;
  /// * a state with nothing fulfilled at all (null, or no `lastFulfilled`)
  ///   also reads `askUser`: there is no last fulfilled date to measure a gap
  ///   from;
  /// * otherwise the policy decides: `'strict'` yields `reset` across a gap
  ///   and `'permissive'` always `resume` (dates on or before the last
  ///   fulfilled date are never a gap).
  ///
  /// The verdict is measured against [ProgressState.lastFulfilled] — the
  /// PERSISTED last fulfilled date — so it must be read before any of
  /// today's completions land (Review Focus 6).
  static MissedDayVerdict missedVerdict(
    ProgressState? state,
    String policy,
    DateTime today,
  ) {
    final RestartPolicy restartPolicy = _restartPolicy(policy);
    final DateTime? lastFulfilled = state?.lastFulfilled;
    if (state == null || lastFulfilled == null) {
      return MissedDayVerdict.askUser;
    }
    return MissedDayEvaluator.evaluateTyped(
      policy: restartPolicy,
      state: state,
      lastFulfilled: lastFulfilled,
      nextDue: _dateOnly(today),
    );
  }

  /// Applies a decided missed-day [verdict] to the persisted progress of
  /// [packId].
  ///
  /// * [MissedDayVerdict.reset] zeroes the streak: `fulfilledOrdinals` 0,
  ///   `lastFulfilled` null and `repetitionsToday` 0 — a void streak keeps
  ///   none of its positions. The earned badges are KEPT, as are the
  ///   completion records: badges are the dated completion history the
  ///   lifetime count is built from (the design separates `badgeHistory[]`
  ///   from the streak), and `completedItemsByDay` is raw history the
  ///   engine's own strict evaluation reproduces the reset from, so neither
  ///   can resurrect the voided series.
  /// * [MissedDayVerdict.resume] keeps the state untouched and writes
  ///   nothing.
  /// * [MissedDayVerdict.askUser] throws an [ArgumentError]: the user has not
  ///   chosen, so no new progress may land — the caller must surface the
  ///   choice first.
  ///
  /// A pack with no persisted progress has nothing to apply, so the call is a
  /// no-op.
  Future<void> applyMissedDay({
    required String packId,
    required MissedDayVerdict verdict,
  }) async {
    if (verdict == MissedDayVerdict.askUser) {
      throw ArgumentError.value(
        verdict,
        'verdict',
        'askUser is the user\'s decision to make: surface it before '
            'applying a missed-day verdict',
      );
    }
    final ProgressState? progress = await repository.progressFor(packId);
    if (progress == null) {
      AppLogger.debug(
        'No persisted progress for "$packId" — nothing to apply a '
            '${verdict.name} verdict to',
        'PROGRESS',
      );
      return;
    }
    if (verdict == MissedDayVerdict.resume) {
      AppLogger.debug(
        'Missed-day verdict resume keeps "$packId" at ordinal '
            '${progress.fulfilledOrdinals}',
        'PROGRESS',
      );
      return;
    }
    final ProgressState reset = ProgressState(
      packId: packId,
      completedItemsByDay: progress.completedItemsByDay,
      badges: progress.badges,
    );
    await repository.saveProgress(reset);
    AppLogger.info(
      'Missed-day verdict reset zeroed "$packId" '
          '(was ordinal ${progress.fulfilledOrdinals}, now 0; '
          '${progress.badges.length} earned badges kept)',
      'PROGRESS',
    );
  }

  /// The items of [pack]'s session whose `CheckpointStep` is
  /// `requiredForCompletion: true` and whose checkpoint is not present and
  /// true in [checkpointStates], in script order.
  ///
  /// An empty list means the checkpoint gate is satisfied — the player also
  /// uses this list to render what is missing while a session stays
  /// incomplete.
  static List<String> missingRequiredItems(
    ContentPack pack,
    Map<String, bool> checkpointStates,
  ) {
    final List<String> items = <String>[];
    for (final SessionStep step in pack.session.steps) {
      if (step is CheckpointStep &&
          step.requiredForCompletion &&
          checkpointStates[step.item] != true &&
          !items.contains(step.item)) {
        items.add(step.item);
      }
    }
    return List<String>.unmodifiable(items);
  }

  /// Finalizes the walk of [pack]'s session and, on success, persists it.
  ///
  /// [state] is the session state `SessionRunner` left after walking the
  /// script. The completion is finalizable only when BOTH hold:
  ///
  /// 1. the walk is finished (`state.isComplete`), and
  /// 2. every `CheckpointStep` with `requiredForCompletion: true` is present
  ///    and true in [checkpointStates] (see [missingRequiredItems]).
  ///
  /// Otherwise the PRE-FINAL state is returned UNCHANGED and nothing is
  /// written — Plan-2 contract (a): the player keeps the walked session and
  /// shows what is missing. On success [persistCompletion] derives and saves
  /// the next progress state from [completedItemsByDay] (the session's
  /// completion records for the pack, layered over the persisted ones) and
  /// [today] (the completion's date), and the same state comes back for the
  /// player to leave.
  ///
  /// The returned state is therefore always the state the player must keep;
  /// whether the completion was finalized is observable through
  /// [missingRequiredItems] (and through the progress the call wrote).
  Future<SessionState> completeSession({
    required SessionState state,
    required ContentPack pack,
    required Map<String, bool> checkpointStates,
    required Map<String, String> completedItemsByDay,
    required DateTime today,
  }) async {
    if (state.scriptId != pack.session.id) {
      throw ArgumentError(
        'session state runs "${state.scriptId}", not the pack\'s script '
        '"${pack.session.id}"',
      );
    }
    if (!state.isComplete) {
      AppLogger.debug(
        'Session of "${pack.id}" has not walked every step '
            '(${state.stepIndex} of ${state.stepCount}) — completion is not '
            'finalizable yet',
        'PROGRESS',
      );
      return state;
    }
    final List<String> missing = missingRequiredItems(pack, checkpointStates);
    if (missing.isNotEmpty) {
      AppLogger.info(
        'Session of "${pack.id}" stays incomplete: required checkpoints '
            'missing (${missing.join(', ')})',
        'PROGRESS',
      );
      return state;
    }
    final ProgressState? persisted = await repository.progressFor(pack.id);
    await persistCompletion(
      pack: pack,
      progress: persisted ?? ProgressState(packId: pack.id),
      completedItemsByDay: completedItemsByDay,
      today: today,
    );
    return state;
  }

  /// Derives the next [ProgressState] for [pack] from its current [progress]
  /// and [completedItemsByDay], and saves it.
  ///
  /// [completedItemsByDay] carries the completion records of the finished
  /// session (keys `<item>:<yyyy-mm-dd>`, the engine's documented
  /// convention); they are layered over the persisted records, so passing the
  /// session's new records alone never drops history. [today] is the
  /// completion's date.
  ///
  /// Derivation:
  ///
  /// * `fulfilledOrdinals` — the persisted streak plus one
  ///   (`progress.fulfilledOrdinals + 1`), for every pack shape. This is the
  ///   pinned `DueToday.schedule.ordinal` source: the program providers
  ///   document that position as the persisted streak plus one
  ///   (`program_providers.dart`), so a finished session always advances the
  ///   streak by exactly one position — including a pack whose earlier
  ///   positions were claimed without completion records (onboarding claims).
  ///   Anchor fulfilment is NOT consulted here: it answers “which anchors the
  ///   records satisfy” ([fulfilledAnchorDates]) and never rewrites the
  ///   ordinal. A streak that fell behind its true position is corrected by
  ///   [applyMissedDay]’s reset, not by this writer.
  /// * `lastFulfilled` — [today], never earlier than the persisted
  ///   `lastFulfilled` (a backdated completion cannot move it backwards).
  /// * `repetitionsToday` — reset to 0.
  /// * `badges` — today's completion appended as a `BadgeRecord` titled with
  ///   the pack's title and dated [today]; one badge per finished session, so
  ///   the lifetime count is the badge count (Plan 2's Task 16 contract).
  /// * `completedItemsByDay` — the layered records.
  ///
  /// Only ONE write per finished session: the player routes completion
  /// through [completeSession], which calls this once. Two sessions on the
  /// same day (a routine pack anchored three times a day) append two badges
  /// with that day's date by design.
  ///
  /// Completions dated after [today] are carried in the persisted records but
  /// never evaluated ([fulfilledAnchorDates] filters them out): they cannot
  /// admit an anchor (the engine's own "ignore completions after today"
  /// convention, which the grace-window service leaves to its callers).
  Future<void> persistCompletion({
    required ContentPack pack,
    required ProgressState progress,
    required Map<String, String> completedItemsByDay,
    required DateTime today,
  }) async {
    if (progress.packId != pack.id) {
      throw ArgumentError(
        'progress is for "${progress.packId}", not the pack "${pack.id}"',
      );
    }
    final DateTime day = _dateOnly(today);
    final Map<String, String> completions = <String, String>{
      ...progress.completedItemsByDay,
      ...completedItemsByDay,
    };
    final int ordinals = progress.fulfilledOrdinals + 1;

    final DateTime? lastFulfilled = progress.lastFulfilled;
    final ProgressState next = ProgressState(
      packId: pack.id,
      fulfilledOrdinals: ordinals,
      lastFulfilled: lastFulfilled != null && lastFulfilled.isAfter(day)
          ? lastFulfilled
          : day,
      repetitionsToday: 0,
      completedItemsByDay: completions,
      badges: <BadgeRecord>[
        ...progress.badges,
        BadgeRecord(title: pack.title, date: day),
      ],
    );
    await repository.saveProgress(next);
    AppLogger.info(
      'Persisted completion of "${pack.id}": ordinal $ordinals on '
          '${_stamp(day)}',
      'PROGRESS',
    );
  }

  /// The anchor dates of [spec] that [completedItemsByDay] fulfil as of
  /// [today] — the composition of the grace-window and anchor-day rules, for
  /// callers to surface (the player can warn that a session completes while
  /// its anchor still asks for an item; the progress surface shows the
  /// credit). The written ordinal is NOT derived from this set: it is the
  /// persisted streak plus one (see [persistCompletion]).
  ///
  /// The anchors are the dates the pack's anchor spec resolves as due between
  /// the earliest completion and [today] inclusive — the same calendar walk
  /// `CommitmentState.evaluate` performs (`commitment_state.dart`) — reduced
  /// to local midnights (the returned set’s values are exactly those dates, so
  /// callers must look them up by the same normalization, never by raw
  /// `DateTime` identity).
  ///
  /// Which anchors are fulfilled:
  ///
  /// * packs whose session declares no checkpoint items fall back to the
  ///   engine’s documented date rule: the anchor day itself completed, or a
  ///   `GraceWindow` admitting one of the completion dates (the expression
  ///   `CommitmentState` applies in its own `_fulfilled`, `commitment_state.dart`);
  /// * otherwise every checkpoint item of the session must be satisfied for
  ///   the anchor: an item with a `GraceWindow` in [spec] must be credited to
  ///   it by `GraceWindowService.creditCheckpointsForAnchors` (the
  ///   authoritative multi-anchor evaluation — the per-anchor view would let
  ///   one in-window completion credit two overlapping anchors), and an item
  ///   without a window must have its exact `<item>:<yyyy-mm-dd anchor>`
  ///   record. Every checkpoint gates the anchor, not only the
  ///   `requiredForCompletion` ones: that flag is the SESSION gate (contract
  ///   (a)), while the devotion’s anchor still asks for a grace-window item
  ///   such as the First Saturdays confession.
  ///
  /// Completions dated after [today] are ignored entirely, as the engine
  /// ignores them: a future-dated grace-window completion can never admit an
  /// earlier anchor (the grace-window service leaves that filtering to its
  /// callers). Keys outside the zero-padded `<item>:<yyyy-mm-dd>` convention
  /// carry no date and never credit anything.
  static Set<DateTime> fulfilledAnchorDates({
    required ContentPack pack,
    required ConsecutiveCommitmentSpec spec,
    required Map<String, String> completedItemsByDay,
    required DateTime today,
  }) {
    final DateTime day = _dateOnly(today);
    final Map<String, String> completions = <String, String>{
      for (final MapEntry<String, String> entry in completedItemsByDay.entries)
        if (_isOnOrBefore(entry.key, day)) entry.key: entry.value,
    };
    final Set<DateTime> completedDates = <DateTime>{
      for (final String key in completions.keys)
        if (_completionDay(key) case final DateTime completed) completed,
    };
    if (completedDates.isEmpty) {
      return const <DateTime>{};
    }
    final DateTime first = completedDates.reduce(
      (DateTime a, DateTime b) => a.isBefore(b) ? a : b,
    );
    final List<DateTime> anchors = _anchorDates(spec.anchor, first, day);
    final List<String> items = _checkpointItems(pack);
    if (items.isEmpty) {
      return <DateTime>{
        for (final DateTime anchor in anchors)
          if (completedDates.contains(anchor) ||
              spec.windows.any(
                (GraceWindow window) => completedDates.any(
                  (DateTime completed) => window.admits(anchor, completed),
                ),
              ))
            anchor,
      };
    }
    final Map<DateTime, Map<String, DateTime>> credits =
        GraceWindowService.creditCheckpointsForAnchors(
          spec: spec,
          anchors: anchors,
          completedItemsByDay: completions,
        );
    final Set<String> windowedItems = <String>{
      for (final GraceWindow window in spec.windows) window.item,
    };
    return <DateTime>{
      for (final DateTime anchor in anchors)
        if (items.every((String item) {
          if (windowedItems.contains(item)) {
            // The credits map is keyed on the normalized local midnights the
            // service derives, so the lookup normalizes the same way — never
            // by raw DateTime identity.
            return credits[_dateOnly(anchor)]?.containsKey(item) ?? false;
          }
          return completions.containsKey('$item:${_stamp(anchor)}');
        }))
          anchor,
    };
  }

  /// The checkpoint items [pack]'s session declares, in script order.
  ///
  /// Every checkpoint gates its commitment's anchor — not only the ones
  /// `requiredForCompletion` marks. That flag is the SESSION gate (contract
  /// (a)): the First Saturdays pack, for example, does not require the
  /// confession checkpoint to finish the session (it may be made inside the
  /// ±8-day grace window instead) while the devotion's anchor still asks for
  /// it. The anchor rule is therefore: windowed item → grace-window credit,
  /// anchor-day item → exact-day record.
  static List<String> _checkpointItems(ContentPack pack) {
    final List<String> items = <String>[];
    for (final SessionStep step in pack.session.steps) {
      if (step is CheckpointStep && !items.contains(step.item)) {
        items.add(step.item);
      }
    }
    return items;
  }

  /// The dates in [first] through [today] (inclusive) on which [anchor]
  /// resolves as due, walked day by day — the same calendar walk
  /// `CommitmentState.evaluate` performs (`commitment_state.dart`).
  static List<DateTime> _anchorDates(
    ScheduleSpec anchor,
    DateTime first,
    DateTime today,
  ) {
    const ScheduleContext context = ScheduleContext();
    final List<DateTime> anchors = <DateTime>[];
    for (
      DateTime d = _dateOnly(first);
      !d.isAfter(today);
      d = DateTime(d.year, d.month, d.day + 1)
    ) {
      if (anchor.resolve(d, context).due) {
        anchors.add(d);
      }
    }
    return anchors;
  }

  /// Resolves the engine's policy enum for the missed-day [policy] string,
  /// throwing the engine's own [ArgumentError] shape for an unknown value.
  static RestartPolicy _restartPolicy(String policy) {
    return switch (policy) {
      'strict' => RestartPolicy.strict,
      'permissive' => RestartPolicy.permissive,
      _ => throw ArgumentError(
        'unknown missed-day policy "$policy" (expected: strict, permissive)',
      ),
    };
  }
}
