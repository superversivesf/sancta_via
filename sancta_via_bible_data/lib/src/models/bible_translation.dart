/// Enumeration of supported Bible translations
enum BibleTranslation {
  /// Catholic Public Domain Version
  cpdv('cpdv', 'Catholic Public Domain Version', 'CPDV'),

  /// Douay-Rheims 1899 American Edition
  drc('drc', 'Douay-Rheims 1899', 'DRC'),

  /// World English Bible Catholic Edition
  engwebc('engwebc', 'World English Bible Catholic', 'WEB-C');

  const BibleTranslation(this.id, this.name, this.abbreviation);

  /// Unique identifier for the translation
  final String id;

  /// Full name of the translation
  final String name;

  /// Common abbreviation
  final String abbreviation;

  /// Get translation by ID
  static BibleTranslation fromId(String id) {
    return BibleTranslation.values.firstWhere(
      (translation) => translation.id == id,
      orElse: () => BibleTranslation.cpdv, // Default to CPDV
    );
  }

  /// Get the default translation
  static BibleTranslation get defaultTranslation => BibleTranslation.cpdv;

  /// Check if a translation ID is supported
  static bool isSupported(String id) {
    return BibleTranslation.values.any((translation) => translation.id == id);
  }

  /// Get all available translation IDs
  static List<String> get availableIds =>
      BibleTranslation.values.map((t) => t.id).toList();
}
