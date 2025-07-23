import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sancta_via_shared_ui/sancta_via_shared_ui.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../providers/novena_app_settings_provider.dart';
import '../../../services/auth_service.dart';
import '../../../widgets/pinput_modal_widget.dart';
import '../../../utils/logger.dart';
import '../../../config/constants.dart';
import '../../novenas/providers/novena_state_provider.dart';
import '../../../utils/database_test_utility.dart';

/// Unified settings screen for Novena Companion using standardized components
class NovenaSettingsScreen extends ConsumerWidget {
  const NovenaSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<PackageInfo>(
      future: PackageInfo.fromPlatform(),
      builder: (context, snapshot) {
        // App information for the unified screen
        final appInfo = AppInfo(
          appName: 'Novena Companion',
          version: snapshot.hasData ? snapshot.data!.version : 'Loading...',
          description: 'Catholic novena companion app with traditional nine-day prayer devotions and liturgical integration for spiritual growth.',
          icon: const Icon(Icons.auto_stories, size: 48, color: Colors.deepPurple),
          onFeedback: () => _showComingSoon(context, 'Feedback'),
          onSupport: () => _showSupportDialog(context),
        );

        // Novena-specific settings section
        final novenaSpecificSettings = _buildNovenaSpecificSettings(context, ref);

        return UnifiedSettingsScreen(
          appInfo: appInfo,
          appSpecificSettings: novenaSpecificSettings,
          customNotifications: [
            CatholicNotificationOptions.novenas(
              enabled: ref.watch(novenaNotificationsEnabledProvider),
              onChanged: (enabled) {
                ref.read(novenaAppSettingsProvider.notifier).updateNovenaNotificationsEnabled(enabled);
              },
            ),
            CatholicNotificationOptions.liturgicalCalendar(
              enabled: false, // TODO: Connect to liturgical notifications
              onChanged: (enabled) {
                _showComingSoon(context, 'Liturgical calendar notifications');
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildNovenaSpecificSettings(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(novenaAppSettingsProvider);
    final activeNovena = ref.watch(novenaStateProvider);
    
    return Column(
      children: [
        // ═══════════════════════════════════════
        // NOVENA SETTINGS SECTION
        // ═══════════════════════════════════════
        const SettingsSectionHeader(title: 'Novena Settings'),

        // Daily reminder time
        ListTile(
          leading: const Icon(Icons.schedule),
          title: const Text('Daily Reminder Time'),
          subtitle: const Text(
            'Set your preferred time for novena prayer reminders',
          ),
          trailing: Text(
            settings.dailyReminderTimeOfDay.format(context),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          onTap: () => _showTimePickerDialog(context, ref),
        ),

        // Show completion celebrations
        SwitchListTile(
          secondary: const Icon(Icons.celebration),
          title: const Text('Completion Celebrations'),
          subtitle: const Text('Show celebrations when completing novena days'),
          value: settings.showCompletionCelebrations,
          onChanged: (value) {
            ref.read(novenaAppSettingsProvider.notifier).updateShowCompletionCelebrations(value);
          },
        ),

        // Allow multiple novenas (future feature)
        SwitchListTile(
          secondary: const Icon(Icons.layers),
          title: const Text('Multiple Novenas'),
          subtitle: const Text('Allow multiple active novenas (coming soon)'),
          value: settings.allowMultipleNovenas,
          onChanged: null, // Disabled for now
        ),

        const Divider(),

        // ═══════════════════════════════════════
        // APPEARANCE SECTION (using shared UI)
        // ═══════════════════════════════════════
        const SettingsSectionHeader(title: 'Appearance'),
        
        // Theme mode selection (Light/Dark/System)
        const ThemeModeSelector(),
        
        // Color intensity selection (Vibrant/Muted)
        const ColorIntensitySelector(),
        
        // Liturgical color preview
        const LiturgicalColorPreview(),
        
        // Current color display for easier verification
        ListTile(
          leading: const Icon(Icons.info),
          title: const Text('Current Theme Color'),
          trailing: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Theme.of(context).colorScheme.outline),
            ),
          ),
        ),
        
        const Divider(),

        // ═══════════════════════════════════════
        // ACCESSIBILITY SECTION (with working font size)
        // ═══════════════════════════════════════
        const AccessibilitySettings(
          fontPreviewText: 'Sample novena prayer text: "O Saint Jude, glorious apostle..."',
          showFontSize: true,
        ),

        const Divider(),

        // ═══════════════════════════════════════
        // SECURITY SECTION
        // ═══════════════════════════════════════
        const SettingsSectionHeader(title: 'Security'),

        // PIN Code Management
        ListTile(
          leading: const Icon(Icons.lock),
          title: Text(settings.hasPinCode ? 'Change PIN Code' : 'Set PIN Code'),
          subtitle: Text(settings.hasPinCode 
              ? 'PIN is currently set for examination data protection'
              : 'Create a ${AppConstants.pinLength}-digit PIN to protect examination data'),
          trailing: settings.hasPinCode 
              ? const Icon(Icons.edit)
              : const Icon(Icons.add),
          onTap: () {
            if (settings.hasPinCode) {
              _showChangePinFlow(context, ref);
            } else {
              _showPinSetupFlow(context, ref);
            }
          },
        ),

        if (settings.hasPinCode)
          ListTile(
            leading: const Icon(Icons.lock_open, color: Colors.orange),
            title: const Text('Remove PIN Code'),
            subtitle: const Text('Remove PIN protection (not recommended)'),
            onTap: () => _showRemovePinFlow(context, ref),
          ),

        const Divider(),

        // ═══════════════════════════════════════
        // DEBUG SECTION (for development)
        // ═══════════════════════════════════════
        const SettingsSectionHeader(title: 'Debug Tools'),
        
        // Database debug tools
        ListTile(
          leading: const Icon(Icons.storage, color: Colors.blue),
          title: const Text('Test Database'),
          subtitle: const Text('Run comprehensive database test'),
          onTap: () => _testDatabase(context),
        ),
        
        ListTile(
          leading: const Icon(Icons.info, color: Colors.blue),
          title: const Text('Database Info'),
          subtitle: const Text('Show database statistics'),
          onTap: () => _showDatabaseInfo(context),
        ),
        
        ListTile(
          leading: const Icon(Icons.refresh, color: Colors.orange),
          title: const Text('Reset Database'),
          subtitle: const Text('Clear and reinitialize database'),
          onTap: () => _resetDatabase(context),
        ),
        
        if (activeNovena != null) ...[
          const Divider(),
          const SettingsSectionHeader(title: 'Debug Tools'),
          
          // Current novena status
          ListTile(
            leading: const Icon(Icons.info, color: Colors.blue),
            title: const Text('Active Novena Status'),
            subtitle: Text(
              'Day ${activeNovena.spiritualDay} of 9 • '
              '${activeNovena.accessibleCompletedCount} completed • '
              'Started: ${activeNovena.startDate.toString().split(' ')[0]}'
            ),
          ),
          
          // Advance novena day
          ListTile(
            leading: const Icon(Icons.fast_forward, color: Colors.orange),
            title: const Text('Advance Novena Day'),
            subtitle: const Text('Move forward one day for testing'),
            onTap: () => _advanceNovenaDay(context, ref),
          ),
          
          // Complete current day
          ListTile(
            leading: const Icon(Icons.check_circle, color: Colors.green),
            title: const Text('Complete Current Day'),
            subtitle: const Text('Mark current spiritual day as complete'),
            onTap: activeNovena.isTodayComplete 
                ? null 
                : () => _completeCurrentDay(context, ref),
          ),
          
          // Reset novena progress
          ListTile(
            leading: const Icon(Icons.refresh, color: Colors.purple),
            title: const Text('Reset Novena Progress'),
            subtitle: const Text('Clear all completed days but keep novena'),
            onTap: () => _resetNovenaProgress(context, ref),
          ),
          
          // Cancel novena
          ListTile(
            leading: const Icon(Icons.cancel, color: Colors.red),
            title: const Text('Cancel Active Novena'),
            subtitle: const Text('Remove the active novena completely'),
            onTap: () => _cancelNovena(context, ref),
          ),
          
        ],
      ],
    );
  }

  Future<void> _showTimePickerDialog(BuildContext context, WidgetRef ref) async {
    final settings = ref.read(novenaAppSettingsProvider);
    final currentTime = settings.dailyReminderTimeOfDay;
    
    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: currentTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            timePickerTheme: TimePickerThemeData(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (pickedTime != null && pickedTime != currentTime) {
      await ref.read(novenaAppSettingsProvider.notifier).updateDailyReminderTime(pickedTime);
      if (context.mounted) {
        _showSuccessSnackBar(context, 'Daily reminder time updated to ${pickedTime.format(context)}');
      }
    }
  }

  // PIN Management Methods (similar to existing implementation)
  Future<void> _showChangePinFlow(BuildContext context, WidgetRef ref) async {
    try {
      // Step 1: Verify current PIN
      final currentPin = await PinputModalWidget.show(
        context: context,
        title: 'Change PIN Code',
        subtitle: 'Enter your current PIN to change your PIN code',
        onForgotPin: () {
          Navigator.of(context).pop();
          _showForgotPinDialog(context, ref);
        },
      );

      if (currentPin == null) return;

      // Verify the current PIN
      final authService = ref.read(authServiceProvider);
      
      // Show loading
      if (context.mounted) {
        PinputModalWidget.show(
          context: context,
          title: 'Verifying PIN',
          subtitle: 'Please wait...',
          isLoading: true,
        );
      }

      final isValid = await authService.validatePin(currentPin);
      
      // Close loading modal
      if (context.mounted) Navigator.of(context).pop();

      if (!isValid) {
        if (context.mounted) {
          _showErrorSnackBar(context, 'Incorrect PIN. Please try again.');
        }
        return;
      }

      // Clear current session for security
      authService.logout();

      // Step 2 & 3: Set new PIN
      if (context.mounted) {
        await _showPinSetupFlow(context, ref, isChange: true);
      }

    } catch (e, stackTrace) {
      AppLogger.error('Change PIN flow error', e, stackTrace, 'NOVENA_SETTINGS');
      if (context.mounted) {
        _showErrorSnackBar(context, 'Failed to change PIN. Please try again.');
      }
    }
  }

  Future<void> _showPinSetupFlow(BuildContext context, WidgetRef ref, {bool isChange = false}) async {
    try {
      // Step 1: Get first PIN
      final firstPin = await PinputModalWidget.show(
        context: context,
        title: isChange ? 'Set New PIN' : 'Set PIN Code',
        subtitle: 'Create a ${AppConstants.pinLength}-digit PIN to protect examination data',
        obscureText: true,
      );

      if (firstPin == null) return;

      // Step 2: Confirm PIN
      if (!context.mounted) return;
      
      final confirmedPin = await PinputModalWidget.show(
        context: context,
        title: 'Confirm PIN',
        subtitle: 'Enter the same ${AppConstants.pinLength} digits to confirm your PIN',
        confirmPinText: firstPin.replaceAll(RegExp(r'.'), '●'),
        obscureText: true,
      );

      if (confirmedPin == null) return;

      if (firstPin != confirmedPin) {
        if (context.mounted) {
          _showErrorSnackBar(context, 'PINs do not match. Please try again.');
          _showPinSetupFlow(context, ref, isChange: isChange); // Restart
        }
        return;
      }

      // Step 3: Save the PIN
      if (context.mounted) {
        await _savePinCode(context, ref, firstPin, isChange: isChange);
      }

    } catch (e, stackTrace) {
      AppLogger.error('PIN setup flow error', e, stackTrace, 'NOVENA_SETTINGS');
      if (context.mounted) {
        _showErrorSnackBar(context, 'Failed to set up PIN. Please try again.');
      }
    }
  }

  Future<void> _showRemovePinFlow(BuildContext context, WidgetRef ref) async {
    try {
      // Step 1: Verify current PIN
      final currentPin = await PinputModalWidget.show(
        context: context,
        title: 'Remove PIN Code',
        subtitle: 'Enter your current PIN to remove PIN protection',
        onForgotPin: () {
          Navigator.of(context).pop();
          _showForgotPinDialog(context, ref);
        },
      );

      if (currentPin == null) return;

      // Verify the current PIN
      final authService = ref.read(authServiceProvider);
      
      // Show loading
      if (context.mounted) {
        PinputModalWidget.show(
          context: context,
          title: 'Verifying PIN',
          subtitle: 'Please wait...',
          isLoading: true,
        );
      }

      final isValid = await authService.validatePin(currentPin);
      
      // Close loading modal
      if (context.mounted) Navigator.of(context).pop();

      if (!isValid) {
        if (context.mounted) {
          _showErrorSnackBar(context, 'Incorrect PIN. Please try again.');
        }
        return;
      }

      // Clear current session for security
      authService.logout();

      // Step 2: Remove PIN
      await ref.read(novenaAppSettingsProvider.notifier).clearPinCode();
      
      if (context.mounted) {
        _showSuccessSnackBar(context, 'PIN code removed successfully', 
                            backgroundColor: Colors.orange);
      }

    } catch (e, stackTrace) {
      AppLogger.error('Remove PIN flow error', e, stackTrace, 'NOVENA_SETTINGS');
      if (context.mounted) {
        _showErrorSnackBar(context, 'Failed to remove PIN. Please try again.');
      }
    }
  }

  Future<void> _savePinCode(BuildContext context, WidgetRef ref, String pin, {bool isChange = false}) async {
    // Show loading modal
    PinputModalWidget.show(
      context: context,
      title: 'Saving PIN',
      subtitle: 'Please wait while we securely save your PIN...',
      isLoading: true,
    );

    try {
      await ref.read(novenaAppSettingsProvider.notifier).setPinCode(pin);
      
      await Future.delayed(const Duration(milliseconds: 500));

      // Verify PIN was stored correctly
      final authService = ref.read(authServiceProvider);
      final isValid = await authService.validatePin(pin);
      
      if (!isValid) {
        throw Exception('PIN storage verification failed. Please try again.');
      }

      // Update settings state
      await ref.read(novenaAppSettingsProvider.notifier).refreshPinStatus();

      // Close loading modal
      if (context.mounted) Navigator.of(context).pop();
      
      if (context.mounted) {
        _showSuccessSnackBar(context, 
            isChange ? 'PIN changed successfully' : 'PIN saved successfully');
      }

    } catch (e, stackTrace) {
      AppLogger.error('PIN save failed', e, stackTrace, 'NOVENA_SETTINGS');
      
      // Close loading modal
      if (context.mounted) Navigator.of(context).pop();
      
      String errorMessage = 'Failed to save PIN. Please try again.';
      
      if (e.toString().contains('iOS Simulator')) {
        errorMessage = 'PIN setup not available in iOS Simulator. Please test on a physical device.';
      } else if (e.toString().contains('Secure storage not available')) {
        errorMessage = 'Secure storage not available. This may be due to device or permission issues.';
      }
      
      if (context.mounted) {
        _showErrorDialog(context, 'PIN Setup Error', errorMessage);
      }
    }

    // Ensure loading modal is closed
    Future.value(null).then((_) {}).catchError((_) {});
  }

  void _showForgotPinDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Forgot PIN?'),
        content: const Text(
          'To reset your PIN, you\'ll need to restart the app and clear app data. '
          'This will remove all saved examination sessions.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(BuildContext context, String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // Database debug methods
  Future<void> _testDatabase(BuildContext context) async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Running database test...'),
          ],
        ),
      ),
    );

    try {
      final results = await DatabaseTestUtility.runDatabaseTest();
      
      // Close loading dialog
      if (context.mounted) Navigator.of(context).pop();
      
      // Show results
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Database Test Results'),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Test Completed: ${results['test_completed'] ?? false}'),
                  const SizedBox(height: 8),
                  if (results['initialization'] != null) ...[
                    Text('Initialization: ${results['initialization']['success'] ? 'Success' : 'Failed'}'),
                    if (results['initialization']['novena_count'] > 0)
                      Text('Novenas: ${results['initialization']['novena_count']}'),
                    const SizedBox(height: 8),
                  ],
                  if (results['stats'] != null) ...[
                    Text('Database Stats:'),
                    Text('  Novenas: ${results['stats']['novenas']}'),
                    Text('  Days: ${results['stats']['days']}'),
                    const SizedBox(height: 8),
                  ],
                  if (results['categories'] != null) ...[
                    Text('Categories: ${(results['categories'] as List).join(', ')}'),
                    const SizedBox(height: 8),
                  ],
                  if (results['difficulties'] != null) ...[
                    Text('Difficulties: ${(results['difficulties'] as List).join(', ')}'),
                    const SizedBox(height: 8),
                  ],
                  if (results['search_test'] != null) ...[
                    Text('Search Test: ${results['search_test']['results_count']} results for "${results['search_test']['search_term']}"'),
                  ],
                  if (results['error'] != null) ...[
                    const SizedBox(height: 8),
                    Text('Error: ${results['error']}', style: const TextStyle(color: Colors.red)),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      // Close loading dialog
      if (context.mounted) Navigator.of(context).pop();
      
      if (context.mounted) {
        _showErrorSnackBar(context, 'Database test failed: $e');
      }
    }
  }

  Future<void> _showDatabaseInfo(BuildContext context) async {
    try {
      // This will print to console and can be viewed in debug logs
      await DatabaseTestUtility.printDatabaseInfo();
      
      if (context.mounted) {
        _showSuccessSnackBar(context, 'Database info printed to console');
      }
    } catch (e) {
      if (context.mounted) {
        _showErrorSnackBar(context, 'Failed to get database info: $e');
      }
    }
  }

  Future<void> _resetDatabase(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Database'),
        content: const Text(
          'This will clear all novena data and reload from JSON files. '
          'This action cannot be undone. Are you sure?'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Resetting database...'),
          ],
        ),
      ),
    );

    try {
      final success = await DatabaseTestUtility.resetDatabase();
      
      // Close loading dialog
      if (context.mounted) Navigator.of(context).pop();
      
      if (success) {
        if (context.mounted) {
          _showSuccessSnackBar(context, 'Database reset successfully', backgroundColor: Colors.orange);
        }
      } else {
        if (context.mounted) {
          _showErrorSnackBar(context, 'Failed to reset database');
        }
      }
    } catch (e) {
      // Close loading dialog
      if (context.mounted) Navigator.of(context).pop();
      
      if (context.mounted) {
        _showErrorSnackBar(context, 'Database reset failed: $e');
      }
    }
  }

  // Debug methods for novena testing
  Future<void> _advanceNovenaDay(BuildContext context, WidgetRef ref) async {
    try {
      final activeNovena = ref.read(novenaStateProvider);
      if (activeNovena == null) return;

      // Advance by moving start date back by 1 day
      final newStartDate = activeNovena.startDate.subtract(const Duration(days: 1));
      final updatedNovena = activeNovena.copyWith(startDate: newStartDate);
      
      await ref.read(novenaStateProvider.notifier).updateState(updatedNovena);
      
      if (context.mounted) {
        _showSuccessSnackBar(context, 
            'Advanced to Day ${updatedNovena.spiritualDay}', 
            backgroundColor: Colors.orange);
      }
      
    } catch (e) {
      if (context.mounted) {
        _showErrorSnackBar(context, 'Failed to advance novena day: $e');
      }
    }
  }

  Future<void> _completeCurrentDay(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(novenaStateProvider.notifier).markTodayComplete();
      if (context.mounted) {
        _showSuccessSnackBar(context, 'Current day marked as complete!');
      }
    } catch (e) {
      if (context.mounted) {
        _showErrorSnackBar(context, 'Failed to complete current day: $e');
      }
    }
  }

  Future<void> _resetNovenaProgress(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Novena Progress'),
        content: const Text('Are you sure you want to clear all completed days? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.purple),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final activeNovena = ref.read(novenaStateProvider);
      if (activeNovena == null) return;

      final resetNovena = activeNovena.copyWith(
        completedDays: List.filled(9, false),
        lastCompletedDate: null,
      );
      
      await ref.read(novenaStateProvider.notifier).updateState(resetNovena);
      if (context.mounted) {
        _showSuccessSnackBar(context, 'Novena progress reset', backgroundColor: Colors.purple);
      }
      
    } catch (e) {
      if (context.mounted) {
        _showErrorSnackBar(context, 'Failed to reset novena progress: $e');
      }
    }
  }

  Future<void> _cancelNovena(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Novena'),
        content: const Text('Are you sure you want to cancel your active novena? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep Novena'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Cancel Novena'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await ref.read(novenaStateProvider.notifier).clearActiveNovena();
      if (context.mounted) {
        _showSuccessSnackBar(context, 'Novena cancelled', backgroundColor: Colors.red);
      }
    } catch (e) {
      if (context.mounted) {
        _showErrorSnackBar(context, 'Failed to cancel novena: $e');
      }
    }
  }


  void _showComingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature - Coming Soon'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSupportDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Support Novena Companion'),
        content: const Text(
          'Novena Companion is part of the Sancta Via ecosystem of Catholic applications.\n\n'
          'This app provides access to traditional nine-day prayer devotions, '
          'with liturgical calendar integration for seasonal novena recommendations.\n\n'
          'Your support helps us continue developing high-quality Catholic applications for the faithful.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showErrorSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccessSnackBar(BuildContext context, String message, {Color? backgroundColor}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: backgroundColor ?? Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}