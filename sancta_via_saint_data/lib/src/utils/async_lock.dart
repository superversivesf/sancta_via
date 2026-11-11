import 'dart:async';

/// A simple async lock for synchronizing access to shared resources.
///
/// Usage:
/// ```dart
/// final AsyncLock lock = AsyncLock();
///
/// await lock.synchronized(() async {
///   // Critical section - only one operation at a time
/// });
/// ```
///
/// Local copy of `sancta_via_bible_data`'s AsyncLock: `saint_data` must not
/// depend on other workspace packages, so the serializing guard is
/// duplicated here instead of imported.
class AsyncLock {
  Completer<void>? _completer;

  /// Runs [operation] only after every previous [synchronized] call on this
  /// lock completed, serializing concurrent callers.
  Future<T> synchronized<T>(Future<T> Function() operation) async {
    // Wait for any pending operation to complete
    while (_completer != null && !_completer!.isCompleted) {
      await _completer!.future;
    }

    // Create a new completer for this operation
    _completer = Completer<void>();

    try {
      final T result = await operation();
      return result;
    } finally {
      // Complete and clear the lock
      _completer!.complete();
      _completer = null;
    }
  }
}
