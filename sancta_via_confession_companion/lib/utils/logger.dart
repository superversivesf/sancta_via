import 'package:flutter/foundation.dart';

class AppLogger {
  static const String _prefix = '[Confession]';

  static void debug(String message, [String? tag]) {
    if (kDebugMode) {
      final tagStr = tag != null ? '[$tag]' : '';
      print('$_prefix$tagStr DEBUG: $message');
    }
  }

  static void info(String message, [String? tag]) {
    if (kDebugMode) {
      final tagStr = tag != null ? '[$tag]' : '';
      print('$_prefix$tagStr INFO: $message');
    }
  }

  static void warning(String message, [String? tag]) {
    if (kDebugMode) {
      final tagStr = tag != null ? '[$tag]' : '';
      print('$_prefix$tagStr WARNING: $message');
    }
  }

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

  static void log(String message, [String? tag]) {
    debug(message, tag);
  }

  static void examination(String message) {
    debug(message, 'EXAM');
  }

  static void repository(String message) {
    debug(message, 'REPO');
  }
}
