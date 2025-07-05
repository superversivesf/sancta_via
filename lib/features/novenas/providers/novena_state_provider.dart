import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/novena.dart';
import '../services/novena_notification_service.dart';
import '../../../utils/logger.dart';

// Key for SharedPreferences storage
const String _activeNovenaKey = 'active_novena_v1';

// State notifier for managing active novena
class NovenaStateNotifier extends StateNotifier<ActiveNovena?> {
  final NovenaNotificationService _notificationService;
  
  NovenaStateNotifier(this._notificationService) : super(null) {
    _loadActiveNovena();
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
        }
      }
    } catch (e) {
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
      } else {
        await prefs.remove(_activeNovenaKey);
      }
    } catch (e) {
      // Handle storage error - could log or show user message
    }
  }

  // Start a new novena with notifications
  Future<void> startNovena(ActiveNovena activeNovena, String novenaTitle) async {
    AppLogger.debug('startNovena called with title: $novenaTitle', 'NOVENA_STATE');
    state = activeNovena;
    await _saveActiveNovena();
    
    // Schedule notifications
    try {
      final result = await _notificationService.scheduleNovenaNotifications(
        activeNovena, 
        novenaTitle,
      );
      
      if (result.success) {
        AppLogger.info('Scheduled ${result.scheduledCount} notifications for novena', 'NOVENA_STATE');
      } else {
        AppLogger.warning('Notification scheduling failed: ${result.error}', 'NOVENA_STATE');
      }
    } catch (e) {
      AppLogger.error('Failed to schedule notifications', e, null, 'NOVENA_STATE');
      // Continue without notifications - don't block novena start
    }
  }

  // Update state without scheduling new notifications (for debug/reset)
  Future<void> updateState(ActiveNovena activeNovena) async {
    AppLogger.debug('updateState called (no notification scheduling)', 'NOVENA_STATE');
    state = activeNovena;
    await _saveActiveNovena();
  }

  // Mark today's spiritual day as complete
  Future<void> markTodayComplete() async {
    AppLogger.debug('markTodayComplete called', 'NOVENA_STATE');
    final current = state;
    if (current == null) {
      AppLogger.warning('markTodayComplete: No active novena found', 'NOVENA_STATE');
      return;
    }

    final spiritualDay = current.spiritualDay;
    AppLogger.debug('markTodayComplete: spiritualDay=$spiritualDay, isTodayComplete=${current.isTodayComplete}', 'NOVENA_STATE');
    
    if (spiritualDay > 9) {
      AppLogger.warning('markTodayComplete: Spiritual day ($spiritualDay) is beyond day 9', 'NOVENA_STATE');
      return;
    }
    
    if (current.isDayComplete(spiritualDay)) {
      AppLogger.debug('markTodayComplete: Spiritual day $spiritualDay is already complete', 'NOVENA_STATE');
      return;
    }

    // Update completed days - ensure array is large enough
    final updatedCompletedDays = List<bool>.from(current.completedDays);
    while (updatedCompletedDays.length < 9) {
      updatedCompletedDays.add(false);
    }
    
    AppLogger.debug('markTodayComplete: Original completedDays: ${current.completedDays}', 'NOVENA_STATE');
    
    updatedCompletedDays[spiritualDay - 1] = true;
    AppLogger.debug('markTodayComplete: Updated completedDays: $updatedCompletedDays', 'NOVENA_STATE');

    state = current.copyWith(
      completedDays: updatedCompletedDays,
      lastCompletedDate: DateTime.now(),
    );

    AppLogger.info('markTodayComplete: State updated for spiritual day $spiritualDay', 'NOVENA_STATE');
    await _saveActiveNovena();
    
    // Cancel today's remaining notifications since prayer is complete
    try {
      await _notificationService.cancelDayNotifications(spiritualDay);
      AppLogger.debug('Cancelled day $spiritualDay notifications', 'NOVENA_STATE');
      
      // Send progress notification
      await _notificationService.sendProgressNotification(
        title: '🎉 Day $spiritualDay Complete!',
        body: 'Well done! You\'ve completed day $spiritualDay of your novena.',
        payload: 'progress_$spiritualDay',
      );
      
      // Check if novena is complete
      if (state?.isComplete == true) {
        await _notificationService.sendProgressNotification(
          title: '🌟 Novena Complete!',
          body: 'Congratulations! You\'ve completed your full 9-day novena journey.',
          payload: 'completion',
          isCompletion: true,
        );
      }
    } catch (e) {
      AppLogger.error('Failed to handle completion notifications', e, null, 'NOVENA_STATE');
    }
  }

  // Clear active novena (cancel or complete)
  Future<void> clearActiveNovena() async {
    // Cancel all notifications before clearing state
    try {
      await _notificationService.cancelAllNovenaNotifications();
      AppLogger.debug('Cancelled all notifications', 'NOVENA_STATE');
    } catch (e) {
      AppLogger.error('Failed to cancel notifications', e, null, 'NOVENA_STATE');
    }
    
    state = null;
    await _saveActiveNovena();
  }

  // Update reminder settings and reschedule notifications
  Future<void> updateReminderSettings({
    required TimeOfDay reminderTime,
    required ReminderInterval reminderFrequency,
    required String novenaTitle,
  }) async {
    final current = state;
    if (current == null) return;

    state = current.copyWith(
      reminderTime: reminderTime,
      reminderFrequency: reminderFrequency,
    );

    await _saveActiveNovena();
    
    // Reschedule notifications with new settings
    try {
      await _notificationService.cancelAllNovenaNotifications();
      final result = await _notificationService.scheduleNovenaNotifications(
        state!, 
        novenaTitle,
      );
      
      if (result.success) {
        AppLogger.info('Rescheduled ${result.scheduledCount} notifications', 'NOVENA_STATE');
      } else {
        AppLogger.warning('Failed to reschedule notifications: ${result.error}', 'NOVENA_STATE');
      }
    } catch (e) {
      AppLogger.error('Failed to update notification settings', e, null, 'NOVENA_STATE');
    }
  }
}

// Updated providers with notification service dependency
final novenaStateProvider = StateNotifierProvider<NovenaStateNotifier, ActiveNovena?>((ref) {
  final notificationService = NovenaNotificationService();
  return NovenaStateNotifier(notificationService);
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
