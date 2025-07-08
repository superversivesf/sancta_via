import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../screens/home/home_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../screens/bible_lookup/bible_lookup_screen.dart';
import '../screens/reading_plan/reading_plan_screen.dart';
import '../screens/bible_search/bible_search_screen.dart';
import '../screens/continue_reading/continue_reading_screen.dart';

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

    // Bible features
    GoRoute(
      path: '/bible-lookup',
      name: 'bible-lookup',
      builder: (context, state) => const BibleLookupScreen(),
    ),
    GoRoute(
      path: '/bible-search',
      name: 'bible-search',
      builder: (context, state) => const BibleSearchScreen(),
    ),
    GoRoute(
      path: '/reading-plan',
      name: 'reading-plan',
      builder: (context, state) => const ReadingPlanScreen(),
    ),
    GoRoute(
      path: '/continue-reading',
      name: 'continue-reading',
      builder: (context, state) => const ContinueReadingScreen(),
    ),

    // Settings
    GoRoute(
      path: '/settings',
      name: 'settings',
      builder: (context, state) => const SettingsScreen(),
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
