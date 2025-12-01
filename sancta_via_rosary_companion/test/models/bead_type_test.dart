import 'package:flutter_test/flutter_test.dart';
import 'package:sancta_via_rosary_companion/models/bead_type.dart';

void main() {
  group('BeadType', () {
    test('should have correct number of values', () {
      expect(BeadType.values.length, 7);
    });

    test('should have correct string values', () {
      expect(BeadType.ourFather.value, 'our_father');
      expect(BeadType.hailMary.value, 'hail_mary');
      expect(BeadType.gloryBe.value, 'glory_be');
      expect(BeadType.apostlesCreed.value, 'apostles_creed');
      expect(BeadType.hailHolyQueen.value, 'hail_holy_queen');
      expect(BeadType.signOfCross.value, 'sign_of_cross');
      expect(BeadType.finalPrayer.value, 'final_prayer');
    });

    test('fromString should return correct BeadType', () {
      expect(BeadType.fromString('our_father'), BeadType.ourFather);
      expect(BeadType.fromString('hail_mary'), BeadType.hailMary);
      expect(BeadType.fromString('glory_be'), BeadType.gloryBe);
      expect(BeadType.fromString('apostles_creed'), BeadType.apostlesCreed);
      expect(BeadType.fromString('hail_holy_queen'), BeadType.hailHolyQueen);
      expect(BeadType.fromString('sign_of_cross'), BeadType.signOfCross);
      expect(BeadType.fromString('final_prayer'), BeadType.finalPrayer);
    });

    test('fromString should return default hailMary for unknown string', () {
      expect(BeadType.fromString('unknown'), BeadType.hailMary);
      expect(BeadType.fromString(''), BeadType.hailMary);
    });
  });
}