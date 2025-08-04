import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/reading_plan.dart';

/// Provider for the reading plan manager (multiple plans)
final readingPlanManagerProvider = StateNotifierProvider<ReadingPlanManagerNotifier, ReadingPlanManager>((ref) {
  final notifier = ReadingPlanManagerNotifier();
  // Automatically check for daily reset and app state when provider is accessed
  notifier.checkDailyResetAndAppState();
  return notifier;
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

/// Provider to get the current reading position (where user should read next)
final currentReadingPositionProvider = Provider<TodaysReading?>((ref) {
  final activePlans = ref.watch(activeReadingPlansProvider);
  
  // Get the first active plan as the primary reading position
  if (activePlans.isEmpty) return null;
  
  final primaryPlan = activePlans.first;
  return TodaysReading.fromPlan(primaryPlan);
});

/// Provider to get where the user should continue reading (current progress position)
final continueReadingPositionProvider = Provider<List<ContinueReading>>((ref) {
  final activePlans = ref.watch(activeReadingPlansProvider);
  return activePlans.map((plan) => ContinueReading.fromPlan(plan)).toList();
});

/// Provider to determine if user should auto-navigate to reading
final shouldAutoNavigateToReadingProvider = Provider<bool>((ref) {
  final currentPosition = ref.watch(currentReadingPositionProvider);
  final todaysUnread = ref.watch(todaysUnreadPlansProvider);
  
  // Auto-navigate if there are unread plans for today or if user has active plans
  return currentPosition != null && todaysUnread.isNotEmpty;
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
  
  // These represent what SHOULD be read today according to schedule
  final String book;
  final int startChapter;
  final int chaptersToRead;
  
  // These represent where the user actually is in their reading
  final String currentBook;
  final int currentChapter;
  
  final bool hasReadToday;
  final BookCollection collection;

  const TodaysReading({
    required this.planId,
    required this.planName,
    required this.book,
    required this.startChapter,
    required this.chaptersToRead,
    required this.currentBook,
    required this.currentChapter,
    required this.hasReadToday,
    required this.collection,
  });

  factory TodaysReading.fromPlan(ReadingPlan plan) {
    // Use the scheduled position for "today's reading"
    return TodaysReading(
      planId: plan.id,
      planName: plan.name,
      book: plan.progress.scheduledBook, 
      startChapter: plan.progress.scheduledChapter,
      chaptersToRead: plan.chaptersPerDay,
      currentBook: plan.progress.currentBook,
      currentChapter: plan.progress.currentChapter,
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
  
  // Display text for where user actually is
  String get currentPositionText {
    return '$currentBook $currentChapter';
  }

  // Check if the user has read ahead of today's scheduled reading
  bool get hasReadAhead {
    if (currentBook != book) {
      // Different books - need to check book order (simplified for now)
      return true; // Assume ahead if different book
    }
    return currentChapter > startChapter;
  }

  // Check if the user has fallen behind the scheduled reading
  bool get hasFallenBehind {
    if (currentBook != book) {
      // Different books - need to check book order (simplified for now)
      return false; // Assume not behind if different book
    }
    return currentChapter < startChapter;
  }
}

class ContinueReading {
  final String planId;
  final String planName;
  final String book;
  final int chapter;
  final BookCollection collection;

  const ContinueReading({
    required this.planId,
    required this.planName,
    required this.book,
    required this.chapter,
    required this.collection,
  });

  factory ContinueReading.fromPlan(ReadingPlan plan) {
    // Use the current reading position (where they should continue)
    return ContinueReading(
      planId: plan.id,
      planName: plan.name,
      book: plan.progress.currentBook,
      chapter: plan.progress.currentChapter,
      collection: plan.collection,
    );
  }

  String get displayText {
    return '$book $chapter';
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
  
  /// Helper method to normalize DateTime to midnight of the same day
  /// This ensures predictable daily advancement behavior for reading plans
  static DateTime _normalizeToMidnight(DateTime dateTime) {
    return DateTime(dateTime.year, dateTime.month, dateTime.day);
  }

  Future<void> _loadPlans() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Check for new multi-plan format first
      final managerJson = prefs.getString(_storageKey);
      if (managerJson != null) {
        final managerMap = jsonDecode(managerJson);
        state = ReadingPlanManager.fromJson(managerMap);
        
        // Check if we need to automatically reset daily status
        await _checkAndResetDailyStatus();
        return;
      }
      
      // Check for legacy single plan format and migrate
      final legacyPlanJson = prefs.getString(_legacyStorageKey);
      if (legacyPlanJson != null) {
        await _migrateLegacyPlan(legacyPlanJson, prefs);
        await _checkAndResetDailyStatus();
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

  /// Automatically check and reset daily status if a new day has started
  Future<void> _checkAndResetDailyStatus() async {
    if (state.needsDailyReset) {
      await resetDailyStatus();
    }
  }

  /// Public method to manually trigger daily reset check and app state management
  Future<void> checkDailyResetAndAppState() async {
    await _checkAndResetDailyStatus();
    await _handleAppReopen();
  }
  
  /// Check if we need to perform daily reset and do it if necessary
  /// This should be called when app resumes from background
  Future<void> checkAndPerformDailyReset() async {
    if (state.needsDailyReset) {
      await _performDailyReset();
    }
  }

  /// Perform the actual daily reset with enhanced logging
  Future<void> _performDailyReset() async {
    final now = DateTime.now();
    final resetMidnight = _normalizeToMidnight(now);
    
    // Reset hasReadToday to false for all plans and advance scheduled reading
    final resetPlans = state.plans.map((plan) {
      if (!plan.isActive || plan.isCompleted) {
        // Just reset the daily status for inactive/completed plans
        return plan.copyWith(hasReadToday: false);
      }
      
      // For active plans, advance the scheduled reading
      final updatedProgress = _advanceScheduledProgress(plan.progress, plan.chaptersPerDay);
      return plan.copyWith(
        hasReadToday: false,
        progress: updatedProgress,
      );
    }).toList();

    // Update state with reset plans and new reset date
    state = state.copyWith(
      plans: resetPlans,
      lastDailyReset: resetMidnight,
      lastUpdated: now,
    );

    // Save to persistent storage
    await _savePlans();
    
    // Enhanced logging for debugging
    final activePlanCount = resetPlans.where((p) => p.isActive && !p.isCompleted).length;
    // ignore: avoid_print
    print('🔄 Daily reset performed at $now');
    // ignore: avoid_print
    print('   Reset $activePlanCount active plans to hasReadToday: false');
    // ignore: avoid_print
    print('   New daily reset date: $resetMidnight');
  }
  
  /// Handle when app is reopened from background - check if we should advance to next reading
  Future<void> _handleAppReopen() async {
    // This method will be called whenever the app is opened or provider is accessed
    // It ensures the user sees their current reading position
    // The actual navigation will be handled by the UI layer
    
    // For now, just ensure daily status is current
    // UI components can check todaysReadingsProvider to know what to show
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

  /// Continue reading - advance to next reading for getting ahead (resets daily status)
  Future<void> continueReading(String planId) async {
    final plan = state.plans.firstWhere((p) => p.id == planId);
    final updatedProgress = _advanceProgress(plan.progress, plan.chaptersPerDay);
    final updatedPlan = plan.copyWith(
      progress: updatedProgress,
      hasReadToday: false, // Reset daily status to allow getting ahead
    );
    await updatePlan(updatedPlan);
  }

  /// Advance to next chapter without changing daily reading status
  Future<void> advanceToNextChapter(String planId) async {
    final plan = state.plans.firstWhere((p) => p.id == planId);
    final updatedProgress = _advanceProgress(plan.progress, plan.chaptersPerDay);
    final updatedPlan = plan.copyWith(
      progress: updatedProgress,
      // Keep hasReadToday unchanged - don't reset the daily reading status
    );
    await updatePlan(updatedPlan);
  }

  /// Mark current reading as complete when user visits the chapter
  Future<void> markCurrentReadingAsComplete(String planId) async {
    final plan = state.plans.firstWhere((p) => p.id == planId);
    final updatedPlan = plan.copyWith(hasReadToday: true);
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
    // This is the public API method - delegate to the internal reset method
    await _performDailyReset();
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

  /// Map of Bible book names to their chapter counts
  static const Map<String, int> _chapterCounts = {
    // Old Testament
    'Genesis': 50, 'Exodus': 40, 'Leviticus': 27, 'Numbers': 36, 'Deuteronomy': 34,
    'Joshua': 24, 'Judges': 21, 'Ruth': 4, '1 Samuel': 31, '2 Samuel': 24,
    '1 Kings': 22, '2 Kings': 25, '1 Chronicles': 29, '2 Chronicles': 36,
    'Ezra': 10, 'Nehemiah': 13, 'Esther': 10, 'Job': 42, 'Psalms': 150,
    'Proverbs': 31, 'Ecclesiastes': 12, 'Song of Songs': 8, 'Isaiah': 66,
    'Jeremiah': 52, 'Lamentations': 5, 'Ezekiel': 48, 'Daniel': 12,
    'Hosea': 14, 'Joel': 3, 'Amos': 9, 'Obadiah': 1, 'Jonah': 4,
    'Micah': 7, 'Nahum': 3, 'Habakkuk': 3, 'Zephaniah': 3, 'Haggai': 2,
    'Zechariah': 14, 'Malachi': 4,
    // New Testament
    'Matthew': 28, 'Mark': 16, 'Luke': 24, 'John': 21, 'Acts': 28,
    'Romans': 16, '1 Corinthians': 16, '2 Corinthians': 13, 'Galatians': 6,
    'Ephesians': 6, 'Philippians': 4, 'Colossians': 4, '1 Thessalonians': 5,
    '2 Thessalonians': 3, '1 Timothy': 6, '2 Timothy': 4, 'Titus': 3,
    'Philemon': 1, 'Hebrews': 13, 'James': 5, '1 Peter': 5, '2 Peter': 3,
    '1 John': 5, '2 John': 1, '3 John': 1, 'Jude': 1, 'Revelation': 22,
  };

  /// Advance only the scheduled reading position (used during daily reset)
  ReadingProgress _advanceScheduledProgress(ReadingProgress current, int chaptersToAdvance) {
    var scheduledChapter = current.scheduledChapter;
    var scheduledBookIndex = current.scheduledBookIndex;
    var scheduledBook = current.scheduledBook;
    var chaptersRemaining = chaptersToAdvance;

    while (chaptersRemaining > 0 && scheduledBookIndex < current.books.length) {
      final bookChapterCount = _chapterCounts[scheduledBook] ?? 30; // Fallback to 30
      
      // Check if we can complete the remaining chapters in the current book
      if (scheduledChapter + chaptersRemaining <= bookChapterCount) {
        // Stay in current book
        scheduledChapter += chaptersRemaining;
        chaptersRemaining = 0;
      } else {
        // Need to move to next book(s)
        chaptersRemaining -= (bookChapterCount - scheduledChapter + 1);
        
        // Move to next book
        scheduledBookIndex++;
        if (scheduledBookIndex < current.books.length) {
          scheduledBook = current.books[scheduledBookIndex];
          scheduledChapter = 1;
        } else {
          // We've completed all books in the schedule
          break;
        }
      }
    }

    return current.copyWith(
      scheduledBook: scheduledBook,
      scheduledChapter: scheduledChapter,
      scheduledBookIndex: scheduledBookIndex,
      lastScheduleAdvancement: DateTime.now(),
    );
  }

  ReadingProgress _advanceProgress(ReadingProgress current, int chaptersToAdvance) {
    var currentChapter = current.currentChapter;
    var bookIndex = current.bookIndex;
    var currentBook = current.currentBook;
    var chaptersRemaining = chaptersToAdvance;

    while (chaptersRemaining > 0 && bookIndex < current.books.length) {
      final bookChapterCount = _chapterCounts[currentBook] ?? 30; // Fallback to 30
      
      // Check if we can complete the remaining chapters in the current book
      if (currentChapter + chaptersRemaining <= bookChapterCount) {
        // Stay in current book
        currentChapter += chaptersRemaining;
        chaptersRemaining = 0;
      } else {
        // Need to move to next book(s)
        chaptersRemaining -= (bookChapterCount - currentChapter + 1);
        
        // Move to next book
        bookIndex++;
        if (bookIndex < current.books.length) {
          currentBook = current.books[bookIndex];
          currentChapter = 1;
        } else {
          // We've completed all books
          break;
        }
      }
    }

    // Check if we've completed the entire collection
    final isCompleted = bookIndex >= current.books.length ||
        (bookIndex == current.books.length - 1 && 
         currentChapter > (_chapterCounts[currentBook] ?? 30));

    return current.copyWith(
      currentBook: currentBook,
      currentChapter: isCompleted ? currentChapter : currentChapter,
      bookIndex: isCompleted ? current.books.length : bookIndex,
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