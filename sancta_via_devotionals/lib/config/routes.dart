import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../screens/home/today_screen.dart';
import '../screens/onboarding/onboarding_screen.dart';
import '../screens/practice/enroll_screen.dart';
import '../screens/practice/practice_screen.dart';
import '../screens/practice/program_detail_screen.dart';
import '../screens/progress/progress_screen.dart';
import '../screens/session/session_player_screen.dart';
import '../screens/settings/settings_screen.dart';

/// Whether the first-launch onboarding walkthrough has completed, read LIVE
/// at every redirect evaluation.
typedef OnboardingGate = bool Function();

/// The production onboarding gate the router's redirect evaluates.
///
/// `main.dart`'s root app installs a closure reading the app's live settings;
/// while it reports `false`, the redirect sends every location that is not
/// `/onboarding` THERE — the walkthrough owns an un-onboarded app (cold start
/// included: a notification's deep link cannot pull the walkthrough away).
/// A completed install is left alone, so Today's re-entry CTA ("Set up your
/// day") can open the walkthrough again, and the walkthrough's done step
/// navigates to Today itself.
///
/// Null — every harness that does not wire it, including all existing widget
/// tests — disables the redirect entirely: Task 13's pinned Today behaviors
/// are untouched, and no test needs to know onboarding exists.
OnboardingGate? appOnboardingGate;

/// Central navigation configuration for the devotionals app.
GoRouter appRouter = buildAppRouter();

/// Builds the app router (a fresh instance per call — widget tests build
/// their own; `appRouter` stays the app-wide one, rebuilt once by `main.dart`
/// because go_router reads `initialLocation` once and the persisted onboarding
/// flag decides the cold-start entry route — see `main.dart`).
///
/// The redirect rule: with the [appOnboardingGate] wired, an un-onboarded app
/// is held in the walkthrough (`!gate() && path != '/onboarding'` →
/// `/onboarding`) and any completed install routes freely. The gate is read
/// FRESH at each evaluation, so flipping the flag mid-session (the walkthrough
/// completing) is honored by the next navigation without rebuilding the
/// router.
///
/// Route table (Task 14's shell restructure — Task 1's flat root grown into
/// the four-branch [StatefulShellRoute]):
///
/// * the shell — four tab branches under one [NavigationBar] shell
///   ([_AppShell]); the branches keep their state across tab switches:
///   - `/` — the Today screen: the liturgical header, the day's
///     time-grouped sections (Task 13), fed by the Today assembly;
///   - `/practice` — the Practice catalog: every seeded pack grouped by
///     family (Task 14);
///   - `/progress` — the Progress placeholder (Task 16 replaces it);
///   - `/settings` — the Settings placeholder (Task 20 replaces it);
/// * `/onboarding` — the onboarding walkthrough (Task 19): welcome (value
///   statement, free/offline note), the claim of existing progress (one
///   "already N in" stepper per commitment pack), the routine picker (the
///   catalog's routine packs, plus the meal & night anchors consent), the
///   reminder toggles (whose enables request notification permission through
///   Task 18's initialize seam), and the done step that flips the settings'
///   `onboardingComplete` and opens Today. An un-onboarded app is held here
///   by the redirect above, and Today's empty-state CTA routes here;
/// * `/session/:packId?forDate=yyyy-MM-dd` — the full-screen session
///   player for the pack, optionally fixed to a calendar day (the deep
///   link's `forDate`; the session resumes across days exactly as the
///   controller's rules decide). TOP-LEVEL, outside the shell: a session
///   is a focused, full-screen walk, and the deep link stays usable from
///   anywhere (the Task-13 pins rely on this shape — a pushed session
///   leaves the shell match of the branch beneath it on the stack);
/// * `/program/:packId` — the program detail (Task 14): description,
///   schedule preview, phase and policy explainers, and the Enroll CTA.
///   Top-level like the session: a detail is a focused page, not a tab;
/// * `/program/:packId/enroll` — the commitment-aware enrollment flow
///   (Task 15): the consecration feast picker, the 54-day explainer and policy
///   choice, and the write-through enroll action. Top-level like the detail.
GoRouter buildAppRouter({String initialLocation = '/'}) {
  return GoRouter(
    initialLocation: initialLocation,
    debugLogDiagnostics: false,
    redirect: (BuildContext context, GoRouterState state) {
      final OnboardingGate? gate = appOnboardingGate;
      if (gate == null) {
        return null;
      }
      if (!gate() && state.uri.path != '/onboarding') {
        return '/onboarding';
      }
      return null;
    },
    routes: <RouteBase>[
      StatefulShellRoute.indexedStack(
        builder:
            (
              BuildContext context,
              GoRouterState state,
              StatefulNavigationShell navigationShell,
            ) => _AppShell(navigationShell: navigationShell),
        branches: <StatefulShellBranch>[
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/',
                name: 'today',
                builder: (BuildContext context, GoRouterState state) =>
                    const TodayScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/practice',
                name: 'practice',
                builder: (BuildContext context, GoRouterState state) =>
                    const PracticeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/progress',
                name: 'progress',
                builder: (BuildContext context, GoRouterState state) =>
                    const ProgressScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/settings',
                name: 'settings',
                builder: (BuildContext context, GoRouterState state) =>
                    const SettingsScreen(),
              ),
            ],
          ),
        ],
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
      GoRoute(
        path: '/program/:packId',
        name: 'program-detail',
        builder: (BuildContext context, GoRouterState state) =>
            ProgramDetailScreen(packId: state.pathParameters['packId']!),
      ),
      GoRoute(
        path: '/program/:packId/enroll',
        name: 'program-enroll',
        builder: (BuildContext context, GoRouterState state) =>
            EnrollScreen(packId: state.pathParameters['packId']!),
      ),
    ],
    errorBuilder: (BuildContext context, GoRouterState state) => Scaffold(
      appBar: AppBar(title: const Text('Page not found')),
      body: Center(child: Text('Route not found: ${state.uri}')),
    ),
  );
}

/// The shell chrome around the four tab branches: the branch content above
/// a minimal [NavigationBar] (icons + labels — the Task 21-25 polish comes
/// later). Re-tapping the current branch resets it to its root, the
/// standard tab-navigation behavior.
class _AppShell extends StatelessWidget {
  const _AppShell({required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (int index) => navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        ),
        destinations: const <Widget>[
          NavigationDestination(
            icon: Icon(Icons.today_outlined),
            selectedIcon: Icon(Icons.today),
            label: 'Today',
          ),
          NavigationDestination(
            icon: Icon(Icons.self_improvement_outlined),
            selectedIcon: Icon(Icons.self_improvement),
            label: 'Practice',
          ),
          NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            selectedIcon: Icon(Icons.insights),
            label: 'Progress',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
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
