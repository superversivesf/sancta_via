import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sancta_via_liturgical_calendar_riverpod/sancta_via_liturgical_calendar_riverpod.dart';

import '../models/prayer.dart';
import '../models/prayer_category.dart';
import '../models/prayer_category_group.dart';
import '../models/prayer_metadata.dart';
import '../models/prayer_preferences.dart';
import '../repositories/prayer_repository.dart';
import '../services/prayer_of_the_day_service.dart';
import '../widgets/enhanced_prayer_text.dart';

// Provider for the repository
final prayerRepositoryProvider = Provider<PrayerRepository>((ref) {
  return PrayerRepository();
});

// Provider for prayer categories
final prayerCategoriesProvider = FutureProvider<List<PrayerCategory>>((ref) async {
  final repository = ref.watch(prayerRepositoryProvider);
  return await repository.getPrayerCategories();
});

// Provider for prayer category groups
final prayerCategoryGroupsProvider = FutureProvider<List<PrayerCategoryGroup>>((ref) async {
  final repository = ref.watch(prayerRepositoryProvider);
  return await repository.getPrayerCategoryGroups();
});

// Provider for all prayer metadata
final prayerMetadataProvider = FutureProvider<List<PrayerMetadata>>((ref) async {
  final repository = ref.watch(prayerRepositoryProvider);
  return await repository.getPrayerMetadata();
});

// Provider for prayers by category
final prayersByCategoryProvider = FutureProvider.family<List<PrayerMetadata>, String>((ref, categoryId) async {
  final repository = ref.watch(prayerRepositoryProvider);
  return await repository.getPrayersByCategory(categoryId);
});

// Provider for prayers by group
final prayersByGroupProvider = FutureProvider.family<List<PrayerMetadata>, String>((ref, groupId) async {
  final repository = ref.watch(prayerRepositoryProvider);
  return await repository.getPrayersByGroup(groupId);
});

// Provider for a specific prayer
final prayerProvider = FutureProvider.family<Prayer?, String>((ref, prayerId) async {
  final repository = ref.watch(prayerRepositoryProvider);
  return await repository.getPrayer(prayerId);
});

// Provider for user preferences
final prayerPreferencesProvider = StateNotifierProvider<PrayerPreferencesNotifier, PrayerPreferences>((ref) {
  final repository = ref.watch(prayerRepositoryProvider);
  return PrayerPreferencesNotifier(repository);
});

// Notifier for prayer preferences
class PrayerPreferencesNotifier extends StateNotifier<PrayerPreferences> {
  final PrayerRepository repository;

  PrayerPreferencesNotifier(this.repository) : super(PrayerPreferences()) {
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    state = await repository.getUserPreferences();
  }

  Future<void> toggleFavorite(String prayerId) async {
    state = await repository.toggleFavorite(prayerId);
  }

  Future<void> addToRecent(String prayerId) async {
    state = await repository.addToRecent(prayerId);
  }

  Future<void> updateFontSize(double fontSize) async {
    final updatedPreferences = state.copyWith(fontSize: fontSize);
    state = updatedPreferences; // Update state immediately
    repository.saveUserPreferences(updatedPreferences); // Save asynchronously without waiting
  }

  Future<void> updateDefaultLanguage(String language) async {
    final updatedPreferences = state.copyWith(defaultLanguage: language);
    state = updatedPreferences; // Update state immediately
    repository.saveUserPreferences(updatedPreferences); // Save asynchronously without waiting
  }

  Future<void> updateReadingMode(PrayerReadingMode readingMode) async {
    final updatedPreferences = state.copyWith(readingMode: readingMode);
    state = updatedPreferences;
    repository.saveUserPreferences(updatedPreferences);
  }

  Future<void> updateVerseHighlighting(bool enabled) async {
    final updatedPreferences = state.copyWith(verseHighlighting: enabled);
    state = updatedPreferences;
    repository.saveUserPreferences(updatedPreferences);
  }

}

// Provider for favorite prayers
final favoritePrayersProvider = FutureProvider<List<PrayerMetadata>>((ref) async {
  final allPrayers = await ref.watch(prayerMetadataProvider.future);
  final preferences = ref.watch(prayerPreferencesProvider);

  return allPrayers
      .where((prayer) => preferences.favoritePrayerIds.contains(prayer.id))
      .toList();
});

// Provider for recent prayers
final recentPrayersProvider = FutureProvider<List<PrayerMetadata>>((ref) async {
  final allPrayers = await ref.watch(prayerMetadataProvider.future);
  final preferences = ref.watch(prayerPreferencesProvider);

  // Sort in the order of recentPrayerIds
  return preferences.recentPrayerIds
      .map((id) => allPrayers.where((prayer) => prayer.id == id))
      .where((prayers) => prayers.isNotEmpty)
      .map((prayers) => prayers.first)
      .toList();
});

// Provider for search query
final searchQueryProvider = StateProvider<String>((ref) => '');

// Provider for search results
final searchResultsProvider = FutureProvider<List<PrayerMetadata>>((ref) async {
  final repository = ref.watch(prayerRepositoryProvider);
  final query = ref.watch(searchQueryProvider);

  if (query.isEmpty) return [];
  return await repository.searchPrayers(query);
});

// Provider for selected translation
final selectedTranslationProvider = StateProvider.family<String?, String>((ref, prayerId) => null);

// Selected tags provider for filtering
final selectedTagsProvider = StateNotifierProvider<SelectedTagsNotifier, List<String>>((ref) {
  return SelectedTagsNotifier();
});

// Font size provider (derived from preferences)
final fontSizeProvider = Provider<double>((ref) {
  final preferences = ref.watch(prayerPreferencesProvider);
  return preferences.fontSize;
});

// Default language provider (derived from preferences)
final defaultLanguageProvider = Provider<String>((ref) {
  final preferences = ref.watch(prayerPreferencesProvider);
  return preferences.defaultLanguage;
});

class SelectedTagsNotifier extends StateNotifier<List<String>> {
  SelectedTagsNotifier() : super([]);

  void toggleTag(String tag) {
    if (state.contains(tag)) {
      state = state.where((t) => t != tag).toList();
    } else {
      state = [...state, tag];
    }
  }

  void clearTags() {
    state = [];
  }
}

// Available tags provider
final availableTagsProvider = Provider<List<String>>((ref) {
  final allPrayers = ref.watch(prayerMetadataProvider).valueOrNull ?? [];
  final Set<String> tags = {};

  for (final prayer in allPrayers) {
    tags.addAll(prayer.tags);
  }

  return tags.toList()..sort();
});

// Provider for favorites filter
final showFavoritesOnlyProvider = StateProvider<bool>((ref) => false);

// Filtered prayers provider
final filteredPrayersProvider = FutureProvider<List<PrayerMetadata>>((ref) async {
  final allPrayersAsync = ref.watch(prayerMetadataProvider);
  final allPrayers = allPrayersAsync.value ?? [];

  final selectedTags = ref.watch(selectedTagsProvider);
  final showFavoritesOnly = ref.watch(showFavoritesOnlyProvider);
  final preferences = ref.watch(prayerPreferencesProvider);

  // Start with all prayers
  var filteredPrayers = allPrayers;

  // Filter by favorites if enabled
  if (showFavoritesOnly) {
    filteredPrayers = filteredPrayers.where((prayer) =>
        preferences.favoritePrayerIds.contains(prayer.id)
    ).toList();
  }

  // Filter by selected tags
  if (selectedTags.isNotEmpty) {
    filteredPrayers = filteredPrayers.where((prayer) {
      return prayer.tags.any((tag) => selectedTags.contains(tag));
    }).toList();
  }

  return filteredPrayers;
});

// Filtered category prayers provider
final filteredCategoryPrayersProvider = FutureProvider.family<List<PrayerMetadata>, String>((ref, categoryFilter) async {
  final allPrayersAsync = ref.watch(prayerMetadataProvider);
  final allPrayers = allPrayersAsync.value ?? [];

  final selectedTags = ref.watch(selectedTagsProvider);
  final showFavoritesOnly = ref.watch(showFavoritesOnlyProvider);
  final preferences = ref.watch(prayerPreferencesProvider);

  // Parse comma-separated categories
  final categories = categoryFilter.split(',');

  // Filter by category
  var filteredPrayers = allPrayers.where((prayer) {
    return prayer.categories.any((cat) => categories.contains(cat));
  }).toList();

  // Apply other filters
  if (showFavoritesOnly) {
    filteredPrayers = filteredPrayers.where((prayer) =>
        preferences.favoritePrayerIds.contains(prayer.id)
    ).toList();
  }

  if (selectedTags.isNotEmpty) {
    filteredPrayers = filteredPrayers.where((prayer) {
      return prayer.tags.any((tag) => selectedTags.contains(tag));
    }).toList();
  }

  return filteredPrayers;
});

// Prayer of the day provider using liturgical calendar
final prayerOfTheDayProvider = FutureProvider<PrayerMetadata?>((ref) async {
  final repository = ref.watch(prayerRepositoryProvider);
  final today = DateTime.now();

  // Get today's liturgical information
  final liturgicalDay = ref.watch(currentLiturgicalDayProvider);
  if (liturgicalDay == null) return null;

  // Get all prayers for selection
  final allPrayers = await repository.getPrayerMetadata();

  // Use the service to select the appropriate prayer
  return PrayerOfTheDayService.selectPrayerOfTheDay(
      today,
      liturgicalDay,
      allPrayers
  );
});

// Provider for liturgical context (useful for UI)
final prayerOfTheDayContextProvider = Provider<Map<String, String>>((ref) {
  final liturgicalDay = ref.watch(currentLiturgicalDayProvider);
  if (liturgicalDay == null) return {};

  return {
    'season': liturgicalDay.season,
    'celebration': liturgicalDay.celebration.name,
    'reason': _getPrayerSelectionReason(liturgicalDay),
  };
});

String _getPrayerSelectionReason(liturgicalDay) {
  if (liturgicalDay.isSolemnity && liturgicalDay.celebration.name.isNotEmpty) {
    return 'Selected for ${liturgicalDay.celebration.name}';
  } else if (liturgicalDay.season.toLowerCase() != 'ordinary time') {
    return 'Selected for ${liturgicalDay.season}';
  } else {
    return 'Today\'s prayer for ${liturgicalDay.season}';
  }
}