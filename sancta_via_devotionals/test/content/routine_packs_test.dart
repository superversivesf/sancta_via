// Routine content (Plan 2, Task 21): companion import + the six routine
// packs.
//
// Two layers are pinned here so neither can drift silently:
//
// 1. The import (`tool/import_prayers.dart`): the tool maps the prayer
//    companion's READ-ONLY assets onto engine [PrayerText] entries and
//    commits the result under `assets/content/prayers/*.json`. The test
//    re-derives the mapping IN MEMORY (never through the tool's writing
//    `runImport`) and checks it against the committed files in both
//    directions — any edit to the companion or the tool that changes the
//    accepted/rejected split must consciously update the pinned rejected
//    list below (no rejected-prayer regression without an explicit list
//    update).
// 2. The six routine packs under `assets/content/packs/`: authored content
//    that follows the engine-fixture packs' shape, loads through
//    [PackLoader], carries the brief's schedule anchors, and — with
//    [PackValidator.problems] over fixture year 2026 — proves its schedules
//    resolve. Prayers the packs embed under the imported prayer's own id
//    must stay equal to the committed import (single-copy rule), so a text
//    fix lands in the import (and re-ships through the pipeline's
//    content-version bump) rather than diverging.
//
// The Lectio pack deliberately stores only a SKELETON: the verse step is the
// day's-readings placeholder, and the pack's `reminders.readings` note
// documents the app-side bible riverpod feed (no dynamic readings are
// embedded — the brief's readings ruling). Likewise the Morning Offering
// pack's papal-intention line is a MANUALLY-updated content field (spec risk
// #6): the intercession prompt and the `reminders.papal_intention` note ship
// the line, with no network fetch.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sancta_via_devotional_engine/sancta_via_devotional_engine.dart';

import '../../tool/import_prayers.dart' as importer;

/// The six routine packs this task ships (filename == pack id stem).
const List<String> _routinePackIds = <String>[
  'morning_offering',
  'daily_examen',
  'lectio_divina',
  'meal_night_prayers',
  'fixed_prayers_morning',
  'fixed_prayers_night',
];

/// The engine-fixture packs plus the six Task-21 routine packs and the nine
/// Task-22 novena packs: the whole shipped catalog, matching the pin test's
/// manifest expectation.
const int _shippedPackCount = 23;

/// The import's pinned rejected-prayer list. A companion or tool change that
/// alters the split changes this expectation — and then this list, the
/// tool's classification table, the committed `assets/content/prayers/`, and
/// the tool's re-run must all be updated together, CONSCIOUSLY.
const List<String> _pinnedRejectedIds = <String>[
  // No companion `attribution` (the companion's own metadata omits them):
  'blessed_trinity_morning',
  'confiteor',
  'jesus_mary_joseph',
  'magnificat',
  'my_god_i_believe',
  'o_mary_conceived_without_sin',
  'prayer_to_st_joseph_purity',
  'sacred_heart_consecration',
  'second_fatima_prayer',
  'st_andrew_novena',
  'te_deum',
  'third_fatima_prayer',
  // ICEL-era liturgical editions (Roman Missal / Martyrology):
  'christmas_proclamation',
  'memorial_acclamation_1',
  'memorial_acclamation_2',
  'memorial_acclamation_3',
  'prayer_for_pope_formal',
  // ICEL/Grail-era Liturgy of the Hours English:
  'compline_commendation',
  'compline_final_prayer',
  'compline_protection',
  'nunc_dimittis',
  // Modern (2021) expansion of an otherwise public-domain litany:
  'litany_st_joseph',
];

/// The in-memory import mapping over the real companion assets (the tool's
/// own mapping functions, WITHOUT its file writes).
importer.ImportOutcome mappedImport() {
  final Map<String, PrayerText> accepted = <String, PrayerText>{};
  final Map<String, String> rejected = <String, String>{};
  for (final MapEntry<String, Map<String, Object?>> entry
      in importer.loadCompanionPrayers(importer.companionAssetsDir).entries) {
    final importer.ImportedPrayer verdict = importer.mapCompanionPrayer(
      entry.value,
    );
    if (verdict.accepted) {
      accepted[verdict.id] = verdict.prayer!;
    } else {
      rejected[verdict.id] = verdict.rejection!;
    }
  }
  return importer.ImportOutcome(accepted: accepted, rejected: rejected);
}

/// The committed import output, keyed by prayer id.
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

/// Every shipped pack asset, filename order.
List<File> shippedPackFiles() =>
    Directory('assets/content/packs')
        .listSync()
        .whereType<File>()
        .where((File file) => file.path.endsWith('.json'))
        .toList()
      ..sort((File a, File b) => a.path.compareTo(b.path));

/// Strips a paragraph's leading `N. ` numbering into its prompt text. The
/// numbering must come FIRST (a paragraph that merely CONTAINS `N. ` is a
/// different segment, e.g. the examen's closing Glory Be).
String _stripPromptNumbering(String paragraph) {
  final RegExpMatch? match = RegExp(r'^\d+\. ').firstMatch(paragraph);
  if (match == null) {
    throw ArgumentError.value(
      paragraph,
      'paragraph',
      'does not start with the companion prompt numbering',
    );
  }
  return paragraph.substring(match.group(0)!.length);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('companion import (tool/import_prayers.dart)', () {
    test('the committed prayers/ output equals the tool mapping', () {
      final importer.ImportOutcome outcome = mappedImport();
      final Map<String, String> committedText = committedImportText();

      expect(
        committedText.keys.toSet(),
        outcome.accepted.keys.toSet(),
        reason:
            'the committed prayers/ files must round-trip against the tool '
            'mapping — a stray committed file or an accepted-but-uncommitted '
            'prayer is drift',
      );
      committedText.forEach((String id, String text) {
        expect(
          text,
          importer.encodedPrayerJson(outcome.accepted[id]!),
          reason:
              '$id: the committed encoding must match the deterministic '
              'tool output (the tool is idempotent/re-runnable)',
        );
        final PrayerText parsed = committedImport()[id]!;
        expect(parsed.source, isNotEmpty, reason: 'PrayerText $id');
        expect(parsed.license, isNotEmpty, reason: 'PrayerText $id');
      });

      expect(
        outcome.rejected.keys.toSet(),
        _pinnedRejectedIds.toSet(),
        reason:
            'the rejected-prayer list is pinned: companion or tool changes '
            'that alter the split must consciously update the pin '
            '(_pinnedRejectedIds), the committed output, and the tool '
            'table together',
      );
      for (final String reason in outcome.rejected.values) {
        expect(reason, isNotEmpty);
      }
    });

    test('the real rootBundle serves every committed prayer', () async {
      final AssetManifest manifest = await AssetManifest.loadFromAssetBundle(
        rootBundle,
      );
      final List<String> declared =
          manifest.listAssets().where(_isPrayerAsset).toList()..sort();
      expect(
        declared,
        contains('assets/content/prayers/morning_offering.json'),
        reason: 'the pubspec must declare assets/content/prayers/',
      );
      expect(declared, hasLength(74), reason: '74 accepted companion prayers');
      for (final String key in declared) {
        final ByteData data = await rootBundle.load(key);
        final PrayerText prayer = PrayerText.fromJson(
          jsonDecode(utf8.decode(Uint8List.sublistView(data)))
              as Map<String, dynamic>,
        );
        expect(
          prayer.id,
          key.substring(key.lastIndexOf('/') + 1, key.length - 5),
        );
        expect(prayer.source, isNotEmpty);
        expect(prayer.license, isNotEmpty);
      }
    });
  });

  group('routine packs', () {
    ContentPack loadPack(String id) => PackLoader.loadFromJsonString(
      File('assets/content/packs/$id.json').readAsStringSync(),
    );

    test('every shipped pack loads through PackLoader', () {
      final List<File> files = shippedPackFiles();
      expect(files, hasLength(_shippedPackCount));
      for (final File file in files) {
        final ContentPack pack = PackLoader.loadFromJsonString(
          file.readAsStringSync(),
        );
        expect(
          pack.id,
          file.path.split(Platform.pathSeparator).last.replaceAll('.json', ''),
          reason: '${file.path}: filename == pack id stem',
        );
        for (final MapEntry<String, PrayerText> entry in pack.content.entries) {
          expect(
            entry.value.source,
            isNotEmpty,
            reason: '${file.path}/${entry.key}',
          );
          expect(
            entry.value.license,
            isNotEmpty,
            reason: '${file.path}/${entry.key}',
          );
        }
      }
    });

    test('every routine pack resolves fixture year 2026', () {
      for (final String id in _routinePackIds) {
        expect(
          PackValidator.problems(loadPack(id), 2026),
          isEmpty,
          reason: '$id: every schedule resolves at least one due date in 2026',
        );
      }
    });

    test('the six routine packs are routine family', () {
      for (final String id in _routinePackIds) {
        expect(loadPack(id).family, PackFamily.routine, reason: id);
      }
    });

    test('embedded prayers match the committed import verbatim', () {
      final Map<String, PrayerText> imported = committedImport();
      for (final String id in _routinePackIds) {
        final ContentPack pack = loadPack(id);
        for (final MapEntry<String, PrayerText> entry in pack.content.entries) {
          final PrayerText? source = imported[entry.key];
          if (source == null) {
            continue; // Authored content (examen prompts, lectio framework).
          }
          expect(
            entry.value,
            source,
            reason:
                '$id: content.${entry.key} must stay equal to the '
                'committed import (single-copy rule)',
          );
        }
      }
    });

    test(
      'morning_offering: offering prayer + papal-intention intercession',
      () {
        final ContentPack pack = loadPack('morning_offering');
        final List<SessionStep> steps = pack.session.steps;

        final TimeOfDaySpec anchor = pack.schedule as TimeOfDaySpec;
        expect(anchor.hour, 6);
        expect(anchor.minute, 0);
        expect(anchor.baseLabel, 'morning_offering');

        expect(steps, hasLength(2));
        final PrayerStep offering = steps.first as PrayerStep;
        expect(offering.text.id, 'morning_offering');
        expect(
          offering.text.text,
          contains('for the intentions of the Holy Father this month'),
        );

        final IntercessionStep intention = steps.last as IntercessionStep;
        final Map<String, dynamic> papal =
            pack.reminders['papal_intention']! as Map<String, dynamic>;
        expect(papal['cadence'], 'monthly');
        expect(papal['note'], isNotEmpty);
        // The shipped, MANUALLY-updated content field: the intercession
        // prompt IS the pack's papal-intention line (spec risk #6 — a
        // content field, never a network fetch).
        expect(papal['current'], isNotEmpty);
        expect(intention.prompt, papal['current']);
      },
    );

    test('daily_examen: five Ignatian reflection prompts, evening anchor', () {
      final ContentPack pack = loadPack('daily_examen');
      final List<SessionStep> steps = pack.session.steps;

      final TimeOfDaySpec anchor = pack.schedule as TimeOfDaySpec;
      expect(anchor.hour, 19);
      expect(anchor.baseLabel, 'daily_examen');

      final List<ReflectionStep> reflections = steps
          .whereType<ReflectionStep>()
          .toList();
      expect(reflections, hasLength(5));

      // The prompts are the numbered paragraphs of the committed companion
      // text (the examen's closing Glory Be is an unnumbered paragraph).
      final PrayerText examenImport = committedImport()['daily_examen']!;
      final List<String> prompts = <String>[
        for (final String paragraph in examenImport.text.split('\n\n'))
          if (RegExp(r'^[1-5]\. ').firstMatch(paragraph) != null)
            _stripPromptNumbering(paragraph),
      ];
      expect(prompts, hasLength(5));
      for (int i = 0; i < prompts.length; i++) {
        expect(
          reflections[i].text!.text,
          prompts[i],
          reason: 'reflection ${i + 1} carries the companion prompt verbatim',
        );
        expect(reflections[i].text!.source, examenImport.source);
        expect(reflections[i].text!.license, examenImport.license);
      }
      expect(steps.whereType<ReflectionStep>().length, 5);
      final PrayerStep closing = steps.last as PrayerStep;
      expect(closing.text.id, 'glory_be');
    });

    test('lectio_divina: readings skeleton + the bible riverpod note', () {
      final ContentPack pack = loadPack('lectio_divina');
      final TimeOfDaySpec anchor = pack.schedule as TimeOfDaySpec;
      expect(anchor.baseLabel, 'lectio_divina');

      final List<SessionStep> steps = pack.session.steps;
      final VerseStep placeholder = steps.first as VerseStep;
      expect(placeholder.versicle, "Today's readings");
      // The verse step is USER-facing (step_views renders it as V./R.): the
      // response must read as prayer guidance, never as authoring copy — no
      // present-tense app-capability claims and no pointer at the pack's
      // authoring note.
      expect(
        placeholder.response,
        'Read today\'s readings from your Bible, slowly and attentively.',
      );

      expect(steps.whereType<ReflectionStep>().length, 4);
      final PrayerStep closing = steps.last as PrayerStep;
      expect(closing.text.id, 'lectio_closing_prayer');

      // The 'readings' reminders note documents the app-side feed (the pack
      // stores the skeleton; no dynamic readings are embedded).
      final Map<String, dynamic> readings =
          pack.reminders['readings']! as Map<String, dynamic>;
      final String note = readings['note']! as String;
      expect(note, contains('bible riverpod'));
      expect(note, contains('sancta_via_bible_data_riverpod'));
      expect(note, contains('readingsFor(date)'));
      expect(readings['feed'], contains('app-side'));
    });

    test('meal_night_prayers: grace window + night set anchors', () {
      final ContentPack pack = loadPack('meal_night_prayers');
      expect(pack.schedules, hasLength(2));
      final TimeOfDaySpec grace = pack.schedules[0] as TimeOfDaySpec;
      final TimeOfDaySpec night = pack.schedules[1] as TimeOfDaySpec;
      expect(
        (grace.hour, grace.minute, grace.baseLabel),
        (11, 45, 'meal_grace'),
      );
      expect(
        (night.hour, night.minute, night.baseLabel),
        (20, 30, 'night_prayers'),
      );

      expect(
        pack.session.steps.map(
          (SessionStep step) => switch (step) {
            PrayerStep() => step.text.id,
            _ => '<non-prayer>',
          },
        ),
        <String>[
          'grace_before_meals',
          'grace_after_meals',
          'prayer_before_sleep',
          'children_bedtime_prayer',
        ],
      );
      expect(pack.reminders['anchors'], isNotEmpty);
    });

    test(
      'fixed_prayers_morning: the morning fixed set at its 07:00 anchor',
      () {
        final ContentPack pack = loadPack('fixed_prayers_morning');
        final TimeOfDaySpec anchor = pack.schedule as TimeOfDaySpec;
        expect(anchor.hour, 7);
        expect(anchor.baseLabel, 'fixed_morning');
        expect(pack.session.steps.length, 8);
        expect(
          pack.content.keys,
          containsAll(<String>[
            'sign_of_the_cross',
            'apostles_creed',
            'our_father',
            'hail_mary',
            'glory_be',
            'guardian_angel_prayer',
            'morning_thanksgiving',
          ]),
        );
      },
    );

    test('fixed_prayers_night: the night fixed set at its 21:00 anchor', () {
      final ContentPack pack = loadPack('fixed_prayers_night');
      final TimeOfDaySpec anchor = pack.schedule as TimeOfDaySpec;
      expect(anchor.hour, 21);
      expect(anchor.baseLabel, 'fixed_night');
      expect(pack.session.steps.length, 4);
      expect(
        pack.content.keys,
        containsAll(<String>[
          'evening_protection',
          'evening_thanksgiving',
          'bedtime_examination',
          'act_of_contrition',
        ]),
      );
    });
  });
}

bool _isPrayerAsset(String key) =>
    key.startsWith('assets/content/prayers/') && key.endsWith('.json');
