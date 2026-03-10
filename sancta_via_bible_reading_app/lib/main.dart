import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sancta_via_liturgical_calendar_riverpod/sancta_via_liturgical_calendar_riverpod.dart';
import 'package:sancta_via_shared_ui/sancta_via_shared_ui.dart' hide AppLogger;

import 'config/routes.dart';
import 'services/user_message_service.dart';
import 'utils/logger.dart';

// Global navigator key for user messages
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set up user message service
  UserMessageService.navigatorKey = navigatorKey;

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
    // FIXED: Clean up user message service
    UserMessageService().clearQueue();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    // FIXED: Only trigger daily reset on resume, with safety checks
    if (state == AppLifecycleState.resumed) {
      AppLogger.info(
        'App resumed from background - safely checking for daily reset',
      );
      _safeCheckForDailyReset();
    } else if (state == AppLifecycleState.paused) {
      AppLogger.info('App paused - cleaning up message queue');
      UserMessageService().clearQueue();
    }
  }

  /// FIXED: Safe daily reset check without racing
  void _safeCheckForDailyReset() {
    // Use a short delay to ensure provider is fully initialized
    Future.delayed(const Duration(milliseconds: 100), () {
      try {
        if (mounted) {
          // The daily reset check is now handled automatically in _loadPlans
          // No need for explicit daily reset calls
          AppLogger.info(
            'Daily status check handled automatically by provider',
          );
        }
      } catch (e) {
        AppLogger.error('Error checking daily reset', e);
      }
    });
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
