import 'package:flutter/material.dart';
import 'package:liturgical_calendar_riverpod/liturgical_calendar_riverpod.dart';
import 'package:shared_ui/shared_ui.dart';
import '../config/routes.dart';
import '../screens/home/home_screen.dart';

class LiturgicalCalendarApp extends ConsumerWidget {
  const LiturgicalCalendarApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch liturgical color for dynamic theming
    final liturgicalColorString = ref.watch(currentLiturgicalColorProvider);
    
    // Watch user preferences
    final themeMode = ref.watch(themeModeProvider);
    final colorIntensity = ref.watch(colorIntensityProvider);
    
    // Parse liturgical color from string
    final liturgicalColor = liturgicalColorString != null 
        ? LiturgicalColor.fromString(liturgicalColorString)
        : null;
    
    return MaterialApp(
      title: 'Sancta Via Calendar',
      theme: AppTheme.lightTheme(liturgicalColor, colorIntensity),
      darkTheme: AppTheme.darkTheme(liturgicalColor, colorIntensity),
      themeMode: themeMode,
      home: const HomeScreen(),
      onGenerateRoute: AppRoutes.generateRoute,
      debugShowCheckedModeBanner: false,
    );
  }
}