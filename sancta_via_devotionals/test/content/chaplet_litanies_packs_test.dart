// Chaplet and litany content (Plan 2, Task 23): the five chaplet-family packs
// and five litany packs authored in this app's assets.
//
// Two layers are pinned here so neither can drift silently:
//
// 1. Shape and loading (the PackLoader's full validation pass): all ten packs
//    load, the chaplets carry the `chaplet` family and the litanies `routine`,
//    every content entry holds a non-empty `source` and `license` in the
//    house vocabulary (public-domain… | original…), and content whose id
//    matches the committed companion import (`assets/content/prayers/`) stays
//    EQUAL to that import — the routine/novena packs' single-copy rule
//    extended to these packs.
// 2. The traditions: the sessions are static (no day variants, no
//    placeholders), every pack is due EVERY day through its time-of-day
//    anchor (whose hour avoids the app's shared 6/12/15/18 Angelus-Mercy
//    anchor hours), and the litany steps carry the pinned invocation counts —
//    Loreto 48 (the received pre-1950 list derived line-for-line from the
//    committed import, dropping exactly the three post-1930 additions), the
//    Sacred Heart 33 (derived from its import), St. Joseph 26 (the received
//    1909 approved list; the 2021 additions are pinned absent, matching the
//    Task-21 import tool's rejection of the modern expansion), Precious Blood
//    24 (the 1960 official redaction), and Humility 16 + 7. The Franciscan
//    Crown's Lent documentation variant (`variantKey: lent`) is pinned
//    present, and each chaplet's group inventory matches its tradition.
//
// The litany step strings carry no per-line license slot (the engine's
// LitanyStep is a plain invocation list), so each pack's
// `reminders.schedule_note` carries the litany text's source and license and
// that documentation is pinned here — the license discipline at pack level,
// exactly as the novena packs documented their scheduled windows.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sancta_via_devotional_engine/sancta_via_devotional_engine.dart';
import 'package:sancta_via_devotionals/services/substitution_service.dart';

/// The five chaplet packs this task ships (filename == pack id stem).
const List<String> _chapletPackIds = <String>[
  'franciscan_crown',
  'holy_wounds',
  'seven_sorrows',
  'st_anne_chaplet',
  'st_michael_chaplet',
];

/// The five litany packs this task ships (filename == pack id stem).
const List<String> _litanyPackIds = <String>[
  'litany_humility',
  'litany_loreto',
  'litany_precious_blood',
  'litany_sacred_heart',
  'litany_st_joseph',
];

/// All ten packs of this task, in filename order.
const List<String> _taskPackIds = <String>[
  'franciscan_crown',
  'holy_wounds',
  'litany_humility',
  'litany_loreto',
  'litany_precious_blood',
  'litany_sacred_heart',
  'litany_st_joseph',
  'seven_sorrows',
  'st_anne_chaplet',
  'st_michael_chaplet',
];

/// The committed import prayers embedded in these packs (their ids must stay
/// equal to `assets/content/prayers/`: the single-copy rule).
const List<String> _embeddedImportIds = <String>[
  'act_of_contrition',
  'apostles_creed',
  'glory_be',
  'hail_mary',
  'litany_loreto',
  'litany_sacred_heart',
  'our_father',
];

/// The shared wall-clock hours whose anchor times the app maps to the USER's
/// configured settings (`_anchorFor`): the Angelus at 6/12/18 and the Hour of
/// Mercy at 15. These packs' anchors avoid them, so every anchor keeps its
/// own authored wall-clock time.
const Set<int> _sharedAnchorHours = <int>{6, 12, 15, 18};

/// The pinned per-pack time-of-day anchors: hour, minute, base label — the
/// daily availability each tradition ships with (documented in schedule_note).
const Map<String, (int, int, String)> _anchorPins =
    <String, (int, int, String)>{
      'franciscan_crown': (7, 30, 'franciscan_crown'),
      'holy_wounds': (13, 0, 'holy_wounds'),
      'litany_humility': (7, 15, 'litany_humility'),
      'litany_loreto': (17, 0, 'litany_loreto'),
      'litany_precious_blood': (16, 30, 'litany_precious_blood'),
      'litany_sacred_heart': (14, 30, 'litany_sacred_heart'),
      'litany_st_joseph': (7, 0, 'litany_st_joseph'),
      'seven_sorrows': (8, 0, 'seven_sorrows'),
      'st_anne_chaplet': (9, 0, 'st_anne'),
      'st_michael_chaplet': (19, 0, 'st_michael'),
    };

/// The litany invocation counts pinned per pack (the engine's LitanyStep
/// inventory, in step order: [trinity-lead, title block]).
const Map<String, List<int>> _litanyInvocationCountPins = <String, List<int>>{
  'litany_humility': <int>[16, 7],
  'litany_loreto': <int>[4, 48],
  'litany_precious_blood': <int>[4, 24],
  'litany_sacred_heart': <int>[4, 33],
  'litany_st_joseph': <int>[4, 26],
};

/// The pin's post-1930 Loreto additions: present in the committed import's
/// received list, dropped from the pack's public-domain pre-1950 redaction.
const List<String> _droppedLoretoLines = <String>[
  'Mother of the Church, pray for us.',
  'Queen assumed into Heaven, pray for us.',
  'Queen of families, pray for us.',
];

/// The 2021 additions to the Litany of Saint Joseph (Francis, May 1, 2021):
/// pinned ABSENT — the pack ships the received 1909 approved list, matching
/// the Task-21 import tool's rejection of the modern expansion.
const List<String> _joseph2021Additions = <String>[
  'Guardian of the Redeemer,',
  'Minister of salvation,',
  'Patron of the afflicted,',
  'Patron of the poor,',
  'Patron of the exiles,',
  'Servant of Christ,',
  'Support in difficulties,',
];

/// The seven joys of the Franciscan Crown, in the Crown's order.
const List<String> _crownJoys = <String>[
  'Joy 1: The Annunciation',
  'Joy 2: The Visitation',
  'Joy 3: The Nativity of Jesus',
  'Joy 4: The Adoration of the Magi',
  'Joy 5: The Finding of the Child Jesus in the Temple',
  'Joy 6: The Resurrection of Our Lord',
  'Joy 7: The Assumption and Coronation of the Blessed Virgin',
];

/// The nine choirs of the St. Michael salutations, in the tradition's
/// descending order (each group's BeadGroupStep mystery).
const List<String> _michaelChoirs = <String>[
  'In honor of the Choir of Seraphim',
  'In honor of the Choir of Cherubim',
  'In honor of the Choir of Thrones',
  'In honor of the Choir of Dominions',
  'In honor of the Choir of Virtues',
  'In honor of the Choir of Powers',
  'In honor of the Choir of Principalities',
  'In honor of the Choir of Archangels',
  'In honor of the Choir of Angels',
];

/// The seven sorrows of the Servite rosary, in the tradition's order.
const List<String> _sevenSorrows = <String>[
  'Sorrow 1: The prophecy of Simeon',
  'Sorrow 2: The flight into Egypt',
  'Sorrow 3: The loss of the Child Jesus in the Temple',
  'Sorrow 4: The meeting of Jesus and Mary on the way of the Cross',
  'Sorrow 5: The Crucifixion and death of Jesus',
  'Sorrow 6: The piercing of the side of Jesus, and His taking down from '
      'the Cross',
  'Sorrow 7: The burial of Jesus',
];

/// The five wounds of the Holy Wounds rosary (feet, hands, then the side).
const List<String> _holyWounds = <String>[
  'The Sacred Wound of the Left Foot',
  'The Sacred Wound of the Right Foot',
  'The Sacred Wound of the Left Hand',
  'The Sacred Wound of the Right Hand',
  'The Sacred Wound of the Side and Heart',
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
  IntercessionStep(:final String? title, :final String prompt) => <String>[
    ?title,
    prompt,
  ],
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
  // These packs carry no reflection or checkpoint steps.
  _ => <String>[],
};

/// A pack's session step strings flattened (the leakage/staleness sweep's
/// corpus).
List<String> sessionStrings(ContentPack pack) => <String>[
  for (final SessionStep step in pack.session.steps) ...stepTexts(step),
];

/// All litany steps of [pack], in session order.
List<LitanyStep> litanySteps(ContentPack pack) => <LitanyStep>[
  for (final SessionStep step in pack.session.steps)
    if (step is LitanyStep) step,
];

/// All bead groups of [pack], in session order.
List<BeadGroupStep> beadGroups(ContentPack pack) => <BeadGroupStep>[
  for (final SessionStep step in pack.session.steps)
    if (step is BeadGroupStep) step,
];

/// All repetition steps of [pack], in session order.
List<RepetitionStep> repetitionSteps(ContentPack pack) => <RepetitionStep>[
  for (final SessionStep step in pack.session.steps)
    if (step is RepetitionStep) step,
];

/// The committed companion import, keyed by prayer id (file stem).
Map<String, PrayerText> committedImport() => <String, PrayerText>{
  for (final String name
      in Directory('assets/content/prayers')
          .listSync()
          .whereType<File>()
          .map((File file) => file.path.split(Platform.pathSeparator).last)
          .where((String name) => name.endsWith('.json')))
    name.substring(0, name.length - 5): PrayerText.fromJson(
      jsonDecode(File('assets/content/prayers/$name').readAsStringSync())
          as Map<String, dynamic>,
    ),
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  ContentPack loadPack(String id) => PackLoader.loadFromJsonString(
    File('assets/content/packs/$id.json').readAsStringSync(),
  );

  group('chaplet and litany packs', () {
    test('all ten load through PackLoader; family; licensed content', () {
      for (final String id in _taskPackIds) {
        final ContentPack pack = loadPack(id);
        expect(pack.id, id, reason: '$id: filename == pack id stem');
        expect(
          pack.family,
          _litanyPackIds.contains(id) ? PackFamily.routine : PackFamily.chaplet,
          reason: id,
        );
        for (final MapEntry<String, PrayerText> entry in pack.content.entries) {
          expect(entry.value.source, isNotEmpty, reason: '$id/${entry.key}');
          expect(entry.value.license, isNotEmpty, reason: '$id/${entry.key}');
        }
      }
    });

    test('every pack resolves at least one due date in 2026 AND 2027', () {
      for (final String id in _taskPackIds) {
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
      for (final String id in _taskPackIds) {
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
                'rule keeps Diary-of-Faustina text out of these packs',
          );
        }
      }
    });

    test('embedded companion prayers match the committed import verbatim', () {
      final Map<String, PrayerText> imported = committedImport();
      for (final String id in _taskPackIds) {
        final ContentPack pack = loadPack(id);
        for (final MapEntry<String, PrayerText> entry in pack.content.entries) {
          final PrayerText? source = imported[entry.key];
          if (source == null) {
            continue; // Authored content (salutations, collects, invocations).
          }
          expect(
            entry.value,
            source,
            reason:
                '$id: content.${entry.key} must stay equal to the committed '
                'import (the single-copy rule, extended to these packs)',
          );
        }
      }
      // And the pins' import list is exactly what these packs embed — an id
      // that stops being embedded drops from the list consciously.
      final Set<String> embedded = <String>{
        for (final String id in _taskPackIds)
          for (final MapEntry<String, PrayerText> entry in loadPack(
            id,
          ).content.entries)
            if (imported.containsKey(entry.key)) entry.key,
      };
      expect(embedded, _embeddedImportIds.toSet());
    });

    test('every session is static: no day variants, no placeholders', () {
      for (final String id in _taskPackIds) {
        final ContentPack pack = loadPack(id);
        expect(
          pack.variants.where(
            (Map<String, dynamic> variant) => variant['dayIndex'] is int,
          ),
          isEmpty,
          reason: '$id: a static session ships no day-index variants',
        );
        for (final String text in sessionStrings(pack)) {
          expect(
            text.contains('{{'),
            false,
            reason:
                '$id: a session with no day tokens must never carry a '
                'placeholder (the substitution gate would throw on a due day)',
          );
        }
        // The substitution pass runs clean on the empty token bag.
        for (final SessionStep step in pack.session.steps) {
          for (final String text in stepTexts(step)) {
            expect(
              () => SubstitutionService.requireFullySubstituted(
                SubstitutionService.substitute(
                  text,
                  tokens: const <String, String>{},
                ),
              ),
              returnsNormally,
              reason: '$id, step ${step.id}: the static token pass',
            );
          }
        }
      }
    });

    test('every pack anchors daily at its pinned time-of-day', () {
      for (final String id in _taskPackIds) {
        final ContentPack pack = loadPack(id);
        expect(pack.schedules, hasLength(1), reason: id);
        final TimeOfDaySpec spec = pack.schedule as TimeOfDaySpec;
        final (int, int, String) pin = _anchorPins[id]!;
        expect(spec.hour, pin.$1, reason: '$id: the pinned anchor hour');
        expect(spec.minute, pin.$2, reason: '$id: the pinned anchor minute');
        expect(spec.baseLabel, pin.$3, reason: '$id: the anchor label');
        expect(
          _sharedAnchorHours.contains(spec.hour),
          false,
          reason:
              '$id: the anchor hour must keep its own wall-clock time '
              '(the app maps 6/12/15/18 to the user\u2019s shared anchor '
              'settings)',
        );
        // Due EVERY day: the ten packs sweep both proof years fully.
        const ScheduleContext context = ScheduleContext();
        for (final int year in <int>[2026, 2027]) {
          for (int month = 1; month <= 12; month++) {
            final int lastDay = DateTime(year, month + 1, 0).day;
            for (int day = 1; day <= lastDay; day++) {
              expect(
                spec.resolve(DateTime(year, month, day), context).due,
                true,
                reason: '$id: $year-$month-$day must be due',
              );
            }
          }
        }
      }
    });

    test('every pack documents its tradition (schedule_note)', () {
      for (final String id in _taskPackIds) {
        final Map<String, dynamic> scheduleNote =
            loadPack(id).reminders['schedule_note']! as Map<String, dynamic>;
        expect(
          (scheduleNote['note']! as String).isNotEmpty,
          true,
          reason: '$id: the schedule note',
        );
        for (final String key in <String>[
          'invocation_source',
          'invocation_license',
        ]) {
          final Object? value = scheduleNote[key];
          expect(
            value is String && value.isNotEmpty,
            true,
            reason: '$id: schedule_note.$key',
          );
          expect(
            scheduleNote['invocation_license']!.startsWith('public-domain') ||
                scheduleNote['invocation_license']!.startsWith('original'),
            true,
            reason: '$id: the note\u2019s license vocabulary',
          );
        }
      }
    });

    test('the litanies carry the pinned invocation counts and responses', () {
      for (final MapEntry<String, List<int>> pin
          in _litanyInvocationCountPins.entries) {
        final List<LitanyStep> steps = litanySteps(loadPack(pin.key));
        expect(
          steps,
          hasLength(2),
          reason: '${pin.key}: the Godhead lead and the title block',
        );
        final List<int> counts = <int>[
          for (final LitanyStep step in steps) step.invocations.length,
        ];
        expect(counts, pin.value, reason: '${pin.key}: invocation counts');
        for (final LitanyStep step in steps) {
          expect(step.response, isNotEmpty, reason: '${pin.key}/${step.id}');
        }
      }
    });

    test(
      'loreto: 48 invocations, the import\u2019s list minus 3 additions',
      () {
        final ContentPack pack = loadPack('litany_loreto');
        final Map<String, PrayerText> imported = committedImport();
        final List<String> importLines = imported['litany_loreto']!.text.split(
          '\n',
        );
        final int firstInvocation = importLines.indexOf(
          'Holy Mary, pray for us.',
        );
        final int agnus = importLines.indexWhere(
          (String line) => line.startsWith('Lamb of God,'),
        );
        final List<String> received = importLines.sublist(
          firstInvocation,
          agnus,
        );
        expect(received, hasLength(51), reason: 'the committed import block');
        // The pack's list is the received list minus exactly the three
        // post-1930 additions, each invocation line stripped to its invocation.
        final List<String> expected = <String>[
          for (final String line in received)
            if (!_droppedLoretoLines.contains(line))
              line.substring(0, line.length - ' pray for us.'.length),
        ];
        final LitanyStep step = litanySteps(pack).last;
        expect(step.invocations, expected, reason: 'the pinned 48');
        expect(step.response, 'pray for us.');
        expect(
          step.groupedResponse,
          true,
          reason: 'the grouped Loreto passage',
        );
        expect(
          step.invocations.first,
          'Holy Mary,',
          reason: 'the first Marian invocation',
        );
        expect(step.invocations.last, 'Queen of peace,');
        // Later 2020 additions are also out (not in the import block at all).
        for (final String addition in <String>[
          'Mother of Mercy,',
          'Mother of Hope,',
          'Solace of Migrants,',
        ]) {
          expect(
            step.invocations.contains(addition),
            false,
            reason: 'the 2020 addition "$addition" is absent',
          );
        }
        // And the dropped lines are precisely the pinned three.
        expect(<String>[
          for (final String line in received)
            if (_droppedLoretoLines.contains(line)) line,
        ], _droppedLoretoLines);
      },
    );

    test('sacred heart: 33 invocations derived from the committed import', () {
      final ContentPack pack = loadPack('litany_sacred_heart');
      final List<String> importLines = committedImport()['litany_sacred_heart']!
          .text
          .split('\n');
      final int first = importLines.indexOf(
        'Heart of Jesus, Son of the Eternal Father, have mercy on us.',
      );
      final int last = importLines.indexOf(
        'Lamb of God, Who takes away the '
        'sins of the world, spare us, O Lord.',
      );
      final List<String> expected = <String>[
        for (final String line in importLines.sublist(first, last))
          line.substring(0, line.length - ' have mercy on us.'.length),
      ];
      final LitanyStep step = litanySteps(pack).last;
      expect(step.invocations, expected, reason: 'the 33, line for line');
      expect(step.response, 'have mercy on us.');
      expect(step.groupedResponse, true, reason: 'the grouped passage');
      expect(
        step.invocations.last,
        'Heart of Jesus, delight of all the Saints,',
      );
      expect(
        (litanySteps(pack).first).invocations,
        hasLength(4),
        reason: 'the four Trinitarian lead-ins',
      );
    });

    test('st_joseph: the received 1909 list; the 2021 additions stay out', () {
      final ContentPack pack = loadPack('litany_st_joseph');
      final LitanyStep step = litanySteps(pack).last;
      expect(step.invocations, hasLength(26));
      expect(step.response, 'pray for us.');
      expect(step.groupedResponse, true);
      expect(step.invocations.first, 'Holy Mary,');
      expect(step.invocations[1], 'Saint Joseph,');
      expect(
        step.invocations.last,
        'Protector of Holy Church,',
        reason: 'the received list\u2019s last invocation',
      );
      for (final String addition in _joseph2021Additions) {
        expect(
          step.invocations.contains(addition),
          false,
          reason:
              'the 2021 addition "$addition" is absent — the pack ships '
              'the received 1909 form (the import tool\u2019s ruling)',
        );
      }
    });

    test('precious blood: the official 24-invocation 1960 redaction', () {
      final ContentPack pack = loadPack('litany_precious_blood');
      final LitanyStep block = litanySteps(pack).last;
      expect(block.invocations, hasLength(24));
      expect(block.response, 'save us.');
      expect(block.groupedResponse, true);
      expect(
        block.invocations.first,
        'Blood of Christ, only-begotten Son of the Eternal Father,',
      );
      expect(
        block.invocations.last,
        'Blood of Christ, most worthy of all glory and honor,',
      );
      // The Apocalypse versicle closes the litany block.
      expect(
        sessionStrings(
          pack,
        ).contains('Thou hast redeemed us, O Lord, in Thy Blood,'),
        true,
      );
    });

    test('humility: 16 deliverances and 7 petitions with their responses', () {
      final ContentPack pack = loadPack('litany_humility');
      final List<LitanyStep> steps = litanySteps(pack);
      expect(steps, hasLength(2));
      final LitanyStep deliverances = steps.first;
      final LitanyStep petitions = steps.last;
      expect(deliverances.invocations, hasLength(16));
      expect(deliverances.response, 'Deliver me, Jesus.');
      expect(deliverances.groupedResponse, false, reason: 'call and response');
      expect(
        deliverances.invocations.first,
        'From the desire of being esteemed,',
      );
      expect(
        deliverances.invocations.last,
        'From the fear of being suspected,',
      );
      expect(petitions.invocations, hasLength(7));
      expect(petitions.response, 'Jesus, grant me the grace to desire it.');
      expect(petitions.groupedResponse, false, reason: 'call and response');
      expect(
        petitions.invocations.last,
        'That others may become holier than I, provided that I may become as '
        'holy as I should,',
      );
    });

    test('crown: seven joys, two concluding Hail Marys, the Lent variant', () {
      final ContentPack pack = loadPack('franciscan_crown');
      final List<BeadGroupStep> groups = beadGroups(pack);
      expect(groups, hasLength(7), reason: 'seven decades');
      expect(
        <String>[for (final BeadGroupStep group in groups) group.mysteryTitle!],
        _crownJoys,
        reason: 'one joy per decade, in the Crown\u2019s order',
      );
      for (final BeadGroupStep group in groups) {
        expect(group.hailMaryCount, 7, reason: group.id);
        expect(group.includeFatimaPrayer, false, reason: group.id);
      }
      // The two additional Hail Marys closing the crown (the 72 years).
      final List<RepetitionStep> repetitions = repetitionSteps(pack);
      expect(
        repetitions.any(
          (RepetitionStep step) =>
              step.count == 2 && step.text.id == 'hail_mary',
        ),
        true,
        reason: 'the two concluding Hail Marys',
      );
      // THE Lent substitution variant key is present.
      final List<Map<String, dynamic>> lentVariants = pack.variants
          .where(
            (Map<String, dynamic> variant) => variant['variantKey'] == 'lent',
          )
          .toList();
      expect(lentVariants, hasLength(1), reason: 'the Lent variant key');
      expect(
        (lentVariants.first['note']! as String).contains('Seven Sorrows'),
        true,
        reason: 'the variant documents the sorrows substitution',
      );
    });

    test('st_michael: nine salutations of (1 Our Father + 3 Hail Marys)', () {
      final ContentPack pack = loadPack('st_michael_chaplet');
      final List<BeadGroupStep> groups = beadGroups(pack);
      expect(groups, hasLength(9), reason: 'nine salutations');
      expect(
        <String>[for (final BeadGroupStep group in groups) group.mysteryTitle!],
        _michaelChoirs,
        reason: 'one choir per salutation, in descending order',
      );
      for (final BeadGroupStep group in groups) {
        expect(group.hailMaryCount, 3, reason: group.id);
        expect(group.includeFatimaPrayer, false, reason: group.id);
        expect(group.mysteryFruit, isNotNull, reason: group.id);
      }
      // The four concluding Our Fathers, in honor of the angelic names.
      final List<String> fatherTitles = <String>[
        for (final SessionStep step in pack.session.steps)
          if (step is PrayerStep && step.text.id == 'our_father') ?step.title,
      ];
      expect(fatherTitles, hasLength(13), reason: '9 salutation + 4 honor');
      expect(fatherTitles.sublist(9), <String>[
        'Our Father \u2014 in honor of Saint Michael',
        'Our Father \u2014 in honor of the Guardian Angels',
        'Our Father \u2014 in honor of Saint Gabriel',
        'Our Father \u2014 in honor of Saint Raphael',
      ]);
    });

    test('seven_sorrows: 7 groups of (1 Our Father + 7 Hail Marys)', () {
      final ContentPack pack = loadPack('seven_sorrows');
      final List<BeadGroupStep> groups = beadGroups(pack);
      expect(groups, hasLength(7));
      expect(<String>[
        for (final BeadGroupStep group in groups) group.mysteryTitle!,
      ], _sevenSorrows);
      for (final BeadGroupStep group in groups) {
        expect(group.hailMaryCount, 7, reason: group.id);
        expect(group.includeFatimaPrayer, false, reason: group.id);
      }
      // The Act of Contrition opens the Servite form.
      expect(
        sessionStrings(
          pack,
        ).any((String text) => text.contains('O my God, I am heartily sorry')),
        true,
      );
    });

    test('holy_wounds: 5 groups of (the Offering + 10 aspirations)', () {
      final ContentPack pack = loadPack('holy_wounds');
      final List<RepetitionStep> repetitions = repetitionSteps(pack);
      expect(repetitions, hasLength(6), reason: '5 groups + the 3x closing');
      final List<int> counts = <int>[
        for (final RepetitionStep step in repetitions) step.count,
      ];
      expect(counts, <int>[10, 10, 10, 10, 10, 3]);
      expect(repetitions.first.text.id, 'hw_mercy');
      expect(
        repetitions.first.text.text,
        'My Jesus, pardon and mercy, by the merits of Thy holy Wounds.',
      );
      // The five groups meditate the five wounds, in the nailing order
      // (feet, hands, then the side) followed by the Lance.
      final List<String> woundTitles = <String>[
        for (final SessionStep step in pack.session.steps)
          if (step is PrayerStep && step.text.id == 'hw_offering') ?step.title,
      ];
      expect(woundTitles, hasLength(5), reason: 'one Offering per wound');
      for (int i = 0; i < _holyWounds.length; i++) {
        expect(
          woundTitles[i].startsWith(_holyWounds[i]),
          true,
          reason: '${_holyWounds[i]}: wound $i, in the tradition\u2019s order',
        );
      }
      expect(
        repetitions.last.text.id,
        'hw_offering',
        reason: 'the Offering closes the rosary, repeated three times',
      );
      expect(
        sessionStrings(pack).contains(
          'Eternal Father, I offer Thee the Wounds of Our Lord Jesus Christ, '
          'to heal those of our souls.',
        ),
        true,
      );
    });

    test('st_anne: 3 parts of (1 Our Father + 5 Hail Marys + 1 Glory Be)', () {
      final ContentPack pack = loadPack('st_anne_chaplet');
      final List<BeadGroupStep> groups = beadGroups(pack);
      expect(groups, hasLength(3));
      for (final BeadGroupStep group in groups) {
        expect(group.hailMaryCount, 5, reason: group.id);
        expect(group.includeFatimaPrayer, false, reason: group.id);
        expect(
          group.title!.contains(
            'Jesus, Mary, and Saint Anne, grant the favor '
            'I ask.',
          ),
          true,
          reason: '$group.id: the after-each-Hail-Mary invocation',
        );
      }
      expect(
        <String>[for (final BeadGroupStep group in groups) group.mysteryTitle!],
        <String>[
          'In honor of Jesus, the Author of Grace',
          'In honor of Mary, the channel of all grace',
          'In honor of Saint Anne, our advocate',
        ],
      );
      expect(
        sessionStrings(pack).where((String text) => text == 'Glory Be'),
        hasLength(3),
        reason: 'one Glory Be closes each part',
      );
    });

    test('the litany steps carry pure titles: no counts, no notes', () {
      const Map<String, List<String>> titlePins = <String, List<String>>{
        'litany_loreto': <String>['The Godhead', 'The Invocation List'],
        'litany_st_joseph': <String>['The Godhead', 'Saint Joseph'],
        'litany_humility': <String>['Deliverances', 'Petitions'],
        'litany_sacred_heart': <String>['The Godhead', 'The Heart of Jesus'],
        'litany_precious_blood': <String>['The Godhead', 'The Blood of Christ'],
      };
      titlePins.forEach((String id, List<String> pins) {
        final ContentPack pack = loadPack(id);
        expect(
          <String>[
            for (final LitanyStep step in litanySteps(pack)) ?step.title,
          ],
          pins,
          reason: '$id: the pinned litany step titles',
        );
        for (final LitanyStep step in litanySteps(pack)) {
          final String? title = step.title;
          expect(
            title == null ||
                (title.contains('(') == false &&
                    title.contains(RegExp(r'\d')) == false),
            true,
            reason:
                '$id/${step.id}: a litany step title carries no editorial '
                'parenthetical or count ("$title")',
          );
        }
      });
    });

    test('no chaplet bead group flags the rosary Fatima slot', () {
      for (final String id in _chapletPackIds) {
        for (final BeadGroupStep group in beadGroups(loadPack(id))) {
          expect(
            group.includeFatimaPrayer,
            false,
            reason:
                '$id/${group.id}: an angel-or-sorrow chaplet has no decade '
                'Fatima prayer (the flag would render the rosary\u2019s '
                'prayer-text slot)',
          );
        }
      }
    });
  });
}
