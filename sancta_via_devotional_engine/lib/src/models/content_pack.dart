/// The [ContentPack] model: one complete devotional program — schedule,
/// session script, and prayer content — as a self-contained data document.
///
/// A pack is the unit the fixturized devotional programs (Task 18's
/// consecration pack, the office packs, and so on) are shipped and loaded
/// in; `src/content/pack_loader.dart` reads the JSON documents this library
/// writes and validates.
///
/// ## Pack JSON format
///
/// ```json
/// {
///   "id": "holy-hour",
///   "title": "Holy Hour",
///   "family": "novena|commitment|office|routine|chaplet",
///   "schedule": {"type": "fixedDate", "month": 11, "day": 2},
///   "session": {"id": "s", "steps": [{"type": "prayer", "id": "s1",
///              "contentRef": "angelus"}]},
///   "content": {"angelus": {"id": "angelus", "text": "...",
///              "source": "Traditional", "license": "public-domain"}},
///   "reminders": {"daily": "09:00"},
///   "variants": [{"language": "latin"}]
/// }
/// ```
///
/// The `schedule` key also accepts the plural `schedules` form — a
/// non-empty list of schedule objects (e.g. a routine pack anchoring the
/// 6:00 Angelus and the 15:00 Hour of Mercy); the two forms are mutually
/// exclusive and both normalize into `ContentPack.schedules` (see the
/// class-level "Schedule forms" doc).
///
/// Schedule `type` dispatch covers every [ScheduleSpec] class:
/// `fixedDate|easterOffset|nthWeekdayOfMonth|consecutiveCommitments|weeklyLoop|timeOfDay`,
/// plus `sessionSeries` for `SessionSeriesSpec` (brief lists six classes;
/// `sessionSeries` is added so Task 18's consecration pack resolves its
/// user-planned start date through the same loader).
///
/// Step `type` dispatch covers every [SessionStep] class:
/// `prayer|verse|reflection|checkpoint|intercession|beadGroup|repetition|litany`.
/// The `prayer` and `repetition` steps carry a `contentRef` and the `verse`
/// step an optional `closingRef` (`reflection` an optional `textRef`) —
/// every reference must resolve to an entry of the pack's `content` map,
/// and a failing reference is a validation problem.
///
/// Validation is a single pass accumulating every problem into one
/// [ContentValidationException] (thrown once with the full `problems`
/// list) — malformed schedules, unknown families and types, missing
/// content references, and unlicensed text are all reported together.
/// The `content` map may be empty (or absent) when the session needs no
/// prayer text. `reminders` and `variants` are opaque app-layer shapes
/// passed through untouched.
library;

import '../content_validation_exception.dart';
import 'prayer_text.dart';
import 'schedule_spec.dart';
import 'session_script.dart';

/// The broad category a [ContentPack] belongs to, driving app-level
/// grouping and presentation.
enum PackFamily {
  /// A program of consecutive fulfillments (e.g. the Five First Saturdays).
  commitment,

  /// A bounded multi-day prayer series (e.g. a nine-day novena).
  novena,

  /// The church's daily prayer (e.g. Morning Prayer, Evening Prayer).
  office,

  /// A freely recurring habit (e.g. a daily Angelus).
  routine,

  /// A counted-beads devotion (e.g. the Rosary or a chaplet).
  chaplet,
}

/// One complete devotional program: schedule(s), session script, and
/// content.
///
/// Everything is immutable; the [schedules], [content], [reminders], and
/// [variants] collections are unmodifiable. [id] and [title] must be
/// non-empty.
///
/// ## Schedule forms
///
/// A pack carries one or more [ScheduleSpec] anchors:
///
/// - `"schedule": {...}` — one schedule (the historical, still-supported
///   single-anchor form);
/// - `"schedules": [{...}, ...]` — a non-empty list of schedules (e.g. a
///   routine pack anchoring the 6:00 Angelus and the 15:00 Hour of Mercy).
///
/// The two forms are mutually exclusive in one document. Both normalize to
/// [schedules] (with [schedule] always aliasing the first entry), while
/// [toJson] writes back whichever form the pack was built from, so a
/// round trip reproduces the loaded document.
class ContentPack {
  /// The stable identifier of the pack.
  final String id;

  /// The display title of the pack.
  final String title;

  /// The broad category of the program.
  final PackFamily family;

  /// An optional human-readable description of the devotion, shown as a
  /// subtitle in discovery surfaces such as onboarding.
  final String? description;

  /// The primary (first) schedule rule deciding when the session is due.
  ///
  /// Alias for [schedules].first: every pack has at least one schedule,
  /// whether built from the single `schedule` form or the `schedules` list.
  final ScheduleSpec schedule;

  /// Every schedule anchor of the pack, normalized into one unmodifiable
  /// list. Single-`schedule` packs carry exactly one entry.
  final List<ScheduleSpec> schedules;

  /// Whether this pack was built from the plural `schedules` form — the
  /// shape [toJson] writes back (see the class-level "Schedule forms" doc).
  final bool _serializedAsList;

  /// The ordered steps of the session the schedule makes due.
  final SessionScript session;

  /// The prayer texts the session's `contentRef` steps resolve against, by
  /// prayer id. May be empty when the session needs no prayer text.
  final Map<String, PrayerText> content;

  /// Opaque reminder configuration for the app layer (keyed by its own
  /// scheme). Never interpreted by the engine.
  final Map<String, dynamic> reminders;

  /// Opaque app-layer display variants. Never interpreted by the engine.
  final List<Map<String, dynamic>> variants;

  /// Creates a [ContentPack] from one or more [ScheduleSpec] anchors.
  ///
  /// Pass exactly one of [schedule] (single-anchor form) or [schedules]
  /// (multi-anchor list); [schedule] and [schedules] both alias the
  /// normalized list either way. Passing both keys is an [ArgumentError].
  ///
  /// Throws an [ArgumentError] when [id] or [title] is empty, or when the
  /// schedule arguments are missing / both given / (for [schedules]) empty.
  /// JSON loading reports every problem — including these — through
  /// [ContentPack.fromJson]'s accumulated [ContentValidationException]
  /// instead.
  ContentPack({
    ScheduleSpec? schedule,
    List<ScheduleSpec>? schedules,
    required this.id,
    required this.title,
    required this.family,
    this.description,
    required this.session,
    Map<String, PrayerText> content = const <String, PrayerText>{},
    Map<String, dynamic> reminders = const <String, dynamic>{},
    List<Map<String, dynamic>> variants = const <Map<String, dynamic>>[],
  }) : schedules = _normalizeScheduleArguments(schedule, schedules, id, title),
       schedule = schedule ?? schedules!.first,
       _serializedAsList = schedules != null,
       content = Map<String, PrayerText>.unmodifiable(content),
       reminders = Map<String, dynamic>.unmodifiable(reminders),
       variants = List<Map<String, dynamic>>.unmodifiable(variants);

  /// Parses one pack from its JSON representation.
  ///
  /// Validates the whole document in a single pass — id, title, family,
  /// schedule (either the `schedule` object or the `schedules` list form),
  /// session, content integrity (every step `contentRef` / `closingRef` /
  /// `textRef` must resolve), reminders, and variants — and throws one
  /// [ContentValidationException] carrying every problem detected. Unknown
  /// `family` values, unknown schedule and step `type` keys, unresolvable
  /// content references, and prayer texts failing their source/license
  /// check are all content-level problems in that one exception (spec
  /// constructor errors fold into the same list).
  ///
  /// The `content` map may be empty or absent. `reminders` and `variants`
  /// are optional.
  factory ContentPack.fromJson(Map<String, dynamic> json) {
    final List<String> problems = <String>[];

    final Object? idValue = json['id'];
    final String? idText = idValue is String ? idValue : null;
    if (idText == null || idText.isEmpty) {
      problems.add('id must be a non-empty string');
    }

    final Object? titleValue = json['title'];
    final String? titleText = titleValue is String ? titleValue : null;
    if (titleText == null || titleText.isEmpty) {
      problems.add('title must be a non-empty string');
    }

    final Object? familyValue = json['family'];
    PackFamily? family;
    if (familyValue == null) {
      problems.add("missing required field 'family'");
    } else if (familyValue is! String) {
      problems.add("'family' must be a string");
    } else {
      family = _familyByName(familyValue, problems);
    }

    String? description;
    if (json.containsKey('description')) {
      final String? parsed = _optionalString(json, 'description', problems, 'pack');
      if (parsed != null && parsed.trim().isNotEmpty) {
        description = parsed;
      }
    }

    ScheduleSpec? schedule;
    List<ScheduleSpec> schedules = const <ScheduleSpec>[];
    final Object? scheduleValue = json['schedule'];
    final Object? schedulesValue = json['schedules'];
    if (scheduleValue == null && schedulesValue == null) {
      problems.add("missing required field 'schedule'");
    } else if (scheduleValue != null && schedulesValue != null) {
      problems.add("'schedule' and 'schedules' must not both be provided");
    } else if (scheduleValue != null) {
      schedule = _parseScheduleSpec(scheduleValue, problems, 'schedule');
    } else if (schedulesValue is! List) {
      problems.add("'schedules' must be a JSON list");
    } else if (schedulesValue.isEmpty) {
      problems.add("'schedules' must not be empty");
    } else {
      final List<ScheduleSpec> parsed = <ScheduleSpec>[];
      for (int i = 0; i < schedulesValue.length; i++) {
        final ScheduleSpec? entry = _parseScheduleSpec(
          schedulesValue[i],
          problems,
          'schedules[$i]',
        );
        if (entry != null) {
          parsed.add(entry);
        }
      }
      schedules = parsed;
    }

    final Map<String, PrayerText> content = _parseContentMap(
      json['content'],
      problems,
    );

    SessionScript? session;
    if (json['session'] == null) {
      problems.add("missing required field 'session'");
    } else {
      session = _parseSessionScript(json['session'], problems, content);
    }

    Map<String, dynamic> reminders = const <String, dynamic>{};
    final Object? remindersValue = json['reminders'];
    if (remindersValue != null) {
      if (remindersValue is Map<String, dynamic>) {
        reminders = remindersValue;
      } else {
        problems.add('reminders must be a JSON object');
      }
    }

    List<Map<String, dynamic>> variants = const <Map<String, dynamic>>[];
    final Object? variantsValue = json['variants'];
    if (variantsValue != null) {
      if (variantsValue is! List) {
        problems.add('variants must be a list');
      } else {
        variants = <Map<String, dynamic>>[];
        for (int i = 0; i < variantsValue.length; i++) {
          final Object? entry = variantsValue[i];
          if (entry is Map<String, dynamic>) {
            variants.add(entry);
          } else {
            problems.add('variants[$i] must be a JSON object');
          }
        }
      }
    }

    if (problems.isNotEmpty) {
      throw ContentValidationException(
        message:
            'Pack "${idText ?? ''}" failed validation: '
            '${problems.join('; ')}',
        problems: problems,
      );
    }
    if (schedule != null) {
      return ContentPack(
        id: idText!, // non-null and non-empty: guaranteed by the problems check
        title: titleText!,
        family: family!,
        description: description,
        schedule: schedule,
        session: session!,
        content: content,
        reminders: reminders,
        variants: variants,
      );
    }
    // The plural form: schedule == null here means 'schedules' was the
    // loaded (and valid) form...
    return ContentPack(
      id: idText!, // non-null and non-empty: guaranteed by the problems check
      title: titleText!,
      family: family!,
      description: description,
      schedules: schedules,
      session: session!,
      content: content,
      reminders: reminders,
      variants: variants,
    );
  }

  /// Serializes this pack to a JSON-compatible map.
  ///
  /// The result re-parses through [ContentPack.fromJson] to a pack with
  /// the same id, title, family, schedules, and session. Step `contentRef`
  /// serialization emits the step's prayer's own id, so a round trip
  /// re-resolves against [content] when every step prayer is the content
  /// entry of that id (which [ContentPack.fromJson] guarantees it is).
  ///
  /// The schedule form is preserved: a pack built from the single
  /// `schedule` form writes `"schedule": {...}`; a pack built from the
  /// `schedules` list form writes `"schedules": [...]` (see the class-level
  /// "Schedule forms" doc).
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'title': title,
      'family': family.name,
      if (description != null) 'description': description,
      ...(_serializedAsList
          ? <String, dynamic>{
              'schedules': <Map<String, dynamic>>[
                for (final ScheduleSpec schedule in schedules)
                  _scheduleSpecToJson(schedule),
              ],
            }
          : <String, dynamic>{'schedule': _scheduleSpecToJson(schedule)}),
      'session': _sessionScriptToJson(session),
      'content': <String, dynamic>{
        for (final MapEntry<String, PrayerText> entry in content.entries)
          entry.key: entry.value.toJson(),
      },
      'reminders': <String, dynamic>{...reminders},
      'variants': <Map<String, dynamic>>[
        for (final Map<String, dynamic> variant in variants)
          <String, dynamic>{...variant},
      ],
    };
  }

  @override
  String toString() =>
      'ContentPack(id: $id, title: $title, family: $family, '
      'schedules: ${schedules.length}, session: $session, '
      'content: ${content.length} prayers)';
}

/// Validates the constructor schedule arguments, normalizing them into the
/// pack's schedule list. The [ArgumentError] every invalid combination
/// (missing, both forms given, empty list — plus empty id/title) carries is
/// thrown from here so the initializer list can reject a bad construction
/// before any field is set.
List<ScheduleSpec> _normalizeScheduleArguments(
  ScheduleSpec? schedule,
  List<ScheduleSpec>? schedules,
  String id,
  String title,
) {
  final List<String> problems = <String>[];
  if (id.isEmpty) {
    problems.add('id must not be empty');
  }
  if (title.isEmpty) {
    problems.add('title must not be empty');
  }
  if (schedule == null && schedules == null) {
    problems.add("missing required field 'schedule'");
  } else if (schedule != null && schedules != null) {
    problems.add("'schedule' and 'schedules' must not both be given");
  } else if (schedules != null && schedules.isEmpty) {
    problems.add("'schedules' must not be empty");
  }
  if (problems.isNotEmpty) {
    throw ArgumentError(
      'ContentPack(id: $id, title: $title) failed validation: '
      '${problems.join('; ')}',
    );
  }
  return List<ScheduleSpec>.unmodifiable(
    schedules ?? <ScheduleSpec>[schedule!],
  );
}

/// Resolves a `family` name, accumulating an unknown-value problem.
PackFamily? _familyByName(String name, List<String> problems) {
  switch (name) {
    case 'commitment':
      return PackFamily.commitment;
    case 'novena':
      return PackFamily.novena;
    case 'office':
      return PackFamily.office;
    case 'routine':
      return PackFamily.routine;
    case 'chaplet':
      return PackFamily.chaplet;
  }
  problems.add(
    'unknown family "$name" (expected: commitment, novena, office, '
    'routine, chaplet)',
  );
  return null;
}

/// Parses the pack's `content` map into its prayer texts.
///
/// Absent or null yields the empty map (an empty content map is allowed).
/// Each entry must be a prayer JSON object whose `id` matches its content
/// key; construction failures (e.g. an empty license, enforced by the
/// [PrayerText] constructor) accumulate as `content.<key>: <problem>`.
Map<String, PrayerText> _parseContentMap(Object? json, List<String> problems) {
  if (json == null) {
    return const <String, PrayerText>{};
  }
  if (json is! Map<String, dynamic>) {
    problems.add('content must be a JSON object');
    return const <String, PrayerText>{};
  }
  final Map<String, PrayerText> content = <String, PrayerText>{};
  json.forEach((String key, Object? value) {
    final String where = 'content.$key';
    if (value is! Map<String, dynamic>) {
      problems.add('$where must be a prayer JSON object');
      return;
    }
    final String? id = _requireString(value, 'id', problems, where);
    final String? text = _requireString(value, 'text', problems, where);
    final String? source = _requireString(value, 'source', problems, where);
    final String? license = _requireString(value, 'license', problems, where);
    final String? latin = _optionalString(value, 'latin', problems, where);
    if (id == null || text == null || source == null || license == null) {
      return;
    }
    if (id != key) {
      problems.add('$where: prayer id "$id" does not match its content key');
      return;
    }
    try {
      content[key] = PrayerText(
        id: id,
        text: text,
        latin: latin,
        source: source,
        license: license,
      );
    } on ContentValidationException catch (e) {
      for (final String problem in e.problems) {
        problems.add('$where: $problem');
      }
    }
  });
  return content;
}

/// Parses the pack's `session` object into a [SessionScript].
SessionScript? _parseSessionScript(
  Object? json,
  List<String> problems,
  Map<String, PrayerText> content,
) {
  if (json is! Map<String, dynamic>) {
    problems.add('session must be a JSON object');
    return null;
  }
  final String? id = _requireString(json, 'id', problems, 'session');
  final Object? stepsValue = json['steps'];
  if (stepsValue == null) {
    problems.add("session is missing 'steps'");
    return null;
  }
  if (stepsValue is! List) {
    problems.add('session.steps must be a list');
    return null;
  }
  if (stepsValue.isEmpty) {
    problems.add('session.steps must not be empty');
    return null;
  }
  final List<SessionStep> steps = <SessionStep>[];
  for (int i = 0; i < stepsValue.length; i++) {
    final Object? entry = stepsValue[i];
    if (entry is! Map<String, dynamic>) {
      problems.add('session.steps[$i] must be a JSON object');
      continue;
    }
    final SessionStep? step = _parseStep(
      entry,
      problems,
      content,
      'session.steps[$i]',
    );
    if (step != null) {
      steps.add(step);
    }
  }
  if (id == null || steps.isEmpty) {
    return null;
  }
  return SessionScript(id: id, steps: steps);
}

/// Parses one session step object by its `type` dispatch key.
SessionStep? _parseStep(
  Map<String, dynamic> json,
  List<String> problems,
  Map<String, PrayerText> content,
  String where,
) {
  final Object? type = json['type'];
  if (type == null) {
    problems.add("$where is missing its 'type'");
    return null;
  }
  if (type is! String || type.isEmpty) {
    problems.add("$where: 'type' must be a non-empty string");
    return null;
  }
  final String? id = _requireString(json, 'id', problems, where);
  final String? title = _optionalString(json, 'title', problems, where);
  switch (type) {
    case 'prayer':
      {
        final String? contentRef = _requireString(
          json,
          'contentRef',
          problems,
          where,
        );
        if (id == null || contentRef == null) {
          return null;
        }
        final PrayerText? text = _resolveContentRef(
          contentRef,
          content,
          problems,
          where,
          'contentRef',
        );
        if (text == null) {
          return null;
        }
        return PrayerStep(id: id, title: title, text: text);
      }
    case 'verse':
      {
        final String? versicle = _requireString(
          json,
          'versicle',
          problems,
          where,
        );
        final String? response = _requireString(
          json,
          'response',
          problems,
          where,
        );
        final String? closingRef = _optionalString(
          json,
          'closingRef',
          problems,
          where,
        );
        if (id == null || versicle == null || response == null) {
          return null;
        }
        final PrayerText? closing = _resolveContentRef(
          closingRef,
          content,
          problems,
          where,
          'closingRef',
        );
        return VerseStep(
          id: id,
          title: title,
          versicle: versicle,
          response: response,
          closing: closing,
        );
      }
    case 'reflection':
      {
        final String? textRef = _optionalString(
          json,
          'textRef',
          problems,
          where,
        );
        final int? durationSeconds = _requireInt(
          json,
          'durationSeconds',
          problems,
          where,
        );
        if (id == null || durationSeconds == null) {
          return null;
        }
        final PrayerText? text = _resolveContentRef(
          textRef,
          content,
          problems,
          where,
          'textRef',
        );
        return ReflectionStep(
          id: id,
          title: title,
          text: text,
          duration: Duration(seconds: durationSeconds),
        );
      }
    case 'checkpoint':
      {
        final String? item = _requireString(json, 'item', problems, where);
        final bool? requiredForCompletion = _requireBool(
          json,
          'requiredForCompletion',
          problems,
          where,
        );
        if (id == null || item == null || requiredForCompletion == null) {
          return null;
        }
        return CheckpointStep(
          id: id,
          title: title,
          item: item,
          requiredForCompletion: requiredForCompletion,
        );
      }
    case 'intercession':
      {
        final String? prompt = _requireString(json, 'prompt', problems, where);
        if (id == null || prompt == null) {
          return null;
        }
        return IntercessionStep(id: id, title: title, prompt: prompt);
      }
    case 'beadGroup':
      {
        final String? mysteryTitle = _optionalString(
          json,
          'mysteryTitle',
          problems,
          where,
        );
        final String? mysteryFruit = _optionalString(
          json,
          'mysteryFruit',
          problems,
          where,
        );
        final int? hailMaryCount = _requireInt(
          json,
          'hailMaryCount',
          problems,
          where,
        );
        final bool? includeFatimaPrayer = _requireBool(
          json,
          'includeFatimaPrayer',
          problems,
          where,
        );
        if (id == null ||
            hailMaryCount == null ||
            includeFatimaPrayer == null) {
          return null;
        }
        try {
          return BeadGroupStep(
            id: id,
            title: title,
            mysteryTitle: mysteryTitle,
            mysteryFruit: mysteryFruit,
            hailMaryCount: hailMaryCount,
            includeFatimaPrayer: includeFatimaPrayer,
          );
        } on ArgumentError catch (e) {
          problems.add('$where: ${e.message}');
          return null;
        }
      }
    case 'repetition':
      {
        final String? contentRef = _requireString(
          json,
          'contentRef',
          problems,
          where,
        );
        final int? count = _requireInt(json, 'count', problems, where);
        if (id == null || contentRef == null || count == null) {
          return null;
        }
        final PrayerText? text = _resolveContentRef(
          contentRef,
          content,
          problems,
          where,
          'contentRef',
        );
        if (text == null) {
          return null;
        }
        try {
          return RepetitionStep(id: id, title: title, text: text, count: count);
        } on ArgumentError catch (e) {
          problems.add('$where: ${e.message}');
          return null;
        }
      }
    case 'litany':
      {
        final List<String>? invocations = _stringList(
          json,
          'invocations',
          problems,
          where,
          allowMissing: false,
        );
        final String? response = _requireString(
          json,
          'response',
          problems,
          where,
        );
        final bool? groupedResponse = _requireBool(
          json,
          'groupedResponse',
          problems,
          where,
        );
        if (id == null ||
            invocations == null ||
            response == null ||
            groupedResponse == null) {
          return null;
        }
        try {
          return LitanyStep(
            id: id,
            title: title,
            invocations: invocations,
            response: response,
            groupedResponse: groupedResponse,
          );
        } on ArgumentError catch (e) {
          problems.add('$where: ${e.message}');
          return null;
        }
      }
    default:
      problems.add('$where: unknown step type "$type"');
      return null;
  }
}

/// Resolves a step's content reference; an unresolvable reference
/// accumulates a problem naming the missing id.
PrayerText? _resolveContentRef(
  String? ref,
  Map<String, PrayerText> content,
  List<String> problems,
  String where,
  String keyName,
) {
  if (ref == null) {
    return null;
  }
  final PrayerText? text = content[ref];
  if (text == null) {
    problems.add('$where: $keyName "$ref" does not resolve to content');
  }
  return text;
}

/// Parses a schedule object by its `type` dispatch key into a
/// [ScheduleSpec].
///
/// The dispatch covers all spec classes: `fixedDate`, `easterOffset`,
/// `nthWeekdayOfMonth`, `consecutiveCommitments`, `weeklyLoop`,
/// `timeOfDay`, and `sessionSeries` (see the library doc comment for the
/// sessionSeries ruling). Unknown `type` keys and missing or mis-typed
/// fields accumulate problems; spec constructor [ArgumentError]s (e.g. a
/// month outside the calendar) fold into the same list.
ScheduleSpec? _parseScheduleSpec(
  Object? json,
  List<String> problems,
  String where,
) {
  if (json is! Map<String, dynamic>) {
    problems.add('$where must be a JSON object');
    return null;
  }
  final Object? type = json['type'];
  if (type == null) {
    problems.add("$where is missing its 'type'");
    return null;
  }
  if (type is! String || type.isEmpty) {
    problems.add("$where: 'type' must be a non-empty string");
    return null;
  }
  switch (type) {
    case 'fixedDate':
      {
        final int? month = _requireInt(json, 'month', problems, where);
        final int? day = _requireInt(json, 'day', problems, where);
        final int? untilMonth = _optionalInt(
          json,
          'untilMonth',
          problems,
          where,
        );
        final int? untilDay = _optionalInt(json, 'untilDay', problems, where);
        if (month == null || day == null) {
          return null;
        }
        try {
          return FixedDateSpec(
            month,
            day,
            untilMonth: untilMonth,
            untilDay: untilDay,
          );
        } on ArgumentError catch (e) {
          problems.add('$where: ${e.message}');
          return null;
        }
      }
    case 'easterOffset':
      {
        final int? startOffset = _requireInt(
          json,
          'startOffset',
          problems,
          where,
        );
        final int? lengthDays = _requireInt(
          json,
          'lengthDays',
          problems,
          where,
        );
        if (startOffset == null || lengthDays == null) {
          return null;
        }
        try {
          return EasterOffsetSpec(startOffset, lengthDays);
        } on ArgumentError catch (e) {
          problems.add('$where: ${e.message}');
          return null;
        }
      }
    case 'nthWeekdayOfMonth':
      {
        final int? weekday = _requireInt(json, 'weekday', problems, where);
        final int? nth = _requireInt(json, 'nth', problems, where);
        if (weekday == null || nth == null) {
          return null;
        }
        try {
          return NthWeekdayOfMonthSpec(weekday, nth);
        } on ArgumentError catch (e) {
          problems.add('$where: ${e.message}');
          return null;
        }
      }
    case 'weeklyLoop':
      {
        final List<int>? weekdays = _intList(
          json,
          'weekdays',
          problems,
          where,
          allowMissing: false,
        );
        final List<int>? skipMonths = _intList(
          json,
          'skipMonths',
          problems,
          where,
          allowMissing: true,
        );
        if (weekdays == null) {
          return null;
        }
        try {
          return WeeklyLoopSpec(
            weekdays: Set<int>.of(weekdays),
            skipMonths: skipMonths,
          );
        } on ArgumentError catch (e) {
          problems.add('$where: ${e.message}');
          return null;
        }
      }
    case 'timeOfDay':
      {
        final int? hour = _requireInt(json, 'hour', problems, where);
        final int? minute = _requireInt(json, 'minute', problems, where);
        final String? baseLabel = _optionalString(
          json,
          'baseLabel',
          problems,
          where,
        );
        final List<SeasonVariant>? variants = _seasonVariants(
          json,
          problems,
          where,
        );
        if (hour == null || minute == null) {
          return null;
        }
        try {
          return TimeOfDaySpec(
            hour,
            minute,
            baseLabel: baseLabel,
            variants: variants ?? const <SeasonVariant>[],
          );
        } on ArgumentError catch (e) {
          problems.add('$where: ${e.message}');
          return null;
        }
      }
    case 'consecutiveCommitments':
      {
        ScheduleSpec? anchor;
        if (json['anchor'] == null) {
          problems.add("$where is missing its 'anchor'");
        } else {
          anchor = _parseScheduleSpec(
            json['anchor'],
            problems,
            '$where.anchor',
          );
        }
        final int? count = _requireInt(json, 'count', problems, where);
        final RestartPolicy? policy = _restartPolicy(json, problems, where);
        final List<GraceWindow> windows = _graceWindows(json, problems, where);
        if (anchor == null || count == null || policy == null) {
          return null;
        }
        try {
          return ConsecutiveCommitmentSpec(
            anchor: anchor,
            count: count,
            policy: policy,
            windows: windows,
          );
        } on ArgumentError catch (e) {
          problems.add('$where: ${e.message}');
          return null;
        }
      }
    case 'sessionSeries':
      {
        final String? startDateText = _requireString(
          json,
          'startDate',
          problems,
          where,
        );
        final int? lengthDays = _requireInt(
          json,
          'lengthDays',
          problems,
          where,
        );
        if (startDateText == null || lengthDays == null) {
          return null;
        }
        final DateTime? startDate = _localDate(
          startDateText,
          problems,
          where,
          'startDate',
        );
        if (startDate == null) {
          return null;
        }
        try {
          return SessionSeriesSpec(
            startDate: startDate,
            lengthDays: lengthDays,
          );
        } on ArgumentError catch (e) {
          problems.add('$where: ${e.message}');
          return null;
        }
      }
    default:
      problems.add('$where: unknown schedule type "$type"');
      return null;
  }
}

/// Resolves a commitment `policy` by name.
RestartPolicy? _restartPolicy(
  Map<String, dynamic> json,
  List<String> problems,
  String where,
) {
  final String? policyText = _requireString(json, 'policy', problems, where);
  switch (policyText) {
    case 'strict':
      return RestartPolicy.strict;
    case 'permissive':
      return RestartPolicy.permissive;
  }
  if (policyText != null) {
    problems.add(
      '$where: unknown policy "$policyText" (expected: strict, permissive)',
    );
  }
  return null;
}

/// Parses the optional `variants` list of a `timeOfDay` schedule.
List<SeasonVariant>? _seasonVariants(
  Map<String, dynamic> json,
  List<String> problems,
  String where,
) {
  final Object? value = json['variants'];
  if (value == null) {
    return null;
  }
  if (value is! List) {
    problems.add("$where: 'variants' must be a list");
    return null;
  }
  final List<SeasonVariant> variants = <SeasonVariant>[];
  for (int i = 0; i < value.length; i++) {
    final Object? entry = value[i];
    final String where2 = '$where.variants[$i]';
    if (entry is! Map<String, dynamic>) {
      problems.add('$where2 must be a JSON object');
      continue;
    }
    final String? variantId = _requireString(
      entry,
      'variantId',
      problems,
      where2,
    );
    final List<int>? months = _intList(
      entry,
      'months',
      problems,
      where2,
      allowMissing: true,
    );
    final List<String>? seasons = _stringList(
      entry,
      'seasons',
      problems,
      where2,
      allowMissing: true,
    );
    if (variantId == null) {
      continue;
    }
    try {
      variants.add(
        SeasonVariant(
          months: months ?? const <int>[],
          seasons: seasons == null ? null : Set<String>.of(seasons),
          variantId: variantId,
        ),
      );
    } on ArgumentError catch (e) {
      problems.add('$where2: ${e.message}');
    }
  }
  return variants;
}

/// Parses the optional `windows` list of a `consecutiveCommitments`
/// schedule.
List<GraceWindow> _graceWindows(
  Map<String, dynamic> json,
  List<String> problems,
  String where,
) {
  final Object? value = json['windows'];
  if (value == null) {
    return const <GraceWindow>[];
  }
  if (value is! List) {
    problems.add("$where: 'windows' must be a list");
    return const <GraceWindow>[];
  }
  final List<GraceWindow> windows = <GraceWindow>[];
  for (int i = 0; i < value.length; i++) {
    final Object? entry = value[i];
    final String where2 = '$where.windows[$i]';
    if (entry is! Map<String, dynamic>) {
      problems.add('$where2 must be a JSON object');
      continue;
    }
    final String? item = _requireString(entry, 'item', problems, where2);
    final int? beforeDays = _requireInt(entry, 'beforeDays', problems, where2);
    final int? afterDays = _requireInt(entry, 'afterDays', problems, where2);
    if (item == null || beforeDays == null || afterDays == null) {
      continue;
    }
    try {
      windows.add(
        GraceWindow(item: item, beforeDays: beforeDays, afterDays: afterDays),
      );
    } on ArgumentError catch (e) {
      problems.add('$where2: ${e.message}');
    }
  }
  return windows;
}

/// Parses a date-only (or local date-time) ISO string to a local-midnight
/// date, refusing time-zone-carrying inputs.
DateTime? _localDate(
  String text,
  List<String> problems,
  String where,
  String keyName,
) {
  final DateTime parsed;
  try {
    parsed = DateTime.parse(text);
  } on FormatException {
    problems.add('$where: $keyName "$text" is not an ISO date string');
    return null;
  }
  if (parsed.isUtc) {
    problems.add(
      '$where: $keyName must be a date-only string '
      '(no time-zone designator)',
    );
    return null;
  }
  return DateTime(parsed.year, parsed.month, parsed.day);
}

/// Serializes a [ScheduleSpec] back to its dispatch JSON.
///
/// The sealed switch is exhaustive over every spec class, so adding a spec
/// without its serialization fails compilation.
Map<String, dynamic> _scheduleSpecToJson(ScheduleSpec spec) {
  return switch (spec) {
    FixedDateSpec(
      :final int month,
      :final int day,
      :final int? untilMonth,
      :final int? untilDay,
    ) =>
      <String, dynamic>{
        'type': 'fixedDate',
        'month': month,
        'day': day,
        if (untilMonth != null) 'untilMonth': untilMonth,
        if (untilDay != null) 'untilDay': untilDay,
      },
    EasterOffsetSpec(:final int startOffset, :final int lengthDays) =>
      <String, dynamic>{
        'type': 'easterOffset',
        'startOffset': startOffset,
        'lengthDays': lengthDays,
      },
    NthWeekdayOfMonthSpec(:final int weekday, :final int nth) =>
      <String, dynamic>{
        'type': 'nthWeekdayOfMonth',
        'weekday': weekday,
        'nth': nth,
      },
    WeeklyLoopSpec(:final Set<int> weekdays, :final List<int>? skipMonths) =>
      <String, dynamic>{
        'type': 'weeklyLoop',
        'weekdays': List<int>.of(weekdays),
        if (skipMonths != null) 'skipMonths': List<int>.of(skipMonths),
      },
    TimeOfDaySpec(
      :final int hour,
      :final int minute,
      :final String? baseLabel,
      :final List<SeasonVariant> variants,
    ) =>
      <String, dynamic>{
        'type': 'timeOfDay',
        'hour': hour,
        'minute': minute,
        if (baseLabel != null) 'baseLabel': baseLabel,
        if (variants.isNotEmpty)
          'variants': <Map<String, dynamic>>[
            for (final SeasonVariant variant in variants)
              _seasonVariantToJson(variant),
          ],
      },
    ConsecutiveCommitmentSpec(
      :final ScheduleSpec anchor,
      :final int count,
      :final RestartPolicy policy,
      :final List<GraceWindow> windows,
    ) =>
      <String, dynamic>{
        'type': 'consecutiveCommitments',
        'anchor': _scheduleSpecToJson(anchor),
        'count': count,
        'policy': policy.name,
        if (windows.isNotEmpty)
          'windows': <Map<String, dynamic>>[
            for (final GraceWindow window in windows)
              <String, dynamic>{
                'item': window.item,
                'beforeDays': window.beforeDays,
                'afterDays': window.afterDays,
              },
          ],
      },
    SessionSeriesSpec(:final DateTime startDate, :final int lengthDays) =>
      <String, dynamic>{
        'type': 'sessionSeries',
        'startDate': _dateToIso(startDate),
        'lengthDays': lengthDays,
      },
  };
}

/// Serializes a [SeasonVariant] to its `timeOfDay.variants` entry.
Map<String, dynamic> _seasonVariantToJson(SeasonVariant variant) {
  return <String, dynamic>{
    if (variant.months.isNotEmpty) 'months': List<int>.of(variant.months),
    if (variant.seasons != null) 'seasons': List<String>.of(variant.seasons!),
    'variantId': variant.variantId,
  };
}

/// Serializes a [SessionScript] to its dispatch JSON.
Map<String, dynamic> _sessionScriptToJson(SessionScript script) {
  return <String, dynamic>{
    'id': script.id,
    'steps': <Map<String, dynamic>>[
      for (final SessionStep step in script.steps) _stepToJson(step),
    ],
  };
}

/// Serializes one [SessionStep] back to its dispatch JSON.
///
/// The sealed switch is exhaustive over every step class.
Map<String, dynamic> _stepToJson(SessionStep step) {
  return switch (step) {
    PrayerStep(
      :final String id,
      :final String? title,
      :final PrayerText text,
    ) =>
      <String, dynamic>{
        'type': 'prayer',
        'id': id,
        if (title != null) 'title': title,
        'contentRef': text.id,
      },
    VerseStep(
      :final String id,
      :final String? title,
      :final String versicle,
      :final String response,
      :final PrayerText? closing,
    ) =>
      <String, dynamic>{
        'type': 'verse',
        'id': id,
        if (title != null) 'title': title,
        'versicle': versicle,
        'response': response,
        if (closing != null) 'closingRef': closing.id,
      },
    ReflectionStep(
      :final String id,
      :final String? title,
      :final PrayerText? text,
      :final Duration duration,
    ) =>
      <String, dynamic>{
        'type': 'reflection',
        'id': id,
        if (title != null) 'title': title,
        if (text != null) 'textRef': text.id,
        'durationSeconds': duration.inSeconds,
      },
    CheckpointStep(
      :final String id,
      :final String? title,
      :final String item,
      :final bool requiredForCompletion,
    ) =>
      <String, dynamic>{
        'type': 'checkpoint',
        'id': id,
        if (title != null) 'title': title,
        'item': item,
        'requiredForCompletion': requiredForCompletion,
      },
    IntercessionStep(
      :final String id,
      :final String? title,
      :final String prompt,
    ) =>
      <String, dynamic>{
        'type': 'intercession',
        'id': id,
        if (title != null) 'title': title,
        'prompt': prompt,
      },
    BeadGroupStep(
      :final String id,
      :final String? title,
      :final String? mysteryTitle,
      :final String? mysteryFruit,
      :final int hailMaryCount,
      :final bool includeFatimaPrayer,
    ) =>
      <String, dynamic>{
        'type': 'beadGroup',
        'id': id,
        if (title != null) 'title': title,
        if (mysteryTitle != null) 'mysteryTitle': mysteryTitle,
        if (mysteryFruit != null) 'mysteryFruit': mysteryFruit,
        'hailMaryCount': hailMaryCount,
        'includeFatimaPrayer': includeFatimaPrayer,
      },
    RepetitionStep(
      :final String id,
      :final String? title,
      :final PrayerText text,
      :final int count,
    ) =>
      <String, dynamic>{
        'type': 'repetition',
        'id': id,
        if (title != null) 'title': title,
        'contentRef': text.id,
        'count': count,
      },
    LitanyStep(
      :final String id,
      :final String? title,
      :final List<String> invocations,
      :final String response,
      :final bool groupedResponse,
    ) =>
      <String, dynamic>{
        'type': 'litany',
        'id': id,
        if (title != null) 'title': title,
        'invocations': List<String>.of(invocations),
        'response': response,
        'groupedResponse': groupedResponse,
      },
  };
}

/// Renders a local-midnight date as its `yyyy-MM-dd` ISO string.
String _dateToIso(DateTime date) {
  final String month = date.month.toString().padLeft(2, '0');
  final String day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}

/// Reads a required string at [key], accumulating a problem when the value
/// is absent or not a string.
String? _requireString(
  Map<String, dynamic> json,
  String key,
  List<String> problems,
  String where,
) {
  final Object? value = json[key];
  if (value == null) {
    problems.add("$where: missing '$key'");
    return null;
  }
  if (value is String) {
    return value;
  }
  problems.add("$where: '$key' must be a string");
  return null;
}

/// Reads an optional string at [key]; absent yields null, a wrong-typed
/// value accumulates a problem.
String? _optionalString(
  Map<String, dynamic> json,
  String key,
  List<String> problems,
  String where,
) {
  final Object? value = json[key];
  if (value == null) {
    return null;
  }
  if (value is String) {
    return value;
  }
  problems.add("$where: '$key' must be a string");
  return null;
}

/// Reads a required integer at [key].
int? _requireInt(
  Map<String, dynamic> json,
  String key,
  List<String> problems,
  String where,
) {
  final Object? value = json[key];
  if (value == null) {
    problems.add("$where: missing '$key'");
    return null;
  }
  if (value is int) {
    return value;
  }
  problems.add("$where: '$key' must be an integer");
  return null;
}

/// Reads an optional integer at [key].
int? _optionalInt(
  Map<String, dynamic> json,
  String key,
  List<String> problems,
  String where,
) {
  final Object? value = json[key];
  if (value == null) {
    return null;
  }
  if (value is int) {
    return value;
  }
  problems.add("$where: '$key' must be an integer");
  return null;
}

/// Reads a required boolean at [key].
bool? _requireBool(
  Map<String, dynamic> json,
  String key,
  List<String> problems,
  String where,
) {
  final Object? value = json[key];
  if (value == null) {
    problems.add("$where: missing '$key'");
    return null;
  }
  if (value is bool) {
    return value;
  }
  problems.add("$where: '$key' must be a boolean");
  return null;
}

/// Reads an integer list at [key]; with [allowMissing] the key may be
/// absent, otherwise its absence accumulates a problem.
List<int>? _intList(
  Map<String, dynamic> json,
  String key,
  List<String> problems,
  String where, {
  required bool allowMissing,
}) {
  final Object? value = json[key];
  if (value == null) {
    if (!allowMissing) {
      problems.add("$where: missing '$key'");
    }
    return null;
  }
  if (value is! List || value.any((Object? e) => e is! int)) {
    problems.add("$where: '$key' must be a list of integers");
    return null;
  }
  return <int>[for (final Object? element in value) element as int];
}

/// Reads a string list at [key]; with [allowMissing] the key may be
/// absent, otherwise its absence accumulates a problem.
List<String>? _stringList(
  Map<String, dynamic> json,
  String key,
  List<String> problems,
  String where, {
  required bool allowMissing,
}) {
  final Object? value = json[key];
  if (value == null) {
    if (!allowMissing) {
      problems.add("$where: missing '$key'");
    }
    return null;
  }
  if (value is! List || value.any((Object? e) => e is! String)) {
    problems.add("$where: '$key' must be a list of strings");
    return null;
  }
  return <String>[for (final Object? element in value) element as String];
}
