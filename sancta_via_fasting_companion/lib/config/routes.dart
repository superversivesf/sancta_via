import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../screens/achievements/achievements_screen.dart';
import '../screens/active_fast/active_fast_screen.dart';
import '../screens/fast_detail/fast_detail_screen.dart';
import '../screens/history/history_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/privacy/privacy_policy_screen.dart';
import '../screens/settings/help_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../screens/start_fast/start_fast_screen.dart';
import '../screens/statistics/statistics_screen.dart';

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

    // Active fast route
    GoRoute(
      path: '/active-fast',
      name: 'active-fast',
      builder: (context, state) => const ActiveFastScreen(),
    ),

    // Start fast route
    GoRoute(
      path: '/start-fast',
      name: 'start-fast',
      builder: (context, state) => const StartFastScreen(),
    ),

    // History route
    GoRoute(
      path: '/history',
      name: 'history',
      builder: (context, state) => const HistoryScreen(),
    ),

    // Settings route
    GoRoute(
      path: '/settings',
      name: 'settings',
      builder: (context, state) => const SettingsScreen(),
    ),

    // Privacy policy route
    GoRoute(
      path: '/privacy-policy',
      name: 'privacy-policy',
      builder: (context, state) => const PrivacyPolicyScreen(),
    ),

    // Help & Support route
    GoRoute(
      path: '/help',
      name: 'help',
      builder: (context, state) => const HelpScreen(),
    ),

    // Achievements route
    GoRoute(
      path: '/achievements',
      name: 'achievements',
      builder: (context, state) => const AchievementsScreen(),
    ),

    // Statistics route
    GoRoute(
      path: '/statistics',
      name: 'statistics',
      builder: (context, state) => const StatisticsScreen(),
    ),

    // Fast detail route
    GoRoute(
      path: '/fast-detail/:sessionId',
      name: 'fast-detail',
      builder: (context, state) {
        final sessionId = state.pathParameters['sessionId']!;
        return FastDetailScreen(sessionId: sessionId);
      },
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
