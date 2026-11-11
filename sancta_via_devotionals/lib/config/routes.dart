import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../screens/today/today_screen.dart';

/// Central navigation configuration for the devotionals app.
final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  debugLogDiagnostics: false,
  routes: <RouteBase>[
    // Today pipeline — placeholder until the Today assembly tasks land.
    GoRoute(
      path: '/',
      name: 'today',
      builder: (BuildContext context, GoRouterState state) =>
          const TodayScreen(),
    ),
  ],
  errorBuilder: (BuildContext context, GoRouterState state) => Scaffold(
    appBar: AppBar(title: const Text('Page not found')),
    body: Center(
      child: Text('Route not found: ${state.uri}'),
    ),
  ),
);
