import 'dart:convert';
import '../models/bible.dart';
import '../models/bible_translation.dart';

/// Abstract interface for loading Bible data
abstract class BibleLoader {
  /// Load a specific Bible translation
  Future<Bible> loadBible(BibleTranslation translation);

  /// Check if a translation is available
  Future<bool> isTranslationAvailable(BibleTranslation translation);

  /// Get list of available translations
  Future<List<BibleTranslation>> getAvailableTranslations();
}

/// Implementation for loading Bible data from embedded JSON
class EmbeddedBibleLoader implements BibleLoader {
  static final Map<BibleTranslation, Bible> _cache = {};
  static final Map<BibleTranslation, String> _bibleData = {};

  /// Initialize with embedded Bible data
  /// This should be called once with the JSON strings for each translation
  static void initialize(Map<BibleTranslation, String> bibleJsonData) {
    _bibleData.clear();
    _bibleData.addAll(bibleJsonData);
  }

  @override
  Future<Bible> loadBible(BibleTranslation translation) async {
    // Check cache first
    if (_cache.containsKey(translation)) {
      return _cache[translation]!;
    }

    // Check if data is available
    final jsonString = _bibleData[translation];
    if (jsonString == null) {
      throw Exception('Bible data not available for ${translation.name}');
    }

    try {
      final Map<String, dynamic> jsonData = json.decode(jsonString);
      final bible = Bible.fromJson(jsonData);

      // Cache the loaded bible
      _cache[translation] = bible;

      return bible;
    } catch (e) {
      throw Exception('Failed to load ${translation.name}: $e');
    }
  }

  @override
  Future<bool> isTranslationAvailable(BibleTranslation translation) async {
    return _bibleData.containsKey(translation);
  }

  @override
  Future<List<BibleTranslation>> getAvailableTranslations() async {
    return _bibleData.keys.toList();
  }

  /// Clear the cache (useful for memory management)
  static void clearCache() {
    _cache.clear();
  }

  /// Get cache size for debugging
  static int getCacheSize() {
    return _cache.length;
  }
}

/// Debug logging utility for AssetBibleLoader
void _debugLog(String message, [String? tag]) {
  final timestamp = DateTime.now().toIso8601String();
  print('[$timestamp] ${tag != null ? '[$tag] ' : ''}$message');
}

/// Implementation for loading Bible data from asset files (for Flutter apps)
class AssetBibleLoader implements BibleLoader {
  static final Map<BibleTranslation, Bible> _cache = {};
  final String assetBasePath;
  final Future<String> Function(String path) assetLoader;

  /// Create an asset loader
  /// [assetBasePath] - Base path for assets (e.g., 'assets/bibles')
  /// [assetLoader] - Function to load asset content (e.g., rootBundle.loadString)
  AssetBibleLoader({
    required this.assetBasePath,
    required this.assetLoader,
  }) {
    _debugLog('AssetBibleLoader created with basePath: $assetBasePath',
        'ASSET_LOADER');
  }

  @override
  Future<Bible> loadBible(BibleTranslation translation) async {
    _debugLog('Loading Bible: ${translation.name} (${translation.id})',
        'ASSET_LOADER');

    // Check cache first
    if (_cache.containsKey(translation)) {
      _debugLog('Found ${translation.name} in cache', 'ASSET_LOADER');
      return _cache[translation]!;
    }

    try {
      final assetPath = '$assetBasePath/${translation.id}.json';
      _debugLog('Attempting to load asset: $assetPath', 'ASSET_LOADER');

      final jsonString = await assetLoader(assetPath);
      _debugLog('Asset loaded successfully: ${jsonString.length} characters',
          'ASSET_LOADER');

      final Map<String, dynamic> jsonData = json.decode(jsonString);
      _debugLog('JSON parsed successfully: ${jsonData.keys.join(', ')}',
          'ASSET_LOADER');

      final bible = Bible.fromJson(jsonData);
      _debugLog(
          'Bible created: ${bible.books.length} books, translation: ${bible.translation.name}',
          'ASSET_LOADER');

      // Cache the loaded bible
      _cache[translation] = bible;
      _debugLog('Bible cached for ${translation.name}', 'ASSET_LOADER');

      return bible;
    } catch (e) {
      _debugLog('ERROR loading ${translation.name}: $e', 'ASSET_LOADER');
      throw Exception('Failed to load ${translation.name} from assets: $e');
    }
  }

  @override
  Future<bool> isTranslationAvailable(BibleTranslation translation) async {
    try {
      final assetPath = '$assetBasePath/${translation.id}.json';
      _debugLog('Checking availability of asset: $assetPath', 'ASSET_LOADER');

      await assetLoader(assetPath);
      _debugLog('Asset available: ${translation.name}', 'ASSET_LOADER');
      return true;
    } catch (e) {
      _debugLog(
          'Asset NOT available: ${translation.name} - $e', 'ASSET_LOADER');
      return false;
    }
  }

  @override
  Future<List<BibleTranslation>> getAvailableTranslations() async {
    _debugLog('Checking available translations...', 'ASSET_LOADER');
    final available = <BibleTranslation>[];

    for (final translation in BibleTranslation.values) {
      _debugLog('Checking translation: ${translation.name} (${translation.id})',
          'ASSET_LOADER');
      if (await isTranslationAvailable(translation)) {
        available.add(translation);
        _debugLog('✓ Added available translation: ${translation.name}',
            'ASSET_LOADER');
      } else {
        _debugLog(
            '✗ Translation not available: ${translation.name}', 'ASSET_LOADER');
      }
    }

    _debugLog(
        'Total available translations: ${available.length} of ${BibleTranslation.values.length}',
        'ASSET_LOADER');
    _debugLog('Available: ${available.map((t) => t.name).join(', ')}',
        'ASSET_LOADER');

    return available;
  }

  /// Clear the cache (useful for memory management)
  static void clearCache() {
    _cache.clear();
  }
}

/// Implementation for loading Bible data from HTTP endpoints
class NetworkBibleLoader implements BibleLoader {
  static final Map<BibleTranslation, Bible> _cache = {};
  final String baseUrl;
  final Future<String> Function(String url) httpClient;

  /// Create a network loader
  /// [baseUrl] - Base URL for Bible data (e.g., 'https://api.example.com/bibles')
  /// [httpClient] - Function to fetch URL content
  NetworkBibleLoader({
    required this.baseUrl,
    required this.httpClient,
  });

  @override
  Future<Bible> loadBible(BibleTranslation translation) async {
    // Check cache first
    if (_cache.containsKey(translation)) {
      return _cache[translation]!;
    }

    try {
      final url = '$baseUrl/${translation.id}.json';
      final jsonString = await httpClient(url);

      final Map<String, dynamic> jsonData = json.decode(jsonString);
      final bible = Bible.fromJson(jsonData);

      // Cache the loaded bible
      _cache[translation] = bible;

      return bible;
    } catch (e) {
      throw Exception('Failed to load ${translation.name} from network: $e');
    }
  }

  @override
  Future<bool> isTranslationAvailable(BibleTranslation translation) async {
    try {
      final url = '$baseUrl/${translation.id}.json';
      await httpClient(url);
      return true;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<List<BibleTranslation>> getAvailableTranslations() async {
    final available = <BibleTranslation>[];

    for (final translation in BibleTranslation.values) {
      if (await isTranslationAvailable(translation)) {
        available.add(translation);
      }
    }

    return available;
  }

  /// Clear the cache (useful for memory management)
  static void clearCache() {
    _cache.clear();
  }
}
