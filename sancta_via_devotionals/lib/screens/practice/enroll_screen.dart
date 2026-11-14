// The enrollment flow (Plan 2, Task 15): the commitment-aware derive-and-enroll
// page behind `/program/:packId/enroll`.
//
// The screen is a thin controller over [EnrollmentService]: every scheduling
// rule lives in the service / engine, and this file owns only the choices and
// their presentation:
//
// * a consecration pack (`reminders.feastAnchor`) offers its feast anchor
//   entries and a year in which to keep the feast, previews Day 1 through
//   `ConsecrationPlanner.startFor`, and — after enrolling — offers the day-34
//   milestone note (the consecration day itself);
// * a planned series (the 54-day novena) shows the two-phase explainer (days
//   1–27 petition, days 28–54 thanksgiving, with the mystery rotation), a
//   user-picked day-1 date field, and the strict/permissive missed-day choice
//   whose initial selection comes from the app setting;
// * a commitment (or any other pack) enrolls as-is, with a fresh progress
//   start and the engine's next-occurrence ordinal math untouched.
//
// After a successful enroll the screen invalidates the Task 14 enrolled signal
// (the detail chip flips), the catalog, and the wrapper's Today/detail/library
// providers, so the derived pack — whose `schedule.startDate` the service
// patched — appears naturally on Today from its own start date. The seeded
// `content_version` is never bumped: reading the catalog again is a no-op
// migration, not a re-seed.
//
// Date discipline: date choices come from `currentDateProvider` and render as
// `yyyy-MM-dd`; no wall-clock read decides a schedule.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sancta_via_devotional_engine/sancta_via_devotional_engine.dart'
    show
        ConsecrationPlanner,
        ConsecutiveCommitmentSpec,
        ContentPack,
        NthWeekdayOfMonthSpec,
        ScheduleSpec,
        SessionSeriesSpec;
import 'package:sancta_via_devotional_engine_riverpod/sancta_via_devotional_engine_riverpod.dart'
    show enrolledProgramsProvider, programDetailProvider, todayProgramsProvider;
import 'package:sancta_via_liturgical_calendar_riverpod/sancta_via_liturgical_calendar_riverpod.dart'
    show currentDateProvider;

import '../../providers/app_settings_provider.dart'
    show missedDayDefaultPolicyProvider;
import '../../providers/content_providers.dart'
    show
        appProgramRepositoryProvider,
        contentLoadedProvider,
        programEnrolledProvider;
import '../../services/enrollment_service.dart';
import '../../utils/logger.dart';
import '../../widgets/today/today_section_card.dart';
import '../../widgets/devotions/kneeling_prayer_glyph.dart';

/// The zero-padded `yyyy-MM-dd` rendering of a local date — the engine's
/// date-discipline shape.
String _stamp(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// The month names, indexed 1–12.
const List<String> _monthNames = <String>[
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

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

/// The ordinal word of a 1-based [nth] occurrence.
String _nthWord(int nth) {
  const List<String> words = <String>[
    'first',
    'second',
    'third',
    'fourth',
    'fifth',
  ];
  return nth >= 1 && nth <= words.length ? words[nth - 1] : '$nth';
}

/// Capitalizes a lower-case engine/variant value for a title.
String _capitalize(String value) =>
    value.isEmpty ? value : '${value[0].toUpperCase()}${value.substring(1)}';

/// The `days <min>–<max>` span of a phase.
String _daySpan(int min, int max) => min == max ? 'day $min' : 'days $min–$max';

/// The enrollment flow route for [packId].
class EnrollScreen extends ConsumerStatefulWidget {
  /// Creates the enrollment flow for the pack the route carried in.
  const EnrollScreen({required this.packId, super.key});

  /// The pack id the route's `/program/:packId/enroll` path carried in.
  final String packId;

  @override
  ConsumerState<EnrollScreen> createState() => _EnrollScreenState();
}

class _EnrollScreenState extends ConsumerState<EnrollScreen> {
  /// The last resolved pack. Kept across a post-enroll catalog re-read so the
  /// success state does not unmount while the invalidated providers reload.
  ContentPack? _pack;

  /// The last resolved clock day (local midnight).
  DateTime? _today;

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<ContentPack>> catalog = ref.watch(
      contentLoadedProvider,
    );
    final AsyncValue<DateTime> clock = ref.watch(currentDateProvider);

    final List<ContentPack>? packs = catalog.valueOrNull;
    bool missing = false;
    if (packs != null) {
      bool found = false;
      for (final ContentPack candidate in packs) {
        if (candidate.id == widget.packId) {
          _pack = candidate;
          found = true;
          break;
        }
      }
      missing = !found && _pack == null;
    }
    final DateTime? now = clock.valueOrNull;
    if (now != null) {
      _today = DateTime(now.year, now.month, now.day);
    }

    final ContentPack? pack = _pack;
    final DateTime? today = _today;
    return Scaffold(
      appBar: AppBar(title: Text(pack?.title ?? 'Enroll')),
      body: missing
          ? const Center(
              child: Text(
                'This program was not found in the catalog.',
                textAlign: TextAlign.center,
              ),
            )
          : pack == null || today == null
          ? const Center(child: CircularProgressIndicator())
          : _EnrollFlow(pack: pack, today: today),
    );
  }
}

/// The mutable enrollment form for one resolved [pack] on [today].
class _EnrollFlow extends ConsumerStatefulWidget {
  const _EnrollFlow({required this.pack, required this.today});

  final ContentPack pack;
  final DateTime today;

  @override
  ConsumerState<_EnrollFlow> createState() => _EnrollFlowState();
}

class _EnrollFlowState extends ConsumerState<_EnrollFlow> {
  /// The chosen feast anchor (consecration packs), defaulting to the first
  /// entry the pack declares.
  FeastAnchor? _feast;

  /// The year in which the chosen feast is kept.
  int? _feastYear;

  /// The user-picked day 1 of a planned series.
  DateTime? _startDate;

  /// The chosen missed-day policy, in `MissedDayEvaluator`'s own vocabulary.
  String _policy = 'permissive';

  bool _enrolling = false;
  bool _enrolled = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final List<FeastAnchor> anchors = FeastAnchor.fromPack(widget.pack);
    if (anchors.isNotEmpty) {
      _feast = anchors.first;
      _feastYear = _nextFeastYear(anchors.first);
    }
    _startDate = widget.today;
    // The default missed-day policy is the app setting; an unexpected stored
    // value falls back to the app's documented permissive default.
    final String configured = ref.read(missedDayDefaultPolicyProvider);
    _policy = configured == 'strict' ? 'strict' : 'permissive';
  }

  /// The next occurrence of [anchor]'s nominal feast, on or after today.
  int _nextFeastYear(FeastAnchor anchor) {
    final DateTime thisYear = anchor.dateIn(widget.today.year);
    return thisYear.isBefore(widget.today)
        ? widget.today.year + 1
        : widget.today.year;
  }

  bool get _isConsecration => _feast != null;

  bool get _isSeries => widget.pack.schedule is SessionSeriesSpec;

  /// A planned series that is NOT a consecration (the 54-day shape): the
  /// consecration is a series too, but its choices are the feast and year, not
  /// a user-picked start date.
  bool get _isPlannedSeries => _isSeries && !_isConsecration;

  bool get _isCommitment => widget.pack.schedule is ConsecutiveCommitmentSpec;

  DateTime? get _feastDate {
    final FeastAnchor? anchor = _feast;
    final int? year = _feastYear;
    if (anchor == null || year == null) {
      return null;
    }
    return anchor.dateIn(year);
  }

  /// The params the service turns into the stored enrollment.
  Map<String, dynamic> _params() {
    if (_isConsecration) {
      return <String, dynamic>{'feast': _stamp(_feastDate!)};
    }
    if (_isSeries) {
      return <String, dynamic>{
        'startDate': _stamp(_startDate!),
        'restartPolicy': _policy,
      };
    }
    return <String, dynamic>{};
  }

  Future<void> _pickStartDate() async {
    final DateTime initial = _startDate ?? widget.today;
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(initial.year - 1),
      lastDate: DateTime(initial.year + 5),
    );
    if (picked != null && mounted) {
      setState(() {
        _startDate = DateTime(picked.year, picked.month, picked.day);
      });
    }
  }

  Future<void> _enroll() async {
    if (_enrolling) {
      return;
    }
    setState(() {
      _enrolling = true;
      _error = null;
    });
    final EnrollmentService service = EnrollmentService(
      repository: ref.read(appProgramRepositoryProvider),
    );
    try {
      await service.enroll(pack: widget.pack, params: _params());
      if (!mounted) {
        return;
      }
      // The Task 14 carry pin: flip the enrolled signal, then refresh every
      // provider built on the catalog so the derived pack (and its patched
      // start date) is what Today and the detail read from now on.
      ref.invalidate(programEnrolledProvider(widget.pack.id));
      ref.invalidate(contentLoadedProvider);
      ref.invalidate(programDetailProvider(widget.pack.id));
      ref.invalidate(todayProgramsProvider);
      ref.invalidate(enrolledProgramsProvider);
      setState(() {
        _enrolling = false;
        _enrolled = true;
      });
    } on Object catch (error, stackTrace) {
      AppLogger.error(
        'Enrollment failed for "${widget.pack.id}"',
        error,
        stackTrace,
        'ENROLL',
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _enrolling = false;
        _error = 'Enrollment could not be saved. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_enrolled) {
      return _successView();
    }
    return ListView(
      children: <Widget>[
        _summaryCard(),
        if (_isConsecration) _consecrationCard(),
        if (_isPlannedSeries) ...<Widget>[
          _startDateCard(),
          _seriesExplainerCard(),
        ],
        if (_isCommitment) _commitmentCard(),
        if (_isPlannedSeries && _policyVariants().isNotEmpty) _policyCard(),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              _error!,
              key: const Key('enroll_error'),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: FilledButton.icon(
            key: const Key('enroll_button'),
            onPressed: _enrolling ? null : _enroll,
            icon: _enrolling
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check_circle_outline),
            label: Text(_enrolling ? 'Enrolling…' : 'Enroll'),
          ),
        ),
      ],
    );
  }

  /// The post-enroll state: a confirmation (plus the consecration day-34
  /// milestone note) and the Done action back to the detail.
  Widget _successView() {
    final DateTime? feast = _feastDate;
    return ListView(
      children: <Widget>[
        TodaySectionCard(
          key: const Key('enroll_success'),
          title: 'Enrolled',
          icon: const Icon(Icons.check_circle_outline),
          children: <Widget>[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 4),
              child: Text(
                'You are enrolled. Your first session is due from the '
                'program’s own start date.',
              ),
            ),
            if (_isConsecration && feast != null)
              ListTile(
                key: const Key('day34_milestone'),
                leading: const Icon(Icons.flag_outlined),
                title: Text('Day 34 — ${_stamp(feast)}'),
                subtitle: const Text(
                  'Your consecration day. Renew your consecration every day.',
                ),
              ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: FilledButton(
            key: const Key('enroll_done_button'),
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/program/${widget.pack.id}');
              }
            },
            child: const Text('Done'),
          ),
        ),
      ],
    );
  }

  /// The pack-level enrollment summary: the schedule's own count/anchor rule
  /// for a commitment, the authored span for a planned series.
  Widget _summaryCard() {
    final String intro;
    final ScheduleSpec schedule = widget.pack.schedule;
    if (schedule case ConsecutiveCommitmentSpec(
      :final ScheduleSpec anchor,
      :final int count,
    )) {
      intro =
          'This program enrolls as it stands: $count fulfillments of '
          '${_anchorPhrase(anchor)}. Your first anchor is the next '
          'occurrence; progress starts fresh.';
    } else if (schedule case SessionSeriesSpec(:final int lengthDays)) {
      intro =
          'This program runs $lengthDays consecutive days. Your first '
          'session is due on the start date you choose.';
    } else {
      intro = 'This program enrolls as it stands.';
    }
    return TodaySectionCard(
      title: 'Enrollment',
      icon: const KneelingPrayerGlyph(),
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text(intro),
        ),
      ],
    );
  }

  /// The commitment's anchor phrase ("the first Saturday of each month").
  String _anchorPhrase(ScheduleSpec anchor) {
    if (anchor is NthWeekdayOfMonthSpec) {
      return 'the ${_nthWord(anchor.nth)} '
          '${_weekdayNames[anchor.weekday - 1]} of each month';
    }
    return 'its recurring anchor';
  }

  /// The consecration choices: the pack's feast anchor entries, the year the
  /// feast is kept, and the planner-previewed Day 1 / Day 34 dates.
  Widget _consecrationCard() {
    final DateTime? feast = _feastDate;
    final DateTime? start = feast == null ? null : _startFor(feast);
    final List<FeastAnchor> anchors = FeastAnchor.fromPack(widget.pack);
    final int firstYear = widget.today.year;
    return TodaySectionCard(
      key: const Key('feast_picker'),
      title: 'Consecration day',
      icon: const Icon(Icons.church_outlined),
      children: <Widget>[
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 4),
          child: Text(
            'Choose the feast on which you will make your consecration. '
            'Day 1 begins 33 days before it.',
          ),
        ),
        if (anchors.isNotEmpty)
          RadioGroup<String>(
            key: const Key('feast_radio_group'),
            groupValue: _feast?.feast,
            onChanged: (String? value) {
              if (value == null) {
                return;
              }
              final FeastAnchor chosen = anchors.firstWhere(
                (FeastAnchor anchor) => anchor.feast == value,
              );
              setState(() {
                _feast = chosen;
                _feastYear = _nextFeastYear(chosen);
              });
            },
            child: Column(
              children: <Widget>[
                for (final FeastAnchor anchor in anchors)
                  RadioListTile<String>(
                    key: ValueKey<String>('feast_option_${anchor.feast}'),
                    value: anchor.feast,
                    title: Text(_capitalize(anchor.feast)),
                    subtitle: Text(
                      '${_monthNames[anchor.month - 1]} ${anchor.day}',
                    ),
                  ),
              ],
            ),
          ),
        if (anchors.isNotEmpty)
          ListTile(
            dense: true,
            title: const Text('Year'),
            trailing: DropdownButton<int>(
              key: const Key('feast_year'),
              value: _feastYear,
              items: <DropdownMenuItem<int>>[
                for (int year = firstYear; year <= firstYear + 10; year++)
                  DropdownMenuItem<int>(value: year, child: Text('$year')),
              ],
              onChanged: (int? value) {
                if (value != null) {
                  setState(() => _feastYear = value);
                }
              },
            ),
          ),
        if (start != null && feast != null) ...<Widget>[
          ListTile(
            key: const Key('consecration_start_preview'),
            dense: true,
            leading: const Icon(Icons.flag_outlined),
            title: Text(_stamp(start)),
            subtitle: const Text('Day 1'),
          ),
          ListTile(
            key: const Key('consecration_day34_preview'),
            dense: true,
            leading: const Icon(Icons.flag),
            title: Text(_stamp(feast)),
            subtitle: const Text('Day 34 — consecration day'),
          ),
        ],
      ],
    );
  }

  /// The planned series' user-picked day-1 date field.
  Widget _startDateCard() {
    return TodaySectionCard(
      title: 'Day 1',
      icon: const Icon(Icons.event),
      children: <Widget>[
        ListTile(
          key: const Key('start_date_field'),
          dense: true,
          leading: const Icon(Icons.today_outlined),
          title: Text(_stamp(_startDate ?? widget.today)),
          subtitle: const Text('Tap to pick the day the program begins'),
          onTap: _pickStartDate,
        ),
      ],
    );
  }

  /// The planned series' phase explainer: one paragraph for the 54-day shape
  /// (its two phases and the mystery rotation), plus the pack's own phase rows.
  Widget _seriesExplainerCard() {
    final int length = (widget.pack.schedule as SessionSeriesSpec).lengthDays;
    final String paragraph = length == 54
        ? 'Days 1–27 are the petition phase, asking for the graces you seek. '
              'Days 28–54 are the thanksgiving phase, thanking God for them. '
              'Each decade follows the joyful, sorrowful, and glorious '
              'mysteries in rotation.'
        : 'This guided series begins on the day you pick and runs '
              '$length consecutive days.';
    return TodaySectionCard(
      title: length == 54 ? 'How the 54 days unfold' : 'How it unfolds',
      icon: const Icon(Icons.auto_stories),
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text(paragraph),
        ),
        ..._phaseRows(),
      ],
    );
  }

  /// The pack's phase rows, grouped from the day variants (petition days
  /// 1–27 / thanksgiving days 28–54 for the 54-day novena).
  List<Widget> _phaseRows() {
    final Map<String, List<int>> phases = <String, List<int>>{};
    for (final Map<String, dynamic> variant in widget.pack.variants) {
      final Object? phase = variant['phase'];
      final Object? dayIndex = variant['dayIndex'];
      if (phase is! String) {
        continue;
      }
      final List<int> days = phases.putIfAbsent(phase, () => <int>[]);
      if (dayIndex is int) {
        days.add(dayIndex);
      }
    }
    return <Widget>[
      for (final MapEntry<String, List<int>> entry in phases.entries)
        ListTile(
          key: ValueKey<String>('enroll_phase_${entry.key}'),
          dense: true,
          title: Text(_capitalize(entry.key)),
          subtitle: entry.value.isEmpty
              ? null
              : Text(
                  _daySpan(
                    entry.value.reduce((int a, int b) => a < b ? a : b),
                    entry.value.reduce((int a, int b) => a > b ? a : b),
                  ),
                ),
        ),
    ];
  }

  /// The pack's missed-day policy variants (the 54-day's strict/permissive
  /// rows), in authored order.
  List<Map<String, dynamic>> _policyVariants() {
    return <Map<String, dynamic>>[
      for (final Map<String, dynamic> variant in widget.pack.variants)
        if (variant['policy'] is String) variant,
    ];
  }

  /// The missed-day choice, preselected from the app setting.
  Widget _policyCard() {
    return TodaySectionCard(
      key: const Key('policy_options'),
      title: 'If a day is missed',
      icon: const Icon(Icons.rule),
      children: <Widget>[
        RadioGroup<String>(
          key: const Key('policy_radio_group'),
          groupValue: _policy,
          onChanged: (String? value) {
            if (value != null) {
              setState(() => _policy = value);
            }
          },
          child: Column(
            children: <Widget>[
              for (final Map<String, dynamic> variant in _policyVariants())
                RadioListTile<String>(
                  key: ValueKey<String>('policy_option_${variant['policy']}'),
                  value: variant['policy'] as String,
                  title: Text(_capitalize(variant['policy'] as String)),
                  subtitle: variant['note'] is String
                      ? Text(variant['note'] as String)
                      : null,
                ),
            ],
          ),
        ),
      ],
    );
  }

  /// The commitment's fresh-start note (the ordinal math counts from the next
  /// occurrence; nothing is pre-filled).
  Widget _commitmentCard() {
    return const TodaySectionCard(
      title: 'Starting fresh',
      icon: const Icon(Icons.playlist_add_check),
      children: <Widget>[
        Padding(
          padding: EdgeInsets.symmetric(vertical: 4),
          child: Text(
            'No fulfillments are recorded yet. The first anchor you keep '
            'counts as the first fulfillment.',
          ),
        ),
      ],
    );
  }

  /// The consecration preparation's Day 1, via the real engine planner.
  DateTime _startFor(DateTime feast) => ConsecrationPlanner.startFor(feast);
}
