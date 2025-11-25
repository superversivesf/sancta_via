import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../screens/home/home_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../features/examination/views/examination_list_screen.dart';
import '../features/examination/views/examination_intro_screen.dart';
import '../features/examination/views/examination_questions_screen.dart';
import '../features/examination/views/examination_summary_screen.dart';
import '../features/examination/views/completed_examinations_screen.dart';
import '../features/examination/views/completed_examination_detail_screen.dart';
import '../providers/text_scaling_provider.dart';

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

    // Examination features
    GoRoute(
      path: '/examinations',
      name: 'examinations',
      builder: (context, state) => const ExaminationListScreen(),
    ),
    GoRoute(
      path: '/examination/:examinationId',
      name: 'examination-intro',
      builder: (context, state) {
        final examinationId = state.pathParameters['examinationId']!;
        return ExaminationIntroScreen(examinationId: examinationId);
      },
      routes: [
        // Nested routes for examination flow
        GoRoute(
          path: 'category/:categoryId',
          name: 'examination-questions',
          builder: (context, state) {
            final examinationId = state.pathParameters['examinationId']!;
            final categoryId = state.pathParameters['categoryId']!;
            return ExaminationQuestionsScreen(
              examinationId: examinationId,
              categoryId: categoryId,
            );
          },
        ),
        GoRoute(
          path: 'summary',
          name: 'examination-summary',
          builder: (context, state) {
            final examinationId = state.pathParameters['examinationId']!;
            return ExaminationSummaryScreen(examinationId: examinationId);
          },
        ),
      ],
    ),

    // Completed examinations
    GoRoute(
      path: '/completed-examinations',
      name: 'completed-examinations',
      builder: (context, state) => const CompletedExaminationsScreen(),
    ),
    GoRoute(
      path: '/completed/:sessionId',
      name: 'completed-examination-detail',
      builder: (context, state) {
        final sessionId = state.pathParameters['sessionId']!;
        return CompletedExaminationDetailScreen(
          completedExaminationId: sessionId,
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
  errorBuilder: (context, state) => Consumer(
    builder: (context, ref, child) {
      final textScaling = ref.watch(textScaleProvider);
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
                style: textScaling.scaledHeadlineSmall(context),
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
      );
    },
  ),
);
