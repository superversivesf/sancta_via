import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/settings_service.dart';
import '../services/settings_error_handler.dart';
import '../../../widgets/pinput_modal_widget.dart';
import '../../../config/constants.dart';

/// PIN management dialog flows
class PinManagementDialog {
  /// Show PIN setup flow for new users
  static Future<void> showSetupPin(BuildContext context, WidgetRef ref) async {
    try {
      final settingsService = ref.read(settingsServiceProvider);

      // Step 1: Get first PIN
      final firstPin = await PinputModalWidget.show(
        context: context,
        title: 'Set PIN Code',
        subtitle:
            'Create a ${AppConstants.pinLength}-digit PIN to protect examination data',
        obscureText: true,
      );

      if (firstPin == null || !context.mounted) return;

      // Step 2: Confirm PIN
      final confirmedPin = await PinputModalWidget.show(
        context: context,
        title: 'Confirm PIN',
        subtitle:
            'Enter the same ${AppConstants.pinLength} digits to confirm your PIN',
        confirmPinText: firstPin.replaceAll(RegExp(r'.'), '●'),
        obscureText: true,
      );

      if (confirmedPin == null || !context.mounted) return;

      if (firstPin != confirmedPin) {
        if (context.mounted) {
          SettingsErrorHandler.handleError(
            context,
            Exception('PINs do not match'),
            operation: 'confirming PIN',
          );
          // Restart the flow
          await showSetupPin(context, ref);
        }
        return;
      }

      // Step 3: Save the PIN with loading
      if (context.mounted) {
        await _savePinWithLoading(
          context,
          settingsService,
          firstPin,
          isChange: false,
        );
      }
    } catch (e) {
      if (context.mounted) {
        SettingsErrorHandler.handleError(
          context,
          e as Exception,
          operation: 'setting up PIN',
        );
      }
    }
  }

  /// Show PIN change flow for existing users
  static Future<void> showChangePin(BuildContext context, WidgetRef ref) async {
    try {
      final settingsService = ref.read(settingsServiceProvider);

      // Step 1: Verify current PIN
      final currentPin = await PinputModalWidget.show(
        context: context,
        title: 'Change PIN Code',
        subtitle: 'Enter your current PIN to change your PIN code',
        onForgotPin: () {
          Navigator.of(context).pop();
          _showForgotPinDialog(context);
        },
      );

      if (currentPin == null || !context.mounted) return;

      // Verify current PIN with loading
      SettingsErrorHandler.showLoadingDialog(
        context,
        title: 'Verifying PIN',
        subtitle: 'Please wait...',
      );

      final isValid = await settingsService.validatePin(currentPin);

      if (context.mounted) {
        SettingsErrorHandler.hideLoadingDialog(context);
      }

      if (!isValid) {
        if (context.mounted) {
          SettingsErrorHandler.handleError(
            context,
            Exception('Incorrect PIN'),
            operation: 'verifying current PIN',
          );
        }
        return;
      }

      // Step 2 & 3: Set new PIN
      if (context.mounted) {
        await _showNewPinFlow(context, ref, settingsService, currentPin);
      }
    } catch (e) {
      if (context.mounted) {
        SettingsErrorHandler.hideLoadingDialog(context);
        SettingsErrorHandler.handleError(
          context,
          e as Exception,
          operation: 'changing PIN',
        );
      }
    }
  }

  /// Show PIN removal flow
  static Future<void> showRemovePin(BuildContext context, WidgetRef ref) async {
    try {
      final settingsService = ref.read(settingsServiceProvider);

      // Step 1: Verify current PIN
      final currentPin = await PinputModalWidget.show(
        context: context,
        title: 'Remove PIN Code',
        subtitle: 'Enter your current PIN to remove PIN protection',
        onForgotPin: () {
          Navigator.of(context).pop();
          _showForgotPinDialog(context);
        },
      );

      if (currentPin == null || !context.mounted) return;

      // Verify and remove PIN with loading
      SettingsErrorHandler.showLoadingDialog(
        context,
        title: 'Removing PIN',
        subtitle: 'Please wait...',
      );

      await settingsService.removePinCode(currentPin);

      if (context.mounted) {
        SettingsErrorHandler.hideLoadingDialog(context);
        SettingsErrorHandler.showSuccess(
          context,
          'PIN code removed successfully',
          backgroundColor: Colors.orange,
        );
      }
    } catch (e) {
      if (context.mounted) {
        SettingsErrorHandler.hideLoadingDialog(context);
        SettingsErrorHandler.handleError(
          context,
          e as Exception,
          operation: 'removing PIN',
        );
      }
    }
  }

  /// New PIN setup flow for PIN changes
  static Future<void> _showNewPinFlow(
    BuildContext context,
    WidgetRef ref,
    SettingsService settingsService,
    String currentPin,
  ) async {
    // Step 1: Get new PIN
    final newPin = await PinputModalWidget.show(
      context: context,
      title: 'Set New PIN',
      subtitle: 'Create a new ${AppConstants.pinLength}-digit PIN',
      obscureText: true,
    );

    if (newPin == null || !context.mounted) return;

    // Step 2: Confirm new PIN
    final confirmedNewPin = await PinputModalWidget.show(
      context: context,
      title: 'Confirm New PIN',
      subtitle: 'Enter the same ${AppConstants.pinLength} digits to confirm',
      confirmPinText: newPin.replaceAll(RegExp(r'.'), '●'),
      obscureText: true,
    );

    if (confirmedNewPin == null || !context.mounted) return;

    if (newPin != confirmedNewPin) {
      if (context.mounted) {
        SettingsErrorHandler.handleError(
          context,
          Exception('PINs do not match'),
          operation: 'confirming new PIN',
        );
        // Restart new PIN flow
        await _showNewPinFlow(context, ref, settingsService, currentPin);
      }
      return;
    }

    // Step 3: Change PIN with loading
    if (context.mounted) {
      SettingsErrorHandler.showLoadingDialog(
        context,
        title: 'Changing PIN',
        subtitle: 'Please wait while we update your PIN...',
      );

      try {
        await settingsService.changePinCode(currentPin, newPin);

        if (context.mounted) {
          SettingsErrorHandler.hideLoadingDialog(context);
          SettingsErrorHandler.showSuccess(context, 'PIN changed successfully');
        }
      } catch (e) {
        if (context.mounted) {
          SettingsErrorHandler.hideLoadingDialog(context);
          SettingsErrorHandler.handleError(
            context,
            e as Exception,
            operation: 'changing PIN',
          );
        }
      }
    }
  }

  /// Save PIN with loading indicator
  static Future<void> _savePinWithLoading(
    BuildContext context,
    SettingsService settingsService,
    String pin, {
    required bool isChange,
  }) async {
    SettingsErrorHandler.showLoadingDialog(
      context,
      title: 'Saving PIN',
      subtitle: 'Please wait while we securely save your PIN...',
    );

    try {
      await settingsService.setupPinCode(pin);

      if (context.mounted) {
        SettingsErrorHandler.hideLoadingDialog(context);
        SettingsErrorHandler.showSuccess(
          context,
          isChange ? 'PIN changed successfully' : 'PIN saved successfully',
        );
      }
    } catch (e) {
      if (context.mounted) {
        SettingsErrorHandler.hideLoadingDialog(context);
        SettingsErrorHandler.handleError(
          context,
          e as Exception,
          operation: 'saving PIN',
        );
      }
    }
  }

  /// Show forgot PIN dialog
  static void _showForgotPinDialog(BuildContext context) {
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
}
