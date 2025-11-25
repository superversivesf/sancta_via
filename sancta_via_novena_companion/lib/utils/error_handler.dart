import 'package:flutter/material.dart';
import '../config/constants.dart';
import 'logger.dart';

/// Custom exception types for the app
class AppException implements Exception {
  final String message;
  final String? userFriendlyMessage;
  final dynamic originalError;

  AppException(this.message, {this.userFriendlyMessage, this.originalError});

  @override
  String toString() => message;
}

class NetworkException extends AppException {
  NetworkException([String? message])
    : super(
        message ?? 'Network error occurred',
        userFriendlyMessage: AppConstants.networkErrorMessage,
      );
}

class DataException extends AppException {
  DataException([String? message])
    : super(
        message ?? 'Data error occurred',
        userFriendlyMessage: AppConstants.genericErrorMessage,
      );
}

class AuthenticationException extends AppException {
  AuthenticationException([String? message])
    : super(
        message ?? 'Authentication failed',
        userFriendlyMessage: AppConstants.pinIncorrectMessage,
      );
}

class SessionException extends AppException {
  SessionException([String? message])
    : super(
        message ?? 'Session error occurred',
        userFriendlyMessage: AppConstants.sessionExpiredMessage,
      );
}

/// Error handling utility class
class ErrorHandler {
  /// Handle and log errors, optionally showing user feedback
  static void handleError(
    dynamic error, {
    StackTrace? stackTrace,
    BuildContext? context,
    String? customMessage,
    bool showUserMessage = true,
    String? tag,
  }) {
    // Log the error
    if (error is AppException) {
      AppLogger.error(
        customMessage ?? error.message,
        error.originalError ?? error,
        stackTrace,
        tag,
      );

      // Show user-friendly message if context provided
      if (context != null && showUserMessage) {
        _showErrorSnackBar(
          context,
          error.userFriendlyMessage ?? AppConstants.genericErrorMessage,
        );
      }
    } else {
      AppLogger.error(
        customMessage ?? 'Unexpected error occurred',
        error,
        stackTrace,
        tag,
      );

      // Show generic message for unexpected errors
      if (context != null && showUserMessage) {
        _showErrorSnackBar(context, AppConstants.genericErrorMessage);
      }
    }
  }

  /// Show error message to user via SnackBar
  static void _showErrorSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.error,
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'Dismiss',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  /// Show error dialog for critical errors
  static void showErrorDialog(
    BuildContext context,
    String title,
    String message, {
    VoidCallback? onRetry,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.error_outline,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(width: 8),
            Text(title),
          ],
        ),
        content: Text(message),
        actions: [
          if (onRetry != null)
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                onRetry();
              },
              child: const Text('Retry'),
            ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Wrap async operations with error handling
  static Future<T?> safeAsyncOperation<T>(
    Future<T> Function() operation, {
    BuildContext? context,
    String? errorMessage,
    String? tag,
    bool showUserMessage = true,
  }) async {
    try {
      return await operation();
    } catch (error, stackTrace) {
      handleError(
        error,
        stackTrace: stackTrace,
        context: context,
        customMessage: errorMessage,
        showUserMessage: showUserMessage,
        tag: tag,
      );
      return null;
    }
  }

  /// Create a safe future builder that handles errors
  static Widget safeFutureBuilder<T>({
    required Future<T> future,
    required Widget Function(BuildContext, T) builder,
    Widget? loadingWidget,
    Widget Function(BuildContext, String)? errorBuilder,
  }) {
    return FutureBuilder<T>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return loadingWidget ??
              const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          final errorMessage = snapshot.error is AppException
              ? (snapshot.error as AppException).userFriendlyMessage ??
                    AppConstants.genericErrorMessage
              : AppConstants.genericErrorMessage;

          return errorBuilder?.call(context, errorMessage) ??
              _buildDefaultErrorWidget(context, errorMessage);
        }

        if (snapshot.hasData) {
          return builder(context, snapshot.data as T);
        }

        return _buildDefaultErrorWidget(context, 'No data available');
      },
    );
  }

  static Widget _buildDefaultErrorWidget(BuildContext context, String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ],
      ),
    );
  }
}
