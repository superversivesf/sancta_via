// Missed-day flow and the session-completion writer (Plan 2, Task 9).
//
// Two app-layer contracts live here; every decision they consume is the
// engine's:
//
// 1. **The missed-day flow** (Review Focus 6). [ProgressService.missedVerdict]
//    is the engine's `MissedDayEvaluator.evaluateTyped` over the PERSISTED
//    progress (the state's own `lastFulfilled`), so `askUser` surfaces before
//    anything new lands, and [ProgressService.applyMissedDay] applies only a
//    decided verdict: `reset` zeroes the streak (`fulfilledOrdinals`,
//    `lastFulfilled`, and the badges the void streak earned), `resume` keeps
//    the state untouched, and `askUser` is refused — it is the user's choice
//    to make, never a verdict the service may apply on its own.
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
// saves it. For a consecutive commitment the anchor credits come from the
// union of the two rules the engine and Task 8's service split between them:
//
// * grace-window items (e.g. the First Saturdays confession, ±8 days) are
//   credited by `GraceWindowService.creditCheckpointsForAnchors` — the
//   multi-anchor evaluation, because the per-anchor view would let one
//   in-window completion credit two overlapping anchors;
// * anchor-day items (e.g. First Saturdays communion, First Fridays
//   communion) get NO credit from that service, exactly as the engine's own
//   anchor-day rule has it: they count only when their
//   `<item>:<yyyy-mm-dd anchor>` record exists.
//
// An anchor is fulfilled when every checkpoint item of the pack's session is
// satisfied that way; the resulting fulfilment dates are then handed to
// `CommitmentState.evaluate`, which owns the restart policy, the gap walk
// (strict restarts the series at a gap, permissive continues across it) and
// the last fulfilled anchor. For a pack with no checkpoint steps at all the
// engine's own date rule stands unchanged (any completion date, exact-day or
// grace-window-admitted), so no behaviour is invented for such packs.
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
  ///   `lastFulfilled` null, `repetitionsToday` 0 and no badges — a void
  ///   streak keeps none of the badges it earned. The completion records
  ///   (`completedItemsByDay`) are kept: they are raw history, and the
  ///   engine's own strict evaluation of that history reproduces the reset
  ///   (it counts only from the last gap), so keeping them cannot resurrect
  ///   the voided series.
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
    );
    await repository.saveProgress(reset);
    AppLogger.info(
      'Missed-day verdict reset zeroed "$packId" '
          '(was ordinal ${progress.fulfilledOrdinals}, now 0)',
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
  /// * `fulfilledOrdinals` — for a consecutive commitment, the engine's
  ///   `CommitmentState.evaluate` over the anchor dates fulfilled by the
  ///   union of the grace-window and anchor-day rules (see the library docs),
  ///   which also applies the pack's restart policy. The engine's evaluation
  ///   is the same position `DueToday.schedule.ordinal` reports (that
  ///   provider computes persisted ordinals + 1,
  ///   `program_providers.dart`), so this service derives it rather than
  ///   trusting a second source. Every other pack advances one position:
  ///   `progress.fulfilledOrdinals + 1`.
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
  /// never evaluated: they cannot admit an anchor (the engine's own
  /// "ignore completions after today" convention, which the grace-window
  /// service leaves to its callers).
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
    final Map<String, String> evaluated = <String, String>{
      for (final MapEntry<String, String> entry in completions.entries)
        if (_isOnOrBefore(entry.key, day)) entry.key: entry.value,
    };

    final ScheduleSpec schedule = pack.schedule;
    final int ordinals = schedule is ConsecutiveCommitmentSpec
        ? CommitmentState.evaluate(
            schedule,
            _fulfilledAnchorDates(
              pack: pack,
              spec: schedule,
              completions: evaluated,
              today: day,
            ),
            day,
          ).fulfilledOrdinals
        : progress.fulfilledOrdinals + 1;

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

  /// The anchor dates of [spec] that [completions] fulfil, for
  /// `CommitmentState.evaluate`.
  ///
  /// Every completion key's date, reduced to a local midnight. When the pack's
  /// session declares NO checkpoint steps there is no item-level rule to
  /// apply, so the completion dates are handed to the engine as they are —
  /// its own anchor-day/grace-window rule decides, unchanged.
  ///
  /// Otherwise the pack's checkpoint items gate each anchor: an item with a
  /// `GraceWindow` in [spec] must be credited to the anchor by
  /// `GraceWindowService.creditCheckpointsForAnchors` (the authoritative
  /// multi-anchor evaluation; the per-anchor view would double-count when
  /// windows overlap), and an item without a window must have its exact
  /// `<item>:<yyyy-mm-dd anchor>` record. The anchors are the dates the
  /// pack's anchor spec resolves as due between the earliest completion and
  /// [today] inclusive — the same span `CommitmentState.evaluate` walks
  /// (`commitment_state.dart`).
  Set<DateTime> _fulfilledAnchorDates({
    required ContentPack pack,
    required ConsecutiveCommitmentSpec spec,
    required Map<String, String> completions,
    required DateTime today,
  }) {
    final Set<DateTime> completedDates = <DateTime>{
      for (final String key in completions.keys)
        if (_completionDay(key) case final DateTime day) day,
    };
    final List<String> items = _checkpointItems(pack);
    if (items.isEmpty || completedDates.isEmpty) {
      return completedDates;
    }
    final DateTime first = completedDates.reduce(
      (DateTime a, DateTime b) => a.isBefore(b) ? a : b,
    );
    final List<DateTime> anchors = _anchorDates(spec.anchor, first, today);
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
