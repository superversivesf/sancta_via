/// Local AppLogger implementation for the devotionals app.
///
/// This file intentionally does NOT import or export from shared_ui
/// to avoid name conflicts. Files that need both this AppLogger
/// and shared_ui components should use:
/// ```dart
/// import 'package:sancta_via_shared_ui/sancta_via_shared_ui.dart' hide AppLogger;
/// import '../utils/logger.dart';
/// ```
library;

import 'package:flutter/foundation.dart';

/// Minimal app logger for the devotionals app, mirroring the sibling apps'
/// `AppLogger` (prayer/saint precedent): tagged methods and a debug-only
/// print for routine messages.
///
/// Delivery is pinned here so the repository seam can log its safe defaults;
/// Task 6's content pipeline consumes the same surface.
class AppLogger {
  static const String _prefix = '[Devotionals]';

  static String _tagSuffix(String? tag) => tag == null ? '' : '[$tag]';

  /// Log debug information (only in debug mode).
  static void debug(String message, [String? tag]) {
    if (kDebugMode) {
      debugPrint('$_prefix${_tagSuffix(tag)} DEBUG: $message');
    }
  }

  /// Log info messages (only in debug mode).
  static void info(String message, [String? tag]) {
    if (kDebugMode) {
      debugPrint('$_prefix${_tagSuffix(tag)} INFO: $message');
    }
  }

  /// Log warnings (only in debug mode, as in the sibling apps).
  static void warning(String message, [String? tag]) {
    if (kDebugMode) {
      debugPrint('$_prefix${_tagSuffix(tag)} WARNING: $message');
    }
  }

  /// Log errors (debug-mode print; release relies on crash reporting).
  static void error(
    String message, [
    dynamic error,
    StackTrace? stackTrace,
    String? tag,
  ]) {
    if (kDebugMode) {
      debugPrint('$_prefix${_tagSuffix(tag)} ERROR: $message');
      if (error != null) {
        debugPrint('Error details: $error');
      }
      if (stackTrace != null) {
        debugPrint('Stack trace: $stackTrace');
      }
    }
  }

  /// Log repository operations.
  static void repository(String message) {
    debug(message, 'REPO');
  }
}
