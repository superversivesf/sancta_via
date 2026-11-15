// Unit tests for `lib/src/utils/face_crop.dart` (face-centered thumb crops).
//
// The pipeline previously center-cropped every image vertically, which cut
// heads off tall portraits whose faces sit below the geometric middle
// (St Hugh of Lincoln: face at ~72% of a 336x768 painting). The crop now
// anchors on the detected face when one is found, top-biased otherwise.
import 'package:flutter_test/flutter_test.dart';

import '../../lib/src/utils/face_crop.dart';

// The Vision-framework result for hugh-of-lincoln's original (336x768),
// converted to top-left origin (Vision natively reports bottom-left).
const FaceRect kHughFace = FaceRect(
  x: 0.482448935508728,
  y: 0.25646742060780525,
  w: 0.11373283714056015,
  h: 0.04975811764597893,
);

void main() {
  group('faceCropRect', () {
    test('faces below center pull the crop down to keep the head', () {
      final CropRect rect = faceCropRect(
        imageWidth: 336,
        imageHeight: 768,
        faces: const <FaceRect>[kHughFace],
      );
      final double faceAbsCenter = (kHughFace.y + kHughFace.h / 2) * 768;
      expect(rect.height, 336);
      expect(rect.y, inInclusiveRange(0, 768 - 336));
      // The face center lands in the UPPER HALF of the crop (target ~35%,
      // with bottom-clamped faces tolerating up to 45%).
      final double faceInCrop = faceAbsCenter - rect.y;
      expect(
        faceInCrop,
        inInclusiveRange(0.05 * rect.height, 0.45 * rect.height),
        reason: 'the detected face must read in the upper part of the thumb',
      );
      final double faceTop = kHughFace.y * 768;
      final double faceBottom = (kHughFace.y + kHughFace.h) * 768;
      expect(rect.y, lessThanOrEqualTo(faceTop + 1));
      expect(rect.y + rect.height, greaterThanOrEqualTo(faceBottom - 1));
      final double faceCenterX = (kHughFace.x + kHughFace.w / 2) * 336;
      final double cropCenterX = rect.x + rect.width / 2;
      expect(cropCenterX, inInclusiveRange(faceCenterX - 40, faceCenterX + 40));
    });

    test('faces already near the top stay in place (no negative crops)', () {
      const FaceRect highFace = FaceRect(
        x: 0.4,
        y: 0.08,
        w: 0.2,
        h: 0.12,
      );
      final CropRect rect = faceCropRect(
        imageWidth: 640,
        imageHeight: 962,
        faces: const <FaceRect>[highFace],
      );
      expect(rect.y, 0, reason: 'a top face should not push the crop above 0');
      expect(rect.height, 640);
      final double faceBottom = (highFace.y + highFace.h) * 962;
      expect(rect.y + rect.height, greaterThanOrEqualTo(faceBottom - 1));
    });

    test('no faces fall back to a top-biased square (not the old center crop)',
        () {
      final CropRect rect = faceCropRect(
        imageWidth: 336,
        imageHeight: 768,
        faces: const <FaceRect>[],
      );
      expect(rect.height, 336);
      expect(rect.y, inInclusiveRange(0, (0.15 * (768 - 336)).round()));
      expect(rect.width, 336);
    });

    test('wider-than-tall images crop horizontally around the face', () {
      const FaceRect face = FaceRect(x: 0.7, y: 0.2, w: 0.1, h: 0.1);
      final CropRect rect = faceCropRect(
        imageWidth: 1000,
        imageHeight: 500,
        faces: const <FaceRect>[face],
      );
      expect(rect.height, 500);
      expect(rect.x, inInclusiveRange(0, 1000 - 500));
      final double faceCenterX = (face.x + face.w / 2) * 1000;
      final double cropCenterX = rect.x + rect.width / 2;
      expect(cropCenterX, inInclusiveRange(faceCenterX - 80, faceCenterX + 80));
    });

    test('clamps when the face sits at the very bottom edge', () {
      const FaceRect bottomFace = FaceRect(x: 0.5, y: 0.95, w: 0.08, h: 0.04);
      final CropRect rect = faceCropRect(
        imageWidth: 336,
        imageHeight: 768,
        faces: const <FaceRect>[bottomFace],
      );
      expect(rect.y, 768 - 336, reason: 'clamped to the image bottom');
      expect(rect.y + rect.height, 768);
    });
  });
}
