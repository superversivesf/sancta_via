import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';

import '../models/reading_plan.dart';
import '../services/user_message_service.dart';

/// Custom exception for reading plan errors
class ReadingPlanException implements Exception {
  final String message;
  ReadingPlanException(this.message);
  
  @override
  String toString() => message;
}

/// Main provider for the reading plan manager
final readingPlanManagerProvider = StateNotifierProvider<ReadingPlanManagerNotifier, ReadingPlanManager>((ref) {
  return ReadingPlanManagerNotifier();
});

/// Provider to get all active reading plans (up to 5)
final activeReadingPlansProvider = Provider<List<ReadingPlan>>((ref) {
  final manager = ref.watch(readingPlanManagerProvider);
  return manager.activePlans;
});

/// Provider to check if user has read anything today
final hasReadTodayProvider = Provider<bool>((ref) {
  final manager = ref.watch(readingPlanManagerProvider);
  return manager.hasReadAnythingToday;
});

class ReadingPlanManagerNotifier extends StateNotifier<ReadingPlanManager> {
  ReadingPlanManagerNotifier() : super(ReadingPlanManager.empty()) {
    _loadPlans();
  }

  static const String _storageKey = 'reading_plan_manager_v2';
  static const String _legacyStorageKey = 'reading_plan_manager'; // Previous version key
  
  /// Load plans from storage with automatic daily reset check
  Future<void> _loadPlans() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Try new storage key first
      final managerJson = prefs.getString(_storageKey);
      if (managerJson != null) {
        final managerMap = jsonDecode(managerJson);
        state = ReadingPlanManager.fromJson(managerMap);
        await _checkAndResetDailyStatus();
        print('📖 Reading plans loaded successfully');
        return;
      }
      
      // Try legacy storage and migrate
      final legacyJson = prefs.getString(_legacyStorageKey);
      if (legacyJson != null) {
        await _migrateLegacyData(legacyJson, prefs);
        return;
      }
      
      // No plans found, start with empty manager
      state = ReadingPlanManager.empty();
      print('📱 Started with empty reading plan manager');
      
    } catch (e) {
      print('❌ Error loading reading plans: $e');
      state = ReadingPlanManager.empty();
      _showErrorMessage('Failed to load reading plans. Starting fresh.');
    }
  }

  /// Migrate data from complex legacy format to simplified format
  Future<void> _migrateLegacyData(String legacyJson, SharedPreferences prefs) async {
    try {
      final legacyData = jsonDecode(legacyJson);
      final legacyPlans = (legacyData['plans'] as List?)?.map((planJson) {
        // Convert legacy plan format to simplified format
        return ReadingPlan(
          id: planJson['id'],
          name: planJson['name'] ?? 'Reading Plan',
          collection: BookCollection.values.firstWhere((e) => e.name == planJson['collection']),
          progress: ReadingProgress.fromJson(planJson['progress']),
          createdAt: DateTime.parse(planJson['createdAt']),
          completedAt: planJson['completedAt'] != null ? DateTime.parse(planJson['completedAt']) : null,
          isActive: planJson['isActive'] ?? true,
        );
      }).toList() ?? <ReadingPlan>[];

      // Create new simplified manager
      final now = DateTime.now();
      state = ReadingPlanManager(
        plans: legacyPlans,
        lastUpdated: now,
        hasReadAnythingToday: false, // Reset daily status during migration
        lastResetDate: DateTime(now.year, now.month, now.day),
      );

      // Save in new format and remove legacy
      await _savePlans();
      await prefs.remove(_legacyStorageKey);
      
      print('✅ Successfully migrated legacy reading plans to simplified format');
      _showSuccessMessage('Reading plans updated to new simplified system!', backgroundColor: null);
      
    } catch (e) {
      print('❌ Error migrating legacy data: $e');
      state = ReadingPlanManager.empty();
      _showErrorMessage('Error migrating reading plans. Starting fresh.');
    }
  }

  /// Check if daily reset is needed and perform it
  Future<void> _checkAndResetDailyStatus() async {
    if (state.needsDailyReset) {
      print('📅 New day detected - resetting daily reading status');
      final now = DateTime.now();
      state = state.copyWith(
        hasReadAnythingToday: false,
        lastResetDate: DateTime(now.year, now.month, now.day),
      );
      await _savePlans();
    }
  }

  /// Save plans to storage
  Future<void> _savePlans() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final managerJson = jsonEncode(state.toJson());
      await prefs.setString(_storageKey, managerJson);
      print('💾 Reading plans saved successfully');
    } catch (e) {
      print('❌ Error saving reading plans: $e');
      _showErrorMessage('Failed to save reading progress.');
    }
  }

  /// Create a new reading plan
  Future<void> createPlan(ReadingPlan plan, {Color? successColor}) async {
    try {
      state = state.addPlan(plan);
      await _savePlans();
      _showSuccessMessage('Reading plan "${plan.name}" created!', backgroundColor: successColor);
    } catch (e) {
      _showErrorMessage('Failed to create reading plan: $e');
      rethrow;
    }
  }

  /// Update an existing reading plan
  Future<void> updatePlan(ReadingPlan plan) async {
    try {
      state = state.updatePlan(plan);
      await _savePlans();
    } catch (e) {
      _showErrorMessage('Failed to update reading plan.');
      rethrow;
    }
  }

  /// Remove a reading plan
  Future<void> removePlan(String planId, {Color? successColor}) async {
    try {
      final plan = state.plans.firstWhere((p) => p.id == planId);
      state = state.removePlan(planId);
      await _savePlans();
      _showSuccessMessage('Reading plan "${plan.name}" removed.', backgroundColor: successColor);
    } catch (e) {
      _showErrorMessage('Failed to remove reading plan.');
      rethrow;
    }
  }

  /// Pause a reading plan
  Future<void> pausePlan(String planId, {Color? successColor}) async {
    try {
      final plan = state.plans.firstWhere((p) => p.id == planId);
      final pausedPlan = plan.copyWith(isActive: false);
      await updatePlan(pausedPlan);
      _showSuccessMessage('Reading plan "${plan.name}" paused.', backgroundColor: successColor);
    } catch (e) {
      _showErrorMessage('Failed to pause reading plan.');
      rethrow;
    }
  }

  /// Resume a reading plan
  Future<void> resumePlan(String planId, {Color? successColor}) async {
    try {
      final plan = state.plans.firstWhere((p) => p.id == planId);
      final resumedPlan = plan.copyWith(isActive: true);
      await updatePlan(resumedPlan);
      _showSuccessMessage('Reading plan "${plan.name}" resumed.', backgroundColor: successColor);
    } catch (e) {
      _showErrorMessage('Failed to resume reading plan.');
      rethrow;
    }
  }

  /// Mark that the user has read a chapter from a specific plan
  Future<void> markChapterRead(String planId, String book, int chapter, {Color? successColor}) async {
    try {
      await _checkAndResetDailyStatus(); // Ensure daily status is current
      
      final plan = state.plans.firstWhere(
        (p) => p.id == planId,
        orElse: () => throw ReadingPlanException('Reading plan not found'),
      );
      
      // Validate chapter
      if (book.isEmpty || chapter <= 0) {
        throw ReadingPlanException('Invalid chapter: $book $chapter');
      }
      
      // Check if book is in the plan's collection
      if (!plan.collection.bookNames.contains(book)) {
        throw ReadingPlanException(
          'Book "$book" is not part of your ${plan.collection.displayName} reading plan.'
        );
      }
      
      // If this is the next chapter in the plan, advance the plan
      if (plan.progress.currentBook == book && plan.progress.currentChapter == chapter) {
        final updatedProgress = _advanceProgress(plan.progress);
        final updatedPlan = plan.copyWith(progress: updatedProgress);
        
        // ✨ NEW: Completion detection logic
        final wasCompleted = plan.isCompleted;
        final isNowCompleted = updatedPlan.isCompleted;
        
        // Mark as read today and update plan
        state = state.updatePlan(updatedPlan).markReadToday();
        await _savePlans();
        
        // ✨ NEW: Show completion dialog if plan just completed
        if (!wasCompleted && isNowCompleted) {
          // Small delay to ensure UI updates before dialog
          Future.delayed(const Duration(milliseconds: 500), () {
            _showCompletionDialog(updatedPlan);
          });
        }
        
        _showSuccessMessage('Completed $book $chapter', backgroundColor: successColor);
      } else {
        // Just mark as read today without advancing the plan
        state = state.markReadToday();
        await _savePlans();
        
        _showSuccessMessage('Marked as read for today', backgroundColor: successColor);
      }
      
    } catch (e) {
      debugPrint('❌ Error marking chapter as read: $e');
      
      if (e is ReadingPlanException) {
        _showErrorMessage(e.message);
      } else {
        _showErrorMessage('Unable to mark chapter as read. Please try again.');
      }
      
      rethrow;
    }
  }

  /// Advance a plan to the next chapter regardless of which chapter was read
  Future<void> advancePlan(String planId, {Color? successColor}) async {
    try {
      await _checkAndResetDailyStatus();
      
      final plan = state.plans.firstWhere(
        (p) => p.id == planId,
        orElse: () => throw ReadingPlanException('Reading plan not found'),
      );
      
      final updatedProgress = _advanceProgress(plan.progress);
      final updatedPlan = plan.copyWith(progress: updatedProgress);
      
      // ✨ NEW: Completion detection logic
      final wasCompleted = plan.isCompleted;
      final isNowCompleted = updatedPlan.isCompleted;
      
      state = state.updatePlan(updatedPlan).markReadToday();
      await _savePlans();
      
      // ✨ NEW: Show completion dialog if plan just completed
      if (!wasCompleted && isNowCompleted) {
        // Small delay to ensure UI updates before dialog
        Future.delayed(const Duration(milliseconds: 500), () {
          _showCompletionDialog(updatedPlan);
        });
      }
      
      _showSuccessMessage('Advanced to ${updatedProgress.nextChapterText}', backgroundColor: successColor);
      
    } catch (e) {
      debugPrint('❌ Error advancing plan: $e');
      _showErrorMessage('Unable to advance reading plan.');
      rethrow;
    }
  }

  /// Reset a plan's progress to the beginning
  Future<void> resetProgress(String planId, {Color? successColor}) async {
    try {
      final plan = state.plans.firstWhere((p) => p.id == planId);
      final newProgress = ReadingProgress.start(plan.collection);
      final resetPlan = plan.copyWith(
        progress: newProgress,
        completedAt: null,
      );
      await updatePlan(resetPlan);
      _showSuccessMessage('Reading plan "${plan.name}" progress reset.', backgroundColor: successColor);
    } catch (e) {
      _showErrorMessage('Failed to reset reading plan progress.');
      rethrow;
    }
  }

  /// Clear all reading plans
  Future<void> clearAllPlans({Color? successColor}) async {
    try {
      state = ReadingPlanManager.empty();
      await _savePlans();
      _showSuccessMessage('All reading plans cleared.', backgroundColor: successColor);
    } catch (e) {
      _showErrorMessage('Failed to clear reading plans.');
      rethrow;
    }
  }

  /// Reset daily reading status to false
  Future<void> resetDailyStatus({Color? successColor}) async {
    try {
      state = state.copyWith(hasReadAnythingToday: false);
      await _savePlans();
      _showSuccessMessage('Daily reading status has been reset.', backgroundColor: successColor);
    } catch (e) {
      _showErrorMessage('Failed to reset daily status.');
      rethrow;
    }
  }

  /// Show completion dialog when a plan is completed
  void _showCompletionDialog(ReadingPlan completedPlan) {
    final context = UserMessageService.navigatorKey?.currentContext;
    if (context == null) return;

    // Calculate stats
    final daysElapsed = completedPlan.completedAt != null 
        ? completedPlan.completedAt!.difference(completedPlan.createdAt).inDays + 1
        : 0;
    final totalCompletedPlans = state.completedPlans.length;

    showDialog(
      context: context,
      barrierDismissible: false, // Require user action
      builder: (dialogContext) {
        // Get theme colors for the dialog
        final theme = Theme.of(dialogContext);
        final primaryColor = theme.colorScheme.primary;
        
        return AlertDialog(
          title: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('🎉 Plan Completed! 🎉'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Plan name and collection
              Text(
                '"${completedPlan.name}"',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              
              // Stats
              _buildStatRow('Collection:', completedPlan.collection.displayName),
              const SizedBox(height: 8),
              _buildStatRow('Started:', _formatDate(completedPlan.createdAt)),
              const SizedBox(height: 8),
              _buildStatRow('Completed:', _formatDate(completedPlan.completedAt)),
              const SizedBox(height: 8),
              _buildStatRow('Time taken:', '$daysElapsed day${daysElapsed != 1 ? 's' : ''}'),
              const SizedBox(height: 16),
              
              // Achievement
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: primaryColor.withValues(alpha: 0.3)),
                ),
                child: Text(
                  totalCompletedPlans == 1 
                      ? 'Your first completed reading plan! 🌟'
                      : 'This is your ${_getOrdinalNumber(totalCompletedPlans)} completed plan! 🌟',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: primaryColor,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Continue Reading'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                // Navigate to reading plans to create a new one
                if (context.mounted) {
                  context.push('/reading-plan');
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
              ),
              child: const Text('Start New Plan'),
            ),
          ],
        );
      },
    );
  }

  /// Helper method to build stat rows
  Widget _buildStatRow(String label, String value) {
    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ),
        Expanded(
          child: Text(value),
        ),
      ],
    );
  }

  /// Helper method to format dates
  String _formatDate(DateTime? date) {
    if (date == null) return 'Unknown';
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  /// Helper method to get ordinal numbers (1st, 2nd, 3rd, etc.)
  String _getOrdinalNumber(int number) {
    if (number >= 11 && number <= 13) {
      return '${number}th';
    }
    switch (number % 10) {
      case 1:
        return '${number}st';
      case 2:
        return '${number}nd';
      case 3:
        return '${number}rd';
      default:
        return '${number}th';
    }
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
    '1 John': 5, '2 John': 1, '3 John': 1, 'Jude': 1, 'Revelation of John': 22,
  };

  /// Advance reading progress by one chapter
  ReadingProgress _advanceProgress(ReadingProgress current) {
    var currentChapter = current.currentChapter;
    var bookIndex = current.bookIndex;
    var currentBook = current.currentBook;

    // Get the chapter count for the current book
    final bookChapterCount = _chapterCounts[currentBook] ?? 30; // Fallback to 30

    // Check if we can stay in the current book
    if (currentChapter < bookChapterCount) {
      // Move to next chapter in same book
      currentChapter++;
    } else {
      // Move to next book
      bookIndex++;
      if (bookIndex < current.books.length) {
        currentBook = current.books[bookIndex];
        currentChapter = 1;
      } else {
        // We've completed all books
        return current.copyWith(
          isCompleted: true,
          lastReadDate: DateTime.now(),
        );
      }
    }

    return current.copyWith(
      currentBook: currentBook,
      currentChapter: currentChapter,
      bookIndex: bookIndex,
      lastReadDate: DateTime.now(),
    );
  }

  /// Show success message to user
  void _showSuccessMessage(String message, {Color? backgroundColor}) {
    UserMessageService().showSuccess(message, backgroundColor: backgroundColor);
  }

  /// Show error message to user
  void _showErrorMessage(String message) {
    UserMessageService().showError(message);
  }
}
