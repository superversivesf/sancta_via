import 'package:flutter/foundation.dart';

/// Saint Companion app settings: favorite and recently-visited saint slugs.
@immutable
class SaintAppSettings {
  /// List of favorite saint slugs
  final List<String> favoriteSlugs;

  /// List of recently viewed saint slugs (most recent first)
  final List<String> recentSlugs;

  /// Maximum number of recent saints to keep
  static const int maxRecentSlugs = 50;

  const SaintAppSettings({
    this.favoriteSlugs = const [],
    this.recentSlugs = const [],
  });

  /// Create default Saint app settings
  factory SaintAppSettings.defaults() {
    return const SaintAppSettings();
  }

  /// Create from JSON map
  factory SaintAppSettings.fromJson(Map<String, dynamic> json) {
    return SaintAppSettings(
      favoriteSlugs: List<String>.from(
        (json['favoriteSlugs'] as List<dynamic>?) ?? <dynamic>[],
      ),
      recentSlugs: List<String>.from(
        (json['recentSlugs'] as List<dynamic>?) ?? <dynamic>[],
      ),
    );
  }

  /// Convert to JSON map
  Map<String, dynamic> toJson() {
    return {'favoriteSlugs': favoriteSlugs, 'recentSlugs': recentSlugs};
  }

  /// Create a copy with updated values
  SaintAppSettings copyWith({
    List<String>? favoriteSlugs,
    List<String>? recentSlugs,
  }) {
    return SaintAppSettings(
      favoriteSlugs: favoriteSlugs ?? this.favoriteSlugs,
      recentSlugs: recentSlugs ?? this.recentSlugs,
    );
  }

  /// Add a saint to favorites
  SaintAppSettings addFavorite(String slug) {
    if (favoriteSlugs.contains(slug)) return this;
    final newFavorites = [...favoriteSlugs, slug];
    return copyWith(favoriteSlugs: newFavorites);
  }

  /// Remove a saint from favorites
  SaintAppSettings removeFavorite(String slug) {
    final newFavorites = favoriteSlugs.where((s) => s != slug).toList();
    return copyWith(favoriteSlugs: newFavorites);
  }

  /// Add a saint to the recent list (most recent first, deduped, capped)
  SaintAppSettings addToRecent(String slug) {
    final newRecent = <String>[slug];
    newRecent.addAll(recentSlugs.where((s) => s != slug));
    if (newRecent.length > maxRecentSlugs) {
      newRecent.removeRange(maxRecentSlugs, newRecent.length);
    }
    return copyWith(recentSlugs: newRecent);
  }

  /// Check if a saint is favorited
  bool isFavorite(String slug) => favoriteSlugs.contains(slug);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SaintAppSettings &&
        listEquals(other.favoriteSlugs, favoriteSlugs) &&
        listEquals(other.recentSlugs, recentSlugs);
  }

  @override
  int get hashCode {
    return Object.hash(
      Object.hashAll(favoriteSlugs),
      Object.hashAll(recentSlugs),
    );
  }

  @override
  String toString() {
    return 'SaintAppSettings('
        'favoriteSlugs: $favoriteSlugs, '
        'recentSlugs: $recentSlugs'
        ')';
  }
}
