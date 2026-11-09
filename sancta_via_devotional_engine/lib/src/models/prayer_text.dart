import '../content_validation_exception.dart';

/// The text of a prayer used by a devotional program.
///
/// A [PrayerText] is immutable content: an [id] identifying the prayer, the
/// vernacular [text], an optional [latin] rendering, and attribution metadata
/// ([source] and [license]). Both [source] and [license] are required to be
/// non-empty; constructing a [PrayerText] with an empty value throws a
/// [ContentValidationException].
class PrayerText {
  /// The stable identifier of the prayer.
  final String id;

  /// The vernacular text of the prayer.
  final String text;

  /// The optional Latin rendering of the prayer.
  final String? latin;

  /// The source/attribution of the prayer text.
  final String source;

  /// The license under which the prayer text is used.
  final String license;

  /// Creates a validated [PrayerText].
  ///
  /// Throws [ContentValidationException] when [source] or [license] is empty.
  PrayerText({
    required this.id,
    required this.text,
    this.latin,
    required this.source,
    required this.license,
  }) {
    final List<String> problems = <String>[];
    if (source.isEmpty) {
      problems.add('source must not be empty');
    }
    if (license.isEmpty) {
      problems.add('license must not be empty');
    }
    if (problems.isNotEmpty) {
      throw ContentValidationException(
        message: 'PrayerText "$id" failed validation: ${problems.join('; ')}',
        problems: problems,
      );
    }
  }

  /// Reconstructs a [PrayerText] from its JSON representation.
  factory PrayerText.fromJson(Map<String, dynamic> json) {
    return PrayerText(
      id: json['id'] as String,
      text: json['text'] as String,
      latin: json['latin'] as String?,
      source: json['source'] as String,
      license: json['license'] as String,
    );
  }

  /// Serializes this [PrayerText] to a JSON-compatible map.
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'text': text,
      'latin': latin,
      'source': source,
      'license': license,
    };
  }

  @override
  String toString() =>
      'PrayerText(id: $id, text: $text, latin: $latin, source: $source, '
      'license: $license)';

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is PrayerText &&
            runtimeType == other.runtimeType &&
            id == other.id &&
            text == other.text &&
            latin == other.latin &&
            source == other.source &&
            license == other.license;
  }

  @override
  int get hashCode =>
      id.hashCode ^
      text.hashCode ^
      latin.hashCode ^
      source.hashCode ^
      license.hashCode;
}
