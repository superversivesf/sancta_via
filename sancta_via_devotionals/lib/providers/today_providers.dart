// The Today assembler (Plan 2, Task 12): one day's devotional program,
// grouped into the sections the Today screen renders.
//
// [todayAssemblyProvider] consumes the wrapper's own due resolution
// (`todayProgramsProvider` — ordinal composition and the completed-commitment
// exclusion live there, never here), the enrolled set of the app's SQLite
// repository (`enrollmentParamsFor(packId) != null`, the Task 5/6 ruling), the
// engine's schedule resolution (`ScheduleSpec.resolve`, which is what carries
// the day's variant labels such as `regina_caeli`), the settings' anchor times
// (`anchorTimesProvider`), and the liturgical calendar's feast window.
//
// ## Sections
//
// * [TodayAssembly.morning] — every enrolled pack's `TimeOfDaySpec` anchor in
//   the 06:00–11:59 window (the Angelus' morning anchor and, once the routine
//   packs ship, the Morning Offering);
// * [TodayAssembly.anchors] — the 12:00–16:59 anchors, EXCLUDING the 15:00
//   Hour of Mercy;
// * [TodayAssembly.mercy] — the 15:00 Hour of Mercy anchor, the Anchors
//   section's own 3pm subsection (§7's "3pm" group);
// * [TodayAssembly.evening] — the 17:00-onward anchors (the Angelus' evening
//   anchor, the daily Examen, night prayers);
// * [TodayAssembly.commitments] — the programs due today, as the wrapper
//   resolves them, with a consecutive commitment's [`TodayItem.ordinalLabel`]
//   ("ordinal N") and a novena's `resolution.dayIndex`. A pack whose schedules
//   are time-of-day anchors is an anchor, not a due session, so it never
//   appears twice (the shipped anchor packs carry only time-of-day schedules).
//   The wrapper reports one due resolution per pack — its first due schedule —
//   so a pack with several non-anchor schedules contributes its first;
// * [TodayAssembly.feastsComing] — the liturgical calendar's celebrations in
//   the 14 days AFTER today (today itself is excluded: the header carries it).
//
// Within every section the order is the store's `packs.id ASC` order (Task 5's
// ordering ruling) and, inside one pack, the pack's own schedule order.
//
// ## Date seam
//
// Every date comes from `currentDateProvider` (awaited through its `future`,
// exactly as the wrapper's providers do — tests freeze it with a
// `Stream.value` override). Nothing here reads `DateTime.now()`: the
// assembly's day is fixed by the stream and every deep link carries it, so a
// tap can never open a different day's session than the tile showed.
//
// ## Divergences from the brief (recorded in the task report)
//
// * The provider is a `FutureProvider`: the enrolled set and the due list are
//   asynchronous (SQLite lookups), so a synchronous `Provider<TodayAssembly>`
//   could only ever return a half-built day.
// * The feast window cannot use `upcomingFeastsProvider(14)`: that provider
//   calls `LiturgicalCalendarService.getUpcomingFeasts` WITHOUT a `fromDate`,
//   so it is pinned to `DateTime.now()` and would ignore the frozen date. The
//   service's own `fromDate` seam is used instead (same celebration filter,
//   same 14-day window, keyed to the assembly's day).
// * The variant labels come from `ScheduleResult.labels` — the engine's own
//   `TimeOfDaySpec` resolution. `VariantService` resolves SESSION substitution
//   tokens; re-deriving schedule labels from it here would duplicate the
//   engine.
//
// Deferred (Task 13's presentation filter): the settings' `enableAngelusAnchors`
// / `enableMercyHourAnchor` toggles. The assembly reports what the catalog
// anchors; hiding a user-disabled anchor is the Today screen's rendering
// decision.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sancta_via_devotional_engine/sancta_via_devotional_engine.dart';
import 'package:sancta_via_devotional_engine_riverpod/sancta_via_devotional_engine_riverpod.dart'
    show DueToday, todayProgramsProvider;
import 'package:sancta_via_liturgical_calendar_riverpod/sancta_via_liturgical_calendar_riverpod.dart';

import '../repositories/program_repository.dart';
import 'app_settings_provider.dart';
import 'content_providers.dart';

/// How many days ahead the feast window looks (the brief's `upcomingFeasts(14)`).
const int _feastWindowDays = 14;

/// Reduces [d] to a local midnight date (the engine's date-only discipline).
DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// The zero-padded `yyyy-mm-dd` rendering of the local date [d] — the session
/// route's `forDate` shape.
String _stamp(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// The session player's deep link for [packId] on [day] (the app router's
/// `/session/:packId?forDate=yyyy-MM-dd` shape; the day is the assembly's, so
/// a tap opens the day the tile described).
String _sessionLink(String packId, DateTime day) =>
    '/session/$packId?forDate=${_stamp(day)}';

/// Which time-of-day section an anchor belongs to.
enum _AnchorSection { morning, noon, mercy, evening }

/// The section of a [TimeOfDaySpec] anchor at [hour]: 6 → Morning, 12 → the
/// noon anchors, 15 → the 3pm mercy subsection, 18 → Evening. Anything else
/// falls into the natural window (before noon → Morning, up to 17:00 → noon
/// anchors, later → Evening) so future routine anchors land somewhere honest.
_AnchorSection _sectionFor(int hour) {
  if (hour == 15) {
    return _AnchorSection.mercy;
  }
  if (hour < 12) {
    return _AnchorSection.morning;
  }
  if (hour < 17) {
    return _AnchorSection.noon;
  }
  return _AnchorSection.evening;
}

/// The anchor instant of [spec] on [day]: the user's configured anchor time
/// for the shipped anchor hours (6/12/15/18 — the Angelus and Hour of Mercy
/// packs), else the spec's own wall-clock time.
DateTime _anchorFor(DateTime day, TimeOfDaySpec spec, AnchorTimes times) {
  final TimeOfDay time = switch (spec.hour) {
    6 => times.angelusMorning,
    12 => times.angelusNoon,
    15 => times.mercyHour,
    18 => times.angelusEvening,
    _ => TimeOfDay(hour: spec.hour, minute: spec.minute),
  };
  return DateTime(day.year, day.month, day.day, time.hour, time.minute);
}

/// One entry of a [TodayAssembly] section.
///
/// The pinned shape: a display [title], the [pack] when the item is a program
/// (feasts are calendar data), the item's [anchor] instant (the day's anchor
/// time, or a feast's calendar date), the [deepLink] into the session player
/// (null when no route exists, e.g. a feast), and the engine [resolution]
/// (`due`, `dayIndex`, `ordinal`, `labels`) when the item came from a schedule.
class TodayItem {
  /// The display title (the pack's title, or the feast's celebration name).
  final String title;

  /// The program the item belongs to, or null for calendar-only items.
  final ContentPack? pack;

  /// The item's wall-clock instant: the anchor time of a due devotion on the
  /// assembly's day, or a coming feast's calendar date.
  final DateTime? anchor;

  /// The session player link for the item, or null when no route exists.
  final String? deepLink;

  /// The engine's resolution of the item's schedule, when it has one.
  final ScheduleResult? resolution;

  /// Creates a [TodayItem].
  const TodayItem({
    required this.title,
    this.pack,
    this.anchor,
    this.deepLink,
    this.resolution,
  });

  /// The commitment position label (`'ordinal N'`) of a due consecutive
  /// commitment, or null for every other item.
  String? get ordinalLabel {
    final int? ordinal = resolution?.ordinal;
    return ordinal == null ? null : 'ordinal $ordinal';
  }

  /// The resolved time-of-day label (e.g. `'angelus'`, `'regina_caeli'`,
  /// `'mercy_hour'`) — the day's variant label, resolved by the engine — or
  /// null when the resolution carries none.
  String? get label {
    final List<String>? labels = resolution?.labels;
    return labels == null || labels.isEmpty ? null : labels.first;
  }

  @override
  String toString() =>
      'TodayItem(title: $title, pack: ${pack?.id}, anchor: $anchor, '
      'labels: ${resolution?.labels}, ordinal: ${resolution?.ordinal})';
}

/// One day's devotional program, grouped into the Today screen's sections.
///
/// Every list is unmodifiable and in `packs.id ASC` order (see the library
/// docs for the section rules).
class TodayAssembly {
  /// The day the assembly describes (a local midnight date).
  final DateTime date;

  /// Morning anchors: 06:00–11:59 time-of-day packs (Angelus morning anchor,
  /// Morning Offering).
  final List<TodayItem> morning;

  /// Noon anchors: 12:00–16:59 time-of-day packs, excluding the 15:00 Hour of
  /// Mercy.
  final List<TodayItem> anchors;

  /// The 3pm Hour of Mercy subsection of the Anchors section (15:00).
  final List<TodayItem> mercy;

  /// Evening anchors: 17:00-onward time-of-day packs (Angelus evening anchor,
  /// Daily Examen, night prayers).
  final List<TodayItem> evening;

  /// Programs due today (commitments, novenas, weekly devotions), as the
  /// wrapper's due resolution reports them.
  final List<TodayItem> commitments;

  /// Celebrations in the 14 days after [date].
  final List<TodayItem> feastsComing;

  /// Creates a [TodayAssembly].
  const TodayAssembly({
    required this.date,
    this.morning = const <TodayItem>[],
    this.anchors = const <TodayItem>[],
    this.mercy = const <TodayItem>[],
    this.evening = const <TodayItem>[],
    this.commitments = const <TodayItem>[],
    this.feastsComing = const <TodayItem>[],
  });

  /// Whether the day carries no devotional item at all — the Today screen's
  /// "nothing to pray yet" (onboarding) state.
  ///
  /// [feastsComing] is deliberately excluded: liturgical data exists whether
  /// or not the user has enrolled in anything, so a feast list alone is not a
  /// devotional program.
  bool get isEmpty =>
      morning.isEmpty &&
      anchors.isEmpty &&
      mercy.isEmpty &&
      evening.isEmpty &&
      commitments.isEmpty;

  @override
  String toString() =>
      'TodayAssembly(date: ${_stamp(date)}, morning: ${morning.length}, '
      'anchors: ${anchors.length}, mercy: ${mercy.length}, '
      'evening: ${evening.length}, commitments: ${commitments.length}, '
      'feastsComing: ${feastsComing.length})';
}

/// The day's assembled devotional program (see the library docs).
///
/// It is a `FutureProvider` because the enrolled set and the due list come
/// from the SQLite repository asynchronously; the screen renders its
/// `loading`/`error` state while the day resolves.
///
/// Like every app provider reading the wrapper's catalog, it expects
/// `main.dart`'s `programRepositoryOverride` on the root scope: that routes
/// `todayProgramsProvider`'s due list to the same SQLite repository this
/// provider reads the enrolled set from.
final FutureProvider<TodayAssembly> todayAssemblyProvider =
    FutureProvider<TodayAssembly>((Ref ref) async {
      final SqliteProgramRepository repository = ref.watch(
        appProgramRepositoryProvider,
      );
      final DateTime today = _dateOnly(
        await ref.watch(currentDateProvider.future),
      );
      final LiturgicalDayData? liturgicalDay = ref.watch(
        currentLiturgicalDayProvider,
      );
      final ScheduleContext context = ScheduleContext(
        seasonKeyValue: liturgicalDay?.seasonKey,
      );
      final AnchorTimes anchorTimes = ref.watch(anchorTimesProvider);

      // Watching the catalog runs the first-launch migration (a version match
      // afterwards is a no-op), so the assembly is self-sufficient: opening
      // Today on a fresh install seeds before it reads.
      await ref.watch(contentLoadedProvider.future);

      // "Enrolled" is the app's enrollment record, never the catalog: the
      // repository returns every seeded pack (Task 5/6 ruling).
      final List<ContentPack> packs = await repository.loadPacks();
      final List<ContentPack> enrolled = <ContentPack>[];
      for (final ContentPack pack in packs) {
        if (await repository.enrollmentParamsFor(pack.id) != null) {
          enrolled.add(pack);
        }
      }

      final List<TodayItem> morning = <TodayItem>[];
      final List<TodayItem> anchors = <TodayItem>[];
      final List<TodayItem> mercy = <TodayItem>[];
      final List<TodayItem> evening = <TodayItem>[];
      for (final ContentPack pack in enrolled) {
        for (final ScheduleSpec spec in pack.schedules) {
          if (spec is! TimeOfDaySpec) {
            continue;
          }
          final ScheduleResult resolution = spec.resolve(today, context);
          if (!resolution.due) {
            continue;
          }
          final TodayItem item = TodayItem(
            title: pack.title,
            pack: pack,
            anchor: _anchorFor(today, spec, anchorTimes),
            deepLink: _sessionLink(pack.id, today),
            resolution: resolution,
          );
          switch (_sectionFor(spec.hour)) {
            case _AnchorSection.morning:
              morning.add(item);
            case _AnchorSection.noon:
              anchors.add(item);
            case _AnchorSection.mercy:
              mercy.add(item);
            case _AnchorSection.evening:
              evening.add(item);
          }
        }
      }

      // The due list is the wrapper's (progress-aware ordinals, and completed
      // commitments already excluded); only this app's enrolled set is
      // filtered on top.
      final Set<String> enrolledIds = <String>{
        for (final ContentPack pack in enrolled) pack.id,
      };
      final List<DueToday> due = await ref.watch(todayProgramsProvider.future);
      final List<TodayItem> commitments = <TodayItem>[];
      for (final DueToday program in due) {
        if (!enrolledIds.contains(program.pack.id)) {
          continue;
        }
        final bool hasAnchorSchedule = program.pack.schedules.any(
          (ScheduleSpec spec) => spec is TimeOfDaySpec,
        );
        if (hasAnchorSchedule) {
          // A time-of-day pack is an anchor (above), not a due session.
          continue;
        }
        commitments.add(
          TodayItem(
            title: program.pack.title,
            pack: program.pack,
            deepLink: _sessionLink(program.pack.id, today),
            resolution: program.schedule,
          ),
        );
      }

      final List<TodayItem> feastsComing = <TodayItem>[
        for (final LiturgicalDayData feast
            in LiturgicalCalendarService.getUpcomingFeasts(
              daysAhead: _feastWindowDays,
              fromDate: today,
            ))
          if (feast.dateTime.isAfter(today))
            TodayItem(title: feast.displayName, anchor: feast.dateTime),
      ];

      return TodayAssembly(
        date: today,
        morning: List<TodayItem>.unmodifiable(morning),
        anchors: List<TodayItem>.unmodifiable(anchors),
        mercy: List<TodayItem>.unmodifiable(mercy),
        evening: List<TodayItem>.unmodifiable(evening),
        commitments: List<TodayItem>.unmodifiable(commitments),
        feastsComing: List<TodayItem>.unmodifiable(feastsComing),
      );
    });
