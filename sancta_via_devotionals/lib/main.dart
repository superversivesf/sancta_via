import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sancta_via_shared_ui/sancta_via_shared_ui.dart' hide AppLogger;

import 'config/routes.dart';

void main() {
  runApp(const ProviderScope(child: SanctaViaDevotionalsApp()));
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
