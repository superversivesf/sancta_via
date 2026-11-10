/// Riverpod providers over the devotional engine's programs: the
/// repository they read through, the enrolled program list, today's due
/// programs, and the per-program detail.
///
/// The providers are a thin reactive seam: every schedule, session, and
/// progress decision is delegated to `sancta_via_devotional_engine` and
/// the sibling date providers of
/// `sancta_via_liturgical_calendar_riverpod`; nothing here re-implements
/// engine semantics. Tests override [programRepositoryProvider] and the
/// sibling `currentDateProvider` (its real implementation ticks on a
/// periodic stream that never completes inside a test — the workspace's
/// date providers are overridden with `Stream.value` instead).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sancta_via_devotional_engine/sancta_via_devotional_engine.dart';
import 'package:sancta_via_liturgical_calendar_riverpod/sancta_via_liturgical_calendar_riverpod.dart';

import '../program_repository.dart';

/// The repository the program providers read through.
///
/// Defaults to the in-memory repository preloaded with the engine
/// fixture packs; override with a concrete repository in tests and in
/// the app.
final Provider<ProgramRepository> programRepositoryProvider =
    Provider<ProgramRepository>((Ref ref) => InMemoryProgramRepository());

/// One program of the user's library: the pack and the user's saved
/// progress for it (null until anything is saved).
class EnrolledProgram {
  /// The program's content pack.
  final ContentPack pack;

  /// The user's persisted progress for [pack], or null.
  final ProgressState? progress;

  /// Creates an [EnrolledProgram].
  const EnrolledProgram({required this.pack, required this.progress});

  @override
  String toString() => 'EnrolledProgram(pack: ${pack.id}, progress: $progress)';
}

/// One program whose session is due today, with its resolution.
class DueToday {
  /// The pack whose session is due.
  final ContentPack pack;

  /// The schedule resolution of today for the pack's first due schedule.
  ///
  /// For a [ConsecutiveCommitmentSpec] pack this carries the position
  /// today's completion takes in [ScheduleResult.ordinal] (see
  /// [todayProgramsProvider]); every other schedule shape resolves as
  /// the engine resolves it.
  final ScheduleResult schedule;

  /// Creates a [DueToday].
  const DueToday({required this.pack, required this.schedule});

  @override
  String toString() => 'DueToday(pack: ${pack.id}, schedule: $schedule)';
}

/// Everything a program detail surface needs: the pack, the user's
/// progress, and — for a consecutive commitment — its restart policy and
/// the projection of the remaining anchor dates.
class ProgramDetail {
  /// The program's content pack.
  final ContentPack pack;

  /// The user's persisted progress for [pack], or null.
  final ProgressState? progress;

  /// The commitment's restart policy as the engine's policy string
  /// (`'strict'` or `'permissive'`), or null for programs that are not a
  /// consecutive commitment.
  ///
  /// The string is the seam the engine's missed-day machinery consumes
  /// (`MissedDayEvaluator.evaluate` takes policy strings): the app layer
  /// decides what a missed day does with it — this wrapper does not.
  final String? restartPolicy;

  /// The anchor dates the commitment's remaining fulfillments can fall
  /// on (the engine's `Projection.remainingDates` from today), or empty
  /// for programs that are not a consecutive commitment.
  final List<DateTime> remainingDates;

  /// Creates a [ProgramDetail].
  const ProgramDetail({
    required this.pack,
    required this.progress,
    required this.restartPolicy,
    required this.remainingDates,
  });

  @override
  String toString() =>
      'ProgramDetail(pack: ${pack.id}, progress: $progress, '
      'restartPolicy: $restartPolicy, '
      'remainingDates: ${remainingDates.length})';
}

/// The programs of the user's library: every repository pack paired
/// with its saved progress.
final FutureProvider<List<EnrolledProgram>> enrolledProgramsProvider =
    FutureProvider<List<EnrolledProgram>>((Ref ref) async {
      final ProgramRepository repository = ref.watch(programRepositoryProvider);
      final List<ContentPack> packs = await repository.loadPacks();
      return <EnrolledProgram>[
        for (final ContentPack pack in packs)
          EnrolledProgram(
            pack: pack,
            progress: await repository.progressFor(pack.id),
          ),
      ];
    });

/// The programs whose session is due today.
///
/// The date is the sibling `currentDateProvider`'s (awaited through its
/// future so a test's `Stream.value` override arrives before anything
/// resolves), and the liturgical day of that date feeds the engine's
/// [ScheduleContext] — season-keyed label variants (e.g. the Angelus
/// pack's Regina Caeli in Eastertide) resolve through it.
///
/// Each due pack contributes one [DueToday] carrying its first due
/// schedule's resolution. For a due [ConsecutiveCommitmentSpec] the
/// resolution's `ordinal` names the position today's completion takes —
/// the persisted streak plus one, the position
/// `CommitmentState.evaluate` reports as `nextOrdinal` on an anchor day.
/// A due [ConsecutiveCommitmentSpec] whose progress shows the
/// commitment complete (`fulfilledOrdinals` at the commitment's
/// `count`) is EXCLUDED from the list: a completed program is not due,
/// and its completion renders through [programDetailProvider] instead.
/// What a MISSED day does to the streak stays the app layer's decision
/// (the engine's `MissedDayEvaluator` / `CommitmentState`, driven by the
/// policy string [ProgramDetail.restartPolicy] surfaces); this provider
/// only reports the position the persisted progress implies.
final FutureProvider<List<DueToday>> todayProgramsProvider =
    FutureProvider<List<DueToday>>((Ref ref) async {
      final ProgramRepository repository = ref.watch(programRepositoryProvider);
      final List<ContentPack> packs = await repository.loadPacks();

      final DateTime today = await ref.watch(currentDateProvider.future);
      final LiturgicalDayData? day = ref.watch(currentLiturgicalDayProvider);
      final ScheduleContext context = ScheduleContext(
        seasonKeyValue: day?.seasonKey,
      );

      final List<DueToday> due = <DueToday>[];
      for (final ContentPack pack in packs) {
        for (final ScheduleSpec schedule in pack.schedules) {
          final ScheduleResult result = schedule.resolve(today, context);
          if (!result.due) {
            continue;
          }
          final ProgressState? progress = await repository.progressFor(pack.id);
          if (schedule is ConsecutiveCommitmentSpec &&
              (progress?.fulfilledOrdinals ?? 0) >= schedule.count) {
            // The commitment is complete: a completed program is not due
            // (its completion renders through programDetailProvider), so
            // no later schedule may resurrect it into today's list.
            break;
          }
          due.add(
            DueToday(
              pack: pack,
              schedule: schedule is ConsecutiveCommitmentSpec
                  ? ScheduleResult(
                      due: result.due,
                      dayIndex: result.dayIndex,
                      ordinal: (progress?.fulfilledOrdinals ?? 0) + 1,
                      labels: result.labels,
                    )
                  : result,
            ),
          );
          break;
        }
      }
      return due;
    });

/// The detail of one program, by pack id.
///
/// Resolves to a [StateError] (the provider's error state) when no pack
/// with [packId] exists in the repository.
final FutureProviderFamily<ProgramDetail, String> programDetailProvider =
    FutureProvider.family<ProgramDetail, String>((
      Ref ref,
      String packId,
    ) async {
      final ProgramRepository repository = ref.watch(programRepositoryProvider);
      final List<ContentPack> packs = await repository.loadPacks();

      final ContentPack pack = packs.firstWhere(
        (ContentPack candidate) => candidate.id == packId,
        orElse: () => throw StateError('no program with pack id "$packId"'),
      );
      final ProgressState? progress = await repository.progressFor(pack.id);
      final DateTime today = await ref.watch(currentDateProvider.future);

      final ScheduleSpec schedule = pack.schedule;
      final ConsecutiveCommitmentSpec? commitment =
          schedule is ConsecutiveCommitmentSpec ? schedule : null;
      return ProgramDetail(
        pack: pack,
        progress: progress,
        restartPolicy: commitment?.policy.name,
        remainingDates: commitment == null
            ? const <DateTime>[]
            : Projection.remainingDates(
                commitment,
                progress?.fulfilledOrdinals ?? 0,
                today,
              ),
      );
    });
