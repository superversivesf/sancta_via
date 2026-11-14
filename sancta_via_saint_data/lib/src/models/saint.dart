import 'saint_category.dart';

/// A single need a saint is invoked for, with its taxonomy category.
class SaintPatronage {
  const SaintPatronage({required this.need, required this.category});

  /// The need this saint is patron of, lowercase (e.g. `lost items`).
  final String need;

  /// The taxonomy category the need belongs to.
  final SaintCategory category;

  /// Parses one entry from a saint-for-that `patronages` array.
  ///
  /// Throws [FormatException] when `need` is missing or the `category` id
  /// is missing or unknown.
  factory SaintPatronage.fromJson(Map<String, dynamic> json) {
    final String? need = json['need'] as String?;
    final String? categoryId = json['category'] as String?;
    final SaintCategory? category = categoryId == null
        ? null
        : SaintCategory.tryParse(categoryId);
    if (need == null || category == null) {
      throw FormatException(
        'SaintPatronage requires a "need" and a known "category", got: $json',
      );
    }
    return SaintPatronage(need: need, category: category);
  }

  /// Serializes back to the saint-for-that patronage shape.
  Map<String, dynamic> toJson() {
    return <String, dynamic>{'need': need, 'category': category.name};
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is SaintPatronage &&
        other.need == need &&
        other.category == category;
  }

  @override
  int get hashCode => Object.hash(need, category);

  @override
  String toString() =>
      'SaintPatronage(need: $need, category: ${category.name})';
}

/// A collect-style prayer shipped with a saint.
class SaintPrayer {
  const SaintPrayer({required this.text, required this.source});

  /// Recognized prayer sources in the dataset.
  static const List<String> validSources = <String>['traditional', 'original'];

  /// The prayer body.
  final String text;

  /// `'traditional'` (existing collect) or `'original'` (dataset-composed).
  final String source;

  /// Parses a prayer object from a saint-for-that record.
  ///
  /// Throws [FormatException] when `text` or `source` is missing.
  factory SaintPrayer.fromJson(Map<String, dynamic> json) {
    final String? text = json['text'] as String?;
    final String? source = json['source'] as String?;
    if (text == null || source == null) {
      throw FormatException(
        'SaintPrayer requires "text" and "source", got: $json',
      );
    }
    return SaintPrayer(text: text, source: source);
  }

  /// Serializes back to the saint-for-that prayer shape.
  Map<String, dynamic> toJson() {
    return <String, dynamic>{'text': text, 'source': source};
  }

  /// True when the prayer has text and a recognized source.
  bool get isValid {
    return text.trim().isNotEmpty && validSources.contains(source);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is SaintPrayer && other.text == text && other.source == source;
  }

  @override
  int get hashCode => Object.hash(text, source);

  @override
  String toString() => 'SaintPrayer(source: $source, length: ${text.length})';
}

/// A saint in the runtime/DB shape: everything the app ships.
///
/// The raw source records carry a `draft` flag; that flag is dropped here —
/// the runtime model only carries what lands in the SQLite database.
class Saint {
  const Saint({
    required this.slug,
    required this.name,
    required this.feastDay,
    this.canonized,
    required this.bio,
    this.prayer,
    this.patronages = const <SaintPatronage>[],
    this.featured = false,
    this.thumbAsset,
    this.imageAttribution,
    this.imageAlt,
    this.history,
    this.historySource,
    this.sources = const <String>[],
  });

  /// Kebab-case unique id, e.g. `abba-garima`.
  final String slug;

  /// Display name, e.g. `St. Abba Garima`.
  final String name;

  /// Feast day as `MM-DD`, or `unknown` when not assigned.
  final String feastDay;

  /// Canonization status (e.g. `Pre-Congregation`), when known.
  final String? canonized;

  /// Longer biography text.
  final String bio;

  /// The saint's prayer, when the record ships one.
  final SaintPrayer? prayer;

  /// Patronage entries (need + category).
  final List<SaintPatronage> patronages;

  /// Whether the saint belongs to the featured homepage set.
  final bool featured;

  /// Bundled thumbnail path (`assets/thumbs/<slug>.jpg`), or `null`.
  final String? thumbAsset;

  /// Image attribution shown on the detail screen.
  final String? imageAttribution;

  /// Image alt text for accessibility.
  final String? imageAlt;

  /// The saint's grounded history body (schema v2), when one was accepted
  /// for the saint; absent for every other saint (they render their bio).
  final String? history;

  /// The history's pinned provenance id + URL, e.g.
  /// `catholic-encyclopedia-1907 https://www.newadvent.org/cathen/<code>.htm`.
  final String? historySource;

  /// Source URLs backing the record.
  final List<String> sources;

  /// Parses a RAW saint-for-that record.
  ///
  /// `featured` defaults to false when absent; the `draft` flag is
  /// intentionally dropped. A present `image` object marks the saint as
  /// having a bundled thumb at `assets/thumbs/<slug>.jpg` and carries its
  /// attribution/alt text (the image `url` itself is not retained).
  factory Saint.fromSourceJson(Map<String, dynamic> json) {
    final String slug = json['slug'] as String;
    final Map<String, dynamic>? image = json['image'] as Map<String, dynamic>?;
    final Map<String, dynamic>? sourceImage = image == null
        ? null
        : <String, dynamic>{...image};
    final Object? rawPrayer = json['prayer'];
    final SaintPrayer? prayer = rawPrayer == null
        ? null
        : SaintPrayer.fromJson(rawPrayer as Map<String, dynamic>);
    final List<SaintPatronage> patronages = <SaintPatronage>[
      for (final Object? item
          in json['patronages'] as List<Object?>? ?? const <Object?>[])
        SaintPatronage.fromJson(item as Map<String, dynamic>),
    ];
    final List<String> sources = <String>[
      for (final Object? source
          in json['sources'] as List<Object?>? ?? const <Object?>[])
        source as String,
    ];
    return Saint(
      slug: slug,
      name: json['name'] as String,
      feastDay: json['feastDay'] as String? ?? 'unknown',
      canonized: json['canonized'] as String?,
      bio: json['bio'] as String,
      prayer: prayer,
      patronages: patronages,
      featured: json['featured'] as bool? ?? false,
      thumbAsset: image == null ? null : 'assets/thumbs/$slug.jpg',
      imageAttribution: sourceImage == null
          ? null
          : sourceImage['attribution'] as String?,
      imageAlt: sourceImage == null ? null : sourceImage['altText'] as String?,
      history: json['history'] as String?,
      historySource: json['historySource'] as String?,
      sources: sources,
    );
  }

  /// Builds a saint from a SQLite `saints` row.
  ///
  /// The row uses the DB column names (`slug`, `name`, `feast_day`,
  /// `canonized`, `bio`, `prayer_text`, `prayer_source`, `featured`,
  /// `thumb_asset`, `image_attribution`, `image_alt`, and — schema v2 —
  /// `history`, `history_source`); patronages and sources are read
  /// separately from the `patronages` and `sources` tables and passed in
  /// explicitly for tests (parameters default null/empty).
  factory Saint.fromDbRow(
    Map<String, dynamic> row, {
    List<SaintPatronage> patronages = const <SaintPatronage>[],
    List<String> sources = const <String>[],
    String? history,
    String? historySource,
  }) {
    final Object? prayerText = row['prayer_text'];
    final Object? prayerSource = row['prayer_source'];
    final SaintPrayer? prayer = prayerText == null
        ? null
        : SaintPrayer(
            text: prayerText as String,
            source: prayerSource == null
                ? 'traditional'
                : prayerSource as String,
          );
    return Saint(
      slug: row['slug'] as String,
      name: row['name'] as String,
      feastDay: row['feast_day'] as String,
      canonized: row['canonized'] as String?,
      bio: row['bio'] as String,
      prayer: prayer,
      patronages: patronages,
      featured: switch (row['featured']) {
        final bool value => value,
        final num value => value != 0,
        _ => false,
      },
      thumbAsset: row['thumb_asset'] as String?,
      imageAttribution: row['image_attribution'] as String?,
      imageAlt: row['image_alt'] as String?,
      history: history ?? row['history'] as String?,
      historySource: historySource ?? row['history_source'] as String?,
      sources: sources,
    );
  }

  /// Serializes back to the saint-for-that record shape.
  ///
  /// `draft` is not emitted (the runtime model drops it), and the image
  /// `url` is not emitted (it is not retained on the runtime model); a
  /// present `image` object still round-trips thumb attribution/alt text.
  Map<String, dynamic> toSourceJson() {
    return <String, dynamic>{
      'slug': slug,
      'name': name,
      'feastDay': feastDay,
      if (canonized != null) 'canonized': canonized,
      'bio': bio,
      if (history != null) 'history': history,
      if (historySource != null) 'historySource': historySource,
      if (prayer != null) 'prayer': prayer!.toJson(),
      'patronages': <Map<String, dynamic>>[
        for (final SaintPatronage patronage in patronages) patronage.toJson(),
      ],
      'featured': featured,
      if (hasImage)
        'image': <String, dynamic>{
          if (imageAttribution != null) 'attribution': imageAttribution,
          if (imageAlt != null) 'altText': imageAlt,
        },
      'sources': List<String>.of(sources),
    };
  }

  /// True when a bundled thumbnail is available.
  bool get hasImage => thumbAsset != null;

  /// True when the record ships a prayer.
  bool get hasPrayer => prayer != null;

  /// True when the feast day is a real `MM-DD` date.
  bool get hasKnownFeast => feastDay != 'unknown' && feastDay.isNotEmpty;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is Saint &&
        other.slug == slug &&
        other.name == name &&
        other.feastDay == feastDay &&
        other.canonized == canonized &&
        other.bio == bio &&
        other.prayer == prayer &&
        _listEquals(other.patronages, patronages) &&
        other.featured == featured &&
        other.thumbAsset == thumbAsset &&
        other.imageAttribution == imageAttribution &&
        other.imageAlt == imageAlt &&
        other.history == history &&
        other.historySource == historySource &&
        _listEquals(other.sources, sources);
  }

  @override
  int get hashCode => Object.hash(
    slug,
    name,
    feastDay,
    canonized,
    bio,
    prayer,
    Object.hashAll(patronages),
    featured,
    thumbAsset,
    imageAttribution,
    imageAlt,
    history,
    historySource,
    Object.hashAll(sources),
  );

  @override
  String toString() =>
      'Saint(slug: $slug, name: $name, patronages: ${patronages.length})';
}

/// Field-by-field list comparison for model equality.
bool _listEquals<T>(List<T> a, List<T> b) {
  if (a.length != b.length) {
    return false;
  }
  for (int i = 0; i < a.length; i++) {
    if (a[i] != b[i]) {
      return false;
    }
  }
  return true;
}
