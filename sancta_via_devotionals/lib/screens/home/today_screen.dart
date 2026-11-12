// The Today screen (Plan 2, Task 13): the app's home tab.
//
// Renders what Task 12's [todayAssemblyProvider] assembled for the frozen
// day, in Spec §7's order — Morning · Angelus times · 3pm · Evening ·
// Commitments · Upcoming feasts — under a liturgical header (color ribbon,
// celebration, rank via the calendar riverpod + the shared UI's
// `ColorIntensity` theming).
//
// ## Task 13's presentation rulings
//
// * The 3pm Hour of Mercy is partitioned OUT of [TodayAssembly.anchors] for
//   display by the `mercy_hour` LABEL seam (Task 12's fix-round ruling: the
//   label is robust — a user-moved mercy hour keeps its label, while an
//   `anchor.hour == 15` check would not).
// * The visibility toggles (`enableAngelusAnchors` / `enableMercyHourAnchor`)
//   are applied HERE, not in the provider (fix-round ruling): the assembly
//   reports the catalog's anchors; hiding a user-disabled one is a Today-
//   visibility decision. The Angelus' anchors are recognised by their
//   engine labels (`angelus` / `regina_caeli`), mirroring the label seam.
//   The toggles never touch commitments.
// * The empty state ("nothing enrolled") is the ASSEMBLY's emptiness — the
//   onboarding CTA shows only there; a day hidden whole by the toggles is
//   a settings outcome, not an onboarding one.
//
// The header reads `currentLiturgicalDayProvider`, which derives from the
// same `currentDateProvider` the assembly froze on, so header and tiles
// describe one day.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sancta_via_liturgical_calendar_riverpod/sancta_via_liturgical_calendar_riverpod.dart';
import 'package:sancta_via_shared_ui/sancta_via_shared_ui.dart' hide AppLogger;

import '../../models/app_settings.dart';
import '../../providers/app_settings_provider.dart';
import '../../providers/today_providers.dart';
import '../../utils/logger.dart';
import '../../widgets/onboarding/empty_today.dart';
import '../../widgets/today/today_item_tile.dart';
import '../../widgets/today/today_section_card.dart';

/// The Hour of Mercy's resolved label — the 3pm-group partition seam.
const String _mercyLabel = 'mercy_hour';

/// The Angelus' resolved labels: the daily label and its Eastertide variant.
const Set<String> _angelusLabels = <String>{'angelus', 'regina_caeli'};

/// Whether [item]'s anchor survives the settings' visibility toggles.
bool _anchorVisible(TodayItem item, DevotionsAppSettings settings) {
  final String? label = item.label;
  if (label == _mercyLabel) {
    return settings.enableMercyHourAnchor;
  }
  if (label != null && _angelusLabels.contains(label)) {
    return settings.enableAngelusAnchors;
  }
  return true;
}

/// The app's Today home screen: the liturgical header, the day's time-grouped
/// sections, and the onboarding empty state.
class TodayScreen extends ConsumerWidget {
  /// Creates the Today screen.
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<TodayAssembly> assembly = ref.watch(todayAssemblyProvider);
    final DevotionsAppSettings settings = ref.watch(devotionsSettingsProvider);
    final LiturgicalDayData? liturgicalDay = ref.watch(
      currentLiturgicalDayProvider,
    );
    final ColorIntensity intensity = ref.watch(colorIntensityProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Today')),
      body: assembly.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object error, StackTrace stack) {
          AppLogger.error('Today assembly failed', error, stack, 'TODAY');
          return const Center(
            child: Text(
              "Today's program could not be loaded. Try reopening the app.",
              textAlign: TextAlign.center,
            ),
          );
        },
        data: (TodayAssembly day) => _TodayList(
          day: day,
          settings: settings,
          liturgicalDay: liturgicalDay,
          intensity: intensity,
        ),
      ),
    );
  }
}

/// The screen body for a resolved [TodayAssembly]: the header, the §7
/// section cards (only non-empty groups render, in canonical order), the
/// onboarding empty state, and the feast window.
class _TodayList extends StatelessWidget {
  const _TodayList({
    required this.day,
    required this.settings,
    required this.liturgicalDay,
    required this.intensity,
  });

  final TodayAssembly day;
  final DevotionsAppSettings settings;
  final LiturgicalDayData? liturgicalDay;
  final ColorIntensity intensity;

  @override
  Widget build(BuildContext context) {
    // The anchor sections after the toggles; the mercy group is partitioned
    // out of the remainder for its 3pm slot (the label seam — see the
    // library docs).
    final List<TodayItem> morning = day.morning
        .where((TodayItem item) => _anchorVisible(item, settings))
        .toList(growable: false);
    final List<TodayItem> anchors = day.anchors
        .where((TodayItem item) => _anchorVisible(item, settings))
        .toList(growable: false);
    final List<TodayItem> mercy = anchors
        .where((TodayItem item) => item.label == _mercyLabel)
        .toList(growable: false);
    final List<TodayItem> noon = anchors
        .where((TodayItem item) => item.label != _mercyLabel)
        .toList(growable: false);
    final List<TodayItem> evening = day.evening
        .where((TodayItem item) => _anchorVisible(item, settings))
        .toList(growable: false);

    final List<Widget> sections = <Widget>[
      for (final (String title, IconData icon, List<TodayItem> items)
          in <(String, IconData, List<TodayItem>)>[
            ('Morning', Icons.wb_sunny, morning),
            ('Angelus Times', Icons.notifications_active, noon),
            ('3pm', Icons.access_time, mercy),
            ('Evening', Icons.bedtime, evening),
            ('Commitments', Icons.flag, day.commitments),
          ])
        if (items.isNotEmpty)
          TodaySectionCard(
            title: title,
            icon: icon,
            children: <Widget>[
              for (final TodayItem item in items) TodayItemTile(item: item),
            ],
          ),
    ];

    return ListView(
      children: <Widget>[
        _TodayLiturgicalHeader(
          day: liturgicalDay,
          intensity: intensity,
          date: day.date,
        ),
        const SizedBox(height: 8),
        if (day.isEmpty) ...<Widget>[
          EmptyToday(
            onboardingComplete: settings.onboardingComplete,
            onStartOnboarding: () => context.go('/onboarding'),
          ),
          const SizedBox(height: 8),
        ] else
          ...sections,
        if (day.feastsComing.isNotEmpty)
          TodaySectionCard(
            title: 'Upcoming Feasts',
            icon: Icons.church,
            children: <Widget>[
              for (final TodayItem feast in day.feastsComing)
                TodayItemTile(item: feast),
            ],
          ),
      ],
    );
  }
}

/// The screen's liturgical header: the celebration's color ribbon, the date,
/// the celebration name, its rank, and the psalter week.
///
/// Renders nothing but the date when the calendar has no answer (the calendar
/// data's own fallbacks aside, the screen must never block Today on it).
class _TodayLiturgicalHeader extends StatelessWidget {
  const _TodayLiturgicalHeader({
    required this.day,
    required this.intensity,
    required this.date,
  });

  final LiturgicalDayData? day;
  final ColorIntensity intensity;
  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String dateLabel = MaterialLocalizations.of(
      context,
    ).formatMediumDate(date);
    final LiturgicalDayData? liturgical = day;

    if (liturgical == null) {
      return Container(
        key: const Key('liturgical_header'),
        padding: const EdgeInsets.all(16),
        child: Text(
          dateLabel,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }
    // Maps the celebration's color code onto the shared liturgical palette
    // at the user's color intensity (mirror of the liturgical app's header).
    final Color liturgicalColor = liturgical.celebration.color
        .toLiturgicalColor(intensity);

    return Container(
      key: const Key('liturgical_header'),
      decoration: BoxDecoration(color: liturgicalColor.withValues(alpha: 0.1)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(height: 6, color: liturgicalColor),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  dateLabel,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  liturgical.celebration.name,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  liturgical.celebration.rankEnum.displayName,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: liturgicalColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  liturgical.psalterWeek.value,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
