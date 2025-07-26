import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/novena.dart';

import '../../../utils/logger.dart';

// Key for SharedPreferences storage
const String _activeNovenaKey = 'active_novena_v1';

// State notifier for managing active novena
class NovenaStateNotifier extends StateNotifier<ActiveNovena?> {
  
  NovenaStateNotifier() : super(null) {
    _loadActiveNovena();
  }

  /// Helper method to format TimeOfDay for logging
  String _formatTimeOfDay(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  // Load active novena from storage
  Future<void> _loadActiveNovena() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final activeNovenaJson = prefs.getString(_activeNovenaKey);
      
      if (activeNovenaJson != null) {
        final activeNovenaData = json.decode(activeNovenaJson) as Map<String, dynamic>;
        final activeNovena = ActiveNovena.fromJson(activeNovenaData);
        
        // Check if novena has expired (more than 9 days since start)
        final daysSinceStart = DateTime.now().difference(activeNovena.startDate).inDays;
        if (daysSinceStart >= 9 || activeNovena.isComplete) {
          // Clear expired/completed novena
          await clearActiveNovena();
        } else {
          state = activeNovena;
          AppLogger.debug('✅ Loaded active novena: ${activeNovena.novenaId}', 'NOVENA_STATE');
          AppLogger.debug('📅 Start Date: ${activeNovena.startDate}', 'NOVENA_STATE');
          AppLogger.debug('📊 Completed Days: ${activeNovena.completedDays}', 'NOVENA_STATE');
          AppLogger.debug('🎯 Current Spiritual Day: ${activeNovena.spiritualDay}', 'NOVENA_STATE');
        }
      }
    } catch (e) {
      AppLogger.error('Error loading active novena', e, null, 'NOVENA_STATE');
      // If there's an error loading, clear the storage
      await clearActiveNovena();
    }
  }

  // Save active novena to storage
  Future<void> _saveActiveNovena() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (state != null) {
        final novenaJson = json.encode(state!.toJson());
        await prefs.setString(_activeNovenaKey, novenaJson);
        AppLogger.debug('Saved active novena state', 'NOVENA_STATE');
      } else {
        await prefs.remove(_activeNovenaKey);
        AppLogger.debug('Cleared active novena from storage', 'NOVENA_STATE');
      }
    } catch (e) {
      AppLogger.error('Failed to save active novena', e, null, 'NOVENA_STATE');
    }
  }

  // Start a new novena
  Future<void> startNovena(ActiveNovena activeNovena, String novenaTitle) async {
    AppLogger.info('🚀 Starting novena: $novenaTitle', 'NOVENA_STATE');
    AppLogger.debug('📅 Start Date: ${activeNovena.startDate}', 'NOVENA_STATE');
    AppLogger.debug('⏰ Reminder Time: ${_formatTimeOfDay(activeNovena.reminderTime)}', 'NOVENA_STATE');
    state = activeNovena;
    await _saveActiveNovena();
  }

  // Update state without scheduling new notifications (for debug/reset)
  Future<void> updateState(ActiveNovena activeNovena) async {
    AppLogger.debug('Updating state without rescheduling notifications', 'NOVENA_STATE');
    state = activeNovena;
    await _saveActiveNovena();
  }

  // Mark a specific day as complete
  Future<void> markDayComplete(int dayNumber) async {
    AppLogger.debug('🎯 Marking day $dayNumber complete', 'NOVENA_STATE');
    final current = state;
    if (current == null) {
      AppLogger.warning('No active novena found', 'NOVENA_STATE');
      return;
    }

    if (dayNumber < 1 || dayNumber > 9) {
      AppLogger.warning('Invalid day number: $dayNumber', 'NOVENA_STATE');
      return;
    }
    
    if (current.isDayComplete(dayNumber)) {
      AppLogger.debug('Day $dayNumber is already complete', 'NOVENA_STATE');
      return;
    }

    // Update completed days - ensure array is large enough
    final updatedCompletedDays = List<bool>.from(current.completedDays);
    while (updatedCompletedDays.length < 9) {
      updatedCompletedDays.add(false);
    }
    
    updatedCompletedDays[dayNumber - 1] = true;
    AppLogger.debug('✅ Updated completion status for day $dayNumber', 'NOVENA_STATE');

    final updatedNovena = current.copyWith(
      completedDays: updatedCompletedDays,
      lastCompletedDate: DateTime.now(),
    );

    state = updatedNovena;
    await _saveActiveNovena();
    
    AppLogger.info('✅ Day $dayNumber marked complete', 'NOVENA_STATE');
    
    // Check if entire novena is complete
    if (updatedNovena.isComplete) {
      AppLogger.info('🌟 Novena completed! All 9 days done.', 'NOVENA_STATE');
    }
  }

  // Mark today's spiritual day as complete (kept for backward compatibility)
  Future<void> markTodayComplete() async {
    final current = state;
    if (current == null) {
      AppLogger.warning('No active novena found', 'NOVENA_STATE');
      return;
    }

    final spiritualDay = current.spiritualDay;
    await markDayComplete(spiritualDay);
  }

  // Clear active novena (cancel or complete)
  Future<void> clearActiveNovena() async {
    AppLogger.info('🗑️ Clearing active novena', 'NOVENA_STATE');
    state = null;
    await _saveActiveNovena();
  }

  // Update reminder settings
  Future<void> updateReminderSettings({
    required TimeOfDay reminderTime,
    required ReminderInterval reminderFrequency,
    required String novenaTitle,
  }) async {
    final current = state;
    if (current == null) {
      AppLogger.warning('Cannot update reminder settings: no active novena', 'NOVENA_STATE');
      return;
    }

    AppLogger.debug('⚙️ Updating reminder settings: ${_formatTimeOfDay(reminderTime)}, ${reminderFrequency.displayName}', 'NOVENA_STATE');

    state = current.copyWith(
      reminderTime: reminderTime,
      reminderFrequency: reminderFrequency,
    );

    await _saveActiveNovena();
  }


}

// Novena state provider without notification dependency
final novenaStateProvider = StateNotifierProvider<NovenaStateNotifier, ActiveNovena?>((ref) {
  return NovenaStateNotifier();
});

// Computed providers for convenience
final hasActiveNovenaProvider = Provider<bool>((ref) {
  return ref.watch(novenaStateProvider) != null;
});

final novenaProgressProvider = Provider<double>((ref) {
  final activeNovena = ref.watch(novenaStateProvider);
  return activeNovena?.progressPercentage ?? 0.0;
});

final currentNovenaSpiritualDayProvider = Provider<int?>((ref) {
  final activeNovena = ref.watch(novenaStateProvider);
  return activeNovena?.spiritualDay;
});

final isTodayCompleteProvider = Provider<bool>((ref) {
  final activeNovena = ref.watch(novenaStateProvider);
  return activeNovena?.isTodayComplete ?? false;
});

final accessibleCompletedCountProvider = Provider<int>((ref) {
  final activeNovena = ref.watch(novenaStateProvider);
  return activeNovena?.accessibleCompletedCount ?? 0;
});

final canAccessTodayProvider = Provider<bool>((ref) {
  final activeNovena = ref.watch(novenaStateProvider);
  if (activeNovena == null) return false;
  return activeNovena.canAccessDay(activeNovena.spiritualDay);
});
