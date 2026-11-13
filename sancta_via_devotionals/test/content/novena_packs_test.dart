// Novena content (Plan 2, Task 22): the nine novena-family packs authored in
// this app's assets.
//
// Two layers are pinned here so neither can drift silently:
//
// 1. Shape and loading (the PackLoader's full validation pass): all nine
//    packs load, carry the `novena` family, and every content entry holds a
//    non-empty `source` and `license`. Content whose id matches the
//    committed companion import (`assets/content/prayers/`) must stay EQUAL
//    to that import — the routine packs' single-copy rule extended to the
//    novena packs — so a text fix lands in the import and re-ships through
//    the pipeline's content-version bump rather than diverging.
// 2. Schedules (the brief's per-tradition anchors) and session text: every
//    pack resolves at least one due date in 2026 AND 2027, the Christmas
//    novena's fixed window resolves across years (asked of 2027, it
//    resolves December 16..24, 2027), St. Jude is due Wednesdays only (and
//    Perpetual Help Tuesdays), and EVERY pack's session text fully
//    substitutes on every due day of 2026 and 2027 — the Task-7 leakage
//    gate run over each step's strings (the christmas/holy-spirit
//    `{{…}}` day tokens; sacred heart's `{{day}}`). The fixed-window
//    novenas and the two weekly loops each pin their tradition's dates.
//
// Schedule rulings documented in the packs' `reminders.schedule_note`
// (authoring metadata; the reminders map is opaque and never rendered):
// the brief's pinned Easter offsets are corrected to the engine's
// semantics — `holy_spirit_pentecost` startOffset 40 (the brief's "−10"
// would place the window in Holy Week) and `sacred_heart` startOffset 59
// (the brief's "+61" is the Friday after Corpus Christi itself, not the
// nine-day preparation) — with the divine_mercy_novena pack's house
// convention of a length-9 window that completes ON the feast (the feast
// day itself is not due): Holy Spirit ends at the Pentecost vigil, Sacred
// Heart ends at the vigil of the solemnity (Easter + 68: the Friday after
// Corpus Christi week, 19 days after Pentecost — both verified against the
// engine's own computus below).
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sancta_via_devotional_engine/sancta_via_devotional_engine.dart';
import 'package:sancta_via_devotionals/services/substitution_service.dart';
import 'package:sancta_via_devotionals/services/variant_service.dart';

/// The nine novena packs this task ships (filename == pack id stem).
const List<String> _novenaPackIds = <String>[
  'christmas_novena',
  'holy_spirit_pentecost',
  'miraculous_medal',
  'novena_for_the_dead',
  'perpetual_help',
  'sacred_heart',
  'st_joseph',
  'st_jude',
  'undoer_of_knots',
];

/// The whole shipped catalog: 8 engine-fixture + 6 Task-21 routine + 9
/// Task-22 novena + 10 Task-23 chaplet/litany packs, per the pin tests'
/// manifest expectation (the routine-packs test and the asset pin carry the
/// same count).
const int _shippedPackCount = 33;

/// Days from [start] (inclusive) through [start] + [count] (exclusive),
/// each a local midnight.
List<DateTime> _days(DateTime start, int count) => <DateTime>[
  for (int i = 0; i < count; i++)
    DateTime(start.year, start.month, start.day + i),
];

/// The single-static-session packs: their session text carries no
/// placeholders and their pack ships no day variants (the brief's
/// undoer-of-knots / st. joseph / for-the-dead trio, joined by the uniform
/// daily exercise of miraculous medal, perpetual help, and st. jude — the
/// latter two resolve without a day index at all, so no token could ever
/// resolve).
const List<String> _staticSessionPacks = <String>[
  'miraculous_medal',
  'novena_for_the_dead',
  'perpetual_help',
  'st_joseph',
  'st_jude',
  'undoer_of_knots',
];

/// Every user-facing string of [step] that the substitution pass rewrites.
List<String> stepTexts(SessionStep step) => switch (step) {
  PrayerStep(:final String? title, :final PrayerText text) => <String>[
    ?title,
    text.text,
    if (text.latin != null) text.latin!,
  ],
  VerseStep(
    :final String? title,
    :final String versicle,
    :final String response,
    :final PrayerText? closing,
  ) =>
    <String>[?title, versicle, response, ?closing?.text],
  ReflectionStep(:final String? title, :final PrayerText? text) => <String>[
    ?title,
    ?text?.text,
  ],
  IntercessionStep(:final String? title, :final String prompt) => <String>[
    ?title,
    prompt,
  ],
  CheckpointStep(:final String? title) => <String>[?title],
  RepetitionStep(:final String? title, :final PrayerText text) => <String>[
    ?title,
    text.text,
  ],
  LitanyStep(
    :final String? title,
    :final List<String> invocations,
    :final String response,
  ) =>
    <String>[?title, ...invocations, response],
  BeadGroupStep(
    :final String? title,
    :final String? mysteryTitle,
    :final String? mysteryFruit,
  ) =>
    <String>[?title, ?mysteryTitle, ?mysteryFruit],
};

/// The committed companion import, keyed by prayer id.
Map<String, PrayerText> committedImport() => <String, PrayerText>{
  for (final MapEntry<String, String> file in committedImportText().entries)
    file.key: PrayerText.fromJson(
      jsonDecode(file.value) as Map<String, dynamic>,
    ),
};

/// The committed import output's raw text, keyed by prayer id (file stem).
Map<String, String> committedImportText() => <String, String>{
  for (final String name
      in Directory('assets/content/prayers')
          .listSync()
          .whereType<File>()
          .map((File file) => file.path.split(Platform.pathSeparator).last)
          .where((String name) => name.endsWith('.json')))
    name.substring(0, name.length - 5): File(
      'assets/content/prayers/$name',
    ).readAsStringSync(),
};

/// The seven per-antiphon bodies of the committed `o_antiphons` import
/// (each block's "December …" date-header line stripped): index 0 ==
/// O Sapientia (December 17) through index 6 == O Emmanuel (December 23).
List<String> oAntiphonBodies() => <String>[
  for (final String block in (committedImport()['o_antiphons']!).text.split(
    '\n\n',
  ))
    block.split('\n').skip(1).join('\n'),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  ContentPack loadPack(String id) => PackLoader.loadFromJsonString(
    File('assets/content/packs/$id.json').readAsStringSync(),
  );

  group('novena packs', () {
    test(
      'all nine load through PackLoader; novena family; licensed content',
      () {
        final List<File> files =
            Directory('assets/content/packs')
                .listSync()
                .whereType<File>()
                .where((File file) => file.path.endsWith('.json'))
                .toList()
              ..sort((File a, File b) => a.path.compareTo(b.path));
        expect(
          files,
          hasLength(_shippedPackCount),
          reason:
              '33 = 8 engine fixtures + 6 Task-21 routine + 9 novena + 10 '
              'chaplet/litany packs',
        );
        for (final String id in _novenaPackIds) {
          final ContentPack pack = loadPack(id);
          expect(pack.id, id, reason: '$id: filename == pack id stem');
          expect(pack.family, PackFamily.novena, reason: id);
          for (final MapEntry<String, PrayerText> entry
              in pack.content.entries) {
            expect(
              entry.value.source,
              isNotEmpty,
              reason: '$id/content.${entry.key}',
            );
            expect(
              entry.value.license,
              isNotEmpty,
              reason: '$id/content.${entry.key}',
            );
          }
        }
      },
    );

    test('every pack resolves at least one due date in 2026 AND 2027', () {
      for (final String id in _novenaPackIds) {
        final ContentPack pack = loadPack(id);
        expect(
          PackValidator.problems(pack, 2026),
          isEmpty,
          reason: '$id: resolves at least one due date in 2026',
        );
        expect(
          PackValidator.problems(pack, 2027),
          isEmpty,
          reason: '$id: resolves at least one due date in 2027',
        );
      }
    });

    test('every content entry is licensed PD or original; no Diary text', () {
      for (final String id in _novenaPackIds) {
        final ContentPack pack = loadPack(id);
        for (final MapEntry<String, PrayerText> entry in pack.content.entries) {
          expect(
            entry.value.license.startsWith('public-domain') ||
                entry.value.license.startsWith('original'),
            true,
            reason:
                '$id/content.${entry.key}: license '
                '"${entry.value.license}" is outside the pack-authored '
                'vocabulary (public-domain… | original…)',
          );
          expect(
            entry.value.text.toLowerCase().contains('faustina') ||
                entry.value.source.toLowerCase().contains('faustina'),
            false,
            reason:
                '$id/content.${entry.key}: the House Divine-Mercy Diary '
                'rule keeps Diary-of-Faustina text out of the novena packs',
          );
        }
      }
    });

    test('embedded companion prayers match the committed import verbatim', () {
      final Map<String, PrayerText> imported = committedImport();
      for (final String id in _novenaPackIds) {
        final ContentPack pack = loadPack(id);
        for (final MapEntry<String, PrayerText> entry in pack.content.entries) {
          final PrayerText? source = imported[entry.key];
          if (source == null) {
            continue; // Authored content (novena prayers, invocations).
          }
          expect(
            entry.value,
            source,
            reason:
                '$id: content.${entry.key} must stay equal to the committed '
                'import (the single-copy rule, extended to the novena packs)',
          );
        }
      }
    });

    test('the weekly loops resolve only their pinned weekday', () {
      final Map<String, int> pinned = <String, int>{
        'perpetual_help': DateTime.tuesday,
        'st_jude': DateTime.wednesday,
      };
      pinned.forEach((String id, int weekday) {
        final ContentPack pack = loadPack(id);
        expect(pack.schedule, isA<WeeklyLoopSpec>(), reason: id);
        final ScheduleContext context = const ScheduleContext();
        for (final int year in <int>[2026, 2027]) {
          for (final DateTime day in _days(DateTime(year, 1, 1), 365)) {
            final bool due = pack.schedule.resolve(day, context).due;
            final bool dueOnWeekday = day.weekday == weekday;
            expect(
              due,
              dueOnWeekday,
              reason:
                  '$id: ${day.toIso8601String()} (weekday ${day.weekday}) '
                  'must be due exactly on weekday $weekday',
            );
          }
        }
      });
    });

    test(
      'christmas_novena: fixed window Dec 16-24 with the cross-year proof',
      () {
        final ContentPack pack = loadPack('christmas_novena');
        final FixedDateSpec spec = pack.schedule as FixedDateSpec;
        expect(spec.month, 12);
        expect(spec.day, 16);
        expect(spec.untilDay, 24);

        final ScheduleContext context = const ScheduleContext();
        for (final int year in <int>[2026, 2027]) {
          // Asked of $year: only the window's nine days resolve, each with
          // its 1-based day index (the fixed-date cross-year proof).
          expect(
            pack.schedule.resolve(DateTime(year, 12, 15), context).due,
            false,
            reason: '$year: the day before the window is not due',
          );
          for (final DateTime day in _days(DateTime(year, 12, 16), 9)) {
            final ScheduleResult result = pack.schedule.resolve(day, context);
            expect(result.due, true, reason: '$day must be due');
            expect(
              result.dayIndex,
              day.day - 15,
              reason: '$day: the window\u2019s 1-based day index',
            );
          }
          expect(
            pack.schedule.resolve(DateTime(year, 12, 25), context).due,
            false,
            reason: '$year: Christmas Day itself is outside the window',
          );
        }
      },
    );

    test('christmas_novena: day variants carry the per-day antiphons', () {
      final ContentPack pack = loadPack('christmas_novena');
      final List<String> oBodies = oAntiphonBodies();
      expect(oBodies, hasLength(7));

      final Map<int, String> pinned = <int, String>{
        1:
            'Drop down dew, O ye heavens, from above, and let the clouds '
            'rain the just: let the earth be opened and bring forth a Saviour.',
        9:
            'For a child is born to us, and a son is given to us, and the '
            'government is upon his shoulder: and his name shall be called '
            'Wonderful, Counsellor, God the Mighty, the Father of the world '
            'to come, the Prince of Peace.',
      };
      for (int dayIndex = 1; dayIndex <= 9; dayIndex++) {
        final Map<String, dynamic>? variant = VariantService.dayVariant(
          pack,
          dayIndex,
        );
        expect(variant, isNotNull, reason: 'day $dayIndex: the day variant');
        final String antiphon = variant!['antiphon']! as String;
        expect(antiphon, isNotEmpty, reason: 'day $dayIndex');
        // Days 2-8 are December 17-23 — the "Great O" antiphons verbatim
        // from the committed o_antiphons import; days 1 and 9 are the
        // pinned vigil texts (the Rorate rendering and the Douay Isaiah).
        expect(
          antiphon,
          pinned.containsKey(dayIndex)
              ? pinned[dayIndex]
              : oBodies[dayIndex - 2],
          reason: 'day $dayIndex',
        );
      }
    });

    test('holy_spirit_pentecost: Easter+40..+48, completing on Pentecost', () {
      final ContentPack pack = loadPack('holy_spirit_pentecost');
      final EasterOffsetSpec spec = pack.schedule as EasterOffsetSpec;
      expect(spec.startOffset, 40);
      expect(spec.lengthDays, 9);
      expect(easterSundayFor(2026), DateTime(2026, 4, 5));
      expect(easterSundayFor(2027), DateTime(2027, 3, 28));

      final ScheduleContext context = const ScheduleContext();
      final Map<int, List<DateTime>> windows = <int, List<DateTime>>{
        2026: _days(DateTime(2026, 5, 15), 9), // Apr 5 + 40 .. + 48.
        2027: _days(DateTime(2027, 5, 7), 9), // Mar 28 + 40 .. + 48.
      };
      windows.forEach((int year, List<DateTime> window) {
        for (final DateTime day in window) {
          final ScheduleResult result = pack.schedule.resolve(day, context);
          expect(result.due, true, reason: '$day must be due');
          expect(
            result.dayIndex,
            window.indexOf(day) + 1,
            reason: '$day: the novena\u2019s 1-based day index',
          );
        }
        // Day 1 is the Friday after Ascension (the tradition's start).
        expect(window.first.weekday, DateTime.friday, reason: 'year $year');
        // The window ends at the Pentecost vigil; the feast itself (the
        // following Sunday) completes the novena and is NOT due.
        final DateTime pentecost = DateTime(
          window.last.year,
          window.last.month,
          window.last.day + 1,
        );
        expect(pentecost.weekday, DateTime.sunday);
        expect(
          pack.schedule.resolve(pentecost, context).due,
          false,
          reason: '$pentecost: the feast completes the novena, not due',
        );
      });
    });

    test(
      'holy_spirit_pentecost: day variants carry the per-day gift invocations',
      () {
        final ContentPack pack = loadPack('holy_spirit_pentecost');
        for (int dayIndex = 1; dayIndex <= 9; dayIndex++) {
          final Map<String, dynamic>? variant = VariantService.dayVariant(
            pack,
            dayIndex,
          );
          expect(variant, isNotNull, reason: 'day $dayIndex');
          expect(
            (variant!['gift']! as String),
            isNotEmpty,
            reason: 'day $dayIndex',
          );
          expect(
            (variant['invocation']! as String),
            isNotEmpty,
            reason: 'day $dayIndex: the per-day invocation text',
          );
        }
      },
    );

    test('sacred_heart: Easter+59..+67, completing on the solemnity (+68)', () {
      final ContentPack pack = loadPack('sacred_heart');
      final EasterOffsetSpec spec = pack.schedule as EasterOffsetSpec;
      expect(spec.startOffset, 59);
      expect(spec.lengthDays, 9);

      final ScheduleContext context = const ScheduleContext();
      final Map<int, List<DateTime>> windows = <int, List<DateTime>>{
        2026: _days(DateTime(2026, 6, 3), 9), // Jun 3..Jun 11.
        2027: _days(DateTime(2027, 5, 26), 9), // May 26..Jun 3.
      };
      windows.forEach((int year, List<DateTime> window) {
        for (final DateTime day in window) {
          final ScheduleResult result = pack.schedule.resolve(day, context);
          expect(result.due, true, reason: '$day must be due');
          expect(
            result.dayIndex,
            window.indexOf(day) + 1,
            reason: '$day: the novena\u2019s 1-based day index',
          );
        }
        // The window ends at the vigil (a Thursday); the solemnity is the
        // following Friday and completes the novena — NOT due.
        expect(window.last.weekday, DateTime.thursday, reason: 'year $year');
        final DateTime solemnity = DateTime(
          window.last.year,
          window.last.month,
          window.last.day + 1,
        );
        expect(solemnity.weekday, DateTime.friday);
        expect(
          pack.schedule.resolve(solemnity, context).due,
          false,
          reason: '$solemnity: the feast completes the novena, not due',
        );
      });
      // The solemnity is Easter + 68: exactly 19 days after Pentecost
      // (+49) — the traditional "Friday after Corpus Christi week" —
      // verified against the engine's own computus for both proof years,
      // correcting the brief's pinned "+61" (which is the day E+61: the
      // Friday after Corpus Christi itself, Corpus Christi = E+60).
      for (final int year in <int>[2026, 2027]) {
        final DateTime easter = easterSundayFor(year);
        final DateTime solemnity = DateTime(
          easter.year,
          easter.month,
          easter.day + 68,
        );
        final DateTime pentecost = DateTime(
          easter.year,
          easter.month,
          easter.day + 49,
        );
        expect(
          solemnity.difference(pentecost).inDays,
          19,
          reason: '$year: +68 is 19 days after Pentecost',
        );
        expect(solemnity.weekday, DateTime.friday, reason: '$year');
      }
    });

    test(
      'every pack\u2019s session text fully substitutes on every due day',
      () {
        final ScheduleContext context = const ScheduleContext();
        for (final String id in _novenaPackIds) {
          final ContentPack pack = loadPack(id);
          for (final int year in <int>[2026, 2027]) {
            for (final DateTime day in _days(DateTime(year, 1, 1), 365)) {
              final ScheduleResult result = pack.schedule.resolve(day, context);
              if (!result.due) {
                continue;
              }
              // The session player's token flow: the day variant's bag,
              // always the resolved `day` when the schedule yields one.
              final Map<String, String> tokens = <String, String>{
                ...VariantService.resolveDayVariant(
                  pack,
                  result.dayIndex ?? -1,
                  forDate: day,
                ),
                if (result.dayIndex != null) 'day': result.dayIndex.toString(),
              };
              for (final SessionStep step in pack.session.steps) {
                for (final String text in stepTexts(step)) {
                  expect(
                    () => SubstitutionService.requireFullySubstituted(
                      SubstitutionService.substitute(text, tokens: tokens),
                    ),
                    returnsNormally,
                    reason: '$id: $day, step ${step.id}, tokens $tokens',
                  );
                }
              }
            }
          }
        }
      },
    );

    test(
      'the single-static-session packs ship no day variants or placeholders',
      () {
        for (final String id in _staticSessionPacks) {
          final ContentPack pack = loadPack(id);
          expect(
            pack.variants.where(
              (Map<String, dynamic> variant) => variant['dayIndex'] is int,
            ),
            isEmpty,
            reason: '$id: a static session ships no day variants',
          );
          for (final SessionStep step in pack.session.steps) {
            for (final String text in stepTexts(step)) {
              expect(
                text.contains('{{'),
                false,
                reason:
                    '$id, step ${step.id}: a session with no day tokens must '
                    'never carry a placeholder (the substitution gate would '
                    'throw on a due day)',
              );
            }
          }
        }
      },
    );

    test('the fixed-window novenas resolve their traditional windows', () {
      // (window start, length, the feast-or-eve note for failure reasons)
      final Map<String, (DateTime, int, String)> windows =
          <String, (DateTime, int, String)>{
            // All Souls' Day is the novena's own first day (the tradition's
            // start; the nine days run November 2..10).
            'novena_for_the_dead': (DateTime(2026, 11, 2), 9, 'Nov 2-10'),
            // The nine days before the September 28 Undoer-of-Knots memorial.
            'undoer_of_knots': (DateTime(2026, 9, 19), 9, 'Sep 19-27'),
            // The nine days before the November 27 Miraculous Medal feast.
            'miraculous_medal': (DateTime(2026, 11, 18), 9, 'Nov 18-26'),
            // The nine days before the March 19 Solemnity of St. Joseph.
            'st_joseph': (DateTime(2026, 3, 10), 9, 'Mar 10-18'),
          };
      final ScheduleContext context = const ScheduleContext();
      windows.forEach((String id, (DateTime, int, String) window) {
        final ContentPack pack = loadPack(id);
        final FixedDateSpec spec = pack.schedule as FixedDateSpec;
        expect(spec.month, window.$1.month, reason: '$id: window start month');
        expect(spec.day, window.$1.day, reason: '$id: window start day');
        expect(
          spec.untilDay,
          window.$1.day + window.$2 - 1,
          reason: '$id: inclusive window end (also same-month)',
        );
        for (final int year in <int>[2026, 2027]) {
          final List<DateTime> days = _days(
            DateTime(year, window.$1.month, window.$1.day),
            window.$2,
          );
          for (final DateTime day in days) {
            final ScheduleResult result = pack.schedule.resolve(day, context);
            expect(result.due, true, reason: '$id: $day must be due');
            expect(
              result.dayIndex,
              days.indexOf(day) + 1,
              reason: '$id: $day the 1-based day index',
            );
          }
          expect(
            pack.schedule
                .resolve(
                  DateTime(year, window.$1.month, window.$1.day - 1),
                  context,
                )
                .due,
            false,
            reason: '$id (${window.$3}): the day before the window is not due',
          );
          final DateTime after = DateTime(
            year,
            window.$1.month,
            window.$1.day + window.$2,
          );
          expect(
            pack.schedule.resolve(after, context).due,
            false,
            reason:
                '$id (${window.$3}): the day after the window '
                '(${after.month}/${after.day}) is not due — the window '
                'completes at the feast',
          );
        }
      });
    });
  });
}
