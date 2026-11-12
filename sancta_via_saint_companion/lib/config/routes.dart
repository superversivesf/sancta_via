import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../screens/categories/categories_screen.dart';
import '../screens/categories/category_detail_screen.dart';
import '../screens/favorites/favorites_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/saint_detail/saint_detail_screen.dart';
import '../screens/search/search_screen.dart';
import '../screens/settings/settings_screen.dart';

/// The app's route table, hoisted so tests (Task 12/14 navigation tests)
/// can navigate through the exact production routes.
final List<RouteBase> appRoutes = <RouteBase>[
  // Home
  GoRoute(
    path: '/',
    name: 'home',
    builder: (context, state) => const HomeScreen(),
  ),

  // Categories
  GoRoute(
    path: '/categories',
    name: 'categories',
    builder: (context, state) => const CategoriesScreen(),
  ),
  GoRoute(
    path: '/categories/:category',
    name: 'category_detail',
    builder: (context, state) =>
        CategoryDetailScreen(categoryId: state.pathParameters['category']!),
  ),

  // Saints
  GoRoute(
    path: '/saints/:slug',
    name: 'saint_detail',
    builder: (context, state) =>
        SaintDetailScreen(slug: state.pathParameters['slug']!),
  ),

  // Search — forwards a string route `extra` (PatronageChip and the
  // category detail need chips push the need text) as the initial query.
  // String-only: the preflight ruling guards the cast against non-string
  // extras like the Task 12 probe.
  GoRoute(
    path: '/search',
    name: 'search',
    builder: (context, state) => SearchScreen(
      initialQuery: state.extra is String ? state.extra as String : null,
    ),
  ),

  // Favorites
  GoRoute(
    path: '/favorites',
    name: 'favorites',
    builder: (context, state) => const FavoritesScreen(),
  ),

  // Settings
  GoRoute(
    path: '/settings',
    name: 'settings',
    builder: (context, state) => const SettingsScreen(),
  ),
];

final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  routes: appRoutes,

  // Error handling - shows the router error and a way back home
  errorBuilder: (context, state) => _RouteErrorScreen(state.error),
);

/// Shown for routes that match nothing in [appRouter].
class _RouteErrorScreen extends StatelessWidget {
  const _RouteErrorScreen(this.error);

  final Object? error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
            Text('$error'),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => context.go('/'),
              child: const Text('Back to Home'),
            ),
          ],
        ),
      ),
    );
  }
}
