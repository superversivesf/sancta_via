import 'package:flutter/foundation.dart';

/// Logger for the Rosary app.
///
/// Provides consistent logging with app-specific prefix.
/// Delegates to sancta_via_shared_ui AppLogger if available,
/// otherwise provides standalone implementation.
class AppLogger {
  static const String _prefix = '[Rosary]';

  /// Log debug information (only in debug mode)
  static void debug(String message, [String? tag]) {
    if (kDebugMode) {
      _log('DEBUG', message, tag);
    }
  }

  /// Log info messages (only in debug mode)
  static void info(String message, [String? tag]) {
    if (kDebugMode) {
      _log('INFO', message, tag);
    }
  }

  /// Log warnings (only in debug mode)
  static void warning(String message, [String? tag]) {
    if (kDebugMode) {
      _log('WARNING', message, tag);
    }
  }

  /// Log errors (always logged, even in release)
  static void error(
    String message, [
    dynamic error,
    StackTrace? stackTrace,
    String? tag,
  ]) {
    _log('ERROR', message, tag);
    if (kDebugMode && error != null) {
      print('$_prefix Error details: $error');
    }
    if (kDebugMode && stackTrace != null) {
      print('$_prefix Stack trace: $stackTrace');
    }
  }

  static void _log(String level, String message, String? tag) {
    final tagStr = tag != null ? '[$tag]' : '';
    print('$_prefix$tagStr $level: $message');
  }
}
