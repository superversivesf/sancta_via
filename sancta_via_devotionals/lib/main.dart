import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sancta_via_shared_ui/sancta_via_shared_ui.dart' hide AppLogger;

import 'config/routes.dart';
import 'providers/content_providers.dart';

void main() {
  runApp(
    ProviderScope(
      // Route the wrapper's program providers through the app's SQLite
      // repository (Task 6): the same instance the content pipeline seeds.
      overrides: <Override>[programRepositoryOverride],
      child: const SanctaViaDevotionalsApp(),
    ),
  );
}

/// Root widget of the Sancta Via Devotionals application.
class SanctaViaDevotionalsApp extends StatelessWidget {
  const SanctaViaDevotionalsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Sancta Via Devotionals',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme(),
      darkTheme: AppTheme.darkTheme(),
      routerConfig: appRouter,
    );
  }
}
