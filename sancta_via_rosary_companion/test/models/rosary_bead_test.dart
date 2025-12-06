import 'package:flutter_test/flutter_test.dart';
import 'package:sancta_via_rosary_companion/models/rosary_bead.dart';
import 'package:sancta_via_rosary_companion/models/bead_type.dart';

void main() {
  group('RosaryBead', () {
    const rosaryBead = RosaryBead(
      id: 'bead_001',
      type: BeadType.hailMary,
      decadePosition: 3,
      prayerText: 'Hail Mary, full of grace...',
      audioUrl: 'audio/hail_mary.mp3',
    );

    test('should create RosaryBead with correct properties', () {
      expect(rosaryBead.id, 'bead_001');
      expect(rosaryBead.type, BeadType.hailMary);
      expect(rosaryBead.decadePosition, 3);
      expect(rosaryBead.prayerText, 'Hail Mary, full of grace...');
      expect(rosaryBead.audioUrl, 'audio/hail_mary.mp3');
    });

    test('can create RosaryBead without audioUrl', () {
      const beadWithoutAudio = RosaryBead(
        id: 'bead_002',
        type: BeadType.ourFather,
        decadePosition: 0,
        prayerText: 'Our Father, who art in heaven...',
      );
      expect(beadWithoutAudio.audioUrl, isNull);
    });

    test('isHailMary should identify hail mary beads', () {
      expect(rosaryBead.isHailMary, isTrue);
      expect(
        const RosaryBead(
          id: 'bead_003',
          type: BeadType.ourFather,
          decadePosition: 0,
          prayerText: 'Our Father...',
        ).isHailMary,
        isFalse,
      );
    });

    test('isOurFather should identify our father beads', () {
      expect(
        const RosaryBead(
          id: 'bead_004',
          type: BeadType.ourFather,
          decadePosition: 0,
          prayerText: 'Our Father...',
        ).isOurFather,
        isTrue,
      );
      expect(rosaryBead.isOurFather, isFalse);
    });

    test('isGloryBe should identify glory be beads', () {
      expect(
        const RosaryBead(
          id: 'bead_005',
          type: BeadType.gloryBe,
          decadePosition: 0,
          prayerText: 'Glory be to the Father...',
        ).isGloryBe,
        isTrue,
      );
      expect(rosaryBead.isGloryBe, isFalse);
    });

    test('isApostlesCreed should identify apostles creed beads', () {
      expect(
        const RosaryBead(
          id: 'bead_006',
          type: BeadType.apostlesCreed,
          decadePosition: 0,
          prayerText: 'I believe in God...',
        ).isApostlesCreed,
        isTrue,
      );
      expect(rosaryBead.isApostlesCreed, isFalse);
    });

    test('isHailHolyQueen should identify hail holy queen beads', () {
      expect(
        const RosaryBead(
          id: 'bead_007',
          type: BeadType.hailHolyQueen,
          decadePosition: 0,
          prayerText: 'Hail, holy Queen...',
        ).isHailHolyQueen,
        isTrue,
      );
      expect(rosaryBead.isHailHolyQueen, isFalse);
    });

    test('copyWith should create new instance with updated properties', () {
      final copiedBead = rosaryBead.copyWith(
        decadePosition: 5,
        prayerText: 'Updated prayer text',
      );

      expect(copiedBead.id, rosaryBead.id);
      expect(copiedBead.type, rosaryBead.type);
      expect(copiedBead.decadePosition, 5);
      expect(copiedBead.prayerText, 'Updated prayer text');
      expect(copiedBead.audioUrl, rosaryBead.audioUrl);
    });

    test('equality should compare id, type, and decadePosition', () {
      const bead1 = RosaryBead(
        id: 'bead_001',
        type: BeadType.hailMary,
        decadePosition: 3,
        prayerText: 'Hail Mary...',
      );
      const bead2 = RosaryBead(
        id: 'bead_001',
        type: BeadType.hailMary,
        decadePosition: 3,
        prayerText: 'Different text',
      );
      const bead3 = RosaryBead(
        id: 'bead_002',
        type: BeadType.hailMary,
        decadePosition: 3,
        prayerText: 'Hail Mary...',
      );

      expect(bead1, bead2);
      expect(bead1, isNot(bead3));
    });

    test('hashCode should be consistent for equal objects', () {
      const bead1 = RosaryBead(
        id: 'bead_001',
        type: BeadType.hailMary,
        decadePosition: 3,
        prayerText: 'Hail Mary...',
      );
      const bead2 = RosaryBead(
        id: 'bead_001',
        type: BeadType.hailMary,
        decadePosition: 3,
        prayerText: 'Different text',
      );

      expect(bead1.hashCode, bead2.hashCode);
    });
  });
}
