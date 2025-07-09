import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../widgets/pinput_modal_widget.dart';
import '../../../widgets/pin_lockout_widget.dart';
import '../../../services/auth_service.dart';
import '../../../config/constants.dart';
import '../../../utils/logger.dart';
import '../../../config/route_names.dart';

class PinAuthScreen extends ConsumerStatefulWidget {
  const PinAuthScreen({super.key});

  @override
  ConsumerState<PinAuthScreen> createState() => _PinAuthScreenState();
}

class _PinAuthScreenState extends ConsumerState<PinAuthScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showPinAuthFlow();
    });
  }

  Future<void> _showPinAuthFlow() async {
    // Get the return destination from the current route BEFORE showing modal
    final returnTo = GoRouterState.of(context).uri.queryParameters['returnTo'];
    AppLogger.debug('Retrieved returnTo parameter: $returnTo', 'PIN_AUTH');
    
    // Load initial data
    final authService = ref.read(authServiceProvider);
    
    // Check if currently locked out
    final isLockedOut = await authService.isLockedOut();
    if (isLockedOut) {
      final remainingTime = await authService.getRemainingLockoutTime();
      if (remainingTime != null && remainingTime.inSeconds > 0) {
        _showLockoutModal(remainingTime);
        return;
      } else {
        // Lockout expired, clear it
        await authService.clearLockoutOnRestart();
      }
    }
    
    final currentAttempts = await authService.getFailedAttempts();
    await _showPinAuthModal(returnTo, currentAttempts);
  }

  Future<void> _showPinAuthModal(String? returnTo, int currentAttempts) async {
    String? errorMessage;
    int attempts = currentAttempts;
    
    while (attempts < AppConstants.maxPinAttempts) {
      try {
        if (!mounted) return;
        
        final enteredPin = await PinputModalWidget.show(
          context: context,
          title: 'Sancta Via',
          subtitle: 'Enter your PIN to continue',
          errorMessage: errorMessage,
          onForgotPin: () {
            Navigator.of(context).pop(); // Close modal
            _showForgotPinDialog();
          },
        );

        if (enteredPin == null || !mounted) {
          // User cancelled
          _handleAuthCancelled();
          return;
        }

        // Validate PIN with loading state
        final isValid = await _validatePinWithLoading(enteredPin);
        
        if (isValid) {
          // Authentication successful
          await _handleAuthSuccess(returnTo);
          return;
        } else {
          // Authentication failed
          attempts = await ref.read(authServiceProvider).getFailedAttempts();
          final newRemainingAttempts = AppConstants.maxPinAttempts - attempts;
          
          if (newRemainingAttempts > 0) {
            errorMessage = 'Incorrect PIN. $newRemainingAttempts attempts remaining.';
          } else {
            // This shouldn't happen with new lockout system, but handle gracefully
            final authService = ref.read(authServiceProvider);
            final remainingTime = await authService.getRemainingLockoutTime();
            if (remainingTime != null) {
              _showLockoutModal(remainingTime);
              return;
            }
          }
        }
        
      } catch (e, stackTrace) {
        AppLogger.error('PIN auth modal error', e, stackTrace, 'PIN_AUTH');
        if (e.toString().contains('locked') || e.toString().contains('wait')) {
          // Handle lockout exception
          final authService = ref.read(authServiceProvider);
          final remainingTime = await authService.getRemainingLockoutTime();
          if (remainingTime != null) {
            _showLockoutModal(remainingTime);
            return;
          }
          errorMessage = e.toString();
        } else {
          errorMessage = 'Failed to validate PIN. Please try again.';
        }
      }
    }
  }

  Future<bool> _validatePinWithLoading(String pin) async {
    // Show loading modal

    try {
      AppLogger.debug('=== PIN VALIDATION START ===', 'PIN_AUTH');
      
      final authService = ref.read(authServiceProvider);
      final isValid = await authService.validatePin(pin);
      
      AppLogger.debug('PIN validation result: $isValid', 'PIN_AUTH');
      
      // Close loading modal
      if (mounted) Navigator.of(context).pop();
      
      return isValid;
      
    } catch (e, stackTrace) {
      AppLogger.error('PIN validation error', e, stackTrace, 'PIN_AUTH');
      
      // Close loading modal
      if (mounted) Navigator.of(context).pop();
      
      rethrow;
    }
  }

  Future<void> _handleAuthSuccess(String? returnTo) async {
    AppLogger.debug('=== AUTHENTICATION SUCCESS ===', 'PIN_AUTH');
    
    if (!mounted) return;
    
    try {
      // Small delay to ensure auth state is set
      await Future.delayed(const Duration(milliseconds: 300));
      
      // Verify authentication state
      final authService = ref.read(authServiceProvider);
      if (!authService.isAuthenticated) {
        AppLogger.warning('Authentication state lost, forcing to true', 'PIN_AUTH');
        authService.setAuthenticatedForDebug(true);
      }
      
      if (returnTo != null && returnTo.isNotEmpty) {
        AppLogger.debug('Navigating to intended destination: $returnTo', 'PIN_AUTH');
        if (mounted) {
          context.go(returnTo);
        }
      } else {
        AppLogger.debug('No return destination, going to home', 'PIN_AUTH');
        if (mounted) {
          context.goNamed(RouteNames.home);
        }
      }
      
    } catch (e, stackTrace) {
      AppLogger.error('Navigation error after PIN auth', e, stackTrace, 'PIN_AUTH');
      // Fallback to home
      try {
        if (mounted) {
          context.goNamed(RouteNames.home);
        }
      } catch (fallbackError) {
        AppLogger.error('Fallback navigation failed', fallbackError, null, 'PIN_AUTH');
      }
    }
  }

  void _handleAuthCancelled() {
    AppLogger.debug('=== AUTHENTICATION CANCELLED ===', 'PIN_AUTH');
    try {
      context.go('/');
    } catch (e, stackTrace) {
      AppLogger.error('Error in cancel navigation', e, stackTrace, 'PIN_AUTH');
      try {
        context.goNamed(RouteNames.home);
      } catch (e2, stackTrace2) {
        AppLogger.error('Fallback cancel navigation failed', e2, stackTrace2, 'PIN_AUTH');
      }
    }
  }

  void _showLockoutModal(Duration remainingTime) async {
    AppLogger.debug('Showing PIN lockout modal, remaining time: $remainingTime', 'PIN_AUTH');
    
    await PinLockoutModal.show(
      context: context,
      lockoutDuration: remainingTime,
    );
    
    // After lockout modal is dismissed, go back to home
    if (mounted && context.mounted) {
      context.go('/');
    }
  }

  void _showForgotPinDialog() {
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
            onPressed: () {
              Navigator.of(context).pop();
              // For now, just navigate back to home
              // In a production app, you might want to implement a proper reset flow
              context.go('/');
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Show a simple background screen behind the modal
    return Scaffold(
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
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.security,
                size: 64,
                color: Theme.of(context).colorScheme.primary.withAlpha(128),
              ),
              const SizedBox(height: 16),
              Text(
                'Authentication Required',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.primary.withAlpha(179),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}