// The program detail screen (Plan 2, Task 14): one catalog pack's page.
//
// Everything renders from the pack's own data — no per-id special cases:
//
// * the family chip and (when the Task 5/6 enrolled ruling fires —
//   `enrollmentParamsFor(packId) != null`) the enrolled chip in place of
//   the Enroll CTA (Task 15 completes the flow's states; the detail-only
//   state is this task's minimum);
// * the description, derived from the schedule's own shape (count, anchor
//   rule, grace windows — never hardcoded per pack);
// * the schedule preview: a commitment's projected anchor dates come from
//   the wrapper's `programDetailProvider` (the engine's
//   `Projection.remainingDates`, progress-aware), a weekly loop renders its
//   weekday table, a time-of-day anchor its daily time plus season-variant
//   explainers, and a series/Easter window their authored rule;
// * the phase explainer rows, grouped from the pack's `variants` entries
//   that carry a `phase` (e.g. the 54-day's petition 1–27 / thanksgiving
//   28–54);
// * the missed-day policy explainer rows, from the `variants` entries that
//   carry a `policy` (the 54-day's strict/permissive notes) — for a
//   consecutive commitment the row instead derives from its RestartPolicy.
//
// The Enroll CTA routes to `/program/:packId/enroll` — the stub route Task
// 15's enrollment flow page will replace.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sancta_via_devotional_engine/sancta_via_devotional_engine.dart'
    show
        ConsecutiveCommitmentSpec,
        ContentPack,
        EasterOffsetSpec,
        FixedDateSpec,
        GraceWindow,
        NthWeekdayOfMonthSpec,
        PackFamily,
        RestartPolicy,
        ScheduleSpec,
        SeasonVariant,
        SessionSeriesSpec,
        TimeOfDaySpec,
        WeeklyLoopSpec;
import 'package:sancta_via_devotional_engine_riverpod/sancta_via_devotional_engine_riverpod.dart'
    show ProgramDetail, programDetailProvider;

import '../../providers/content_providers.dart';
import '../../utils/logger.dart';
import '../../widgets/today/today_section_card.dart';

/// The zero-padded `yyyy-MM-dd` rendering of the local date (the engine's
/// date-discipline shape — every previewed date renders as its ISO stamp).
String _stamp(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// The zero-padded `HH:mm` wall-clock label of [hour]/[minute] — the
/// engine's own `TimeOfDaySpec` fallback-label shape.
String _clock(int hour, int minute) =>
    '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

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

/// The ordinal word of a 1-based [nth] occurrence ("the `<nth>` `<weekday>`…").
///
/// The shipped anchors stay within the first five; a larger `nth` — legal
/// engine input — degrades honestly to its numeral.
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

/// Capitalizes a lower-case engine/variant value for a row title.
String _capitalize(String value) =>
    value.isEmpty ? value : '${value[0].toUpperCase()}${value.substring(1)}';

/// The singular family label of a pack (the catalog groups use the plurals).
String _familyLabel(PackFamily family) => switch (family) {
  PackFamily.commitment => 'Commitment',
  PackFamily.novena => 'Novena',
  PackFamily.office => 'Office',
  PackFamily.routine => 'Routine',
  PackFamily.chaplet => 'Chaplet',
};

/// The day span a phase covers, as `days <min>–<max>` (`day <n>` when the
/// phase holds a single day).
String _daySpan(int min, int max) => min == max ? 'day $min' : 'days $min–$max';

/// The app's program detail screen for [packId].
class ProgramDetailScreen extends ConsumerWidget {
  /// Creates the detail screen for the pack the route carried in.
  const ProgramDetailScreen({required this.packId, super.key});

  /// The pack id the route's `/program/:packId` path carried in.
  final String packId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<ProgramDetail> detail = ref.watch(
      programDetailProvider(packId),
    );
    final AsyncValue<bool> enrolled = ref.watch(
      programEnrolledProvider(packId),
    );
    return Scaffold(
      appBar: AppBar(title: Text(detail.valueOrNull?.pack.title ?? 'Program')),
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object error, StackTrace stack) {
          AppLogger.error('Program detail failed', error, stack, 'PRACTICE');
          return const Center(
            child: Text(
              'This program could not be loaded. Try reopening the app.',
              textAlign: TextAlign.center,
            ),
          );
        },
        data: (ProgramDetail data) =>
            _DetailBody(detail: data, enrolled: enrolled.valueOrNull ?? false),
      ),
    );
  }
}

/// The detail body for a resolved [ProgramDetail].
class _DetailBody extends StatelessWidget {
  const _DetailBody({required this.detail, required this.enrolled});

  final ProgramDetail detail;
  final bool enrolled;

  @override
  Widget build(BuildContext context) {
    final ContentPack pack = detail.pack;
    final List<Widget> scheduleRows = _scheduleRows(detail);
    final List<Widget> phaseRows = _phaseRows(pack);
    final List<Widget> policyRows = _variantPolicyRows(pack);
    return ListView(
      children: <Widget>[
        _HeaderCard(pack: pack),
        TodaySectionCard(
          title: 'About',
          icon: Icons.info_outline,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(_describeSchedule(pack)),
            ),
          ],
        ),
        if (scheduleRows.isNotEmpty)
          TodaySectionCard(
            key: const Key('schedule_preview'),
            title: 'Schedule',
            icon: Icons.event,
            children: scheduleRows,
          ),
        if (phaseRows.isNotEmpty)
          TodaySectionCard(
            title: 'Phases',
            icon: Icons.auto_stories,
            children: phaseRows,
          ),
        if (policyRows.isNotEmpty)
          TodaySectionCard(
            title: 'Missed-day policy',
            icon: Icons.rule,
            children: policyRows,
          ),
        _EnrollSection(packId: pack.id, enrolled: enrolled),
      ],
    );
  }

  /// The description paragraph, derived from the pack's schedule shape.
  String _describeSchedule(ContentPack pack) {
    final StringBuffer buffer = StringBuffer();
    switch (pack.schedule) {
      case ConsecutiveCommitmentSpec(
        :final ScheduleSpec anchor,
        :final int count,
        :final List<GraceWindow> windows,
      ):
        buffer.write(
          '$count fulfillments of ${_anchorPhrase(anchor)}, '
          'one per anchor date.',
        );
        for (final GraceWindow window in windows) {
          buffer.write(
            ' ${_capitalize(window.item)} may be made within '
            '${window.beforeDays} days before or ${window.afterDays} days '
            'after an anchor date.',
          );
        }
      case SessionSeriesSpec(:final DateTime startDate, :final int lengthDays):
        buffer.write(
          'Day 1 begins ${_stamp(startDate)}, running $lengthDays days.',
        );
      case EasterOffsetSpec():
        buffer.write('A bounded prayer window anchored to Easter Sunday.');
      case WeeklyLoopSpec(:final Set<int> weekdays):
        buffer.write('Prayed every week on ${_weekdayList(weekdays)}.');
      case TimeOfDaySpec(:final int hour, :final int minute):
        buffer.write('Prayed every day at ${_clock(hour, minute)}.');
      case FixedDateSpec(:final int month, :final int day):
        buffer.write('Observed every ${_monthNames[month - 1]} $day.');
      case NthWeekdayOfMonthSpec(:final int weekday, :final int nth):
        buffer.write(
          'Due every month on the ${_nthWord(nth)} '
          '${_weekdayNames[weekday - 1]}.',
        );
    }
    return buffer.toString();
  }

  /// The anchor phrase of a commitment's per-position spec, as used inside
  /// "N fulfillments of the …".
  String _anchorPhrase(ScheduleSpec anchor) {
    return switch (anchor) {
      NthWeekdayOfMonthSpec(:final int weekday, :final int nth) =>
        'the ${_nthWord(nth)} ${_weekdayNames[weekday - 1]} of each month',
      WeeklyLoopSpec(:final Set<int> weekdays) =>
        'a weekly anchor (${_weekdayList(weekdays)})',
      FixedDateSpec(:final int month, :final int day) =>
        'a fixed date (${_monthNames[month - 1]} $day)',
      TimeOfDaySpec(:final int hour, :final int minute) =>
        'a daily anchor at ${_clock(hour, minute)}',
      EasterOffsetSpec() => 'an Easter-anchored date',
      SessionSeriesSpec() => 'a planned series date',
      ConsecutiveCommitmentSpec() => 'a nested commitment anchor',
    };
  }

  /// The `A, B and C` list of a weekday set, in calendar order.
  String _weekdayList(Set<int> weekdays) {
    final List<String> names = <String>[
      for (int weekday = 1; weekday <= 7; weekday++)
        if (weekdays.contains(weekday)) _weekdayNames[weekday - 1],
    ];
    if (names.length <= 1) {
      return names.isEmpty ? '' : names.first;
    }
    return '${names.sublist(0, names.length - 1).join(', ')} and '
        '${names.last}';
  }

  /// The schedule preview rows for the resolved detail.
  ///
  /// The row shape follows the schedule class: a commitment projects its
  /// remaining anchor dates (progress-aware, through the wrapper's
  /// provider) and names its restart policy; a weekly loop renders its
  /// weekday table; a time-of-day anchor renders its daily time and its
  /// season variants; a series or Easter window renders its authored rule.
  List<Widget> _scheduleRows(ProgramDetail detail) {
    final ScheduleSpec schedule = detail.pack.schedule;
    return switch (schedule) {
      ConsecutiveCommitmentSpec(:final RestartPolicy policy) => <Widget>[
        ListTile(
          key: const Key('schedule_policy_row'),
          dense: true,
          title: Text(_capitalize(policy.name)),
          subtitle: Text(_policySentence(policy)),
        ),
        for (final DateTime date in detail.remainingDates)
          ListTile(
            key: ValueKey<String>('schedule_date_${_stamp(date)}'),
            dense: true,
            leading: const Icon(Icons.event_outlined),
            title: Text(_stamp(date)),
          ),
        if (detail.remainingDates.isEmpty)
          const ListTile(
            dense: true,
            title: Text('The series is complete — nothing further is due.'),
          ),
      ],
      SessionSeriesSpec(:final DateTime startDate, :final int lengthDays) =>
        <Widget>[
          ListTile(
            dense: true,
            leading: const Icon(Icons.flag_outlined),
            title: Text(_stamp(startDate)),
            subtitle: const Text('Day 1'),
          ),
          ListTile(
            dense: true,
            leading: const Icon(Icons.flag_outlined),
            title: Text(
              _stamp(
                DateTime(
                  startDate.year,
                  startDate.month,
                  startDate.day + lengthDays - 1,
                ),
              ),
            ),
            subtitle: Text('Day $lengthDays'),
          ),
        ],
      EasterOffsetSpec(:final int startOffset, :final int lengthDays) =>
        <Widget>[
          ListTile(
            dense: true,
            leading: const Icon(Icons.event_outlined),
            title: Text('$lengthDays days'),
            subtitle: const Text('Window length'),
          ),
          ListTile(
            dense: true,
            leading: const Icon(Icons.event_outlined),
            title: Text(_easterOffsetPhrase(startOffset)),
            subtitle: const Text('Opens'),
          ),
        ],
      WeeklyLoopSpec(:final Set<int> weekdays, :final List<int>? skipMonths) =>
        <Widget>[
          for (int weekday = 1; weekday <= 7; weekday++)
            ListTile(
              key: ValueKey<String>('schedule_weekday_$weekday'),
              dense: true,
              title: Text(_weekdayNames[weekday - 1]),
              trailing: weekdays.contains(weekday)
                  ? const Text('Due')
                  : const Text('—'),
            ),
          if (skipMonths != null && skipMonths.isNotEmpty)
            ListTile(
              dense: true,
              title: Text(
                'Skipped in full: '
                '${skipMonths.map((int month) => _monthNames[month - 1]).join(', ')}',
              ),
            ),
        ],
      TimeOfDaySpec(
        :final int hour,
        :final int minute,
        :final List<SeasonVariant> variants,
      ) =>
        <Widget>[
          ListTile(
            key: const Key('schedule_anchor_row'),
            dense: true,
            leading: const Icon(Icons.schedule),
            title: Text('Every day at ${_clock(hour, minute)}'),
          ),
          for (final SeasonVariant variant in variants)
            ListTile(
              key: ValueKey<String>('schedule_variant_${variant.variantId}'),
              dense: true,
              leading: const Icon(Icons.label_outline),
              title: Text(variant.variantId),
              subtitle: Text(_variantCondition(variant)),
            ),
        ],
      FixedDateSpec(:final int month, :final int day) => <Widget>[
        ListTile(
          dense: true,
          leading: const Icon(Icons.event_outlined),
          title: Text('${_monthNames[month - 1]} $day'),
          subtitle: const Text('Every year'),
        ),
      ],
      NthWeekdayOfMonthSpec(:final int weekday, :final int nth) => <Widget>[
        ListTile(
          dense: true,
          leading: const Icon(Icons.event_outlined),
          title: Text(
            'The ${_nthWord(nth)} ${_weekdayNames[weekday - 1]} '
            'of each month',
          ),
        ),
      ],
    };
  }

  /// The restart-policy explainer sentence (the row subtitle beside the
  /// capitalized policy title).
  String _policySentence(RestartPolicy policy) => switch (policy) {
    RestartPolicy.strict =>
      'A missed anchor date voids the count so far; the series restarts '
          'from the miss.',
    RestartPolicy.permissive =>
      'The count continues across a missed anchor date; the miss itself is '
          'still recorded.',
  };

  /// When an Easter-offset window opens, as an honest rule phrase (no
  /// wall-clock year is consulted — the window re-anchors every year).
  String _easterOffsetPhrase(int startOffset) {
    if (startOffset == 0) {
      return 'On Easter Sunday';
    }
    return startOffset < 0
        ? '${-startOffset} days before Easter Sunday'
        : '$startOffset days after Easter Sunday';
  }

  /// The match condition of a season variant: its months and/or its season
  /// keys, as rendered for the variant explainer row.
  String _variantCondition(SeasonVariant variant) {
    final List<String> parts = <String>[
      if (variant.months.isNotEmpty)
        'in ${variant.months.map((int month) => _monthNames[month - 1]).join(', ')}',
      if (variant.seasons != null && variant.seasons!.isNotEmpty)
        'during ${variant.seasons!.join(', ')}',
    ];
    return parts.join(' or ');
  }

  /// The phase explainer rows, grouped from the pack's day variants: one
  /// row per distinct `phase` value, in first-appearance order, with the
  /// day span the phase covers.
  List<Widget> _phaseRows(ContentPack pack) {
    final Map<String, List<int>> phases = <String, List<int>>{};
    for (final Map<String, dynamic> variant in pack.variants) {
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
          key: ValueKey<String>('phase_row_${entry.key}'),
          dense: true,
          title: Text(_capitalize(entry.key)),
          subtitle: entry.value.isEmpty
              ? null
              : Text(
                  _daySpan(
                    entry.value.reduce(math.min),
                    entry.value.reduce(math.max),
                  ),
                ),
        ),
    ];
  }

  /// The missed-day policy explainer rows, from the pack's `variants`
  /// entries that carry a `policy` value and (typically) an explanatory
  /// `note` — the 54-day's strict/permissive rows.
  List<Widget> _variantPolicyRows(ContentPack pack) {
    return <Widget>[
      for (final Map<String, dynamic> variant in pack.variants)
        if (variant['policy'] is String)
          ListTile(
            key: ValueKey<String>('policy_row_${variant['policy']}'),
            dense: true,
            title: Text(_capitalize(variant['policy'] as String)),
            subtitle: variant['note'] is String
                ? Text(variant['note'] as String)
                : null,
          ),
    ];
  }
}

/// The detail header: the pack's family chip (the singular family label
/// beside the pack title in the AppBar). The enrolled chip renders at the
/// list's end instead of the CTA — one enrolled indicator, never two.
class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.pack});

  final ContentPack pack;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 8,
          children: <Widget>[
            Chip(
              avatar: const Icon(Icons.category_outlined),
              label: Text(_familyLabel(pack.family)),
            ),
          ],
        ),
      ),
    );
  }
}

/// The list's end: the Enroll CTA when the user is not enrolled (routing to
/// the Task-15 stub route), the enrolled chip when the Task 5/6 ruling
/// reports an enrollment (`enrollmentParamsFor(packId) != null`).
class _EnrollSection extends StatelessWidget {
  const _EnrollSection({required this.packId, required this.enrolled});

  final String packId;
  final bool enrolled;

  @override
  Widget build(BuildContext context) {
    if (enrolled) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Chip(
            key: Key('enrolled_chip'),
            avatar: Icon(Icons.check_circle_outline),
            label: Text('Enrolled'),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      child: FilledButton.icon(
        key: const Key('enroll_cta'),
        onPressed: () => context.push('/program/$packId/enroll'),
        icon: const Icon(Icons.add_circle_outline),
        label: const Text('Enroll'),
      ),
    );
  }
}
