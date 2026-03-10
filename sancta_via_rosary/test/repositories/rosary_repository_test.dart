import 'package:flutter_test/flutter_test.dart';
import 'package:rosary_companion/models/models.dart';
import 'package:rosary_companion/repositories/rosary_repository.dart';

void main() {
  group('RosaryRepository', () {
    late RosaryRepository repository;

    setUp(() {
      repository = RosaryRepository.instance;
      repository.clearCache();
    });

    tearDown(() {
      repository.clearCache();
    });

    group('Singleton Pattern', () {
      test('instance returns same object', () {
        final instance1 = RosaryRepository.instance;
        final instance2 = RosaryRepository.instance;

        expect(identical(instance1, instance2), isTrue);
      });

      test('internal constructor creates new instance', () {
        // This is an implementation detail, but we verify the singleton works
        final instance1 = RosaryRepository.instance;
        final instance2 = RosaryRepository.instance;

        expect(instance1, equals(instance2));
      });
    });

    group('getPrayers', () {
      test('returns list of prayers', () {
        final prayers = repository.getPrayers();

        expect(prayers, isNotEmpty);
        expect(prayers.length, greaterThan(5));
      });

      test('contains required opening prayers', () {
        final prayers = repository.getPrayers();

        final prayerIds = prayers.map((p) => p.id).toList();

        expect(prayerIds, contains('sign-of-cross'));
        expect(prayerIds, contains('apostles-creed'));
        expect(prayerIds, contains('our-father-opening'));
        expect(prayerIds, contains('hail-mary-opening'));
        expect(prayerIds, contains('glory-be-opening'));
      });

      test('contains required decade prayers', () {
        final prayers = repository.getPrayers();

        final prayerIds = prayers.map((p) => p.id).toList();

        expect(prayerIds, contains('our-father'));
        expect(prayerIds, contains('hail-mary'));
        expect(prayerIds, contains('glory-be'));
        expect(prayerIds, contains('fatima-prayer'));
      });

      test('contains closing prayers', () {
        final prayers = repository.getPrayers();

        final prayerIds = prayers.map((p) => p.id).toList();

        expect(prayerIds, contains('hail-holy-queen'));
        expect(prayerIds, contains('closing-prayer'));
      });

      test('prayers have correct types', () {
        final prayers = repository.getPrayers();

        final signOfCross = prayers.firstWhere((p) => p.id == 'sign-of-cross');
        expect(signOfCross.type, equals(PrayerType.signOfCross));

        final ourFather = prayers.firstWhere((p) => p.id == 'our-father');
        expect(ourFather.type, equals(PrayerType.ourFather));

        final hailMary = prayers.firstWhere((p) => p.id == 'hail-mary');
        expect(hailMary.type, equals(PrayerType.hailMary));

        final gloryBe = prayers.firstWhere((p) => p.id == 'glory-be');
        expect(gloryBe.type, equals(PrayerType.gloryBe));

        final fatima = prayers.firstWhere((p) => p.id == 'fatima-prayer');
        expect(fatima.type, equals(PrayerType.fatimaPrayer));

        final closing = prayers.firstWhere((p) => p.id == 'hail-holy-queen');
        expect(closing.type, equals(PrayerType.closing));
      });

      test('hail mary has partial prayer structure', () {
        final prayers = repository.getPrayers();
        final hailMary = prayers.firstWhere((p) => p.id == 'hail-mary');

        expect(hailMary.isPartial, isTrue);
        expect(hailMary.partialStart, isNotNull);
        expect(hailMary.partialRepeat, isNotNull);
        expect(hailMary.repeatCount, equals(10));
      });

      test('formatted text is not empty for partial prayers', () {
        final prayers = repository.getPrayers();
        final hailMary = prayers.firstWhere((p) => p.id == 'hail-mary');

        expect(hailMary.formattedText, isNotEmpty);
        expect(hailMary.formattedText, contains('1.'));
        expect(hailMary.formattedText, contains('10.'));
      });

      test('caching returns same list on second call', () {
        final prayers1 = repository.getPrayers();
        final prayers2 = repository.getPrayers();

        expect(identical(prayers1, prayers2), isTrue);
      });
    });

    group('getAllMysteries', () {
      test('returns 20 mysteries', () {
        final mysteries = repository.getAllMysteries();

        expect(mysteries.length, equals(20));
      });

      test('returns all 4 mystery sets', () {
        final mysteries = repository.getAllMysteries();

        final joyfulCount = mysteries
            .where((m) => m.mysterySet == MysterySet.joyful)
            .length;
        final sorrowfulCount = mysteries
            .where((m) => m.mysterySet == MysterySet.sorrowful)
            .length;
        final gloriousCount = mysteries
            .where((m) => m.mysterySet == MysterySet.glorious)
            .length;
        final luminousCount = mysteries
            .where((m) => m.mysterySet == MysterySet.luminous)
            .length;

        expect(joyfulCount, equals(5));
        expect(sorrowfulCount, equals(5));
        expect(gloriousCount, equals(5));
        expect(luminousCount, equals(5));
      });

      test('each set has mysteries numbered 1-5', () {
        final mysteries = repository.getAllMysteries();

        for (final set in MysterySet.values) {
          final setMysteries = mysteries
              .where((m) => m.mysterySet == set)
              .toList();
          final numbers = setMysteries.map((m) => m.number).toList()..sort();

          expect(numbers, equals([1, 2, 3, 4, 5]));
        }
      });

      test('each mystery has required fields', () {
        final mysteries = repository.getAllMysteries();

        for (final mystery in mysteries) {
          expect(mystery.id, isNotEmpty);
          expect(mystery.name, isNotEmpty);
          expect(mystery.fruit, isNotEmpty);
          expect(mystery.scripture, isNotEmpty);
          expect(mystery.description, isNotEmpty);
        }
      });

      test('caching returns same list on second call', () {
        final mysteries1 = repository.getAllMysteries();
        final mysteries2 = repository.getAllMysteries();

        expect(identical(mysteries1, mysteries2), isTrue);
      });
    });

    group('getMysteries', () {
      test('returns 5 mysteries for joyful set', () {
        final mysteries = repository.getMysteries(MysterySet.joyful);

        expect(mysteries.length, equals(5));
        expect(
          mysteries.every((m) => m.mysterySet == MysterySet.joyful),
          isTrue,
        );
      });

      test('returns 5 mysteries for sorrowful set', () {
        final mysteries = repository.getMysteries(MysterySet.sorrowful);

        expect(mysteries.length, equals(5));
        expect(
          mysteries.every((m) => m.mysterySet == MysterySet.sorrowful),
          isTrue,
        );
      });

      test('returns 5 mysteries for glorious set', () {
        final mysteries = repository.getMysteries(MysterySet.glorious);

        expect(mysteries.length, equals(5));
        expect(
          mysteries.every((m) => m.mysterySet == MysterySet.glorious),
          isTrue,
        );
      });

      test('returns 5 mysteries for luminous set', () {
        final mysteries = repository.getMysteries(MysterySet.luminous);

        expect(mysteries.length, equals(5));
        expect(
          mysteries.every((m) => m.mysterySet == MysterySet.luminous),
          isTrue,
        );
      });

      test('mysteries are sorted by number', () {
        for (final set in MysterySet.values) {
          final mysteries = repository.getMysteries(set);
          final numbers = mysteries.map((m) => m.number).toList();

          expect(numbers, equals([1, 2, 3, 4, 5]));
        }
      });

      test('first mystery in each set has number 1', () {
        for (final set in MysterySet.values) {
          final mysteries = repository.getMysteries(set);

          expect(mysteries.first.number, equals(1));
        }
      });

      test('last mystery in each set has number 5', () {
        for (final set in MysterySet.values) {
          final mysteries = repository.getMysteries(set);

          expect(mysteries.last.number, equals(5));
        }
      });

      test('returns expected joyful mysteries', () {
        final mysteries = repository.getMysteries(MysterySet.joyful);

        expect(mysteries[0].name, contains('Annunciation'));
        expect(mysteries[1].name, contains('Visitation'));
        expect(mysteries[2].name, contains('Nativity'));
        expect(mysteries[3].name, contains('Presentation'));
        expect(mysteries[4].name, contains('Finding'));
      });

      test('returns expected sorrowful mysteries', () {
        final mysteries = repository.getMysteries(MysterySet.sorrowful);

        expect(mysteries[0].name, contains('Agony'));
        expect(mysteries[1].name, contains('Scourging'));
        expect(mysteries[2].name, contains('Crowning'));
        expect(mysteries[3].name, contains('Carrying'));
        expect(mysteries[4].name, contains('Crucifixion'));
      });

      test('returns expected glorious mysteries', () {
        final mysteries = repository.getMysteries(MysterySet.glorious);

        expect(mysteries[0].name, contains('Resurrection'));
        expect(mysteries[1].name, contains('Ascension'));
        expect(mysteries[2].name, contains('Holy Spirit'));
        expect(mysteries[3].name, contains('Assumption'));
        expect(mysteries[4].name, contains('Coronation'));
      });

      test('returns expected luminous mysteries', () {
        final mysteries = repository.getMysteries(MysterySet.luminous);

        expect(mysteries[0].name, contains('Baptism'));
        expect(mysteries[1].name, contains('Cana'));
        expect(mysteries[2].name, contains('Proclamation'));
        expect(mysteries[3].name, contains('Transfiguration'));
        expect(mysteries[4].name, contains('Eucharist'));
      });
    });

    group('getMysteryForDay', () {
      test('returns joyful for Monday (1)', () {
        final set = repository.getMysteryForDay(1);
        expect(set, equals(MysterySet.joyful));
      });

      test('returns sorrowful for Tuesday (2)', () {
        final set = repository.getMysteryForDay(2);
        expect(set, equals(MysterySet.sorrowful));
      });

      test('returns glorious for Wednesday (3)', () {
        final set = repository.getMysteryForDay(3);
        expect(set, equals(MysterySet.glorious));
      });

      test('returns luminous for Thursday (4)', () {
        final set = repository.getMysteryForDay(4);
        expect(set, equals(MysterySet.luminous));
      });

      test('returns sorrowful for Friday (5)', () {
        final set = repository.getMysteryForDay(5);
        expect(set, equals(MysterySet.sorrowful));
      });

      test('returns joyful for Saturday (6)', () {
        final set = repository.getMysteryForDay(6);
        expect(set, equals(MysterySet.joyful));
      });

      test('returns glorious for Sunday (7)', () {
        final set = repository.getMysteryForDay(7);
        expect(set, equals(MysterySet.glorious));
      });

      test('handles all weekday values', () {
        for (int i = 1; i <= 7; i++) {
          final set = repository.getMysteryForDay(i);
          expect(MysterySet.values, contains(set));
        }
      });
    });

    group('getMysteryForToday', () {
      test('returns a valid mystery set', () {
        final set = repository.getMysteryForToday();

        expect(MysterySet.values, contains(set));
      });

      test('returns consistent set for same date', () {
        // Both calls should return the same result (today's set)
        final set1 = repository.getMysteryForToday();
        final set2 = repository.getMysteryForToday();

        expect(set1, equals(set2));
      });
    });

    group('clearCache', () {
      test('clears prayers cache', () {
        // Populate cache
        final prayers1 = repository.getPrayers();
        repository.clearCache();

        // After clearing, should still return prayers (reloaded)
        final prayers2 = repository.getPrayers();
        expect(prayers2, isNotEmpty);
        expect(prayers1.length, equals(prayers2.length));
      });

      test('clears mysteries cache', () {
        // Populate cache
        final mysteries1 = repository.getAllMysteries();
        repository.clearCache();

        // After clearing, should still return mysteries (reloaded)
        final mysteries2 = repository.getAllMysteries();
        expect(mysteries2.length, equals(20));
        expect(mysteries1.length, equals(mysteries2.length));
      });

      test('does not throw when called multiple times', () {
        expect(() {
          repository.clearCache();
          repository.clearCache();
          repository.clearCache();
        }, returnsNormally);
      });

      test('returns new instances after clear', () {
        final prayers1 = repository.getPrayers();
        final mysteries1 = repository.getAllMysteries();

        repository.clearCache();

        final prayers2 = repository.getPrayers();
        final mysteries2 = repository.getAllMysteries();

        // Should be different instances
        expect(identical(prayers1, prayers2), isFalse);
        expect(identical(mysteries1, mysteries2), isFalse);
      });
    });

    group('Integration', () {
      test('can get prayers and mysteries together', () {
        final prayers = repository.getPrayers();
        final mysteries = repository.getMysteries(MysterySet.joyful);

        expect(prayers, isNotEmpty);
        expect(mysteries.length, equals(5));
      });

      test('all mystery sets can be retrieved', () {
        final allMysteries = <Mystery>[];

        for (final set in MysterySet.values) {
          allMysteries.addAll(repository.getMysteries(set));
        }

        expect(allMysteries.length, equals(20));
      });

      test('prayers and mysteries have no ID collisions', () {
        final prayers = repository.getPrayers();
        final mysteries = repository.getAllMysteries();

        final prayerIds = prayers.map((p) => p.id).toSet();
        final mysteryIds = mysteries.map((m) => m.id).toSet();

        final intersection = prayerIds.intersection(mysteryIds);
        expect(intersection, isEmpty);
      });
    });
  });
}
