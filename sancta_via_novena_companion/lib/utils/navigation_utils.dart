import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../config/route_names.dart';

/// Navigation utilities for consistent routing throughout the app
/// Uses GoRouter methods directly with proper push vs go semantics
class AppNavigation {
  // =============================================================================
  // TOP-LEVEL NAVIGATION (replaces stack, no back button)
  // Use for main app flow transitions
  // =============================================================================

  static void goToHome(BuildContext context) {
    context.goNamed(RouteNames.home);
  }

  static void goToAuth(BuildContext context) {
    context.goNamed(RouteNames.auth);
  }

  static void goToPinAuth(BuildContext context) {
    context.goNamed(RouteNames.pinAuth);
  }

  // =============================================================================
  // PUSH NAVIGATION (adds to stack, shows back button)
  // Use for navigating within features
  // =============================================================================

  // Settings navigation
  static void pushToSettings(BuildContext context) {
    context.pushNamed(RouteNames.settings);
  }

  static void pushToThemePreview(BuildContext context) {
    context.pushNamed(RouteNames.themePreview);
  }

  static void pushToPinSetup(BuildContext context) {
    context.pushNamed(RouteNames.pinSetup);
  }

  static void pushToPrivacyPolicy(BuildContext context) {
    context.pushNamed(RouteNames.privacyPolicy);
  }

  // Novena navigation
  static void pushToNovenas(BuildContext context) {
    context.pushNamed(RouteNames.novenas);
  }

  static void pushToNovenaDetail(BuildContext context, String novenaId) {
    context.pushNamed(
      RouteNames.novenaDetail,
      pathParameters: {'novenaId': novenaId},
    );
  }

  static void pushToNovenaConfiguration(BuildContext context, String novenaId) {
    context.pushNamed(
      RouteNames.novenaConfiguration,
      pathParameters: {'novenaId': novenaId},
    );
  }

  static void pushToActiveNovena(BuildContext context) {
    context.pushNamed(RouteNames.activeNovena);
  }

  static void pushToDailyNovena(BuildContext context, int dayNumber) {
    context.pushNamed(
      RouteNames.dailyNovena,
      pathParameters: {'dayNumber': dayNumber.toString()},
    );
  }

  // =============================================================================
  // UTILITY METHODS
  // =============================================================================

  /// Go back to previous screen
  static void goBack(BuildContext context) {
    context.pop();
  }

  /// Check if we can go back
  static bool canGoBack(BuildContext context) {
    return context.canPop();
  }

  /// Go to home (replaces entire stack)
  static void popUntilHome(BuildContext context) {
    context.goNamed(RouteNames.home);
  }

  // =============================================================================
  // NAVIGATION WITH EXTRA DATA
  // =============================================================================

  /// Navigate with extra data that doesn't appear in URL
  static void pushWithExtra(
    BuildContext context,
    String routeName,
    Object extra, {
    Map<String, String>? pathParameters,
  }) {
    context.pushNamed(
      routeName,
      pathParameters: pathParameters ?? {},
      extra: extra,
    );
  }

  static void goWithExtra(
    BuildContext context,
    String routeName,
    Object extra, {
    Map<String, String>? pathParameters,
  }) {
    context.goNamed(
      routeName,
      pathParameters: pathParameters ?? {},
      extra: extra,
    );
  }
}
