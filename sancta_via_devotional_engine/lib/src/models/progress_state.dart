/// The user's progress through one devotional pack: the commitment
/// ordinals fulfilled so far, the last fulfilled date, the repetitions
/// recorded today, the per-day completed items, and the earned badges.
///
/// All dates are local calendar dates — reduced to local midnight
/// (`DateTime(year, month, day)`) on construction and serialized as
/// date-only ISO strings; as in the pack loader's date parsing, a
/// time-zone designator is refused at parse, because it would render a
/// different calendar date in another zone. The
/// [ProgressState.completedItemsByDay] keys follow the convention
/// `<item>:<yyyy-mm-dd>` (zero-padded, local dates) so the app layer can
/// group completions by item and day; the engine never interprets the
/// keys and carries them verbatim through [ProgressState.toJson] and
/// [ProgressState.fromJson].
///
/// Validation follows the engine's two conventions: constructing a
/// [ProgressState] with an empty pack id throws an [ArgumentError]
/// (badge titles are never empty — `BadgeRecord`'s constructor enforces
/// it), while parsing JSON is tolerant of shape but loud, accumulating
/// every problem into one [ContentValidationException] as the pack
/// loader does. The [ProgressState.completedItemsByDay] map and the
/// [ProgressState.badges] list are unmodifiable.
library;

import '../content_validation_exception.dart';

/// Reduces [d] to a local midnight date (a `DateTime(year, month, day)`
/// construction), preserving the local calendar components.
DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// The zero-padded `yyyy-mm-dd` rendering of a local date.
String _isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// One badge a pack granted, earned on a calendar date.
class BadgeRecord {
  /// The badge's display title (never empty).
  final String title;

  /// The local calendar date the badge was earned on (a local midnight
  /// date).
  final DateTime date;

  /// Creates a [BadgeRecord].
  ///
  /// [date] is reduced to a local midnight date (see the library docs).
  /// Throws an [ArgumentError] when [title] is empty.
  BadgeRecord({required this.title, required DateTime date})
    : date = _dateOnly(date) {
    if (title.isEmpty) {
      throw ArgumentError('title must not be empty');
    }
  }

  /// Parses one badge from its JSON representation.
  ///
  /// `title` must be a non-empty string (an absent or wrong-typed value
  /// reaches the constructor's [ArgumentError]); `date` must be an ISO
  /// date string without a time-zone designator, parsed to a local
  /// midnight date. Malformed input throws an [ArgumentError] — JSON
  /// loading folds it into the loader's accumulated
  /// [ContentValidationException].
  factory BadgeRecord.fromJson(Map<String, dynamic> json) {
    final Object? titleValue = json['title'];
    final String title = titleValue is String ? titleValue : '';

    final Object? dateValue = json['date'];
    if (dateValue is! String) {
      throw ArgumentError("'date' must be an ISO date string");
    }
    final DateTime parsed;
    try {
      parsed = DateTime.parse(dateValue);
    } on FormatException {
      throw ArgumentError('date "$dateValue" is not an ISO date string');
    }
    if (parsed.isUtc) {
      throw ArgumentError(
        "'date' must be a date-only string (no time-zone designator)",
      );
    }
    return BadgeRecord(title: title, date: parsed);
  }

  /// Serializes this badge to a JSON-compatible map.
  Map<String, dynamic> toJson() {
    return <String, dynamic>{'title': title, 'date': _isoDate(date)};
  }

  @override
  String toString() => 'BadgeRecord(title: $title, date: ${_isoDate(date)})';
}

/// The user's progress through one devotional pack: the commitment
/// ordinals fulfilled so far, the last fulfilled date, the repetitions
/// recorded today, the per-day completed items, and the earned badges.
class ProgressState {
  /// The id of the pack the progress belongs to — the content pack's own
  /// `id` (never empty).
  final String packId;

  /// The commitment ordinals fulfilled so far — the streak's length;
  /// zero when nothing is fulfilled yet or the pack carries no
  /// commitment.
  final int fulfilledOrdinals;

  /// The last date on which anything was completed (a local midnight
  /// date), or null when nothing is completed yet.
  final DateTime? lastFulfilled;

  /// The number of repetitions recorded today for counted devotions
  /// (e.g. decades of the rosary); zero until any are recorded. The day
  /// boundary is the app layer's to roll over; the engine only carries
  /// the value.
  final int repetitionsToday;

  /// The items completed on their days, keyed `<item>:<yyyy-mm-dd>`
  /// (e.g. `confession:2026-12-05`), with the app layer's own completion
  /// notes as values. The keys are never interpreted by the engine.
  final Map<String, String> completedItemsByDay;

  /// The badges earned so far, in earning order.
  final List<BadgeRecord> badges;

  /// Creates a [ProgressState], taking the supplied collections as
  /// unmodifiable copies and reducing [lastFulfilled] to a local midnight
  /// date.
  ///
  /// Throws an [ArgumentError] when [packId] is empty.
  ProgressState({
    required this.packId,
    this.fulfilledOrdinals = 0,
    DateTime? lastFulfilled,
    this.repetitionsToday = 0,
    Map<String, String> completedItemsByDay = const <String, String>{},
    List<BadgeRecord> badges = const <BadgeRecord>[],
  }) : lastFulfilled = lastFulfilled == null ? null : _dateOnly(lastFulfilled),
       completedItemsByDay = Map<String, String>.unmodifiable(
         completedItemsByDay,
       ),
       badges = List<BadgeRecord>.unmodifiable(badges) {
    if (packId.isEmpty) {
      throw ArgumentError(
        'ProgressState(packId: $packId) failed validation: '
        'packId must not be empty',
      );
    }
  }

  /// Parses one state from its JSON representation.
  ///
  /// Tolerant of shape: every field but `packId` is optional, defaulting
  /// to the zero state — zero ordinals, no last fulfilled date, no
  /// repetitions, empty completions, empty badges — and `packId` may be
  /// absent or mistyped (reported as a problem rather than failing to
  /// parse). Every problem — wrong types, an empty pack id, badges
  /// failing their checks, dates rejected by the date-only discipline —
  /// accumulates into one [ContentValidationException], thrown once with
  /// the full list, as the pack loader does.
  factory ProgressState.fromJson(Map<String, dynamic> json) {
    final List<String> problems = <String>[];

    final Object? packIdValue = json['packId'];
    final String? packId = packIdValue is String ? packIdValue : null;
    if (packId == null || packId.isEmpty) {
      problems.add('packId must be a non-empty string');
    }

    int fulfilledOrdinals = 0;
    final Object? ordinalsValue = json['fulfilledOrdinals'];
    if (ordinalsValue != null) {
      if (ordinalsValue is int) {
        fulfilledOrdinals = ordinalsValue;
      } else {
        problems.add("'fulfilledOrdinals' must be an integer");
      }
    }

    int repetitionsToday = 0;
    final Object? repetitionsValue = json['repetitionsToday'];
    if (repetitionsValue != null) {
      if (repetitionsValue is int) {
        repetitionsToday = repetitionsValue;
      } else {
        problems.add("'repetitionsToday' must be an integer");
      }
    }

    DateTime? lastFulfilled;
    final Object? lastValue = json['lastFulfilled'];
    if (lastValue != null) {
      if (lastValue is String) {
        lastFulfilled = _localDate(lastValue, "'lastFulfilled'", problems);
      } else {
        problems.add("'lastFulfilled' must be an ISO date string");
      }
    }

    final Map<String, String> completions = _parseCompletions(
      json['completedItemsByDay'],
      problems,
    );
    final List<BadgeRecord> badges = _parseBadges(json['badges'], problems);

    if (problems.isNotEmpty) {
      throw ContentValidationException(
        message:
            'ProgressState "${packId ?? ''}" failed validation: '
            '${problems.join('; ')}',
        problems: problems,
      );
    }
    return ProgressState(
      packId:
          packId!, // non-null and non-empty: guaranteed by the problems check
      fulfilledOrdinals: fulfilledOrdinals,
      lastFulfilled: lastFulfilled,
      repetitionsToday: repetitionsToday,
      completedItemsByDay: completions,
      badges: badges,
    );
  }

  /// Serializes this state to a JSON-compatible map.
  ///
  /// Dates are written as date-only ISO strings (zero-padded
  /// `yyyy-mm-dd`); a null [ProgressState.lastFulfilled] is omitted, so a
  /// round trip through [ProgressState.fromJson] preserves it as null.
  /// The result re-parses to a state with the same field values.
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'packId': packId,
      'fulfilledOrdinals': fulfilledOrdinals,
      if (lastFulfilled != null) 'lastFulfilled': _isoDate(lastFulfilled!),
      'repetitionsToday': repetitionsToday,
      'completedItemsByDay': <String, String>{...completedItemsByDay},
      'badges': <Map<String, dynamic>>[
        for (final BadgeRecord badge in badges) badge.toJson(),
      ],
    };
  }

  @override
  String toString() =>
      'ProgressState(packId: $packId, '
      'fulfilledOrdinals: $fulfilledOrdinals, '
      'lastFulfilled: ${lastFulfilled == null ? null : _isoDate(lastFulfilled!)}, '
      'repetitionsToday: $repetitionsToday, '
      'completedItemsByDay: ${completedItemsByDay.length} items, '
      'badges: ${badges.length}';
}

/// Parses a date-only (or local date-time) ISO string to a local-midnight
/// date, accumulating a problem when it fails to parse or carries a
/// time-zone designator.
DateTime? _localDate(String text, String keyName, List<String> problems) {
  final DateTime parsed;
  try {
    parsed = DateTime.parse(text);
  } on FormatException {
    problems.add('$keyName "$text" is not an ISO date string');
    return null;
  }
  if (parsed.isUtc) {
    problems.add(
      '$keyName must be a date-only string (no time-zone designator)',
    );
    return null;
  }
  return DateTime(parsed.year, parsed.month, parsed.day);
}

/// Parses the `completedItemsByDay` object into its
/// `<item>:<yyyy-mm-dd>` keyed map.
///
/// Absent or null yields the empty map; a wrong-typed value or a
/// non-string entry value accumulates a problem. The keys themselves are
/// the app layer's convention and are carried verbatim, never
/// interpreted.
Map<String, String> _parseCompletions(Object? json, List<String> problems) {
  if (json == null) {
    return const <String, String>{};
  }
  if (json is! Map<String, dynamic>) {
    problems.add('completedItemsByDay must be a JSON object');
    return const <String, String>{};
  }
  final Map<String, String> completions = <String, String>{};
  json.forEach((String key, Object? value) {
    if (value is String) {
      completions[key] = value;
    } else {
      problems.add('completedItemsByDay.$key must be a string');
    }
  });
  return completions;
}

/// Parses the `badges` list into its [BadgeRecord]s.
///
/// Absent or null yields the empty list; a wrong-typed list or entry
/// accumulates a problem, as does a badge failing its own checks (folded
/// from [BadgeRecord.fromJson] and the [BadgeRecord] constructor).
List<BadgeRecord> _parseBadges(Object? json, List<String> problems) {
  if (json == null) {
    return const <BadgeRecord>[];
  }
  if (json is! List) {
    problems.add('badges must be a list');
    return const <BadgeRecord>[];
  }
  final List<BadgeRecord> badges = <BadgeRecord>[];
  for (int i = 0; i < json.length; i++) {
    final Object? entry = json[i];
    if (entry is! Map<String, dynamic>) {
      problems.add('badges[$i] must be a JSON object');
      continue;
    }
    try {
      badges.add(BadgeRecord.fromJson(entry));
    } on ArgumentError catch (e) {
      problems.add('badges[$i]: ${e.message}');
    }
  }
  return badges;
}
