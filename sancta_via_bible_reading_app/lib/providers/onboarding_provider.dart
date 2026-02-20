import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bible_data_riverpod/bible_data_riverpod.dart' hide AppLogger;
import 'dart:convert';
import 'package:flutter/services.dart';
import '../utils/logger.dart';

/// Onboarding state
enum OnboardingState { checking, loading, completed, error }

/// Onboarding progress information
class OnboardingProgress {
  final OnboardingState state;
  final String message;
  final double progress; // 0.0 to 1.0
  final String? error;
  final int currentStep;
  final int totalSteps;

  const OnboardingProgress({
    required this.state,
    required this.message,
    required this.progress,
    required this.currentStep,
    required this.totalSteps,
    this.error,
  });

  OnboardingProgress copyWith({
    OnboardingState? state,
    String? message,
    double? progress,
    String? error,
    int? currentStep,
    int? totalSteps,
  }) {
    return OnboardingProgress(
      state: state ?? this.state,
      message: message ?? this.message,
      progress: progress ?? this.progress,
      error: error ?? this.error,
      currentStep: currentStep ?? this.currentStep,
      totalSteps: totalSteps ?? this.totalSteps,
    );
  }
}

/// Onboarding service that manages first-time app initialization
class OnboardingService {
  static const String _onboardingCompletedKey = 'onboarding_completed';
  static const String _databaseInitializedKey = 'database_initialized';

  /// Check if this is the first run
  static Future<bool> isFirstRun() async {
    final prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool(_onboardingCompletedKey) ?? false);
  }

  /// Mark onboarding as completed
  static Future<void> markOnboardingCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingCompletedKey, true);
    await prefs.setBool(_databaseInitializedKey, true);
  }

  /// Check if database is initialized
  static Future<bool> isDatabaseInitialized() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_databaseInitializedKey) ?? false;
  }

  /// Load JSON file content (legacy method for uncompressed files)
  static Future<Map<String, dynamic>> loadJsonFile(String path) async {
    try {
      final jsonString = await rootBundle.loadString(path);
      return json.decode(jsonString) as Map<String, dynamic>;
    } catch (e) {
      AppLogger.debug('Error loading JSON file $path: $e', 'ONBOARDING');
      rethrow;
    }
  }

  /// Get available Bible translations from compressed JSON files
  static Future<List<BibleTranslation>> getAvailableBibleTranslations() async {
    return [
      BibleTranslation.cpdv,
      BibleTranslation.drc,
      BibleTranslation.engwebc,
    ];
  }
}

/// Onboarding notifier that manages the onboarding process
class OnboardingNotifier extends StateNotifier<OnboardingProgress> {
  OnboardingNotifier()
    : super(
        const OnboardingProgress(
          state: OnboardingState.checking,
          message: 'Checking app status...',
          progress: 0.0,
          currentStep: 0,
          totalSteps: 5,
        ),
      );

  /// Initialize the onboarding process
  Future<void> initialize() async {
    AppLogger.debug('Starting onboarding initialization...', 'ONBOARDING');

    try {
      // Step 1: Check if this is first run
      state = state.copyWith(
        state: OnboardingState.checking,
        message: 'Checking app status...',
        progress: 0.0,
        currentStep: 1,
      );

      final isFirstRun = await OnboardingService.isFirstRun();
      final isDatabaseInitialized =
          await OnboardingService.isDatabaseInitialized();

      AppLogger.debug(
        'First run: $isFirstRun, Database initialized: $isDatabaseInitialized',
        'ONBOARDING',
      );

      if (!isFirstRun && isDatabaseInitialized) {
        // App already initialized
        state = state.copyWith(
          state: OnboardingState.completed,
          message: 'App ready!',
          progress: 1.0,
          currentStep: 4,
        );
        return;
      }

      // Need to initialize the database
      await _initializeBibleDatabase();
    } catch (e) {
      AppLogger.debug('Onboarding initialization error: $e', 'ONBOARDING');
      state = state.copyWith(
        state: OnboardingState.error,
        message: 'Failed to initialize app',
        error: e.toString(),
      );
    }
  }

  /// Initialize the Bible database from compressed JSON files
  Future<void> _initializeBibleDatabase() async {
    AppLogger.debug('Starting Bible database initialization...', 'ONBOARDING');

    try {
      // Step 2: Load available translations
      state = state.copyWith(
        state: OnboardingState.loading,
        message: 'Loading Bible translations...',
        progress: 0.2,
        currentStep: 2,
      );

      final translations =
          await OnboardingService.getAvailableBibleTranslations();
      AppLogger.debug(
        'Found ${translations.length} translations to load',
        'ONBOARDING',
      );

      // Step 3: Verify compressed Bible files
      // COMMENTED OUT: We no longer ship compressed files
      /*
      state = state.copyWith(
        message: 'Verifying Bible data...',
        progress: 0.4,
        currentStep: 3,
      );

      await OnboardingService.verifyCompressedBibleFiles();
      AppLogger.debug('All compressed Bible files verified successfully', 'ONBOARDING');
      */

      // Skip verification step since we only use the SQLite database
      AppLogger.debug(
        'Skipping compressed file verification - using SQLite database only',
        'ONBOARDING',
      );

      // Step 4: Initialize Bible service and load data
      state = state.copyWith(
        message: 'Initializing Bible service...',
        progress: 0.6,
        currentStep: 4,
      );

      // The Bible service will automatically handle database initialization
      // when it's accessed for the first time. We just need to make sure
      // it's properly initialized by accessing it.

      // This will be handled by the Bible service provider
      await Future.delayed(
        const Duration(milliseconds: 500),
      ); // Small delay for UI

      // Step 5: Complete initialization
      state = state.copyWith(
        message: 'Finalizing setup...',
        progress: 0.8,
        currentStep: 5,
      );

      // Mark as completed
      await OnboardingService.markOnboardingCompleted();

      state = state.copyWith(
        state: OnboardingState.completed,
        message: 'Welcome to Sancta Via Bible!',
        progress: 1.0,
      );

      AppLogger.debug('Bible database initialization completed', 'ONBOARDING');
    } catch (e) {
      AppLogger.debug('Bible database initialization error: $e', 'ONBOARDING');
      state = state.copyWith(
        state: OnboardingState.error,
        message: 'Failed to initialize Bible database',
        error: e.toString(),
      );
    }
  }

  /// Retry onboarding process
  Future<void> retry() async {
    AppLogger.debug('Retrying onboarding process...', 'ONBOARDING');
    state = const OnboardingProgress(
      state: OnboardingState.checking,
      message: 'Retrying...',
      progress: 0.0,
      currentStep: 0,
      totalSteps: 5,
    );
    await initialize();
  }
}

/// Provider for onboarding state
final onboardingProvider =
    StateNotifierProvider<OnboardingNotifier, OnboardingProgress>((ref) {
      return OnboardingNotifier();
    });

/// Provider to check if app is ready
final appReadyProvider = Provider<bool>((ref) {
  final onboarding = ref.watch(onboardingProvider);
  final bibleService = ref.watch(bibleServiceNotifierProvider);

  return onboarding.state == OnboardingState.completed && bibleService.hasValue;
});

/// Provider to check if this is first run
final isFirstRunProvider = FutureProvider<bool>((ref) async {
  return await OnboardingService.isFirstRun();
});
