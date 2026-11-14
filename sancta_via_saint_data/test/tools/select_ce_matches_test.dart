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
        CeEntry(code: '06255b', title: 'Francis of Assissi, Saint', note: ''),
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
      expect(json.keys, <String>{'collisions', 'fuzzy'});
      expect((json['collisions'] as List<dynamic>).first.keys, <String>{
        'slug',
        'name',
        'ceHead',
        'ceCode',
      });
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
}
