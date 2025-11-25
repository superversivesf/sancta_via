// Custom exception for data-related errors
class DataException implements Exception {
  final String message;

  DataException(this.message);

  @override
  String toString() => message;
}

// Custom exception for storage-related errors
class StorageException implements Exception {
  final String message;

  StorageException(this.message);

  @override
  String toString() => message;
}

// Global error handler
class ErrorHandler {
  static void handleError(dynamic error, StackTrace? stackTrace) {
    // In a real app, you might want to send errors to a logging service
    // Using AppLogger instead of print for production
    if (stackTrace != null) {
      // Import logger when needed
      // AppLogger.error('Global error handled', error, stackTrace);
    }
  }
}
