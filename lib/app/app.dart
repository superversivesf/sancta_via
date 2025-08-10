import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sancta_via_liturgical_calendar_riverpod/sancta_via_liturgical_calendar_riverpod.dart';
import 'package:sancta_via_shared_ui/sancta_via_shared_ui.dart';
import '../config/routes.dart';
import '../providers/calendar_providers.dart' as local_providers;

class LiturgicalCalendarApp extends ConsumerStatefulWidget {
  const LiturgicalCalendarApp({super.key});

  @override
  ConsumerState<LiturgicalCalendarApp> createState() => _LiturgicalCalendarAppState();
}

class _LiturgicalCalendarAppState extends ConsumerState<LiturgicalCalendarApp> 
    with WidgetsBindingObserver {

  @override
  void initState() {
    super.initState();
    // Add app lifecycle observer
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    // Remove app lifecycle observer
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    // When app comes back from background, check if date has changed
    if (state == AppLifecycleState.resumed) {
      _checkAndUpdateDateIfNeeded();
    }
  }

  void _checkAndUpdateDateIfNeeded() {
    final now = DateTime.now();
    final selectedDate = ref.read(local_providers.selectedDateProvider);
    
    // Check if the selected date is no longer today
    final isSelectedDateToday = selectedDate.year == now.year && 
                               selectedDate.month == now.month && 
                               selectedDate.day == now.day;
    
    // If the app was backgrounded overnight or longer, update to today
    if (!isSelectedDateToday) {
      // Update selected date to today
      ref.read(local_providers.selectedDateProvider.notifier).state = now;
      
      // Also update displayed month to current month if needed
      final displayedMonth = ref.read(local_providers.displayedMonthProvider);
      final isDisplayedMonthCurrent = displayedMonth.year == now.year && 
                                     displayedMonth.month == now.month;
      
      if (!isDisplayedMonthCurrent) {
        ref.read(local_providers.displayedMonthProvider.notifier).state = 
            DateTime(now.year, now.month, 1);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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