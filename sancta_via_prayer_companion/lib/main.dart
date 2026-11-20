import 'package:flutter/material.dart';
import 'package:sancta_via_liturgical_calendar_riverpod/sancta_via_liturgical_calendar_riverpod.dart';
import 'package:sancta_via_shared_ui/sancta_via_shared_ui.dart';

import 'config/routes.dart';
import 'providers/prayer_app_settings_provider.dart';

void main() {
  runApp(const ProviderScope(child: PrayerCompanionApp()));
}

class PrayerCompanionApp extends ConsumerWidget {
  const PrayerCompanionApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch liturgical color for dynamic theming
    final currentLiturgicalColor = ref.watch(currentLiturgicalColorProvider);

    // Watch user preferences
    final themeMode = ref.watch(themeModeProvider);
    final colorIntensity = ref.watch(colorIntensityProvider);
    final effectiveTextScale = ref.watch(prayerAppSettingsProvider).effectiveTextScaleFactor;

    // Parse liturgical color from string
    final liturgicalColor = currentLiturgicalColor != null
        ? LiturgicalColor.fromString(currentLiturgicalColor)
        : null;

    return MaterialApp.router(
      title: 'Prayer Companion',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme(liturgicalColor, colorIntensity),
      darkTheme: AppTheme.darkTheme(liturgicalColor, colorIntensity),
      themeMode: themeMode,
      routerConfig: appRouter,
      builder: (BuildContext context, Widget? child) =>
          textScaleClampedBuilder(effectiveTextScale, context, child),
    );
  }
}
