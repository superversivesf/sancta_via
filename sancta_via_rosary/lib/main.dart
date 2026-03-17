import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sancta_via_liturgical_calendar_riverpod/sancta_via_liturgical_calendar_riverpod.dart';
import 'package:sancta_via_shared_ui/sancta_via_shared_ui.dart';

import 'config/routes.dart';
import 'providers/rosary_stats_provider.dart';
import 'services/notification_service.dart';
import 'services/rosary_statistics_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize notification service
  await NotificationService.instance.initialize();

  // Initialize statistics service
  final statsService = await RosaryStatisticsService.create();

  runApp(
    ProviderScope(
      overrides: [
        // Override the statistics service provider with initialized instance
        rosaryStatisticsServiceProvider.overrideWithValue(statsService),
      ],
      child: const RosaryCompanionApp(),
    ),
  );
}

class RosaryCompanionApp extends ConsumerWidget {
  const RosaryCompanionApp({super.key});

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
      title: 'Sancta Via Rosary',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme(liturgicalColor, colorIntensity),
      darkTheme: AppTheme.darkTheme(liturgicalColor, colorIntensity),
      themeMode: themeMode,
      routerConfig: appRouter,
    );
  }
}
