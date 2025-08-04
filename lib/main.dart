import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sancta_via_liturgical_calendar_riverpod/sancta_via_liturgical_calendar_riverpod.dart';
import 'package:sancta_via_shared_ui/sancta_via_shared_ui.dart';

import 'config/routes.dart';
import 'providers/reading_plan_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  runApp(const ProviderScope(child: BibleReadingApp()));
}

class BibleReadingApp extends ConsumerStatefulWidget {
  const BibleReadingApp({super.key});

  @override
  ConsumerState<BibleReadingApp> createState() => _BibleReadingAppState();
}

class _BibleReadingAppState extends ConsumerState<BibleReadingApp> 
    with WidgetsBindingObserver {

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    // When app comes back to foreground, check for daily reset
    if (state == AppLifecycleState.resumed) {
      // ignore: avoid_print
      print('🔆 App resumed from background - checking for daily reset');
      _checkForDailyReset();
    }
  }

  void _checkForDailyReset() {
    // Trigger daily reset check in reading plan provider
    ref.read(readingPlanManagerProvider.notifier).checkAndPerformDailyReset();
  }

  @override
  Widget build(BuildContext context) {
    // Watch liturgical color for dynamic theming
    final currentLiturgicalColor = ref.watch(currentLiturgicalColorProvider);
    
    // Watch user preferences
    final themeMode = ref.watch(themeModeProvider);
    final colorIntensity = ref.watch(colorIntensityProvider);
    
    // Parse liturgical color from string
    final liturgicalColor = currentLiturgicalColor != null 
        ? LiturgicalColor.fromString(currentLiturgicalColor)
        : null;

    return MaterialApp.router(
      title: 'Bible Reading App',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme(liturgicalColor, colorIntensity),
      darkTheme: AppTheme.darkTheme(liturgicalColor, colorIntensity),
      themeMode: themeMode,
      routerConfig: appRouter,
    );
  }
}
