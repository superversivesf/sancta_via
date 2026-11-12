// The enrollment flow's derive-and-enroll service (Plan 2, Task 15).
//
// The service owns the app-layer rules that turn an authored pack plus the
// user's choices into the program they actually start:
//
// * **Commitments** ([ConsecutiveCommitmentSpec] packs, e.g. the Five First
//   Saturdays) enroll as-is with empty params. Nothing is patched: the
//   persisted progress starts empty, and the engine's own ordinal arithmetic
//   counts the first anchor from the next occurrence.
// * **Consecration** (`reminders.feastAnchor` packs, e.g. the Total
//   Consecration) take the nominal feast date as the `feast` param and patch
//   `schedule.startDate` to [ConsecrationPlanner.startFor] — day 1 of the
//   33-day preparation. The nominal feast is NEVER re-resolved against the
//   liturgical calendar (Plan 1 Task 18's pointer); day 34 is the feast the
//   user picked. Params carry `{feast, startDate, day34}`.
// * **Planned series** (e.g. the 54-day Rosary Novena) take the user-picked
//   day-1 `startDate` and, when the pack offers a missed-day choice, the
//   `restartPolicy` in `MissedDayEvaluator`'s own vocabulary (`strict` |
//   `permissive`). `schedule.startDate` is patched and the rest of the pack
//   (reminders, phases, variants, session) survives untouched.
//
// Derived packs are serialized, patched at the schedule document, and loaded
// back through [PackLoader.loadFromJsonString], so every derived pack is
// schema-validated by the same single pass the content pipeline runs. The
// derived row replaces the seeded pack row (Review Focus 5) under the SAME
// seeded `pack_version`: enrollment is user state, not a content re-seed, and
// `meta.content_version` is never bumped. `repository.enroll` is delegated to,
// so re-enrolling replaces the params without duplicating them and never
// touches the user's persisted progress.
//
// Date discipline: every date the service reads or writes is a local
// midnight calendar date carried as a `yyyy-MM-dd` ISO string — the format
// Task 5's params round-trip pins as JSON-encodable — and `DateTime` params
// are never stored raw. The service reads no provider and no clock: callers
// supply the user's chosen dates (the settings-driven policy default lives in
// the screen, so Task 19's onboarding can claim this service unchanged).
library;

import 'dart:convert';

import 'package:sancta_via_devotional_engine/sancta_via_devotional_engine.dart';

import '../database/devotionals_database.dart' show PackRow;
import '../repositories/program_repository.dart';

/// One feast entry the enrollment flow can offer for a consecration day.
///
/// Parsed from a pack's opaque `reminders.feastAnchor` metadata: the shipped
/// Total Consecration carries one map, `{"feast": "annunciation", "date":
/// "03-25"}`, but a future pack may carry a list of the same maps. The shape
/// is app-owned (the engine passes `reminders` through untouched), so the
/// parser accepts both and skips malformed entries rather than inventing a
/// feast.
class FeastAnchor {
  /// Creates a feast anchor entry.
  const FeastAnchor({
    required this.feast,
    required this.month,
    required this.day,
  });

  /// The feast's stable key (e.g. `annunciation`).
  final String feast;

  /// The feast's nominal month (1 through 12), from the anchor's `MM-DD`.
  final int month;

  /// The feast's nominal day (1 through 31), from the anchor's `MM-DD`.
  final int day;

  /// Every usable feast anchor the pack's `reminders.feastAnchor` declares,
  /// in authored order; an absent or malformed block yields an empty list.
  static List<FeastAnchor> fromPack(ContentPack pack) {
    final Object? raw = pack.reminders['feastAnchor'];
    final List<Object?> entries = raw is List ? raw : <Object?>[raw];
    final List<FeastAnchor> anchors = <FeastAnchor>[];
    for (final Object? entry in entries) {
      if (entry is! Map) {
        continue;
      }
      final Object? feast = entry['feast'];
      final Object? date = entry['date'];
      if (feast is! String || feast.isEmpty || date is! String) {
        continue;
      }
      final RegExpMatch? match = RegExp(r'^(\d{2})-(\d{2})$').firstMatch(date);
      if (match == null) {
        continue;
      }
      final int month = int.parse(match.group(1)!);
      final int day = int.parse(match.group(2)!);
      // Validate the pair against a real calendar (year 2000 is a leap year,
      // so a February 29 feast is admitted).
      final DateTime probe = DateTime(2000, month, day);
      if (probe.year != 2000 || probe.month != month || probe.day != day) {
        continue;
      }
      anchors.add(FeastAnchor(feast: feast, month: month, day: day));
    }
    return anchors;
  }

  /// The nominal feast day in [year] as a local midnight date.
  DateTime dateIn(int year) => DateTime(year, month, day);
}

/// Derives and persists the pack a user's enrollment choices describe.
///
/// Construct once over the app's [SqliteProgramRepository] (the same instance
/// the content pipeline seeds) and call [derivePack] / [enroll]. The service
/// is controller-agnostic: it reads no provider, no settings, and no clock, so
/// the enrollment screen and Task 19's onboarding can both claim it.
class EnrollmentService {
  /// Creates an [EnrollmentService] over [repository].
  EnrollmentService({required this.repository});

  /// The store the derived pack row and the enrollment params are written to.
  final SqliteProgramRepository repository;

  /// The schema-validated pack [params] describe, with the derivation applied
  /// but NOT persisted.
  ///
  /// * `feast` (consecration): patches `schedule.startDate` to
  ///   [ConsecrationPlanner.startFor]'s day 1; params normalize to
  ///   `{feast, startDate, day34}` with day 34 = the nominal feast date;
  /// * `startDate` (planned series): patches `schedule.startDate`; a
  ///   `restartPolicy` is validated and carried when present;
  /// * anything else: the pack unchanged (commitments enroll as-is).
  ///
  /// Throws an [ArgumentError] for an unparsable date, an unknown restart
  /// policy, or a session-series pack asked to enroll without a start date.
  Future<ContentPack> derivePack({
    required ContentPack pack,
    required Map<String, dynamic> params,
  }) async {
    return _derive(pack, params).pack;
  }

  /// Enrolls the user in [pack] under [params], persisting the derived pack
  /// row first and the params second.
  ///
  /// Re-enrolling replaces both (the repository upserts by pack id and by
  /// enrollment pack id), keeps the seeded `pack_version` and
  /// `meta.content_version` untouched, and leaves the user's persisted
  /// progress exactly where it stood — progress is not enrollment state.
  Future<void> enroll({
    required ContentPack pack,
    required Map<String, dynamic> params,
  }) async {
    final _Derivation derivation = _derive(pack, params);
    if (!identical(derivation.pack, pack)) {
      await _replacePack(derivation.pack);
    }
    await repository.enroll(pack.id, derivation.params);
  }

  /// Applies the family rules to [pack] / [params], returning the derived pack
  /// and the normalized params that must be stored with it.
  _Derivation _derive(ContentPack pack, Map<String, dynamic> params) {
    final Object? feast = params['feast'];
    if (feast != null) {
      return _deriveConsecration(pack, feast);
    }
    if (pack.schedule is SessionSeriesSpec) {
      final Object? startDate = params['startDate'];
      if (startDate == null) {
        throw ArgumentError(
          'enrolling the session-series pack "${pack.id}" needs a startDate '
          '(or a consecration feast) so day 1 is user-planned, never the '
          'fixture placeholder',
        );
      }
      return _deriveSeries(pack, startDate, params['restartPolicy']);
    }
    // A commitment (or any non-series pack) enrolls as-is. Its params are the
    // empty map: the engine's ordinal math already starts from the next
    // occurrence, and there is no user choice to record.
    return _Derivation(pack: pack, params: <String, dynamic>{});
  }

  /// The consecration derivation: the nominal feast selects day 34, and day 1
  /// is 33 calendar days before it (the real planner, never re-resolved).
  _Derivation _deriveConsecration(ContentPack pack, Object feastValue) {
    final DateTime feast = _parseDate(feastValue, 'feast');
    if (pack.schedule is! SessionSeriesSpec) {
      throw ArgumentError.value(
        pack.id,
        'pack',
        'a consecration feast applies to a sessionSeries pack',
      );
    }
    final DateTime start = ConsecrationPlanner.startFor(feast);
    return _Derivation(
      pack: _patchSeriesStart(pack, start),
      params: <String, dynamic>{
        'feast': _stamp(feast),
        'startDate': _stamp(start),
        'day34': _stamp(feast),
      },
    );
  }

  /// The planned-series derivation (the 54-day novena shape): the user-picked
  /// day 1 patches the series; the missed-day policy rides in the engine's
  /// own string vocabulary when the caller supplies it.
  _Derivation _deriveSeries(
    ContentPack pack,
    Object startValue,
    Object? policyValue,
  ) {
    final DateTime start = _parseDate(startValue, 'startDate');
    final Map<String, dynamic> params = <String, dynamic>{
      'startDate': _stamp(start),
    };
    if (policyValue != null) {
      params['restartPolicy'] = _parseRestartPolicy(policyValue);
    } else if (pack.variants.any(
      (Map<String, dynamic> variant) => variant['policy'] is String,
    )) {
      // The pack offers a strict/permissive choice: storing the series without
      // the user's decision would leave the missed-day flow to guess.
      throw ArgumentError(
        'enrolling "${pack.id}" needs a restartPolicy (strict | permissive)',
      );
    }
    return _Derivation(pack: _patchSeriesStart(pack, start), params: params);
  }

  /// Serializes [pack], patches the session-series `startDate`, and loads the
  /// document back through [PackLoader] — schema validation, reminders, and
  /// every other block survive the round trip.
  ContentPack _patchSeriesStart(ContentPack pack, DateTime startDate) {
    final Map<String, dynamic> json = pack.toJson();
    final String stamp = _stamp(startDate);
    final Object? schedule = json['schedule'];
    if (schedule is Map<String, dynamic>) {
      if (schedule['type'] != 'sessionSeries') {
        throw ArgumentError.value(
          pack.id,
          'pack',
          'the derived start date applies to a sessionSeries schedule',
        );
      }
      json['schedule'] = <String, dynamic>{...schedule, 'startDate': stamp};
    } else {
      final Object? schedules = json['schedules'];
      if (schedules is! List) {
        throw ArgumentError.value(
          pack.id,
          'pack',
          'the pack carries no schedule document to derive',
        );
      }
      bool patched = false;
      final List<Object?> next = <Object?>[];
      for (final Object? entry in schedules) {
        if (entry is Map<String, dynamic> && entry['type'] == 'sessionSeries') {
          next.add(<String, dynamic>{...entry, 'startDate': stamp});
          patched = true;
        } else {
          next.add(entry);
        }
      }
      if (!patched) {
        throw ArgumentError.value(
          pack.id,
          'pack',
          'the pack carries no sessionSeries schedule to derive',
        );
      }
      json['schedules'] = next;
    }
    return PackLoader.loadFromJsonString(jsonEncode(json));
  }

  /// Replaces the pack row under the seeded pack version.
  ///
  /// `meta.content_version` and every other pack row are untouched: this is a
  /// user-state write, not a content migration. A missing row (a pack that was
  /// never seeded) falls back to the persisted content version, then to an
  /// explicit `unversioned` marker — the pack's content version is metadata,
  /// never a scheduling input.
  Future<void> _replacePack(ContentPack pack) async {
    final PackRow? existing = await repository.database.getPack(pack.id);
    final String packVersion =
        existing?.packVersion ??
        await repository.persistedPackVersion() ??
        'unversioned';
    await repository.database.upsertPack(
      id: pack.id,
      json: jsonEncode(pack.toJson()),
      packVersion: packVersion,
      embeddedAt: DateTime.now().toUtc().toIso8601String(),
    );
    // The repository's catalog cache must see the replacement; the caller then
    // invalidates the providers built on top of it.
    repository.clearCache();
  }

  /// Parses a date-only param into a local midnight date.
  ///
  /// Only the strict `yyyy-MM-dd` shape is accepted, and the components are
  /// validated against a rebuilt calendar date — `DateTime`'s normalizing
  /// constructor would silently roll `2026-13-05` into the next year.
  static DateTime _parseDate(Object? value, String key) {
    if (value is! String) {
      throw ArgumentError.value(value, key, 'must be a yyyy-MM-dd string');
    }
    final RegExpMatch? match = RegExp(
      r'^(\d{4})-(\d{2})-(\d{2})$',
    ).firstMatch(value);
    if (match == null) {
      throw ArgumentError.value(value, key, 'must be a yyyy-MM-dd string');
    }
    final int year = int.parse(match.group(1)!);
    final int month = int.parse(match.group(2)!);
    final int day = int.parse(match.group(3)!);
    final DateTime date = DateTime(year, month, day);
    if (date.year != year || date.month != month || date.day != day) {
      throw ArgumentError.value(value, key, 'must be a real calendar date');
    }
    return date;
  }

  /// Validates a missed-day policy against the engine's own vocabulary.
  static String _parseRestartPolicy(Object value) {
    if (value is! String || (value != 'strict' && value != 'permissive')) {
      throw ArgumentError.value(
        value,
        'restartPolicy',
        "must be 'strict' or 'permissive' (MissedDayEvaluator's vocabulary)",
      );
    }
    return value;
  }

  /// The zero-padded `yyyy-MM-dd` rendering of a local date.
  static String _stamp(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

/// One derivation result: the pack to store and the params that describe it.
class _Derivation {
  const _Derivation({required this.pack, required this.params});

  final ContentPack pack;
  final Map<String, dynamic> params;
}
