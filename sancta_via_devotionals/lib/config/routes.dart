import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../screens/home/today_screen.dart';
import '../screens/onboarding/onboarding_screen.dart';
import '../screens/session/session_player_screen.dart';

/// Central navigation configuration for the devotionals app.
final GoRouter appRouter = buildAppRouter();

/// Builds the app router (a fresh instance per call — widget tests build
/// their own; `appRouter` stays the app-wide one).
///
/// Route table:
/// * `/` — the Today screen: the liturgical header, the day's time-grouped
///   sections (Task 13), fed by the Today assembly;
/// * `/onboarding` — the onboarding walkthrough placeholder (the real flow
///   lands in Task 19; Today's empty-state CTA routes here today);
/// * `/session/:packId?forDate=yyyy-MM-dd` — the full-screen session
///   player for the pack, optionally fixed to a calendar day (the deep
///   link's `forDate`; the session resumes across days exactly as the
///   controller's rules decide).
GoRouter buildAppRouter({String initialLocation = '/'}) {
  return GoRouter(
    initialLocation: initialLocation,
    debugLogDiagnostics: false,
    routes: <RouteBase>[
      GoRoute(
        path: '/',
        name: 'today',
        builder: (BuildContext context, GoRouterState state) =>
            const TodayScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        name: 'onboarding',
        builder: (BuildContext context, GoRouterState state) =>
            const OnboardingScreen(),
      ),
      GoRoute(
        path: '/session/:packId',
        name: 'session-player',
        builder: (BuildContext context, GoRouterState state) =>
            SessionPlayerScreen(
              packId: state.pathParameters['packId']!,
              forDate: parseSessionForDate(
                state.uri.queryParameters['forDate'],
              ),
            ),
      ),
    ],
    errorBuilder: (BuildContext context, GoRouterState state) => Scaffold(
      appBar: AppBar(title: const Text('Page not found')),
      body: Center(child: Text('Route not found: ${state.uri}')),
    ),
  );
}

/// The session route's optional `forDate` query parameter — the deep link's
/// calendar day for the player.
///
/// ONLY the strict `yyyy-MM-dd` shape is accepted (a date-only ISO string,
/// the engine's date discipline); any other value — a timestamp, a
/// localized date, an impossible calendar day like `2026-13-05` — opens the
/// session on the clock's day instead, never on a mis-parsed date.
DateTime? parseSessionForDate(String? raw) {
  if (raw == null || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(raw)) {
    return null;
  }
  // `DateTime.parse` ROLLS impossible calendar days over (`2026-13-05`
  // parses as 2027-01-05), so validate the components against a rebuilt
  // local midnight instead of trusting the parse.
  final int year = int.parse(raw.substring(0, 4));
  final int month = int.parse(raw.substring(5, 7));
  final int day = int.parse(raw.substring(8, 10));
  if (month < 1 || month > 12 || day < 1 || day > 31) {
    return null;
  }
  final DateTime parsed = DateTime(year, month, day);
  if (parsed.year != year || parsed.month != month || parsed.day != day) {
    return null;
  }
  return parsed;
}
