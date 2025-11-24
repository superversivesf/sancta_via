import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bible_data/bible_data.dart';
import 'bible_providers.dart';
import 'settings_providers.dart';

/// Provider for getting scripture content by reference string
final scriptureProvider = FutureProvider.family<ScriptureContent, String>((ref, reference) async {
  final serviceAsync = ref.watch(bibleServiceNotifierProvider);
  final translation = ref.watch(selectedBibleTranslationProvider);
  
  return serviceAsync.when(
    data: (service) async {
      return await service.getScriptureByReference(reference, translation);
    },
    loading: () => throw Exception('Bible service is loading'),
    error: (error, stack) => throw error,
  );
});

/// Provider for getting scripture content by parsed reference
final scriptureByReferenceProvider = FutureProvider.family<ScriptureContent, ({ScriptureReference reference, BibleTranslation translation})>((ref, params) async {
  final serviceAsync = ref.watch(bibleServiceNotifierProvider);
  
  return serviceAsync.when(
    data: (service) async {
      return await service.getScriptureContent(params.reference, params.translation);
    },
    loading: () => throw Exception('Bible service is loading'),
    error: (error, stack) => throw error,
  );
});

/// Provider for getting multiple scripture references at once
final multipleScripturesProvider = FutureProvider.family<List<ScriptureContent>, ({List<String> references, BibleTranslation translation})>((ref, params) async {
  final serviceAsync = ref.watch(bibleServiceNotifierProvider);
  
  return serviceAsync.when(
    data: (service) async {
      // Parse string references to ScriptureReference objects
      final parsedReferences = params.references
          .map((refString) {
            try {
              return ScriptureReference.parse(refString);
            } catch (e) {
              // Return a dummy reference if parsing fails
              return ScriptureReference(
                book: 'Unknown',
                chapter: 0,
                displayText: refString,
              );
            }
          })
          .toList();
      
      return await service.getMultipleScriptures(parsedReferences, params.translation);
    },
    loading: () => throw Exception('Bible service is loading'),
    error: (error, stack) => throw error,
  );
});

/// Provider for parsing scripture references
final parsedReferenceProvider = Provider.family<ScriptureReference?, String>((ref, referenceString) {
  try {
    return ScriptureReference.parse(referenceString);
  } catch (e) {
    return null;
  }
});

/// Provider for validating scripture references
final referenceValidationProvider = Provider.family<bool, String>((ref, referenceString) {
  final parsed = ref.watch(parsedReferenceProvider(referenceString));
  return parsed != null;
});

/// StateNotifier for managing current scripture reading state
class CurrentScriptureNotifier extends StateNotifier<AsyncValue<ScriptureContent?>> {
  CurrentScriptureNotifier(this._ref) : super(const AsyncValue.data(null));

  final Ref _ref;
  String? _currentReference;
  BibleTranslation? _currentTranslation;

  /// Load scripture by reference string
  Future<void> loadScripture(String reference, {BibleTranslation? translation}) async {
    if (reference.isEmpty) {
      state = const AsyncValue.data(null);
      return;
    }

    final BibleTranslation useTranslation = translation ?? _ref.read(selectedBibleTranslationProvider);
    
    // Avoid reloading the same scripture
    if (_currentReference == reference && _currentTranslation == useTranslation) {
      return;
    }

    state = const AsyncValue.loading();
    _currentReference = reference;
    _currentTranslation = useTranslation;

    try {
      final serviceAsync = _ref.read(bibleServiceNotifierProvider);
      await serviceAsync.when(
        data: (service) async {
          final content = await service.getScriptureByReference(reference, useTranslation);
          // Only update state if this is still the current request
          if (_currentReference == reference && _currentTranslation == useTranslation) {
            state = AsyncValue.data(content);
          }
        },
        loading: () => throw Exception('Bible service is loading'),
        error: (error, stack) => throw error,
      );
    } catch (error, stackTrace) {
      if (_currentReference == reference && _currentTranslation == useTranslation) {
        state = AsyncValue.error(error, stackTrace);
      }
    }
  }

  /// Clear current scripture
  void clear() {
    state = const AsyncValue.data(null);
    _currentReference = null;
    _currentTranslation = null;
  }

  /// Get current reference
  String? get currentReference => _currentReference;

  /// Get current translation
  BibleTranslation? get currentTranslation => _currentTranslation;
}

/// Provider for managing current scripture reading
final currentScriptureProvider = StateNotifierProvider<CurrentScriptureNotifier, AsyncValue<ScriptureContent?>>((ref) {
  return CurrentScriptureNotifier(ref);
});

/// Provider for today's suggested scripture reading
/// This could be integrated with lectionary data in the future
final todaysScriptureProvider = FutureProvider<ScriptureContent?>((ref) async {
  // For now, return a default daily reading
  // This should be integrated with lectionary_data in a real app
  final serviceAsync = ref.watch(bibleServiceNotifierProvider);
  final translation = ref.watch(selectedBibleTranslationProvider);
  
  return serviceAsync.when(
    data: (service) async {
      // Default to a psalm for daily reading
      final psalms = ['Psalm 23', 'Psalm 91', 'Psalm 139', 'Psalm 121', 'Psalm 46'];
      final dayOfYear = DateTime.now().difference(DateTime(DateTime.now().year, 1, 1)).inDays;
      final selectedPsalm = psalms[dayOfYear % psalms.length];
      
      return await service.getScriptureByReference(selectedPsalm, translation);
    },
    loading: () => null,
    error: (error, stack) => null,
  );
});

/// Provider for favorite scripture verses
final favoriteScripturesProvider = StateNotifierProvider<FavoriteScripturesNotifier, List<String>>((ref) {
  return FavoriteScripturesNotifier();
});

/// StateNotifier for managing favorite scriptures
class FavoriteScripturesNotifier extends StateNotifier<List<String>> {
  FavoriteScripturesNotifier() : super([]);

  /// Add a scripture reference to favorites
  void addFavorite(String reference) {
    if (!state.contains(reference)) {
      state = [...state, reference];
    }
  }

  /// Remove a scripture reference from favorites
  void removeFavorite(String reference) {
    state = state.where((ref) => ref != reference).toList();
  }

  /// Toggle favorite status of a scripture reference
  void toggleFavorite(String reference) {
    if (state.contains(reference)) {
      removeFavorite(reference);
    } else {
      addFavorite(reference);
    }
  }

  /// Check if a reference is favorited
  bool isFavorite(String reference) {
    return state.contains(reference);
  }

  /// Clear all favorites
  void clearFavorites() {
    state = [];
  }

  /// Load favorites from storage (to be implemented by apps)
  void loadFavorites(List<String> favorites) {
    state = favorites;
  }
}

/// Provider for getting all favorite scripture contents
final favoriteScriptureContentsProvider = FutureProvider<List<ScriptureContent>>((ref) async {
  final favorites = ref.watch(favoriteScripturesProvider);
  final translation = ref.watch(selectedBibleTranslationProvider);
  
  if (favorites.isEmpty) return [];
  
  final serviceAsync = ref.watch(bibleServiceNotifierProvider);
  return serviceAsync.when(
    data: (service) async {
      // Parse string references to ScriptureReference objects
      final parsedReferences = favorites
          .map((refString) {
            try {
              return ScriptureReference.parse(refString);
            } catch (e) {
              // Return null for invalid references, filter them out
              return null;
            }
          })
          .where((ref) => ref != null)
          .cast<ScriptureReference>()
          .toList();
      
      return await service.getMultipleScriptures(parsedReferences, translation);
    },
    loading: () => <ScriptureContent>[],
    error: (error, stack) => <ScriptureContent>[],
  );
});

/// Provider for checking if a reference is in favorites
final isReferenceInFavoritesProvider = Provider.family<bool, String>((ref, reference) {
  final notifier = ref.watch(favoriteScripturesProvider.notifier);
  return notifier.isFavorite(reference);
});

// ============================================================================
// OPTIMIZED PROVIDERS - Much faster app startup and chapter loading
// ============================================================================

/// Provider for optimized scripture content by reference (much faster!)
final optimizedScriptureByReferenceProvider = FutureProvider.family<OptimizedScriptureContent, ({ScriptureReference reference, BibleTranslation translation})>((ref, params) async {
  final serviceAsync = ref.watch(optimizedBibleServiceNotifierProvider);
  
  return serviceAsync.when(
    data: (service) async {
      return await service.getScriptureContent(params.reference, params.translation);
    },
    loading: () => throw Exception('Optimized Bible service is loading'),
    error: (error, stack) => throw error,
  );
});

/// Fast provider that gets book names without loading full Bible content
final optimizedBookNamesProvider = FutureProvider.family<List<String>, BibleTranslation>((ref, translation) async {
  final serviceAsync = ref.watch(optimizedBibleServiceNotifierProvider);
  
  return serviceAsync.when(
    data: (service) async {
      return await service.getBookNames(translation);
    },
    loading: () => throw Exception('Optimized Bible service is loading'),
    error: (error, stack) => throw error,
  );
});

/// Fast provider that gets chapter count for a book
final optimizedChapterCountProvider = FutureProvider.family<int, ({String bookName, BibleTranslation translation})>((ref, params) async {
  final serviceAsync = ref.watch(optimizedBibleServiceNotifierProvider);
  
  return serviceAsync.when(
    data: (service) async {
      return await service.getChapterCount(params.bookName, params.translation);
    },
    loading: () => throw Exception('Optimized Bible service is loading'),
    error: (error, stack) => throw error,
  );
});

/// Fast provider for checking if a book exists
final optimizedBookExistsProvider = FutureProvider.family<bool, ({String bookName, BibleTranslation translation})>((ref, params) async {
  final serviceAsync = ref.watch(optimizedBibleServiceNotifierProvider);
  
  return serviceAsync.when(
    data: (service) async {
      return await service.hasBook(params.bookName, params.translation);
    },
    loading: () => false,
    error: (error, stack) => false,
  );
});

/// Fast provider for available translations (no content loading)
final optimizedAvailableTranslationsProvider = FutureProvider<List<BibleTranslation>>((ref) async {
  final serviceAsync = ref.watch(optimizedBibleServiceNotifierProvider);
  
  return serviceAsync.when(
    data: (service) async {
      return await service.getAvailableTranslations();
    },
    loading: () => <BibleTranslation>[],
    error: (error, stack) => <BibleTranslation>[],
  );
});
