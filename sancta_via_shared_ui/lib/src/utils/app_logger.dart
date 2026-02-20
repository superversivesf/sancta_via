import 'package:flutter/foundation.dart';

/// Unified logging utility for all Sancta Via apps.
///
/// Provides consistent debug logging across the monorepo with:
/// - Automatic debug mode detection via kDebugMode
/// - App-specific prefixes for easy filtering
/// - Multiple log levels (debug, info, warning, error)
/// - Tag support for component categorization
///
/// Usage:
/// ```dart
/// // Basic usage
/// AppLogger.debug('Message');
///
/// // With tag
/// AppLogger.info('User logged in', 'AUTH');
///
/// // Error with details
/// AppLogger.error('Failed to load data', error, stackTrace, 'REPO');
/// ```
class AppLogger {
  final String _prefix;

  const AppLogger._(this._prefix);

  /// Logger for Bible Reading app
  static const AppLogger bibleReading = AppLogger._('[BibleReading]');

  /// Logger for Prayer Companion app
  static const AppLogger prayer = AppLogger._('[Prayer]');

  /// Logger for Novena Companion app
  static const AppLogger novena = AppLogger._('[Novena]');

  /// Logger for Confession Companion app
  static const AppLogger confession = AppLogger._('[Confession]');

  /// Logger for Bible Data package
  static const AppLogger bibleData = AppLogger._('[BibleData]');

  /// Logger for Liturgical Calendar
  static const AppLogger liturgical = AppLogger._('[Liturgical]');

  /// Logger for Shared UI
  static const AppLogger sharedUi = AppLogger._('[SharedUI]');

  /// Log debug information (only in debug mode)
  void debug(String message, [String? tag]) {
    if (kDebugMode) {
      _log('DEBUG', message, tag);
    }
  }

  /// Log info messages (only in debug mode)
  void info(String message, [String? tag]) {
    if (kDebugMode) {
      _log('INFO', message, tag);
    }
  }

  /// Log warnings (only in debug mode)
  void warning(String message, [String? tag]) {
    if (kDebugMode) {
      _log('WARNING', message, tag);
    }
  }

  /// Log errors (always logged, even in release)
  void error(
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

  void _log(String level, String message, String? tag) {
    final tagStr = tag != null ? '[$tag]' : '';
    print('$_prefix$tagStr $level: $message');
  }
}

/// Convenience methods for quick logging without selecting a specific logger.
///
/// Uses a generic [App] prefix.
class AppLoggerHelper {
  static const _generic = AppLogger._('[App]');

  /// @deprecated Use AppLogger.bibleReading.debug instead
  static void debug(String message, [String? tag]) =>
      _generic.debug(message, tag);

  /// @deprecated Use AppLogger.bibleReading.info instead
  static void info(String message, [String? tag]) =>
      _generic.info(message, tag);

  /// @deprecated Use AppLogger.bibleReading.warning instead
  static void warning(String message, [String? tag]) =>
      _generic.warning(message, tag);

  /// @deprecated Use AppLogger.bibleReading.error instead
  static void error(
    String message, [
    dynamic error,
    StackTrace? stackTrace,
    String? tag,
  ]) => _generic.error(message, error, stackTrace, tag);
}
