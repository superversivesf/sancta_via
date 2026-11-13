// The session player controller (Plan 2, Task 10).
//
// The player's state machine over the engine's `SessionRunner`: start a
// pack's session (resolving the day's variant and substituting every text
// ONCE), walk it step by step, record counted repetitions, toggle
// checkpoints, tick a reflection countdown, and — on the final step — route
// the completion through Task 9's `ProgressService.completeSession`.
//
// ## State shape (Task 11's contract)
//
// `SessionPlayerState` carries the pinned four fields:
//
// * `session` — the engine cursor (current step index, recorded counts,
//   completion timestamps);
// * `checkpoints` — item → recorded (the app-layer gate's input);
// * `reflectionEndsAt` — the wall-clock end of the current reflection, when
//   one is running, so a pause/resume restores the countdown;
// * `tokens` — the day's substitution tokens (the variant snapshot's
//   token bag).
//
// Three additive fields complete the render contract without touching the
// pinned four: `script` is the RESOLVED script snapshot (the pack's steps
// with every text substituted once at start — the engine's `SessionState` is
// only a cursor and carries no text), `variant` is the day-variant snapshot
// (Task 11 may read `phase`/`virtue` for banners), and `status`/`errorMessage`
// say whether the session is loading, active, finalized, or failed. The
// checkpoint dates (`checkpointDates`) and the pack's grace-window items
// (`windowedCheckpointItems`) are likewise additive: they let the
// CheckpointStep card offer the off-anchor "When?" entry (final review I1).
//
// ## Completion contract
//
// The last `completeStep()` awaits `ProgressService.completeSession`. The
// controller REFLECTS the service's answer, it never forces one:
//
// * the walk is finished and every `requiredForCompletion` checkpoint is
//   present and true → the completion is persisted and the state moves to
//   [SessionPlayerStatus.finalized];
// * otherwise the pre-final walked state comes back unchanged, the active
//   session stays persisted, and [SessionPlayerState.missingRequiredItems]
//   (plus [SessionPlayerState.isFinalizable], the Task 9 predicate
//   `isComplete && missing.isEmpty`) tell the player what is still missing.
//   Toggling a required checkpoint retries the finalization.
//
// Anchor arithmetic is NOT the player's business: `fulfilledAnchorDates` is
// never consulted here, and the recorded ordinal is whatever
// `completeSession`/`persistCompletion` writes (the persisted streak plus
// one).
//
// ## Persistence and resume
//
// Every transition (start, step, record, checkpoint, reflection tick) writes
// the full snapshot — `SessionState.toJson()`, the checkpoint map and its
// per-item completion dates, the token map, the day-variant snapshot and the
// session's day — to `meta('active_session_<packId>')` through the
// [DevotionalsDatabase] helpers. Writes are serialized through one queue
// (each write captures its snapshot at request time, so the last mutation
// wins) and never fail the chain.
//
// ## Schedule-label alternates (C2)
//
// A time-of-day schedule may re-label its resolution by season (the Angelus
// pack resolves `regina_caeli` throughout Eastertide). The resolved label is
// threaded into the script resolution: the first label for which the pack
// ships alternate content selects it —
//
// * `<label>_versicles` (a `PrayerText`) replaces the inline V./R. pairs of
//   the script's verse steps, pair for pair in script order (the shipped
//   Regina Caeli text carries exactly the three pairs the Angelus session
//   walks; pairs beyond the available text are left at the pack default);
// * `<label>_collect` replaces the prayer step(s) whose content id names a
//   collect (`*_collect`).
//
// Without a shipped alternate the pack's default session plays unchanged
// (ordinary-time Angelus). The label is re-resolved from the session's day
// on resume — the liturgical calendar is deterministic, so the resumed text
// is byte-identical — and it is never guessed: the notification body names
// the same label from the same `ScheduleResult.labels`.
//
// The controller resumes a pack's unfinished session (pause/resume):
// construction may take a resume pack id, and [startSession] checks the
// persisted snapshot before starting fresh. The resume path REPLACES the
// state only when a persisted snapshot exists, its `scriptId` matches the
// pack's session, and — when [startSession] is given a `forDate` — its day is
// that same calendar day; anything else starts fresh (and the first write
// overwrites the stale snapshot). Before reading, the load drains the write
// queue, so a persist that raced a start has already landed: a mid-start
// write can never clobber the snapshot the resume reads. A corrupt snapshot
// is logged and treated as absent. On resume the script is re-derived from
// the PERSISTED tokens/variant (same day, same text) so the substitution gate
// re-runs and resumed text is byte-identical to the start snapshot.
//
// **Completion is at-most-once.** The snapshot is a cache of the walk, not
// the source of truth (the written `ProgressState` is), so snapshot
// write/clear failures are logged and swallowed rather than failing the
// prayer session. The finalize order is: persist the finished snapshot, then
// write the completion, then clear the snapshot. If the app dies inside that
// last window, a complete, gate-satisfied snapshot survives beside its
// written completion; resuming such a snapshot publishes it as FINALIZED and
// clears it WITHOUT calling the completion writer — a later checkpoint
// toggle can then never append a second ordinal/badge. The deliberate
// trade-off is at-most-once: a crash between the finished snapshot and the
// completion write (the narrower window) resumes as finalized and does not
// re-write the completion; double-counting a finished devotion is the worse
// harm, and the day can be reopened from the Today surface.
//
// ## Dates
//
// The session's day (local midnight) is fixed at start ([startSession]'s
// `forDate`, else the clock's day) and is the completion date
// `completeSession` receives — a session opened for a past day completes on
// that day, never on "now". Every recorded checkpoint item carries the
// session day as its `<item>:<yyyy-mm-dd>` completion record date (Task 9's
// caller contract: record every checkpoint marked true so the anchor
// composition can credit it).
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sancta_via_devotional_engine/sancta_via_devotional_engine.dart';
import 'package:sancta_via_devotional_engine_riverpod/sancta_via_devotional_engine_riverpod.dart'
    show ProgramRepository;
import 'package:sancta_via_liturgical_calendar/sancta_via_liturgical_calendar.dart'
    show LiturgicalCalendarService;

import '../database/devotionals_database.dart';
import '../providers/content_providers.dart';
import '../providers/today_providers.dart' show notificationServiceProvider;
import '../repositories/program_repository.dart';
import '../services/notification_service.dart';
import '../services/progress_service.dart';
import '../services/substitution_service.dart';
import '../services/variant_service.dart';
import '../utils/logger.dart';

/// Reduces [d] to a local midnight date (the engine's date-only discipline).
DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// The zero-padded `yyyy-mm-dd` rendering of the local date [d] — the
/// completion-key convention Task 9 writes.
String _stamp(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// The `meta` key one pack's active session persists under.
String _activeSessionKey(String packId) => 'active_session_$packId';

/// The one-step placeholder script the idle/loading/error states carry: the
/// engine's `SessionState` is a cursor that always belongs to a script, and
/// [SessionPlayerState.status] — never the sentinel's id — is the
/// discriminator between "no session yet" and a real one.
final SessionScript _idleScript = SessionScript(
  id: '',
  steps: <SessionStep>[const VerseStep(id: 'idle', versicle: '', response: '')],
);

/// Where a [SessionPlayerState] is in the player lifecycle.
enum SessionPlayerStatus {
  /// No session has been started or resumed yet.
  idle,

  /// The pack's catalog/session snapshot is being loaded.
  loading,

  /// A session is running (or is complete but not yet finalized).
  active,

  /// The completion was written through `ProgressService.completeSession`.
  finalized,

  /// Loading or substitution failed; [SessionPlayerState.errorMessage] says
  /// why.
  error,
}

/// The session player's immutable state — Task 11's render contract.
///
/// The pinned fields are [session], [checkpoints], [reflectionEndsAt], and
/// [tokens]. [script] (the resolved, substituted script snapshot), [variant]
/// (the day-variant snapshot), [day] (the started calendar day — Task 11
/// fix round 1), [status], [errorMessage], and [missingRequiredItems] are
/// additive fields the UI needs to render the player; they never replace or
/// reinterpret the pinned four.
class SessionPlayerState {
  /// The engine cursor of the running session.
  final SessionState session;

  /// The session's steps with every text substituted once at start.
  final SessionScript script;

  /// The checkpoint gate's map: devotion item → recorded.
  final Map<String, bool> checkpoints;

  /// The recorded checkpoints' completion dates (item → local midnight), the
  /// dates the completion records are written under. A grace-window item may
  /// carry a date other than the session day (the Task-I1 "When?" entry).
  final Map<String, DateTime> checkpointDates;

  /// The pack's Fatima prayer (`content['fatima-prayer']`), substituted once
  /// at start, or null when the pack ships none. The BeadGroupStep card
  /// renders THIS text with its attribution when the Fatima flag is on —
  /// never an app-hardcoded copy (final review I5).
  final PrayerText? fatimaPrayer;

  /// The checkpoint items the pack's commitment schedule gives a grace
  /// window (`ConsecutiveCommitmentSpec.windows`) — the items the player
  /// offers an off-anchor completion-date entry for. Empty for every other
  /// pack shape.
  final Set<String> windowedCheckpointItems;

  /// The wall-clock end of the running reflection, or null when none runs.
  final DateTime? reflectionEndsAt;

  /// The day's substitution tokens (the variant snapshot's token bag).
  final Map<String, String> tokens;

  /// The day-variant entry the session was started with (empty when the pack
  /// ships none for the day), kept so a resumed or finishing player renders
  /// the same day's data.
  final Map<String, dynamic> variant;

  /// The calendar day the session was started for (local midnight), an
  /// additive field Task 11's header renders when a deep link opens the
  /// player WITHOUT its `forDate` parameter. It survives the active-session
  /// snapshot's round trip (the resume publishes the snapshot's original
  /// day, never the resume clock's day) and is null whenever no session is
  /// loaded (idle/loading/error).
  final DateTime? day;

  /// Where the player is in its lifecycle.
  final SessionPlayerStatus status;

  /// Why loading failed, when [status] is [SessionPlayerStatus.error].
  final String? errorMessage;

  /// The required checkpoint items still missing, in script order (Task 9's
  /// `missingRequiredItems`, surfaced for the player).
  final List<String> missingRequiredItems;

  /// Creates a [SessionPlayerState].
  const SessionPlayerState({
    required this.session,
    required this.script,
    this.checkpoints = const <String, bool>{},
    this.checkpointDates = const <String, DateTime>{},
    this.windowedCheckpointItems = const <String>{},
    this.fatimaPrayer,
    this.reflectionEndsAt,
    this.tokens = const <String, String>{},
    this.variant = const <String, dynamic>{},
    this.day,
    this.status = SessionPlayerStatus.idle,
    this.errorMessage,
    this.missingRequiredItems = const <String>[],
  });

  /// The idle state: the placeholder script with an empty cursor.
  factory SessionPlayerState.idle() {
    return SessionPlayerState(
      session: SessionRunner.forState(_idleScript),
      script: _idleScript,
    );
  }

  /// Whether the walk is finished AND every required checkpoint is recorded
  /// — the Task 9 finalization predicate (`isComplete && missing.isEmpty`).
  ///
  /// When [status] is [SessionPlayerStatus.finalized] the completion has
  /// already been written; otherwise a true answer means the player may
  /// finalize (the controller retries automatically on the next checkpoint
  /// toggle).
  bool get isFinalizable => session.isComplete && missingRequiredItems.isEmpty;

  /// The current step of [script], or null when the session is complete or
  /// no session is active.
  SessionStep? get currentStep {
    if (status != SessionPlayerStatus.active || session.isComplete) {
      return null;
    }
    if (session.stepIndex < 0 || session.stepIndex >= script.steps.length) {
      return null;
    }
    return script.steps[session.stepIndex];
  }

  @override
  String toString() =>
      'SessionPlayerState(status: ${status.name}, '
      'stepIndex: ${session.stepIndex}/${session.stepCount}, '
      'day: ${day == null ? '-' : _stamp(day!)}, '
      'checkpoints: $checkpoints, tokens: ${tokens.length}, '
      'missing: $missingRequiredItems)';
}

/// One running session's mutable working state (the controller's private
/// book-keeping behind the immutable [SessionPlayerState]).
class _ActiveSession {
  _ActiveSession({
    required this.pack,
    required this.day,
    required this.dayIndex,
    required this.variant,
    required this.tokens,
    required this.script,
    required this.session,
    this.fatimaPrayer,
    Map<String, bool>? checkpoints,
    Map<String, DateTime>? checkpointDates,
    this.reflectionEndsAt,
  }) : checkpoints = checkpoints ?? <String, bool>{},
       checkpointDates = checkpointDates ?? <String, DateTime>{};

  final ContentPack pack;
  final DateTime day;
  final int? dayIndex;
  final Map<String, dynamic> variant;
  final Map<String, String> tokens;
  final SessionScript script;

  /// The pack's resolved Fatima prayer, or null when it ships none.
  final PrayerText? fatimaPrayer;

  SessionState session;
  final Map<String, bool> checkpoints;
  final Map<String, DateTime> checkpointDates;
  DateTime? reflectionEndsAt;

  /// The checkpoint completion records (`<item>:<yyyy-mm-dd>`) the
  /// completion writer receives — one per item recorded true.
  Map<String, String> get completionRecords => <String, String>{
    for (final MapEntry<String, DateTime> entry in checkpointDates.entries)
      '${entry.key}:${_stamp(entry.value)}': 'done',
  };

  /// The JSON snapshot persisted to `meta('active_session_<packId>')`.
  ///
  /// Every collection is copied, so a snapshot captured for one write can
  /// never be mutated by a later transition before it is encoded.
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'packId': pack.id,
      'day': _stamp(day),
      'dayIndex': dayIndex,
      'variant': <String, dynamic>{...variant},
      'session': session.toJson(),
      'checkpoints': <String, bool>{...checkpoints},
      'checkpointDates': <String, String>{
        for (final MapEntry<String, DateTime> entry in checkpointDates.entries)
          entry.key: _stamp(entry.value),
      },
      'reflectionEndsAt': reflectionEndsAt?.toIso8601String(),
      'tokens': <String, String>{...tokens},
    };
  }
}

/// A persisted active session read back from `meta`, before the pack is
/// known (so the script cannot be rebuilt yet).
class _SavedSession {
  _SavedSession({
    required this.day,
    required this.dayIndex,
    required this.variant,
    required this.session,
    required this.checkpoints,
    required this.checkpointDates,
    required this.reflectionEndsAt,
    required this.tokens,
  });

  final DateTime day;
  final int? dayIndex;
  final Map<String, dynamic> variant;
  final SessionState session;
  final Map<String, bool> checkpoints;
  final Map<String, DateTime> checkpointDates;
  final DateTime? reflectionEndsAt;
  final Map<String, String> tokens;

  /// Parses one persisted snapshot defensively; a shape mismatch throws and
  /// the caller treats the snapshot as absent.
  factory _SavedSession.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> sessionJson =
        json['session'] as Map<String, dynamic>;
    final Map<String, dynamic> checkpointsJson =
        json['checkpoints'] as Map<String, dynamic>;
    final Map<String, dynamic> datesJson =
        json['checkpointDates'] as Map<String, dynamic>;
    final Map<String, dynamic> tokenJson =
        json['tokens'] as Map<String, dynamic>;
    final Object? variantJson = json['variant'];
    final Object? reflection = json['reflectionEndsAt'];
    return _SavedSession(
      day: DateTime.parse(json['day'] as String),
      dayIndex: json['dayIndex'] as int?,
      variant: variantJson is Map<String, dynamic>
          ? Map<String, dynamic>.unmodifiable(variantJson)
          : const <String, dynamic>{},
      session: SessionState.fromJson(sessionJson),
      checkpoints: <String, bool>{
        for (final MapEntry<String, dynamic> entry in checkpointsJson.entries)
          entry.key: entry.value as bool,
      },
      checkpointDates: <String, DateTime>{
        for (final MapEntry<String, dynamic> entry in datesJson.entries)
          entry.key: DateTime.parse(entry.value as String),
      },
      reflectionEndsAt: reflection is String
          ? DateTime.parse(reflection)
          : null,
      tokens: <String, String>{
        for (final MapEntry<String, dynamic> entry in tokenJson.entries)
          entry.key: entry.value as String,
      },
    );
  }
}

/// The session player controller over the engine's `SessionRunner` and Task
/// 9's `ProgressService` (see the library docs for the full contract).
class SessionPlayerController extends StateNotifier<SessionPlayerState> {
  /// Creates a controller over [repository] (content + progress) and
  /// [database] (the `meta` active-session store).
  ///
  /// [progressService] defaults to a [ProgressService] over [repository];
  /// [clock] is the wall-clock source for reflection deadlines and the day a
  /// session opened without `forDate` belongs to (tests inject it).
  ///
  /// [resumePackId] makes construction load that pack's persisted session
  /// (pause/resume on a fresh player): the load runs un-awaited — as a
  /// `StateNotifier` constructor cannot await — and [ready] completes when it
  /// settles.
  ///
  /// [onSessionCompleted] is the notification refresh point (Task 18): it runs
  /// once per FINALIZED session, fire-and-forget (a failed hook is logged and
  /// never fails the prayer session). Null in unit tests that do not wire
  /// notifications.
  SessionPlayerController({
    required this.repository,
    required this.database,
    ProgressService? progressService,
    DateTime Function()? clock,
    String? resumePackId,
    this.onSessionCompleted,
  }) : progress = progressService ?? ProgressService(repository: repository),
       _clock = clock ?? DateTime.now,
       super(SessionPlayerState.idle()) {
    if (resumePackId != null) {
      _ready = startSession(resumePackId);
    } else {
      _ready = Future<void>.value();
    }
  }

  /// The content/progress repository the controller reads through.
  final ProgramRepository repository;

  /// The store the active-session snapshot persists in (`meta` helpers).
  final DevotionalsDatabase database;

  /// The completion writer (Task 9).
  final ProgressService progress;

  /// The optional session-completion hook (Task 18's notification refresh
  /// point) — see the constructor docs.
  final Future<void> Function()? onSessionCompleted;

  final DateTime Function() _clock;

  /// Completes when a construction-time resume (or the immediate idle) has
  /// settled. Exposed so callers/tests can await the load instead of
  /// polling.
  late final Future<void> _ready;

  /// Awaitable construction-time load (already complete when no
  /// [SessionPlayerController.resumePackId] was given).
  Future<void> get ready => _ready;

  /// The running session's private working state, or null when no session is
  /// active.
  _ActiveSession? _active;

  /// Bumped by every [startSession]; an async load that lost the race must
  /// not publish.
  int _generation = 0;

  /// Tail of the serialized persist chain.
  Future<void>? _writeQueue;

  /// Starts (or resumes) the session of [packId] for [forDate].
  ///
  /// [forDate] fixes the day the session belongs to (default: the clock's
  /// day) and therefore its `dayIndex`, variant, tokens, and completion date.
  ///
  /// The persisted active session for [packId] is resumed when one exists and
  /// its day is [forDate]'s (see the library docs); otherwise a fresh session
  /// starts from the pack's schedule resolution. An unknown pack, or a
  /// substitution leak, leaves the state in [SessionPlayerStatus.error] with
  /// [SessionPlayerState.errorMessage] set — never a thrown error out of the
  /// player.
  Future<void> startSession(String packId, {DateTime? forDate}) async {
    final int generation = ++_generation;
    _active = null;
    final SessionPlayerState idle = SessionPlayerState.idle();
    state = SessionPlayerState(
      session: idle.session,
      script: idle.script,
      status: SessionPlayerStatus.loading,
    );
    try {
      await _drainWrites();
      final List<ContentPack> packs = await repository.loadPacks();
      final ContentPack? pack = _findPack(packs, packId);
      if (pack == null) {
        AppLogger.warning(
          'No content pack "$packId" is loaded — the player cannot start',
          'SESSION',
        );
        if (generation != _generation || !mounted) {
          return;
        }
        state = SessionPlayerState(
          session: idle.session,
          script: idle.script,
          status: SessionPlayerStatus.error,
          errorMessage: 'No content pack "$packId" is loaded',
        );
        return;
      }
      final DateTime? requestedDay = forDate == null
          ? null
          : _dateOnly(forDate);
      final _SavedSession? saved = await _readSaved(packId);
      final bool resumable =
          saved != null &&
          saved.session.scriptId == pack.session.id &&
          (requestedDay == null || _isSameDay(saved.day, requestedDay));
      if (resumable) {
        final _ActiveSession resumed = _activeFromSaved(pack, saved);
        if (generation != _generation || !mounted) {
          return;
        }
        // Completion is at-most-once. A complete, gate-satisfied snapshot
        // that outlived its completion write can only mean the app died
        // inside the finalize window (the snapshot is persisted just before
        // `completeSession` runs). Publishing it ACTIVE would let a later
        // checkpoint toggle re-enter `persistCompletion` and write a second
        // ordinal/badge, so it is published FINALIZED and cleared without
        // touching progress.
        final bool completionAlreadyLanded =
            resumed.session.isComplete &&
            ProgressService.missingRequiredItems(
              pack,
              resumed.checkpoints,
            ).isEmpty;
        _active = resumed;
        if (completionAlreadyLanded) {
          _publish(SessionPlayerStatus.finalized);
          _active = null;
          await _clearActive(pack.id);
          AppLogger.info(
            'Resumed the completed session of "${pack.id}" as finalized — '
                'its completion was already written; the snapshot is cleared '
                'without a second write',
            'SESSION',
          );
          return;
        }
        _publish(SessionPlayerStatus.active);
        AppLogger.info(
          'Resumed "${pack.id}" at step ${saved.session.stepIndex} of '
              '${saved.session.stepCount}',
          'SESSION',
        );
        return;
      }
      final _ActiveSession active = _startFresh(
        pack,
        requestedDay ?? _dateOnly(_clock()),
      );
      if (generation != _generation || !mounted) {
        return;
      }
      _active = active;
      _publish(SessionPlayerStatus.active);
      await _persistActive();
    } catch (e, stackTrace) {
      AppLogger.error(
        'Failed to start the session for "$packId"',
        e,
        stackTrace,
        'SESSION',
      );
      if (generation != _generation || !mounted) {
        return;
      }
      state = SessionPlayerState(
        session: idle.session,
        script: idle.script,
        status: SessionPlayerStatus.error,
        errorMessage: 'Could not start "$packId": $e',
      );
    }
  }

  /// Completes the current step and advances; on the last step, finalizes
  /// the completion through [ProgressService.completeSession] (see the
  /// library docs).
  ///
  /// A counted step ([RepetitionStep], [BeadGroupStep]) that has not reached
  /// its target is not completed: the engine throws, the controller logs and
  /// leaves the session where it is — the UI's counter drives [record] first.
  Future<void> completeStep() async {
    final _ActiveSession? active = _active;
    if (active == null || state.status != SessionPlayerStatus.active) {
      return;
    }
    if (active.session.isComplete) {
      return;
    }
    final SessionState next;
    try {
      next = SessionRunner.completeCurrent(
        active.session,
        script: active.script,
      );
    } on StateError catch (e) {
      AppLogger.debug(
        'Step ${active.session.stepIndex} of "${active.pack.id}" is not '
            'completable yet: $e',
        'SESSION',
      );
      return;
    }
    active.session = next;
    _publish(SessionPlayerStatus.active);
    await _persistActive();
    if (next.isComplete) {
      await _finalize();
    }
  }

  /// Accumulates [count] into the current step's recorded counter.
  ///
  /// A non-positive [count] is ignored (there is nothing to record), and a
  /// complete session has no current step to record into.
  Future<void> record(int count) async {
    final _ActiveSession? active = _active;
    if (count <= 0 ||
        active == null ||
        state.status != SessionPlayerStatus.active ||
        active.session.isComplete) {
      return;
    }
    active.session = SessionRunner.record(active.session, count);
    _publish(SessionPlayerStatus.active);
    await _persistActive();
  }

  /// Toggles the checkpoint [item] and retries finalization when the walk is
  /// already complete (the gate's other half).
  ///
  /// Recording the item true dates its completion record at the session's
  /// day; toggling it false removes the record.
  Future<void> toggleCheckpoint(String item) async {
    final _ActiveSession? active = _active;
    if (item.isEmpty ||
        active == null ||
        state.status != SessionPlayerStatus.active) {
      return;
    }
    final bool recorded = !(active.checkpoints[item] ?? false);
    active.checkpoints[item] = recorded;
    if (recorded) {
      active.checkpointDates[item] = _dateOnly(active.day);
    } else {
      active.checkpointDates.remove(item);
    }
    _publish(SessionPlayerStatus.active);
    await _persistActive();
    if (active.session.isComplete) {
      await _finalize();
    }
  }

  /// Records the checkpoint [item] true on [completedOn] — the off-anchor
  /// completion-date entry (final review I1).
  ///
  /// A grace-window item (e.g. the First Saturdays confession, ±8 days) may
  /// be made on a day other than the anchor; the completion record must carry
  /// the day it was actually made, because that is the date the grace-window
  /// composition credits. The item is recorded true and dated [completedOn]
  /// (reduced to its local midnight), and finalization is retried when the
  /// walk is already complete. Only the schedule's windowed items are offered
  /// this way ([SessionPlayerState.windowedCheckpointItems]); an item outside
  /// the windows records exactly as [toggleCheckpoint] would, dated at the
  /// chosen day.
  Future<void> recordCheckpointOn(String item, DateTime completedOn) async {
    final _ActiveSession? active = _active;
    if (item.isEmpty ||
        active == null ||
        state.status != SessionPlayerStatus.active) {
      return;
    }
    active.checkpoints[item] = true;
    active.checkpointDates[item] = _dateOnly(completedOn);
    _publish(SessionPlayerStatus.active);
    await _persistActive();
    if (active.session.isComplete) {
      await _finalize();
    }
  }

  /// Records the running reflection's [remaining] time, so the countdown
  /// survives a pause/resume. A non-positive [remaining] clears the deadline
  /// (the countdown finished).
  Future<void> tickReflection(Duration remaining) async {
    final _ActiveSession? active = _active;
    if (active == null || state.status != SessionPlayerStatus.active) {
      return;
    }
    active.reflectionEndsAt = remaining.inMilliseconds <= 0
        ? null
        : _clock().add(remaining);
    _publish(SessionPlayerStatus.active);
    await _persistActive();
  }

  /// Routes the finished walk through `ProgressService.completeSession`.
  ///
  /// The written progress is the service's; the controller only reflects the
  /// answer: finalization persisted → [SessionPlayerStatus.finalized] and the
  /// active snapshot cleared; the gate held → the walked state stays active
  /// and persists, with [SessionPlayerState.missingRequiredItems] naming what
  /// is missing.
  ///
  /// The active session AND the start generation are captured at ENTRY, so a
  /// `startSession` that lands while the completion write is in flight
  /// invalidates this call's publish (the walk it finalizes is the one it
  /// captured) — narrowing the interleave window to the write itself.
  /// Completion is at-most-once: a gate-satisfied finished snapshot that
  /// survives a crash is resumed FINALIZED by [startSession] instead of
  /// being written again (see the library docs).
  Future<void> _finalize() async {
    final _ActiveSession? active = _active;
    if (active == null) {
      return;
    }
    final int generation = _generation;
    try {
      final SessionState walked = await progress.completeSession(
        state: active.session,
        pack: active.pack,
        checkpointStates: active.checkpoints,
        completedItemsByDay: active.completionRecords,
        today: active.day,
      );
      if (!mounted || generation != _generation) {
        return;
      }
      active.session = walked;
      final List<String> missing = ProgressService.missingRequiredItems(
        active.pack,
        active.checkpoints,
      );
      if (walked.isComplete && missing.isEmpty) {
        _publish(SessionPlayerStatus.finalized);
        _active = null;
        await _clearActive(active.pack.id);
        AppLogger.info(
          'Finalized the session of "${active.pack.id}" for '
              '${_stamp(active.day)}',
          'SESSION',
        );
        _notifyCompleted();
      } else {
        _publish(SessionPlayerStatus.active);
        await _persistActive();
        AppLogger.info(
          'Session of "${active.pack.id}" stays incomplete: '
              '${missing.join(', ')}',
          'SESSION',
        );
      }
    } catch (e, stackTrace) {
      // A failed write must not destroy the player: the walked session stays
      // resumable and the next checkpoint toggle retries finalization.
      AppLogger.error(
        'Failed to finalize the session of "${active.pack.id}"',
        e,
        stackTrace,
        'SESSION',
      );
    }
  }

  /// Runs the optional session-completion hook (Task 18's refresh point),
  /// fire-and-forget: the completion is already persisted, so a failing
  /// notification refresh must never surface as a session failure.
  void _notifyCompleted() {
    final Future<void> Function()? hook = onSessionCompleted;
    if (hook == null) {
      return;
    }
    unawaited(_runCompletionHook(hook));
  }

  Future<void> _runCompletionHook(Future<void> Function() hook) async {
    try {
      await hook();
    } catch (e, stackTrace) {
      AppLogger.error(
        'Session-completion notification refresh failed',
        e,
        stackTrace,
        'SESSION',
      );
    }
  }

  /// The fresh session of [pack] for [day]: resolve the day's schedule and
  /// variant, substitute every text once, and start the engine cursor.
  _ActiveSession _startFresh(ContentPack pack, DateTime day) {
    final ScheduleResult resolution = _resolveDay(pack, day);
    final int? dayIndex = resolution.dayIndex;
    final Map<String, dynamic> variant = dayIndex == null
        ? const <String, dynamic>{}
        : VariantService.dayVariant(pack, dayIndex) ??
              const <String, dynamic>{};
    final Map<String, String> tokens = _tokensFor(pack, day, dayIndex, variant);
    final SessionScript script = _resolveScript(
      pack,
      day,
      tokens,
      variant,
      labels: resolution.labels,
    );
    return _ActiveSession(
      pack: pack,
      day: day,
      dayIndex: dayIndex,
      variant: variant,
      tokens: tokens,
      script: script,
      fatimaPrayer: _fatimaPrayer(pack, tokens),
      session: SessionRunner.forState(script),
    );
  }

  /// The resumed session of [pack] from [saved]: the persisted cursor,
  /// checkpoints, countdown, and token/variant snapshot, with the script
  /// re-derived from that snapshot (the substitution gate runs again, and
  /// the day's schedule label is re-resolved for the same day).
  _ActiveSession _activeFromSaved(ContentPack pack, _SavedSession saved) {
    final SessionScript script = _resolveScript(
      pack,
      saved.day,
      saved.tokens,
      saved.variant,
      labels: _resolveDay(pack, _dateOnly(saved.day)).labels,
    );
    return _ActiveSession(
      pack: pack,
      day: _dateOnly(saved.day),
      dayIndex: saved.dayIndex,
      variant: saved.variant,
      tokens: saved.tokens,
      script: script,
      fatimaPrayer: _fatimaPrayer(pack, saved.tokens),
      session: saved.session,
      checkpoints: <String, bool>{...saved.checkpoints},
      checkpointDates: <String, DateTime>{...saved.checkpointDates},
      reflectionEndsAt: saved.reflectionEndsAt,
    );
  }

  /// The day's token bag: the season-driven mystery cycle first (the rosary
  /// shape), then the day variant's own tokens (which win — the 54-day
  /// novena's cycle is its variant's `mysterySet`), and always `day` when
  /// the schedule resolves one.
  Map<String, String> _tokensFor(
    ContentPack pack,
    DateTime day,
    int? dayIndex,
    Map<String, dynamic> variant,
  ) {
    final Map<String, String> tokens = <String, String>{
      ...VariantService.resolveCycleMysteryTokens(pack, forDate: day),
    };
    if (dayIndex != null) {
      tokens.addAll(
        VariantService.resolveDayVariant(pack, dayIndex, forDate: day),
      );
      tokens.putIfAbsent('day', () => dayIndex.toString());
    }
    return Map<String, String>.unmodifiable(tokens);
  }

  /// The pack's script with every text substituted ONCE (the Review Focus 4
  /// leakage gate): a bead group gets its own decade's mystery tokens, every
  /// other step the day's tokens, and — when the resolved schedule label
  /// ships alternates — the label's versicles/collect replace the defaults
  /// (see the library docs). Any leftover `{{…}}` throws — the caller
  /// surfaces it as the player's error state instead of rendering it.
  SessionScript _resolveScript(
    ContentPack pack,
    DateTime day,
    Map<String, String> tokens,
    Map<String, dynamic> variant, {
    List<String> labels = const <String>[],
  }) {
    final Object? set = variant['mysterySet'];
    final String? setOverride = set is String ? set : null;
    final String? fruitFallback = tokens['virtue'];
    int beadIndex = 0;
    final List<SessionStep> steps = <SessionStep>[];
    for (final SessionStep step in pack.session.steps) {
      if (step is BeadGroupStep) {
        beadIndex++;
        final Map<String, String> stepTokens = <String, String>{
          ...tokens,
          ...VariantService.resolveBeadMysteryTokens(
            pack: pack,
            forDate: day,
            beadIndex: beadIndex,
            setOverride: setOverride,
            fruitFallback: fruitFallback,
          ),
        };
        steps.add(
          BeadGroupStep(
            id: step.id,
            title: _substituteOrNull(step.title, stepTokens),
            mysteryTitle: _substituteOrNull(step.mysteryTitle, stepTokens),
            mysteryFruit: _substituteOrNull(step.mysteryFruit, stepTokens),
            hailMaryCount: step.hailMaryCount,
            includeFatimaPrayer: step.includeFatimaPrayer,
          ),
        );
        continue;
      }
      steps.add(_resolveStep(step, tokens));
    }
    _applyLabelAlternates(pack, labels, tokens, steps);
    return SessionScript(id: pack.session.id, steps: steps);
  }

  /// The first resolved schedule [labels] entry (in resolution order) the
  /// pack ships alternate content for (`<label>_versicles` or
  /// `<label>_collect`), or null when none does.
  String? _alternateLabel(ContentPack pack, List<String> labels) {
    for (final String label in labels) {
      if (label.isEmpty) {
        continue;
      }
      if (pack.content.containsKey('${label}_versicles') ||
          pack.content.containsKey('${label}_collect')) {
        return label;
      }
    }
    return null;
  }

  /// Replaces [steps]' defaults with the resolved [labels]' alternates, in
  /// place (see the library docs for the mapping rule).
  void _applyLabelAlternates(
    ContentPack pack,
    List<String> labels,
    Map<String, String> tokens,
    List<SessionStep> steps,
  ) {
    final String? label = _alternateLabel(pack, labels);
    if (label == null) {
      return;
    }
    final PrayerText? versicles = pack.content['${label}_versicles'];
    if (versicles != null) {
      final List<(String versicle, String response)> pairs = _versePairs(
        versicles.text,
      );
      int verseIndex = 0;
      for (int i = 0; i < steps.length; i++) {
        final SessionStep step = steps[i];
        if (step is! VerseStep) {
          continue;
        }
        if (verseIndex >= pairs.length) {
          break;
        }
        final (String versicle, String response) pair = pairs[verseIndex++];
        steps[i] = VerseStep(
          id: step.id,
          title: step.title,
          versicle: _substitute(pair.$1, tokens),
          response: _substitute(pair.$2, tokens),
          closing: step.closing,
        );
      }
    }
    final PrayerText? collect = pack.content['${label}_collect'];
    if (collect != null) {
      for (int i = 0; i < steps.length; i++) {
        final SessionStep step = steps[i];
        if (step is PrayerStep && step.text.id.endsWith('_collect')) {
          steps[i] = PrayerStep(
            id: step.id,
            title: step.title,
            text: _resolveText(collect, tokens),
          );
        }
      }
    }
  }

  /// The V./R. pairs of an alternate-versicles text, in authored order: each
  /// `V.` line opens a pair and the next `R.` line closes it. A trailing
  /// unterminated pair is ignored (there is no response to render).
  List<(String, String)> _versePairs(String text) {
    final List<(String, String)> pairs = <(String, String)>[];
    String? pendingVersicle;
    for (final String rawLine in text.split('\n')) {
      final String line = rawLine.trim();
      if (line.startsWith('V.')) {
        pendingVersicle = line.substring(2).trim();
        continue;
      }
      if (line.startsWith('R.') && pendingVersicle != null) {
        pairs.add((pendingVersicle, line.substring(2).trim()));
        pendingVersicle = null;
      }
    }
    return pairs;
  }

  /// One non-bead step with its texts substituted.
  SessionStep _resolveStep(SessionStep step, Map<String, String> tokens) {
    return switch (step) {
      PrayerStep() => PrayerStep(
        id: step.id,
        title: _substituteOrNull(step.title, tokens),
        text: _resolveText(step.text, tokens),
      ),
      VerseStep() => VerseStep(
        id: step.id,
        title: _substituteOrNull(step.title, tokens),
        versicle: _substitute(step.versicle, tokens),
        response: _substitute(step.response, tokens),
        closing: step.closing == null
            ? null
            : _resolveText(step.closing!, tokens),
      ),
      ReflectionStep() => ReflectionStep(
        id: step.id,
        title: _substituteOrNull(step.title, tokens),
        text: step.text == null ? null : _resolveText(step.text!, tokens),
        duration: step.duration,
      ),
      CheckpointStep() => CheckpointStep(
        id: step.id,
        title: _substituteOrNull(step.title, tokens),
        item: step.item,
        requiredForCompletion: step.requiredForCompletion,
      ),
      IntercessionStep() => IntercessionStep(
        id: step.id,
        title: _substituteOrNull(step.title, tokens),
        prompt: _substitute(step.prompt, tokens),
      ),
      RepetitionStep() => RepetitionStep(
        id: step.id,
        title: _substituteOrNull(step.title, tokens),
        text: _resolveText(step.text, tokens),
        count: step.count,
      ),
      LitanyStep() => LitanyStep(
        id: step.id,
        title: _substituteOrNull(step.title, tokens),
        invocations: <String>[
          for (final String invocation in step.invocations)
            _substitute(invocation, tokens),
        ],
        response: _substitute(step.response, tokens),
        groupedResponse: step.groupedResponse,
      ),
      BeadGroupStep() => step,
    };
  }

  /// One prayer text with its vernacular and Latin renderings substituted.
  PrayerText _resolveText(PrayerText text, Map<String, String> tokens) {
    return PrayerText(
      id: text.id,
      text: _substitute(text.text, tokens),
      latin: _substituteOrNull(text.latin, tokens),
      source: text.source,
      license: text.license,
    );
  }

  /// Substitutes [value] once and enforces the leakage gate on the result.
  String _substitute(String value, Map<String, String> tokens) {
    return SubstitutionService.requireFullySubstituted(
      SubstitutionService.substitute(value, tokens: tokens),
    );
  }

  /// Substitutes an optional text, keeping null as null.
  String? _substituteOrNull(String? value, Map<String, String> tokens) {
    return value == null ? null : _substitute(value, tokens);
  }

  /// The pack's resolution for [day], under the day's liturgical season so
  /// season-keyed label variants (the Angelus' Regina Caeli) resolve exactly
  /// as the Today tile and the notification planner resolved them.
  ScheduleResult _resolveDay(ContentPack pack, DateTime day) {
    final ScheduleContext context = ScheduleContext(
      seasonKeyValue: LiturgicalCalendarService.getDayForDate(
        _dateOnly(day),
      )?.seasonKey,
    );
    for (final ScheduleSpec spec in pack.schedules) {
      final ScheduleResult result = spec.resolve(day, context);
      if (result.due) {
        return result;
      }
    }
    return pack.schedules.first.resolve(day, context);
  }

  /// The loaded pack [packId], or null when the catalog does not carry it.
  ContentPack? _findPack(List<ContentPack> packs, String packId) {
    for (final ContentPack pack in packs) {
      if (pack.id == packId) {
        return pack;
      }
    }
    return null;
  }

  /// Publishes the active session's state with [status].
  void _publish(SessionPlayerStatus status) {
    final _ActiveSession? active = _active;
    if (active == null) {
      return;
    }
    state = SessionPlayerState(
      session: active.session,
      script: active.script,
      checkpoints: Map<String, bool>.unmodifiable(active.checkpoints),
      checkpointDates: Map<String, DateTime>.unmodifiable(
        active.checkpointDates,
      ),
      windowedCheckpointItems: _windowedItems(active.pack),
      fatimaPrayer: active.fatimaPrayer,
      reflectionEndsAt: active.reflectionEndsAt,
      tokens: active.tokens,
      variant: active.variant,
      day: active.day,
      status: status,
      missingRequiredItems: ProgressService.missingRequiredItems(
        active.pack,
        active.checkpoints,
      ),
    );
  }

  /// The pack's Fatima prayer with its tokens substituted (the same
  /// substitution gate as every other text), or null when the pack ships no
  /// `content['fatima-prayer']` entry.
  PrayerText? _fatimaPrayer(ContentPack pack, Map<String, String> tokens) {
    final PrayerText? prayer = pack.content['fatima-prayer'];
    return prayer == null ? null : _resolveText(prayer, tokens);
  }

  /// The checkpoint items of [pack]'s commitment schedule that carry a grace
  /// window — the items whose completion date the player may pick.
  static Set<String> _windowedItems(ContentPack pack) {
    final Set<String> items = <String>{};
    for (final ScheduleSpec spec in pack.schedules) {
      if (spec is ConsecutiveCommitmentSpec) {
        for (final GraceWindow window in spec.windows) {
          items.add(window.item);
        }
      }
    }
    return Set<String>.unmodifiable(items);
  }

  /// Enqueues a write of the current snapshot; the snapshot is captured NOW
  /// (so writes land in mutation order and the last one wins).
  Future<void> _persistActive() {
    final _ActiveSession? active = _active;
    if (active == null) {
      return Future<void>.value();
    }
    final String packId = active.pack.id;
    final Map<String, dynamic> snapshot = active.toJson();
    return _scheduleWrite(() => _writeActive(packId, snapshot));
  }

  /// Enqueues the removal of the pack's active snapshot.
  Future<void> _clearActive(String packId) {
    return _scheduleWrite(() => _deleteActive(packId));
  }

  /// Serializes [write] behind the queue; a failed write is logged and never
  /// poisons the chain — the snapshot is a resume cache, not the source of
  /// truth, so losing a cache write must never fail the prayer session.
  Future<void> _scheduleWrite(Future<void> Function() write) {
    final Future<void> preceding = _writeQueue ?? Future<void>.value();
    final Future<void> next = preceding.then((_) => write());
    _writeQueue = next;
    return next;
  }

  /// Drains the write queue (a resume's read must see every prior write).
  Future<void> _drainWrites() async {
    final Future<void>? queue = _writeQueue;
    if (queue != null) {
      await queue;
    }
  }

  Future<void> _writeActive(
    String packId,
    Map<String, dynamic> snapshot,
  ) async {
    try {
      await database.setMeta(_activeSessionKey(packId), jsonEncode(snapshot));
    } catch (e, stackTrace) {
      AppLogger.error(
        'Failed to persist the active session of "$packId"',
        e,
        stackTrace,
        'SESSION',
      );
    }
  }

  Future<void> _deleteActive(String packId) async {
    try {
      await database.deleteMeta(_activeSessionKey(packId));
    } catch (e, stackTrace) {
      AppLogger.error(
        'Failed to clear the active session of "$packId"',
        e,
        stackTrace,
        'SESSION',
      );
    }
  }

  /// The persisted active session of [packId], or null when absent/corrupt.
  Future<_SavedSession?> _readSaved(String packId) async {
    try {
      final String? raw = await database.getMeta(_activeSessionKey(packId));
      if (raw == null) {
        return null;
      }
      final Object? decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('active session is not a JSON object');
      }
      return _SavedSession.fromJson(decoded);
    } catch (e) {
      AppLogger.warning(
        'Active session snapshot of "$packId" is unreadable — starting '
            'fresh ($e)',
        'SESSION',
      );
      return null;
    }
  }

  /// Whether two date-only values are the same calendar day.
  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

/// The per-pack session player controller, over the app's SQLite repository
/// and its `meta` store.
///
/// Keyed by pack id: the family's key is the pack whose session the screen
/// plays, and it doubles as the construction-time resume id (a fresh player
/// instance restores that pack's unfinished session — pause/resume). The
/// content catalog is expected to be seeded by the app's content pipeline
/// (`contentLoadedProvider`) before the player opens, as the Today flow does.
final sessionPlayerControllerProvider = StateNotifierProvider.autoDispose
    .family<SessionPlayerController, SessionPlayerState, String>((
      Ref ref,
      String packId,
    ) {
      final SqliteProgramRepository repository = ref.watch(
        appProgramRepositoryProvider,
      );
      // Task 18's session-completion refresh point. The service is read once
      // here (not inside the callback), so the hook never touches a disposed
      // provider; the provider itself is app-lifetime.
      final NotificationService notifications = ref.watch(
        notificationServiceProvider,
      );
      return SessionPlayerController(
        repository: repository,
        database: repository.database,
        resumePackId: packId,
        onSessionCompleted: notifications.refresh,
      );
    });
