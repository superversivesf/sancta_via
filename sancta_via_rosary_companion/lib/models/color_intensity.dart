import 'package:flutter/material.dart';

enum ColorIntensity {
  normal('Normal'),
  vivid('Vivid'),
  subdued('Subdued');

  const ColorIntensity(this.displayName);

  final String displayName;

  factory ColorIntensity.fromString(String value) {
    return ColorIntensity.values.firstWhere(
      (type) => type.displayName.toLowerCase() == value.toLowerCase(),
      orElse: () => ColorIntensity.normal,
    );
  }

  Color applyToColor(Color color) {
    switch (this) {
      case ColorIntensity.normal:
        return color;
      case ColorIntensity.vivid:
        return color.withValues(alpha: 1.0);
      case ColorIntensity.subdued:
        return color.withValues(alpha: 0.6);
    }
  }
}
