import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sancta_via_shared_ui/sancta_via_shared_ui.dart' hide AppLogger;

import 'config/routes.dart';
import 'providers/content_providers.dart';
import 'providers/today_providers.dart';
import 'services/notification_service.dart';
import 'utils/logger.dart';

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
///
/// Besides the router it owns the notification wiring's app-side half
/// (Task 18): it listens to the service's tap stream and routes each deep
/// link, and it runs the app-open refresh hook once, after the content
/// catalog is seeded.
class SanctaViaDevotionalsApp extends ConsumerStatefulWidget {
  const SanctaViaDevotionalsApp({super.key});

  @override
  ConsumerState<SanctaViaDevotionalsApp> createState() =>
      _SanctaViaDevotionalsAppState();
}

class _SanctaViaDevotionalsAppState
    extends ConsumerState<SanctaViaDevotionalsApp> {
  StreamSubscription<String>? _taps;

  @override
  void initState() {
    super.initState();
    // Attach the tap listener BEFORE the first initialize: the cold-start
    // launch payload is emitted from initialize (the service buffers nothing,
    // so the listener must already be there).
    final NotificationService service = ref.read(notificationServiceProvider);
    _taps = service.taps.listen(_openDeepLink);
    unawaited(_refreshNotificationsOnOpen());
  }

  @override
  void dispose() {
    unawaited(_taps?.cancel());
    super.dispose();
  }

  /// The app-open refresh point (spec §9): after `ensureContentLoaded`, one
  /// initialize + refresh. A failure is logged: reminders are a nicety, never
  /// a reason to fail startup.
  Future<void> _refreshNotificationsOnOpen() async {
    try {
      await ref.read(notificationRefreshProvider.future);
    } catch (e, stackTrace) {
      AppLogger.error(
        'Notification refresh on app open failed',
        e,
        stackTrace,
        'NOTIF',
      );
    }
  }

  /// Routes a notification tap: a session deep link opens the player, and
  /// anything else lands on Today (the pinned `/` fallback).
  void _openDeepLink(String link) {
    if (link.startsWith('/session/')) {
      appRouter.go(link);
      return;
    }
    appRouter.go('/');
  }

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
