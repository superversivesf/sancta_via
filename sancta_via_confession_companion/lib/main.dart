import 'package:flutter/material.dart';
import 'package:sancta_via_shared_ui/sancta_via_shared_ui.dart';
import 'package:sancta_via_liturgical_calendar_riverpod/sancta_via_liturgical_calendar_riverpod.dart';

import 'config/routes.dart';
import 'config/constants.dart';
import 'providers/confession_app_settings_provider.dart';

void main() {
  runApp(const ProviderScope(child: ConfessionCompanionApp()));
}

class ConfessionCompanionApp extends ConsumerWidget {
  const ConfessionCompanionApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final liturgicalData = ref.watch(currentLiturgicalDayProvider);
    final themeMode = ref.watch(themeModeProvider);
    final colorIntensity = ref.watch(colorIntensityProvider);
    final effectiveTextScale = ref.watch(confessionEffectiveTextScaleProvider);

    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: liturgicalData != null
          ? AppTheme.lightTheme(
              LiturgicalColor.fromString(liturgicalData.celebration.color),
              colorIntensity,
            )
          : AppTheme.lightTheme(null, colorIntensity),
      darkTheme: liturgicalData != null
          ? AppTheme.darkTheme(
              LiturgicalColor.fromString(liturgicalData.celebration.color),
              colorIntensity,
            )
          : AppTheme.darkTheme(null, colorIntensity),
      themeMode: themeMode,
      routerConfig: appRouter,
      builder: (BuildContext context, Widget? child) =>
          textScaleClampedBuilder(effectiveTextScale, context, child),
    );
  }
}
