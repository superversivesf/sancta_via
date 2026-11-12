// The onboarding walkthrough (Plan 2, Task 19) at `/onboarding`.
//
// Five steps, one page, linear:
//
// * **welcome** — the value statement and the free/offline note;
// * **claim** — "already further along?": for every commitment pack whose
//   schedule is a [ConsecutiveCommitmentSpec], a stepper in the brief's shape
//   ("I'm already N First Fridays in", 0..count) recording the position the
//   user already keeps. Advancing WRITES the claim (records-free composition,
//   Task 9's ruled ordinal source): `fulfilledOrdinals: N` with `lastFulfilled`
//   = the pack's last anchor occurrence strictly BEFORE today — computed
//   walking the calendar backward with the engine's own anchor resolution (the
//   mirror of `Projection.remainingDates`' forward walk) — and NO completion
//   records and NO badges (badges are earned by completion). The next
//   completion lands on the position the engine composes: persisted streak
//   plus one. An UNCHANGED advance writes nothing (the persisted state is the
//   claim: recomputing would fabricate a recent `lastFulfilled` and erase a
//   lapsed gap). Zeroing a claim this run made (back, zero, next) restores the
//   captured pre-run state exactly (fix round 1);
// * **routine** — the catalog's own routine-family packs (the seeded Angelus,
//   Hour of Mercy, Holy Rosary) as enrollment toggles through
//   [EnrollmentService], plus the meal & night anchors consent (the
//   off-by-default `nightItemsEnabled` setting — it is a settings flag, not a
//   pack). Onboarding only ADDS anchors: a switch-off of a program the user
//   already had enrolled is a local UI choice and the enrollment persists
//   (Practice owns removal); only a pack this run enrolled is un-enrolled on
//   switch-off (fix round 1). The brief's Morning Offering / Examen are not
//   seeded packs yet, so they appear here exactly when the catalog carries
//   them — the catalog is the authority, nothing is hard-coded;
// * **reminders** — the morning/evening consent toggles. Enabling one is the
//   consent that requests permission: the service's own `initialize` (Task
//   18's seam — the plugin's permission request lives there, idempotent, so
//   repeated switches never re-ask) followed by a refresh so the planner
//   re-plans with the new consent. Disabling only refreshes;
// * **done** — persists `onboardingComplete` and navigates to Today.
//
// Every provider the walkthrough touches is invalidated after a write (the
// enroll-screen convention), so Today and Progress read the post-walkthrough
// state the moment the done step lands on `/`.
//
// Date discipline: the walkthrough's "today" is `currentDateProvider` — the
// same frozen seam every screen and provider reads — reduced to a local
// midnight. No wall-clock read decides a claim.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sancta_via_devotional_engine/sancta_via_devotional_engine.dart'
    show
        BadgeRecord,
        ConsecutiveCommitmentSpec,
        ContentPack,
        NthWeekdayOfMonthSpec,
        PackFamily,
        ProgressState,
        ScheduleContext,
        ScheduleSpec;
import 'package:sancta_via_devotional_engine_riverpod/sancta_via_devotional_engine_riverpod.dart'
    show enrolledProgramsProvider, programDetailProvider, todayProgramsProvider;
import 'package:sancta_via_liturgical_calendar_riverpod/sancta_via_liturgical_calendar_riverpod.dart'
    show currentDateProvider;
import 'package:sancta_via_shared_ui/sancta_via_shared_ui.dart' hide AppLogger;

import '../../providers/app_settings_provider.dart'
    show DevotionsSettingsNotifier, devotionsSettingsProvider;
import '../../providers/content_providers.dart'
    show
        appProgramRepositoryProvider,
        contentLoadedProvider,
        programEnrolledProvider;
import '../../providers/progress_providers.dart' show progressAssemblyProvider;
import '../../providers/today_providers.dart'
    show notificationServiceProvider, todayAssemblyProvider;
import '../../repositories/program_repository.dart';
import '../../services/enrollment_service.dart';
import '../../services/notification_service.dart';
import '../../utils/logger.dart';
import '../../widgets/today/today_section_card.dart';

/// The walkthrough's steps, in order.
enum _OnboardingStep { welcome, claim, routine, reminders, done }

/// The weekday names, indexed 1–7 exactly as `DateTime` numbers weekdays.
const List<String> _weekdayNames = <String>[
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

/// The pre-run state of one commitment pack, captured before the walkthrough's
/// first write so a take-back restores it exactly (fix round 1).
class _ClaimBaseline {
  const _ClaimBaseline({required this.progress, required this.params});

  /// The persisted progress before the run, or null when the pack had none.
  final ProgressState? progress;

  /// The enrollment params before the run, or null when the pack was not
  /// enrolled (this run's enrollment is then the only row to remove).
  final Map<String, dynamic>? params;
}

/// The onboarding walkthrough screen (`/onboarding`).
class OnboardingScreen extends ConsumerStatefulWidget {
  /// Creates the walkthrough.
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  _OnboardingStep _step = _OnboardingStep.welcome;

  /// The claim position per commitment pack, 0..count (seeded from the
  /// persisted progress so a re-run shows where things stand).
  final Map<String, int> _claims = <String, int>{};

  /// The packs THIS walkthrough run claimed (zeroing one takes it back).
  final Set<String> _claimedThisRun = <String>{};

  /// The pre-run claim state per pack, captured before this run's first
  /// write so a take-back can restore it exactly (see [_applyClaims]).
  final Map<String, _ClaimBaseline> _priorClaims = <String, _ClaimBaseline>{};

  /// The routine packs THIS run enrolled (a switch-off takes back only these;
  /// a pre-existing enrollment persists — see [_toggleRoutine]).
  final Set<String> _routineAddedThisRun = <String>{};

  /// The routine-pack enrollment states (seeded from the store).
  final Map<String, bool> _routineOn = <String, bool>{};

  /// The reminder consent mirrors (seeded from the live settings).
  bool _morningReminder = false;
  bool _eveningReminder = false;

  /// The walkthrough's local midnight day (from the frozen date stream).
  DateTime? _today;

  /// The commitment packs the claim step offers, and the routine packs the
  /// routine step toggles — both re-derived from the catalog (never
  /// hard-coded), null until the catalog resolves.
  List<ContentPack>? _claimables;
  List<ContentPack>? _routinePacks;

  /// Whether the store-seeding pass ran (claim/routine/reminder mirrors).
  bool _seeded = false;

  bool _busy = false;
  String? _error;

  bool get _isFirstStep => _step == _OnboardingStep.welcome;
  bool get _isDoneStep => _step == _OnboardingStep.done;

  /// Sees the persisted claim/routine/reminder state once, when the catalog
  /// lands — a re-run of the walkthrough (Today's CTA) starts where things
  /// already stand; a fresh store seeds zeros and offs.
  Future<void> _seedFromStore(List<ContentPack> packs) async {
    final SqliteProgramRepository repository = ref.read(
      appProgramRepositoryProvider,
    );
    for (final ContentPack pack in packs) {
      final ScheduleSpec schedule = pack.schedule;
      if (schedule is ConsecutiveCommitmentSpec) {
        final ProgressState? progress = await repository.progressFor(pack.id);
        if (!mounted) {
          return;
        }
        setState(() {
          _claims[pack.id] = (progress?.fulfilledOrdinals ?? 0).clamp(
            0,
            schedule.count,
          );
        });
        continue;
      }
      if (pack.family == PackFamily.routine) {
        final bool enrolled =
            await repository.enrollmentParamsFor(pack.id) != null;
        if (!mounted) {
          return;
        }
        setState(() => _routineOn[pack.id] = enrolled);
      }
    }
    final bool morning = ref
        .read(devotionsSettingsProvider)
        .morningReminderEnabled;
    final bool evening = ref
        .read(devotionsSettingsProvider)
        .eveningReminderEnabled;
    if (!mounted) {
      return;
    }
    setState(() {
      _morningReminder = morning;
      _eveningReminder = evening;
    });
  }

  /// The claim step's writes, applied on ADVANCE (one write per step, never
  /// per spin).
  ///
  /// Two history rules (fix round 1):
  ///
  /// * **An unchanged advance writes NOTHING** — the seeded stepper already
  ///   shows the persisted claim, and the persisted state IS the claim.
  ///   Rewriting it would recompute `lastFulfilled` to the last anchor before
  ///   today (fabricating a recent fulfillment, erasing the lapse a
  ///   missed-day gap is measured from) and zero `repetitionsToday`,
  ///   contradicting the step's own "nothing is backdated" promise.
  /// * **A take-back restores the pre-run state, never destroys history** —
  ///   the pre-run progress and enrollment params are captured before the
  ///   first write; zeroing the claim this run made restores them exactly
  ///   (or, for a program this run enrolled, removes only the rows this run
  ///   wrote via `unenroll`).
  Future<void> _applyClaims() async {
    final DateTime? today = _today;
    final List<ContentPack>? claimables = _claimables;
    if (today == null || claimables == null) {
      return;
    }
    final SqliteProgramRepository repository = ref.read(
      appProgramRepositoryProvider,
    );
    final EnrollmentService service = EnrollmentService(repository: repository);
    for (final ContentPack pack in claimables) {
      final ScheduleSpec schedule = pack.schedule;
      if (schedule is! ConsecutiveCommitmentSpec) {
        continue;
      }
      final int claimed = _claims[pack.id] ?? 0;
      final ProgressState? prior = await repository.progressFor(pack.id);

      if (claimed > 0 && prior?.fulfilledOrdinals == claimed) {
        // Unchanged: the persisted state IS the claim — no write at all.
        continue;
      }
      if (claimed > 0) {
        if (!_priorClaims.containsKey(pack.id)) {
          // Capture the pre-run state BEFORE the first write, so a take-back
          // can restore it exactly (a null params map = not enrolled before).
          _priorClaims[pack.id] = _ClaimBaseline(
            progress: prior,
            params: await repository.enrollmentParamsFor(pack.id),
          );
        }
        // A claim is an enrollment plus the records-free progress write:
        // ordinals as claimed, the last anchor BEFORE today as
        // lastFulfilled, and the existing records/badges PRESERVED (a fresh
        // claim has none — the pinned shape).
        await service.enroll(pack: pack, params: <String, dynamic>{});
        await repository.saveProgress(
          ProgressState(
            packId: pack.id,
            fulfilledOrdinals: claimed,
            lastFulfilled: _lastAnchorBefore(schedule.anchor, today),
            completedItemsByDay:
                prior?.completedItemsByDay ?? const <String, String>{},
            badges: prior?.badges ?? const <BadgeRecord>[],
          ),
        );
        _claimedThisRun.add(pack.id);
        _invalidateForWrite(pack.id);
        continue;
      }
      if (_claimedThisRun.contains(pack.id)) {
        // Take-back (fix-round ruling (a)): restore the pre-run state. A
        // program this run enrolled is un-enrolled (only rows this run
        // wrote); a pre-existing enrollment is KEPT — its progress and
        // params are restored, or (when it carried no progress) only the
        // progress row this run wrote is deleted.
        final _ClaimBaseline? baseline = _priorClaims.remove(pack.id);
        if (baseline == null || baseline.params == null) {
          await repository.unenroll(pack.id);
        } else {
          if (baseline.progress != null) {
            await repository.saveProgress(baseline.progress!);
          } else {
            await repository.database.deleteProgress(pack.id);
          }
          await repository.enroll(pack.id, baseline.params!);
        }
        _claimedThisRun.remove(pack.id);
        _invalidateForWrite(pack.id);
      }
    }
  }

  /// The last date [anchor] resolved due strictly BEFORE [today] — the
  /// claim's `lastFulfilled` ("the last occurrence before today").
  ///
  /// The mirror of the engine's forward `Projection.remainingDates` walk:
  /// the same anchor resolution and local-midnight discipline, walked
  /// backward with a generous bound (an anchor recurs at least monthly, so a
  /// hit lands within ~40 days). An anchor that never resolves returns null
  /// and the claim persists WITHOUT a date — the engine's documented
  /// un-anchored claim shape (`missedVerdict` reads ordinals without a date
  /// as exactly that).
  DateTime? _lastAnchorBefore(ScheduleSpec anchor, DateTime today) {
    const ScheduleContext context = ScheduleContext();
    DateTime day = DateTime(today.year, today.month, today.day);
    for (int walked = 0; walked < 1500; walked++) {
      day = DateTime(day.year, day.month, day.day - 1);
      if (anchor.resolve(day, context).due) {
        return day;
      }
    }
    return null;
  }

  /// Enroll or un-enroll one routine pack (the SwitchListTile's write).
  ///
  /// Onboarding only ADDS anchors (fix-round ruling (b)): a switch-on enrolls
  /// the pack (remembering when the enrollment is this run's), and a
  /// switch-off is a LOCAL UI choice — only a pack THIS run enrolled is
  /// un-enrolled. A program the user already had enrolled stays enrolled (and
  /// keeps its progress): the walkthrough never destroys history it did not
  /// create, and Practice owns removal.
  Future<void> _toggleRoutine(ContentPack pack, bool enroll) async {
    final SqliteProgramRepository repository = ref.read(
      appProgramRepositoryProvider,
    );
    try {
      if (enroll) {
        if (await repository.enrollmentParamsFor(pack.id) == null) {
          _routineAddedThisRun.add(pack.id);
        }
        await EnrollmentService(
          repository: repository,
        ).enroll(pack: pack, params: <String, dynamic>{});
        _invalidateForWrite(pack.id);
        return;
      }
      if (_routineAddedThisRun.contains(pack.id)) {
        await repository.unenroll(pack.id);
        _routineAddedThisRun.remove(pack.id);
        _invalidateForWrite(pack.id);
      }
    } catch (error, stackTrace) {
      AppLogger.error(
        'Onboarding routine toggle failed for "${pack.id}"',
        error,
        stackTrace,
        'ONBOARD',
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _routineOn[pack.id] = !enroll;
        _error = 'Could not save that change. Please try again.';
      });
    }
  }

  /// The meal & night anchors consent (the off-by-default settings flag).
  Future<void> _toggleNightItems(bool enabled) {
    return ref
        .read(devotionsSettingsProvider.notifier)
        .setNightItemsEnabled(enabled);
  }

  /// The reminder consent toggles. Enabling IS the consent that requests
  /// permission: the service's `initialize` (Task 18's seam — the plugin's
  /// permission request lives inside, idempotent) runs once, then a re-plan
  /// applies the new consent. Disabling only re-plans.
  ///
  /// Fix round 2: enabling ALSO opens the SHARED master gate
  /// (`baseSettingsProvider.notificationsEnabled`) in the same step — the
  /// gate closes the whole plan (Task 20 fix round 1), so a consent taken
  /// here must yield scheduled reminders; the write happens BEFORE the
  /// refresh below and persists through the base-settings setter. A
  /// disabling write never closes the gate (the walkthrough exposes no
  /// master switch; only the settings screen's own switch governs closing
  /// it again).
  Future<void> _toggleReminder({
    required bool morning,
    required bool enabled,
  }) async {
    // The gate write precedes the consent write (the same step): the
    // refresh at the end of this method then plans over the gate-open
    // state the walkthrough just persisted.
    if (enabled) {
      await ref
          .read(baseSettingsProvider.notifier)
          .setNotificationsEnabled(true);
    }
    final DevotionsSettingsNotifier settings = ref.read(
      devotionsSettingsProvider.notifier,
    );
    if (morning) {
      await settings.setMorningReminderEnabled(enabled);
    } else {
      await settings.setEveningReminderEnabled(enabled);
    }
    final NotificationService service = ref.read(notificationServiceProvider);
    if (enabled) {
      await service.initialize();
    }
    await service.refresh();
  }

  /// Invalidates every provider that reads user state after a write (the
  /// enroll-screen convention).
  void _invalidateForWrite(String packId) {
    ref.invalidate(programEnrolledProvider(packId));
    ref.invalidate(programDetailProvider(packId));
    ref.invalidate(todayProgramsProvider);
    ref.invalidate(enrolledProgramsProvider);
    ref.invalidate(todayAssemblyProvider);
    ref.invalidate(progressAssemblyProvider);
  }

  /// Advances one step; the claim step's advance persists its writes first.
  Future<void> _advance() async {
    if (_busy) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_step == _OnboardingStep.claim) {
        await _applyClaims();
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _step = switch (_step) {
          _OnboardingStep.welcome => _OnboardingStep.claim,
          _OnboardingStep.claim => _OnboardingStep.routine,
          _OnboardingStep.routine => _OnboardingStep.reminders,
          _OnboardingStep.reminders => _OnboardingStep.done,
          _OnboardingStep.done => _OnboardingStep.done,
        };
        _busy = false;
      });
    } catch (error, stackTrace) {
      AppLogger.error(
        'Onboarding advance failed',
        error,
        stackTrace,
        'ONBOARD',
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _busy = false;
        _error = 'Something went wrong saving your setup. Please try again.';
      });
    }
  }

  /// The done step: persist `onboardingComplete` and open Today.
  Future<void> _finish() async {
    if (_busy) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(devotionsSettingsProvider.notifier)
          .setOnboardingComplete(true);
      if (!mounted) {
        return;
      }
      context.go('/');
    } catch (error, stackTrace) {
      AppLogger.error(
        'Onboarding completion failed',
        error,
        stackTrace,
        'ONBOARD',
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _busy = false;
        _error = 'Something went wrong saving your setup. Please try again.';
      });
    }
  }

  /// Steps one back (never before the welcome).
  void _stepBack() {
    setState(() {
      _step = switch (_step) {
        _OnboardingStep.claim => _OnboardingStep.welcome,
        _OnboardingStep.routine => _OnboardingStep.claim,
        _OnboardingStep.reminders => _OnboardingStep.routine,
        _OnboardingStep.done => _OnboardingStep.reminders,
        _OnboardingStep.welcome => _OnboardingStep.welcome,
      };
    });
  }

  /// Steps the claim stepper by [delta]; the row clamps itself 0..count.
  void _stepClaim(String packId, int delta) {
    setState(() {
      _claims[packId] = (_claims[packId] ?? 0) + delta;
    });
  }

  /// The claim row's label — the brief's "I'm already N First Fridays in",
  /// with the weekday derived from the pack's own anchor (never hard-coded).
  String _claimLabel(ConsecutiveCommitmentSpec spec, int claimed) {
    final ScheduleSpec anchor = spec.anchor;
    if (anchor is NthWeekdayOfMonthSpec) {
      return "I'm already $claimed ${_weekdayNames[anchor.weekday - 1]}s in";
    }
    return "I'm already $claimed in";
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<ContentPack>> catalog = ref.watch(
      contentLoadedProvider,
    );
    final AsyncValue<DateTime> clock = ref.watch(currentDateProvider);
    final DateTime? now = clock.valueOrNull;
    if (now != null) {
      _today = DateTime(now.year, now.month, now.day);
    }
    final List<ContentPack>? packs = catalog.valueOrNull;
    if (packs != null) {
      if (!_seeded) {
        _seeded = true;
        unawaited(_seedFromStore(packs));
      }
      _claimables = <ContentPack>[
        for (final ContentPack pack in packs)
          if (pack.schedule is ConsecutiveCommitmentSpec) pack,
      ];
      _routinePacks = <ContentPack>[
        for (final ContentPack pack in packs)
          if (pack.family == PackFamily.routine) pack,
      ];
    }

    final Widget body;
    if (packs == null || clock.isLoading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (catalog.hasError) {
      body = const Center(
        child: Text(
          'The devotional catalog could not be loaded. Try reopening the '
          'app.',
          textAlign: TextAlign.center,
        ),
      );
    } else {
      body = switch (_step) {
        _OnboardingStep.welcome => _welcomeStep(),
        _OnboardingStep.claim => _claimStep(),
        _OnboardingStep.routine => _routineStep(),
        _OnboardingStep.reminders => _remindersStep(),
        _OnboardingStep.done => _doneStep(),
      };
    }

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Getting started'),
      ),
      body: Stack(
        children: <Widget>[
          body,
          if (_error != null)
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  key: const Key('onboarding_error'),
                  _error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: _navBar(),
    );
  }

  /// The walkthrough's bottom navigation: Back (hidden on done, disabled on
  /// welcome), then the step's forward action.
  Widget _navBar() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Row(
          children: <Widget>[
            if (!_isDoneStep) ...<Widget>[
              TextButton.icon(
                key: const Key('onboarding_back'),
                onPressed: _isFirstStep || _busy ? null : _stepBack,
                icon: const Icon(Icons.chevron_left),
                label: const Text('Back'),
              ),
              const Spacer(),
              FilledButton.icon(
                key: const Key('onboarding_next'),
                onPressed: _busy ? null : _advance,
                icon: const Icon(Icons.chevron_right),
                label: Text(_isFirstStep ? 'Begin' : 'Next'),
              ),
            ] else ...<Widget>[
              const Spacer(),
              FilledButton.icon(
                key: const Key('onboarding_done'),
                onPressed: _busy ? null : _finish,
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('Done'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// The welcome step: the value statement and the free/offline note.
  Widget _welcomeStep() {
    return ListView(
      key: const Key('onboarding_welcome'),
      padding: const EdgeInsets.all(16),
      children: const <Widget>[
        TodaySectionCard(
          title: 'Pray the day with the Church',
          icon: Icons.self_improvement,
          children: <Widget>[
            Padding(
              padding: EdgeInsets.symmetric(vertical: 4),
              child: Text(
                'Sancta Via gathers the Church’s daily rhythm — the Angelus, '
                'the Hour of Mercy, the Rosary, the First Fridays and First '
                'Saturdays, novenas, and the Total Consecration — into one '
                'quiet app that walks you through every prayer, step by '
                'step.',
              ),
            ),
          ],
        ),
        TodaySectionCard(
          title: 'Free, and yours to keep',
          icon: Icons.cloud_off_outlined,
          children: <Widget>[
            Padding(
              padding: EdgeInsets.symmetric(vertical: 4),
              child: Text(
                'The app is free, and everything is stored on your device. '
                'The liturgical calendar and every devotion work offline — '
                'no account, no subscription.',
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// The claim step: one stepper per commitment pack.
  Widget _claimStep() {
    final List<ContentPack> packs = _claimables ?? const <ContentPack>[];
    return ListView(
      key: const Key('claim_step'),
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        const TodaySectionCard(
          title: 'Already further along?',
          icon: Icons.flag_outlined,
          children: <Widget>[
            Padding(
              padding: EdgeInsets.symmetric(vertical: 4),
              child: Text(
                'Step each program to where you already are. Your next '
                'completions pick up from there — nothing is backdated, and '
                'no badges are claimed (badges are earned by completion).',
              ),
            ),
          ],
        ),
        for (final ContentPack pack in packs) _claimRow(pack),
      ],
    );
  }

  /// One commitment pack's claim row: the pack's own title, the engine-
  /// derived "already N in" label, and the 0..count stepper.
  Widget _claimRow(ContentPack pack) {
    final ScheduleSpec schedule = pack.schedule;
    if (schedule is! ConsecutiveCommitmentSpec) {
      return const SizedBox.shrink();
    }
    final int claimed = _claims[pack.id] ?? 0;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              pack.title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              _claimLabel(schedule, claimed),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                IconButton(
                  key: Key('claim_minus_${pack.id}'),
                  onPressed: claimed == 0
                      ? null
                      : () => _stepClaim(pack.id, -1),
                  icon: const Icon(Icons.remove_circle_outline),
                ),
                Text(
                  '$claimed',
                  key: Key('claim_value_${pack.id}'),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                IconButton(
                  key: Key('claim_plus_${pack.id}'),
                  onPressed: claimed >= schedule.count
                      ? null
                      : () => _stepClaim(pack.id, 1),
                  icon: const Icon(Icons.add_circle_outline),
                ),
                const Spacer(),
                Text(
                  'of ${schedule.count}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// The routine step: the catalog's own routine-family packs, plus the meal
  /// & night anchors consent (a settings flag, not a pack).
  Widget _routineStep() {
    final List<ContentPack> packs = _routinePacks ?? const <ContentPack>[];
    final bool nightItems = ref
        .watch(devotionsSettingsProvider)
        .nightItemsEnabled;
    return ListView(
      key: const Key('routine_step'),
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        const TodaySectionCard(
          title: 'Your daily anchors',
          icon: Icons.schedule,
          children: <Widget>[
            Padding(
              padding: EdgeInsets.symmetric(vertical: 4),
              child: Text(
                'Turn on the prayers you want woven into today. Each one '
                'shows up on Today at its own hour — and you can change '
                'these any time in Practice.',
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(vertical: 4),
              child: Text(
                'Turning a switch off here never removes a program you '
                'already had enrolled — its enrollment and progress stay; '
                'Practice manages removal.',
              ),
            ),
          ],
        ),
        for (final ContentPack pack in packs)
          SwitchListTile(
            key: Key('routine_toggle_${pack.id}'),
            value: _routineOn[pack.id] ?? false,
            title: Text(pack.title),
            onChanged: (bool value) {
              setState(() => _routineOn[pack.id] = value);
              unawaited(_toggleRoutine(pack, value));
            },
          ),
        const Divider(),
        SwitchListTile(
          key: const Key('routine_toggle_night_items'),
          value: nightItems,
          title: const Text('Meal & night anchors'),
          subtitle: const Text(
            'Adds mealtime and night prayer anchors to Today, and lets '
            'them remind you. These are off by default.',
          ),
          onChanged: (bool value) {
            unawaited(_toggleNightItems(value));
          },
        ),
      ],
    );
  }

  /// The reminders step: the morning and evening consent toggles.
  Widget _remindersStep() {
    return ListView(
      key: const Key('reminders_step'),
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        const TodaySectionCard(
          title: 'A gentle reminder',
          icon: Icons.notifications_none,
          children: <Widget>[
            Padding(
              padding: EdgeInsets.symmetric(vertical: 4),
              child: Text(
                'When you have something due, one quiet nudge can arrive '
                'that morning — and one in the evening — instead of you '
                'having to remember.',
              ),
            ),
          ],
        ),
        SwitchListTile(
          key: const Key('reminder_toggle_morning'),
          value: _morningReminder,
          title: const Text('Morning reminders'),
          onChanged: (bool value) {
            setState(() => _morningReminder = value);
            unawaited(_toggleReminder(morning: true, enabled: value));
          },
        ),
        SwitchListTile(
          key: const Key('reminder_toggle_evening'),
          value: _eveningReminder,
          title: const Text('Evening reminders'),
          onChanged: (bool value) {
            setState(() => _eveningReminder = value);
            unawaited(_toggleReminder(morning: false, enabled: value));
          },
        ),
        const SizedBox(height: 8),
        Text(
          'On iPhone and Mac, reminders arrive quietly until you allow '
          'notifications in system settings.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  /// The done step: the closing note; the bottom bar's Done completes.
  Widget _doneStep() {
    return ListView(
      key: const Key('done_step'),
      padding: const EdgeInsets.all(16),
      children: const <Widget>[
        TodaySectionCard(
          title: 'You’re set.',
          icon: Icons.check_circle_outline,
          children: <Widget>[
            Padding(
              padding: EdgeInsets.symmetric(vertical: 4),
              child: Text(
                'Your setup is saved on this device. Everything stays free '
                'and offline — change your anchors, reminders, and programs '
                'any time from Practice and Settings.',
              ),
            ),
          ],
        ),
      ],
    );
  }
}
