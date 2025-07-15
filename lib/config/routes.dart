import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../screens/app_wrapper.dart';
import '../screens/settings/settings_screen.dart';
import '../screens/bible_lookup/bible_lookup_screen.dart';
import '../screens/reading_plan/reading_plan_screen.dart';
import '../screens/bible_search/bible_search_screen.dart';
import '../screens/continue_reading/continue_reading_screen.dart';
import '../screens/chapter_selection/chapter_selection_screen.dart';
import '../screens/chapter/chapter_reading_screen.dart';
import '../screens/verse_selection/verse_selection_screen.dart';

final appRouter = GoRouter(
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
        final bookName = state.pathParameters['bookName']!;
        return ChapterSelectionScreen(bookName: bookName);
      },
    ),
    GoRoute(
      path: '/chapter/:bookName/:chapter',
      name: 'chapter-reading',
      builder: (context, state) {
        final bookName = state.pathParameters['bookName']!;
        final chapter = int.parse(state.pathParameters['chapter']!);
        final startVerse = state.uri.queryParameters['startVerse'];
        return ChapterReadingScreen(
          bookName: bookName, 
          chapter: chapter,
          startVerse: startVerse != null ? int.tryParse(startVerse) : null,
        );
      },
    ),
    GoRoute(
      path: '/verse-selection/:bookName/:chapter',
      name: 'verse-selection',
      builder: (context, state) {
        final bookName = state.pathParameters['bookName']!;
        final chapter = int.parse(state.pathParameters['chapter']!);
        return VerseSelectionScreen(
          bookName: bookName,
          chapter: chapter,
        );
      },
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