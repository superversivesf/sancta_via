import 'package:flutter_test/flutter_test.dart';
import 'package:rosary_companion/models/mystery.dart';
import 'package:rosary_companion/models/mystery_set.dart';

void main() {
  group('Mystery Model', () {
    const testMystery = Mystery(
      id: 'joyful-1',
      name: 'The Annunciation',
      mysterySet: MysterySet.joyful,
      number: 1,
      fruit: 'Humility',
      scripture: 'Luke 1:26-38',
      description:
          'The Angel Gabriel announces to Mary that she will conceive and become the mother of Jesus.',
      extendedMeditation: 'Extended meditation text',
      imagePath: 'assets/mysteries/annunciation.png',
      iconName: 'annunciation_icon',
    );

    group('Creation', () {
      test('can be created with all required fields', () {
        const mystery = Mystery(
          id: 'sorrowful-1',
          name: 'The Agony in the Garden',
          mysterySet: MysterySet.sorrowful,
          number: 1,
          fruit: 'Sorrow for Sin',
          scripture: 'Matthew 26:36-46',
          description: 'Jesus prays in the Garden of Gethsemane.',
        );

        expect(mystery.id, equals('sorrowful-1'));
        expect(mystery.name, equals('The Agony in the Garden'));
        expect(mystery.mysterySet, equals(MysterySet.sorrowful));
        expect(mystery.number, equals(1));
        expect(mystery.fruit, equals('Sorrow for Sin'));
        expect(mystery.scripture, equals('Matthew 26:36-46'));
        expect(
          mystery.description,
          equals('Jesus prays in the Garden of Gethsemane.'),
        );
        expect(mystery.extendedMeditation, isNull);
        expect(mystery.imagePath, isNull);
        expect(mystery.iconName, isNull);
      });

      test('can be created with optional fields', () {
        expect(
          testMystery.extendedMeditation,
          equals('Extended meditation text'),
        );
        expect(
          testMystery.imagePath,
          equals('assets/mysteries/annunciation.png'),
        );
        expect(testMystery.iconName, equals('annunciation_icon'));
      });

      test('number must be between 1 and 5', () {
        expect(
          () => Mystery(
            id: 'test-0',
            name: 'Test Mystery',
            mysterySet: MysterySet.joyful,
            number: 0,
            fruit: 'Test Fruit',
            scripture: 'Test 1:1',
            description: 'Test description',
          ),
          throwsAssertionError,
        );

        expect(
          () => Mystery(
            id: 'test-6',
            name: 'Test Mystery',
            mysterySet: MysterySet.joyful,
            number: 6,
            fruit: 'Test Fruit',
            scripture: 'Test 1:1',
            description: 'Test description',
          ),
          throwsAssertionError,
        );

        expect(
          () => Mystery(
            id: 'test-5',
            name: 'Test Mystery',
            mysterySet: MysterySet.joyful,
            number: 5,
            fruit: 'Test Fruit',
            scripture: 'Test 1:1',
            description: 'Test description',
          ),
          returnsNormally,
        );
      });
    });

    group('JSON Serialization', () {
      test('serializes to JSON correctly', () {
        final json = testMystery.toJson();

        expect(json['id'], equals('joyful-1'));
        expect(json['name'], equals('The Annunciation'));
        expect(json['mysterySet'], equals('joyful'));
        expect(json['number'], equals(1));
        expect(json['fruit'], equals('Humility'));
        expect(json['scripture'], equals('Luke 1:26-38'));
        expect(
          json['description'],
          equals(
            'The Angel Gabriel announces to Mary that she will conceive and become the mother of Jesus.',
          ),
        );
        expect(json['extendedMeditation'], equals('Extended meditation text'));
        expect(json['imagePath'], equals('assets/mysteries/annunciation.png'));
        expect(json['iconName'], equals('annunciation_icon'));
      });

      test('deserializes from JSON correctly', () {
        final json = {
          'id': 'glorious-3',
          'name': 'The Descent of the Holy Spirit',
          'mysterySet': 'glorious',
          'number': 3,
          'fruit': 'Love of God',
          'scripture': 'Acts 2:1-41',
          'description':
              'The Holy Spirit descends upon the Apostles at Pentecost.',
          'extendedMeditation': null,
          'imagePath': null,
          'iconName': null,
        };

        final mystery = Mystery.fromJson(json);

        expect(mystery.id, equals('glorious-3'));
        expect(mystery.name, equals('The Descent of the Holy Spirit'));
        expect(mystery.mysterySet, equals(MysterySet.glorious));
        expect(mystery.number, equals(3));
        expect(mystery.fruit, equals('Love of God'));
        expect(mystery.scripture, equals('Acts 2:1-41'));
        expect(
          mystery.description,
          equals('The Holy Spirit descends upon the Apostles at Pentecost.'),
        );
        expect(mystery.extendedMeditation, isNull);
        expect(mystery.imagePath, isNull);
        expect(mystery.iconName, isNull);
      });

      test('round-trip serialization preserves data', () {
        final json = testMystery.toJson();
        final restoredMystery = Mystery.fromJson(json);

        expect(restoredMystery.id, equals(testMystery.id));
        expect(restoredMystery.name, equals(testMystery.name));
        expect(restoredMystery.mysterySet, equals(testMystery.mysterySet));
        expect(restoredMystery.number, equals(testMystery.number));
        expect(restoredMystery.fruit, equals(testMystery.fruit));
        expect(restoredMystery.scripture, equals(testMystery.scripture));
        expect(restoredMystery.description, equals(testMystery.description));
        expect(
          restoredMystery.extendedMeditation,
          equals(testMystery.extendedMeditation),
        );
        expect(restoredMystery.imagePath, equals(testMystery.imagePath));
        expect(restoredMystery.iconName, equals(testMystery.iconName));
      });
    });

    group('Enum Conversions', () {
      test('correctly serializes MysterySet enum', () {
        final joyfulMystery = testMystery.copyWith(
          mysterySet: MysterySet.joyful,
        );
        expect(joyfulMystery.toJson()['mysterySet'], equals('joyful'));

        final sorrowfulMystery = testMystery.copyWith(
          mysterySet: MysterySet.sorrowful,
        );
        expect(sorrowfulMystery.toJson()['mysterySet'], equals('sorrowful'));

        final gloriousMystery = testMystery.copyWith(
          mysterySet: MysterySet.glorious,
        );
        expect(gloriousMystery.toJson()['mysterySet'], equals('glorious'));

        final luminousMystery = testMystery.copyWith(
          mysterySet: MysterySet.luminous,
        );
        expect(luminousMystery.toJson()['mysterySet'], equals('luminous'));
      });

      test('correctly deserializes MysterySet enum from string', () {
        final joyfulJson = {'...': '...', 'mysterySet': 'joyful'};
        expect(
          Mystery.fromJson({...testMystery.toJson(), ...joyfulJson}).mysterySet,
          equals(MysterySet.joyful),
        );

        final sorrowfulJson = {'...': '...', 'mysterySet': 'sorrowful'};
        expect(
          Mystery.fromJson({
            ...testMystery.toJson(),
            ...sorrowfulJson,
          }).mysterySet,
          equals(MysterySet.sorrowful),
        );

        final gloriousJson = {'...': '...', 'mysterySet': 'glorious'};
        expect(
          Mystery.fromJson({
            ...testMystery.toJson(),
            ...gloriousJson,
          }).mysterySet,
          equals(MysterySet.glorious),
        );

        final luminousJson = {'...': '...', 'mysterySet': 'luminous'};
        expect(
          Mystery.fromJson({
            ...testMystery.toJson(),
            ...luminousJson,
          }).mysterySet,
          equals(MysterySet.luminous),
        );
      });
    });

    group('Copy With', () {
      test('creates copy with updated fields', () {
        final updated = testMystery.copyWith(
          name: 'Updated Name',
          fruit: 'Updated Fruit',
        );

        expect(updated.id, equals(testMystery.id));
        expect(updated.name, equals('Updated Name'));
        expect(updated.fruit, equals('Updated Fruit'));
        expect(updated.mysterySet, equals(testMystery.mysterySet));
      });

      test('creates identical copy when no fields provided', () {
        final copy = testMystery.copyWith();

        expect(copy.id, equals(testMystery.id));
        expect(copy.name, equals(testMystery.name));
        expect(copy.mysterySet, equals(testMystery.mysterySet));
        expect(copy.number, equals(testMystery.number));
      });
    });

    group('Computed Properties', () {
      test('fullTitle includes set short name and mystery name', () {
        expect(testMystery.fullTitle, equals('Joyful: The Annunciation'));

        final sorrowful = testMystery.copyWith(
          name: 'The Agony',
          mysterySet: MysterySet.sorrowful,
        );
        expect(sorrowful.fullTitle, equals('Sorrowful: The Agony'));
      });

      test('formattedScripture prefixes with Scripture:', () {
        expect(
          testMystery.formattedScripture,
          equals('Scripture: Luke 1:26-38'),
        );
      });

      test('formattedFruit prefixes with Fruit:', () {
        expect(testMystery.formattedFruit, equals('Fruit: Humility'));
      });

      test('globalOrder returns correct position across all sets', () {
        final joyful1 = testMystery.copyWith(
          mysterySet: MysterySet.joyful,
          number: 1,
        );
        expect(joyful1.globalOrder, equals(1));

        final joyful5 = testMystery.copyWith(
          mysterySet: MysterySet.joyful,
          number: 5,
        );
        expect(joyful5.globalOrder, equals(5));

        final sorrowful1 = testMystery.copyWith(
          mysterySet: MysterySet.sorrowful,
          number: 1,
        );
        expect(sorrowful1.globalOrder, equals(6));

        final sorrowful5 = testMystery.copyWith(
          mysterySet: MysterySet.sorrowful,
          number: 5,
        );
        expect(sorrowful5.globalOrder, equals(10));

        final glorious1 = testMystery.copyWith(
          mysterySet: MysterySet.glorious,
          number: 1,
        );
        expect(glorious1.globalOrder, equals(11));

        final glorious5 = testMystery.copyWith(
          mysterySet: MysterySet.glorious,
          number: 5,
        );
        expect(glorious5.globalOrder, equals(15));

        final luminous1 = testMystery.copyWith(
          mysterySet: MysterySet.luminous,
          number: 1,
        );
        expect(luminous1.globalOrder, equals(16));

        final luminous5 = testMystery.copyWith(
          mysterySet: MysterySet.luminous,
          number: 5,
        );
        expect(luminous5.globalOrder, equals(20));
      });
    });

    group('Equality', () {
      test('equal mysteries have same id', () {
        const mystery1 = Mystery(
          id: 'test-1',
          name: 'Name 1',
          mysterySet: MysterySet.joyful,
          number: 1,
          fruit: 'Fruit 1',
          scripture: 'Scripture 1',
          description: 'Description 1',
        );

        const mystery2 = Mystery(
          id: 'test-1',
          name: 'Different Name',
          mysterySet: MysterySet.sorrowful,
          number: 2,
          fruit: 'Different Fruit',
          scripture: 'Different Scripture',
          description: 'Different Description',
        );

        expect(mystery1, equals(mystery2));
        expect(mystery1.hashCode, equals(mystery2.hashCode));
      });

      test('different ids are not equal', () {
        const mystery1 = Mystery(
          id: 'test-1',
          name: 'Same Name',
          mysterySet: MysterySet.joyful,
          number: 1,
          fruit: 'Same Fruit',
          scripture: 'Same Scripture',
          description: 'Same Description',
        );

        const mystery2 = Mystery(
          id: 'test-2',
          name: 'Same Name',
          mysterySet: MysterySet.joyful,
          number: 1,
          fruit: 'Same Fruit',
          scripture: 'Same Scripture',
          description: 'Same Description',
        );

        expect(mystery1, isNot(equals(mystery2)));
      });
    });

    group('To String', () {
      test('toString returns formatted string', () {
        final str = testMystery.toString();
        expect(str, contains('joyful-1'));
        expect(str, contains('The Annunciation'));
        expect(str, contains('Joyful'));
        expect(str, contains('number: 1'));
      });
    });
  });
}
