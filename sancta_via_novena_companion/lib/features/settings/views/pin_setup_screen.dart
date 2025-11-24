import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../widgets/pinput_modal_widget.dart';
import '../../../services/auth_service.dart';
import '../../../config/constants.dart';
import '../../../utils/logger.dart';
import '../providers/novena_app_settings_provider.dart';

class PinSetupScreen extends ConsumerStatefulWidget {
  const PinSetupScreen({super.key});

  @override
  ConsumerState<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends ConsumerState<PinSetupScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showPinSetupFlow();
    });
  }

  Future<void> _showPinSetupFlow() async {
    try {
      // Step 1: Get first PIN
      final firstPin = await PinputModalWidget.show(
        context: context,
        title: 'Set PIN Code',
        subtitle: 'Create a ${AppConstants.pinLength}-digit PIN to protect examination data',
        obscureText: true,
      );

      if (firstPin == null || !mounted) {
        // User cancelled or widget disposed
        if (mounted) {
          context.pop();
        }
        return;
      }

      // Step 2: Confirm PIN
      final confirmedPin = await PinputModalWidget.show(
        context: context,
        title: 'Confirm PIN',
        subtitle: 'Enter the same ${AppConstants.pinLength} digits to confirm your PIN',
        confirmPinText: firstPin.replaceAll(RegExp(r'.'), '●'),
        obscureText: true,
      );

      if (confirmedPin == null || !mounted) {
        // User cancelled or widget disposed
        if (mounted) {
          context.pop();
        }
        return;
      }

      if (firstPin != confirmedPin) {
        // PINs don't match - show error and restart
        _showErrorDialog('PINs do not match. Please try again.');
        _showPinSetupFlow(); // Restart the flow
        return;
      }

      // Step 3: Save the PIN
      await _savePinCode(firstPin);

    } catch (e, stackTrace) {
      AppLogger.error('PIN setup flow error', e, stackTrace, 'PIN_SETUP');
      if (mounted) {
        _showErrorDialog('Failed to set up PIN. Please try again.');
        context.pop();
      }
    }
  }

  Future<void> _savePinCode(String pin) async {
    // Show loading modal
    final loadingFuture = PinputModalWidget.show(
      context: context,
      title: 'Saving PIN',
      subtitle: 'Please wait while we securely save your PIN...',
      isLoading: true,
    );

    try {
      AppLogger.debug('=== PIN SETUP SAVE START ===', 'PIN_SETUP');
      AppLogger.debug('Saving PIN of length: ${pin.length}', 'PIN_SETUP');
      
      final authService = ref.read(authServiceProvider);
      await authService.setPinCode(pin);
      
      AppLogger.debug('PIN set in auth service, waiting for storage to settle', 'PIN_SETUP');
      await Future.delayed(const Duration(milliseconds: 500));

      // Verify PIN was stored correctly
      AppLogger.debug('Verifying PIN storage by testing validation', 'PIN_SETUP');
      final isValid = await authService.validatePin(pin);
      AppLogger.debug('PIN validation test result: $isValid', 'PIN_SETUP');
      
      if (!isValid) {
        AppLogger.warning('PIN validation failed immediately after saving!', 'PIN_SETUP');
        throw Exception('PIN storage verification failed. Please try again.');
      }

      // Update settings state
      await ref.read(novenaAppSettingsProvider.notifier).refreshPinStatus();

      // IMPORTANT: Force logout to ensure user must authenticate to access protected content
      AppLogger.debug('Forcing logout after PIN setup to clear authentication state', 'PIN_SETUP');
      authService.forceLogout();
      authService.debugAuthState();

      AppLogger.debug('=== PIN SAVE PROCESS COMPLETED SUCCESSFULLY ===', 'PIN_SETUP');
      
      // Close loading modal
      if (mounted) Navigator.of(context).pop();
      
      if (mounted) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('PIN saved successfully'),
              ],
            ),
            backgroundColor: Theme.of(context).colorScheme.primary,
            behavior: SnackBarBehavior.floating,
          ),
        );
        context.pop();
      }

    } catch (e, stackTrace) {
      AppLogger.error('PIN save failed', e, stackTrace, 'PIN_SETUP');
      
      // Close loading modal
      if (mounted) Navigator.of(context).pop();
      
      if (mounted) {
        String errorMessage = 'Failed to save PIN. Please try again.';
        
        if (e.toString().contains('iOS Simulator')) {
          errorMessage = 'PIN setup not available in iOS Simulator. Please test on a physical device.';
        } else if (e.toString().contains('Secure storage not available')) {
          errorMessage = 'Secure storage not available. This may be due to device or permission issues.';
        }
        
        _showErrorDialog(errorMessage);
        context.pop();
      }
    }

    // Ensure loading modal is closed
    loadingFuture.then((_) {}).catchError((_) {});
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('PIN Setup Error'),
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

  @override
  Widget build(BuildContext context) {
    // Show a simple background while PIN setup loads
    return Scaffold(
      appBar: AppBar(
        title: const Text('Set PIN Code'),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).colorScheme.primary.withAlpha(26),
              Theme.of(context).colorScheme.surface,
            ],
          ),
        ),
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      ),
    );
  }
}