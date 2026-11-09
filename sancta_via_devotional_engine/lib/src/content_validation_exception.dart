/// Typed exception raised when devotional content fails validation.
///
/// Carries a human-readable [message] summarizing the failure and the
/// concrete [problems] that were detected (e.g. empty required fields).
class ContentValidationException implements Exception {
  /// A short summary of why validation failed.
  final String message;

  /// The individual validation problems that were detected.
  final List<String> problems;

  /// Creates a [ContentValidationException].
  const ContentValidationException({
    required this.message,
    required this.problems,
  });

  @override
  String toString() => 'ContentValidationException: $message';
}
