import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'config/routes.dart';
import 'features/settings/providers/settings_providers.dart';
import 'providers/theme_provider.dart' as local_theme;
import 'services/app_lifecycle_service.dart';
import 'services/secure_storage_service.dart';
import 'features/novenas/services/novena_notification_service.dart';
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
  
  // Initialize notification service for novenas
  try {
    final notificationService = NovenaNotificationService();
    await notificationService.initialize();
    
    // Set up navigation callback for notification taps
    notificationService.setNavigationCallback((payload) {
      _handleNotificationNavigation(payload);
    });
    
    AppLogger.info('Novena notification service initialized successfully', 'MAIN');
  } catch (e) {
    AppLogger.error('Failed to initialize notification service: $e', 'MAIN');
    // Continue with app startup even if notification service fails
  }
  
  runApp(
    const ProviderScope(
      child: NovenaCompanionApp(),
    ),
  );
}

/// Handle navigation when notification is tapped
void _handleNotificationNavigation(String payload) {
  try {
    AppLogger.info('Handling notification navigation: $payload', 'NOTIFICATION_NAV');
    
    // Parse payload to determine navigation destination
    if (payload.startsWith('daily_reminder_')) {
      // Extract day number from payload like 'daily_reminder_3'
      final dayStr = payload.split('_').last;
      final day = int.tryParse(dayStr);
      if (day != null) {
        // Navigate to active novena dashboard - user can then go to specific day
        appRouter.pushNamed('/active-novena');
      }
    } else if (payload.startsWith('follow_up_')) {
      // Follow-up reminders also go to dashboard
      appRouter.pushNamed('/active-novena');
    } else if (payload.startsWith('progress_') || payload == 'completion') {
      // Progress notifications go to dashboard
      appRouter.pushNamed('/active-novena');
    } else {
      // Default: go to novenas section
      appRouter.pushNamed('/novenas');
    }
  } catch (e) {
    AppLogger.error('Failed to handle notification navigation: $e', 'NOTIFICATION_NAV');
    // Fallback: go to home
    appRouter.pushNamed('/');
  }
}

class NovenaCompanionApp extends ConsumerWidget {
  const NovenaCompanionApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(local_theme.themeModeProvider);
    final lightTheme = ref.watch(local_theme.lightThemeProvider);
    final darkTheme = ref.watch(local_theme.darkThemeProvider);
    final fontScale = ref.watch(settingsProvider).fontSize;
    
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
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(fontScale),
          ),
          child: child!,
        );
      },
    );
  }
}
