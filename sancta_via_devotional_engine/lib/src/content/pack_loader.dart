/// Loading and validating [ContentPack]s from JSON documents and fixture
/// directories.
///
/// The pack JSON format itself is documented on `ContentPack` (see
/// `src/models/content_pack.dart`), which owns the single-validation-pass
/// parsing every entry point here delegates to.
library;

import 'dart:convert';
import 'dart:io';

import '../content_validation_exception.dart';
import '../models/content_pack.dart';
import '../models/prayer_text.dart';
import '../models/schedule_context.dart';

/// Loads [ContentPack]s from decoded JSON, JSON strings, or fixture
/// directories.
///
/// All three entry points run the same single validation pass (see
/// [ContentPack.fromJson]) and throw one `ContentValidationException`
/// carrying every problem — including the license enforcement that never
/// renders a prayer text missing its source or license.
class PackLoader {
  const PackLoader._();

  /// Parses one pack from a decoded JSON object.
  ///
  /// See [ContentPack.fromJson] for the validation pass this delegates to.
  static ContentPack load(Map<String, dynamic> json) {
    return ContentPack.fromJson(json);
  }

  /// Parses one pack from a JSON document string.
  ///
  /// Malformed JSON syntax throws a `FormatException` from the decoder;
  /// a top-level non-object (e.g. a JSON array) is a content-level problem
  /// and throws a [ContentValidationException].
  static ContentPack loadFromJsonString(String s) {
    final Object? decoded = jsonDecode(s);
    if (decoded is! Map<String, dynamic>) {
      throw ContentValidationException(
        message:
            'pack JSON must be a JSON object, not a '
            '${decoded.runtimeType}',
        problems: <String>['pack JSON must be a JSON object'],
      );
    }
    return ContentPack.fromJson(decoded);
  }

  /// Loads every `.json` file directly inside [dir], in sorted filename
  /// order, as packs.
  ///
  /// The scan is non-recursive: only files ending in `.json` are read
  /// (subdirectories and other files are ignored), so a fixture directory's
  /// pack order is deterministic. Each file must parse as a pack; a
  /// failing file throws its `ContentValidationException`. This is a
  /// `dart:io` (VM / native embedder) facility — notably used at build
  /// time to embed packs; runtime loading through dart:core-safe APIs
  /// should prefer [load]/[loadFromJsonString].
  static List<ContentPack> loadFixturesIn(String dir) {
    final List<FileSystemEntity> entries = Directory(dir).listSync();
    final List<String> paths = <String>[
      for (final FileSystemEntity entry in entries)
        if (entry is File && entry.path.endsWith('.json')) entry.path,
    ]..sort();
    return <ContentPack>[
      for (final String path in paths)
        loadFromJsonString(File(path).readAsStringSync()),
    ];
  }
}

/// Static checks over a loaded [ContentPack] that a fixture's schedule and
/// content must satisfy.
class PackValidator {
  const PackValidator._();

  /// The problems found against [pack] for the given [fixtureYear], or an
  /// empty list when the pack is valid.
  ///
  /// Two checks:
  ///
  /// 1. The pack's schedule must resolve to at least one due date within
  ///    [fixtureYear]: every calendar day of the year is resolved with an
  ///    empty [ScheduleContext]. A schedule with zero due dates (e.g. a
  ///    one-shot session series planned entirely in another year) is a
  ///    problem.
  /// 2. Every content prayer text must carry a non-empty source and
  ///    license. [PrayerText]'s constructor already enforces this at load
  ///    time; the check is repeated here so a caller handed only a
  ///    constructed pack still receives a message naming the offending
  ///    content key.
  static List<String> problems(ContentPack pack, int fixtureYear) {
    final List<String> problems = <String>[];
    final ScheduleContext context = ScheduleContext();
    bool anyDue = false;
    for (int month = 1; month <= 12 && !anyDue; month++) {
      final int lastDay = DateTime(fixtureYear, month + 1, 0).day;
      for (int day = 1; day <= lastDay && !anyDue; day++) {
        if (pack.schedule
            .resolve(DateTime(fixtureYear, month, day), context)
            .due) {
          anyDue = true;
        }
      }
    }
    if (!anyDue) {
      problems.add('schedule resolves to zero due dates in $fixtureYear');
    }
    for (final MapEntry<String, PrayerText> entry in pack.content.entries) {
      if (entry.value.source.isEmpty) {
        problems.add('content.${entry.key}: source must not be empty');
      }
      if (entry.value.license.isEmpty) {
        problems.add('content.${entry.key}: license must not be empty');
      }
    }
    return problems;
  }
}
