import 'package:flutter/material.dart';

/// Builder wrapper for `MaterialApp.builder` that applies the house text-scale
/// composition: a `MediaQuery.withClampedTextScaling` clamp (0.8–2.0) plus the
/// app's effective text scale applied to the whole tree.
///
/// Used by every console app so large system text (iOS "Larger Text",
/// Android "Font size") is honored and bounded consistently; three apps
/// previously scaled only individual text widgets and overflowed at
/// 150–200% system settings (2026-11-20 consult, copilot #3).
///
/// Use from a `builder:` callback, reading the app's effective scale first:
/// `builder: (context, child) => textScaleClampedBuilder(effectiveScale, child)`.
Widget textScaleClampedBuilder(
  double effectiveScale,
  BuildContext context,
  Widget? child,
) {
  return MediaQuery.withClampedTextScaling(
    minScaleFactor: 0.8,
    maxScaleFactor: 2.0,
    child: MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(effectiveScale)),
      child: child!,
    ),
  );
}
