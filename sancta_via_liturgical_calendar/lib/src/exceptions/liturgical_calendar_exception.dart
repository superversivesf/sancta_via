/// Types of liturgical calendar exceptions
enum LiturgicalCalendarExceptionType {
  initialization,
  notInitialized,
  dataLoading,
  yearNotAvailable,
  invalidDate,
  dataFormat,
}

/// Exception thrown by liturgical calendar operations
class LiturgicalCalendarException implements Exception {
  final String message;
  final LiturgicalCalendarExceptionType type;
  final Object? originalException;
  final StackTrace? stackTrace;

  const LiturgicalCalendarException(
    this.message, {
    required this.type,
    this.originalException,
    this.stackTrace,
  });

  @override
  String toString() {
    return 'LiturgicalCalendarException(${type.name}): $message';
  }

  /// Create an exception for initialization failures
  static LiturgicalCalendarException initialization(
    String details, [
    Object? cause,
  ]) {
    return LiturgicalCalendarException(
      'Failed to initialize liturgical calendar: $details',
      type: LiturgicalCalendarExceptionType.initialization,
      originalException: cause,
    );
  }

  /// Create an exception for uninitialized service
  static LiturgicalCalendarException notInitialized() {
    return const LiturgicalCalendarException(
      'Liturgical calendar service not initialized. Call initialize() first.',
      type: LiturgicalCalendarExceptionType.notInitialized,
    );
  }

  /// Create an exception for unavailable years
  static LiturgicalCalendarException yearNotAvailable(int year) {
    return LiturgicalCalendarException(
      'Year $year not available in liturgical data',
      type: LiturgicalCalendarExceptionType.yearNotAvailable,
    );
  }

  /// Create an exception for data loading failures
  static LiturgicalCalendarException dataLoading(
    String details, [
    Object? cause,
  ]) {
    return LiturgicalCalendarException(
      'Failed to load liturgical data: $details',
      type: LiturgicalCalendarExceptionType.dataLoading,
      originalException: cause,
    );
  }

  /// Create an exception for invalid dates
  static LiturgicalCalendarException invalidDate(String details) {
    return LiturgicalCalendarException(
      'Invalid date: $details',
      type: LiturgicalCalendarExceptionType.invalidDate,
    );
  }

  /// Create an exception for data format issues
  static LiturgicalCalendarException dataFormat(
    String details, [
    Object? cause,
  ]) {
    return LiturgicalCalendarException(
      'Data format error: $details',
      type: LiturgicalCalendarExceptionType.dataFormat,
      originalException: cause,
    );
  }
}
