// Day-variant and mystery-cycle token resolution for pack sessions (Plan 2,
// Task 10).
//
// A pack's `variants` list is opaque app-layer data the engine never
// interprets. This service turns it into the token map Task 7's
// `SubstitutionService` consumes, so the session player can resolve
// `{{day}}`, `{{mysteryTitle}}`, and `{{mysteryFruit}}` ONCE at session start:
//
// * [VariantService.resolveDayVariant] is the pinned interface: the entry
//   whose `dayIndex` equals the resolved day's `ScheduleResult.dayIndex`
//   becomes the day's token bag (every string value under its own key — e.g.
//   the 54-day novena's `petition`, `phase`, `virtue`; the Divine Mercy
//   novena's `title`, `intention`), plus `day` = the 1-based day index. A
//   pack with no entry for that day yields no tokens (the pinned "else empty
//   tokens"), and the substitution gate then reports any placeholder the
//   caller failed to cover rather than rendering it.
// * The day's mystery tokens (`mysteryTitle` / `mysteryFruit`) come from the
//   pack's own mystery metadata, in one of two documented shapes:
//   - an entry naming its own `mystery`/`fruit` (the rosary pack's 20-entry
//     shape, keyed `setTitle` + 1-based `index`) — [resolveBeadMysteryTokens]
//     resolves the exact decade;
//   - a day variant naming a `mysterySet` (the 54-day novena's shape) — the
//     cycle's answer is that set's display title and, when present, the day's
//     `virtue` as the fruit. The 54-day pack carries no individual mystery
//     titles (only the per-day set and virtue), so the token carries the set
//     title; shipping concrete names there is a content decision, not an app
//     invention.
// * The mystery CYCLE itself is season-driven when the pack does not name a
//   set: [rosaryMysteriesFor] (the engine's Plan-1 set selection, which
//   overrides the weekday map on Sundays by liturgical season) resolves the
//   set for `forDate`, and the pack's metadata then supplies the decade's
//   title/fruit. That is the pack's `reminders.mysterySource` contract
//   (`'rosaryMysteriesFor'`).
//
// Date discipline: `forDate` is reduced to a local midnight before it reaches
// `rosaryMysteriesFor`, matching the engine's date-only rule. The service is
// pure: no clock reads — callers pass the session's day.
library;

import 'package:sancta_via_devotional_engine/sancta_via_devotional_engine.dart';
import 'package:sancta_via_liturgical_calendar/sancta_via_liturgical_calendar.dart';

/// Reduces [d] to a local midnight date (the engine's date-only discipline).
DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// A pack variant's display label for the mystery set [set] — the cycle's
/// answer when the pack names a set but ships no individual mystery titles
/// (the 54-day novena). The set names are the engine's [MysterySet] values
/// (`joyful`, `sorrowful`, `glorious`, `luminous`).
String _setLabel(String set) {
  if (set.isEmpty) {
    return 'Mysteries';
  }
  return '${set[0].toUpperCase()}${set.substring(1)} Mysteries';
}

/// Day-variant and mystery-cycle token resolution for pack sessions.
class VariantService {
  const VariantService._();

  /// The pack variant entry carrying [dayIndex], or null when the pack ships
  /// none for that day.
  ///
  /// Lookup is by the variant's own `dayIndex` key (never by list position),
  /// so a pack may carry documentation variants (the 54-day novena's
  /// `strict` / `permissive` / `include-luminous` entries) beside its day
  /// variants without disturbing the mapping.
  static Map<String, dynamic>? dayVariant(ContentPack pack, int dayIndex) {
    for (final Map<String, dynamic> variant in pack.variants) {
      if (variant['dayIndex'] == dayIndex) {
        return Map<String, dynamic>.unmodifiable(variant);
      }
    }
    return null;
  }

  /// The substitution tokens for [pack]'s day variant at [dayIndex].
  ///
  /// Returns the empty map when the pack carries no variant for [dayIndex]
  /// (the pinned "else empty tokens").
  ///
  /// A found variant becomes a token bag: `day` is the 1-based index and
  /// every other string-valued entry is a token under its own key — so the
  /// 54-day novena contributes `petition` (Task 7's documented legacy shape:
  /// both phases read `variant['petition']`), `phase`, `mysterySet`, and
  /// `virtue`. `mysteryTitle`/`mysteryFruit` are then resolved from the
  /// pack's mystery metadata (see [resolveBeadMysteryTokens]); `forDate`
  /// supplies the season-driven cycle when the variant names no set of its
  /// own.
  static Map<String, String> resolveDayVariant(
    ContentPack pack,
    int dayIndex, {
    DateTime? forDate,
  }) {
    final Map<String, dynamic>? variant = dayVariant(pack, dayIndex);
    if (variant == null) {
      return const <String, String>{};
    }
    final Map<String, String> tokens = <String, String>{
      'day': dayIndex.toString(),
    };
    for (final MapEntry<String, dynamic> entry in variant.entries) {
      final Object? value = entry.value;
      if (entry.key != 'id' && value is String) {
        tokens[entry.key] = value;
      }
    }
    tokens.addAll(_mysteryTokensFromVariant(pack, variant, forDate));
    return Map<String, String>.unmodifiable(tokens);
  }

  /// The day-level mystery tokens of a pack whose mystery cycle comes from
  /// the calendar rather than from a day variant (the rosary shape): the
  /// first decade of [forDate]'s set.
  ///
  /// Returns the empty map when [pack] carries no per-set mystery metadata —
  /// there is nothing to resolve, and the caller's substitution gate then
  /// reports any uncovered placeholder.
  static Map<String, String> resolveCycleMysteryTokens(
    ContentPack pack, {
    required DateTime forDate,
  }) {
    if (!_hasMysteryMetadata(pack)) {
      return const <String, String>{};
    }
    return resolveBeadMysteryTokens(pack: pack, forDate: forDate, beadIndex: 1);
  }

  /// The mystery tokens of the [beadIndex]-th (1-based) bead group of [pack]
  /// on [forDate].
  ///
  /// [setOverride] is the day variant's `mysterySet` when it names one (the
  /// 54-day novena): the day's cycle is the pack's own, not the calendar's.
  /// Without it, the set is [rosaryMysteriesFor] of [forDate] — the engine's
  /// season-aware selection — and only packs carrying per-set metadata
  /// resolve (see [_hasMysteryMetadata]).
  ///
  /// Resolution order:
  ///
  /// 1. the metadata entry whose `setTitle` equals the set and whose `index`
  ///    equals [beadIndex] — the rosary's exact decade;
  /// 2. failing an exact index, the set's entry at [beadIndex] clamped into
  ///    the available entries (a pack short of metadata still yields the
  ///    set's own first title rather than a placeholder leak);
  /// 3. when the pack ships no metadata at all but the day variant names a
  ///    set: that set's display title ([_setLabel]) and [fruitFallback] (the
  ///    variant's `virtue`) as its fruit.
  ///
  /// The returned tokens are `mysteryTitle` and, when known,
  /// `mysteryFruit`; nothing else is invented.
  static Map<String, String> resolveBeadMysteryTokens({
    required ContentPack pack,
    required int beadIndex,
    DateTime? forDate,
    String? setOverride,
    String? fruitFallback,
  }) {
    String? set = setOverride;
    if (set == null) {
      if (forDate == null || !_hasMysteryMetadata(pack)) {
        return const <String, String>{};
      }
      final LiturgicalDayData? day = LiturgicalCalendarService.getDayForDate(
        _dateOnly(forDate),
      );
      set = rosaryMysteriesFor(_dateOnly(forDate), day).name;
    }
    final List<Map<String, dynamic>> entries = <Map<String, dynamic>>[
      for (final Map<String, dynamic> variant in pack.variants)
        if (variant['setTitle'] == set) variant,
    ];
    if (entries.isEmpty) {
      if (setOverride == null) {
        return const <String, String>{};
      }
      return Map<String, String>.unmodifiable(<String, String>{
        'mysteryTitle': _setLabel(set),
        if (fruitFallback != null && fruitFallback.isNotEmpty)
          'mysteryFruit': fruitFallback,
      });
    }
    Map<String, dynamic> chosen = entries.first;
    for (final Map<String, dynamic> entry in entries) {
      if (entry['index'] == beadIndex) {
        chosen = entry;
        break;
      }
    }
    if (chosen['index'] != beadIndex) {
      final int position = (beadIndex - 1).clamp(0, entries.length - 1);
      chosen = entries[position];
    }
    final Object? title = chosen['mystery'];
    final Object? fruit = chosen['fruit'];
    return Map<String, String>.unmodifiable(<String, String>{
      if (title is String && title.isNotEmpty) 'mysteryTitle': title,
      if (fruit is String && fruit.isNotEmpty) 'mysteryFruit': fruit,
    });
  }

  /// Whether [pack] carries per-set mystery metadata (the rosary shape:
  /// entries keyed `setTitle` + `index` with `mystery`/`fruit` values).
  static bool _hasMysteryMetadata(ContentPack pack) {
    return pack.variants.any(
      (Map<String, dynamic> variant) =>
          variant['setTitle'] is String && variant['mystery'] is String,
    );
  }

  /// The mystery tokens a day [variant] itself implies.
  ///
  /// An entry carrying its own `mystery`/`fruit` answers directly; an entry
  /// naming a `mysterySet` defers to [resolveBeadMysteryTokens] (the day's
  /// set is the cycle, so the first decade's tokens are the day-level
  /// answer). Variants with neither carry no mystery tokens.
  static Map<String, String> _mysteryTokensFromVariant(
    ContentPack pack,
    Map<String, dynamic> variant,
    DateTime? forDate,
  ) {
    final Object? mystery = variant['mystery'];
    if (mystery is String && mystery.isNotEmpty) {
      final Object? fruit = variant['fruit'];
      return Map<String, String>.unmodifiable(<String, String>{
        'mysteryTitle': mystery,
        if (fruit is String && fruit.isNotEmpty) 'mysteryFruit': fruit,
      });
    }
    final Object? set = variant['mysterySet'];
    if (set is String && set.isNotEmpty) {
      final Object? virtue = variant['virtue'];
      return resolveBeadMysteryTokens(
        pack: pack,
        forDate: forDate,
        beadIndex: 1,
        setOverride: set,
        fruitFallback: virtue is String ? virtue : null,
      );
    }
    return const <String, String>{};
  }
}
