import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/theme_provider.dart';
import '../../../utils/navigation_utils.dart';
import '../providers/settings_providers.dart';
import '../../../utils/logger.dart';
import '../../../services/auth_service.dart';
import '../../../widgets/pinput_modal_widget.dart';
import '../../../config/constants.dart';
import '../../../config/theme.dart';
import '../../novenas/providers/novena_state_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          // Theme Section
          _buildSectionHeader(context, 'Appearance'),

          // Theme mode selection
          ListTile(
            leading: const Icon(Icons.brightness_6),
            title: const Text('Theme Mode'),
            trailing: DropdownButton<ThemeMode>(
              value: themeMode,
              onChanged: (ThemeMode? newValue) {
                if (newValue != null) {
                  ref.read(themeModeProvider.notifier).setThemeMode(newValue);
                }
              },
              items: const [
                DropdownMenuItem(
                  value: ThemeMode.system,
                  child: Text('System'),
                ),
                DropdownMenuItem(
                  value: ThemeMode.light,
                  child: Text('Light'),
                ),
                DropdownMenuItem(
                  value: ThemeMode.dark,
                  child: Text('Dark'),
                ),
              ],
            ),
          ),

          // Color scheme style setting
          ListTile(
            leading: const Icon(Icons.palette),
            title: const Text('Color Intensity'),
            subtitle: const Text('Choose between vibrant or muted colors'),
            trailing: DropdownButton<ColorSchemeStyle>(
              value: settings.colorSchemeStyle,
              onChanged: (ColorSchemeStyle? newValue) {
                if (newValue != null) {
                  ref.read(settingsProvider.notifier).setColorSchemeStyle(newValue);
                }
              },
              items: const [
                DropdownMenuItem(
                  value: ColorSchemeStyle.vibrant,
                  child: Text('Vibrant'),
                ),
                DropdownMenuItem(
                  value: ColorSchemeStyle.muted,
                  child: Text('Muted'),
                ),
              ],
            ),
          ),

          // Preview liturgical colors
          ListTile(
            leading: const Icon(Icons.color_lens),
            title: const Text('Preview Liturgical Colors'),
            subtitle: const Text('See how the app looks in different seasons and color styles'),
            onTap: () {
              AppNavigation.pushToThemePreview(context);
            },
          ),

          const Divider(),

          // Accessibility Section
          _buildSectionHeader(context, 'Accessibility'),

          // Font size slider
          ListTile(
            leading: const Icon(Icons.text_fields),
            title: const Text('Font Size'),
            subtitle: Slider(
              value: settings.fontSize,
              min: 0.8,
              max: 1.4,
              divisions: 6,
              label: _getFontSizeLabel(settings.fontSize),
              onChanged: (value) {
                ref.read(settingsProvider.notifier).setFontSize(value);
              },
            ),
          ),

          const Divider(),

          // Security Section
          _buildSectionHeader(context, 'Security'),

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
                // Require PIN verification before allowing change
                _showChangePinFlow(context, ref);
              } else {
                // First-time setup, no verification needed
                _showPinSetupFlow(context, ref);
              }
            },
          ),

          if (settings.hasPinCode)
            ListTile(
              leading: const Icon(Icons.lock_open, color: Colors.orange),
              title: const Text('Remove PIN Code'),
              subtitle: const Text('Remove PIN protection (not recommended)'),
              onTap: () {
                _showRemovePinFlow(context, ref);
              },
            ),

          const Divider(),

          // Debug Section (for testing)
          _buildDebugSection(context, ref),

          const Divider(),

          // About Section
          _buildSectionHeader(context, 'About'),

          ListTile(
            leading: const Icon(Icons.info),
            title: const Text('About Sancta Via'),
            onTap: () {
              showAboutDialog(
                context: context,
                applicationName: 'Sancta Via',
                applicationVersion: '1.0.0',
                applicationLegalese: '© 2025 Sancta Via',
                applicationIcon: Image.asset(
                  'assets/app_icon.png',
                  width: 48,
                  height: 48,
                ),
                children: [
                  const SizedBox(height: 16),
                  const Text(
                    'A Catholic app featuring prayers and examination of conscience tools for preparing for confession.',
                  ),
                ],
              );
            },
          ),

          ListTile(
            leading: const Icon(Icons.privacy_tip),
            title: const Text('Privacy Policy'),
            subtitle: const Text('How we protect your personal data'),
            onTap: () {
              AppNavigation.pushToPrivacyPolicy(context);
            },
          ),

          ListTile(
            leading: const Icon(Icons.code),
            title: const Text('Version'),
            subtitle: const Text('1.0.0'),
          ),

          // Debug: Installation ID (helpful for testing fresh install detection)
          FutureBuilder<String?>(
            future: ref.read(authServiceProvider).getInstallationId(),
            builder: (context, snapshot) {
              if (snapshot.hasData && snapshot.data != null) {
                final installId = snapshot.data!;
                final shortId = installId.length > 20 ? '${installId.substring(0, 20)}...' : installId;
                return ListTile(
                  leading: const Icon(Icons.fingerprint),
                  title: const Text('Installation ID'),
                  subtitle: Text(shortId),
                  onTap: () {
                    // Show full ID in dialog for debugging
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Installation ID'),
                        content: SelectableText(installId),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('OK'),
                          ),
                        ],
                      ),
                    );
                  },
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
    );
  }

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
      final loadingFuture = PinputModalWidget.show(
        context: context,
        title: 'Verifying PIN',
        subtitle: 'Please wait...',
        isLoading: true,
      );

      final isValid = await authService.validatePin(currentPin);
      
      // Close loading modal
      if (context.mounted) Navigator.of(context).pop();

      if (!isValid) {
        _showErrorSnackBar(context, 'Incorrect PIN. Please try again.');
        return;
      }

      // Clear current session for security
      authService.logout();

      // Step 2 & 3: Set new PIN (using the PIN setup flow)
      await _showPinSetupFlow(context, ref, isChange: true);

    } catch (e, stackTrace) {
      AppLogger.error('Change PIN flow error', e, stackTrace, 'SETTINGS');
      _showErrorSnackBar(context, 'Failed to change PIN. Please try again.');
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
      final confirmedPin = await PinputModalWidget.show(
        context: context,
        title: 'Confirm PIN',
        subtitle: 'Enter the same ${AppConstants.pinLength} digits to confirm your PIN',
        confirmPinText: firstPin.replaceAll(RegExp(r'.'), '●'),
        obscureText: true,
      );

      if (confirmedPin == null) return;

      if (firstPin != confirmedPin) {
        _showErrorSnackBar(context, 'PINs do not match. Please try again.');
        _showPinSetupFlow(context, ref, isChange: isChange); // Restart
        return;
      }

      // Step 3: Save the PIN
      await _savePinCode(context, ref, firstPin, isChange: isChange);

    } catch (e, stackTrace) {
      AppLogger.error('PIN setup flow error', e, stackTrace, 'SETTINGS');
      _showErrorSnackBar(context, 'Failed to set up PIN. Please try again.');
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
      final loadingFuture = PinputModalWidget.show(
        context: context,
        title: 'Verifying PIN',
        subtitle: 'Please wait...',
        isLoading: true,
      );

      final isValid = await authService.validatePin(currentPin);
      
      // Close loading modal
      if (context.mounted) Navigator.of(context).pop();

      if (!isValid) {
        _showErrorSnackBar(context, 'Incorrect PIN. Please try again.');
        return;
      }

      // Clear current session for security
      authService.logout();

      // Step 2: Remove PIN
      await ref.read(settingsProvider.notifier).clearPinCode();
      
      _showSuccessSnackBar(context, 'PIN code removed successfully', 
                          backgroundColor: Colors.orange);

    } catch (e, stackTrace) {
      AppLogger.error('Remove PIN flow error', e, stackTrace, 'SETTINGS');
      _showErrorSnackBar(context, 'Failed to remove PIN. Please try again.');
    }
  }

  Future<void> _savePinCode(BuildContext context, WidgetRef ref, String pin, {bool isChange = false}) async {
    // Show loading modal
    final loadingFuture = PinputModalWidget.show(
      context: context,
      title: 'Saving PIN',
      subtitle: 'Please wait while we securely save your PIN...',
      isLoading: true,
    );

    try {
      final authService = ref.read(authServiceProvider);
      await authService.setPinCode(pin);
      
      await Future.delayed(const Duration(milliseconds: 500));

      // Verify PIN was stored correctly
      final isValid = await authService.validatePin(pin);
      
      if (!isValid) {
        throw Exception('PIN storage verification failed. Please try again.');
      }

      // Update settings state
      await ref.read(settingsProvider.notifier).refreshPinStatus();

      // Close loading modal
      if (context.mounted) Navigator.of(context).pop();
      
      _showSuccessSnackBar(context, 
          isChange ? 'PIN changed successfully' : 'PIN saved successfully');

    } catch (e, stackTrace) {
      AppLogger.error('PIN save failed', e, stackTrace, 'SETTINGS');
      
      // Close loading modal
      if (context.mounted) Navigator.of(context).pop();
      
      String errorMessage = 'Failed to save PIN. Please try again.';
      
      if (e.toString().contains('iOS Simulator')) {
        errorMessage = 'PIN setup not available in iOS Simulator. Please test on a physical device.';
      } else if (e.toString().contains('Secure storage not available')) {
        errorMessage = 'Secure storage not available. This may be due to device or permission issues.';
      }
      
      _showErrorDialog(context, 'PIN Setup Error', errorMessage);
    }

    // Ensure loading modal is closed
    loadingFuture.then((_) {}).catchError((_) {});
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

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  String _getFontSizeLabel(double value) {
    if (value <= 0.8) return 'Smallest';
    if (value <= 0.9) return 'Smaller';
    if (value <= 0.95) return 'Small';
    if (value >= 1.35) return 'Largest';
    if (value >= 1.2) return 'Larger';
    if (value >= 1.1) return 'Large';
    return 'Normal';
  }

  Widget _buildDebugSection(BuildContext context, WidgetRef ref) {
    final activeNovena = ref.watch(novenaStateProvider);
    
    return Column(
      children: [
        _buildSectionHeader(context, 'Debug Tools'),
        
        if (activeNovena != null) ...[
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
          
        ] else ...[
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('No Active Novena'),
            subtitle: const Text('Start a novena to see debug options'),
          ),
        ],
      ],
    );
  }

  Future<void> _advanceNovenaDay(BuildContext context, WidgetRef ref) async {
    try {
      final activeNovena = ref.read(novenaStateProvider);
      if (activeNovena == null) return;

      // Advance by moving start date back by 1 day
      final newStartDate = activeNovena.startDate.subtract(const Duration(days: 1));
      final updatedNovena = activeNovena.copyWith(startDate: newStartDate);
      
      await ref.read(novenaStateProvider.notifier).updateState(updatedNovena);
      
      _showSuccessSnackBar(context, 
          'Advanced to Day ${updatedNovena.spiritualDay}', 
          backgroundColor: Colors.orange);
      
    } catch (e) {
      _showErrorSnackBar(context, 'Failed to advance novena day: $e');
    }
  }

  Future<void> _completeCurrentDay(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(novenaStateProvider.notifier).markTodayComplete();
      _showSuccessSnackBar(context, 'Current day marked as complete!');
    } catch (e) {
      _showErrorSnackBar(context, 'Failed to complete current day: $e');
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
      _showSuccessSnackBar(context, 'Novena progress reset', backgroundColor: Colors.purple);
      
    } catch (e) {
      _showErrorSnackBar(context, 'Failed to reset novena progress: $e');
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
      _showSuccessSnackBar(context, 'Novena cancelled', backgroundColor: Colors.red);
    } catch (e) {
      _showErrorSnackBar(context, 'Failed to cancel novena: $e');
    }
  }
}