import 'package:flutter_test/flutter_test.dart';
import 'package:saint_data/saint_data.dart';

/// Inline fixture based on the real `abba-garima.json` source record
/// (bio shortened; all other values verbatim from the dataset).
final Map<String, dynamic> garimaJson = <String, dynamic>{
  'slug': 'abba-garima',
  'name': 'St. Abba Garima',
  'feastDay': '06-24',
  'bio': 'Abba Garima was one of the Nine Saints of Ethiopia, a group of '
      'monastic fathers traditionally said to have arrived from the Roman '
      'East during the late fifth century. He is remembered as a father of '
      'monks, founding a monastery at Enda Garima in the highlands of Tigray.',
  'patronages': <Map<String, dynamic>>[
    <String, dynamic>{'need': 'monks', 'category': 'spiritual'},
    <String, dynamic>{'need': 'missionaries', 'category': 'spiritual'},
  ],
  'prayer': <String, dynamic>{
    'text': 'O God, who sent blessed Garima among the Nine Saints to plant '
        'the monastic life and the Gospel in the highlands of Ethiopia, '
        'grant, we pray, that through his intercession the Church in every '
        'land may be built up in prayer, learning, and the fear of your '
        'name. We ask this through Christ our Lord. Amen.',
    'source': 'original',
  },
  'sources': <String>['https://en.wikipedia.org/wiki/Abba_Garima'],
  'featured': false,
  'draft': false,
};

/// Fixture with an image object, `draft: true`, and `featured: true`.
final Map<String, dynamic> imagedJson = <String, dynamic>{
  'slug': 'aaron-of-aleth',
  'name': 'St. Aaron of Aleth',
  'feastDay': '06-22',
  'bio': 'Aaron of Aleth was a hermit on an island off the Breton coast in '
      'the sixth century.',
  'patronages': <Map<String, dynamic>>[
    <String, dynamic>{'need': 'hermits', 'category': 'spiritual'},
  ],
  'prayer': <String, dynamic>{
    'text': 'O God, who called your servant Aaron to withdraw from the world, '
        'grant that we may follow him into prayer.',
    'source': 'traditional',
  },
  'sources': <String>['https://en.wikipedia.org/wiki/Aaron_of_Aleth'],
  'featured': true,
  'draft': true,
  'image': <String, dynamic>{
    'url': 'https://upload.wikimedia.org/wikipedia/commons/6/63/Saint_Aaron.jpg',
    'attribution': 'Wikimedia Commons',
    'altText': 'Portrait of St. Aaron of Aleth',
  },
};

/// Fixture with no `prayer` key.
final Map<String, dynamic> noPrayerJson = <String, dynamic>{
  'slug': 'nicholas-of-tolentino',
  'name': 'St. Nicholas of Tolentino',
  'feastDay': '09-10',
  'bio': 'Nicholas of Tolentino was an Augustinian friar remembered for his '
      'charity toward the souls in purgatory.',
  'patronages': <Map<String, dynamic>>[
    <String, dynamic>{'need': 'lost souls', 'category': 'spiritual'},
  ],
  'sources': <String>['https://en.wikipedia.org/wiki/Nicholas_of_Tolentino'],
};

/// Minimal fixture: no `feastDay`, `featured`, `canonized`, `prayer`, or
/// `image` keys, to exercise defaults.
final Map<String, dynamic> minimalJson = <String, dynamic>{
  'slug': 'saint-cyril',
  'name': 'St. Cyril of Jerusalem',
  'bio': 'Cyril of Jerusalem instructed catechumens in the faith in the '
      'fourth century.',
  'patronages': <Map<String, dynamic>>[
    <String, dynamic>{'need': 'catechists', 'category': 'spiritual'},
  ],
  'sources': <String>[],
};

void main() {
  group('Saint.fromSourceJson', () {
    test('parses the abba-garima record fields', () {
      final Saint saint = Saint.fromSourceJson(garimaJson);

      expect(saint.slug, 'abba-garima');
      expect(saint.name, 'St. Abba Garima');
      expect(saint.feastDay, '06-24');
      expect(saint.canonized, isNull);
      expect(
        saint.bio,
        'Abba Garima was one of the Nine Saints of Ethiopia, a group of '
        'monastic fathers traditionally said to have arrived from the Roman '
        'East during the late fifth century. He is remembered as a father of '
        'monks, founding a monastery at Enda Garima in the highlands of Tigray.',
      );
      expect(saint.patronages, hasLength(2));
      expect(saint.patronages[0].need, 'monks');
      expect(saint.patronages[0].category, SaintCategory.spiritual);
      expect(saint.patronages[1].need, 'missionaries');
      expect(saint.patronages[1].category, SaintCategory.spiritual);
      expect(
        saint.prayer?.text,
        'O God, who sent blessed Garima among the Nine Saints to plant '
        'the monastic life and the Gospel in the highlands of Ethiopia, '
        'grant, we pray, that through his intercession the Church in every '
        'land may be built up in prayer, learning, and the fear of your '
        'name. We ask this through Christ our Lord. Amen.',
      );
      expect(saint.prayer?.source, 'original');
      expect(
        saint.sources,
        <String>['https://en.wikipedia.org/wiki/Abba_Garima'],
      );
      expect(saint.featured, isFalse);
      expect(saint.thumbAsset, isNull);
      expect(saint.imageAttribution, isNull);
      expect(saint.imageAlt, isNull);
    });

    test('reports prayer, image, and feast flags', () {
      final Saint saint = Saint.fromSourceJson(garimaJson);

      expect(saint.hasPrayer, isTrue);
      expect(saint.hasImage, isFalse);
      expect(saint.hasKnownFeast, isTrue);
    });

    test('parses image fields, keeps featured, and drops draft', () {
      final Saint saint = Saint.fromSourceJson(imagedJson);

      expect(saint.slug, 'aaron-of-aleth');
      expect(saint.featured, isTrue);
      expect(saint.thumbAsset, 'assets/thumbs/aaron-of-aleth.jpg');
      expect(saint.hasImage, isTrue);
      expect(saint.imageAttribution, 'Wikimedia Commons');
      expect(saint.imageAlt, 'Portrait of St. Aaron of Aleth');
      // `draft` never reaches the runtime model or its serialized shape.
      expect(saint.toSourceJson().containsKey('draft'), isFalse);
    });

    test('round-trips every retained field through toSourceJson', () {
      final Saint original = Saint.fromSourceJson(imagedJson);
      final Saint roundTripped =
          Saint.fromSourceJson(original.toSourceJson());

      expect(roundTripped.slug, original.slug);
      expect(roundTripped.name, original.name);
      expect(roundTripped.feastDay, original.feastDay);
      expect(roundTripped.canonized, original.canonized);
      expect(roundTripped.bio, original.bio);
      expect(roundTripped.prayer, original.prayer);
      expect(roundTripped.patronages, original.patronages);
      expect(roundTripped.featured, original.featured);
      expect(roundTripped.thumbAsset, original.thumbAsset);
      expect(roundTripped.imageAttribution, original.imageAttribution);
      expect(roundTripped.imageAlt, original.imageAlt);
      expect(roundTripped.sources, original.sources);
      expect(roundTripped, original);
    });

    test('round-trips prayerless records through toSourceJson', () {
      final Saint original = Saint.fromSourceJson(garimaJson);
      final Saint roundTripped =
          Saint.fromSourceJson(original.toSourceJson());

      expect(roundTripped.prayer, isNotNull);
      expect(roundTripped, original);
    });

    test('equal records have equal hashCodes', () {
      final Saint a = Saint.fromSourceJson(garimaJson);
      final Saint b = Saint.fromSourceJson(garimaJson);

      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a == Saint.fromSourceJson(imagedJson), isFalse);
    });
  });

  group('Saint field defaults', () {
    test('absent booleans, feastDay, and image fall back', () {
      final Saint saint = Saint.fromSourceJson(minimalJson);

      expect(saint.feastDay, 'unknown');
      expect(saint.hasKnownFeast, isFalse);
      expect(saint.featured, isFalse);
      expect(saint.canonized, isNull);
      expect(saint.prayer, isNull);
      expect(saint.hasPrayer, isFalse);
      expect(saint.thumbAsset, isNull);
      expect(saint.hasImage, isFalse);
      expect(saint.patronages, hasLength(1));
      expect(saint.sources, isEmpty);
    });

    test('no prayer key yields null prayer and hasPrayer false', () {
      final Saint saint = Saint.fromSourceJson(noPrayerJson);

      expect(saint.prayer, isNull);
      expect(saint.hasPrayer, isFalse);
      expect(saint.slug, 'nicholas-of-tolentino');
    });
  });

  group('Saint.fromDbRow', () {
    final Map<String, dynamic> thereseRow = <String, dynamic>{
      'slug': 'therese-of-lisieux',
      'name': 'St. Thérèse of Lisieux',
      'feast_day': '10-01',
      'canonized': '1925',
      'bio': 'Therese of Lisieux was a Carmelite nun who taught the little '
          'way of spiritual childhood.',
      'prayer_text': 'O little Therese, teach us your confident trust in God.',
      'prayer_source': 'traditional',
      'featured': 1,
      'thumb_asset': 'packages/saint_data/assets/thumbs/therese-of-lisieux.jpg',
      'image_attribution': 'Wikimedia Commons',
      'image_alt': 'Portrait of St. Therese of Lisieux',
    };

    test('parses db columns with patronages and sources', () {
      final Saint saint = Saint.fromDbRow(
        thereseRow,
        patronages: <SaintPatronage>[
          const SaintPatronage(
            need: 'missions',
            category: SaintCategory.spiritual,
          ),
          const SaintPatronage(need: 'florists', category: SaintCategory.jobs),
        ],
        sources: <String>['https://en.wikipedia.org/wiki/Th%C3%A9r%C3%A8se'],
      );

      expect(saint.slug, 'therese-of-lisieux');
      expect(saint.name, 'St. Thérèse of Lisieux');
      expect(saint.feastDay, '10-01');
      expect(saint.canonized, '1925');
      expect(saint.bio, contains('little way'));
      expect(saint.prayer?.text, contains('confident trust'));
      expect(saint.prayer?.source, 'traditional');
      expect(saint.hasPrayer, isTrue);
      expect(saint.featured, isTrue);
      expect(saint.thumbAsset,
          'packages/saint_data/assets/thumbs/therese-of-lisieux.jpg');
      expect(saint.hasImage, isTrue);
      expect(saint.imageAttribution, 'Wikimedia Commons');
      expect(saint.imageAlt, 'Portrait of St. Therese of Lisieux');
      expect(saint.patronages, hasLength(2));
      expect(saint.patronages[0], const SaintPatronage(
        need: 'missions',
        category: SaintCategory.spiritual,
      ));
      expect(saint.sources,
          <String>['https://en.wikipedia.org/wiki/Th%C3%A9r%C3%A8se']);
    });

    test('featured 0 and absent map to false', () {
      expect(
        Saint.fromDbRow(<String, dynamic>{...thereseRow, 'featured': 0})
            .featured,
        isFalse,
      );
      final Map<String, dynamic> absentRow = <String, dynamic>{...thereseRow}
        ..remove('featured');
      expect(Saint.fromDbRow(absentRow).featured, isFalse);
    });

    test('null prayer columns yield null prayer', () {
      final Saint saint = Saint.fromDbRow(<String, dynamic>{
        ...thereseRow,
        'prayer_text': null,
        'prayer_source': null,
      });

      expect(saint.prayer, isNull);
      expect(saint.hasPrayer, isFalse);
    });

    test('defaults patronages and sources to empty lists', () {
      final Saint saint = Saint.fromDbRow(thereseRow);

      expect(saint.patronages, isEmpty);
      expect(saint.sources, isEmpty);
    });

    test('null optional image columns yield null fields', () {
      final Saint saint = Saint.fromDbRow(<String, dynamic>{
        ...thereseRow,
        'thumb_asset': null,
        'image_attribution': null,
        'image_alt': null,
      });

      expect(saint.thumbAsset, isNull);
      expect(saint.imageAttribution, isNull);
      expect(saint.imageAlt, isNull);
    });
  });

  group('SaintPatronage', () {
    test('fromJson and toJson round-trip', () {
      final SaintPatronage patronage = SaintPatronage.fromJson(
        <String, dynamic>{'need': 'monks', 'category': 'spiritual'},
      );

      expect(patronage.need, 'monks');
      expect(patronage.category, SaintCategory.spiritual);
      expect(
        patronage.toJson(),
        <String, dynamic>{'need': 'monks', 'category': 'spiritual'},
      );
      expect(
        SaintPatronage.fromJson(patronage.toJson()),
        const SaintPatronage(need: 'monks', category: SaintCategory.spiritual),
      );
    });

    test('unknown or missing category throws', () {
      expect(
        () => SaintPatronage.fromJson(<String, dynamic>{
          'need': 'monks',
          'category': 'bogus',
        }),
        throwsFormatException,
      );
      expect(
        () => SaintPatronage.fromJson(<String, dynamic>{'need': 'monks'}),
        throwsFormatException,
      );
    });

    test('missing need throws', () {
      expect(
        () => SaintPatronage.fromJson(
          <String, dynamic>{'category': 'spiritual'},
        ),
        throwsFormatException,
      );
    });

    test('equal patronages have equal hashCodes', () {
      const SaintPatronage a = SaintPatronage(
        need: 'monks',
        category: SaintCategory.spiritual,
      );
      const SaintPatronage b = SaintPatronage(
        need: 'monks',
        category: SaintCategory.spiritual,
      );

      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(
        a == const SaintPatronage(need: 'monks', category: SaintCategory.jobs),
        isFalse,
      );
    });
  });

  group('SaintPrayer', () {
    test('fromJson parses text and source', () {
      final SaintPrayer prayer = SaintPrayer.fromJson(
        <String, dynamic>{'text': 'Pray for us.', 'source': 'traditional'},
      );

      expect(prayer.text, 'Pray for us.');
      expect(prayer.source, 'traditional');
      expect(prayer.toJson(),
          <String, dynamic>{'text': 'Pray for us.', 'source': 'traditional'});
    });

    test('isValid accepts known sources with text', () {
      expect(
        const SaintPrayer(text: 'Pray for us.', source: 'traditional')
            .isValid,
        isTrue,
      );
      expect(
        const SaintPrayer(text: 'Pray for us.', source: 'original').isValid,
        isTrue,
      );
    });

    test('isValid rejects empty text and unknown sources', () {
      expect(const SaintPrayer(text: '   ', source: 'original').isValid,
          isFalse);
      expect(const SaintPrayer(text: '', source: 'traditional').isValid,
          isFalse);
      expect(const SaintPrayer(text: 'Pray for us.', source: 'blog').isValid,
          isFalse);
    });

    test('fromJson requires text and source', () {
      expect(
        () => SaintPrayer.fromJson(<String, dynamic>{'source': 'original'}),
        throwsFormatException,
      );
      expect(
        () => SaintPrayer.fromJson(<String, dynamic>{'text': 'Pray for us.'}),
        throwsFormatException,
      );
    });

    test('equal prayers have equal hashCodes', () {
      const SaintPrayer a = SaintPrayer(
        text: 'Pray for us.',
        source: 'traditional',
      );
      const SaintPrayer b = SaintPrayer(
        text: 'Pray for us.',
        source: 'traditional',
      );

      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });
  });

  group('SaintCategory', () {
    test("tryParse('illness') returns illness with verbatim label", () {
      final SaintCategory? parsed = SaintCategory.tryParse('illness');

      expect(parsed, SaintCategory.illness);
      expect(parsed!.label, 'Illness & healing');
      expect(parsed.description, 'Diseases, mental health, specific conditions');
    });

    test("tryParse('bogus') returns null", () {
      expect(SaintCategory.tryParse('bogus'), isNull);
      expect(SaintCategory.tryParse(''), isNull);
    });

    test('all 10 ids parse in source order with verbatim labels', () {
      const Map<String, String> expectedLabels = <String, String>{
        'everyday': 'Everyday life',
        'illness': 'Illness & healing',
        'jobs': 'Jobs & professions',
        'travel': 'Travel & transport',
        'persecution': 'Persecution & prisoners',
        'spiritual': 'Spiritual life',
        'military': 'Military & first responders',
        'family': 'Children & family',
        'nature': 'Animals & nature',
        'special': 'Special intentions',
      };

      expect(
        SaintCategory.values.map((SaintCategory category) => category.name),
        expectedLabels.keys.toList(),
      );
      for (final MapEntry<String, String> entry in expectedLabels.entries) {
        final SaintCategory? parsed = SaintCategory.tryParse(entry.key);
        expect(parsed, isNotNull, reason: 'id ${entry.key} should parse');
        expect(parsed!.label, entry.value);
        expect(parsed.description, isNotEmpty);
      }
    });

    test('all 10 descriptions are verbatim from the taxonomy', () {
      const Map<String, String> expectedDescriptions = <String, String>{
        'everyday': 'Lost items, housework, errands, daily needs',
        'illness': 'Diseases, mental health, specific conditions',
        'jobs': 'Vocations, trades, occupations',
        'travel': 'Travelers, drivers, sailors, aviators',
        'persecution': 'Martyrs, oppressed, prisoners, refugees',
        'spiritual': 'Doubt, conversion, prayer, temptations',
        'military': 'Soldiers, police, firefighters, EMS',
        'family': 'Children, mothers, fathers, fertility, marriage',
        'nature': 'Pets, ecology, environment, weather',
        'special': 'Impossible causes, the dying, the poor',
      };

      for (final SaintCategory category in SaintCategory.values) {
        expect(
          category.description,
          expectedDescriptions[category.name],
          reason: 'description of ${category.name} must match the taxonomy',
        );
      }
    });
  });

  group('SaintSearchResult', () {
    const Saint joan = Saint(
      slug: 'joan-of-arc',
      name: 'St. Joan of Arc',
      feastDay: '05-30',
      bio: 'A peasant girl who led armies for France.',
    );

    test('holds the saint and rationale', () {
      const SaintSearchResult result = SaintSearchResult(
        saint: joan,
        matchRationale: 'name',
      );

      expect(result.saint, same(joan));
      expect(result.matchRationale, 'name');
    });

    test('equal results have equal hashCodes', () {
      const SaintSearchResult a = SaintSearchResult(
        saint: joan,
        matchRationale: 'name',
      );
      const SaintSearchResult b = SaintSearchResult(
        saint: joan,
        matchRationale: 'name',
      );

      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });
  });
}
