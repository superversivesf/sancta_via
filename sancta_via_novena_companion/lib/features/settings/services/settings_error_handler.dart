import 'package:flutter/material.dart';
import '../../../utils/logger.dart';

/// Centralized error handling for settings
class SettingsErrorHandler {
  /// Handle settings-related errors with user-friendly messages
  static void handleError(
    BuildContext context,
    Exception error, {
    String? operation,
    VoidCallback? onRetry,
  }) {
    final String userMessage = _getUserFriendlyMessage(error);

    if (operation != null) {
      AppLogger.error(
        'Settings error during $operation',
        error,
        null,
        'SETTINGS_ERROR',
      );
    }

    _showErrorSnackBar(context, userMessage, onRetry: onRetry);
  }

  /// Show success message
  static void showSuccess(
    BuildContext context,
    String message, {
    Color? backgroundColor,
  }) {
    _showSuccessSnackBar(context, message, backgroundColor: backgroundColor);
  }

  /// Convert technical errors to user-friendly messages
  static String _getUserFriendlyMessage(Exception error) {
    final errorString = error.toString().toLowerCase();

    if (errorString.contains('ios simulator')) {
      return 'PIN setup not available in iOS Simulator. Please test on a physical device.';
    } else if (errorString.contains('secure storage')) {
      return 'Secure storage not available. This may be due to device or permission issues.';
    } else if (errorString.contains('incorrect') ||
        errorString.contains('invalid pin')) {
      return 'Incorrect PIN. Please try again.';
    } else if (errorString.contains('pin must be')) {
      return 'PIN must be exactly 4 digits.';
    } else if (errorString.contains('pins do not match')) {
      return 'PINs do not match. Please try again.';
    } else if (errorString.contains('network') ||
        errorString.contains('connection')) {
      return 'Network error. Please check your connection and try again.';
    } else if (errorString.contains('storage') ||
        errorString.contains('database')) {
      return 'Storage error. Please restart the app and try again.';
    } else {
      return 'An unexpected error occurred. Please try again.';
    }
  }

  static void _showErrorSnackBar(
    BuildContext context,
    String message, {
    VoidCallback? onRetry,
  }) {
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
        action: onRetry != null
            ? SnackBarAction(
                label: 'Retry',
                textColor: Colors.white,
                onPressed: onRetry,
              )
            : null,
      ),
    );
  }

  static void _showSuccessSnackBar(
    BuildContext context,
    String message, {
    Color? backgroundColor,
  }) {
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

  /// Show confirmation dialog for destructive actions
  static Future<bool> showConfirmationDialog(
    BuildContext context, {
    required String title,
    required String message,
    required String confirmText,
    String cancelText = 'Cancel',
    Color? confirmColor,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(cancelText),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: confirmColor != null
                ? TextButton.styleFrom(foregroundColor: confirmColor)
                : null,
            child: Text(confirmText),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  /// Show loading dialog
  static void showLoadingDialog(
    BuildContext context, {
    required String title,
    String? subtitle,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(title),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
            ],
          ],
        ),
      ),
    );
  }

  /// Hide loading dialog
  static void hideLoadingDialog(BuildContext context) {
    Navigator.of(context).pop();
  }
}
