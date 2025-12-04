import 'package:flutter/foundation.dart';

/// Simple logging utility for the app
///
/// Provides debug, info, warning, and error logging with optional tags
class AppLogger {
  /// Log a debug message (only in debug mode)
  static void debug(String message, String tag) {
    if (kDebugMode) {
      debugPrint('[$tag] DEBUG: $message');
    }
  }

  /// Log an info message
  static void info(String message, String tag) {
    if (kDebugMode) {
      debugPrint('[$tag] INFO: $message');
    }
  }

  /// Log a warning message
  static void warning(String message, String tag) {
    if (kDebugMode) {
      debugPrint('[$tag] WARNING: $message');
    }
  }

  /// Log an error message with optional exception and stack trace
  static void error(
    String message,
    Object? error,
    StackTrace? stackTrace,
    String tag,
  ) {
    if (kDebugMode) {
      debugPrint('[$tag] ERROR: $message');
      if (error != null) {
        debugPrint('[$tag] Exception: $error');
      }
      if (stackTrace != null) {
        debugPrint('[$tag] Stack trace:\n$stackTrace');
      }
    }
  }
}
