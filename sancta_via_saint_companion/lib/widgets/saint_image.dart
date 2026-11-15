import 'package:flutter/material.dart';
import 'package:saint_data/saint_data.dart';

/// A saint's bundled thumbnail with a graceful offline fallback.
///
/// Renders `Image.asset(..., package: 'saint_data')` when [Saint.thumbAsset]
/// is declared, and the gray person-icon placeholder otherwise. A declared
/// thumb whose file is missing from the bundle (Task 6 carry-forward: some
/// 404'd at build time) surfaces the same placeholder via the asset load
/// errorBuilder — saint imagery is never fetched over the network.
class SaintImage extends StatelessWidget {
  const SaintImage({
    required this.saint,
    this.width,
    this.height,
    this.borderRadius,
    this.showPlaceholderIfMissing = true,
    super.key,
  });

  /// The saint whose thumb to render.
  final Saint saint;

  /// Rendered width; unbounded when null.
  final double? width;

  /// Rendered height; unbounded when null.
  final double? height;

  /// Rounded corners applied to both the image and the placeholder.
  final BorderRadius? borderRadius;

  /// When true (the default), a saint with no bundled thumb — or a thumb
  /// that fails to load — shows the gray person-icon placeholder. List rows
  /// pass false: the box is simply left OUT when there is no image.
  final bool showPlaceholderIfMissing;

  /// Gray person-icon placeholder shown when no thumb is bundled or the
  /// bundled file fails to load.
  Widget _buildPlaceholder() {
    if (!showPlaceholderIfMissing) {
      return const SizedBox.shrink();
    }
    return Container(
      key: const Key('saint_image_placeholder'),
      width: width,
      height: height,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFE0E0E0),
        borderRadius: borderRadius,
      ),
      child: const Icon(
        Icons.person_outline,
        size: 28,
        color: Color(0xFF9E9E9E),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String? thumbAsset = saint.thumbAsset;
    if (thumbAsset == null) {
      return _buildPlaceholder();
    }
    final Widget image = Image.asset(
      thumbAsset,
      package: 'saint_data',
      fit: BoxFit.cover,
      // Tall portrait paintings are the dominant thumb geometry; a plain
      // center-crop removes the face. Anchoring to the TOP keeps heads in
      // frame (the saint-for-that site's June fix, mirrored here).
      alignment: Alignment.topCenter,
      width: width,
      height: height,
      errorBuilder:
          (BuildContext context, Object error, StackTrace? stackTrace) =>
              _buildPlaceholder(),
    );
    final BorderRadius? corners = borderRadius;
    if (corners == null) {
      return image;
    }
    return ClipRRect(borderRadius: corners, child: image);
  }
}
