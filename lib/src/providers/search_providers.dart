import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bible_data/bible_data.dart';
import 'bible_providers.dart';
import 'settings_providers.dart';

/// Provider for searching scripture text
final scriptureSearchProvider = FutureProvider.family<List<SearchResult>, String>((ref, query) async {
  if (query.trim().isEmpty) return [];
  
  final serviceAsync = ref.watch(bibleServiceNotifierProvider);
  final translation = ref.watch(selectedBibleTranslationProvider);
  final searchSettings = ref.watch(searchSettingsProvider);
  
  return serviceAsync.when(
    data: (service) async {
      return await service.searchText(
        query,
        translation,
        caseSensitive: searchSettings.caseSensitive,
        wholeWords: searchSettings.wholeWords,
        oldTestamentOnly: searchSettings.oldTestamentOnly,
        newTestamentOnly: searchSettings.newTestamentOnly,
        maxResults: searchSettings.maxResults,
      );
    },
    loading: () => <SearchResult>[],
    error: (error, stack) => throw error,
  );
});

/// Provider for advanced scripture search with custom parameters
final advancedScriptureSearchProvider = FutureProvider.family<List<SearchResult>, SearchParameters>((ref, params) async {
  if (params.query.trim().isEmpty) return [];
  
  final serviceAsync = ref.watch(bibleServiceNotifierProvider);
  
  return serviceAsync.when(
    data: (service) async {
      return await service.searchText(
        params.query,
        params.translation,
        caseSensitive: params.caseSensitive,
        wholeWords: params.wholeWords,
        oldTestamentOnly: params.oldTestamentOnly,
        newTestamentOnly: params.newTestamentOnly,
        maxResults: params.maxResults,
      );
    },
    loading: () => <SearchResult>[],
    error: (error, stack) => throw error,
  );
});

/// Search parameters model for advanced search
class SearchParameters {
  final String query;
  final BibleTranslation translation;
  final bool caseSensitive;
  final bool wholeWords;
  final bool oldTestamentOnly;
  final bool newTestamentOnly;
  final int maxResults;

  const SearchParameters({
    required this.query,
    required this.translation,
    this.caseSensitive = false,
    this.wholeWords = false,
    this.oldTestamentOnly = false,
    this.newTestamentOnly = false,
    this.maxResults = 50,
  });

  SearchParameters copyWith({
    String? query,
    BibleTranslation? translation,
    bool? caseSensitive,
    bool? wholeWords,
    bool? oldTestamentOnly,
    bool? newTestamentOnly,
    int? maxResults,
  }) {
    return SearchParameters(
      query: query ?? this.query,
      translation: translation ?? this.translation,
      caseSensitive: caseSensitive ?? this.caseSensitive,
      wholeWords: wholeWords ?? this.wholeWords,
      oldTestamentOnly: oldTestamentOnly ?? this.oldTestamentOnly,
      newTestamentOnly: newTestamentOnly ?? this.newTestamentOnly,
      maxResults: maxResults ?? this.maxResults,
    );
  }
}

/// StateNotifier for managing search state
class SearchStateNotifier extends StateNotifier<SearchState> {
  SearchStateNotifier(this._ref) : super(const SearchState.initial());

  final Ref _ref;

  /// Perform a search with the current query
  Future<void> search(String query) async {
    if (query.trim().isEmpty) {
      state = const SearchState.initial();
      return;
    }

    state = SearchState.loading(query);

    try {
      final serviceAsync = _ref.read(bibleServiceNotifierProvider);
      final translation = _ref.read(selectedBibleTranslationProvider);
      final searchSettings = _ref.read(searchSettingsProvider);

      await serviceAsync.when(
        data: (service) async {
          final results = await service.searchText(
            query,
            translation,
            caseSensitive: searchSettings.caseSensitive,
            wholeWords: searchSettings.wholeWords,
            oldTestamentOnly: searchSettings.oldTestamentOnly,
            newTestamentOnly: searchSettings.newTestamentOnly,
            maxResults: searchSettings.maxResults,
          );
          
          state = SearchState.success(query, results);
        },
        loading: () => throw Exception('Bible service is loading'),
        error: (error, stack) => throw error,
      );
    } catch (error, stackTrace) {
      state = SearchState.error(query, error, stackTrace);
    }
  }

  /// Clear search results
  void clear() {
    state = const SearchState.initial();
  }

  /// Get current query
  String? get currentQuery => state.query;

  /// Get current results
  List<SearchResult> get currentResults => state.results;
}

/// Search state sealed class
sealed class SearchState {
  final String? query;
  final List<SearchResult> results;

  const SearchState(this.query, this.results);

  const factory SearchState.initial() = SearchStateInitial;
  const factory SearchState.loading(String query) = SearchStateLoading;
  const factory SearchState.success(String query, List<SearchResult> results) = SearchStateSuccess;
  const factory SearchState.error(String query, Object error, StackTrace stackTrace) = SearchStateError;
}

class SearchStateInitial extends SearchState {
  const SearchStateInitial() : super(null, const []);
}

class SearchStateLoading extends SearchState {
  const SearchStateLoading(String query) : super(query, const []);
}

class SearchStateSuccess extends SearchState {
  const SearchStateSuccess(String query, List<SearchResult> results) : super(query, results);
}

class SearchStateError extends SearchState {
  final Object error;
  final StackTrace stackTrace;

  const SearchStateError(String query, this.error, this.stackTrace) : super(query, const []);
}

/// Provider for search state management
final searchStateProvider = StateNotifierProvider<SearchStateNotifier, SearchState>((ref) {
  return SearchStateNotifier(ref);
});

/// Provider for search suggestions based on popular searches
final searchSuggestionsProvider = Provider<List<String>>((ref) {
  return [
    'love',
    'peace',
    'hope',
    'faith',
    'forgiveness',
    'salvation',
    'eternal life',
    'Jesus',
    'God',
    'Holy Spirit',
    'prayer',
    'blessing',
    'mercy',
    'grace',
    'kingdom of heaven',
    'righteousness',
    'wisdom',
    'strength',
    'comfort',
    'joy',
  ];
});

/// Provider for search history
final searchHistoryProvider = StateNotifierProvider<SearchHistoryNotifier, List<String>>((ref) {
  return SearchHistoryNotifier();
});

/// StateNotifier for managing search history
class SearchHistoryNotifier extends StateNotifier<List<String>> {
  SearchHistoryNotifier() : super([]);

  /// Add a search query to history
  void addSearch(String query) {
    if (query.trim().isEmpty) return;
    
    final trimmedQuery = query.trim();
    
    // Remove if already exists
    final newState = state.where((q) => q != trimmedQuery).toList();
    
    // Add to front
    newState.insert(0, trimmedQuery);
    
    // Limit to 20 items
    if (newState.length > 20) {
      newState.removeRange(20, newState.length);
    }
    
    state = newState;
  }

  /// Remove a search query from history
  void removeSearch(String query) {
    state = state.where((q) => q != query).toList();
  }

  /// Clear all search history
  void clearHistory() {
    state = [];
  }

  /// Load history from storage (to be implemented by apps)
  void loadHistory(List<String> history) {
    state = history;
  }
}

/// Provider for getting recent searches (last 5)
final recentSearchesProvider = Provider<List<String>>((ref) {
  final history = ref.watch(searchHistoryProvider);
  return history.take(5).toList();
});

/// Provider for searching by verse number
final verseNumberSearchProvider = FutureProvider.family<List<SearchResult>, int>((ref, verseNumber) async {
  final serviceAsync = ref.watch(bibleServiceNotifierProvider);
  final translation = ref.watch(selectedBibleTranslationProvider);
  
  return serviceAsync.when(
    data: (service) async {
      final searchService = await service.getSearchService(translation);
      return await searchService.searchByVerseNumber(verseNumber);
    },
    loading: () => <SearchResult>[],
    error: (error, stack) => throw error,
  );
});

/// Provider for getting search service directly
final searchServiceProvider = FutureProvider.family<BibleSearchService, BibleTranslation>((ref, translation) async {
  final serviceAsync = ref.watch(bibleServiceNotifierProvider);
  
  return serviceAsync.when(
    data: (service) async {
      return await service.getSearchService(translation);
    },
    loading: () => throw Exception('Bible service is loading'),
    error: (error, stack) => throw error,
  );
});
