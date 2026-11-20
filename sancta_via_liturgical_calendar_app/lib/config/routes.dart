import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../screens/home/home_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../screens/calendar/calendar_screen.dart';
import '../screens/day_detail/day_detail_screen.dart';
import '../screens/search/search_screen.dart';

/// Strict YYYY-MM-DD parsing: rejects values that `DateTime.parse`
/// silently normalises (e.g. 2026-13-05 becomes 2027-01-05, 2026-02-30
/// becomes 2026-03-02) by checking that the parsed date round-trips to
/// the same components. Mirrors the parser sancta_via_devotionals
/// documents for its /day/:date deep links.
DateTime? _parseStrictDate(String input) {
  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(input);
  if (match == null) return null;
  final year = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final day = int.parse(match.group(3)!);
  final date = DateTime(year, month, day);
  if (date.year != year || date.month != month || date.day != day) {
    return null;
  }
  return date;
}

final appRouter = GoRouter(
  initialLocation: '/',
  debugLogDiagnostics: false,


  // Redirect invalid dates to home
  redirect: (context, state) {
    // Check day-detail route for valid date
    final pathSegments = state.uri.pathSegments;
    if (pathSegments.isNotEmpty &&
        pathSegments.first == 'day' &&
        pathSegments.length >= 2) {
      if (_parseStrictDate(pathSegments[1]) == null) {
        // Invalid date format or rolled-over date - redirect to home
        return '/';
      }
    }
    return null; // No redirect needed
  },

  routes: [
    // Home route
    GoRoute(
      path: '/',
      name: 'home',
      builder: (context, state) => const HomeScreen(),
    ),

    // Calendar features
    GoRoute(
      path: '/calendar',
      name: 'calendar',
      builder: (context, state) => const CalendarScreen(),
    ),
    GoRoute(
      path: '/day/:date',
      name: 'day-detail',
      builder: (context, state) {
        final dateString = state.pathParameters['date']!;
        // Defensive parsing - redirect should catch invalid dates,
        // but this provides a safety net
        final date = _parseStrictDate(dateString) ?? DateTime.now();
        return DayDetailScreen(date: date);
      },
    ),
    GoRoute(
      path: '/search',
      name: 'search',
      builder: (context, state) => const SearchScreen(),
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
