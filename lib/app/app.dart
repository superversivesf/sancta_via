import 'package:flutter/material.dart';
import 'package:sancta_via_liturgical_calendar_riverpod/sancta_via_liturgical_calendar_riverpod.dart';
import 'package:sancta_via_shared_ui/sancta_via_shared_ui.dart';
import '../config/routes.dart';
import '../providers/calendar_providers.dart' as local_providers;

class LiturgicalCalendarApp extends ConsumerWidget {
  const LiturgicalCalendarApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch liturgical color for dynamic theming - now based on selected date!
    final liturgicalColorString = ref.watch(local_providers.selectedDateLiturgicalColorProvider);
    
    // Watch shared UI theme providers
    final themeMode = ref.watch(themeModeProvider);
    
    // Watch user preferences
    final colorIntensity = ref.watch(colorIntensityProvider);
    
    // Watch font size setting for text scaling
    final textScale = ref.watch(effectiveTextScaleProvider);
    
    // Parse liturgical color from string
    final liturgicalColor = liturgicalColorString != null 
        ? LiturgicalColor.fromString(liturgicalColorString)
        : null;
    
    // Get themes from shared UI system
    final lightTheme = AppTheme.lightTheme(liturgicalColor, colorIntensity);
    final darkTheme = AppTheme.darkTheme(liturgicalColor, colorIntensity);
    
    return MaterialApp.router(
      title: 'Sancta Via Calendar',
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: themeMode,
      routerConfig: appRouter,
      debugShowCheckedModeBanner: false,
      // Apply user's font size setting to all text throughout the app
      builder: (context, child) {
        return MediaQuery.withClampedTextScaling(
          minScaleFactor: 0.8,
          maxScaleFactor: 2.0,
          child: MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(textScale),
            ),
            child: child!,
          ),
        );
      },
    );
  }
}