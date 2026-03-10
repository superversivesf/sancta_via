import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/models.dart';
import '../screens/home/home_screen.dart';
import '../screens/mystery_selection_screen.dart';
import '../screens/rosary_screen.dart';
import '../screens/settings/notification_settings_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../screens/statistics_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  debugLogDiagnostics: false,

  routes: [
    // Home route
    GoRoute(
      path: '/',
      name: 'home',
      builder: (context, state) => const HomeScreen(),
    ),

    // Mystery Selection route
    GoRoute(
      path: '/mysteries',
      name: 'mysteries',
      builder: (context, state) => const MysterySelectionScreen(),
    ),

    // Rosary Prayer route (with optional mystery set parameter)
    GoRoute(
      path: '/rosary/:mysterySet',
      name: 'rosary',
      builder: (context, state) {
        final mysterySetParam = state.pathParameters['mysterySet'];
        final mysterySet = MysterySet.fromString(mysterySetParam);
        return RosaryScreen(initialMysterySet: mysterySet);
      },
    ),

    // Statistics route
    GoRoute(
      path: '/statistics',
      name: 'statistics',
      builder: (context, state) => const StatisticsScreen(),
    ),

    // Settings routes
    GoRoute(
      path: '/settings',
      name: 'settings',
      builder: (context, state) => const SettingsScreen(),
    ),
    GoRoute(
      path: '/settings/notifications',
      name: 'notificationSettings',
      builder: (context, state) => const NotificationSettingsScreen(),
    ),
  ],

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
            onPressed: () => context.go('/'),
            child: const Text('Go Home'),
          ),
        ],
      ),
    ),
  ),
);
