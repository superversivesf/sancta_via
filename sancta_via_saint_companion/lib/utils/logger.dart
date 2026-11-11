import 'package:flutter/foundation.dart';

/// Local mirror of the [AppLogger] convention for the Saint Companion app.
///
/// `sancta_via_shared_ui` exports a shared `AppLogger`, but it is
/// instance-based and has no `[SaintCompanion]` logger instance, and
/// `prayer_companion` established the static local-mirror precedent
/// (`lib/utils/logger.dart`). Keep the method shape and release behavior
/// identical to the shared logger: debug/info/warning are gated to debug
/// mode, errors are always logged.
class AppLogger {
  static const String _prefix = '[SaintCompanion]';

  /// Log debug information (only in debug mode)
  static void debug(String message, [String? tag]) {
    if (kDebugMode) {
      final tagStr = tag != null ? '[$tag]' : '';
      print('$_prefix$tagStr DEBUG: $message');
    }
  }

  /// Log info messages (only in debug mode)
  static void info(String message, [String? tag]) {
    if (kDebugMode) {
      final tagStr = tag != null ? '[$tag]' : '';
      print('$_prefix$tagStr INFO: $message');
    }
  }

  /// Log warnings (only in debug mode)
  static void warning(String message, [String? tag]) {
    final tagStr = tag != null ? '[$tag]' : '';
    if (kDebugMode) {
      print('$_prefix$tagStr WARNING: $message');
    }
  }

  /// Log errors (always logged, even in release; details only in debug)
  static void error(
    String message, [
    dynamic error,
    StackTrace? stackTrace,
    String? tag,
  ]) {
    final tagStr = tag != null ? '[$tag]' : '';
    print('$_prefix$tagStr ERROR: $message');
    if (kDebugMode) {
      if (error != null) print('Error details: $error');
      if (stackTrace != null) print('Stack trace: $stackTrace');
    }
  }
}
