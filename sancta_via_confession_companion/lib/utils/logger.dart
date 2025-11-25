import 'dart:developer' as developer;

class AppLogger {
  static const bool _isDebugMode = true;

  static void log(String message, [String? tag]) {
    if (_isDebugMode) {
      developer.log(message, name: tag ?? 'App');
    }
  }

  static void error(
    String message,
    dynamic error,
    StackTrace? stackTrace, [
    String? tag,
  ]) {
    if (_isDebugMode) {
      developer.log(
        '$message: $error',
        name: tag ?? 'Error',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  static void warning(String message, [String? tag]) {
    if (_isDebugMode) {
      developer.log(message, name: tag ?? 'Warning');
    }
  }

  static void examination(String message) {
    log(message, 'EXAM');
  }

  static void repository(String message) {
    log(message, 'REPO');
  }
}
