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
    _setupNotificationService();
    _loadActiveNovena();
  }

  /// Set up notification service with completion checking
  void _setupNotificationService() {
    // Set up completion check callback
    _notificationService.setCompletionCheckCallback((int day) {
      final current = state;
      if (current == null) return false;
      return current.isDayComplete(day);
    });
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
          AppLogger.debug('Loaded active novena: ${activeNovena.novenaId}, day ${activeNovena.spiritualDay}', 'NOVENA_STATE');
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

  // Start a new novena with smart notifications
  Future<void> startNovena(ActiveNovena activeNovena, String novenaTitle) async {
    AppLogger.info('Starting novena: $novenaTitle', 'NOVENA_STATE');
    state = activeNovena;
    await _saveActiveNovena();
    
    // Schedule smart notifications that check completion status
    try {
      final result = await _notificationService.scheduleNovenaNotifications(
        activeNovena, 
        novenaTitle,
      );
      
      if (result.success) {
        AppLogger.info('Scheduled ${result.scheduledCount} smart notifications for novena', 'NOVENA_STATE');
        if (result.errors.isNotEmpty) {
          AppLogger.warning('Some notification scheduling had warnings: ${result.errors}', 'NOVENA_STATE');
        }
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
    AppLogger.debug('Updating state without rescheduling notifications', 'NOVENA_STATE');
    state = activeNovena;
    await _saveActiveNovena();
  }

  // Mark today's spiritual day as complete with smart notification updates
  Future<void> markTodayComplete() async {
    AppLogger.debug('Marking today complete', 'NOVENA_STATE');
    final current = state;
    if (current == null) {
      AppLogger.warning('No active novena found', 'NOVENA_STATE');
      return;
    }

    final spiritualDay = current.spiritualDay;
    AppLogger.debug('Current spiritual day: $spiritualDay, already complete: ${current.isTodayComplete}', 'NOVENA_STATE');
    
    if (spiritualDay > 9) {
      AppLogger.warning('Spiritual day ($spiritualDay) is beyond day 9', 'NOVENA_STATE');
      return;
    }
    
    if (current.isDayComplete(spiritualDay)) {
      AppLogger.debug('Spiritual day $spiritualDay is already complete', 'NOVENA_STATE');
      return;
    }

    // Update completed days - ensure array is large enough
    final updatedCompletedDays = List<bool>.from(current.completedDays);
    while (updatedCompletedDays.length < 9) {
      updatedCompletedDays.add(false);
    }
    
    updatedCompletedDays[spiritualDay - 1] = true;
    AppLogger.debug('Updated completion status for day $spiritualDay', 'NOVENA_STATE');

    final updatedNovena = current.copyWith(
      completedDays: updatedCompletedDays,
      lastCompletedDate: DateTime.now(),
    );

    state = updatedNovena;
    await _saveActiveNovena();
    
    // Use smart notification updates that handle progress and rescheduling
    try {
      await _notificationService.updateNotificationsForProgress(
        updatedNovena,
        'Current Novena', // You might want to pass the actual title here
        spiritualDay,
      );
      
      AppLogger.info('Day $spiritualDay marked complete with smart notification updates', 'NOVENA_STATE');
      
      // Check if entire novena is complete
      if (updatedNovena.isComplete) {
        AppLogger.info('Novena completed! All 9 days done.', 'NOVENA_STATE');
        await _notificationService.sendProgressNotification(
          title: '🌟 Novena Complete!',
          body: 'Congratulations! You\'ve completed your full 9-day novena journey. May your prayers be answered.',
          payload: 'completion',
          isCompletion: true,
        );
      }
    } catch (e) {
      AppLogger.error('Failed to handle smart notification updates', e, null, 'NOVENA_STATE');
    }
  }

  // Clear active novena (cancel or complete)
  Future<void> clearActiveNovena() async {
    AppLogger.info('Clearing active novena', 'NOVENA_STATE');
    
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

  // Update reminder settings and reschedule smart notifications
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

    AppLogger.debug('Updating reminder settings: ${reminderTime.format(null)}, ${reminderFrequency.displayName}', 'NOVENA_STATE');

    state = current.copyWith(
      reminderTime: reminderTime,
      reminderFrequency: reminderFrequency,
    );

    await _saveActiveNovena();
    
    // Reschedule smart notifications with new settings
    try {
      await _notificationService.cancelAllNovenaNotifications();
      final result = await _notificationService.scheduleNovenaNotifications(
        state!, 
        novenaTitle,
      );
      
      if (result.success) {
        AppLogger.info('Rescheduled ${result.scheduledCount} smart notifications with new settings', 'NOVENA_STATE');
      } else {
        AppLogger.warning('Failed to reschedule notifications: ${result.error}', 'NOVENA_STATE');
      }
    } catch (e) {
      AppLogger.error('Failed to update notification settings', e, null, 'NOVENA_STATE');
    }
  }

  // Reschedule notifications (useful when app comes back from background)
  Future<void> rescheduleNotifications(String novenaTitle) async {
    final current = state;
    if (current == null) return;

    AppLogger.debug('Rescheduling notifications for active novena', 'NOVENA_STATE');
    
    try {
      // Cancel existing notifications first
      await _notificationService.cancelAllNovenaNotifications();
      
      // Reschedule with current state (smart notifications will skip completed days)
      final result = await _notificationService.scheduleNovenaNotifications(
        current,
        novenaTitle,
      );
      
      if (result.success) {
        AppLogger.debug('Rescheduled ${result.scheduledCount} notifications', 'NOVENA_STATE');
      } else {
        AppLogger.warning('Failed to reschedule notifications: ${result.error}', 'NOVENA_STATE');
      }
    } catch (e) {
      AppLogger.error('Failed to reschedule notifications', e, null, 'NOVENA_STATE');
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

final accessibleCompletedCountProvider = Provider<int>((ref) {
  final activeNovena = ref.watch(novenaStateProvider);
  return activeNovena?.accessibleCompletedCount ?? 0;
});

final canAccessTodayProvider = Provider<bool>((ref) {
  final activeNovena = ref.watch(novenaStateProvider);
  if (activeNovena == null) return false;
  return activeNovena.canAccessDay(activeNovena.spiritualDay);
});
