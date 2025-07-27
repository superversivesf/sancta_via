import 'package:flutter/material.dart';
import 'package:sancta_via_liturgical_calendar_riverpod/sancta_via_liturgical_calendar_riverpod.dart';
import 'package:sancta_via_shared_ui/sancta_via_shared_ui.dart';

import 'config/routes.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize notification service
  await NotificationService.initialize();
  
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
