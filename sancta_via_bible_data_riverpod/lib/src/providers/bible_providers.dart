import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bible_data/bible_data.dart';

/// Provider for the Bible service instance
/// This is the main service provider that all other providers depend on
final bibleServiceProvider = Provider<BibleService>((ref) {
  // Create an asset loader for loading Bible data from app assets
  final loader = AssetBibleLoader(
    assetBasePath: 'assets/bibles',
    assetLoader: rootBundle.loadString,
  );
  return BibleService(loader);
});

/// Provider for the optimized Bible service (fast startup, chapter-level caching)
final optimizedBibleServiceProvider = Provider<OptimizedBibleService>((ref) {
  final loader = OptimizedSqliteBibleLoader(
    databaseAssetPath: 'assets/bibles.db',
  );
  return OptimizedBibleService(loader);
});

/// Debug-enhanced AssetBibleLoader that logs all operations
class DebugAssetBibleLoader implements BibleLoader {
  final AssetBibleLoader _loader;

  DebugAssetBibleLoader(this._loader);

  @override
  Future<Bible> loadBible(BibleTranslation translation) async {
    AppLogger.loader(
      'Starting to load Bible: ${translation.name} (${translation.id})',
      'BIBLE_LOADER',
    );

    try {
      final bible = await _loader.loadBible(translation);
      AppLogger.loader(
        'Successfully loaded Bible: ${translation.name}, ${bible.books.length} books',
        'BIBLE_LOADER',
      );
      return bible;
    } catch (e) {
      AppLogger.loader('Failed to load Bible ${translation.name}: $e', 'BIBLE_LOADER');
      rethrow;
    }
  }

  @override
  Future<bool> isTranslationAvailable(BibleTranslation translation) async {
    AppLogger.loader(
      'Checking if translation is available: ${translation.name} (${translation.id})',
      'BIBLE_LOADER',
    );

    try {
      final available = await _loader.isTranslationAvailable(translation);
      AppLogger.loader(
        'Translation ${translation.name} available: $available',
        'BIBLE_LOADER',
      );
      return available;
    } catch (e) {
      AppLogger.loader(
        'Error checking translation availability for ${translation.name}: $e',
        'BIBLE_LOADER',
      );
      return false;
    }
  }

  @override
  Future<List<BibleTranslation>> getAvailableTranslations() async {
    AppLogger.loader('Getting available translations...', 'BIBLE_LOADER');

    try {
      final translations = await _loader.getAvailableTranslations();
      AppLogger.loader(
        'Available translations: ${translations.map((t) => t.id).join(', ')}',
        'BIBLE_LOADER',
      );
      return translations;
    } catch (e) {
      AppLogger.loader('Error getting available translations: $e', 'BIBLE_LOADER');
      return [];
    }
  }
}

/// Provider for configuring the Bible loader
/// Apps can override this to provide their own loader configuration
final bibleLoaderProvider = Provider<BibleLoader>((ref) {
  if (kIsWeb) {
    // Web doesn't support SQLite, fall back to JSON loading
    AppLogger.loader(
      'Creating AssetBibleLoader for web platform (JSON fallback)',
      'BIBLE_LOADER',
    );

    final baseLoader = AssetBibleLoader(
      assetBasePath: 'assets/bibles',
      assetLoader: (path) async {
        AppLogger.loader('Loading asset: $path', 'BIBLE_LOADER');
        try {
          final content = await rootBundle.loadString(path);
          AppLogger.loader(
            'Asset loaded successfully: $path, length: ${content.length}',
            'BIBLE_LOADER',
          );
          return content;
        } catch (e) {
          AppLogger.loader('Failed to load asset $path: $e', 'BIBLE_LOADER');
          rethrow;
        }
      },
    );

    return DebugAssetBibleLoader(baseLoader);
  } else {
    // Mobile/Desktop: Use high-performance SQLite
    AppLogger.loader(
      'Creating SqliteBibleLoader for mobile/desktop platform',
      'BIBLE_LOADER',
    );

    return SqliteBibleLoader(databaseAssetPath: 'assets/bibles.db');
  }
});

/// StateNotifier for managing Bible service initialization and state
class BibleServiceNotifier extends StateNotifier<AsyncValue<BibleService>> {
  BibleServiceNotifier(this._loader) : super(const AsyncValue.loading()) {
    AppLogger.loader(
      'BibleServiceNotifier created, starting initialization...',
      'BIBLE_SERVICE',
    );
    _initialize();
  }

  final BibleLoader _loader;
  BibleService? _service;

  Future<void> _initialize() async {
    AppLogger.loader('Initializing BibleService...', 'BIBLE_SERVICE');

    try {
      _service = BibleService(_loader);
      AppLogger.loader('BibleService created successfully', 'BIBLE_SERVICE');

      // Test loading available translations to verify assets work
      final availableTranslations = await _service!.getAvailableTranslations();
      AppLogger.loader(
        'Available translations on startup: ${availableTranslations.map((t) => t.id).join(', ')}',
        'BIBLE_SERVICE',
      );

      state = AsyncValue.data(_service!);
      AppLogger.loader('BibleService initialization complete', 'BIBLE_SERVICE');
    } catch (error, stackTrace) {
      AppLogger.loader('BibleService initialization failed: $error', 'BIBLE_SERVICE');
      AppLogger.loader('Stack trace: $stackTrace', 'BIBLE_SERVICE');
      state = AsyncValue.error(error, stackTrace);
    }
  }

  /// Get the current Bible service instance
  BibleService? get service => _service;

  /// Preload common Bible translations for better performance
  Future<void> preloadTranslations(List<BibleTranslation> translations) async {
    if (_service == null) return;

    try {
      await _service!.preloadTranslations(translations);
    } catch (error) {
      // Log error but don't change state - preloading is optional
    }
  }

  /// Clear all caches
  void clearCache() {
    _service?.clearCache();
  }

  /// Get cache statistics
  Map<String, dynamic> getCacheStats() {
    return _service?.getCacheStats() ?? {};
  }
}

/// Fast StateNotifier for optimized Bible service (no expensive startup operations)
class OptimizedBibleServiceNotifier
    extends StateNotifier<AsyncValue<OptimizedBibleService>> {
  OptimizedBibleServiceNotifier(this._loader)
    : super(const AsyncValue.loading()) {
    AppLogger.loader(
      'OptimizedBibleServiceNotifier created, starting fast initialization...',
      'OPTIMIZED_SERVICE',
    );
    _initialize();
  }

  final OptimizedSqliteBibleLoader _loader;
  OptimizedBibleService? _service;

  Future<void> _initialize() async {
    AppLogger.loader(
      'Initializing OptimizedBibleService (fast)...',
      'OPTIMIZED_SERVICE',
    );

    try {
      _service = OptimizedBibleService(_loader);
      AppLogger.loader(
        'OptimizedBibleService created successfully',
        'OPTIMIZED_SERVICE',
      );

      // NO expensive operations here - just mark as ready
      // Available translations will be queried only when needed

      state = AsyncValue.data(_service!);
      AppLogger.loader(
        'OptimizedBibleService initialization complete (fast)',
        'OPTIMIZED_SERVICE',
      );
    } catch (error, stackTrace) {
      AppLogger.loader(
        'OptimizedBibleService initialization failed: $error',
        'OPTIMIZED_SERVICE',
      );
      AppLogger.loader('Stack trace: $stackTrace', 'OPTIMIZED_SERVICE');
      state = AsyncValue.error(error, stackTrace);
    }
  }

  /// Get the current optimized Bible service instance
  OptimizedBibleService? get service => _service;

  /// Clear all caches
  void clearCache() {
    _service?.clearCache();
  }

  /// Get cache statistics
  Map<String, dynamic> getCacheStats() {
    return _service?.getCacheStats() ?? {};
  }
}

/// Provider for the Bible service with initialization state
final bibleServiceNotifierProvider =
    StateNotifierProvider<BibleServiceNotifier, AsyncValue<BibleService>>((
      ref,
    ) {
      final loader = ref.watch(bibleLoaderProvider);
      return BibleServiceNotifier(loader);
    });

/// Provider for the optimized Bible service with fast initialization
final optimizedBibleServiceNotifierProvider =
    StateNotifierProvider<
      OptimizedBibleServiceNotifier,
      AsyncValue<OptimizedBibleService>
    >((ref) {
      final loader = OptimizedSqliteBibleLoader(
        databaseAssetPath: 'assets/bibles.db',
      );
      return OptimizedBibleServiceNotifier(loader);
    });

/// Main provider that uses the optimized service for better performance
final mainBibleServiceProvider = Provider<AsyncValue<OptimizedBibleService>>((
  ref,
) {
  return ref.watch(optimizedBibleServiceNotifierProvider);
});

/// Provider for checking if Bible translations are available
final availableTranslationsProvider = FutureProvider<List<BibleTranslation>>((
  ref,
) async {
  final serviceAsync = ref.watch(bibleServiceNotifierProvider);
  return serviceAsync.when(
    data: (service) async {
      // Return all supported translations
      return BibleTranslation.values;
    },
    loading: () => <BibleTranslation>[],
    error: (error, stack) => <BibleTranslation>[],
  );
});

/// Provider for Bible book mapping information
final bibleBookMappingProvider = Provider<BibleBookMapping>((ref) {
  return BibleBookMapping();
});

/// Provider for all Bible books metadata
final allBibleBooksProvider = Provider<List<BookMetadata>>((ref) {
  return BibleBookMapping.allBooks;
});

/// Provider for Old Testament books metadata
final oldTestamentBooksProvider = Provider<List<BookMetadata>>((ref) {
  return BibleBookMapping.oldTestamentBooks;
});

/// Provider for New Testament books metadata
final newTestamentBooksProvider = Provider<List<BookMetadata>>((ref) {
  return BibleBookMapping.newTestamentBooks;
});

/// Provider for finding a book metadata by name, ID, or abbreviation
final findBookProvider = Provider.family<BookMetadata?, String>((
  ref,
  identifier,
) {
  return BibleBookMapping.findBook(identifier);
});

/// Provider for Bible statistics
final bibleStatsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final serviceAsync = ref.watch(bibleServiceNotifierProvider);
  return serviceAsync.when(
    data: (service) async {
      final stats = service.getCacheStats();
      stats['total_books'] = BibleBookMapping.allBooks.length;
      stats['old_testament_books'] = BibleBookMapping.oldTestamentBooks.length;
      stats['new_testament_books'] = BibleBookMapping.newTestamentBooks.length;
      return stats;
    },
    loading: () => <String, dynamic>{},
    error: (error, stack) => <String, dynamic>{'error': error.toString()},
  );
});
