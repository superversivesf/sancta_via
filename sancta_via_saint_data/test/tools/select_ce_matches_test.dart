// Unit tests for `tools/select_ce_matches.dart` (Task 1 of the
// saint-histories plan) — fixture-driven, NO network.
//
// Fixtures: a mini CE letter-index HTML (same entry shape as the real
// `cathen/<letter>-ce.htm` pages) and a 6-saint seed subset. The tests pin:
//   * honorific stripping and trailing-honorific stripping,
//   * surname-reorder variants (`Loyola, Ignatius`),
//   * collision quarantine (two slugs resolving to one article -> BOTH
//     quarantined, never auto-shared),
//   * 1:1 acceptance and pinned selection.json row shape,
//   * ranking (featured first, then patronageCount desc, then name),
//   * drop reasons recorded, including the Review Focus trap:
//     `St. Adalbert of Egmond` must NEVER resolve to CE's
//     `Adalbert, Saint` article.
// Fix round 1 adds regression groups pinning the review's named cases:
// multi-part comma titles (I1), the 9 wrong-person matches (C1/C2), the
// recovered I1 exacts, and the surviving spelling-variant fuzzy accepts.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tools/select_ce_matches.dart';

final String _html = File(
  'test/fixtures/ce_index_sample.html',
).readAsStringSync();

List<Map<String, dynamic>> loadFixtureSeeds() {
  final Map<String, dynamic> decoded =
      jsonDecode(File('test/fixtures/seed_sample.json').readAsStringSync())
          as Map<String, dynamic>;
  return (decoded['saints'] as List<dynamic>).cast<Map<String, dynamic>>();
}

void main() {
  group('parseCeIndex', () {
    test('parses exactly the entry lines, ignoring nav and prose links', () {
      final List<CeEntry> entries = parseCeIndex(_html);
      // 6 index entries; the nav links (`a.htm`, `b.htm`), the prose
      // `Church` link, and the donation banner must be excluded.
      expect(entries.map((CeEntry e) => e.code).toSet(), hasLength(6));
      expect(
        entries.map((CeEntry e) => e.code).toSet(),
        containsAll(<String>['06255a', '07487a', '01026a', '12615a']),
      );
      expect(entries.any((CeEntry e) => e.code == '03744a'), isFalse);
    });

    test('decodes HTML entities in titles and notes', () {
      final List<CeEntry> entries = parseCeIndex(_html);
      final CeEntry bobl = entries.singleWhere(
        (CeEntry e) => e.code == '01026b',
      );
      expect(bobl.title, 'Böbl');
      expect(bobl.note, 'Bishop of Böblingen, fifth—sixth century');
      final CeEntry francis = entries.singleWhere(
        (CeEntry e) => e.code == '06255a',
      );
      expect(francis.note, 'Founder of the Franciscan Order (1181—1226)');
    });

    test('unwraps inline tags inside the anchor (<strong>)', () {
      final List<CeEntry> entries = parseCeIndex(_html);
      final CeEntry adalbert = entries.singleWhere(
        (CeEntry e) => e.code == '01026a',
      );
      expect(adalbert.title, 'Adalbert, Saint');
    });
  });

  group('nameVariants', () {
    test('strips leading honorifics', () {
      expect(
        nameVariants('St. Francis of Assisi'),
        contains('francis of assisi'),
      );
    });

    test('strips trailing-honorific CE form', () {
      expect(
        nameVariants('Francis of Assisi, Saint'),
        contains('francis of assisi'),
      );
    });

    test('emits surname-reorder variants for comma titles', () {
      final Set<String> variants = nameVariants('Loyola, Ignatius');
      expect(variants, contains('loyola ignatius'));
      expect(variants, contains('ignatius loyola'));
    });

    test('folds diacritics so entity-decoded titles match seed names', () {
      expect(nameVariants('St. Böbl'), contains('bobl'));
      final CeEntry bobl = parseCeIndex(
        _html,
      ).singleWhere((CeEntry e) => e.code == '01026b');
      expect(nameVariants(bobl.title), contains('bobl'));
    });
  });

  group('similarity', () {
    test('is 1.0 for identical strings', () {
      expect(similarity('joseph of arimathea', 'joseph of arimathea'), 1.0);
    });

    test('scores the Adalbert trap low so it can never auto-match', () {
      expect(similarity('adalbert of egmond', 'adalbert') < 0.5, isTrue);
    });
  });

  group('buildSelection (fixture)', () {
    late Selection selection;

    setUp(() {
      selection = buildSelection(
        saints: loadFixtureSeeds(),
        entries: parseCeIndex(_html),
      );
    });

    test('accepts exactly the 1:1 matches', () {
      final Set<String> matchedSlugs = selection.matches
          .map((CeMatch m) => m.slug)
          .toSet();
      expect(matchedSlugs, <String>{
        'bobl',
        'francis-of-assisi',
        'ignatius-loyola',
      });
    });

    test('match rows carry the pinned selection.json shape', () {
      final CeMatch francis = selection.matches.singleWhere(
        (CeMatch m) => m.slug == 'francis-of-assisi',
      );
      expect(francis.jsonKeys, <String>{
        'slug',
        'name',
        'ceCode',
        'ceTitle',
        'ceUrl',
        'patronageCount',
        'featured',
      });
      expect(francis.ceCode, '06255a');
      expect(francis.ceTitle, 'Francis of Assisi, Saint');
      expect(francis.ceUrl, 'https://www.newadvent.org/cathen/06255a.htm');
      expect(francis.patronageCount, 4);
      expect(francis.featured, isFalse);
    });

    test('honorific strip: St. Francis of Assisi matches the CE article', () {
      expect(
        selection.matches.any(
          (CeMatch m) => m.slug == 'francis-of-assisi' && m.ceCode == '06255a',
        ),
        isTrue,
      );
    });

    test('surname-reorder: Loyola, Ignatius matches St. Ignatius Loyola', () {
      expect(
        selection.matches.any(
          (CeMatch m) => m.slug == 'ignatius-loyola' && m.ceCode == '07487a',
        ),
        isTrue,
      );
    });

    test('entity decode: St. Böbl matches B&ouml;bl', () {
      expect(
        selection.matches.any(
          (CeMatch m) => m.slug == 'bobl' && m.ceCode == '01026b',
        ),
        isTrue,
      );
    });

    test('two slugs matching one article -> BOTH quarantined', () {
      final Set<String> collisionSlugs = selection.collisions
          .map((CollisionRow c) => c.slug)
          .toSet();
      expect(collisionSlugs, <String>{
        'francis-xavier',
        'saint-francis-xavier',
      });
      expect(
        selection.collisions.every((CollisionRow c) => c.ceCode == '06256a'),
        isTrue,
      );
      expect(
        selection.collisions.every(
          (CollisionRow c) => c.ceHead == 'Francis Xavier, Saint',
        ),
        isTrue,
      );
      // And neither slug may appear as an accepted match.
      expect(
        selection.matches.any((CeMatch m) => m.ceCode == '06256a'),
        isFalse,
      );
    });

    test(
      'REVIEW FOCUS: St. Adalbert of Egmond never resolves to Adalbert, Saint',
      () {
        final bool matched = selection.matches.any(
          (CeMatch m) => m.slug == 'adalbert-egmond',
        );
        expect(matched, isFalse);
        final bool collided = selection.collisions.any(
          (CollisionRow c) => c.slug == 'adalbert-egmond',
        );
        expect(collided, isFalse);
        final bool fuzzy = selection.fuzzy.any(
          (FuzzyRow f) => f.slug == 'adalbert-egmond',
        );
        expect(fuzzy, isFalse);
        // It is an honest drop with a recorded reason.
        final SelectionDrop drop = selection.drops.singleWhere(
          (SelectionDrop d) => d.slug == 'adalbert-egmond',
        );
        expect(drop.reason, 'no-ce-match');
      },
    );

    test('quarantined slugs also appear in drops, keeping counts honest', () {
      final Map<String, String> dropReasons = <String, String>{
        for (final SelectionDrop d in selection.drops) d.slug: d.reason,
      };
      expect(dropReasons['francis-xavier'], 'collision-quarantined');
      expect(dropReasons['saint-francis-xavier'], 'collision-quarantined');
    });

    test('counts account for every seed', () {
      expect(selection.counts['seeds'], 6);
      expect(selection.counts['matched'], 3);
      expect(selection.counts['dropped'], 3);
    });

    test(
      'ranking: featured first, then patronageCount desc, then name asc',
      () {
        final List<String> order = selection.matches
            .map((CeMatch m) => m.slug)
            .toList();
        // bobl is featured (beats the p4 non-featured pair); francis and
        // ignatius sit at p4, so the name tie-break orders them F < I.
        expect(order, <String>['bobl', 'francis-of-assisi', 'ignatius-loyola']);
      },
    );
  });

  group('buildSelection (synthetic units)', () {
    Selection build(List<Map<String, dynamic>> saints, List<CeEntry> entries) {
      return buildSelection(saints: saints, entries: entries);
    }

    test('patronageCount desc, then name asc, among equal featured', () {
      final Selection selection = build(
        <Map<String, dynamic>>[
          <String, dynamic>{
            'slug': 'zeta',
            'name': 'St. Zeta',
            'patronages': <dynamic>[
              <String, String>{'need': 'a', 'category': 'special'},
              <String, String>{'need': 'b', 'category': 'special'},
              <String, String>{'need': 'c', 'category': 'special'},
              <String, String>{'need': 'd', 'category': 'special'},
              <String, String>{'need': 'e', 'category': 'special'},
            ],
            'featured': false,
          },
          <String, dynamic>{
            'slug': 'alfa',
            'name': 'St. Alfa',
            'patronages': <dynamic>[
              <String, String>{'need': 'a', 'category': 'special'},
              <String, String>{'need': 'b', 'category': 'special'},
              <String, String>{'need': 'c', 'category': 'special'},
              <String, String>{'need': 'd', 'category': 'special'},
              <String, String>{'need': 'e', 'category': 'special'},
            ],
            'featured': false,
          },
          <String, dynamic>{
            'slug': 'mid',
            'name': 'St. Mid',
            'patronages': <dynamic>[
              <String, String>{'need': 'a', 'category': 'special'},
              <String, String>{'need': 'b', 'category': 'special'},
              <String, String>{'need': 'c', 'category': 'special'},
              <String, String>{'need': 'd', 'category': 'special'},
            ],
            'featured': false,
          },
        ],
        <CeEntry>[
          CeEntry(code: '00001a', title: 'Zeta, Saint', note: ''),
          CeEntry(code: '00002a', title: 'Alfa, Saint', note: ''),
          CeEntry(code: '00003a', title: 'Mid, Saint', note: ''),
        ],
      );
      final List<String> order = selection.matches
          .map((CeMatch m) => m.slug)
          .toList();
      // p5 first (name asc: alfa < zeta), then the p4 entry.
      expect(order, <String>['alfa', 'zeta', 'mid']);
    });

    test('fuzzy >= 0.9 candidates are accepted 1:1', () {
      final Selection selection = build(loadFixtureSeeds(), <CeEntry>[
        CeEntry(
          code: '06255b',
          title: 'Francis of Assissi, Saint',
          note: 'Founder of the Franciscan Order, the poverello of Assisi',
        ),
        CeEntry(code: '01026a', title: 'Adalbert, Saint', note: ''),
      ]);
      final CeMatch match = selection.matches.singleWhere(
        (CeMatch m) => m.slug == 'francis-of-assisi',
      );
      expect(match.ceCode, '06255b');
      expect(match.matchType, 'fuzzy');
      expect(match.ratio, greaterThanOrEqualTo(0.9));
      // The other 5 seeds have no candidates at all.
      expect(selection.matches, hasLength(1));
    });

    test('fuzzy in [0.75, 0.9) quarantines to manual_review', () {
      final Selection selection = build(
        <Map<String, dynamic>>[
          <String, dynamic>{
            'slug': 'aabcd',
            'name': 'St. Aabcd',
            'patronages': <dynamic>[],
            'featured': false,
          },
        ],
        <CeEntry>[
          // similarity('aabcd', 'aabd') = 1 - 1/5 = 0.8 -> quarantine band.
          CeEntry(code: '0aab1a', title: 'Aabd, Saint', note: ''),
        ],
      );
      expect(selection.matches, isEmpty);
      final FuzzyRow fuzzy = selection.fuzzy.single;
      expect(fuzzy.slug, 'aabcd');
      expect(fuzzy.ceHead, 'Aabd, Saint');
      expect(fuzzy.ratio, closeTo(0.8, 0.0001));
      expect(
        selection.drops
            .singleWhere((SelectionDrop d) => d.slug == 'aabcd')
            .reason,
        'fuzzy-quarantined',
      );
    });

    test('multi-saint group articles quarantine instead of matching', () {
      final Selection selection = build(
        <Map<String, dynamic>>[
          <String, dynamic>{
            'slug': 'quirinus',
            'name': 'St. Quirinus',
            'patronages': <dynamic>[],
            'featured': false,
          },
        ],
        <CeEntry>[
          CeEntry(
            code: '12615a',
            title: 'Quirinus, Saints',
            note: 'Article discusses several saints of this name',
          ),
        ],
      );
      expect(selection.matches, isEmpty);
      expect(selection.collisions.single.slug, 'quirinus');
      expect(selection.collisions.single.ceHead, 'Quirinus, Saints');
      expect(
        selection.drops
            .singleWhere((SelectionDrop d) => d.slug == 'quirinus')
            .reason,
        'collision-quarantined',
      );
    });

    test('seeds without any CE candidate drop with a reason', () {
      final Selection selection = build(
        <Map<String, dynamic>>[
          <String, dynamic>{
            'slug': 'xyzzy',
            'name': 'St. Xyzzy',
            'patronages': <dynamic>[],
            'featured': false,
          },
        ],
        <CeEntry>[CeEntry(code: '00001a', title: 'Zeta, Saint', note: '')],
      );
      expect(selection.matches, isEmpty);
      expect(
        selection.drops
            .singleWhere((SelectionDrop d) => d.slug == 'xyzzy')
            .reason,
        'no-ce-match',
      );
    });
  });

  group('output shapes', () {
    late Selection selection;

    setUp(() {
      selection = buildSelection(
        saints: loadFixtureSeeds(),
        entries: parseCeIndex(_html),
      );
    });

    test('toSelectionJson pins the selection.json shape', () {
      final Map<String, dynamic> json = toSelectionJson(selection);
      expect(json.keys, <String>{'generatedAt', 'matches', 'drops', 'counts'});
      expect((json['matches'] as List<dynamic>).first.keys, <String>{
        'slug',
        'name',
        'ceCode',
        'ceTitle',
        'ceUrl',
        'patronageCount',
        'featured',
      });
      expect((json['drops'] as List<dynamic>).first.keys, <String>{
        'name',
        'reason',
      });
      final Map<String, dynamic> counts =
          json['counts'] as Map<String, dynamic>;
      expect(counts.keys, <String>{'seeds', 'matched', 'dropped'});
    });

    test('toManualReviewJson pins the manual_review.json shape', () {
      final Map<String, dynamic> json = toManualReviewJson(selection);
      expect(json.keys, <String>{'collisions', 'conflicted', 'fuzzy'});
      expect((json['collisions'] as List<dynamic>).first.keys, <String>{
        'slug',
        'name',
        'ceHead',
        'ceCode',
      });
      // Conflicted rows carry ceHead, ceCode, ratio, and their refusal
      // cause (here: a trailing-roman-numeral conflict).
      final Selection ordinal = buildSelection(
        saints: <Map<String, dynamic>>[
          <String, dynamic>{
            'slug': 'confseed-ii',
            'name': 'St. Confseed II',
            'patronages': <dynamic>[],
            'featured': false,
            'bio': 'The second Confseed, a martyr under the emperor Decius',
          },
        ],
        entries: <CeEntry>[
          CeEntry(
            code: '0c0f1a',
            title: 'Confseed I',
            note: 'The first Confseed, converted at the praetorium, d. 249',
          ),
        ],
      );
      expect(ordinal.matches, isEmpty);
      final ConflictedRow row = ordinal.conflicted.single;
      expect(row.ceHead, 'Confseed I');
      expect(row.ceCode, '0c0f1a');
      expect(row.slug, 'confseed-ii');
      expect(row.cause, 'ordinal-conflict');
      expect(row.ratio, greaterThanOrEqualTo(0.9));
    });

    test('toReviewJson is the human-readable variant with CE notes', () {
      final Map<String, dynamic> json = toReviewJson(selection);
      final Map<String, dynamic> first =
          (json['matches'] as List<dynamic>).first as Map<String, dynamic>;
      expect(first['ceNote'], isA<String>());
      // The bobl row shows its decoded note.
      final Map<String, dynamic> bobl = (json['matches'] as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .singleWhere((Map<String, dynamic> m) => m['slug'] == 'bobl');
      expect((bobl['ceNote'] as String).isNotEmpty, isTrue);
    });
  });

  // -------------------------------------------------------------------------
  // Fix round 1 regressions: the review's named cases, with CE titles and
  // notes verbatim from the 1907-12 New Advent index pages.
  // -------------------------------------------------------------------------

  group('nameVariants: multi-part comma titles (I1)', () {
    test('Surname, Given, Honorific reorders to Given + Surname', () {
      expect(nameVariants('More, Thomas, Saint'), contains('thomas more'));
      expect(nameVariants('Damasus I, Saint, Pope'), contains('damasus i'));
      expect(nameVariants('Nicholas I, Saint, Pope'), contains('nicholas i'));
      expect(nameVariants('Eugene I, Saint, Pope'), contains('eugene i'));
      expect(nameVariants('Benedict II, Saint, Pope'), contains('benedict ii'));
    });

    test('Comma-honorific parts strip mid-list in any order', () {
      expect(
        nameVariants('Canisius, Peter, Blessed'),
        contains('peter canisius'),
      );
      expect(nameVariants('Faber, Peter, Saint'), contains('peter faber'));
    });

    test('Honorific parts are dropped, qualifiers kept', () {
      expect(
        nameVariants('Colman, Saint, of Templeshambo'),
        contains('colman of templeshambo'),
      );
      expect(nameVariants('Colman, Saint Elo'), contains('colman elo'));
    });

    test('2-part behavior is unchanged (`Loyola, Ignatius`)', () {
      expect(nameVariants('Loyola, Ignatius'), contains('ignatius loyola'));
      expect(nameVariants('Loyola, Ignatius'), contains('loyola ignatius'));
      expect(nameVariants('Bede, The Venerable'), contains('bede'));
      expect(nameVariants('The Popes'), contains('the popes'));
    });
  });

  group('regression C1: one-character-different wrong persons', () {
    CeEntry entry(String code, String title, String note) =>
        CeEntry(code: code, title: title, note: note);

    Map<String, dynamic> seed(String slug, String name, String bio) =>
        <String, dynamic>{
          'slug': slug,
          'name': name,
          'patronages': <dynamic>[],
          'featured': false,
          'bio': bio,
        };

    test('St. Thomas More never claims Moore, Thomas (Irish poet)', () {
      final Selection withCorrect = buildSelection(
        saints: <Map<String, dynamic>>[
          seed(
            'thomas-more',
            'St. Thomas More',
            'Martyr, Lord Chancellor of England',
          ),
        ],
        entries: <CeEntry>[
          entry('10553b', 'Moore, Thomas', 'Poet and biographer, b. at Dublin'),
          entry('14689c', 'More, Thomas, Saint', 'Martyr, Lord Chancellor'),
        ],
      );
      expect(withCorrect.matches.single.ceCode, '14689c');
      expect(withCorrect.matches.single.matchType, 'exact');

      // Without the correct article the wrong-person candidate refuses
      // (inverted-title surname guard), it never silently matches.
      final Selection mooreOnly = buildSelection(
        saints: <Map<String, dynamic>>[
          seed(
            'thomas-more',
            'St. Thomas More',
            'Martyr, Lord Chancellor of England',
          ),
        ],
        entries: <CeEntry>[
          entry('10553b', 'Moore, Thomas', 'Poet and biographer, b. at Dublin'),
        ],
      );
      expect(mooreOnly.matches, isEmpty);
      expect(mooreOnly.conflicted.single.cause, 'surname-mismatch');
      expect(
        mooreOnly.drops
            .singleWhere((SelectionDrop d) => d.slug == 'thomas-more')
            .reason,
        'conflicted-quarantined',
      );
    });

    test('St. Damasus I claims Damasus I, Saint, Pope; never Damasus II', () {
      final Selection selection = buildSelection(
        saints: <Map<String, dynamic>>[
          seed(
            'pope-damasus-i',
            'St. Damasus I',
            'Condemned the Apollinarian heresy',
          ),
        ],
        entries: <CeEntry>[
          entry(
            '04614a',
            'Damasus II, Pope',
            'A native of Bavaria and the third German',
          ),
          entry(
            '04613a',
            'Damasus I, Saint, Pope',
            'Condemned Apollinarianism',
          ),
        ],
      );
      expect(selection.matches.single.ceCode, '04613a');
      expect(selection.matches.single.matchType, 'exact');
      expect(selection.matches.single.ceTitle, 'Damasus I, Saint, Pope');

      final Selection wrongOnly = buildSelection(
        saints: <Map<String, dynamic>>[
          seed(
            'pope-damasus-i',
            'St. Damasus I',
            'Condemned the Apollinarian heresy',
          ),
        ],
        entries: <CeEntry>[
          entry(
            '04614a',
            'Damasus II, Pope',
            'A native of Bavaria and the third German',
          ),
        ],
      );
      expect(wrongOnly.matches, isEmpty);
      expect(wrongOnly.conflicted.single.cause, 'ordinal-conflict');
    });

    test(
      'St. Marcellus I claims Marcellus I, Saint, Pope; never Marcellus II',
      () {
        final Selection selection = buildSelection(
          saints: <Map<String, dynamic>>[
            seed(
              'pope-marcellus-i',
              'St. Marcellus I',
              'Pope after the death of Marcellinus',
            ),
          ],
          entries: <CeEntry>[
            entry(
              '09641a',
              'Marcellus II, Pope',
              'Born 6 May, 1501 at Montepulciano',
            ),
            entry(
              '09640b',
              'Marcellus I, Saint, Pope',
              'Pope after Marcellinus',
            ),
          ],
        );
        expect(selection.matches.single.ceCode, '09640b');

        final Selection wrongOnly = buildSelection(
          saints: <Map<String, dynamic>>[
            seed(
              'pope-marcellus-i',
              'St. Marcellus I',
              'Pope after the death of Marcellinus',
            ),
          ],
          entries: <CeEntry>[
            entry(
              '09641a',
              'Marcellus II, Pope',
              'Born 6 May, 1501 at Montepulciano',
            ),
          ],
        );
        expect(wrongOnly.matches, isEmpty);
        expect(wrongOnly.conflicted.single.cause, 'ordinal-conflict');
      },
    );

    test('St. Theodosius II never claims Theodosius I (Roman Emperor)', () {
      final Selection selection = buildSelection(
        saints: <Map<String, dynamic>>[
          seed(
            'theodosius-ii',
            'St. Theodosius II',
            'Bishop of Kiev, a Russian abbot',
          ),
        ],
        entries: <CeEntry>[
          entry(
            '14577d',
            'Theodosius I',
            'Roman Emperor, born in Spain, died at Milan',
          ),
        ],
      );
      expect(selection.matches, isEmpty);
      final ConflictedRow row = selection.conflicted.single;
      expect(row.cause, 'ordinal-conflict');
      expect(row.ceHead, 'Theodosius I');
      expect(
        selection.drops
            .singleWhere((SelectionDrop d) => d.slug == 'theodosius-ii')
            .reason,
        'conflicted-quarantined',
      );
    });

    test('St. Deogratias never claims Deo Gratias (liturgical formula)', () {
      final Selection selection = buildSelection(
        saints: <Map<String, dynamic>>[
          seed(
            'deogratias-bishop',
            'St. Deogratias',
            'Bishop of Carthage under Gaiseric',
          ),
        ],
        entries: <CeEntry>[
          entry(
            '04737a',
            'Deo Gratias',
            'An old liturgical formula of the Latin Church',
          ),
        ],
      );
      expect(selection.matches, isEmpty);
      expect(selection.conflicted.single.cause, 'non-person-article');
      expect(
        selection.drops
            .singleWhere((SelectionDrop d) => d.slug == 'deogratias-bishop')
            .reason,
        'conflicted-quarantined',
      );
    });

    test('St. Contentius never claims Consentius (family-name article)', () {
      final Selection selection = buildSelection(
        saints: <Map<String, dynamic>>[
          seed(
            'contentius',
            'St. Contentius',
            'A bishop of the early Gallic church',
          ),
        ],
        entries: <CeEntry>[
          entry(
            '04284a',
            'Consentius',
            'The name of a fifth-century Gallo-Roman family, three of whose representatives are known',
          ),
        ],
      );
      expect(selection.matches, isEmpty);
      expect(selection.conflicted.single.cause, 'multi-person-article');
    });

    test(
      'St. Oda of Canterbury never claims Odo of Canterbury (Abbot of Battle)',
      () {
        final Selection selection = buildSelection(
          saints: <Map<String, dynamic>>[
            seed(
              'oda-of-canterbury',
              'St. Oda of Canterbury',
              'A bishop of the English church of the tenth century',
            ),
          ],
          entries: <CeEntry>[
            entry('11211b', 'Odo of Canterbury', 'Abbot of Battle (d. 1200)'),
          ],
        );
        expect(selection.matches, isEmpty);
        // The whole-string ratio clears the accept floor (0.9412) — grounding
        // is the guard that refuses it.
        expect(selection.conflicted.single.ratio, greaterThanOrEqualTo(0.9));
        expect(selection.conflicted.single.cause, 'no-grounding');
        expect(
          selection.drops
              .singleWhere((SelectionDrop d) => d.slug == 'oda-of-canterbury')
              .reason,
          'conflicted-quarantined',
        );
      },
    );
  });

  group('regression C2: shared article and bare-name collisions', () {
    test('St. Pelagia never claims the four-saints Pelagia article', () {
      final Selection selection = buildSelection(
        saints: <Map<String, dynamic>>[
          <String, dynamic>{
            'slug': 'pelagia',
            'name': 'St. Pelagia',
            'patronages': <dynamic>[],
            'featured': false,
          },
        ],
        entries: <CeEntry>[
          CeEntry(
            code: '11601d',
            title: 'Pelagia',
            note: 'Discusses four saints of this name',
          ),
        ],
      );
      expect(selection.matches, isEmpty);
      expect(selection.collisions.single.ceCode, '11601d');
      expect(selection.collisions.single.ceHead, 'Pelagia');
      expect(
        selection.drops
            .singleWhere((SelectionDrop d) => d.slug == 'pelagia')
            .reason,
        'collision-quarantined',
      );
    });

    test('moses-bishop-of-the-arabs never claims bare Moses (the prophet)', () {
      final Selection selection = buildSelection(
        saints: <Map<String, dynamic>>[
          <String, dynamic>{
            'slug': 'moses-bishop-of-the-arabs',
            'name': 'St. Moses',
            'patronages': <dynamic>[],
            'featured': false,
          },
        ],
        entries: <CeEntry>[
          CeEntry(
            code: '10596a',
            title: 'Moses',
            note: 'Hebrew liberator, leader, lawgiver, prophet, and historian',
          ),
        ],
      );
      expect(selection.matches, isEmpty);
      expect(selection.collisions.single.ceCode, '10596a');
      expect(
        selection.drops
            .singleWhere(
              (SelectionDrop d) => d.slug == 'moses-bishop-of-the-arabs',
            )
            .reason,
        'collision-quarantined',
      );
    });

    test('pope-qualified slug never claims a marker-less bare title', () {
      // CE titles for popes always carry a Pope/Saint marker; a pope seed
      // claiming bare `Caius` (a third-century Christian author) is a
      // wrong-person match, same class as the Moses collision.
      final Selection selection = buildSelection(
        saints: <Map<String, dynamic>>[
          <String, dynamic>{
            'slug': 'pope-caius',
            'name': 'Pope St. Caius',
            'patronages': <dynamic>[],
            'featured': false,
          },
          <String, dynamic>{
            'slug': 'pope-anacletus',
            'name': 'St. Anacletus',
            'patronages': <dynamic>[],
            'featured': false,
          },
        ],
        entries: <CeEntry>[
          CeEntry(
            code: '03144a',
            title: 'Caius',
            note: 'Third-century Christian author',
          ),
          CeEntry(
            code: '01229a',
            title: 'Anacletus, Pope Saint',
            note: 'Third pope, a martyr',
          ),
        ],
      );
      expect(selection.matches.map((CeMatch m) => m.slug), <String>[
        'pope-anacletus',
      ]);
      expect(
        selection.drops
            .singleWhere((SelectionDrop d) => d.slug == 'pope-caius')
            .reason,
        'collision-quarantined',
      );
      expect(selection.collisions.single.ceCode, '03144a');
    });

    test('bare-name guard spares unqualified slugs and marked titles', () {
      // Corbinian (no slug qualifier) keeps its exact bare-title match;
      // Hedwig matches a marked title even though her name is bare...
      final Selection selection = buildSelection(
        saints: <Map<String, dynamic>>[
          <String, dynamic>{
            'slug': 'corbinian',
            'name': 'St. Corbinian',
            'patronages': <dynamic>[],
            'featured': false,
            'bio': 'Bishop of Freising in Bavaria',
          },
        ],
        entries: <CeEntry>[
          CeEntry(
            code: '03782a',
            title: 'Corbinian',
            note: 'Bishop of Freising, in Bavaria',
          ),
          CeEntry(
            code: '10596a',
            title: 'Moses',
            note: 'Hebrew liberator, leader, lawgiver, prophet',
          ),
        ],
      );
      expect(selection.matches.single.ceCode, '03782a');
      expect(selection.matches.single.matchType, 'exact');
    });
  });

  group('regression I1: recovered 1:1 matches', () {
    CeEntry entry(String code, String title, String note) =>
        CeEntry(code: code, title: title, note: note);

    void expectExact({
      required Map<String, dynamic> seed,
      required List<CeEntry> entries,
      required String ceCode,
    }) {
      final Selection selection = buildSelection(
        saints: <Map<String, dynamic>>[seed],
        entries: entries,
      );
      expect(selection.matches, hasLength(1), reason: 'single 1:1 match');
      expect(selection.matches.single.ceCode, ceCode);
      expect(selection.matches.single.matchType, 'exact');
      expect(selection.drops, isEmpty);
    }

    test('St. Nicholas I -> Nicholas I, Saint, Pope (never Nicholas II)', () {
      expectExact(
        seed: <String, dynamic>{
          'slug': 'pope-nicholas-i',
          'name': 'St. Nicholas I',
          'patronages': <dynamic>[],
          'featured': false,
        },
        entries: <CeEntry>[
          entry('11054a', 'Nicholas I, Saint, Pope', 'Strengthened the papacy'),
          entry('11055a', 'Nicholas II, Pope', 'Elected in 1058'),
        ],
        ceCode: '11054a',
      );
    });

    test('St. Eugene I -> Eugene I, Saint, Pope (never Eugene II)', () {
      expectExact(
        seed: <String, dynamic>{
          'slug': 'pope-eugene-i',
          'name': 'St. Eugene I',
          'patronages': <dynamic>[],
          'featured': false,
        },
        entries: <CeEntry>[
          entry('05598a', 'Eugene I, Saint, Pope', 'Pope in 654'),
          entry('05598b', 'Eugene II, Pope', 'Pope in 824'),
        ],
        ceCode: '05598a',
      );
    });

    test(
      'St. Benedict II -> Benedict II, Saint, Pope (never Benedict III)',
      () {
        expectExact(
          seed: <String, dynamic>{
            'slug': 'pope-benedict-ii',
            'name': 'St. Benedict II',
            'patronages': <dynamic>[],
            'featured': false,
          },
          entries: <CeEntry>[
            entry('02427d', 'Benedict II, Saint, Pope', 'Pope, d. 685'),
            entry('02427e', 'Benedict III, Pope', 'Pope, d. 858'),
          ],
          ceCode: '02427d',
        );
      },
    );

    test('St. Peter Canisius -> Canisius, Peter, Blessed', () {
      expectExact(
        seed: <String, dynamic>{
          'slug': 'peter-canisius',
          'name': 'St. Peter Canisius',
          'patronages': <dynamic>[],
          'featured': false,
        },
        entries: <CeEntry>[
          entry(
            '11756c',
            'Canisius, Peter, Blessed',
            'Jesuit, Doctor of the Church',
          ),
          entry('03250b', 'Canisius, Henricus', 'Historian (1510-1587)'),
          entry('03250c', 'Canisius, Theodorich', 'Another Canisius'),
        ],
        ceCode: '11756c',
      );
    });

    test('St. Peter Faber -> Faber, Peter, Saint (never Faber, Philip)', () {
      expectExact(
        seed: <String, dynamic>{
          'slug': 'peter-faber',
          'name': 'St. Peter Faber',
          'patronages': <dynamic>[],
          'featured': false,
        },
        entries: <CeEntry>[
          entry(
            '11767a',
            'Faber, Peter, Saint',
            'First Jesuit, companion of St. Ignatius',
          ),
          entry('05742c', 'Faber, Philip', 'Bishop of Vienna'),
        ],
        ceCode: '11767a',
      );
    });

    test('St. Colmans keep distinct articles', () {
      // The qualifiers in the multi-part titles must not collapse into a
      // shared bare `colman` claim (which would collide both seeds).
      final Selection selection = buildSelection(
        saints: <Map<String, dynamic>>[
          <String, dynamic>{
            'slug': 'colman-of-templeshambo',
            'name': 'St. Colman of Templeshambo',
            'patronages': <dynamic>[],
            'featured': false,
          },
          <String, dynamic>{
            'slug': 'colm-n-elo',
            'name': 'St. Colmán Elo',
            'patronages': <dynamic>[],
            'featured': false,
          },
          <String, dynamic>{
            'slug': 'colman-martyr',
            'name': 'St. Colman',
            'patronages': <dynamic>[],
            'featured': false,
          },
        ],
        entries: <CeEntry>[
          entry(
            '04115a',
            'Colman, Saint, of Templeshambo',
            'Irish abbot of Templeshambo',
          ),
          entry(
            '04115e',
            'Colman, Saint Elo',
            'Irish bishop on the island of Elo',
          ),
          entry('04115g', 'Colman, Saint', 'Irishman martyred on pilgrimage'),
          entry('04115c', 'Colman, Saint, of Mayo', 'An abbey founder'),
        ],
      );
      final Map<String, String> slugToCode = <String, String>{
        for (final CeMatch m in selection.matches) m.slug: m.ceCode,
      };
      expect(slugToCode, <String, String>{
        'colman-of-templeshambo': '04115a',
        'colm-n-elo': '04115e',
        'colman-martyr': '04115g',
      });
      expect(selection.drops, isEmpty);
    });
  });

  group('regression: legitimate spelling-variant accepts survive', () {
    CeEntry entry(String code, String title, String note) =>
        CeEntry(code: code, title: title, note: note);

    test('St. Olaf Haraldsson still matches Haraldson, Saint Olaf', () {
      final Selection selection = buildSelection(
        saints: <Map<String, dynamic>>[
          <String, dynamic>{
            'slug': 'olaf-haraldsson',
            'name': 'St. Olaf Haraldsson',
            'patronages': <dynamic>[],
            'featured': false,
            'bio': 'King and martyr of Norway, fell in battle at Stiklestad',
          },
        ],
        entries: <CeEntry>[
          entry(
            '05952a',
            'Haraldson, Saint Olaf',
            'Martyr and King of Norway, d. 1030',
          ),
        ],
      );
      expect(selection.matches.single.ceCode, '05952a');
      expect(selection.matches.single.matchType, 'fuzzy');
      expect(selection.matches.single.ratio, greaterThanOrEqualTo(0.9));
    });

    test('St. Earconwald still matches Erconwald, Saint (grounding)', () {
      final Selection selection = buildSelection(
        saints: <Map<String, dynamic>>[
          <String, dynamic>{
            'slug': 'earconwald',
            'name': 'St. Earconwald',
            'patronages': <dynamic>[],
            'featured': false,
            'bio':
                'Bishop of London, founded the monasteries of Chertsey and Barking',
          },
        ],
        entries: <CeEntry>[
          entry(
            '04171a',
            'Erconwald, Saint',
            'Monk, Bishop of London, founded two monasteries',
          ),
        ],
      );
      expect(selection.matches.single.ceCode, '04171a');
      expect(selection.matches.single.matchType, 'fuzzy');
    });

    test('St. Stanislaus Kostka still matches Kostka, Saint Stanislas', () {
      final Selection selection = buildSelection(
        saints: <Map<String, dynamic>>[
          <String, dynamic>{
            'slug': 'stanislaus-kostka',
            'name': 'St. Stanislaus Kostka',
            'patronages': <dynamic>[],
            'featured': false,
            'bio': 'Polish Jesuit novice, died in Rome in 1568',
          },
        ],
        entries: <CeEntry>[
          entry(
            '12312a',
            'Kostka, Saint Stanislas',
            'Polish Jesuit, died in 1568',
          ),
        ],
      );
      expect(selection.matches.single.ceCode, '12312a');
      expect(selection.matches.single.matchType, 'fuzzy');
    });

    test(
      'St. Ignatios of Constantinople still matches Ignatius of Constantinople',
      () {
        final Selection selection = buildSelection(
          saints: <Map<String, dynamic>>[
            <String, dynamic>{
              'slug': 'ignatios-of-constantinople',
              'name': 'St. Ignatios of Constantinople',
              'patronages': <dynamic>[],
              'featured': false,
              'bio': 'Patriarch of Constantinople, deposed and restored',
            },
          ],
          entries: <CeEntry>[
            entry(
              '04771c',
              'Ignatius of Constantinople, Saint',
              'Son of Emperor Michael I, patriarch, deposed',
            ),
          ],
        );
        expect(selection.matches.single.ceCode, '04771c');
        expect(selection.matches.single.matchType, 'fuzzy');
      },
    );
  });
}
