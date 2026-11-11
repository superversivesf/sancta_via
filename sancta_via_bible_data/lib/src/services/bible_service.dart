import '../models/bible.dart';
import '../models/bible_translation.dart';
import '../models/bible_verse.dart';
import '../models/scripture_reference.dart';
import '../utils/reference_parser.dart';
import '../utils/logger.dart';
import 'bible_loader.dart';
import 'bible_search_service.dart';

/// Result of looking up scripture text
class ScriptureContent {
  /// The scripture reference
  final ScriptureReference reference;

  /// The text content
  final String text;

  /// The translation used
  final BibleTranslation translation;

  /// Whether the content was found
  final bool found;

  /// Error message if content was not found
  final String? errorMessage;

  /// Structured verses backing the text, with their true numbers.
  /// Empty when not found (or when no verses were available).
  final List<BibleVerse> verses;

  const ScriptureContent({
    required this.reference,
    required this.text,
    required this.translation,
    required this.found,
    this.errorMessage,
    this.verses = const [],
  });

  /// Create a successful result
  factory ScriptureContent.found({
    required ScriptureReference reference,
    required String text,
    required BibleTranslation translation,
    List<BibleVerse> verses = const [],
  }) {
    return ScriptureContent(
      reference: reference,
      text: text,
      translation: translation,
      found: true,
      verses: verses,
    );
  }

  /// Create a not found result
  factory ScriptureContent.notFound({
    required ScriptureReference reference,
    required BibleTranslation translation,
    String? errorMessage,
  }) {
    return ScriptureContent(
      reference: reference,
      text: '',
      translation: translation,
      found: false,
      errorMessage: errorMessage,
    );
  }

  @override
  String toString() =>
      found ? text : 'Not found: ${errorMessage ?? 'Unknown error'}';
}

/// Main service for Bible operations
class BibleService {
  final BibleLoader _loader;
  final Map<BibleTranslation, Bible> _cache = {};
  final Map<BibleTranslation, BibleSearchService> _searchServices = {};

  BibleService(this._loader);

  /// Get a Bible for the specified translation
  Future<Bible> getBible(BibleTranslation translation) async {
    AppLogger.service(
      'getBible called for ${translation.name} (${translation.id})',
      'BIBLE_SERVICE',
    );

    if (_cache.containsKey(translation)) {
      AppLogger.service(
        'Bible ${translation.name} found in cache',
        'BIBLE_SERVICE',
      );
      return _cache[translation]!;
    }

    AppLogger.service(
      'Loading Bible ${translation.name} from loader...',
      'BIBLE_SERVICE',
    );

    try {
      final bible = await _loader.loadBible(translation);
      AppLogger.service(
        'Bible ${translation.name} loaded successfully: ${bible.books.length} books',
        'BIBLE_SERVICE',
      );

      _cache[translation] = bible;

      // Create search service for this Bible
      _searchServices[translation] = BibleSearchService(bible);
      AppLogger.service(
        'Search service created for ${translation.name}',
        'BIBLE_SERVICE',
      );

      return bible;
    } catch (e) {
      AppLogger.service(
        'Failed to load Bible ${translation.name}: $e',
        'BIBLE_SERVICE',
      );
      rethrow;
    }
  }

  /// Get search service for a translation
  Future<BibleSearchService> getSearchService(
    BibleTranslation translation,
  ) async {
    if (_searchServices.containsKey(translation)) {
      return _searchServices[translation]!;
    }

    // This will load the Bible and create the search service
    await getBible(translation);
    return _searchServices[translation]!;
  }

  /// Get scripture content by reference
  Future<ScriptureContent> getScriptureContent(
    ScriptureReference reference,
    BibleTranslation translation,
  ) async {
    AppLogger.service(
      'getScriptureContent called: ${reference.displayText} from ${translation.name}',
      'BIBLE_SERVICE',
    );

    try {
      AppLogger.service(
        'Loading Bible for ${translation.name}...',
        'BIBLE_SERVICE',
      );
      final bible = await getBible(translation);

      AppLogger.service(
        'Looking for book: "${reference.book}" in ${bible.books.length} books',
        'BIBLE_SERVICE',
      );
      final book = bible.findBook(reference.book);

      if (book == null) {
        AppLogger.service(
          'Book "${reference.book}" not found. Available books: ${bible.bookNames.join(', ')}',
          'BIBLE_SERVICE',
        );
        return ScriptureContent.notFound(
          reference: reference,
          translation: translation,
          errorMessage:
              'Book "${reference.book}" not found in ${translation.abbreviation}',
        );
      }

      AppLogger.service(
        'Found book: ${book.name}, looking for chapter ${reference.chapter}',
        'BIBLE_SERVICE',
      );
      final chapter = book.getChapter(reference.chapter);
      if (chapter == null) {
        AppLogger.service(
          'Chapter ${reference.chapter} not found in ${reference.book}. Available chapters: ${book.chapterNumbers.join(', ')}',
          'BIBLE_SERVICE',
        );
        return ScriptureContent.notFound(
          reference: reference,
          translation: translation,
          errorMessage:
              'Chapter ${reference.chapter} not found in ${reference.book}',
        );
      }

      String text;
      List<BibleVerse> structuredVerses;

      if (reference.startVerse != null && reference.endVerse != null) {
        AppLogger.service(
          'Getting verse range ${reference.startVerse}-${reference.endVerse} from chapter ${reference.chapter}',
          'BIBLE_SERVICE',
        );
        // Get specific verse range
        final verses = chapter.getVerseRange(
          reference.startVerse!,
          reference.endVerse!,
        );
        if (verses.isEmpty) {
          AppLogger.service(
            'No verses found for range ${reference.startVerse}-${reference.endVerse}. Chapter has ${chapter.verses.length} verses',
            'BIBLE_SERVICE',
          );
          return ScriptureContent.notFound(
            reference: reference,
            translation: translation,
            errorMessage:
                'Verses ${reference.startVerse}-${reference.endVerse} not found',
          );
        }

        text = verses.map((verse) => '${verse.number} ${verse.text}').join(' ');
        structuredVerses = verses;
        AppLogger.service(
          'Successfully retrieved ${verses.length} verses, text length: ${text.length}',
          'BIBLE_SERVICE',
        );
      } else {
        AppLogger.service(
          'Getting entire chapter ${reference.chapter}',
          'BIBLE_SERVICE',
        );
        // Get entire chapter
        if (chapter.verses.isEmpty) {
          AppLogger.service(
            'Chapter ${reference.chapter} has no verses',
            'BIBLE_SERVICE',
          );
          return ScriptureContent.notFound(
            reference: reference,
            translation: translation,
            errorMessage: 'No verses available for this chapter',
          );
        }
        text = chapter.fullText;
        structuredVerses = chapter.verses;
        AppLogger.service(
          'Successfully retrieved entire chapter, text length: ${text.length}',
          'BIBLE_SERVICE',
        );
      }

      AppLogger.service(
        'Scripture content retrieved successfully for ${reference.displayText}',
        'BIBLE_SERVICE',
      );
      return ScriptureContent.found(
        reference: reference,
        text: text,
        translation: translation,
        verses: structuredVerses,
      );
    } catch (e) {
      AppLogger.service(
        'Error loading scripture ${reference.displayText}: $e',
        'BIBLE_SERVICE',
      );
      return ScriptureContent.notFound(
        reference: reference,
        translation: translation,
        errorMessage: 'Error loading scripture: ${e.toString()}',
      );
    }
  }

  /// Get scripture content by parsing a reference string
  Future<ScriptureContent> getScriptureByReference(
    String referenceText,
    BibleTranslation translation,
  ) async {
    try {
      final reference = ReferenceParser.parse(referenceText);
      return getScriptureContent(reference, translation);
    } catch (e) {
      final dummyRef = ScriptureReference(
        book: 'Unknown',
        chapter: 0,
        displayText: referenceText,
      );
      return ScriptureContent.notFound(
        reference: dummyRef,
        translation: translation,
        errorMessage: 'Could not parse reference: $referenceText',
      );
    }
  }

  /// Search for text across the Bible
  Future<List<SearchResult>> searchText(
    String query,
    BibleTranslation translation, {
    bool caseSensitive = false,
    bool wholeWords = false,
    List<String>? bookFilter,
    bool oldTestamentOnly = false,
    bool newTestamentOnly = false,
    int maxResults = 100,
  }) async {
    final searchService = await getSearchService(translation);
    return searchService.searchText(
      query,
      caseSensitive: caseSensitive,
      wholeWords: wholeWords,
      bookFilter: bookFilter,
      oldTestamentOnly: oldTestamentOnly,
      newTestamentOnly: newTestamentOnly,
      maxResults: maxResults,
    );
  }

  /// Get verse text directly (convenience method)
  Future<String?> getVerseText(
    String bookName,
    int chapter,
    int verse,
    BibleTranslation translation,
  ) async {
    final reference = ScriptureReference.verse(bookName, chapter, verse);
    final content = await getScriptureContent(reference, translation);
    return content.found ? content.text : null;
  }

  /// Get chapter text directly (convenience method)
  Future<String?> getChapterText(
    String bookName,
    int chapter,
    BibleTranslation translation,
  ) async {
    final reference = ScriptureReference.chapter(bookName, chapter);
    final content = await getScriptureContent(reference, translation);
    return content.found ? content.text : null;
  }

  /// Get verse range text directly (convenience method)
  Future<String?> getVerseRangeText(
    String bookName,
    int chapter,
    int startVerse,
    int endVerse,
    BibleTranslation translation,
  ) async {
    final reference = ScriptureReference.range(
      bookName,
      chapter,
      startVerse,
      endVerse,
    );
    final content = await getScriptureContent(reference, translation);
    return content.found ? content.text : null;
  }

  /// Check if a book exists in a translation
  Future<bool> hasBook(String bookName, BibleTranslation translation) async {
    try {
      final bible = await getBible(translation);
      return bible.hasBook(bookName);
    } catch (e) {
      return false;
    }
  }

  /// Get all book names for a translation
  Future<List<String>> getBookNames(BibleTranslation translation) async {
    try {
      final bible = await getBible(translation);
      return bible.bookNames;
    } catch (e) {
      return [];
    }
  }

  /// Get available translations
  Future<List<BibleTranslation>> getAvailableTranslations() async {
    AppLogger.service('Getting available translations...', 'BIBLE_SERVICE');

    try {
      final translations = await _loader.getAvailableTranslations();
      AppLogger.service(
        'Available translations: ${translations.map((t) => '${t.name} (${t.id})').join(', ')}',
        'BIBLE_SERVICE',
      );
      return translations;
    } catch (e) {
      AppLogger.service(
        'Error getting available translations: $e',
        'BIBLE_SERVICE',
      );
      rethrow;
    }
  }

  /// Check if a translation is available
  Future<bool> isTranslationAvailable(BibleTranslation translation) async {
    AppLogger.service(
      'Checking if ${translation.name} (${translation.id}) is available...',
      'BIBLE_SERVICE',
    );

    try {
      final available = await _loader.isTranslationAvailable(translation);
      AppLogger.service(
        '${translation.name} availability: $available',
        'BIBLE_SERVICE',
      );
      return available;
    } catch (e) {
      AppLogger.service(
        'Error checking availability for ${translation.name}: $e',
        'BIBLE_SERVICE',
      );
      return false;
    }
  }

  /// Preload translations for better performance
  Future<void> preloadTranslations([
    List<BibleTranslation>? translations,
  ]) async {
    final toLoad = translations ?? await getAvailableTranslations();

    for (final translation in toLoad) {
      try {
        await getBible(translation);
      } catch (e) {
        // Continue with other translations if one fails
      }
    }
  }

  /// Clear all caches
  void clearCache() {
    _cache.clear();
    _searchServices.clear();
  }

  /// Get cache statistics
  Map<String, int> getCacheStats() {
    return {
      'loaded_bibles': _cache.length,
      'search_services': _searchServices.length,
    };
  }

  /// Validate a scripture reference without loading content
  Future<bool> isValidReference(
    String referenceText,
    BibleTranslation translation,
  ) async {
    try {
      final reference = ReferenceParser.parse(referenceText);
      final bible = await getBible(translation);
      final book = bible.findBook(reference.book);

      if (book == null) return false;
      if (!book.hasChapter(reference.chapter)) return false;

      if (reference.startVerse != null) {
        final chapter = book.getChapter(reference.chapter);
        if (chapter == null) return false;

        if (!chapter.hasVerse(reference.startVerse!)) return false;
        if (reference.endVerse != null &&
            !chapter.hasVerse(reference.endVerse!)) {
          return false;
        }
      }

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Get multiple scripture contents at once
  Future<List<ScriptureContent>> getMultipleScriptures(
    List<ScriptureReference> references,
    BibleTranslation translation,
  ) async {
    final results = <ScriptureContent>[];

    for (final reference in references) {
      final content = await getScriptureContent(reference, translation);
      results.add(content);
    }

    return results;
  }
}
