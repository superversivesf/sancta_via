import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/reading_plan.dart';

/// Provider for the reading plan manager (multiple plans)
final readingPlanManagerProvider = StateNotifierProvider<ReadingPlanManagerNotifier, ReadingPlanManager>((ref) {
  return ReadingPlanManagerNotifier();
});

/// Provider to get all active reading plans
final activeReadingPlansProvider = Provider<List<ReadingPlan>>((ref) {
  final manager = ref.watch(readingPlanManagerProvider);
  return manager.activePlans;
});

/// Provider to get all completed reading plans
final completedReadingPlansProvider = Provider<List<ReadingPlan>>((ref) {
  final manager = ref.watch(readingPlanManagerProvider);
  return manager.completedPlans;
});

/// Provider to get all paused reading plans
final pausedReadingPlansProvider = Provider<List<ReadingPlan>>((ref) {
  final manager = ref.watch(readingPlanManagerProvider);
  return manager.pausedPlans;
});

/// Provider to get all plans scheduled for today
final todaysReadingPlansProvider = Provider<List<ReadingPlan>>((ref) {
  final manager = ref.watch(readingPlanManagerProvider);
  return manager.getPlansForToday();
});

/// Provider to get today's unread plans
final todaysUnreadPlansProvider = Provider<List<ReadingPlan>>((ref) {
  final manager = ref.watch(readingPlanManagerProvider);
  return manager.getTodaysUnreadPlans();
});

/// Provider to get today's read plans
final todaysReadPlansProvider = Provider<List<ReadingPlan>>((ref) {
  final manager = ref.watch(readingPlanManagerProvider);
  return manager.getTodaysReadPlans();
});

/// Provider to get today's plans ordered by status (unread first)
final todaysPlansOrderedProvider = Provider<List<ReadingPlan>>((ref) {
  final manager = ref.watch(readingPlanManagerProvider);
  return manager.getTodaysPlansOrderedByStatus();
});

/// Provider to check if user should read today (any plan)
final shouldReadTodayProvider = Provider<bool>((ref) {
  final todaysPlans = ref.watch(todaysReadingPlansProvider);
  return todaysPlans.isNotEmpty;
});

/// Provider to check if user can add new plans
final canAddNewPlanProvider = Provider<bool>((ref) {
  final manager = ref.watch(readingPlanManagerProvider);
  return manager.canAddNewPlan();
});

/// Provider to get today's readings for all active plans
final todaysReadingsProvider = Provider<List<TodaysReading>>((ref) {
  final todaysPlans = ref.watch(todaysReadingPlansProvider);
  return todaysPlans.map((plan) => TodaysReading.fromPlan(plan)).toList();
});

/// Provider to get today's readings ordered by status
final todaysReadingsOrderedProvider = Provider<List<TodaysReading>>((ref) {
  final orderedPlans = ref.watch(todaysPlansOrderedProvider);
  return orderedPlans.map((plan) => TodaysReading.fromPlan(plan)).toList();
});

/// BACKWARD COMPATIBILITY: Provider for the first active reading plan (mimics old single plan behavior)
final currentReadingPlanProvider = Provider<ReadingPlan?>((ref) {
  final activePlans = ref.watch(activeReadingPlansProvider);
  return activePlans.isNotEmpty ? activePlans.first : null;
});

/// BACKWARD COMPATIBILITY: Provider for single today's reading (first plan)
final todaysReadingProvider = Provider<TodaysReading?>((ref) {
  final todaysReadings = ref.watch(todaysReadingsProvider);
  return todaysReadings.isNotEmpty ? todaysReadings.first : null;
});

class TodaysReading {
  final String planId;
  final String planName;
  final String book;
  final int startChapter;
  final int chaptersToRead;
  final bool hasReadToday;
  final BookCollection collection;

  const TodaysReading({
    required this.planId,
    required this.planName,
    required this.book,
    required this.startChapter,
    required this.chaptersToRead,
    required this.hasReadToday,
    required this.collection,
  });

  factory TodaysReading.fromPlan(ReadingPlan plan) {
    return TodaysReading(
      planId: plan.id,
      planName: plan.name,
      book: plan.progress.currentBook,
      startChapter: plan.progress.currentChapter,
      chaptersToRead: plan.chaptersPerDay,
      hasReadToday: plan.hasReadToday,
      collection: plan.collection,
    );
  }

  List<int> get chapterRange {
    return List.generate(chaptersToRead, (index) => startChapter + index);
  }

  String get displayText {
    if (chaptersToRead == 1) {
      return '$book $startChapter';
    } else {
      final endChapter = startChapter + chaptersToRead - 1;
      return '$book $startChapter-$endChapter';
    }
  }

  String get planDisplayText {
    return '$planName: $displayText';
  }
}

class ReadingPlanManagerNotifier extends StateNotifier<ReadingPlanManager> {
  ReadingPlanManagerNotifier() : super(ReadingPlanManager.empty()) {
    _loadPlans();
  }

  static const String _storageKey = 'reading_plan_manager';
  static const String _legacyStorageKey = 'reading_plan'; // Old single plan key

  Future<void> _loadPlans() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Check for new multi-plan format first
      final managerJson = prefs.getString(_storageKey);
      if (managerJson != null) {
        final managerMap = jsonDecode(managerJson);
        state = ReadingPlanManager.fromJson(managerMap);
        return;
      }
      
      // Check for legacy single plan format and migrate
      final legacyPlanJson = prefs.getString(_legacyStorageKey);
      if (legacyPlanJson != null) {
        await _migrateLegacyPlan(legacyPlanJson, prefs);
        return;
      }
      
      // No plans found, start with empty manager
      state = ReadingPlanManager.empty();
    } catch (e) {
      // If there's an error loading, keep empty state
      // ignore: avoid_print
      print('Error loading reading plans: $e');
      state = ReadingPlanManager.empty();
    }
  }

  Future<void> _migrateLegacyPlan(String legacyPlanJson, SharedPreferences prefs) async {
    try {
      final legacyPlanMap = jsonDecode(legacyPlanJson);
      final legacyPlan = ReadingPlan.fromJson(legacyPlanMap);
      
      // Create a new manager with the migrated plan
      state = ReadingPlanManager.empty().addPlan(legacyPlan);
      
      // Save in new format and remove old format
      await _savePlans();
      await prefs.remove(_legacyStorageKey);
      
      // ignore: avoid_print
      print('Successfully migrated legacy reading plan to new multi-plan format');
    } catch (e) {
      // ignore: avoid_print
      print('Error migrating legacy reading plan: $e');
    }
  }

  Future<void> _savePlans() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final managerJson = jsonEncode(state.toJson());
      await prefs.setString(_storageKey, managerJson);
    } catch (e) {
      // ignore: avoid_print
      print('Error saving reading plans: $e');
    }
  }

  Future<void> createPlan(ReadingPlan plan) async {
    try {
      state = state.addPlan(plan);
      await _savePlans();
    } catch (e) {
      // Re-throw to let UI handle the error
      rethrow;
    }
  }

  Future<void> updatePlan(ReadingPlan plan) async {
    state = state.updatePlan(plan);
    await _savePlans();
  }

  Future<void> removePlan(String planId) async {
    state = state.removePlan(planId);
    await _savePlans();
  }

  Future<void> pausePlan(String planId) async {
    final plan = state.plans.firstWhere((p) => p.id == planId);
    final pausedPlan = plan.copyWith(isActive: false);
    await updatePlan(pausedPlan);
  }

  Future<void> resumePlan(String planId) async {
    final plan = state.plans.firstWhere((p) => p.id == planId);
    final resumedPlan = plan.copyWith(isActive: true);
    await updatePlan(resumedPlan);
  }

  Future<void> markPlanReadToday(String planId) async {
    final plan = state.plans.firstWhere((p) => p.id == planId);
    final updatedProgress = _advanceProgress(plan.progress, plan.chaptersPerDay);
    final updatedPlan = plan.copyWith(
      progress: updatedProgress,
      hasReadToday: true,
    );
    await updatePlan(updatedPlan);
  }

  Future<void> markChapterComplete(String planId, String book, int chapter) async {
    final plan = state.plans.firstWhere((p) => p.id == planId);
    
    // If this is the current chapter, advance progress
    if (plan.progress.currentBook == book && plan.progress.currentChapter == chapter) {
      final updatedProgress = _advanceProgress(plan.progress, 1);
      final updatedPlan = plan.copyWith(
        progress: updatedProgress,
        hasReadToday: true,
      );
      await updatePlan(updatedPlan);
    }
  }

  Future<void> resetDailyStatus() async {
    // Reset hasReadToday for all plans (call this at start of new day)
    final updatedPlans = state.plans.map((plan) {
      return plan.copyWith(hasReadToday: false);
    }).toList();
    
    state = state.copyWith(plans: updatedPlans);
    await _savePlans();
  }

  Future<void> resetProgress(String planId) async {
    final plan = state.plans.firstWhere((p) => p.id == planId);
    final newProgress = ReadingProgress.start(plan.collection);
    final resetPlan = plan.copyWith(
      progress: newProgress,
      completedAt: null,
      hasReadToday: false,
    );
    await updatePlan(resetPlan);
  }

  Future<void> updatePlanSettings(
    String planId, {
    String? name,
    Set<DayOfWeek>? scheduledDays,
    int? chaptersPerDay,
    bool? remindersEnabled,
    TimeOfDay? reminderTime,
  }) async {
    final plan = state.plans.firstWhere((p) => p.id == planId);
    final updatedPlan = plan.copyWith(
      name: name ?? plan.name,
      scheduledDays: scheduledDays ?? plan.scheduledDays,
      chaptersPerDay: chaptersPerDay ?? plan.chaptersPerDay,
      remindersEnabled: remindersEnabled ?? plan.remindersEnabled,
      reminderTime: reminderTime ?? plan.reminderTime,
    );
    await updatePlan(updatedPlan);
  }

  ReadingProgress _advanceProgress(ReadingProgress current, int chaptersToAdvance) {
    var currentChapter = current.currentChapter;
    var bookIndex = current.bookIndex;
    var currentBook = current.currentBook;

    // Advance chapters
    currentChapter += chaptersToAdvance;

    // Check if we need to move to the next book
    // Note: This is simplified - in a real app you'd need actual chapter counts per book
    const averageChaptersPerBook = 30; // Simplified assumption
    
    while (currentChapter > averageChaptersPerBook && bookIndex < current.books.length - 1) {
      currentChapter -= averageChaptersPerBook;
      bookIndex++;
      currentBook = current.books[bookIndex];
    }

    // Check if we've completed the entire collection
    final isCompleted = bookIndex >= current.books.length - 1 && currentChapter > averageChaptersPerBook;

    return current.copyWith(
      currentBook: currentBook,
      currentChapter: currentChapter,
      bookIndex: bookIndex,
      isCompleted: isCompleted,
      lastReadDate: DateTime.now(),
    );
  }

  // BACKWARD COMPATIBILITY METHODS

  /// Legacy method for single plan compatibility
  Future<void> clearPlan() async {
    // Clear all plans for backward compatibility
    state = ReadingPlanManager.empty();
    await _savePlans();
  }

  /// Legacy method for single plan compatibility  
  Future<void> completeToday() async {
    final todaysPlans = state.getPlansForToday();
    if (todaysPlans.isNotEmpty) {
      await markPlanReadToday(todaysPlans.first.id);
    }
  }
}