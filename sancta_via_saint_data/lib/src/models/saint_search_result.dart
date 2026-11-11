import 'saint.dart';

/// A search hit: the matched saint plus why it matched.
class SaintSearchResult {
  const SaintSearchResult({required this.saint, required this.matchRationale});

  /// The matched saint.
  final Saint saint;

  /// Which index matched: `'name'`, `'patronage'`, or `'bio'`.
  final String matchRationale;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is SaintSearchResult &&
        other.saint == saint &&
        other.matchRationale == matchRationale;
  }

  @override
  int get hashCode => Object.hash(saint, matchRationale);

  @override
  String toString() =>
      'SaintSearchResult(slug: ${saint.slug}, rationale: $matchRationale)';
}
