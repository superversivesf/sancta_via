import 'package:flutter/foundation.dart';

/// Logger for the saint_data package.
///
/// Writes to stdout in debug builds only ([kDebugMode]); no-ops in release.
class SaintLogger {
  static const String _prefix = '[SaintData]';

  /// Logs a debug-level message.
  static void debug(String message, {required String tag}) {
    if (kDebugMode) {
      print('$_prefix[$tag] DEBUG: $message');
    }
  }

  /// Logs an informational message.
  static void info(String message, {required String tag}) {
    if (kDebugMode) {
      print('$_prefix[$tag] INFO: $message');
    }
  }

  /// Logs a warning message.
  static void warning(String message, {required String tag}) {
    if (kDebugMode) {
      print('$_prefix[$tag] WARNING: $message');
    }
  }

  /// Logs an error with its underlying [Object] and [StackTrace].
  static void error(
    String message,
    Object error,
    StackTrace stackTrace, {
    required String tag,
  }) {
    if (kDebugMode) {
      print('$_prefix[$tag] ERROR: $message');
      print('Error details: $error');
      print('Stack trace: $stackTrace');
    }
  }
}
