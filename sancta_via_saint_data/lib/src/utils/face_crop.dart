// Face-centered crop math for saint thumbnails (Task: heads-in-frame).
//
// The original thumb pipeline center-cropped every image vertically
// (`y = (height - square) ~/ 2`), which decapitated tall portraits whose
// faces sit below the geometric middle. The crop now anchors on the face
// detected by the macOS Vision framework (via tool/facedetect.swift);
// images with no detected face fall back to a top-biased square, because
// painted portraits almost always put the head in the upper third.
import 'dart:math' as math;

/// A detected face rectangle, normalized to the image dimensions
/// (Vision's own coordinate convention).
class FaceRect {
  const FaceRect({
    required this.x,
    required this.y,
    required this.w,
    required this.h,
  });

  final double x;
  final double y;
  final double w;
  final double h;

  double get centerX => x + w / 2;
  double get centerY => y + h / 2;
}

/// The crop rectangle, in absolute pixels.
class CropRect {
  const CropRect({required this.x, required this.y, required this.size});

  final int x;
  final int y;
  final int size;

  double get height => size.toDouble();
  double get width => size.toDouble();
}

/// How far down the image the fallback (no-face) crop starts: 15% of the
/// slack keeps empty margins above the head while still biasing toward the
/// subject. (The old pipeline anchored at 50%, the decapitation bug.)
const double fallbackTopBias = 0.15;

/// Where in the crop the face center should land, as a fraction of the
/// crop edge: upper third leaves headroom for mitres, halos, and hair.
const double _faceTargetFraction = 0.35;

/// Computes the square crop rect for an image given its size and the
/// detected faces (may be empty). Picks the LARGEST face, centers the crop
/// on it horizontally, and vertically places its center at ~35% of the
/// crop edge, so the face reads in the upper middle of the 1:1 thumb.
CropRect faceCropRect({
  required int imageWidth,
  required int imageHeight,
  required List<FaceRect> faces,
}) {
  final int square = math.min(imageWidth, imageHeight);

  if (faces.isEmpty) {
    return CropRect(
      x: (imageWidth - square) ~/ 2,
      y: ((imageHeight - square) * fallbackTopBias).round(),
      size: square,
    );
  }

  // Largest detected face wins (the subject's, not a bystander's).
  FaceRect best = faces.first;
  for (final FaceRect face in faces.skip(1)) {
    if (face.w * face.h > best.w * best.h) {
      best = face;
    }
  }
  final double faceCenterX = best.centerX * imageWidth;
  final double faceCenterY = best.centerY * imageHeight;

  int x = (faceCenterX - square / 2).round();
  x = x.clamp(0, math.max(0, imageWidth - square));

  int y = (faceCenterY - square * _faceTargetFraction).round();
  y = y.clamp(0, math.max(0, imageHeight - square));

  // Keep the whole detected face inside the crop where the geometry
  // allows (a face taller than the square can't fully fit).
  final double faceTop = best.y * imageHeight;
  final double faceBottom = (best.y + best.h) * imageHeight;
  if (faceTop - 12 >= 0 && y > faceTop - 12) {
    y = (faceTop - 12).round().clamp(0, math.max(0, imageHeight - square));
  }
  if (faceBottom + 12 <= imageHeight &&
      y + square < faceBottom + 12) {
    y = (faceBottom + 12 - square)
        .round()
        .clamp(0, math.max(0, imageHeight - square));
  }

  return CropRect(x: x, y: y, size: square);
}
