import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// MIGRATION: Now uses unified settings system
import 'confession_app_settings_provider.dart';

// Provider that creates scaled text styles based on user's font size preference
// UPDATED: Now uses the new unified settings system while maintaining the same interface
final textScaleProvider = Provider<TextScaling>((ref) {
  final settings = ref.watch(confessionAppSettingsProvider);
  // Use the effectiveTextScaleFactor for more accurate scaling
  return TextScaling(baseFontSize: settings.fontSize);
});

class TextScaling {
  final double baseFontSize;
  
  // Base font size is 18, so we calculate scale factor from that
  // Clamp the scale factor to prevent extreme sizes
  double get scaleFactor => (baseFontSize / 18.0).clamp(0.67, 1.5);
  
  TextScaling({required this.baseFontSize});
  
  // Scaled text styles - with more conservative scaling for very large text
  TextStyle scaledDisplayLarge(BuildContext context) => 
      (Theme.of(context).textTheme.displayLarge ?? const TextStyle(fontSize: 57))
          .copyWith(fontSize: 57 * (scaleFactor * 0.9)); // Scale down large displays
          
  TextStyle scaledDisplayMedium(BuildContext context) => 
      (Theme.of(context).textTheme.displayMedium ?? const TextStyle(fontSize: 45))
          .copyWith(fontSize: 45 * (scaleFactor * 0.9));
          
  TextStyle scaledDisplaySmall(BuildContext context) => 
      (Theme.of(context).textTheme.displaySmall ?? const TextStyle(fontSize: 36))
          .copyWith(fontSize: 36 * (scaleFactor * 0.95));
          
  TextStyle scaledHeadlineLarge(BuildContext context) => 
      (Theme.of(context).textTheme.headlineLarge ?? const TextStyle(fontSize: 32))
          .copyWith(fontSize: 32 * scaleFactor);
          
  TextStyle scaledHeadlineMedium(BuildContext context) => 
      (Theme.of(context).textTheme.headlineMedium ?? const TextStyle(fontSize: 28))
          .copyWith(fontSize: 28 * scaleFactor);
          
  TextStyle scaledHeadlineSmall(BuildContext context) => 
      (Theme.of(context).textTheme.headlineSmall ?? const TextStyle(fontSize: 24))
          .copyWith(fontSize: 24 * scaleFactor);
          
  TextStyle scaledTitleLarge(BuildContext context) => 
      (Theme.of(context).textTheme.titleLarge ?? const TextStyle(fontSize: 22))
          .copyWith(fontSize: 22 * scaleFactor);
          
  TextStyle scaledTitleMedium(BuildContext context) => 
      (Theme.of(context).textTheme.titleMedium ?? const TextStyle(fontSize: 16))
          .copyWith(fontSize: 16 * scaleFactor);
          
  TextStyle scaledTitleSmall(BuildContext context) => 
      (Theme.of(context).textTheme.titleSmall ?? const TextStyle(fontSize: 14))
          .copyWith(fontSize: 14 * scaleFactor);
          
  TextStyle scaledBodyLarge(BuildContext context) => 
      (Theme.of(context).textTheme.bodyLarge ?? const TextStyle(fontSize: 16))
          .copyWith(fontSize: 16 * scaleFactor);
          
  TextStyle scaledBodyMedium(BuildContext context) => 
      (Theme.of(context).textTheme.bodyMedium ?? const TextStyle(fontSize: 14))
          .copyWith(fontSize: 14 * scaleFactor);
          
  TextStyle scaledBodySmall(BuildContext context) => 
      (Theme.of(context).textTheme.bodySmall ?? const TextStyle(fontSize: 12))
          .copyWith(fontSize: 12 * scaleFactor);
          
  TextStyle scaledLabelLarge(BuildContext context) => 
      (Theme.of(context).textTheme.labelLarge ?? const TextStyle(fontSize: 14))
          .copyWith(fontSize: 14 * scaleFactor);
          
  TextStyle scaledLabelMedium(BuildContext context) => 
      (Theme.of(context).textTheme.labelMedium ?? const TextStyle(fontSize: 12))
          .copyWith(fontSize: 12 * scaleFactor);
          
  TextStyle scaledLabelSmall(BuildContext context) => 
      (Theme.of(context).textTheme.labelSmall ?? const TextStyle(fontSize: 11))
          .copyWith(fontSize: 11 * scaleFactor);
}
