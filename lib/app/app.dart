import 'package:flutter/material.dart';
import 'package:sancta_via_liturgical_calendar_riverpod/sancta_via_liturgical_calendar_riverpod.dart';
import 'package:sancta_via_shared_ui/sancta_via_shared_ui.dart';
import '../config/routes.dart';

class LiturgicalCalendarApp extends ConsumerWidget {
  const LiturgicalCalendarApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch liturgical color for dynamic theming from riverpod package
    final liturgicalColorString = ref.watch(currentLiturgicalColorProvider);
    
    // Watch shared UI theme providers
    final themeMode = ref.watch(themeModeProvider);
    
    // Watch user preferences
    final colorIntensity = ref.watch(colorIntensityProvider);
    
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
    );
  }
}