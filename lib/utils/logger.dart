import 'package:flutter/foundation.dart';

class AppLogger {
  static const String _prefix = '[PrayerCompanion]';
  
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
  
  /// Log warnings (appears in both debug and release for important issues)
  static void warning(String message, [String? tag]) {
    final tagStr = tag != null ? '[$tag]' : '';
    if (kDebugMode) {
      print('$_prefix$tagStr WARNING: $message');
    }
  }
  
  /// Log errors (always logged, even in release)
  static void error(String message, [dynamic error, StackTrace? stackTrace, String? tag]) {
    final tagStr = tag != null ? '[$tag]' : '';
    if (kDebugMode) {
      print('$_prefix$tagStr ERROR: $message');
      if (error != null) print('Error details: $error');
      if (stackTrace != null) print('Stack trace: $stackTrace');
    }
  }
  
  /// Log prayer-specific operations
  static void prayer(String message) {
    debug(message, 'PRAYER');
  }
  
  /// Log repository operations
  static void repository(String message) {
    debug(message, 'REPO');
  }
}