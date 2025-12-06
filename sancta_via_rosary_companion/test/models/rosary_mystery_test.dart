import 'package:flutter_test/flutter_test.dart';
import 'package:sancta_via_rosary_companion/models/rosary_mystery.dart';
import 'package:sancta_via_rosary_companion/models/mystery_type.dart';

void main() {
  group('RosaryMystery', () {
    const rosaryMystery = RosaryMystery(
      id: 'joyful-1',
      type: MysteryType.joyful,
      mysteryNumber: 1,
      title: 'The Annunciation',
      description: 'The Angel Gabriel announces...',
      scriptureText: 'Hail, full of grace (Luke 1:28)',
      meditationText: 'We pray for humility...',
    );

    test('should create RosaryMystery with correct properties', () {
      expect(rosaryMystery.id, 'joyful-1');
      expect(rosaryMystery.type, MysteryType.joyful);
      expect(rosaryMystery.mysteryNumber, 1);
      expect(rosaryMystery.title, 'The Annunciation');
      expect(rosaryMystery.description, 'The Angel Gabriel announces...');
      expect(rosaryMystery.scriptureText, 'Hail, full of grace (Luke 1:28)');
      expect(rosaryMystery.meditationText, 'We pray for humility...');
    });

    test('isFirstMystery should identify first mysteries', () {
      expect(
        const RosaryMystery(
          id: 'sorrowful-1',
          type: MysteryType.sorrowful,
          mysteryNumber: 1,
          title: 'First',
          description: 'Desc',
          scriptureText: 'Text',
          meditationText: 'Meditation',
        ).isFirstMystery,
        isTrue,
      );
      expect(rosaryMystery.isFirstMystery, isTrue);
    });

    test('isLastMystery should identify last mysteries', () {
      expect(
        const RosaryMystery(
          id: 'glorious-5',
          type: MysteryType.glorious,
          mysteryNumber: 5,
          title: 'Last',
          description: 'Desc',
          scriptureText: 'Text',
          meditationText: 'Meditation',
        ).isLastMystery,
        isTrue,
      );
      expect(rosaryMystery.isLastMystery, isFalse);
    });

    test('typeDisplayName should return formatted display name', () {
      const joyfulMystery = RosaryMystery(
        id: 'joyful-2',
        type: MysteryType.joyful,
        mysteryNumber: 2,
        title: 'Mystery 2',
        description: 'Description 2',
        scriptureText: 'Scripture 2',
        meditationText: 'Meditation 2',
      );

      expect(joyfulMystery.typeDisplayName, 'Joyful Mysteries');
      expect(
        const RosaryMystery(
          id: 'sorrowful-2',
          type: MysteryType.sorrowful,
          mysteryNumber: 2,
          title: 'Mystery',
          description: 'Desc',
          scriptureText: 'Text',
          meditationText: 'Meditation',
        ).typeDisplayName,
        'Sorrowful Mysteries',
      );
    });

    test('mysteryDisplayTitle should return formatted title with number', () {
      expect(rosaryMystery.mysteryDisplayTitle, '1. The Annunciation');
      expect(
        const RosaryMystery(
          id: 'luminous-3',
          type: MysteryType.luminous,
          mysteryNumber: 3,
          title: 'Proclamation',
          description: 'Desc',
          scriptureText: 'Text',
          meditationText: 'Meditation',
        ).mysteryDisplayTitle,
        '3. Proclamation',
      );
    });

    test('copyWith should create new instance with updated properties', () {
      final copiedMystery = rosaryMystery.copyWith(
        mysteryNumber: 2,
        title: 'Updated Title',
      );

      expect(copiedMystery.id, rosaryMystery.id);
      expect(copiedMystery.type, rosaryMystery.type);
      expect(copiedMystery.mysteryNumber, 2);
      expect(copiedMystery.title, 'Updated Title');
      expect(copiedMystery.description, rosaryMystery.description);
      expect(copiedMystery.scriptureText, rosaryMystery.scriptureText);
      expect(copiedMystery.meditationText, rosaryMystery.meditationText);
    });

    test('equality should compare id, type, and mystery number', () {
      const mystery1 = RosaryMystery(
        id: 'joyful-1',
        type: MysteryType.joyful,
        mysteryNumber: 1,
        title: 'Mystery 1',
        description: 'Desc 1',
        scriptureText: 'Text 1',
        meditationText: 'Meditation 1',
      );
      const mystery2 = RosaryMystery(
        id: 'joyful-1',
        type: MysteryType.joyful,
        mysteryNumber: 1,
        title: 'Different Title',
        description: 'Desc 2',
        scriptureText: 'Text 2',
        meditationText: 'Meditation 2',
      );
      const mystery3 = RosaryMystery(
        id: 'joyful-2',
        type: MysteryType.joyful,
        mysteryNumber: 2,
        title: 'Mystery 1',
        description: 'Desc 1',
        scriptureText: 'Text 1',
        meditationText: 'Meditation 1',
      );

      expect(mystery1, mystery2);
      expect(mystery1, isNot(mystery3));
    });

    test('hashCode should be consistent for equal objects', () {
      const mystery1 = RosaryMystery(
        id: 'joyful-1',
        type: MysteryType.joyful,
        mysteryNumber: 1,
        title: 'First Mystery',
        description: 'First description',
        scriptureText: 'First text',
        meditationText: 'First meditation',
      );
      const mystery2 = RosaryMystery(
        id: 'joyful-1',
        type: MysteryType.joyful,
        mysteryNumber: 1,
        title: 'Different Title',
        description: 'Different description',
        scriptureText: 'Different text',
        meditationText: 'Different meditation',
      );

      expect(mystery1.hashCode, mystery2.hashCode);
    });
  });
}
