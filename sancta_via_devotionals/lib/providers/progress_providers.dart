// The Progress assembler (Plan 2, Task 16): one row per enrolled program —
// its ordinal/day position, its remaining anchor projection, its series
// phase, and its missed-day verdict — plus the lifetime badge count.
//
// [progressAssemblyProvider] consumes the settled seams, never re-deriving
// them:
//
// * `enrolledProgramsProvider` (Task 5/6) — the whole catalog paired with the
//   user's saved progress; the APP-level enrolled ruling
//   (`enrollmentParamsFor(packId) != null`, the Task 12 precedent) filters it
//   to the programs the user actually enrolled in. The catalog alone is
//   never presented as "your progress";
// * `programDetailProvider` (the wrapper) — a commitment's
//   `Projection.remainingDates` come from there, progress-aware, exactly as
//   the detail screen reads them;
// * `VariantService.dayVariant` (Task 10) — a series day's phase label comes
//   from the pack's OWN day-variant data, keyed by the day index the series
//   schedule resolves for today;
// * `ProgressService.missedVerdict` (Task 9) — the missed-day decision.
//
// ## Missed-day policy source (the Task 15 carry)
//
// The per-pack policy is `enrollmentParamsFor(packId)['restartPolicy']` when
// the params carry one, else the settings default
// (`missedDayDefaultPolicyProvider`) — the settings-only assumption is
// superseded for enrolled packs (Task 15 review ruling). An unknown policy
// string reaches `ProgressService.missedVerdict` and throws its own loud
// [ArgumentError]: bad state is surfaced, never silently defaulted.
//
// ## Missed-day surfacing (the Task 9 scope)
//
// The verdict is computed ONLY for `SessionSeriesSpec` packs — the
// evaluator's pinned cadence scope (daily series). Anchor-recurring
// commitments are driven by `CommitmentState` through the session
// completion writer, never by this verdict, so they render no missed-day
// card. Within that scope the surfaced states are the ones needing the
// user:
//
// * `reset` — the strict-policy gap card, with the ruled Apply affordance
//   (applying clears the streak COUNT; the badge history and the series'
//   start date stay — the count is not "reset to day 1", fix round 1);
// * `askUser` WITH fulfilled ordinals — the un-anchored claim state (fix
//   round 1): a persisted progress can carry ordinals without a
//   `lastFulfilled` date (Task 19's claim shape), and `missedVerdict`
//   answers `askUser` for exactly that; the card surfaces it read-only —
//   the service refuses to apply an `askUser` verdict — naming what
//   anchors it: the next completed day.
//
// A permissive policy answers `resume` (the pack's own policy already
// decided — nothing to apply, and `applyMissedDay(resume)` is a
// documented no-op), and a FRESH program (zero fulfilled) renders no
// card: nothing is fulfilled, nothing lags. A verdict only exists on a
// live series (today still inside the window); a closed window renders
// nothing.
//
// ## The position chips (the Review Focus 2 shape)
//
// * a consecutive commitment renders `'N of M'` at the position the next
//   completion takes — the persisted streak plus one, the SAME position
//   `DueToday.schedule.ordinal` reports on Today (fix round 1: a fresh
//   program reads `'1 of M'`, never a completions-style `'0 of M'`); the
//   fulfilled history lives in the badges;
// * a session series renders `'day N of M'` from the SCHEDULE's own day
//   index — the same day the session player resolves, so the phase banner
//   and the player always describe the same day; before the user-picked
//   day 1 the chip honestly reads `'starts <yyyy-mm-dd>'`;
// * both shapes render `'Complete'` once their count is fulfilled — a
//   completed program shows its state and its badges, NEVER an ordinal
//   (Review Focus 2), and the commitment's projection line is empty by the
//   engine's own ruling (a completed program is stable, nothing remains);
// * time-of-day anchors and the other schedule shapes carry no position
//   (their progress history is the badges) and show no chip.
//
// ## Dates
//
// Every date comes from `currentDateProvider` (awaited through its future,
// the workspace seam tests freeze with `Stream.value`); nothing reads the
// clock. The lifetime count is the documented sum of `ProgressState.badges`
// lengths — the badges survive resets (Task 9), so the count only grows.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sancta_via_devotional_engine/sancta_via_devotional_engine.dart'
    show
        ConsecutiveCommitmentSpec,
        ContentPack,
        MissedDayVerdict,
        ProgressState,
        ScheduleResult,
        ScheduleSpec,
        ScheduleContext,
        SessionSeriesSpec;
import 'package:sancta_via_devotional_engine_riverpod/sancta_via_devotional_engine_riverpod.dart'
    show
        EnrolledProgram,
        ProgramDetail,
        enrolledProgramsProvider,
        programDetailProvider;
import 'package:sancta_via_liturgical_calendar_riverpod/sancta_via_liturgical_calendar_riverpod.dart'
    show currentDateProvider;

import '../repositories/program_repository.dart';
import '../services/progress_service.dart';
import '../services/variant_service.dart';
import 'app_settings_provider.dart' show missedDayDefaultPolicyProvider;
import 'content_providers.dart';

/// Reduces [d] to a local midnight date (the engine's date-only discipline).
DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// The zero-padded `yyyy-mm-dd` rendering of the local date [d] — the
/// engine's date-only stamp shape.
String _stamp(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// Capitalizes a lower-case variant value for a display label.
String _capitalize(String value) =>
    value.isEmpty ? value : '${value[0].toUpperCase()}${value.substring(1)}';

/// One enrolled program's progress row (see the library docs for the chip
/// and verdict rules).
class ProgressEntry {
  /// Creates an entry.
  const ProgressEntry({
    required this.pack,
    required this.progress,
    required this.asOf,
    this.remainingDates = const <DateTime>[],
    this.seriesDayIndex,
    this.seriesLengthDays,
    this.seriesStartDate,
    this.seriesPhase,
    this.missedVerdict,
  });

  /// The program's content pack (the enrolled, possibly derived pack).
  final ContentPack pack;

  /// The user's persisted progress for [pack], or null until anything is
  /// saved.
  final ProgressState? progress;

  /// The day the assembly was built for (a local midnight date) — the chip
  /// and the verdict are answers for that day.
  final DateTime asOf;

  /// The commitment's remaining anchor dates (`Projection.remainingDates`
  /// through `programDetailProvider`); empty for non-commitment shapes and
  /// for a completed commitment.
  final List<DateTime> remainingDates;

  /// The series schedule's 1-based day index for [asOf] (the day the player
  /// would resolve), or null when [asOf] lies outside the window.
  final int? seriesDayIndex;

  /// The series' total length in days, or null for non-series shapes.
  final int? seriesLengthDays;

  /// The series' day-1 date (local midnight), or null for non-series shapes.
  final DateTime? seriesStartDate;

  /// The day variant's `phase` (capitalized for display), or null when the
  /// pack ships no phase for [seriesDayIndex] — the brief pins the phase
  /// banner for the consecration / 54-day shapes.
  final String? seriesPhase;

  /// The surfaced missed-day verdict: `reset` (the strict-policy gap, with
  /// the Apply affordance) or `askUser` on a live daily series with
  /// fulfilled ordinals but no `lastFulfilled` date (the un-anchored claim
  /// state, surfaced read-only). Null for every other state — resume,
  /// fresh programs, and non-series shapes (see the library docs).
  final MissedDayVerdict? missedVerdict;

  /// Whether the program's count is fully fulfilled: a commitment at its
  /// count, or a series at its length. Complete programs render their
  /// 'Complete' state and badges — never a position chip (Review Focus 2).
  bool get isComplete {
    final ScheduleSpec schedule = pack.schedule;
    final int fulfilled = progress?.fulfilledOrdinals ?? 0;
    if (schedule is ConsecutiveCommitmentSpec) {
      return fulfilled >= schedule.count;
    }
    if (schedule is SessionSeriesSpec) {
      return fulfilled >= schedule.lengthDays;
    }
    return false;
  }

  /// The position chip's label, or null when the schedule shape carries no
  /// countable position (see the library docs).
  String? get positionLabel {
    final ScheduleSpec schedule = pack.schedule;
    final int fulfilled = progress?.fulfilledOrdinals ?? 0;
    switch (schedule) {
      case ConsecutiveCommitmentSpec(:final int count):
        // The position the next completion takes: the persisted streak
        // plus one — the same position `DueToday.schedule.ordinal`
        // reports (fix round 1; a fresh program reads '1 of $count').
        return isComplete ? 'Complete' : '${fulfilled + 1} of $count';
      case SessionSeriesSpec(:final DateTime startDate, :final int lengthDays):
        if (isComplete) {
          return 'Complete';
        }
        final int? dayIndex = seriesDayIndex;
        if (dayIndex != null) {
          return 'day $dayIndex of $lengthDays';
        }
        return _dateOnly(asOf).isBefore(_dateOnly(startDate))
            ? 'starts ${_stamp(startDate)}'
            : '$fulfilled of $lengthDays';
      default:
        return null;
    }
  }

  @override
  String toString() =>
      'ProgressEntry(pack: ${pack.id}, chip: $positionLabel, '
      'phase: $seriesPhase, remaining: ${remainingDates.length}, '
      'verdict: $missedVerdict)';
}

/// The Progress tab's data: one entry per enrolled program plus the
/// documented lifetime count.
class ProgressAssembly {
  /// Creates an assembly.
  const ProgressAssembly({
    required this.date,
    required this.entries,
    required this.lifetimeBadges,
  });

  /// The day the assembly describes (a local midnight date).
  final DateTime date;

  /// The enrolled programs' rows, in the store's `packs.id ASC` order
  /// (Task 5's ordering ruling), unmodifiable.
  final List<ProgressEntry> entries;

  /// The LIFETIME completions count: the sum of every saved
  /// `ProgressState.badges` length. One badge per finished session is the
  /// completion writer's own rule (Task 9), and badges survive strict
  /// resets, so this number is the lifetime total and only grows.
  final int lifetimeBadges;

  @override
  String toString() =>
      'ProgressAssembly(date: ${_stamp(date)}, entries: ${entries.length}, '
      'lifetimeBadges: $lifetimeBadges)';
}

/// The Progress tab's assembly over the enrolled programs (see the library
/// docs).
///
/// A `FutureProvider` because the enrolled list, the enrollment params and
/// the per-pack details resolve through SQLite; the screen renders its
/// loading/error state while it settles. Like every app provider reading
/// the wrapper's catalog, it expects `main.dart`'s `programRepositoryOverride`
/// on the root scope.
final FutureProvider<ProgressAssembly>
progressAssemblyProvider = FutureProvider<ProgressAssembly>((Ref ref) async {
  final SqliteProgramRepository repository = ref.watch(
    appProgramRepositoryProvider,
  );
  final DateTime asOf = _dateOnly(await ref.watch(currentDateProvider.future));

  // Watching the catalog runs the first-launch migration (a version
  // match afterwards is a no-op), as Today's assembly does.
  await ref.watch(contentLoadedProvider.future);

  // The wrapper reports every catalog pack WITH its progress; the
  // enrolled ruling filters to the programs with an enrollment record
  // (and keeps each pack's params — the per-pack policy source).
  final List<EnrolledProgram> enrolled = <EnrolledProgram>[];
  final Map<String, Map<String, dynamic>> paramsByPack =
      <String, Map<String, dynamic>>{};
  // The wrapper's list is the whole catalog, in `packs.id ASC` order.
  final List<EnrolledProgram> catalog = await ref.watch(
    enrolledProgramsProvider.future,
  );
  for (final EnrolledProgram program in catalog) {
    final Map<String, dynamic>? params = await repository.enrollmentParamsFor(
      program.pack.id,
    );
    if (params == null) {
      continue;
    }
    paramsByPack[program.pack.id] = params;
    enrolled.add(program);
  }

  final String defaultPolicy = ref.watch(missedDayDefaultPolicyProvider);
  final int lifetimeBadges = enrolled.fold<int>(
    0,
    (int total, EnrolledProgram program) =>
        total + (program.progress?.badges.length ?? 0),
  );

  final List<ProgressEntry> entries = <ProgressEntry>[];
  for (final EnrolledProgram program in enrolled) {
    final ContentPack pack = program.pack;
    final ProgressState? progress = program.progress;

    // The per-pack missed-day policy (Task 15 carry ruling): the
    // enrollment params override, else the settings default. An unknown
    // value reaches missedVerdict and throws loudly.
    final Object? policyParam = paramsByPack[pack.id]!['restartPolicy'];
    final String policy = policyParam is String ? policyParam : defaultPolicy;

    final ScheduleSpec schedule = pack.schedule;
    if (schedule case final SessionSeriesSpec series) {
      // The series' own day for the assembly's date: the same day the
      // session player resolves (a default context suffices — a series
      // resolution is date arithmetic, not season-dependent).
      final ScheduleResult resolution = series.resolve(
        asOf,
        const ScheduleContext(),
      );
      final int? dayIndex = resolution.due ? resolution.dayIndex : null;
      String? phase;
      if (dayIndex != null) {
        final Object? raw = VariantService.dayVariant(pack, dayIndex)?['phase'];
        if (raw is String && raw.isNotEmpty) {
          phase = _capitalize(raw);
        }
      }
      // The verdict: engine decision over the persisted progress, with
      // the per-pack policy, on a live series with something fulfilled.
      // Surfaced: reset (the strict gap — actionable) and askUser with
      // ordinals (the un-anchored claim — read-only). Resume (kept-current
      // strict, or the permissive policy's own answer) and fresh programs
      // render nothing.
      MissedDayVerdict? verdict;
      if (resolution.due && (progress?.fulfilledOrdinals ?? 0) > 0) {
        final MissedDayVerdict decided = ProgressService.missedVerdict(
          progress,
          policy,
          asOf,
        );
        if (decided == MissedDayVerdict.reset ||
            decided == MissedDayVerdict.askUser) {
          verdict = decided;
        }
      }
      entries.add(
        ProgressEntry(
          pack: pack,
          progress: progress,
          asOf: asOf,
          seriesDayIndex: dayIndex,
          seriesLengthDays: series.lengthDays,
          seriesStartDate: series.startDate,
          seriesPhase: phase,
          missedVerdict: verdict,
        ),
      );
      continue;
    }
    if (schedule is ConsecutiveCommitmentSpec) {
      // The projection is the wrapper's (progress-aware
      // remainingDates); a completed commitment's list is empty by the
      // engine's own ruling.
      final ProgramDetail detail = await ref.watch(
        programDetailProvider(pack.id).future,
      );
      entries.add(
        ProgressEntry(
          pack: pack,
          progress: progress,
          asOf: asOf,
          remainingDates: detail.remainingDates,
        ),
      );
      continue;
    }
    // The other shapes (time-of-day anchors, weekly loops): the
    // badges carry the progress; no chip, no projection.
    entries.add(ProgressEntry(pack: pack, progress: progress, asOf: asOf));
  }
  return ProgressAssembly(
    date: asOf,
    entries: List<ProgressEntry>.unmodifiable(entries),
    lifetimeBadges: lifetimeBadges,
  );
});
