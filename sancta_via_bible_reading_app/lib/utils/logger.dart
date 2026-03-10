/// Local AppLogger implementation for backward compatibility.
///
/// Provides static logging methods matching the original API.
/// This file intentionally does NOT import or export from shared_ui
/// to avoid name conflicts. Files that need both this AppLogger
/// and shared_ui components should use:
/// ```dart
/// import 'package:sancta_via_shared_ui/sancta_via_shared_ui.dart' hide AppLogger;
/// import '../utils/logger.dart';
/// ```
library;

import 'package:flutter/foundation.dart';

/// App-wide logging utility with static methods for easy access.
///
/// Provides consistent debug logging with app-specific prefixes.
// ignore: avoid_classes_with_only_static_members
class AppLogger {
  static const String _prefix = '[BibleReading]';

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
    if (kDebugMode) {
      final tagStr = tag != null ? '[$tag]' : '';
      print('$_prefix$tagStr WARNING: $message');
    }
  }

  /// Log errors (always logged, even in release)
  static void error(
    String message, [
    dynamic error,
    StackTrace? stackTrace,
    String? tag,
  ]) {
    final tagStr = tag != null ? '[$tag]' : '';
    if (kDebugMode) {
      print('$_prefix$tagStr ERROR: $message');
      if (error != null) print('Error details: $error');
      if (stackTrace != null) print('Stack trace: $stackTrace');
    }
  }

  /// Log provider operations
  static void provider(String message, [String? tag]) {
    debug(message, tag ?? 'PROVIDER');
  }

  /// Log routing operations
  static void route(String message, [String? tag]) {
    debug(message, tag ?? 'ROUTE');
  }

  /// Log service operations
  static void service(String message, [String? tag]) {
    debug(message, tag ?? 'SERVICE');
  }
}
