import 'dart:async';

/// A simple async lock for synchronizing access to shared resources.
///
/// Usage:
/// ```dart
/// final _lock = AsyncLock();
///
/// await _lock.synchronized(() async {
///   // Critical section - only one operation at a time
///   _cache[key] = value;
/// });
/// ```
class AsyncLock {
  Completer<void>? _completer;

  /// Execute an async operation with exclusive access.
  Future<T> synchronized<T>(Future<T> Function() operation) async {
    // Wait for any pending operation to complete
    while (_completer != null && !_completer!.isCompleted) {
      await _completer!.future;
    }

    // Create a new completer for this operation
    _completer = Completer<void>();

    try {
      final result = await operation();
      return result;
    } finally {
      // Complete and clear the lock
      _completer!.complete();
      _completer = null;
    }
  }
}
