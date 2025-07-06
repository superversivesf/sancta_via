import 'package:flutter/material.dart';
import 'package:sancta_via_liturgical_calendar_riverpod/sancta_via_liturgical_calendar_riverpod.dart';
import 'package:sancta_via_shared_ui/sancta_via_shared_ui.dart';

import 'screens/home/home_screen.dart';
import 'screens/settings/settings_screen.dart';
import 'screens/bible_lookup/bible_lookup_screen.dart';
import 'screens/reading_plan/reading_plan_screen.dart';
import 'screens/bible_search/bible_search_screen.dart';
import 'screens/continue_reading/continue_reading_screen.dart';

void main() {
  runApp(const ProviderScope(child: BibleReadingApp()));
}

class BibleReadingApp extends ConsumerWidget {
  const BibleReadingApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch liturgical color for dynamic theming
    final currentLiturgicalColor = ref.watch(currentLiturgicalColorProvider);
    
    // Watch user preferences
    final themeMode = ref.watch(themeModeProvider);
    final colorIntensity = ref.watch(colorIntensityProvider);
    
    // Parse liturgical color from string
    final liturgicalColor = currentLiturgicalColor != null 
        ? LiturgicalColor.fromString(currentLiturgicalColor)
        : null;

    return MaterialApp(
      title: 'Bible Reading App',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme(liturgicalColor, colorIntensity),
      darkTheme: AppTheme.darkTheme(liturgicalColor, colorIntensity),
      themeMode: themeMode,
      home: const HomeScreen(),
      routes: {
        '/settings': (context) => const SettingsScreen(),
        '/bible-lookup': (context) => const BibleLookupScreen(),
        '/reading-plan': (context) => const ReadingPlanScreen(),
        '/bible-search': (context) => const BibleSearchScreen(),
        '/continue-reading': (context) => const ContinueReadingScreen(),
      },
    );
  }
}
