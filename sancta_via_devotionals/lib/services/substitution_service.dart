// Placeholder substitution for pack session content (Plan 2, Task 7).
//
// Pack session text and variant formulas carry `{{…}}` placeholders. The
// sanctioned token set is `day`, `mysteryTitle`, and `mysteryFruit` — the
// pack-content conventions from Plan 1 Tasks 16/17 (the rosary/54-day packs
// template bead-group mystery titles and fruits; day-indexed novena texts
// template the day number, e.g. "Day {{day}} of the 33-day preparation").
// Callers resolve the day's variant (Task 10 owns that: `dayIndex` from the
// `ScheduleResult`, the mystery tokens from the cycle) and drive every string
// through [SubstitutionService.substitute] ONCE at session start.
//
// Leakage gate: [SubstitutionService.requireFullySubstituted] is THE gate the
// session player (Task 10) and the render layer (Task 11) run before any
// session text reaches the screen. An unresolved `{{…}}` occurrence is a
// Review Focus 4 defect — a user-visible template leak — so it throws a
// `StateError` listing ALL remaining occurrences instead of rendering.
//
// Substitution semantics — ONE pass, verbatim insertion (documented choice):
//
// - A single left-to-right scan replaces every `{{key}}` whose key is in the
//   token map with the mapped value verbatim, and replaces `{{day}}` from
//   `dayIndex` (the caller's explicit `'day'` token entry overrides
//   `dayIndex`). No recursion: substituted values are never re-scanned.
// - Keys absent from the effective token set — including `{{day}}` when no
//   `dayIndex` is supplied — stay untouched and will trip the requirement
//   gate. By the same one-pass rule a substituted VALUE containing
//   `{{…}}` survives substitution verbatim and is then flagged by
//   `requireFullySubstituted` on the final output (never silently
//   double-substituted).
//
// Known legacy shape (Plan 1 Task 19 ruling): the 54-day pack stores the
// thanksgiving-decade formulas under key `petition` for BOTH phases — the
// petition phase's formulas and the thanksgiving phase's formulas both live
// under `petition`. Callers read `variant['petition']` regardless of phase
// and hand that text in as a token value; this service is shape-agnostic on
// the token map.
library;

/// Static placeholder substitution and leakage-gating for pack session
/// content.
class SubstitutionService {
  /// `{{key}}` placeholders: double braces around a non-empty run of
  /// non-brace characters. Keys are matched exactly (no trimming) and the
  /// same pattern drives both substitution and the leftover scan.
  static final RegExp _placeholderPattern = RegExp(r'\{\{([^{}]+)\}\}');

  /// Substitutes sanctioned placeholders in [input] in one pass.
  ///
  /// Every `{{key}}` whose key is present in [tokens] becomes the mapped
  /// value verbatim; `{{day}}` additionally resolves from [dayIndex] when
  /// given (an explicit `'day'` entry in [tokens] overrides it). Keys with no
  /// resolution — including `{{day}}` without a [dayIndex] — stay in the
  /// output untouched; pair every user-facing use with
  /// [requireFullySubstituted] so leftovers can never render.
  static String substitute(
    String input, {
    Map<String, String> tokens = const <String, String>{},
    int? dayIndex,
  }) {
    final Map<String, String> effective = <String, String>{
      if (dayIndex != null) 'day': dayIndex.toString(),
      ...tokens,
    };
    return input.replaceAllMapped(_placeholderPattern, (Match match) {
      final String key = match.group(1)!;
      return effective[key] ?? match.group(0)!;
    });
  }

  /// The leakage gate: returns [input] unchanged when it carries no
  /// remaining `{{…}}` occurrence, otherwise throws a `StateError` whose
  /// message lists ALL remaining occurrences (not just the first) — session
  /// text must arrive fully substituted before it is rendered.
  static String requireFullySubstituted(String input) {
    final List<String> leftovers = <String>[
      for (final RegExpMatch match in _placeholderPattern.allMatches(input))
        match.group(0)!,
    ];
    if (leftovers.isEmpty) {
      return input;
    }
    throw StateError(
      'Unresolved placeholders remain — session text must be fully '
      'substituted before rendering: ${leftovers.join(', ')}',
    );
  }
}
