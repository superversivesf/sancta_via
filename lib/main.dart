import 'package:flutter/material.dart';
import 'package:sancta_via_shared_ui/sancta_via_shared_ui.dart';
import 'package:sancta_via_liturgical_calendar_riverpod/sancta_via_liturgical_calendar_riverpod.dart';
import 'config/routes.dart';
import 'services/app_lifecycle_service.dart';
import 'services/secure_storage_service.dart';
import 'services/database/novena_database_initializer.dart';

import 'utils/logger.dart';

// Global navigation key for notification handling
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Check for fresh installation and clean up leftover data
  try {
    final isFreshInstall = await SecureStorageService.checkAndHandleFreshInstallation();
    if (isFreshInstall) {
      AppLogger.info('Fresh installation detected - leftover data cleared', 'MAIN');
    } else {
      AppLogger.info('Existing installation detected', 'MAIN');
    }
  } catch (e) {
    AppLogger.error('Failed to check installation status: $e', 'MAIN');
    // Continue with app startup even if installation check fails
  }
  
  // Initialize novena database
  try {
    final databaseInitializer = NovenaDatabaseInitializer();
    final initResult = await databaseInitializer.initializeDatabase();
    
    if (initResult.success) {
      if (initResult.wasAlreadyInitialized) {
        AppLogger.info('Database was already initialized', 'MAIN');
      } else {
        AppLogger.info('Database initialized successfully: ${initResult.novenaCount} novenas loaded', 'MAIN');
        if (initResult.errors.isNotEmpty) {
          AppLogger.warning('Database initialization had ${initResult.errors.length} warnings: ${initResult.errors}', 'MAIN');
        }
      }
      
      // Log database stats for debugging
      final stats = await databaseInitializer.getDatabaseInfo();
      AppLogger.info('Database stats: ${stats['stats']}', 'MAIN');
    } else {
      AppLogger.error('Database initialization failed: ${initResult.error}', 'MAIN');
      // Continue with app startup - the app can still function without the database
    }
  } catch (e) {
    AppLogger.error('Database initialization threw exception: $e', 'MAIN');
    // Continue with app startup even if database fails
  }
  
  // Notification service temporarily disabled
  AppLogger.info('Notification service disabled', 'MAIN');
  
  runApp(
    const ProviderScope(
      child: NovenaCompanionApp(),
    ),
  );
}



class NovenaCompanionApp extends ConsumerWidget {
  const NovenaCompanionApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch shared UI theme providers
    final themeMode = ref.watch(themeModeProvider);
    final colorIntensity = ref.watch(colorIntensityProvider);
    final textScale = ref.watch(effectiveTextScaleProvider);
    
    // Watch liturgical color for dynamic theming (using shared provider)
    final currentLiturgicalColorString = ref.watch(currentLiturgicalColorProvider);
    
    // Parse liturgical color from string (same as other Sancta Via apps)
    final liturgicalColor = currentLiturgicalColorString != null 
        ? LiturgicalColor.fromString(currentLiturgicalColorString)
        : null;
    
    // Debug logging for color values
    AppLogger.debug('Theme rebuild - Liturgical Color: $currentLiturgicalColorString, Color Intensity: $colorIntensity', 'THEME_DEBUG');
    
    // Get themes from shared UI system  
    final lightTheme = AppTheme.lightTheme(liturgicalColor, colorIntensity);
    final darkTheme = AppTheme.darkTheme(liturgicalColor, colorIntensity);
    
    // Log actual primary colors for debugging
    AppLogger.debug('Primary Color (Light): ${lightTheme.colorScheme.primary}, (Dark): ${darkTheme.colorScheme.primary}', 'COLOR_DEBUG');
    
    // Initialize app lifecycle service for date change detection
    ref.watch(appLifecycleServiceProvider);

    return MaterialApp.router(
      title: 'Novena Companion',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: lightTheme,
      darkTheme: darkTheme,
      routerConfig: appRouter,
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
