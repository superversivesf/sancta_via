// Application entry point and root widget (Plan 2; init-order audit in
// Task 25).
//
// ## Startup order (verified, with the one deliberate inversion)
//
// The required dependency order is
//
//   db → content → notifications → router
//
// and the live chain honours it: the notification app-open hook
// (`notificationRefreshProvider`) awaits `contentLoadedProvider`, which runs
// the first-launch migration — opening the SQLite database and seeding the
// shipped pack catalog — BEFORE the planner reads packs, enrollments, and
// progress, and the notification service initializes before its first plan.
// The router is the one step that is constructed EARLY (`main` builds it
// before `runApp`, because `MaterialApp.router` cannot be built without it),
// and that is safe by construction: the router consumes no database,
// content, notification, or repository state — it is a pure config object
// over route builders, and its only input is the persisted onboarding flag.
//
// The app-open notification initialize deliberately stays in the root
// widget's `initState` rather than moving ahead of `runApp`: the tap stream
// listener must attach BEFORE `NotificationService.initialize()` emits the
// cold-start launch payload (the service buffers nothing, Task 18's pinned
// contract), and the widget is the first place a listener can exist. Moving
// initialization earlier would trade a harmless ordering inversion for a
// dropped cold-start tap — a real regression, so it is not done.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sancta_via_shared_ui/sancta_via_shared_ui.dart' hide AppLogger;

import 'config/routes.dart';
import 'providers/app_settings_provider.dart'
    show
        devotionsSettingsProvider,
        onboardingCompleteProvider,
        readPersistedOnboardingComplete;
import 'providers/content_providers.dart';
import 'providers/today_providers.dart';
import 'services/notification_service.dart';
import 'utils/logger.dart';

Future<void> main() async {
  // The cold-start entry route (Task 19): go_router reads `initialLocation`
  // once, and the persisted onboarding flag decides it BEFORE the first
  // frame — a returning user opens Today, a fresh install the walkthrough —
  // so the async settings load can never strand a complete user inside the
  // walkthrough. From there the redirect gate (wired below) holds an
  // un-onboarded app in the walkthrough at every navigation.
  WidgetsFlutterBinding.ensureInitialized();
  final bool onboardingComplete = await readPersistedOnboardingComplete();
  appRouter = buildAppRouter(
    // The store read above IS the loaded path of the cold-start rule (the
    // persisted truth was awaited before the first frame), so the live flag
    // decides the entry route; `persistedEntry` is only read while a load is
    // unresolved (see [decideColdStartRoute]).
    initialLocation: decideColdStartRoute(
      isLoaded: true,
      onboardingComplete: onboardingComplete,
      persistedEntry: '/',
    ),
  );
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
/// catalog is seeded. It also wires the onboarding gate ([appOnboardingGate])
/// through which the router holds an un-onboarded app in the walkthrough
/// (Task 19), and — Task 20 — the MaterialApp plumbing from the settings
/// composition: the locale follows the shared base settings' default
/// language and the theme mode follows the shared theme-mode store, so the
/// base-settings controls on the settings screen drive the running app.
class SanctaViaDevotionalsApp extends ConsumerStatefulWidget {
  /// Creates the root app.
  ///
  /// [router] presents the app-wide [appRouter] (whose entry route [main]
  /// rebuilt from the persisted onboarding flag) unless a test supplies its
  /// own instance.
  const SanctaViaDevotionalsApp({this.router, super.key});

  /// The router configuration, or null for the app-wide [appRouter].
  final GoRouter? router;

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
    // The onboarding gate (Task 19): the router's redirect re-reads the LIVE
    // settings through this closure at every navigation, and the PURE
    // cold-start rule ([decideColdStartRoute]) answers. Until the async
    // settings load resolved, the rule keeps the persisted entry — the app
    // is already open where the store sent it, so the gate stays open; a
    // loaded store saying incomplete is what closes it into the walkthrough.
    // Installed once — the app runs for the process lifetime.
    appOnboardingGate = () =>
        decideColdStartRoute(
          isLoaded: ref.read(devotionsSettingsProvider.notifier).isLoaded,
          onboardingComplete: ref.read(onboardingCompleteProvider),
          // The gate's "persisted entry": the app is already open at the
          // route `main` chose from the store.
          persistedEntry: '/',
        ) ==
        '/';
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
    // Task 20's material plumbing: what the settings screen's shared
    // base-settings controls write is what the app runs with — the locale
    // from `baseSettingsProvider`'s default language and the theme mode
    // from the shared theme store the `ThemeModeSelector` drives (the
    // base-settings model itself carries no theme-mode field; the shared
    // theme providers are its storage, as in the sibling apps).
    final AppLanguage language = ref
        .watch(baseSettingsProvider)
        .defaultLanguage;
    final ThemeMode themeMode = ref.watch(themeModeProvider);
    return MaterialApp.router(
      title: 'Sancta Via Devotionals',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme(),
      darkTheme: AppTheme.darkTheme(),
      themeMode: themeMode,
      locale: Locale(language.code),
      routerConfig: widget.router ?? appRouter,
    );
  }
}
