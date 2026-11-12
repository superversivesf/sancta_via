// The Settings tab (Plan 2, Task 20): the shared `UnifiedSettingsScreen`
// composition plus this app's own devotional settings section.
//
// ## Composition (the brief's pinned seam)
//
// The base-settings controls are the shared widgets themselves — appearance
// (theme mode, color intensity, the liturgical color preview), accessibility
// (font size, text scaling, reduce motion, haptics), the language selector,
// and the shared notifications gate. Each delegates to the SHARED providers
// (`baseSettingsProvider`, `themeModeProvider`, `colorIntensityProvider`):
// nothing here re-wraps them in app state. `main.dart` wires what the app's
// `MaterialApp` consumes from those providers — the locale (the base
// settings' default language) and the theme mode (the dark/light/system
// choice) — so the controls on this screen drive the running app.
//
// The app section carries the [DevotionsAppSettings] fields the brief pins
// (amended in fix round 1 to add the two routine reminder consents):
//
// * the four anchor reminder times (time pickers over
//   `anchorTimesProvider`, written through the notifier setters);
// * the Angelus and Divine-Mercy-Hour anchor toggles;
// * the morning and evening reminder consent toggles (plan inputs the
//   planner gates the non-anchor routine anchors on; onboarding takes the
//   consents first, this screen is the post-onboarding surface);
// * the meal & night anchors toggle, with its explicit "off by default"
//   warning (the setting is a consent, not a default);
// * the missed-day default policy selector — only `MissedDayEvaluator`'s own
//   vocabulary (`'strict'` / `'permissive'`) is presentable. An unknown value
//   reaching the screen (a corrupt or pre-Task-2 store) is REFUSED: neither
//   row checks, a not-recognized note renders, and picking a known value is
//   the fix the screen offers;
// * the Latin display and Luminous-mysteries toggles.
//
// Everything persists through [DevotionsSettingsNotifier] (its setters
// schedule the SharedPreferences write; nothing in this screen touches
// storage directly).
//
// ## Notification refresh
//
// A change the planner or the master gate reads at plan time — the anchor
// times, the anchor toggles, the morning/evening reminder consents, the
// night-items gate, and the SHARED `baseSettingsProvider` master gate
// (`notificationsEnabled`, fix round 1) — fires ONE
// `NotificationService.refresh()` per change event, fire-and-forget with
// logging and never awaited, the same discipline as Task 18's three wired
// refresh points. No debounce is needed: the service serializes refreshes
// through its own queue, and a second change event lands its own pass over
// the then-current settings. Display/content preferences (Latin, Luminous)
// and the missed-day policy are not plan inputs, so they do not refresh.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:package_info_plus/package_info_plus.dart';

import 'package:sancta_via_shared_ui/sancta_via_shared_ui.dart' hide AppLogger;

import '../../models/app_settings.dart' show DevotionsAppSettings;
import '../../providers/app_settings_provider.dart'
    show AnchorTimes, anchorTimesProvider, devotionsSettingsProvider;
import '../../providers/today_providers.dart' show notificationServiceProvider;
import '../../services/notification_service.dart' show NotificationService;
import '../../utils/logger.dart';

/// The screen the Settings tab mounts (routes.dart): the shared unified
/// settings composition, then the app's devotional settings, then About.
///
/// `PackageInfo.fromPlatform()` resolves asynchronously; until it does the
/// About section's version reads `Loading...` (the saint-companion pattern —
/// never a crash, never a fake version number).
class DevotionalsSettingsScreen extends ConsumerWidget {
  /// Creates the Settings screen.
  const DevotionalsSettingsScreen({super.key});

  /// `MissedDayEvaluator`'s own policy vocabulary (Task 2): the strings the
  /// evaluator's string API (and the engine's `RestartPolicy`) accept. The
  /// selector presents ONLY these values; anything else is refused.
  static const List<String> selectablePolicyChoices = <String>[
    'strict',
    'permissive',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The shared master gate is a plan input (fix round 1): the
    // `NotificationsSettings` switch writes `baseSettingsProvider` directly,
    // so the screen listens for ITS changes and fires one refresh per gate
    // event — with the gate closed the next pass cancels every reminder,
    // with it open the next pass re-plans (the diff's own work).
    ref.listen<BaseSettingsModel>(baseSettingsProvider, (
      BaseSettingsModel? previous,
      BaseSettingsModel next,
    ) {
      if (previous?.notificationsEnabled != next.notificationsEnabled) {
        _refreshAfterScheduleChange(ref);
      }
    });
    return FutureBuilder<PackageInfo>(
      future: PackageInfo.fromPlatform(),
      builder: (BuildContext context, AsyncSnapshot<PackageInfo> snapshot) {
        // App information for the unified screen.
        final AppInfo appInfo = AppInfo(
          appName: 'Sancta Via Devotionals',
          version: snapshot.hasData ? snapshot.data!.version : 'Loading...',
          description:
              'Offline Catholic devotionals: the Today pipeline and its '
              'daily anchors, guided prayer sessions, and commitment '
              'trackers, themed by the liturgical year.',
          icon: const Icon(Icons.church, size: 48, color: Colors.indigo),
        );

        return UnifiedSettingsScreen(
          appInfo: appInfo,
          // No extra shared-notification options: the app's reminder
          // specifics are the anchor section below, and the composition's
          // inert placeholder options (enabled: false, no onChanged) would
          // be dishonest switches.
          customNotifications: const <NotificationOption>[],
          appSpecificSettings: _buildDevotionsSection(context, ref),
        );
      },
    );
  }

  /// The devotional app section: anchors, display, and missed-day policy —
  /// every control bound to the [DevotionsAppSettings] state through the
  /// notifier's own setters.
  Widget _buildDevotionsSection(BuildContext context, WidgetRef ref) {
    final DevotionsAppSettings settings = ref.watch(devotionsSettingsProvider);
    final AnchorTimes times = ref.watch(anchorTimesProvider);

    return Column(
      key: const Key('devotions_settings_section'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SettingsSectionHeader(title: 'Daily Anchors'),
        // ── Anchor reminder times ──
        _AnchorTimeTile(
          rowKey: 'anchor_time_angelus_morning',
          icon: Icons.wb_twilight,
          title: 'Angelus — Morning',
          time: times.angelusMorning,
          onPick: (TimeOfDay time) => ref
              .read(devotionsSettingsProvider.notifier)
              .setAngelusMorning(time),
        ),
        _AnchorTimeTile(
          rowKey: 'anchor_time_angelus_noon',
          icon: Icons.light_mode_outlined,
          title: 'Angelus — Noon',
          time: times.angelusNoon,
          onPick: (TimeOfDay time) =>
              ref.read(devotionsSettingsProvider.notifier).setAngelusNoon(time),
        ),
        _AnchorTimeTile(
          rowKey: 'anchor_time_mercy',
          icon: Icons.church_outlined,
          title: 'Divine Mercy Hour',
          time: times.mercyHour,
          onPick: (TimeOfDay time) =>
              ref.read(devotionsSettingsProvider.notifier).setMercyHour(time),
        ),
        _AnchorTimeTile(
          rowKey: 'anchor_time_angelus_evening',
          icon: Icons.brightness_3_outlined,
          title: 'Angelus — Evening',
          time: times.angelusEvening,
          onPick: (TimeOfDay time) => ref
              .read(devotionsSettingsProvider.notifier)
              .setAngelusEvening(time),
        ),
        // ── Anchor toggles ──
        SwitchListTile(
          key: const Key('toggle_angelus_anchors'),
          secondary: const Icon(Icons.access_time),
          title: const Text('Angelus anchors'),
          subtitle: const Text(
            'Remind at the Angelus times above (morning, noon, evening)',
          ),
          value: settings.enableAngelusAnchors,
          onChanged: (bool value) {
            ref
                .read(devotionsSettingsProvider.notifier)
                .setAngelusAnchorsEnabled(value);
            _refreshAfterScheduleChange(ref);
          },
        ),
        SwitchListTile(
          key: const Key('toggle_mercy_anchor'),
          secondary: const Icon(Icons.hourglass_bottom),
          title: const Text('Hour of Mercy anchor'),
          subtitle: const Text('Remind at the Divine Mercy hour anchor above'),
          value: settings.enableMercyHourAnchor,
          onChanged: (bool value) {
            ref
                .read(devotionsSettingsProvider.notifier)
                .setMercyHourAnchorEnabled(value);
            _refreshAfterScheduleChange(ref);
          },
        ),
        // ── Routine reminder consents (the post-onboarding surface —
        // fix round 1 brief amendment; the planner gates the non-anchor
        // routine anchors on these two flags).
        SwitchListTile(
          key: const Key('toggle_morning_reminder'),
          secondary: const Icon(Icons.wb_sunny_outlined),
          title: const Text('Morning reminders'),
          subtitle: const Text(
            'Reminders for the routine anchors before 5pm (e.g. the '
            'Morning Offering)',
          ),
          value: settings.morningReminderEnabled,
          onChanged: (bool value) {
            ref
                .read(devotionsSettingsProvider.notifier)
                .setMorningReminderEnabled(value);
            _refreshAfterScheduleChange(ref);
          },
        ),
        SwitchListTile(
          key: const Key('toggle_evening_reminder'),
          secondary: const Icon(Icons.nights_stay_outlined),
          title: const Text('Evening reminders'),
          subtitle: const Text(
            'Reminders for the routine anchors from 5pm (e.g. the daily '
            'Examen)',
          ),
          value: settings.eveningReminderEnabled,
          onChanged: (bool value) {
            ref
                .read(devotionsSettingsProvider.notifier)
                .setEveningReminderEnabled(value);
            _refreshAfterScheduleChange(ref);
          },
        ),
        // The meal & night anchors: a consent, never a default.
        SwitchListTile(
          key: const Key('toggle_night_items'),
          secondary: const Icon(Icons.dark_mode_outlined),
          title: const Text('Meal & night prayers'),
          value: settings.nightItemsEnabled,
          onChanged: (bool value) {
            ref
                .read(devotionsSettingsProvider.notifier)
                .setNightItemsEnabled(value);
            _refreshAfterScheduleChange(ref);
          },
        ),
        const Padding(
          key: Key('night_items_warning'),
          padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Text(
            'This stays off by default — turning it on adds the meal and '
            'night prayer anchors to Today and schedules their reminders.',
            style: TextStyle(fontSize: 12, color: Colors.redAccent),
          ),
        ),
        const Divider(),
        const SettingsSectionHeader(title: 'Prayer Display'),
        SwitchListTile(
          key: const Key('toggle_latin_display'),
          secondary: const Icon(Icons.translate),
          title: const Text('Latin display'),
          subtitle: const Text(
            'Show Latin enrichments alongside the English prayers',
          ),
          value: settings.latinDisplayEnabled,
          onChanged: (bool value) {
            ref
                .read(devotionsSettingsProvider.notifier)
                .setLatinDisplayEnabled(value);
          },
        ),
        SwitchListTile(
          key: const Key('toggle_luminous_set'),
          secondary: const Icon(Icons.auto_stories),
          title: const Text('Luminous mysteries'),
          subtitle: const Text(
            'Include the Luminous mysteries wherever the schedules offer '
            'them',
          ),
          value: settings.luminousSetEnabled,
          onChanged: (bool value) {
            ref
                .read(devotionsSettingsProvider.notifier)
                .setLuminousSetEnabled(value);
          },
        ),
        const Divider(),
        const SettingsSectionHeader(title: 'Missed-Day Defaults'),
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text(
            'The default way enrolled programs treat a missed day, unless '
            'a program carries its own choice:',
            style: TextStyle(fontSize: 13),
          ),
        ),
        ..._buildPolicyRows(context, ref, settings),
      ],
    );
  }

  /// The two policy rows, over `MissedDayEvaluator`'s vocabulary.
  ///
  /// `strict` and `permissive` always render; the stored value checks its
  /// row. An unknown stored value is REFUSED (not presented as chosen): the
  /// rows stay unselected and a note explains the fix — picking one below
  /// writes a value the evaluator accepts.
  List<Widget> _buildPolicyRows(
    BuildContext context,
    WidgetRef ref,
    DevotionsAppSettings settings,
  ) {
    final bool known = selectablePolicyChoices.contains(
      settings.missedDayDefaultPolicy,
    );
    Future<void> pick(String value) {
      return ref
          .read(devotionsSettingsProvider.notifier)
          .setMissedDayDefaultPolicy(value);
    }

    return <Widget>[
      RadioGroup<String>(
        // With an unrecognized stored value the group carries null: no row
        // presents it as chosen (the refusal below explains the fix).
        groupValue: known ? settings.missedDayDefaultPolicy : null,
        onChanged: (String? value) {
          if (value != null) {
            unawaited(pick(value));
          }
        },
        child: const Column(
          children: <Widget>[
            RadioListTile<String>(
              key: Key('policy_strict'),
              secondary: Icon(Icons.gavel),
              title: Text('Strict'),
              subtitle: Text('A missed day resets the streak to zero'),
              value: 'strict',
            ),
            RadioListTile<String>(
              key: Key('policy_permissive'),
              secondary: Icon(Icons.battery_alert),
              title: Text('Permissive'),
              subtitle: Text('A missed day resumes without penalty'),
              value: 'permissive',
            ),
          ],
        ),
      ),
      // The refusal surface for an unknown stored value (a corrupt or
      // pre-Task-2 store): never normalized away, never presented as chosen.
      if (!known)
        const Padding(
          key: Key('policy_unknown_note'),
          padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Text(
            'The stored missed-day policy is not a recognized value — it is '
            'left unchanged until you pick Strict or Permissive above.',
            style: TextStyle(fontSize: 12, color: Colors.redAccent),
          ),
        ),
    ];
  }
}

/// One schedule-relevant change event → one fire-and-forget refresh (see
/// the library docs): the planner and the master gate read the anchor
/// times, the anchor toggles, the reminder consents, the night-items gate,
/// and the shared base gate at plan time, so each of those change events
/// re-plans the reminders over the settings the change just wrote.
void _refreshAfterScheduleChange(WidgetRef ref) {
  final NotificationService service = ref.read(notificationServiceProvider);
  unawaited(_runRefresh(service));
}

/// The refresh with its failure surface: logged, never thrown into the
/// widget tree (the service itself also swallows — this log belongs to the
/// settings change that asked for the pass).
Future<void> _runRefresh(NotificationService service) async {
  try {
    await service.refresh();
  } catch (e, stackTrace) {
    AppLogger.error(
      'Notification refresh after a settings change failed',
      e,
      stackTrace,
      'NOTIF',
    );
  }
}

/// One anchor-reminder-time row: the formatted time, opening the platform
/// time picker. The pick writes through the settings notifier (persisted)
/// and fires the notification refresh — anchor times are plan inputs.
class _AnchorTimeTile extends ConsumerWidget {
  /// Creates one anchor-time row. [rowKey] is the widget test's stable key.
  const _AnchorTimeTile({
    required String rowKey,
    required this.icon,
    required this.title,
    required this.time,
    required this.onPick,
  }) : _rowKey = rowKey;

  final String _rowKey;
  final IconData icon;
  final String title;
  final TimeOfDay time;

  /// Persists the picked time through the settings notifier (one of its
  /// pinned anchor setters).
  final Future<void> Function(TimeOfDay) onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final MaterialLocalizations localizations = MaterialLocalizations.of(
      context,
    );
    return ListTile(
      key: Key(_rowKey),
      leading: Icon(icon),
      title: Text(title),
      subtitle: const Text('Daily anchor reminder time'),
      trailing: Text(
        localizations.formatTimeOfDay(time),
        style: Theme.of(context).textTheme.titleMedium,
      ),
      onTap: () {
        _pickTime(context, ref);
      },
    );
  }

  Future<void> _pickTime(BuildContext context, WidgetRef ref) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: time,
    );
    if (!context.mounted || picked == null) {
      // Cancelled (a dismissal is not a change event): nothing persists,
      // nothing refreshes.
      return;
    }
    if (picked == time) {
      // The same time is not a change event.
      return;
    }
    await onPick(picked);
    _refreshAfterScheduleChange(ref);
  }
}
