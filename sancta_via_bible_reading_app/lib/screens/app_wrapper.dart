import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bible_data_riverpod/bible_data_riverpod.dart';

import '../providers/onboarding_provider.dart';
import '../providers/reading_plan_provider.dart';
import 'onboarding/onboarding_screen.dart';
import 'home/home_screen.dart';

/// App wrapper that handles onboarding and app initialization
class AppWrapper extends ConsumerWidget {
  const AppWrapper({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the onboarding state
    final onboardingProgress = ref.watch(onboardingProvider);
    final bibleServiceAsync = ref.watch(bibleServiceNotifierProvider);

    // Check if app is ready
    final isAppReady =
        onboardingProgress.state == OnboardingState.completed &&
        bibleServiceAsync.hasValue;

    // Ensure daily reset check happens when app is ready
    if (isAppReady) {
      // Trigger daily reset check (this provider will handle it automatically)
      ref.watch(readingPlanManagerProvider);
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 500),
      child: isAppReady ? const HomeScreen() : const OnboardingScreen(),
    );
  }
}
