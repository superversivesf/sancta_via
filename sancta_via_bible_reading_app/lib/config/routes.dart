import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../main.dart';
import '../models/reading_plan.dart';
import '../screens/app_wrapper.dart';
import '../screens/settings/settings_screen.dart';
import '../screens/bible_lookup/bible_lookup_screen.dart';
import '../screens/reading_plan/reading_plan_screen.dart';
import '../screens/bible_search/bible_search_screen.dart';
import '../screens/continue_reading/continue_reading_screen.dart';
import '../screens/chapter_selection/chapter_selection_screen.dart';
import '../screens/chapter/chapter_reading_screen.dart';
import '../screens/verse_selection/verse_selection_screen.dart';
import '../screens/debug/numbered_books_debug_screen.dart';

final appRouter = GoRouter(
  navigatorKey: navigatorKey, // Global navigator key for user messages
  initialLocation: '/',
  debugLogDiagnostics: false,

  routes: [
    // Home route - uses AppWrapper to handle onboarding
    GoRoute(
      path: '/',
      name: 'home',
      builder: (context, state) => const AppWrapper(),
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

    // Chapter navigation routes
    GoRoute(
      path: '/chapter-selection/:bookName',
      name: 'chapter-selection',
      builder: (context, state) {
        try {
          // FIXED: Proper URL decoding
          final bookName = Uri.decodeComponent(
            state.pathParameters['bookName']!,
          );

          if (!_isValidBookName(bookName)) {
            throw Exception('Invalid book name: $bookName');
          }

          return ChapterSelectionScreen(bookName: bookName);
        } catch (e) {
          print('❌ Error parsing chapter selection route: $e');
          return _buildRouteErrorScreen(context, 'Invalid book name: $e');
        }
      },
    ),
    GoRoute(
      path: '/chapter/:bookName/:chapter',
      name: 'chapter-reading',
      builder: (context, state) {
        try {
          // FIXED: Proper URL decoding
          final bookName = Uri.decodeComponent(
            state.pathParameters['bookName']!,
          );
          final chapter = int.parse(state.pathParameters['chapter']!);
          final startVerse = state.uri.queryParameters['startVerse'];

          // Validate book name against known Bible books
          if (!_isValidBookName(bookName)) {
            throw Exception('Invalid book name: $bookName');
          }

          return ChapterReadingScreen(
            bookName: bookName,
            chapter: chapter,
            startVerse: startVerse != null ? int.tryParse(startVerse) : null,
          );
        } catch (e) {
          print('❌ Error parsing chapter route: $e');
          // Return error screen instead of crashing
          return _buildRouteErrorScreen(
            context,
            'Invalid chapter parameters: $e',
          );
        }
      },
    ),
    GoRoute(
      path: '/verse-selection/:bookName/:chapter',
      name: 'verse-selection',
      builder: (context, state) {
        try {
          // FIXED: Proper URL decoding
          final bookName = Uri.decodeComponent(
            state.pathParameters['bookName']!,
          );
          final chapter = int.parse(state.pathParameters['chapter']!);

          if (!_isValidBookName(bookName)) {
            throw Exception('Invalid book name: $bookName');
          }

          return VerseSelectionScreen(bookName: bookName, chapter: chapter);
        } catch (e) {
          print('❌ Error parsing verse selection route: $e');
          return _buildRouteErrorScreen(
            context,
            'Invalid verse selection parameters: $e',
          );
        }
      },
    ),

    // Settings
    GoRoute(
      path: '/settings',
      name: 'settings',
      builder: (context, state) => const SettingsScreen(),
    ),

    // Debug routes (for development/testing)
    GoRoute(
      path: '/debug/numbered-books',
      name: 'numbered-books-debug',
      builder: (context, state) => const NumberedBooksDebugScreen(),
    ),
  ],

  // Enhanced error handling
  errorBuilder: (context, state) =>
      _buildRouteErrorScreen(context, 'Page not found: ${state.uri.path}'),
);

/// NEW: Validate book names against known Bible books
bool _isValidBookName(String bookName) {
  // DEBUGGING: Log the book name being validated
  print('🔍 Validating book name: "$bookName"');

  // Check against all possible book collections
  for (final collection in BookCollection.values) {
    if (collection.bookNames.contains(bookName)) {
      print('✅ Book "$bookName" found in collection: ${collection.name}');
      return true;
    }
  }

  // DEBUGGING: Log all books in collections to help debug
  print('❌ Book "$bookName" not found in any collection!');
  print('📚 Available books in collections:');
  for (final collection in BookCollection.values) {
    print(
      '   ${collection.name}: ${collection.bookNames.take(5).join(", ")}${collection.bookNames.length > 5 ? "..." : ""}',
    );
  }

  return false;
}

/// NEW: Build consistent error screen for route issues
Widget _buildRouteErrorScreen(BuildContext context, String error) {
  return Scaffold(
    appBar: AppBar(
      title: const Text('Navigation Error'),
      automaticallyImplyLeading: true,
    ),
    body: Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text(
            'Navigation Error',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              error,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => context.go('/'),
            child: const Text('Go Home'),
          ),
        ],
      ),
    ),
  );
}
