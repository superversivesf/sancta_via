import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../utils/logger.dart';

import '../features/auth/views/pin_auth_screen.dart';
import '../features/home/views/home_screen.dart';
import '../features/novenas/views/novena_list_screen.dart';
import '../features/novenas/views/novena_detail_screen.dart';
import '../features/novenas/views/novena_configuration_screen.dart';
import '../features/novenas/views/active_novena_dashboard.dart';
import '../features/novenas/views/daily_novena_screen.dart';
import '../features/settings/views/novena_settings_screen.dart';
import '../features/settings/views/theme_preview_screen.dart';
import '../features/settings/views/pin_setup_screen.dart';
import '../features/settings/views/privacy_policy_screen.dart';
import '../features/auth/views/auth_screen.dart';
import 'route_names.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  debugLogDiagnostics: false,

  routes: [
    // Home route
    GoRoute(
      path: '/',
      name: RouteNames.home,
      builder: (context, state) => const HomeScreen(),
    ),

    // Auth routes
    GoRoute(
      path: '/auth',
      name: RouteNames.auth,
      builder: (context, state) => const AuthScreen(),
    ),
    GoRoute(
      path: '/auth/pin',
      name: RouteNames.pinAuth,
      builder: (context, state) => const PinAuthScreen(),
    ),

    // Settings routes
    GoRoute(
      path: '/settings',
      name: RouteNames.settings,
      builder: (context, state) => const NovenaSettingsScreen(),
      routes: [
        GoRoute(
          path: 'theme-preview',
          name: RouteNames.themePreview,
          builder: (context, state) => const ThemePreviewScreen(),
        ),
        GoRoute(
          path: 'pin-setup',
          name: RouteNames.pinSetup,
          builder: (context, state) => const PinSetupScreen(),
        ),
        GoRoute(
          path: 'privacy-policy',
          name: RouteNames.privacyPolicy,
          builder: (context, state) => const PrivacyPolicyScreen(),
        ),
      ],
    ),

    // Novena routes
    GoRoute(
      path: '/novenas',
      name: RouteNames.novenas,
      builder: (context, state) => const NovenaListScreen(),
      routes: [
        // Active novena route
        GoRoute(
          path: 'active',
          name: RouteNames.activeNovena,
          builder: (context, state) {
            AppLogger.debug('🔍 [ROUTES] Building ActiveNovenaDashboard', 'NOVENA_ROUTES');
            return const ActiveNovenaDashboard();
          },
          routes: [
            GoRoute(
              path: 'day/:dayNumber',
              name: RouteNames.dailyNovena,
              builder: (context, state) {
                final dayNumber = int.parse(state.pathParameters['dayNumber']!);
                AppLogger.debug('🔍 [ROUTES] Building DailyNovenaScreen for day $dayNumber', 'NOVENA_ROUTES');
                return DailyNovenaScreen(dayNumber: dayNumber);
              },
            ),
          ],
        ),
        // Individual novena detail
        GoRoute(
          path: ':novenaId',
          name: RouteNames.novenaDetail,
          builder: (context, state) {
            final novenaId = state.pathParameters['novenaId']!;
            AppLogger.debug('🔍 [ROUTES] Building NovenaDetailScreen with novenaId: "$novenaId"', 'NOVENA_ROUTES');
            return NovenaDetailScreen(novenaId: novenaId);
          },
          routes: [
            GoRoute(
              path: 'configure',
              name: RouteNames.novenaConfiguration,
              builder: (context, state) {
                final novenaId = state.pathParameters['novenaId']!;
                AppLogger.debug('🔍 [ROUTES] Building NovenaConfigurationScreen with novenaId: "$novenaId"', 'NOVENA_ROUTES');
                return NovenaConfigurationScreen(novenaId: novenaId);
              },
            ),
          ],
        ),
      ],
    ),
  ],

  // Authentication redirect logic - simplified for novena app
  redirect: (BuildContext context, GoRouterState state) async {
    try {
      // No protected routes in the basic novena app - all content is accessible
      AppLogger.debug("Route: ${state.matchedLocation}", 'ROUTER');
      return null; // No redirect needed
      
    } catch (e, stackTrace) {
      AppLogger.error('Router redirect error', e, stackTrace, 'ROUTER');
      return null; // Don't redirect on error
    }
  },

  // Error handling
  errorBuilder: (context, state) => Scaffold(
    appBar: AppBar(
      title: const Text('Page Not Found'),
      automaticallyImplyLeading: true,
    ),
    body: Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64),
          const SizedBox(height: 16),
          Text(
            'Page Not Found',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text('No route found for ${state.uri.path}'),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => context.goNamed(RouteNames.home),
            child: const Text('Go Home'),
          ),
        ],
      ),
    ),
  ),
);
