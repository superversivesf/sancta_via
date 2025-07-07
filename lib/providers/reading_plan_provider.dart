import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/reading_plan.dart';

/// Provider for the current reading plan
final readingPlanProvider = StateNotifierProvider<ReadingPlanNotifier, ReadingPlan?>((ref) {
  return ReadingPlanNotifier();
});

/// Provider to get the current reading plan
final currentReadingPlanProvider = Provider<ReadingPlan?>((ref) {
  return ref.watch(readingPlanProvider);
});

/// Provider to check if user should read today
final shouldReadTodayProvider = Provider<bool>((ref) {
  final plan = ref.watch(readingPlanProvider);
  return plan?.shouldReadToday() ?? false;
});

/// Provider to get today's reading
final todaysReadingProvider = Provider<TodaysReading?>((ref) {
  final plan = ref.watch(readingPlanProvider);
  if (plan == null || !plan.shouldReadToday()) return null;
  
  return TodaysReading(
    book: plan.progress.currentBook,
    startChapter: plan.progress.currentChapter,
    chaptersToRead: plan.chaptersPerDay,
  );
});

class TodaysReading {
  final String book;
  final int startChapter;
  final int chaptersToRead;

  const TodaysReading({
    required this.book,
    required this.startChapter,
    required this.chaptersToRead,
  });

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
}

class ReadingPlanNotifier extends StateNotifier<ReadingPlan?> {
  ReadingPlanNotifier() : super(null) {
    _loadPlan();
  }

  static const String _storageKey = 'reading_plan';

  Future<void> _loadPlan() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final planJson = prefs.getString(_storageKey);
      
      if (planJson != null) {
        final planMap = jsonDecode(planJson);
        state = ReadingPlan.fromJson(planMap);
      }
    } catch (e) {
      // If there's an error loading, keep null state
      // ignore: avoid_print
      print('Error loading reading plan: $e');
    }
  }

  Future<void> _savePlan() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (state != null) {
        final planJson = jsonEncode(state!.toJson());
        await prefs.setString(_storageKey, planJson);
      } else {
        await prefs.remove(_storageKey);
      }
    } catch (e) {
      // ignore: avoid_print
      print('Error saving reading plan: $e');
    }
  }

  Future<void> createPlan(ReadingPlan plan) async {
    state = plan;
    await _savePlan();
  }

  Future<void> clearPlan() async {
    state = null;
    await _savePlan();
  }

  Future<void> markChapterComplete(String book, int chapter) async {
    if (state == null) return;

    final currentPlan = state!;
    var progress = currentPlan.progress;

    // If this is the current chapter, advance progress
    if (progress.currentBook == book && progress.currentChapter == chapter) {
      progress = _advanceProgress(progress, currentPlan.chaptersPerDay);
    }

    state = currentPlan.copyWith(progress: progress);
    await _savePlan();
  }

  Future<void> completeToday() async {
    if (state == null) return;

    final currentPlan = state!;
    final progress = _advanceProgress(currentPlan.progress, currentPlan.chaptersPerDay);

    state = currentPlan.copyWith(progress: progress);
    await _savePlan();
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
    );
  }

  Future<void> resetProgress() async {
    if (state == null) return;

    final currentPlan = state!;
    final newProgress = ReadingProgress.start(currentPlan.collection);

    state = currentPlan.copyWith(
      progress: newProgress,
      completedAt: null,
    );
    await _savePlan();
  }

  Future<void> updatePlanSettings({
    ReadingFrequency? frequency,
    int? chaptersPerDay,
    bool? remindersEnabled,
    TimeOfDay? reminderTime,
  }) async {
    if (state == null) return;

    state = state!.copyWith(
      frequency: frequency ?? state!.frequency,
      chaptersPerDay: chaptersPerDay ?? state!.chaptersPerDay,
      remindersEnabled: remindersEnabled ?? state!.remindersEnabled,
      reminderTime: reminderTime ?? state!.reminderTime,
    );
    await _savePlan();
  }
}
